#import "AxsCutLiftPresenter.h"

static UIView *axs_cutlift_hudView = nil;

@implementation AxsCutLiftPresenter

+ (UIWindow *)axs_cutlift_activeWindow {
    if (@available(iOS 13.0, *)) {
        for (UIScene *scene in [UIApplication sharedApplication].connectedScenes) {
            if (![scene isKindOfClass:[UIWindowScene class]]) {
                continue;
            }
            if (scene.activationState != UISceneActivationStateForegroundActive) {
                continue;
            }
            UIWindowScene *windowScene = (UIWindowScene *)scene;
            for (UIWindow *window in windowScene.windows) {
                if (window.isKeyWindow && !window.hidden) {
                    return window;
                }
            }
        }
    }
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated-declarations"
    return [UIApplication sharedApplication].keyWindow;
#pragma clang diagnostic pop
}

+ (UIViewController *)axs_cutlift_topControllerInWindow:(UIWindow *)window {
    UIViewController *controller = window.rootViewController;
    while (controller.presentedViewController) {
        controller = controller.presentedViewController;
    }
    // 分栏控制器 / 导航栈需要继续下钻，否则会盖在空容器上。
    while (controller) {
        if ([controller isKindOfClass:[UITabBarController class]]) {
            controller = ((UITabBarController *)controller).selectedViewController;
        } else if ([controller isKindOfClass:[UINavigationController class]]) {
            controller = ((UINavigationController *)controller).topViewController;
        } else if ([controller isKindOfClass:[UISplitViewController class]]) {
            UISplitViewController *split = (UISplitViewController *)controller;
            controller = split.viewControllers.lastObject;
        } else {
            break;
        }
    }
    return controller;
}

+ (void)axs_cutlift_showHUDInWindow:(UIWindow *)window text:(NSString *)text {
    if (!window) {
        return;
    }
    [self axs_cutlift_hideHUD];

    UIVisualEffectView *hud = [[UIVisualEffectView alloc]
        initWithEffect:[UIBlurEffect effectWithStyle:UIBlurEffectStyleSystemMaterialDark]];
    hud.translatesAutoresizingMaskIntoConstraints = NO;
    hud.layer.cornerRadius = 16.0;
    hud.layer.cornerCurve = kCACornerCurveContinuous;
    hud.layer.masksToBounds = YES;
    hud.userInteractionEnabled = NO;

    UIActivityIndicatorView *spinner =
        [[UIActivityIndicatorView alloc] initWithActivityIndicatorStyle:UIActivityIndicatorViewStyleMedium];
    spinner.translatesAutoresizingMaskIntoConstraints = NO;
    spinner.color = [UIColor whiteColor];
    [spinner startAnimating];
    [hud.contentView addSubview:spinner];

    UILabel *label = [[UILabel alloc] initWithFrame:CGRectZero];
    label.translatesAutoresizingMaskIntoConstraints = NO;
    label.text = text.length > 0 ? text : @"抠图中…";
    label.font = [UIFont systemFontOfSize:13.0 weight:UIFontWeightMedium];
    label.textColor = [UIColor whiteColor];
    label.textAlignment = NSTextAlignmentCenter;
    [hud.contentView addSubview:label];

    [window addSubview:hud];
    [NSLayoutConstraint activateConstraints:@[
        [hud.centerXAnchor constraintEqualToAnchor:window.centerXAnchor],
        [hud.centerYAnchor constraintEqualToAnchor:window.centerYAnchor],
        [hud.widthAnchor constraintEqualToConstant:132.0],
        [hud.heightAnchor constraintEqualToConstant:104.0],
        [spinner.centerXAnchor constraintEqualToAnchor:hud.contentView.centerXAnchor],
        [spinner.topAnchor constraintEqualToAnchor:hud.contentView.topAnchor constant:26.0],
        [label.topAnchor constraintEqualToAnchor:spinner.bottomAnchor constant:12.0],
        [label.leadingAnchor constraintEqualToAnchor:hud.contentView.leadingAnchor constant:8.0],
        [label.trailingAnchor constraintEqualToAnchor:hud.contentView.trailingAnchor constant:-8.0],
    ]];

    hud.alpha = 0.0;
    [UIView animateWithDuration:0.15
                     animations:^{
                         hud.alpha = 1.0;
                     }];
    axs_cutlift_hudView = hud;
}

+ (void)axs_cutlift_hideHUD {
    UIView *hud = axs_cutlift_hudView;
    axs_cutlift_hudView = nil;
    if (!hud) {
        return;
    }
    [UIView animateWithDuration:0.15
        animations:^{
            hud.alpha = 0.0;
        }
        completion:^(BOOL finished) {
            [hud removeFromSuperview];
        }];
}

@end
