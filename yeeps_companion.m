// yeeps_companion.m
// Yeeps Companion — iOS UIKit overlay dylib
// Inject via eSign or similar iOS injection tool

#import <UIKit/UIKit.h>
#import <objc/runtime.h>

@interface YeepsOverlayWindow : UIWindow
@end

@interface YeepsButton : UIButton
+ (instancetype)buttonWithTitle:(NSString *)title color:(UIColor *)color;
@end

@interface YeepsViewController : UIViewController
@property (nonatomic, strong) UIView *panel;
@property (nonatomic, strong) UIButton *toggleBtn;
@property (nonatomic) BOOL isPanelVisible;
@end

__attribute__((constructor))
static void yeeps_init(void) {
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.5 * NSEC_PER_SEC)),
                   dispatch_get_main_queue(), ^{
        YeepsOverlayWindow *win = [[YeepsOverlayWindow alloc]
                                    initWithFrame:[UIScreen mainScreen].bounds];
        win.windowLevel = UIWindowLevelAlert + 100;
        win.backgroundColor = [UIColor clearColor];
        win.userInteractionEnabled = YES;
        YeepsViewController *vc = [YeepsViewController new];
        win.rootViewController = vc;
        [win makeKeyAndVisible];
        id appDelegate = [UIApplication sharedApplication].delegate;
        objc_setAssociatedObject(appDelegate, "yeepsWindow", win,
                                 OBJC_ASSOCIATION_RETAIN_NONATOMIC);
        NSLog(@"[YeepsCompanion] Injected into: %@",
              [[NSBundle mainBundle] bundleIdentifier]);
    });
}

@implementation YeepsOverlayWindow
- (BOOL)pointInside:(CGPoint)point withEvent:(UIEvent *)event {
    for (UIView *v in self.rootViewController.view.subviews) {
        if (!v.hidden && CGRectContainsPoint(v.frame, point)) return YES;
    }
    return NO;
}
@end

@implementation YeepsButton
+ (instancetype)buttonWithTitle:(NSString *)title color:(UIColor *)color {
    YeepsButton *btn = [YeepsButton buttonWithType:UIButtonTypeCustom];
    [btn setTitle:title forState:UIControlStateNormal];
    [btn setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
    btn.titleLabel.font = [UIFont systemFontOfSize:14 weight:UIFontWeightSemibold];
    btn.backgroundColor = color;
    btn.layer.cornerRadius = 10;
    btn.layer.masksToBounds = YES;
    btn.layer.borderWidth = 0.5;
    btn.layer.borderColor = [UIColor colorWithWhite:1 alpha:0.25].CGColor;
    [btn addTarget:btn action:@selector(touchDown) forControlEvents:UIControlEventTouchDown];
    [btn addTarget:btn action:@selector(touchUp) forControlEvents:UIControlEventTouchUpInside|UIControlEventTouchUpOutside];
    return btn;
}
- (void)touchDown {
    [UIView animateWithDuration:0.1 animations:^{
        self.alpha = 0.6;
        self.transform = CGAffineTransformMakeScale(0.96, 0.96);
    }];
}
- (void)touchUp {
    [UIView animateWithDuration:0.15 animations:^{
        self.alpha = 1.0;
        self.transform = CGAffineTransformIdentity;
    }];
}
@end

@implementation YeepsViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    self.view.backgroundColor = [UIColor clearColor];
    self.view.userInteractionEnabled = YES;
    [self setupToggleButton];
    [self setupPanel];
}

- (void)setupToggleButton {
    _toggleBtn = [UIButton buttonWithType:UIButtonTypeCustom];
    _toggleBtn.frame = CGRectMake(20, 120, 50, 50);
    _toggleBtn.backgroundColor = [UIColor colorWithRed:0.45 green:0.15 blue:0.9 alpha:0.95];
    _toggleBtn.layer.cornerRadius = 25;
    _toggleBtn.layer.shadowColor = [UIColor colorWithRed:0.5 green:0.2 blue:1.0 alpha:1].CGColor;
    _toggleBtn.layer.shadowRadius = 10;
    _toggleBtn.layer.shadowOpacity = 0.8;
    _toggleBtn.layer.shadowOffset = CGSizeZero;
    UILabel *icon = [[UILabel alloc] initWithFrame:_toggleBtn.bounds];
    icon.text = @"✦";
    icon.textAlignment = NSTextAlignmentCenter;
    icon.font = [UIFont systemFontOfSize:22];
    icon.userInteractionEnabled = NO;
    [_toggleBtn addSubview:icon];
    [_toggleBtn addTarget:self action:@selector(togglePanel) forControlEvents:UIControlEventTouchUpInside];
    UIPanGestureRecognizer *pan = [[UIPanGestureRecognizer alloc] initWithTarget:self action:@selector(dragToggle:)];
    [_toggleBtn addGestureRecognizer:pan];
    [self.view addSubview:_toggleBtn];
}

- (void)dragToggle:(UIPanGestureRecognizer *)g {
    CGPoint t = [g translationInView:self.view];
    CGPoint center = _toggleBtn.center;
    center.x += t.x; center.y += t.y;
    CGFloat r = 25; CGSize s = self.view.bounds.size;
    center.x = MAX(r, MIN(s.width - r, center.x));
    center.y = MAX(r + 44, MIN(s.height - r - 34, center.y));
    _toggleBtn.center = center;
    [g setTranslation:CGPointZero inView:self.view];
}

- (void)setupPanel {
    CGFloat pw = 260, ph = 320;
    CGFloat sx = [UIScreen mainScreen].bounds.size.width;
    _panel = [[UIView alloc] initWithFrame:CGRectMake(sx - pw - 12, 180, pw, ph)];
    _panel.backgroundColor = [UIColor colorWithRed:0.06 green:0.06 blue:0.14 alpha:0.96];
    _panel.layer.cornerRadius = 18;
    _panel.layer.borderWidth = 0.5;
    _panel.layer.borderColor = [UIColor colorWithWhite:1 alpha:0.15].CGColor;
    _panel.layer.shadowColor = [UIColor colorWithRed:0.3 green:0.1 blue:0.7 alpha:1].CGColor;
    _panel.layer.shadowRadius = 20;
    _panel.layer.shadowOpacity = 0.5;
    _panel.layer.shadowOffset = CGSizeZero;
    _panel.hidden = YES;
    _panel.alpha = 0;
    UIPanGestureRecognizer *pan = [[UIPanGestureRecognizer alloc] initWithTarget:self action:@selector(dragPanel:)];
    [_panel addGestureRecognizer:pan];
    [self buildPanelContents];
    [self.view addSubview:_panel];
}

- (void)buildPanelContents {
    CGFloat pw = _panel.bounds.size.width;
    UILabel *title = [UILabel new];
    title.text = @"✦  YEEPS";
    title.font = [UIFont systemFontOfSize:18 weight:UIFontWeightBold];
    title.textColor = [UIColor colorWithRed:0.85 green:0.6 blue:1.0 alpha:1];
    title.frame = CGRectMake(16, 16, pw - 32, 26);
    [_panel addSubview:title];
    UILabel *sub = [UILabel new];
    sub.text = @"companion overlay";
    sub.font = [UIFont monospacedSystemFontOfSize:10 weight:UIFontWeightRegular];
    sub.textColor = [UIColor colorWithWhite:0.55 alpha:1];
    sub.frame = CGRectMake(18, 42, pw - 32, 14);
    [_panel addSubview:sub];
    UIView *div = [[UIView alloc] initWithFrame:CGRectMake(16, 62, pw - 32, 0.5)];
    div.backgroundColor = [UIColor colorWithWhite:1 alpha:0.12];
    [_panel addSubview:div];
    [self addCard:@"STATUS" value:@"● Active" color:[UIColor colorWithRed:0.2 green:1.0 blue:0.5 alpha:1] y:74];
    [self addCard:@"VERSION" value:@"1.0.0" color:[UIColor colorWithWhite:0.9 alpha:1] y:130];
    NSArray *btnTitles = @[@"Reload", @"Respawn", @"Screenshot", @"Close"];
    NSArray *btnColors = @[
        [UIColor colorWithRed:0.35 green:0.1 blue:0.8 alpha:0.9],
        [UIColor colorWithRed:0.1 green:0.5 blue:0.3 alpha:0.9],
        [UIColor colorWithRed:0.1 green:0.35 blue:0.7 alpha:0.9],
        [UIColor colorWithRed:0.5 green:0.1 blue:0.15 alpha:0.9],
    ];
    NSArray *btnActions = @[
        NSStringFromSelector(@selector(doReload)),
        NSStringFromSelector(@selector(doRespawn)),
        NSStringFromSelector(@selector(doScreenshot)),
        NSStringFromSelector(@selector(doClose)),
    ];
    CGFloat bw = (pw - 44) / 2;
    for (int i = 0; i < 4; i++) {
        CGFloat bx = 16 + (i % 2) * (bw + 12);
        CGFloat by = 196 + (i / 2) * 52;
        YeepsButton *btn = [YeepsButton buttonWithTitle:btnTitles[i] color:btnColors[i]];
        btn.frame = CGRectMake(bx, by, bw, 40);
        [btn addTarget:self action:NSSelectorFromString(btnActions[i]) forControlEvents:UIControlEventTouchUpInside];
        [_panel addSubview:btn];
    }
}

- (void)addCard:(NSString *)label value:(NSString *)value color:(UIColor *)vc y:(CGFloat)y {
    CGFloat pw = _panel.bounds.size.width;
    UIView *card = [[UIView alloc] initWithFrame:CGRectMake(12, y, pw - 24, 48)];
    card.backgroundColor = [UIColor colorWithWhite:1 alpha:0.05];
    card.layer.cornerRadius = 10;
    card.layer.borderWidth = 0.5;
    card.layer.borderColor = [UIColor colorWithWhite:1 alpha:0.1].CGColor;
    [_panel addSubview:card];
    UILabel *lbl = [UILabel new];
    lbl.text = label;
    lbl.font = [UIFont monospacedSystemFontOfSize:9 weight:UIFontWeightMedium];
    lbl.textColor = [UIColor colorWithWhite:0.45 alpha:1];
    lbl.frame = CGRectMake(12, 6, pw - 48, 14);
    [card addSubview:lbl];
    UILabel *val = [UILabel new];
    val.text = value;
    val.font = [UIFont systemFontOfSize:14 weight:UIFontWeightSemibold];
    val.textColor = vc;
    val.frame = CGRectMake(12, 22, pw - 48, 18);
    [card addSubview:val];
}

- (void)dragPanel:(UIPanGestureRecognizer *)g {
    CGPoint t = [g translationInView:self.view];
    _panel.center = CGPointMake(_panel.center.x + t.x, _panel.center.y + t.y);
    [g setTranslation:CGPointZero inView:self.view];
}

- (void)togglePanel {
    _isPanelVisible = !_isPanelVisible;
    if (_isPanelVisible) {
        _panel.hidden = NO;
        _panel.transform = CGAffineTransformMakeScale(0.85, 0.85);
        [UIView animateWithDuration:0.3 delay:0 usingSpringWithDamping:0.7 initialSpringVelocity:0.5 options:0 animations:^{
            self.panel.alpha = 1;
            self.panel.transform = CGAffineTransformIdentity;
        } completion:nil];
    } else {
        [UIView animateWithDuration:0.2 animations:^{
            self.panel.alpha = 0;
            self.panel.transform = CGAffineTransformMakeScale(0.9, 0.9);
        } completion:^(BOOL done) {
            self.panel.hidden = YES;
            self.panel.transform = CGAffineTransformIdentity;
        }];
    }
}

- (void)doReload     { [self flashPanel]; NSLog(@"[YeepsCompanion] Reload"); }
- (void)doRespawn    { [self flashPanel]; NSLog(@"[YeepsCompanion] Respawn"); }
- (void)doScreenshot {
    UIGraphicsBeginImageContextWithOptions([UIScreen mainScreen].bounds.size, NO, 0);
    [[UIApplication sharedApplication].keyWindow drawViewHierarchyInRect:[UIScreen mainScreen].bounds afterScreenUpdates:YES];
    UIImage *img = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();
    UIImageWriteToSavedPhotosAlbum(img, nil, nil, nil);
}
- (void)doClose { [self togglePanel]; }
- (void)flashPanel {
    [UIView animateWithDuration:0.1 animations:^{ self.panel.alpha = 0.4; } completion:^(BOOL d) {
        [UIView animateWithDuration:0.15 animations:^{ self.panel.alpha = 1.0; }];
    }];
}
- (BOOL)prefersStatusBarHidden { return YES; }
@end
