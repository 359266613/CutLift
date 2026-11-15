#import "AxsCutLiftSegmenter.h"
#import <CoreImage/CoreImage.h>
#import <CoreVideo/CoreVideo.h>
#import <ImageIO/ImageIO.h>
#import <Vision/Vision.h>
#import <math.h>
#import <stdlib.h>

static NSString * const AxsCutLiftSegmenterErrorDomain = @"com.axs.cutlift.segmenter";
static const CGFloat AxsCutLiftScanMaxDimension = 256.0;

static CIContext *axs_cutlift_sharedContext(void) {
    static CIContext *context;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        // 无 EDR/颜色管理的渲染上下文，输出仍是标准 sRGB 位图。
        context = [CIContext contextWithOptions:@{kCIContextUseSoftwareRenderer : @NO}];
    });
    return context;
}

static UIImage *axs_cutlift_uprightImage(UIImage *image) {
    if (image.imageOrientation == UIImageOrientationUp) {
        return image;
    }
    UIGraphicsImageRendererFormat *format = [UIGraphicsImageRendererFormat defaultFormat];
    format.scale = image.scale;
    format.opaque = NO;
    UIGraphicsImageRenderer *renderer = [[UIGraphicsImageRenderer alloc] initWithSize:image.size
                                                                              format:format];
    return [renderer imageWithActions:^(UIGraphicsImageRendererContext *context) {
        [image drawInRect:CGRectMake(0.0, 0.0, image.size.width, image.size.height)];
    }];
}

static CIImage *axs_cutlift_maskFittedToExtent(CIImage *mask, CGRect extent) {
    if (CGRectIsEmpty(mask.extent) || CGRectIsEmpty(extent)) {
        return nil;
    }
    CGFloat scaleX = extent.size.width / mask.extent.size.width;
    CGFloat scaleY = extent.size.height / mask.extent.size.height;
    CIImage *fitted = mask;
    if (fabs(scaleX - 1.0) > 0.001 || fabs(scaleY - 1.0) > 0.001) {
        fitted = [mask imageByApplyingTransform:CGAffineTransformMakeScale(scaleX, scaleY)];
    }
    return [fitted imageByCroppingToRect:extent];
}

static CIImage *axs_cutlift_personMask(CIImage *input, BOOL accurate, NSError **error) {
    VNGeneratePersonSegmentationRequest *request = [[VNGeneratePersonSegmentationRequest alloc] init];
    request.qualityLevel = accurate ? VNGeneratePersonSegmentationRequestQualityLevelAccurate
                                    : VNGeneratePersonSegmentationRequestQualityLevelBalanced;
    request.outputPixelFormat = kCVPixelFormatType_OneComponent8;
    VNImageRequestHandler *handler =
        [[VNImageRequestHandler alloc] initWithCIImage:input
                                          orientation:kCGImagePropertyOrientationUp
                                              options:@{}];
    if (![handler performRequests:@[ request ] error:error]) {
        return nil;
    }
    VNPixelBufferObservation *observation =
        (VNPixelBufferObservation *)request.results.firstObject;
    if (!observation || !observation.pixelBuffer) {
        return nil;
    }
    return axs_cutlift_maskFittedToExtent([CIImage imageWithCVPixelBuffer:observation.pixelBuffer],
                                          input.extent);
}

static CIImage *axs_cutlift_objectMask(CIImage *input, NSError **error) {
    VNGenerateObjectnessBasedSaliencyImageRequest *request =
        [[VNGenerateObjectnessBasedSaliencyImageRequest alloc] init];
    VNImageRequestHandler *handler =
        [[VNImageRequestHandler alloc] initWithCIImage:input
                                          orientation:kCGImagePropertyOrientationUp
                                              options:@{}];
    if (![handler performRequests:@[ request ] error:error]) {
        return nil;
    }
    VNSaliencyImageObservation *observation =
        (VNSaliencyImageObservation *)request.results.firstObject;
    if (!observation || !observation.pixelBuffer) {
        return nil;
    }
    CIImage *heat = axs_cutlift_maskFittedToExtent(
        [CIImage imageWithCVPixelBuffer:observation.pixelBuffer], input.extent);
    if (!heat) {
        return nil;
    }
    // 显著性输出是热力图，压成硬边蒙版才不会出现半透明重影。
    CIFilter *controls = [CIFilter filterWithName:@"CIColorControls"];
    [controls setValue:heat forKey:kCIInputImageKey];
    [controls setValue:@1.6 forKey:kCIInputContrastKey];
    [controls setValue:@-0.25 forKey:kCIInputBrightnessKey];
    CIImage *stepped = controls.outputImage;
    CIFilter *gamma = [CIFilter filterWithName:@"CIGammaAdjust"];
    [gamma setValue:stepped forKey:kCIInputImageKey];
    [gamma setValue:@0.6 forKey:@"inputPower"];
    return gamma.outputImage;
}

/// 返回 CI 坐标系（左下原点）下的主体外框；找不到主体时返回 CGRectNull。
static CGRect axs_cutlift_subjectBounds(CIImage *mask, CGRect extent) {
    CGFloat longest = MAX(extent.size.width, extent.size.height);
    if (longest <= 0.0) {
        return CGRectNull;
    }
    CGFloat scale = MIN(1.0, AxsCutLiftScanMaxDimension / longest);
    size_t width = (size_t)MAX(1.0, floor(extent.size.width * scale));
    size_t height = (size_t)MAX(1.0, floor(extent.size.height * scale));
    size_t bytesPerRow = width;
    uint8_t *buffer = calloc(height * bytesPerRow, 1);
    if (!buffer) {
        return CGRectNull;
    }
    CGColorSpaceRef space = CGColorSpaceCreateDeviceGray();
    CGContextRef context = CGBitmapContextCreate(buffer, width, height, 8, bytesPerRow, space,
                                                 kCGImageAlphaNone);
    CGColorSpaceRelease(space);
    CGImageRef maskImage = context ? [axs_cutlift_sharedContext() createCGImage:mask
                                                                      fromRect:extent]
                                   : NULL;
    if (!context || !maskImage) {
        if (context) CGContextRelease(context);
        if (maskImage) CGImageRelease(maskImage);
        free(buffer);
        return CGRectNull;
    }
    CGContextDrawImage(context, CGRectMake(0.0, 0.0, (CGFloat)width, (CGFloat)height), maskImage);
    CGImageRelease(maskImage);
    CGContextRelease(context);

    size_t minX = width, minY = height, maxX = 0, maxY = 0;
    BOOL found = NO;
    for (size_t y = 0; y < height; y++) {
        const uint8_t *row = buffer + y * bytesPerRow;
        for (size_t x = 0; x < width; x++) {
            if (row[x] <= 32) {
                continue;
            }
            found = YES;
            if (x < minX) minX = x;
            if (x > maxX) maxX = x;
            if (y < minY) minY = y;
            if (y > maxY) maxY = y;
        }
    }
    free(buffer);
    if (!found) {
        return CGRectNull;
    }

    CGFloat originX = floor((CGFloat)minX / scale);
    CGFloat originYTop = floor((CGFloat)minY / scale);
    CGFloat widthPx = ceil((CGFloat)(maxX + 1) / scale) - originX;
    CGFloat heightPx = ceil((CGFloat)(maxY + 1) / scale) - originYTop;
    // 位图原点在左上，CI 原点在左下，需要翻转 y。
    CGFloat originY = extent.size.height - originYTop - heightPx;
    return CGRectMake(originX, originY, widthPx, heightPx);
}

@implementation AxsCutLiftSegmenter

+ (void)axs_cutlift_cutoutFromImage:(UIImage *)image
                           accurate:(BOOL)accurate
                            feather:(CGFloat)feather
                               trim:(BOOL)trim
                         completion:(AxsCutLiftSegmentCompletion)completion {
    if (!completion) {
        return;
    }
    if (!image) {
        completion(nil, [NSError errorWithDomain:AxsCutLiftSegmenterErrorDomain
                                            code:1
                                        userInfo:@{NSLocalizedDescriptionKey : @"没有可处理的图片"}]);
        return;
    }
    UIImage *source = axs_cutlift_uprightImage(image);
    if (!source.CGImage) {
        completion(nil, [NSError errorWithDomain:AxsCutLiftSegmenterErrorDomain
                                            code:2
                                        userInfo:@{NSLocalizedDescriptionKey : @"图片无法解码"}]);
        return;
    }

    dispatch_async(dispatch_get_global_queue(QOS_CLASS_USER_INITIATED, 0), ^{
        @autoreleasepool {
            CIImage *input = [CIImage imageWithCGImage:source.CGImage];
            CGRect extent = input.extent;
            NSError *error = nil;

            CIImage *mask = axs_cutlift_personMask(input, accurate, &error);
            if (!mask) {
                mask = axs_cutlift_objectMask(input, &error);
            }
            if (!mask) {
                NSError *failure = error ?: [NSError errorWithDomain:AxsCutLiftSegmenterErrorDomain
                                                                code:3
                                                            userInfo:@{
                                                                NSLocalizedDescriptionKey :
                                                                    @"没有识别到可抠出的主体"
                                                            }];
                dispatch_async(dispatch_get_main_queue(), ^{
                    completion(nil, failure);
                });
                return;
            }

            if (feather > 0.01) {
                CIFilter *blur = [CIFilter filterWithName:@"CIGaussianBlur"];
                [blur setValue:mask forKey:kCIInputImageKey];
                [blur setValue:@(feather) forKey:kCIInputRadiusKey];
                CIImage *blurred = blur.outputImage;
                if (blurred) {
                    mask = [blurred imageByCroppingToRect:extent];
                }
            }

            CIImage *base = input;
            if (trim) {
                CGRect bounds = axs_cutlift_subjectBounds(mask, extent);
                CGRect clipped = CGRectIsNull(bounds) ? CGRectNull : CGRectIntersection(bounds, extent);
                if (!CGRectIsNull(clipped) && clipped.size.width >= 8.0 && clipped.size.height >= 8.0) {
                    base = [input imageByCroppingToRect:clipped];
                    mask = [mask imageByCroppingToRect:clipped];
                    extent = clipped;
                }
            }

            CIImage *composited = nil;
            CIFilter *blend = [CIFilter filterWithName:@"CIBlendWithMask"];
            if (blend) {
                [blend setValue:base forKey:kCIInputImageKey];
                [blend setValue:[CIImage emptyImage] forKey:kCIInputBackgroundImageKey];
                [blend setValue:mask forKey:kCIInputMaskImageKey];
                composited = blend.outputImage;
            }

            UIImage *result = nil;
            if (composited) {
                CGImageRef rendered = [axs_cutlift_sharedContext() createCGImage:composited
                                                                        fromRect:extent];
                if (rendered) {
                    result = [UIImage imageWithCGImage:rendered
                                                scale:source.scale
                                          orientation:UIImageOrientationUp];
                    CGImageRelease(rendered);
                }
            }

            dispatch_async(dispatch_get_main_queue(), ^{
                if (result) {
                    completion(result, nil);
                } else {
                    completion(nil, [NSError errorWithDomain:AxsCutLiftSegmenterErrorDomain
                                                        code:4
                                                    userInfo:@{
                                                        NSLocalizedDescriptionKey : @"抠图渲染失败"
                                                    }]);
                }
            });
        }
    });
}

@end
