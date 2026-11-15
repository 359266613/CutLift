#pragma once

#import <UIKit/UIKit.h>

/// 负责找当前窗口/顶层控制器，并提供抠图期间的轻量 HUD。
@interface AxsCutLiftPresenter : NSObject

+ (UIWindow *)axs_cutlift_activeWindow;
+ (UIViewController *)axs_cutlift_topControllerInWindow:(UIWindow *)window;
+ (void)axs_cutlift_showHUDInWindow:(UIWindow *)window text:(NSString *)text;
+ (void)axs_cutlift_hideHUD;

@end
