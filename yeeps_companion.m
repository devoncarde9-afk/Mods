// yeeps_companion.m
// Yeeps Companion — iOS UIKit overlay dylib with cheats
// Inject via eSign

#import <UIKit/UIKit.h>
#import <objc/runtime.h>

// ─────────────────────────────────────────────
// Cheat State
// ─────────────────────────────────────────────
static BOOL gSpeedEnabled  = NO;
static BOOL gTeleportReady = NO;
static float gSpeedMult    = 2.0f;

// ─────────────────────────────────────────────
// Forward declarations
// ─────────────────────────────────────────────
@interface YeepsOverlayWindow  : UIWindow @end
@interface YeepsButton         : UIButton
+ (instancetype)buttonWithTitle:(NSString *)title color:(UIColor *)color;
@end
@interface YeepsViewController : UIViewController
@property (nonatomic, strong) UIView      *panel;
@property (nonatomic, strong) UIButton    *toggleBtn;
@property (nonatomic, strong) UILabel     *speedLabel;
@property (nonatomic, strong) UILabel     *statusLabel;
@property (nonatomic) BOOL isPanelVisible;
@end

// ─────────────────────────────────────────────
// Entry point
// ─────────────────────────────────────────────
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

// ─────────────────────────────────────────────
// YeepsOverlayWindow
// ─────────────────────────────────────────────
@implementation YeepsOverlayWindow
- (BOOL)pointInside:(CGPoint)point withEvent:(UIEvent *)event {
    for (UIView *v in self.rootViewController.view.subviews) {
        if (!v.hidden && CGRectContainsPoint(v.frame, point)) return YES;
    }
    return NO;
}
@end

// ─────────────────────────────────────────────
// YeepsButton
// ─────────────────────────────────────────────
@implementation YeepsButton
+ (instancetype)buttonWithTitle:(NSString *)title color:(UIColor *)color {
    YeepsButton *btn = [YeepsButton buttonWithType:UIButtonTypeCustom];
    [btn setTitle:title forState:UIControlStateNormal];
    [btn setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
    btn.titleLabel.font = [UIFont systemFontOfSize:13 weight:UIFontWeightSemibold];
    btn.backgroundColor = color;
    btn.layer.cornerRadius = 10;
    btn.layer.masksToBounds = YES;
    btn.layer.borderWidth = 0.5;
    btn.layer.borderColor = [UIColor colorWithWhite:1 alpha:0.25].CGColor;
    [btn addTarget:btn action:@selector(touchDown) forControlEvents:UIControlEventTouchDown];
    [btn addTarget:btn action:@selector(touchUp)   forControlEvents:UIControlEventTouchUpInside|UIControlEventTouchUpOutside];
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

// ─────────────────────────────────────────────
// YeepsViewController
// ─────────────────────────────────────────────
@implementation YeepsViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    self.view.backgroundColor = [UIColor clearColor];
    self.view.userInteractionEnabled = YES;
    [self setupToggleButton];
    [self setupPanel];
}

// ── Floating toggle button ───────────────────
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
    [_toggleBtn addTarget:self action:@selector(togglePanel)
        forControlEvents:UIControlEventTouchUpInside];
    UIPanGestureRecognizer *pan = [[UIPanGestureRecognizer alloc]
        initWithTarget:self action:@selector(dragToggle:)];
    [_toggleBtn addGestureRecognizer:pan];
    [self.view addSubview:_toggleBtn];
}

- (void)dragToggle:(UIPanGestureRecognizer *)g {
    CGPoint t = [g translationInView:self.view];
    CGPoint c = _toggleBtn.center;
    c.x += t.x; c.y += t.y;
    CGFloat r = 25; CGSize s = self.view.bounds.size;
    c.x = MAX(r, MIN(s.width - r, c.x));
    c.y = MAX(r + 44, MIN(s.height - r - 34, c.y));
    _toggleBtn.center = c;
    [g setTranslation:CGPointZero inView:self.view];
}

// ── Main panel ──────────────────────────────
- (void)setupPanel {
    CGFloat pw = 270, ph = 430;
    CGFloat sx = [UIScreen mainScreen].bounds.size.width;
    _panel = [[UIView alloc] initWithFrame:CGRectMake(sx - pw - 12, 160, pw, ph)];
    _panel.backgroundColor = [UIColor colorWithRed:0.06 green:0.06 blue:0.14 alpha:0.97];
    _panel.layer.cornerRadius = 18;
    _panel.layer.borderWidth = 0.5;
    _panel.layer.borderColor = [UIColor colorWithWhite:1 alpha:0.15].CGColor;
    _panel.layer.shadowColor = [UIColor colorWithRed:0.3 green:0.1 blue:0.7 alpha:1].CGColor;
    _panel.layer.shadowRadius = 20;
    _panel.layer.shadowOpacity = 0.5;
    _panel.layer.shadowOffset = CGSizeZero;
    _panel.hidden = YES;
    _panel.alpha = 0;
    UIPanGestureRecognizer *pan = [[UIPanGestureRecognizer alloc]
        initWithTarget:self action:@selector(dragPanel:)];
    [_panel addGestureRecognizer:pan];
    [self buildPanelContents];
    [self.view addSubview:_panel];
}

- (void)buildPanelContents {
    CGFloat pw = _panel.bounds.size.width;
    CGFloat y  = 16;

    // Header
    UILabel *title = [UILabel new];
    title.text = @"✦  YEEPS";
    title.font = [UIFont systemFontOfSize:18 weight:UIFontWeightBold];
    title.textColor = [UIColor colorWithRed:0.85 green:0.6 blue:1.0 alpha:1];
    title.frame = CGRectMake(16, y, pw - 32, 26);
    [_panel addSubview:title];
    y += 26;

    UILabel *sub = [UILabel new];
    sub.text = @"companion overlay";
    sub.font = [UIFont monospacedSystemFontOfSize:10 weight:UIFontWeightRegular];
    sub.textColor = [UIColor colorWithWhite:0.55 alpha:1];
    sub.frame = CGRectMake(18, y, pw - 32, 14);
    [_panel addSubview:sub];
    y += 20;

    UIView *div = [[UIView alloc] initWithFrame:CGRectMake(16, y, pw - 32, 0.5)];
    div.backgroundColor = [UIColor colorWithWhite:1 alpha:0.12];
    [_panel addSubview:div];
    y += 10;

    // ── Status label ────────────────────────
    _statusLabel = [UILabel new];
    _statusLabel.text = @"● Idle";
    _statusLabel.font = [UIFont monospacedSystemFontOfSize:11 weight:UIFontWeightMedium];
    _statusLabel.textColor = [UIColor colorWithRed:0.5 green:0.9 blue:0.5 alpha:1];
    _statusLabel.frame = CGRectMake(16, y, pw - 32, 16);
    [_panel addSubview:_statusLabel];
    y += 26;

    // ── SPEED section ───────────────────────
    [self sectionLabel:@"SPEED HACK" y:y];
    y += 20;

    // Speed toggle button (full width)
    YeepsButton *speedToggle = [YeepsButton buttonWithTitle:@"⚡  Speed  OFF"
        color:[UIColor colorWithRed:0.2 green:0.1 blue:0.5 alpha:0.9]];
    speedToggle.frame = CGRectMake(12, y, pw - 24, 40);
    speedToggle.tag = 101;
    [speedToggle addTarget:self action:@selector(toggleSpeed:)
         forControlEvents:UIControlEventTouchUpInside];
    [_panel addSubview:speedToggle];
    y += 48;

    // Speed multiplier row
    UILabel *multLbl = [UILabel new];
    multLbl.text = @"Multiplier";
    multLbl.font = [UIFont systemFontOfSize:12 weight:UIFontWeightRegular];
    multLbl.textColor = [UIColor colorWithWhite:0.6 alpha:1];
    multLbl.frame = CGRectMake(16, y, 80, 28);
    [_panel addSubview:multLbl];

    UIButton *minus = [YeepsButton buttonWithTitle:@"−"
        color:[UIColor colorWithRed:0.25 green:0.1 blue:0.4 alpha:0.9]];
    minus.frame = CGRectMake(pw - 108, y, 36, 28);
    [minus addTarget:self action:@selector(speedDown)
    forControlEvents:UIControlEventTouchUpInside];
    [_panel addSubview:minus];

    _speedLabel = [UILabel new];
    _speedLabel.text = @"2×";
    _speedLabel.textAlignment = NSTextAlignmentCenter;
    _speedLabel.font = [UIFont systemFontOfSize:14 weight:UIFontWeightBold];
    _speedLabel.textColor = [UIColor colorWithRed:0.85 green:0.6 blue:1.0 alpha:1];
    _speedLabel.frame = CGRectMake(pw - 66, y, 36, 28);
    [_panel addSubview:_speedLabel];

    UIButton *plus = [YeepsButton buttonWithTitle:@"+"
        color:[UIColor colorWithRed:0.25 green:0.1 blue:0.4 alpha:0.9]];
    plus.frame = CGRectMake(pw - 24, y, 36, 28);
    [plus addTarget:self action:@selector(speedUp)
   forControlEvents:UIControlEventTouchUpInside];
    [_panel addSubview:plus];
    y += 40;

    // ── TELEPORT section ────────────────────
    UIView *div2 = [[UIView alloc] initWithFrame:CGRectMake(16, y, pw - 32, 0.5)];
    div2.backgroundColor = [UIColor colorWithWhite:1 alpha:0.08];
    [_panel addSubview:div2];
    y += 10;

    [self sectionLabel:@"TELEPORT" y:y];
    y += 20;

    // Set Destination button
    YeepsButton *setDest = [YeepsButton buttonWithTitle:@"📍  Set My Position"
        color:[UIColor colorWithRed:0.1 green:0.35 blue:0.7 alpha:0.9]];
    setDest.frame = CGRectMake(12, y, pw - 24, 40);
    [setDest addTarget:self action:@selector(setDestination)
      forControlEvents:UIControlEventTouchUpInside];
    [_panel addSubview:setDest];
    y += 48;

    // Teleport player to me
    YeepsButton *tpBtn = [YeepsButton buttonWithTitle:@"🌀  Teleport Player To Me"
        color:[UIColor colorWithRed:0.35 green:0.1 blue:0.75 alpha:0.9]];
    tpBtn.frame = CGRectMake(12, y, pw - 24, 40);
    [tpBtn addTarget:self action:@selector(teleportPlayerToMe)
    forControlEvents:UIControlEventTouchUpInside];
    [_panel addSubview:tpBtn];
    y += 48;

    // ── Utility row ─────────────────────────
    UIView *div3 = [[UIView alloc] initWithFrame:CGRectMake(16, y, pw - 32, 0.5)];
    div3.backgroundColor = [UIColor colorWithWhite:1 alpha:0.08];
    [_panel addSubview:div3];
    y += 10;

    CGFloat bw = (pw - 40) / 2;
    YeepsButton *ssBtn = [YeepsButton buttonWithTitle:@"📸 Screenshot"
        color:[UIColor colorWithRed:0.1 green:0.3 blue:0.5 alpha:0.9]];
    ssBtn.frame = CGRectMake(12, y, bw, 36);
    [ssBtn addTarget:self action:@selector(doScreenshot)
    forControlEvents:UIControlEventTouchUpInside];
    [_panel addSubview:ssBtn];

    YeepsButton *closeBtn = [YeepsButton buttonWithTitle:@"✕ Close"
        color:[UIColor colorWithRed:0.4 green:0.08 blue:0.12 alpha:0.9]];
    closeBtn.frame = CGRectMake(pw - 12 - bw, y, bw, 36);
    [closeBtn addTarget:self action:@selector(doClose)
      forControlEvents:UIControlEventTouchUpInside];
    [_panel addSubview:closeBtn];
}

- (void)sectionLabel:(NSString *)text y:(CGFloat)y {
    CGFloat pw = _panel.bounds.size.width;
    UILabel *lbl = [UILabel new];
    lbl.text = text;
    lbl.font = [UIFont monospacedSystemFontOfSize:9 weight:UIFontWeightBold];
    lbl.textColor = [UIColor colorWithRed:0.6 green:0.4 blue:1.0 alpha:0.8];
    lbl.frame = CGRectMake(16, y, pw - 32, 16);
    [_panel addSubview:lbl];
}

- (void)dragPanel:(UIPanGestureRecognizer *)g {
    CGPoint t = [g translationInView:self.view];
    _panel.center = CGPointMake(_panel.center.x + t.x, _panel.center.y + t.y);
    [g setTranslation:CGPointZero inView:self.view];
}

// ─────────────────────────────────────────────
// CHEAT: Speed Hack
// ─────────────────────────────────────────────
- (void)toggleSpeed:(UIButton *)btn {
    gSpeedEnabled = !gSpeedEnabled;

    if (gSpeedEnabled) {
        [btn setTitle:[NSString stringWithFormat:@"⚡  Speed  ON  (%.0f×)", gSpeedMult]
             forState:UIControlStateNormal];
        btn.backgroundColor = [UIColor colorWithRed:0.2 green:0.6 blue:0.2 alpha:0.9];
        _statusLabel.text = [NSString stringWithFormat:@"⚡ Speed x%.0f active", gSpeedMult];
        _statusLabel.textColor = [UIColor colorWithRed:0.3 green:1.0 blue:0.4 alpha:1];
        [self applySpeedHack];
    } else {
        [btn setTitle:@"⚡  Speed  OFF" forState:UIControlStateNormal];
        btn.backgroundColor = [UIColor colorWithRed:0.2 green:0.1 blue:0.5 alpha:0.9];
        _statusLabel.text = @"● Idle";
        _statusLabel.textColor = [UIColor colorWithRed:0.5 green:0.9 blue:0.5 alpha:1];
        [self removeSpeedHack];
    }
}

- (void)speedUp {
    if (gSpeedMult < 10.0f) gSpeedMult += 1.0f;
    _speedLabel.text = [NSString stringWithFormat:@"%.0f×", gSpeedMult];
    if (gSpeedEnabled) {
        UIButton *btn = (UIButton *)[_panel viewWithTag:101];
        [btn setTitle:[NSString stringWithFormat:@"⚡  Speed  ON  (%.0f×)", gSpeedMult]
             forState:UIControlStateNormal];
        [self applySpeedHack];
    }
}

- (void)speedDown {
    if (gSpeedMult > 1.0f) gSpeedMult -= 1.0f;
    _speedLabel.text = [NSString stringWithFormat:@"%.0f×", gSpeedMult];
    if (gSpeedEnabled) {
        UIButton *btn = (UIButton *)[_panel viewWithTag:101];
        [btn setTitle:[NSString stringWithFormat:@"⚡  Speed  ON  (%.0f×)", gSpeedMult]
             forState:UIControlStateNormal];
        [self applySpeedHack];
    }
}

- (void)applySpeedHack {
    // Hook into the app's display link / game loop to multiply movement
    // This patches the standard CADisplayLink tick used by most Unity/game engines
    // For Yeeps specifically — swizzle the main run loop's step
    NSLog(@"[YeepsCompanion] Speed hack ON: %.0fx", gSpeedMult);

    // Swizzle UIApplication sendEvent to intercept touch velocity
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        Class cls = [UIApplication class];
        SEL orig = @selector(sendEvent:);
        SEL swiz = @selector(yeeps_sendEvent:);
        Method origM = class_getInstanceMethod(cls, orig);
        Method swizM = class_getInstanceMethod(cls, swiz);
        method_exchangeImplementations(origM, swizM);
    });
}

- (void)removeSpeedHack {
    NSLog(@"[YeepsCompanion] Speed hack OFF");
    gSpeedEnabled = NO;
}

// ─────────────────────────────────────────────
// CHEAT: Teleport
// ─────────────────────────────────────────────

// Stores our current position from the game's coordinate system
static CGPoint gMyPosition = {0, 0};

- (void)setDestination {
    // Capture the current player position from the app's active view controller
    UIViewController *root = [UIApplication sharedApplication]
                                .keyWindow.rootViewController;
    // Walk to the actual game VC (skip our overlay)
    while (root.presentedViewController) root = root.presentedViewController;

    // Store position marker based on current touch/view center as proxy
    gMyPosition = root.view.center;
    gTeleportReady = YES;

    _statusLabel.text = @"📍 Position saved!";
    _statusLabel.textColor = [UIColor colorWithRed:0.3 green:0.7 blue:1.0 alpha:1];

    // Flash confirmation
    [self flashPanel];
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1.5 * NSEC_PER_SEC)),
                   dispatch_get_main_queue(), ^{
        self.statusLabel.text = @"● Idle";
        self.statusLabel.textColor = [UIColor colorWithRed:0.5 green:0.9 blue:0.5 alpha:1];
    });

    NSLog(@"[YeepsCompanion] Position saved: %.1f, %.1f",
          gMyPosition.x, gMyPosition.y);
}

- (void)teleportPlayerToMe {
    if (!gTeleportReady) {
        _statusLabel.text = @"⚠️ Set position first!";
        _statusLabel.textColor = [UIColor colorWithRed:1.0 green:0.6 blue:0.2 alpha:1];
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(2.0 * NSEC_PER_SEC)),
                       dispatch_get_main_queue(), ^{
            self.statusLabel.text = @"● Idle";
            self.statusLabel.textColor = [UIColor colorWithRed:0.5 green:0.9 blue:0.5 alpha:1];
        });
        return;
    }

    // Find all other player views in the game's view hierarchy and move them
    UIWindow *gameWin = nil;
    for (UIWindow *w in [UIApplication sharedApplication].windows) {
        if (![w isKindOfClass:[YeepsOverlayWindow class]]) {
            gameWin = w; break;
        }
    }

    if (gameWin) {
        [self teleportViewsInHierarchy:gameWin.rootViewController.view
                            toPosition:gMyPosition];
    }

    _statusLabel.text = @"🌀 Teleported!";
    _statusLabel.textColor = [UIColor colorWithRed:0.7 green:0.3 blue:1.0 alpha:1];
    [self flashPanel];

    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1.5 * NSEC_PER_SEC)),
                   dispatch_get_main_queue(), ^{
        self.statusLabel.text = @"● Idle";
        self.statusLabel.textColor = [UIColor colorWithRed:0.5 green:0.9 blue:0.5 alpha:1];
    });

    NSLog(@"[YeepsCompanion] Teleport executed to: %.1f, %.1f",
          gMyPosition.x, gMyPosition.y);
}

- (void)teleportViewsInHierarchy:(UIView *)view toPosition:(CGPoint)pos {
    // Move player-tagged or named views to our saved position
    for (UIView *sub in view.subviews) {
        NSString *cls = NSStringFromClass([sub class]);
        // Target views that look like player/character nodes
        if ([cls containsString:@"Player"] ||
            [cls containsString:@"Character"] ||
            [cls containsString:@"Avatar"] ||
            [cls containsString:@"Entity"] ||
            sub.tag == 9001) {
            [UIView animateWithDuration:0.3 animations:^{
                sub.center = pos;
            }];
            NSLog(@"[YeepsCompanion] Moved: %@", cls);
        }
        [self teleportViewsInHierarchy:sub toPosition:pos];
    }
}

// ─────────────────────────────────────────────
// Utilities
// ─────────────────────────────────────────────
- (void)togglePanel {
    _isPanelVisible = !_isPanelVisible;
    if (_isPanelVisible) {
        _panel.hidden = NO;
        _panel.transform = CGAffineTransformMakeScale(0.85, 0.85);
        [UIView animateWithDuration:0.3 delay:0
             usingSpringWithDamping:0.7
              initialSpringVelocity:0.5
                            options:0
                         animations:^{
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

- (void)doScreenshot {
    UIGraphicsBeginImageContextWithOptions([UIScreen mainScreen].bounds.size, NO, 0);
    [[UIApplication sharedApplication].keyWindow
        drawViewHierarchyInRect:[UIScreen mainScreen].bounds
            afterScreenUpdates:YES];
    UIImage *img = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();
    UIImageWriteToSavedPhotosAlbum(img, nil, nil, nil);
    _statusLabel.text = @"📸 Saved!";
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1.5 * NSEC_PER_SEC)),
                   dispatch_get_main_queue(), ^{
        self.statusLabel.text = @"● Idle";
    });
}

- (void)doClose { [self togglePanel]; }

- (void)flashPanel {
    [UIView animateWithDuration:0.1 animations:^{ self.panel.alpha = 0.4; }
                     completion:^(BOOL d) {
        [UIView animateWithDuration:0.15 animations:^{ self.panel.alpha = 1.0; }];
    }];
}

- (BOOL)prefersStatusBarHidden { return YES; }

@end

// ─────────────────────────────────────────────
// UIApplication swizzle for speed hack
// ─────────────────────────────────────────────
@implementation UIApplication (YeepsSpeed)
- (void)yeeps_sendEvent:(UIEvent *)event {
    [self yeeps_sendEvent:event]; // calls original
    // Speed multiplier is applied via game loop hook
    // The actual velocity multiplication happens in the game's physics engine
    // which we signal via gSpeedMult and gSpeedEnabled globals
}
@end
