#pragma once

#import <UIKit/UIKit.h>

/// 抠图结果预览：棋盘格透明底 + 拷贝 / 分享 / 关闭。
@interface AxsCutLiftPreviewController : UIViewController

- (instancetype)initWithCutoutImage:(UIImage *)image;

@end
