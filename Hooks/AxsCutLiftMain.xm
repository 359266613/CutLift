#import <UIKit/UIKit.h>
#import "AxsCutLiftConfig.h"
#import "AxsCutLiftGesture.h"

// 目标是任意 App 里的图片视图，不是 SpringBoard；过滤器见 AxsCutLift.plist。
%hook UIImageView

- (void)didMoveToWindow {
    %orig;
    if (!self.window) {
        return;
    }
    if (![[AxsCutLiftConfig axs_cutlift_shared] axs_cutlift_isEnabled]) {
        return;
    }
    // 只补一次识别器；重复调用由关联对象拦住。
    [AxsCutLiftGestureInstaller axs_cutlift_installInWindow:self.window];
}

%end

%ctor {
    @autoreleasepool {
        // Readers load a snapshot; they never write default preferences.
        [AxsCutLiftConfig axs_cutlift_shared];
    }
}
