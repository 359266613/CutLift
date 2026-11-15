#import "AxsCutLiftPreviewController.h"

static UIColor *axs_cutlift_checkerColor(void) {
    static UIColor *color;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        CGSize tile = CGSizeMake(20.0, 20.0);
        UIGraphicsImageRenderer *renderer = [[UIGraphicsImageRenderer alloc] initWithSize:tile];
        UIImage *pattern = [renderer imageWithActions:^(UIGraphicsImageRendererContext *context) {
            CGContextRef cg = context.CGContext;
            [[UIColor colorWithWhite:0.98 alpha:1.0] setFill];
            CGContextFillRect(cg, CGRectMake(0.0, 0.0, tile.width, tile.height));
            [[UIColor colorWithWhite:0.86 alpha:1.0] setFill];
            CGContextFillRect(cg, CGRectMake(0.0, 0.0, tile.width / 2.0, tile.height / 2.0));
            CGContextFillRect(cg, CGRectMake(tile.width / 2.0, tile.height / 2.0,
                                             tile.width / 2.0, tile.height / 2.0));
        }];
        color = [UIColor colorWithPatternImage:pattern];
    });
    return color;
}

@interface AxsCutLiftPreviewController ()

@property (nonatomic, strong) UIImage *cutoutImage;
@property (nonatomic, strong) UIImageView *imageView;
@property (nonatomic, strong) UIView *stageView;

@end

@implementation AxsCutLiftPreviewController

- (instancetype)initWithCutoutImage:(UIImage *)image {
    self = [super initWithNibName:nil bundle:nil];
    if (self) {
        _cutoutImage = image;
    }
    return self;
}

- (void)viewDidLoad {
    [super viewDidLoad];
    self.title = @"轻抠";
    self.view.backgroundColor = [UIColor systemBackgroundColor];
    if (@available(iOS 15.0, *)) {
        UISheetPresentationController *sheet = self.sheetPresentationController;
        sheet.prefersGrabberVisible = YES;
        sheet.preferredCornerRadius = 22.0;
    }
    [self axs_cutlift_buildInterface];
}

- (void)axs_cutlift_buildInterface {
    UIView *stage = [[UIView alloc] initWithFrame:CGRectZero];
    stage.translatesAutoresizingMaskIntoConstraints = NO;
    stage.backgroundColor = axs_cutlift_checkerColor();
    stage.layer.cornerRadius = 16.0;
    stage.layer.cornerCurve = kCACornerCurveContinuous;
    stage.layer.masksToBounds = YES;
    [self.view addSubview:stage];
    self.stageView = stage;

    UIImageView *imageView = [[UIImageView alloc] initWithImage:self.cutoutImage];
    imageView.translatesAutoresizingMaskIntoConstraints = NO;
    imageView.contentMode = UIViewContentModeScaleAspectFit;
    imageView.layer.shadowColor = [UIColor blackColor].CGColor;
    imageView.layer.shadowOpacity = 0.18;
    imageView.layer.shadowRadius = 12.0;
    imageView.layer.shadowOffset = CGSizeMake(0.0, 6.0);
    [stage addSubview:imageView];
    self.imageView = imageView;

    UILabel *caption = [[UILabel alloc] initWithFrame:CGRectZero];
    caption.translatesAutoresizingMaskIntoConstraints = NO;
    caption.text = [NSString stringWithFormat:@"%.0f × %.0f · 透明底 PNG",
                                              self.cutoutImage.size.width * self.cutoutImage.scale,
                                              self.cutoutImage.size.height * self.cutoutImage.scale];
    caption.font = [UIFont preferredFontForTextStyle:UIFontTextStyleFootnote];
    caption.textColor = [UIColor secondaryLabelColor];
    caption.textAlignment = NSTextAlignmentCenter;
    [self.view addSubview:caption];

    UIStackView *actions = [[UIStackView alloc] initWithFrame:CGRectZero];
    actions.translatesAutoresizingMaskIntoConstraints = NO;
    actions.axis = UILayoutConstraintAxisHorizontal;
    actions.distribution = UIStackViewDistributionFillEqually;
    actions.spacing = 12.0;
    [actions addArrangedSubview:[self axs_cutlift_buttonWithTitle:@"拷贝"
                                                         selector:@selector(axs_cutlift_copyTapped:)]];
    [actions addArrangedSubview:[self axs_cutlift_buttonWithTitle:@"分享"
                                                         selector:@selector(axs_cutlift_shareTapped:)]];
    [actions addArrangedSubview:[self axs_cutlift_buttonWithTitle:@"关闭"
                                                         selector:@selector(axs_cutlift_closeTapped:)]];
    [self.view addSubview:actions];

    UILayoutGuide *safe = self.view.safeAreaLayoutGuide;
    [NSLayoutConstraint activateConstraints:@[
        [stage.topAnchor constraintEqualToAnchor:safe.topAnchor constant:16.0],
        [stage.leadingAnchor constraintEqualToAnchor:safe.leadingAnchor constant:16.0],
        [stage.trailingAnchor constraintEqualToAnchor:safe.trailingAnchor constant:-16.0],
        [stage.bottomAnchor constraintEqualToAnchor:actions.topAnchor constant:-16.0],

        [imageView.topAnchor constraintEqualToAnchor:stage.topAnchor constant:12.0],
        [imageView.leadingAnchor constraintEqualToAnchor:stage.leadingAnchor constant:12.0],
        [imageView.trailingAnchor constraintEqualToAnchor:stage.trailingAnchor constant:-12.0],
        [imageView.bottomAnchor constraintEqualToAnchor:stage.bottomAnchor constant:-12.0],

        [caption.topAnchor constraintEqualToAnchor:stage.bottomAnchor constant:8.0],
        [caption.leadingAnchor constraintEqualToAnchor:safe.leadingAnchor constant:16.0],
        [caption.trailingAnchor constraintEqualToAnchor:safe.trailingAnchor constant:-16.0],

        [actions.topAnchor constraintEqualToAnchor:caption.bottomAnchor constant:12.0],
        [actions.leadingAnchor constraintEqualToAnchor:safe.leadingAnchor constant:16.0],
        [actions.trailingAnchor constraintEqualToAnchor:safe.trailingAnchor constant:-16.0],
        [actions.heightAnchor constraintEqualToConstant:50.0],
        [actions.bottomAnchor constraintEqualToAnchor:safe.bottomAnchor constant:-16.0],
    ]];
}

- (UIButton *)axs_cutlift_buttonWithTitle:(NSString *)title selector:(SEL)selector {
    UIButton *button = [UIButton buttonWithType:UIButtonTypeSystem];
    [button setTitle:title forState:UIControlStateNormal];
    button.titleLabel.font = [UIFont systemFontOfSize:16.0 weight:UIFontWeightSemibold];
    button.backgroundColor = [UIColor secondarySystemBackgroundColor];
    button.layer.cornerRadius = 12.0;
    button.layer.cornerCurve = kCACornerCurveContinuous;
    [button addTarget:self action:selector forControlEvents:UIControlEventTouchUpInside];
    return button;
}

- (void)axs_cutlift_copyTapped:(UIButton *)sender {
    UIPasteboard *pasteboard = [UIPasteboard generalPasteboard];
    pasteboard.image = self.cutoutImage;
    UIImpactFeedbackGenerator *feedback =
        [[UIImpactFeedbackGenerator alloc] initWithStyle:UIImpactFeedbackStyleLight];
    [feedback impactOccurred];
    [self axs_cutlift_flashMessage:@"已拷贝到剪贴板"];
}

- (void)axs_cutlift_shareTapped:(UIButton *)sender {
    UIActivityViewController *controller =
        [[UIActivityViewController alloc] initWithActivityItems:@[ self.cutoutImage ]
                                         applicationActivities:nil];
    UIPopoverPresentationController *popover = controller.popoverPresentationController;
    if (popover) {
        popover.sourceView = sender;
        popover.sourceRect = sender.bounds;
    }
    if (@available(iOS 15.0, *)) {
        UISheetPresentationController *sheet = controller.sheetPresentationController;
        sheet.prefersGrabberVisible = NO;
    }
    [self presentViewController:controller animated:YES completion:nil];
}

- (void)axs_cutlift_closeTapped:(UIButton *)sender {
    [self dismissViewControllerAnimated:YES completion:nil];
}

- (void)axs_cutlift_flashMessage:(NSString *)message {
    UILabel *toast = [[UILabel alloc] initWithFrame:CGRectZero];
    toast.translatesAutoresizingMaskIntoConstraints = NO;
    toast.text = message;
    toast.font = [UIFont systemFontOfSize:14.0 weight:UIFontWeightMedium];
    toast.textColor = [UIColor whiteColor];
    toast.textAlignment = NSTextAlignmentCenter;
    toast.backgroundColor = [[UIColor blackColor] colorWithAlphaComponent:0.78];
    toast.layer.cornerRadius = 10.0;
    toast.layer.cornerCurve = kCACornerCurveContinuous;
    toast.layer.masksToBounds = YES;
    toast.alpha = 0.0;
    [self.view addSubview:toast];
    [NSLayoutConstraint activateConstraints:@[
        [toast.centerXAnchor constraintEqualToAnchor:self.view.centerXAnchor],
        [toast.bottomAnchor constraintEqualToAnchor:self.view.safeAreaLayoutGuide.bottomAnchor
                                          constant:-90.0],
        [toast.heightAnchor constraintEqualToConstant:34.0],
        [toast.widthAnchor constraintEqualToConstant:170.0],
    ]];
    [UIView animateWithDuration:0.18
                     animations:^{
                         toast.alpha = 1.0;
                     }
                     completion:^(BOOL finished) {
                         [UIView animateWithDuration:0.25
                                              delay:1.1
                                            options:UIViewAnimationOptionBeginFromCurrentState
                                         animations:^{
                                             toast.alpha = 0.0;
                                         }
                                         completion:^(BOOL done) {
                                             [toast removeFromSuperview];
                                         }];
                     }];
}

@end
