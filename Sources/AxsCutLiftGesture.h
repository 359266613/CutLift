#pragma once

#import <UIKit/UIKit.h>

/// 把双指长按识别器挂到窗口上，避免改动 App 内任何视图的 userInteractionEnabled。
@interface AxsCutLiftGestureInstaller : NSObject

+ (void)axs_cutlift_installInWindow:(UIWindow *)window;

@end
