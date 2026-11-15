#pragma once

#import <UIKit/UIKit.h>

typedef void (^AxsCutLiftSegmentCompletion)(UIImage *image, NSError *error);

/// 抠图核心：iOS 16 上没有前景实例蒙版，先走人像分割，失败再退显著物体检测。
@interface AxsCutLiftSegmenter : NSObject

+ (void)axs_cutlift_cutoutFromImage:(UIImage *)image
                           accurate:(BOOL)accurate
                            feather:(CGFloat)feather
                               trim:(BOOL)trim
                         completion:(AxsCutLiftSegmentCompletion)completion;

@end
