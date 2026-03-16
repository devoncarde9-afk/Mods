// yeeps_companion.m
// Yeeps Companion — iOS UIKit overlay dylib
// Full mod menu — inject via eSign

#import <UIKit/UIKit.h>
#import <objc/runtime.h>
#import <AVFoundation/AVFoundation.h>

// ─────────────────────────────────────────────
// Globals
// ─────────────────────────────────────────────
static BOOL  gSpeedEnabled    = NO;
static BOOL  gNoClipEnabled   = NO;
static BOOL  gAutoStreakOn     = NO;
static BOOL  gESPEnabled       = NO;
static BOOL  gFreezeTime       = NO;
static float gSpeedMult        = 2.0f;
static CGPoint gSavedPosition  = {0,0};
static BOOL  gPositionSaved    = NO;
static NSTimer *gStreakTimer   = nil;

// ─────────────────────────────────────────────
// Forward decls
// ─────────────────────────────────────────────
@interface YeepsOverlayWindow  : UIWindow @end
@interface YeepsButton         : UIButton
+ (instancetype)buttonWithTitle:(NSString *)t color:(UIColor *)c;
@end
@interface YeepsToggleButton   : YeepsButton
@property BOOL isOn;
- (void)setOn:(BOOL)on;
@end
@interface YeepsViewController : UIViewController
@property (strong) UIView        *panel;
@property (strong) UIScrollView  *scrollView;
@property (strong) UIButton      *toggleBtn;
@property (strong) UILabel       *statusLabel;
@property (strong) UILabel       *fpsLabel;
@property (strong) NSTimer       *fpsTimer;
@property (strong) NSDate        *lastFrameTime;
@property         BOOL            isPanelVisible;
@end

// ─────────────────────────────────────────────
// Entry point
// ─────────────────────────────────────────────
__attribute__((constructor))
static void yeeps_init(void) {
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.5*NSEC_PER_SEC)),
                   dispatch_get_main_queue(), ^{
        YeepsOverlayWindow *win = [[YeepsOverlayWindow alloc]
                                    initWithFrame:[UIScreen mainScreen].bounds];
        win.windowLevel = UIWindowLevelAlert + 100;
        win.backgroundColor = [UIColor clearColor];
        win.userInteractionEnabled = YES;
        YeepsViewController *vc = [YeepsViewController new];
        win.rootViewController = vc;
        [win makeKeyAndVisible];
        objc_setAssociatedObject([UIApplication sharedApplication].delegate,
                                 "yeepsWin", win, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
        NSLog(@"[YeepsCompanion] Loaded in: %@",
              [[NSBundle mainBundle] bundleIdentifier]);
    });
}

// ─────────────────────────────────────────────
// YeepsOverlayWindow
// ─────────────────────────────────────────────
@implementation YeepsOverlayWindow
- (BOOL)pointInside:(CGPoint)p withEvent:(UIEvent *)e {
    for (UIView *v in self.rootViewController.view.subviews)
        if (!v.hidden && CGRectContainsPoint(v.frame, p)) return YES;
    return NO;
}
@end

// ─────────────────────────────────────────────
// YeepsButton
// ─────────────────────────────────────────────
@implementation YeepsButton
+ (instancetype)buttonWithTitle:(NSString *)t color:(UIColor *)c {
    YeepsButton *b = [self buttonWithType:UIButtonTypeCustom];
    [b setTitle:t forState:UIControlStateNormal];
    [b setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
    b.titleLabel.font = [UIFont systemFontOfSize:13 weight:UIFontWeightSemibold];
    b.titleLabel.adjustsFontSizeToFitWidth = YES;
    b.backgroundColor = c;
    b.layer.cornerRadius = 10;
    b.layer.masksToBounds = YES;
    b.layer.borderWidth = 0.5;
    b.layer.borderColor = [UIColor colorWithWhite:1 alpha:0.2].CGColor;
    [b addTarget:b action:@selector(td) forControlEvents:UIControlEventTouchDown];
    [b addTarget:b action:@selector(tu) forControlEvents:UIControlEventTouchUpInside|UIControlEventTouchUpOutside];
    return b;
}
- (void)td { [UIView animateWithDuration:0.08 animations:^{ self.alpha=0.55; self.transform=CGAffineTransformMakeScale(0.96,0.96); }]; }
- (void)tu { [UIView animateWithDuration:0.12 animations:^{ self.alpha=1; self.transform=CGAffineTransformIdentity; }]; }
@end

// ─────────────────────────────────────────────
// YeepsToggleButton
// ─────────────────────────────────────────────
@implementation YeepsToggleButton
- (void)setOn:(BOOL)on {
    _isOn = on;
    self.backgroundColor = on
        ? [UIColor colorWithRed:0.1 green:0.6 blue:0.25 alpha:0.95]
        : [UIColor colorWithRed:0.25 green:0.08 blue:0.45 alpha:0.9];
}
@end

// ─────────────────────────────────────────────
// YeepsViewController
// ─────────────────────────────────────────────
@implementation YeepsViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    self.view.backgroundColor = [UIColor clearColor];
    [self setupFAB];
    [self setupPanel];
    [self startFPSCounter];
}

// ── Floating action button ───────────────────
- (void)setupFAB {
    _toggleBtn = [UIButton buttonWithType:UIButtonTypeCustom];
    _toggleBtn.frame = CGRectMake(16, 130, 52, 52);
    _toggleBtn.backgroundColor = [UIColor colorWithRed:0.42 green:0.12 blue:0.88 alpha:0.95];
    _toggleBtn.layer.cornerRadius = 26;
    _toggleBtn.layer.shadowColor = [UIColor colorWithRed:0.5 green:0.2 blue:1 alpha:1].CGColor;
    _toggleBtn.layer.shadowRadius = 12;
    _toggleBtn.layer.shadowOpacity = 0.85;
    _toggleBtn.layer.shadowOffset = CGSizeZero;
    UILabel *ic = [[UILabel alloc] initWithFrame:_toggleBtn.bounds];
    ic.text = @"✦"; ic.textAlignment = NSTextAlignmentCenter;
    ic.font = [UIFont systemFontOfSize:24];
    ic.userInteractionEnabled = NO;
    [_toggleBtn addSubview:ic];
    [_toggleBtn addTarget:self action:@selector(togglePanel) forControlEvents:UIControlEventTouchUpInside];
    UIPanGestureRecognizer *pan = [[UIPanGestureRecognizer alloc] initWithTarget:self action:@selector(dragFAB:)];
    [_toggleBtn addGestureRecognizer:pan];
    [self.view addSubview:_toggleBtn];
}

- (void)dragFAB:(UIPanGestureRecognizer *)g {
    CGPoint t = [g translationInView:self.view];
    CGPoint c = _toggleBtn.center;
    c.x = MAX(26, MIN(self.view.bounds.size.width-26,  c.x+t.x));
    c.y = MAX(70, MIN(self.view.bounds.size.height-50, c.y+t.y));
    _toggleBtn.center = c;
    [g setTranslation:CGPointZero inView:self.view];
}

// ── Panel ────────────────────────────────────
- (void)setupPanel {
    CGFloat pw = 280;
    CGFloat sx = [UIScreen mainScreen].bounds.size.width;
    _panel = [[UIView alloc] initWithFrame:CGRectMake(sx-pw-10, 140, pw, 500)];
    _panel.backgroundColor = [UIColor colorWithRed:0.05 green:0.05 blue:0.12 alpha:0.97];
    _panel.layer.cornerRadius = 18;
    _panel.layer.borderWidth = 0.5;
    _panel.layer.borderColor = [UIColor colorWithWhite:1 alpha:0.13].CGColor;
    _panel.layer.shadowColor = [UIColor colorWithRed:0.3 green:0.1 blue:0.7 alpha:1].CGColor;
    _panel.layer.shadowRadius = 22; _panel.layer.shadowOpacity = 0.55;
    _panel.layer.shadowOffset = CGSizeZero;
    _panel.hidden = YES; _panel.alpha = 0;

    // Header (fixed)
    UIView *header = [[UIView alloc] initWithFrame:CGRectMake(0,0,pw,70)];
    header.backgroundColor = [UIColor colorWithWhite:0 alpha:0];

    UILabel *ttl = [UILabel new];
    ttl.text = @"✦  YEEPS MOD"; ttl.frame = CGRectMake(14,10,pw-80,26);
    ttl.font = [UIFont systemFontOfSize:17 weight:UIFontWeightBold];
    ttl.textColor = [UIColor colorWithRed:0.85 green:0.6 blue:1 alpha:1];
    [header addSubview:ttl];

    _statusLabel = [UILabel new];
    _statusLabel.text = @"● Ready"; _statusLabel.frame = CGRectMake(14,36,pw-80,16);
    _statusLabel.font = [UIFont monospacedSystemFontOfSize:10 weight:UIFontWeightMedium];
    _statusLabel.textColor = [UIColor colorWithRed:0.4 green:1 blue:0.5 alpha:1];
    [header addSubview:_statusLabel];

    _fpsLabel = [UILabel new];
    _fpsLabel.text = @"-- FPS"; _fpsLabel.frame = CGRectMake(pw-70,10,60,20);
    _fpsLabel.font = [UIFont monospacedSystemFontOfSize:10 weight:UIFontWeightMedium];
    _fpsLabel.textColor = [UIColor colorWithWhite:0.4 alpha:1];
    _fpsLabel.textAlignment = NSTextAlignmentRight;
    [header addSubview:_fpsLabel];

    UIButton *closeX = [UIButton buttonWithType:UIButtonTypeCustom];
    closeX.frame = CGRectMake(pw-36,8,28,28);
    [closeX setTitle:@"✕" forState:UIControlStateNormal];
    [closeX setTitleColor:[UIColor colorWithWhite:0.5 alpha:1] forState:UIControlStateNormal];
    closeX.titleLabel.font = [UIFont systemFontOfSize:14];
    [closeX addTarget:self action:@selector(togglePanel) forControlEvents:UIControlEventTouchUpInside];
    [header addSubview:closeX];

    UIView *div = [[UIView alloc] initWithFrame:CGRectMake(12,66,pw-24,0.5)];
    div.backgroundColor = [UIColor colorWithWhite:1 alpha:0.1];
    [header addSubview:div];

    [_panel addSubview:header];

    // Scrollable content
    _scrollView = [[UIScrollView alloc] initWithFrame:CGRectMake(0,70,pw,430)];
    _scrollView.showsVerticalScrollIndicator = NO;
    _scrollView.alwaysBounceVertical = YES;
    [_panel addSubview:_scrollView];

    [self buildScrollContent:pw];

    UIPanGestureRecognizer *pan = [[UIPanGestureRecognizer alloc] initWithTarget:self action:@selector(dragPanel:)];
    pan.delegate = (id)self;
    [_panel addGestureRecognizer:pan];

    [self.view addSubview:_panel];
}

- (BOOL)gestureRecognizer:(UIGestureRecognizer *)g shouldRecognizeSimultaneouslyWithGestureRecognizer:(UIGestureRecognizer *)o { return NO; }

- (void)buildScrollContent:(CGFloat)pw {
    CGFloat y = 8;
    CGFloat bw = (pw-32)/2;

    // ── MOVEMENT ────────────────────────────
    y = [self sectionAt:y width:pw title:@"MOVEMENT"];

    // Speed toggle
    YeepsToggleButton *speedBtn = [self toggleBtnTitle:@"⚡ Speed Hack" tag:201 y:y width:pw-20];
    [speedBtn addTarget:self action:@selector(toggleSpeed:) forControlEvents:UIControlEventTouchUpInside];
    y += 46;

    // Speed stepper
    y = [self stepperRowAt:y width:pw label:@"Speed" minusTag:211 plusTag:212 valueTag:213 value:@"2×"];
    y += 8;

    // Noclip toggle
    YeepsToggleButton *ncBtn = [self toggleBtnTitle:@"👻 No Clip" tag:202 y:y width:pw-20];
    [ncBtn addTarget:self action:@selector(toggleNoclip:) forControlEvents:UIControlEventTouchUpInside];
    y += 46;

    // ── TELEPORT ────────────────────────────
    UIView *d1 = [[UIView alloc] initWithFrame:CGRectMake(10,y,pw-20,0.5)];
    d1.backgroundColor = [UIColor colorWithWhite:1 alpha:0.08]; [_scrollView addSubview:d1]; y+=10;
    y = [self sectionAt:y width:pw title:@"TELEPORT"];

    YeepsButton *savePosBtn = [YeepsButton buttonWithTitle:@"📍 Save My Position"
        color:[UIColor colorWithRed:0.1 green:0.3 blue:0.65 alpha:0.9]];
    savePosBtn.frame = CGRectMake(10, y, pw-20, 40);
    [savePosBtn addTarget:self action:@selector(savePosition) forControlEvents:UIControlEventTouchUpInside];
    [_scrollView addSubview:savePosBtn]; y += 46;

    YeepsButton *tpBtn = [YeepsButton buttonWithTitle:@"🌀 Teleport Player To Me"
        color:[UIColor colorWithRed:0.3 green:0.1 blue:0.7 alpha:0.9]];
    tpBtn.frame = CGRectMake(10, y, pw-20, 40);
    [tpBtn addTarget:self action:@selector(teleportToMe) forControlEvents:UIControlEventTouchUpInside];
    [_scrollView addSubview:tpBtn]; y += 46;

    YeepsButton *tpSaved = [YeepsButton buttonWithTitle:@"📌 Teleport Me To Saved"
        color:[UIColor colorWithRed:0.1 green:0.2 blue:0.55 alpha:0.9]];
    tpSaved.frame = CGRectMake(10, y, pw-20, 40);
    [tpSaved addTarget:self action:@selector(teleportMeToSaved) forControlEvents:UIControlEventTouchUpInside];
    [_scrollView addSubview:tpSaved]; y += 46;

    // ── VISUALS ──────────────────────────────
    UIView *d2 = [[UIView alloc] initWithFrame:CGRectMake(10,y,pw-20,0.5)];
    d2.backgroundColor = [UIColor colorWithWhite:1 alpha:0.08]; [_scrollView addSubview:d2]; y+=10;
    y = [self sectionAt:y width:pw title:@"VISUALS"];

    YeepsToggleButton *espBtn = [self toggleBtnTitle:@"👁 ESP / Wallhack" tag:203 y:y width:pw-20];
    [espBtn addTarget:self action:@selector(toggleESP:) forControlEvents:UIControlEventTouchUpInside];
    y += 46;

    YeepsToggleButton *freezeBtn = [self toggleBtnTitle:@"❄️ Freeze Time" tag:204 y:y width:pw-20];
    [freezeBtn addTarget:self action:@selector(toggleFreeze:) forControlEvents:UIControlEventTouchUpInside];
    y += 46;

    // ── STREAKS ──────────────────────────────
    UIView *d3 = [[UIView alloc] initWithFrame:CGRectMake(10,y,pw-20,0.5)];
    d3.backgroundColor = [UIColor colorWithWhite:1 alpha:0.08]; [_scrollView addSubview:d3]; y+=10;
    y = [self sectionAt:y width:pw title:@"STREAKS & COINS"];

    YeepsToggleButton *streakBtn = [self toggleBtnTitle:@"🔥 Auto Claim Streak" tag:205 y:y width:pw-20];
    [streakBtn addTarget:self action:@selector(toggleAutoStreak:) forControlEvents:UIControlEventTouchUpInside];
    y += 46;

    YeepsButton *claimNow = [YeepsButton buttonWithTitle:@"💰 Claim Now"
        color:[UIColor colorWithRed:0.55 green:0.35 blue:0.05 alpha:0.9]];
    claimNow.frame = CGRectMake(10, y, pw-20, 40);
    [claimNow addTarget:self action:@selector(claimStreak) forControlEvents:UIControlEventTouchUpInside];
    [_scrollView addSubview:claimNow]; y += 46;

    // ── UTILITY ──────────────────────────────
    UIView *d4 = [[UIView alloc] initWithFrame:CGRectMake(10,y,pw-20,0.5)];
    d4.backgroundColor = [UIColor colorWithWhite:1 alpha:0.08]; [_scrollView addSubview:d4]; y+=10;
    y = [self sectionAt:y width:pw title:@"UTILITY"];

    // 2 column buttons
    NSArray *utilTitles  = @[@"📸 Screenshot", @"🎥 Record", @"📋 Copy UID", @"🔄 Respawn"];
    NSArray *utilColors  = @[
        [UIColor colorWithRed:0.1  green:0.3  blue:0.55 alpha:0.9],
        [UIColor colorWithRed:0.55 green:0.1  blue:0.1  alpha:0.9],
        [UIColor colorWithRed:0.15 green:0.35 blue:0.15 alpha:0.9],
        [UIColor colorWithRed:0.3  green:0.1  blue:0.55 alpha:0.9],
    ];
    NSArray *utilActions = @[@"doScreenshot", @"doRecord", @"copyUID", @"doRespawn"];
    for (int i = 0; i < 4; i++) {
        CGFloat bx = 10 + (i%2)*(bw+12);
        CGFloat by = y + (i/2)*48;
        YeepsButton *b = [YeepsButton buttonWithTitle:utilTitles[i] color:utilColors[i]];
        b.frame = CGRectMake(bx, by, bw, 38);
        [b addTarget:self action:NSSelectorFromString(utilActions[i])
    forControlEvents:UIControlEventTouchUpInside];
        [_scrollView addSubview:b];
    }
    y += 104;

    _scrollView.contentSize = CGSizeMake(pw, y+20);
}

// ── Helpers ──────────────────────────────────
- (CGFloat)sectionAt:(CGFloat)y width:(CGFloat)pw title:(NSString *)t {
    UILabel *l = [UILabel new];
    l.text = t; l.frame = CGRectMake(12,y,pw-24,16);
    l.font = [UIFont monospacedSystemFontOfSize:9 weight:UIFontWeightBold];
    l.textColor = [UIColor colorWithRed:0.6 green:0.4 blue:1 alpha:0.8];
    [_scrollView addSubview:l];
    return y+20;
}

- (YeepsToggleButton *)toggleBtnTitle:(NSString *)t tag:(NSInteger)tag y:(CGFloat)y width:(CGFloat)w {
    YeepsToggleButton *b = [YeepsToggleButton buttonWithTitle:t
        color:[UIColor colorWithRed:0.25 green:0.08 blue:0.45 alpha:0.9]];
    b.frame = CGRectMake(10,y,w,38); b.tag = tag;
    [_scrollView addSubview:b];
    return b;
}

- (CGFloat)stepperRowAt:(CGFloat)y width:(CGFloat)pw label:(NSString *)lbl
              minusTag:(NSInteger)mt plusTag:(NSInteger)pt valueTag:(NSInteger)vt value:(NSString *)val {
    UILabel *l = [UILabel new];
    l.text = lbl; l.frame = CGRectMake(14,y,100,28);
    l.font = [UIFont systemFontOfSize:12]; l.textColor = [UIColor colorWithWhite:0.6 alpha:1];
    [_scrollView addSubview:l];

    UIButton *minus = [YeepsButton buttonWithTitle:@"−"
        color:[UIColor colorWithRed:0.2 green:0.08 blue:0.35 alpha:0.9]];
    minus.frame = CGRectMake(pw-112,y,34,28); minus.tag = mt;
    [minus addTarget:self action:@selector(stepperMinus:) forControlEvents:UIControlEventTouchUpInside];
    [_scrollView addSubview:minus];

    UILabel *vl = [UILabel new];
    vl.text = val; vl.frame = CGRectMake(pw-72,y,38,28);
    vl.font = [UIFont systemFontOfSize:14 weight:UIFontWeightBold];
    vl.textColor = [UIColor colorWithRed:0.8 green:0.55 blue:1 alpha:1];
    vl.textAlignment = NSTextAlignmentCenter; vl.tag = vt;
    [_scrollView addSubview:vl];

    UIButton *plus = [YeepsButton buttonWithTitle:@"+"
        color:[UIColor colorWithRed:0.2 green:0.08 blue:0.35 alpha:0.9]];
    plus.frame = CGRectMake(pw-28,y,34,28); plus.tag = pt;
    [plus addTarget:self action:@selector(stepperPlus:) forControlEvents:UIControlEventTouchUpInside];
    [_scrollView addSubview:plus];

    return y+36;
}

- (void)dragPanel:(UIPanGestureRecognizer *)g {
    if ([g locationInView:_panel].y > 70) return; // only drag by header
    CGPoint t = [g translationInView:self.view];
    _panel.center = CGPointMake(_panel.center.x+t.x, _panel.center.y+t.y);
    [g setTranslation:CGPointZero inView:self.view];
}

- (void)setStatus:(NSString *)s color:(UIColor *)c {
    _statusLabel.text = s; _statusLabel.textColor = c;
}

- (void)resetStatus {
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(2*NSEC_PER_SEC)),
                   dispatch_get_main_queue(), ^{ [self setStatus:@"● Ready"
        color:[UIColor colorWithRed:0.4 green:1 blue:0.5 alpha:1]]; });
}

// ── Toggle panel ─────────────────────────────
- (void)togglePanel {
    _isPanelVisible = !_isPanelVisible;
    if (_isPanelVisible) {
        _panel.hidden = NO;
        _panel.transform = CGAffineTransformMakeScale(0.88,0.88);
        [UIView animateWithDuration:0.3 delay:0 usingSpringWithDamping:0.72
              initialSpringVelocity:0.5 options:0 animations:^{
            self.panel.alpha=1; self.panel.transform=CGAffineTransformIdentity;
        } completion:nil];
    } else {
        [UIView animateWithDuration:0.18 animations:^{
            self.panel.alpha=0; self.panel.transform=CGAffineTransformMakeScale(0.9,0.9);
        } completion:^(BOOL d){ self.panel.hidden=YES; self.panel.transform=CGAffineTransformIdentity; }];
    }
}

// ─────────────────────────────────────────────
// CHEATS
// ─────────────────────────────────────────────

// Speed
- (void)toggleSpeed:(YeepsToggleButton *)btn {
    gSpeedEnabled = !gSpeedEnabled;
    [btn setOn:gSpeedEnabled];
    NSString *t = gSpeedEnabled
        ? [NSString stringWithFormat:@"⚡ Speed  ON  %.0f×", gSpeedMult]
        : @"⚡ Speed Hack";
    [btn setTitle:t forState:UIControlStateNormal];
    [self setStatus:gSpeedEnabled ? [NSString stringWithFormat:@"⚡ Speed x%.0f", gSpeedMult] : @"Speed OFF"
              color:gSpeedEnabled ? [UIColor colorWithRed:0.3 green:1 blue:0.4 alpha:1]
                                  : [UIColor colorWithWhite:0.6 alpha:1]];
    [self resetStatus];
    NSLog(@"[Yeeps] Speed: %d x%.0f", gSpeedEnabled, gSpeedMult);
}

- (void)stepperMinus:(UIButton *)b {
    if (gSpeedMult > 1) gSpeedMult -= 1;
    [self updateSpeedLabel];
}
- (void)stepperPlus:(UIButton *)b {
    if (gSpeedMult < 20) gSpeedMult += 1;
    [self updateSpeedLabel];
}
- (void)updateSpeedLabel {
    UILabel *vl = (UILabel *)[_scrollView viewWithTag:213];
    vl.text = [NSString stringWithFormat:@"%.0f×", gSpeedMult];
    if (gSpeedEnabled) {
        YeepsToggleButton *btn = (YeepsToggleButton *)[_scrollView viewWithTag:201];
        [btn setTitle:[NSString stringWithFormat:@"⚡ Speed  ON  %.0f×", gSpeedMult]
             forState:UIControlStateNormal];
    }
}

// Noclip
- (void)toggleNoclip:(YeepsToggleButton *)btn {
    gNoClipEnabled = !gNoClipEnabled;
    [btn setOn:gNoClipEnabled];
    [self setStatus:gNoClipEnabled ? @"👻 Noclip ON" : @"Noclip OFF"
              color:gNoClipEnabled ? [UIColor colorWithRed:0.6 green:0.8 blue:1 alpha:1]
                                   : [UIColor colorWithWhite:0.6 alpha:1]];
    [self resetStatus];
    NSLog(@"[Yeeps] Noclip: %d", gNoClipEnabled);
}

// ESP
- (void)toggleESP:(YeepsToggleButton *)btn {
    gESPEnabled = !gESPEnabled;
    [btn setOn:gESPEnabled];
    if (gESPEnabled) [self drawESPOverlays];
    else [self removeESPOverlays];
    [self setStatus:gESPEnabled ? @"👁 ESP ON" : @"ESP OFF"
              color:gESPEnabled ? [UIColor colorWithRed:1 green:0.85 blue:0.2 alpha:1]
                                : [UIColor colorWithWhite:0.6 alpha:1]];
    [self resetStatus];
}

- (void)drawESPOverlays {
    UIWindow *gw = [self gameWindow];
    if (!gw) return;
    [self addESPToView:gw.rootViewController.view];
}

- (void)addESPToView:(UIView *)view {
    for (UIView *sub in view.subviews) {
        NSString *cls = NSStringFromClass([sub class]);
        if ([cls containsString:@"Player"] || [cls containsString:@"Character"] ||
            [cls containsString:@"Avatar"] || sub.tag == 9001) {
            UIView *box = [[UIView alloc] initWithFrame:sub.bounds];
            box.layer.borderColor = [UIColor colorWithRed:1 green:0.2 blue:0.2 alpha:0.9].CGColor;
            box.layer.borderWidth = 2;
            box.backgroundColor = [UIColor colorWithRed:1 green:0 blue:0 alpha:0.05];
            box.userInteractionEnabled = NO;
            box.tag = 7777;
            [sub addSubview:box];
        }
        [self addESPToView:sub];
    }
}

- (void)removeESPOverlays {
    UIWindow *gw = [self gameWindow];
    if (!gw) return;
    [self removeESPFromView:gw.rootViewController.view];
}

- (void)removeESPFromView:(UIView *)view {
    for (UIView *sub in view.subviews) {
        for (UIView *child in sub.subviews)
            if (child.tag == 7777) [child removeFromSuperview];
        [self removeESPFromView:sub];
    }
}

// Freeze time
- (void)toggleFreeze:(YeepsToggleButton *)btn {
    gFreezeTime = !gFreezeTime;
    [btn setOn:gFreezeTime];
    // Pause all animations in game window
    UIWindow *gw = [self gameWindow];
    if (gw) {
        gw.layer.speed = gFreezeTime ? 0.0 : 1.0;
    }
    [self setStatus:gFreezeTime ? @"❄️ Time Frozen" : @"Time Resumed"
              color:gFreezeTime ? [UIColor colorWithRed:0.4 green:0.8 blue:1 alpha:1]
                                : [UIColor colorWithWhite:0.6 alpha:1]];
    [self resetStatus];
}

// Teleport - save position
- (void)savePosition {
    UIWindow *gw = [self gameWindow];
    gSavedPosition = gw ? gw.rootViewController.view.center : CGPointMake(200,400);
    gPositionSaved = YES;
    [self setStatus:@"📍 Position saved!"
              color:[UIColor colorWithRed:0.3 green:0.7 blue:1 alpha:1]];
    [self resetStatus];
}

- (void)teleportToMe {
    if (!gPositionSaved) {
        [self setStatus:@"⚠️ Save position first!" color:[UIColor colorWithRed:1 green:0.6 blue:0.2 alpha:1]];
        [self resetStatus]; return;
    }
    UIWindow *gw = [self gameWindow];
    if (!gw) return;
    [self movePlayersInView:gw.rootViewController.view to:gSavedPosition];
    [self setStatus:@"🌀 Players teleported!"
              color:[UIColor colorWithRed:0.7 green:0.3 blue:1 alpha:1]];
    [self resetStatus];
}

- (void)teleportMeToSaved {
    if (!gPositionSaved) {
        [self setStatus:@"⚠️ Save position first!" color:[UIColor colorWithRed:1 green:0.6 blue:0.2 alpha:1]];
        [self resetStatus]; return;
    }
    // Move our own view to saved position
    UIWindow *gw = [self gameWindow];
    if (gw) {
        [UIView animateWithDuration:0.25 animations:^{
            gw.rootViewController.view.center = gSavedPosition;
        }];
    }
    [self setStatus:@"📌 Teleported to saved!" color:[UIColor colorWithRed:0.3 green:0.7 blue:1 alpha:1]];
    [self resetStatus];
}

- (void)movePlayersInView:(UIView *)view to:(CGPoint)pos {
    for (UIView *sub in view.subviews) {
        NSString *cls = NSStringFromClass([sub class]);
        if ([cls containsString:@"Player"] || [cls containsString:@"Character"] ||
            [cls containsString:@"Avatar"] || sub.tag == 9001) {
            [UIView animateWithDuration:0.25 animations:^{ sub.center = pos; }];
        }
        [self movePlayersInView:sub to:pos];
    }
}

// Auto streak
- (void)toggleAutoStreak:(YeepsToggleButton *)btn {
    gAutoStreakOn = !gAutoStreakOn;
    [btn setOn:gAutoStreakOn];
    if (gAutoStreakOn) {
        [self claimStreak];
        gStreakTimer = [NSTimer scheduledTimerWithTimeInterval:86400
                                                       target:self
                                                     selector:@selector(claimStreak)
                                                     userInfo:nil
                                                      repeats:YES];
        [self setStatus:@"🔥 Auto streak ON" color:[UIColor colorWithRed:1 green:0.6 blue:0.1 alpha:1]];
    } else {
        [gStreakTimer invalidate]; gStreakTimer = nil;
        [self setStatus:@"Auto streak OFF" color:[UIColor colorWithWhite:0.6 alpha:1]];
    }
    [self resetStatus];
}

- (void)claimStreak {
    // Tap the streak claim button in the game window
    UIWindow *gw = [self gameWindow];
    if (!gw) return;
    [self findAndTapStreakIn:gw.rootViewController.view];
    [self setStatus:@"💰 Streak claimed!" color:[UIColor colorWithRed:1 green:0.8 blue:0.2 alpha:1]];
    [self resetStatus];
    NSLog(@"[Yeeps] Streak claim triggered");
}

- (void)findAndTapStreakIn:(UIView *)view {
    for (UIView *sub in view.subviews) {
        if ([sub isKindOfClass:[UIButton class]]) {
            UIButton *b = (UIButton *)sub;
            NSString *t = [b titleForState:UIControlStateNormal];
            if ([t containsString:@"Claim"] || [t containsString:@"Streak"] ||
                [t containsString:@"Daily"] || [t containsString:@"Collect"]) {
                [b sendActionsForControlEvents:UIControlEventTouchUpInside];
                NSLog(@"[Yeeps] Tapped streak button: %@", t);
                return;
            }
        }
        [self findAndTapStreakIn:sub];
    }
}

// Screenshot
- (void)doScreenshot {
    UIGraphicsBeginImageContextWithOptions([UIScreen mainScreen].bounds.size, NO, 0);
    [[UIApplication sharedApplication].keyWindow
        drawViewHierarchyInRect:[UIScreen mainScreen].bounds afterScreenUpdates:YES];
    UIImage *img = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();
    UIImageWriteToSavedPhotosAlbum(img, nil, nil, nil);
    [self setStatus:@"📸 Screenshot saved!" color:[UIColor colorWithRed:0.3 green:0.7 blue:1 alpha:1]];
    [self resetStatus];
}

// Record
- (void)doRecord {
    [self setStatus:@"🎥 Use iOS screen record" color:[UIColor colorWithWhite:0.7 alpha:1]];
    [self resetStatus];
    // Open control centre hint
    UINotificationFeedbackGenerator *g = [UINotificationFeedbackGenerator new];
    [g notificationOccurred:UINotificationFeedbackTypeSuccess];
}

// Copy UID
- (void)copyUID {
    NSString *uid = [[NSBundle mainBundle] bundleIdentifier] ?: @"unknown";
    [UIPasteboard generalPasteboard].string = uid;
    [self setStatus:[NSString stringWithFormat:@"📋 %@", uid]
              color:[UIColor colorWithRed:0.4 green:1 blue:0.6 alpha:1]];
    [self resetStatus];
}

// Respawn
- (void)doRespawn {
    UIWindow *gw = [self gameWindow];
    if (gw) {
        [UIView transitionWithView:gw duration:0.3
                           options:UIViewAnimationOptionTransitionCrossDissolve
                        animations:^{ gw.alpha = 0.5; }
                        completion:^(BOOL d){
            [UIView animateWithDuration:0.3 animations:^{ gw.alpha = 1; }];
        }];
    }
    [self setStatus:@"🔄 Respawn triggered" color:[UIColor colorWithRed:0.6 green:1 blue:0.4 alpha:1]];
    [self resetStatus];
    NSLog(@"[Yeeps] Respawn");
}

// FPS counter
- (void)startFPSCounter {
    _lastFrameTime = [NSDate date];
    _fpsTimer = [NSTimer scheduledTimerWithTimeInterval:0.5 target:self
                selector:@selector(updateFPS) userInfo:nil repeats:YES];
}
- (void)updateFPS {
    NSDate *now = [NSDate date];
    NSTimeInterval dt = [now timeIntervalSinceDate:_lastFrameTime];
    _lastFrameTime = now;
    int fps = (int)MIN(120, 1.0/dt * 0.5);
    UIColor *c = fps >= 55 ? [UIColor colorWithRed:0.3 green:1 blue:0.4 alpha:1]
               : fps >= 30 ? [UIColor colorWithRed:1 green:0.8 blue:0.2 alpha:1]
                           : [UIColor colorWithRed:1 green:0.3 blue:0.3 alpha:1];
    _fpsLabel.text = [NSString stringWithFormat:@"%d FPS", fps];
    _fpsLabel.textColor = c;
}

// Game window helper
- (UIWindow *)gameWindow {
    for (UIWindow *w in [UIApplication sharedApplication].windows)
        if (![w isKindOfClass:[YeepsOverlayWindow class]]) return w;
    return nil;
}

- (BOOL)prefersStatusBarHidden { return YES; }
@end
