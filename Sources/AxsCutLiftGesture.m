#import "AxsCutLiftGesture.h"
#import "AxsCutLiftConfig.h"
#import "AxsCutLiftPresenter.h"
#import "AxsCutLiftPreviewController.h"
#import "AxsCutLiftSegmenter.h"
#import <objc/runtime.h>

static const void *AxsCutLiftRecognizerKey = &AxsCutLiftRecognizerKey;
static BOOL axs_cutlift_isProcessing = NO;
static const CGFloat AxsCutLiftMinimumPixelSide = 160.0;

@interface AxsCutLiftGestureHandler : NSObject
+ (instancetype)axs_cutlift_sharedHandler;
- (void)axs_cutlift_handleRecognizer:(UILongPressGestureRecognizer *)recognizer;
@end

@implementation AxsCutLiftGestureHandler

+ (instancetype)axs_cutlift_sharedHandler {
    static AxsCutLiftGestureHandler *handler;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        handler = [[self alloc] init];
    });
    return handler;
}

- (void)axs_cutlift_handleRecognizer:(UILongPressGestureRecognizer *)recognizer {
    if (recognizer.state != UIGestureRecognizerStateBegan || axs_cutlift_isProcessing) {
        return;
    }
    // 开关关闭后识别器仍在，这里读快照即时生效。
    if (![[AxsCutLiftConfig axs_cutlift_shared] axs_cutlift_isEnabled]) {
        return;
    }
    UIView *host = recognizer.view;
    UIWindow *window = [host isKindOfClass:[UIWindow class]] ? (UIWindow *)host : host.window;
    if (!window) {
        return;
    }

    CGPoint point = [recognizer locationInView:window];
    UIImageView *target = [self axs_cutlift_imageViewAtPoint:point window:window];
    if (!target) {
        return;
    }
    UIImage *image = target.image;
    if (!image || image.size.width <= 0.0 || image.size.height <= 0.0) {
        return;
    }
    // 跳过图标、表情、缩略图这类小图，避免误触。
    CGFloat pixelWidth = image.size.width * image.scale;
    CGFloat pixelHeight = image.size.height * image.scale;
    if (MIN(pixelWidth, pixelHeight) < AxsCutLiftMinimumPixelSide) {
        return;
    }

    AxsCutLiftConfig *config = [AxsCutLiftConfig axs_cutlift_shared];
    BOOL accurate = [[config axs_cutlift_valueForKey:@"accurate" defaultValue:@YES] boolValue];
    BOOL trim = [[config axs_cutlift_valueForKey:@"trim" defaultValue:@YES] boolValue];
    CGFloat feather = [[config axs_cutlift_valueForKey:@"feather" defaultValue:@2.0] doubleValue];

    axs_cutlift_isProcessing = YES;
    [AxsCutLiftPresenter axs_cutlift_showHUDInWindow:window text:@"抠图中…"];

    __weak typeof(self) weakSelf = self;
    [AxsCutLiftSegmenter axs_cutlift_cutoutFromImage:image
                                            accurate:accurate
                                             feather:feather
                                                trim:trim
                                          completion:^(UIImage *result, NSError *error) {
        axs_cutlift_isProcessing = NO;
        [AxsCutLiftPresenter axs_cutlift_hideHUD];
        if (!result) {
            [weakSelf axs_cutlift_reportFailure:error inWindow:window];
            return;
        }
        UINotificationFeedbackGenerator *feedback =
            [[UINotificationFeedbackGenerator alloc] init];
        [feedback notificationOccurred:UINotificationFeedbackTypeSuccess];
        [weakSelf axs_cutlift_presentResult:result inWindow:window];
    }];
}

- (UIImageView *)axs_cutlift_imageViewAtPoint:(CGPoint)point window:(UIWindow *)window {
    UIView *hit = [window hitTest:point withEvent:nil];
    for (UIView *view = hit; view; view = view.superview) {
        if ([view isKindOfClass:[UIImageView class]]) {
            return (UIImageView *)view;
        }
        if (view == window) {
            break;
        }
    }
    return nil;
}

- (void)axs_cutlift_presentResult:(UIImage *)image inWindow:(UIWindow *)window {
    UIViewController *presenter = [AxsCutLiftPresenter axs_cutlift_topControllerInWindow:window];
    if (!presenter) {
        return;
    }
    AxsCutLiftPreviewController *controller =
        [[AxsCutLiftPreviewController alloc] initWithCutoutImage:image];
    controller.modalPresentationStyle = UIModalPresentationPageSheet;
    [presenter presentViewController:controller animated:YES completion:nil];
}

- (void)axs_cutlift_reportFailure:(NSError *)error inWindow:(UIWindow *)window {
    UIViewController *presenter = [AxsCutLiftPresenter axs_cutlift_topControllerInWindow:window];
    if (!presenter) {
        return;
    }
    UIAlertController *alert = [UIAlertController
        alertControllerWithTitle:@"没有抠出主体"
                         message:error.localizedDescription ?: @"换一张主体更清晰的图片再试一次。"
                  preferredStyle:UIAlertControllerStyleAlert];
    [alert addAction:[UIAlertAction actionWithTitle:@"好"
                                              style:UIAlertActionStyleDefault
                                            handler:nil]];
    [presenter presentViewController:alert animated:YES completion:nil];
}

@end

@implementation AxsCutLiftGestureInstaller

+ (void)axs_cutlift_installInWindow:(UIWindow *)window {
    if (!window) {
        return;
    }
    if (objc_getAssociatedObject(window, AxsCutLiftRecognizerKey)) {
        return;
    }
    AxsCutLiftConfig *config = [AxsCutLiftConfig axs_cutlift_shared];
    BOOL twoFinger = [[config axs_cutlift_valueForKey:@"twoFinger" defaultValue:@YES] boolValue];

    UILongPressGestureRecognizer *recognizer =
        [[UILongPressGestureRecognizer alloc] initWithTarget:[AxsCutLiftGestureHandler axs_cutlift_sharedHandler]
                                                      action:@selector(axs_cutlift_handleRecognizer:)];
    recognizer.numberOfTouchesRequired = twoFinger ? 2 : 1;
    recognizer.minimumPressDuration = 0.45;
    recognizer.allowableMovement = 12.0;
    // 不打断 App 自己的手势与触摸。
    recognizer.cancelsTouchesInView = NO;
    recognizer.delaysTouchesBegan = NO;
    recognizer.delaysTouchesEnded = NO;
    [window addGestureRecognizer:recognizer];
    objc_setAssociatedObject(window, AxsCutLiftRecognizerKey, recognizer,
                             OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

@end
