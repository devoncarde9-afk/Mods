// yeeps_companion.m
// Yeeps Companion — macOS dylib with floating GUI overlay
// Inject via DYLD_INSERT_LIBRARIES or load from host app
//
// Build: see build.sh

#import <Cocoa/Cocoa.h>
#import <QuartzCore/QuartzCore.h>
#include <mach-o/dyld.h>

// ─────────────────────────────────────────────
// Forward declarations
// ─────────────────────────────────────────────
@interface YeepsWindow     : NSPanel   @end
@interface YeepsController : NSObject  <NSApplicationDelegate>
@property (strong) YeepsWindow *window;
- (void)launch;
@end
@interface GradientView    : NSView    @end
@interface PulseButton     : NSButton  @end

// ─────────────────────────────────────────────
// Entry point — called when dylib is loaded
// ─────────────────────────────────────────────
__attribute__((constructor))
static void yeeps_init(void) {
    // Must run UI on main thread; use dispatch in case we're injected
    dispatch_async(dispatch_get_main_queue(), ^{
        // Ensure NSApp exists (handles injection into non-Cocoa targets too)
        if (!NSApp) {
            [NSApplication sharedApplication];
            [NSApp setActivationPolicy:NSApplicationActivationPolicyAccessory];
        }
        YeepsController *ctrl = [YeepsController new];
        // Keep alive — associate with NSApp via objc runtime trick
        objc_setAssociatedObject(NSApp, "yeepsController", ctrl,
                                 OBJC_ASSOCIATION_RETAIN_NONATOMIC);
        [ctrl launch];
    });
}

// ─────────────────────────────────────────────
// GradientView — animated mesh background
// ─────────────────────────────────────────────
@implementation GradientView {
    CAGradientLayer *_grad;
    NSTimer         *_timer;
    CGFloat          _phase;
}

- (instancetype)initWithFrame:(NSRect)frame {
    self = [super initWithFrame:frame];
    if (!self) return nil;
    self.wantsLayer = YES;

    _grad = [CAGradientLayer layer];
    _grad.frame = self.bounds;
    _grad.autoresizingMask = kCALayerWidthSizable | kCALayerHeightSizable;
    _grad.startPoint = CGPointMake(0, 0);
    _grad.endPoint   = CGPointMake(1, 1);
    [self updateGradientPhase:0];
    [self.layer addSublayer:_grad];

    // Subtle corner radius
    self.layer.cornerRadius = 16;
    self.layer.masksToBounds = YES;

    _timer = [NSTimer scheduledTimerWithTimeInterval:0.05
                                             target:self
                                           selector:@selector(tick)
                                           userInfo:nil
                                            repeats:YES];
    return self;
}

- (void)tick {
    _phase += 0.015;
    [CATransaction begin];
    [CATransaction setAnimationDuration:0.1];
    [self updateGradientPhase:_phase];
    [CATransaction commit];
}

- (void)updateGradientPhase:(CGFloat)p {
    CGFloat s = sin(p), c = cos(p * 0.7);
    NSColor *c1 = [NSColor colorWithRed:0.04 + 0.02*s
                                  green:0.06 + 0.02*c
                                   blue:0.14 + 0.03*s
                                  alpha:1.0];
    NSColor *c2 = [NSColor colorWithRed:0.08 + 0.03*c
                                  green:0.04 + 0.02*s
                                   blue:0.20 + 0.04*c
                                  alpha:1.0];
    NSColor *c3 = [NSColor colorWithRed:0.02
                                  green:0.10 + 0.03*s
                                   blue:0.18 + 0.02*c
                                  alpha:1.0];
    _grad.colors = @[(__bridge id)c1.CGColor,
                     (__bridge id)c2.CGColor,
                     (__bridge id)c3.CGColor];
}

- (void)dealloc { [_timer invalidate]; }
@end

// ─────────────────────────────────────────────
// PulseButton — glowing accent button
// ─────────────────────────────────────────────
@implementation PulseButton {
    CALayer *_glow;
    BOOL     _pulsing;
}

- (void)awakeFromNib { [self commonInit]; }
- (instancetype)initWithFrame:(NSRect)f {
    self = [super initWithFrame:f];
    [self commonInit];
    return self;
}

- (void)commonInit {
    self.wantsLayer = YES;
    self.bezelStyle = NSBezelStyleInline;
    self.bordered   = NO;
    [self.cell setBackgroundColor:[NSColor clearColor]];

    self.layer.cornerRadius = 10;
    self.layer.backgroundColor =
        [NSColor colorWithRed:0.3 green:0.1 blue:0.7 alpha:0.85].CGColor;
    self.layer.borderWidth = 1;
    self.layer.borderColor =
        [NSColor colorWithRed:0.6 green:0.3 blue:1.0 alpha:0.6].CGColor;

    // Shadow glow
    self.layer.shadowColor  = [NSColor colorWithRed:0.5 green:0.2 blue:1.0 alpha:1].CGColor;
    self.layer.shadowRadius = 8;
    self.layer.shadowOpacity = 0.7;
    self.layer.shadowOffset  = CGSizeZero;
}

- (void)mouseEntered:(NSEvent *)e {
    [CATransaction begin];
    [CATransaction setAnimationDuration:0.15];
    self.layer.backgroundColor =
        [NSColor colorWithRed:0.4 green:0.15 blue:0.9 alpha:0.95].CGColor;
    self.layer.shadowOpacity = 1.0;
    [CATransaction commit];
}

- (void)mouseExited:(NSEvent *)e {
    [CATransaction begin];
    [CATransaction setAnimationDuration:0.25];
    self.layer.backgroundColor =
        [NSColor colorWithRed:0.3 green:0.1 blue:0.7 alpha:0.85].CGColor;
    self.layer.shadowOpacity = 0.7;
    [CATransaction commit];
}

- (void)updateTrackingAreas {
    [super updateTrackingAreas];
    for (NSTrackingArea *t in self.trackingAreas)
        [self removeTrackingArea:t];
    NSTrackingArea *ta = [[NSTrackingArea alloc]
        initWithRect:self.bounds
             options:NSTrackingMouseEnteredAndExited | NSTrackingActiveAlways
               owner:self
            userInfo:nil];
    [self addTrackingArea:ta];
}
@end

// ─────────────────────────────────────────────
// YeepsWindow — floating panel
// ─────────────────────────────────────────────
@implementation YeepsWindow

- (instancetype)init {
    NSRect frame = NSMakeRect(0, 0, 320, 480);
    self = [super initWithContentRect:frame
                            styleMask:NSWindowStyleMaskNonactivatingPanel |
                                      NSWindowStyleMaskFullSizeContentView |
                                      NSWindowStyleMaskTitled |
                                      NSWindowStyleMaskClosable |
                                      NSWindowStyleMaskResizable
                              backing:NSBackingStoreBuffered
                                defer:NO];
    if (!self) return nil;

    self.title = @"Yeeps";
    self.titlebarAppearsTransparent = YES;
    self.movableByWindowBackground  = YES;
    self.level = NSFloatingWindowLevel;
    self.collectionBehavior = NSWindowCollectionBehaviorCanJoinAllSpaces |
                              NSWindowCollectionBehaviorStationary;
    self.isOpaque = NO;
    self.backgroundColor = [NSColor clearColor];
    self.hasShadow = YES;
    self.minSize = NSMakeSize(260, 340);

    // Visual effect (blur) base
    NSVisualEffectView *fx = [[NSVisualEffectView alloc]
                               initWithFrame:self.contentView.bounds];
    fx.autoresizingMask = NSViewWidthSizable | NSViewHeightSizable;
    fx.material  = NSVisualEffectMaterialHUDWindow;
    fx.blendingMode = NSVisualEffectBlendingModeBehindWindow;
    fx.state = NSVisualEffectStateActive;
    fx.wantsLayer = YES;
    fx.layer.cornerRadius = 16;
    fx.layer.masksToBounds = YES;
    [self.contentView addSubview:fx positioned:NSWindowBelow relativeTo:nil];

    // Gradient overlay
    GradientView *bg = [[GradientView alloc]
                         initWithFrame:self.contentView.bounds];
    bg.autoresizingMask = NSViewWidthSizable | NSViewHeightSizable;
    [self.contentView addSubview:bg];

    [self buildUI];
    [self center];
    return self;
}

- (void)buildUI {
    NSView *cv = self.contentView;
    CGFloat W = cv.bounds.size.width;

    // ── Header ──────────────────────────────
    NSTextField *logo = [NSTextField labelWithString:@"✦ YEEPS"];
    logo.font = [NSFont fontWithName:@"SF Pro Rounded" size:22]
             ?: [NSFont boldSystemFontOfSize:22];
    logo.textColor = [NSColor colorWithRed:0.85 green:0.6 blue:1.0 alpha:1];
    logo.frame = NSMakeRect(20, cv.bounds.size.height - 64, W - 40, 30);
    logo.autoresizingMask = NSViewWidthSizable | NSViewMinYMargin;
    [cv addSubview:logo];

    NSTextField *sub = [NSTextField labelWithString:@"companion"];
    sub.font = [NSFont fontWithName:@"SF Mono" size:11]
            ?: [NSFont monospacedSystemFontOfSize:11 weight:NSFontWeightRegular];
    sub.textColor = [NSColor colorWithWhite:0.6 alpha:0.8];
    sub.frame = NSMakeRect(22, cv.bounds.size.height - 82, W - 40, 16);
    sub.autoresizingMask = NSViewWidthSizable | NSViewMinYMargin;
    [cv addSubview:sub];

    // Divider
    NSBox *div = [[NSBox alloc] initWithFrame:NSMakeRect(20, cv.bounds.size.height - 96, W - 40, 1)];
    div.boxType = NSBoxSeparator;
    div.autoresizingMask = NSViewWidthSizable | NSViewMinYMargin;
    [cv addSubview:div];

    // ── Status card ─────────────────────────
    [self addCardAtY:cv.bounds.size.height - 180
               width:W
               title:@"STATUS"
               value:@"● Online"
           valueColor:[NSColor colorWithRed:0.3 green:1.0 blue:0.5 alpha:1]
                  in:cv];

    // ── Info cards ──────────────────────────
    [self addCardAtY:cv.bounds.size.height - 250
               width:W
               title:@"VERSION"
               value:@"1.0.0-dylib"
           valueColor:[NSColor colorWithWhite:0.85 alpha:1]
                  in:cv];

    [self addCardAtY:cv.bounds.size.height - 320
               width:W
               title:@"HOST PROCESS"
               value:[NSString stringWithFormat:@"%@",
                      [[NSProcessInfo processInfo] processName]]
           valueColor:[NSColor colorWithRed:0.6 green:0.8 blue:1.0 alpha:1]
                  in:cv];

    // ── Action buttons ──────────────────────
    [self addButtonAtY:100 width:W label:@"Reload Companion" action:@selector(doReload) in:cv];
    [self addButtonAtY:56  width:W label:@"Hide Window"      action:@selector(doHide)   in:cv];
}

// ── Card helper ─────────────────────────────
- (void)addCardAtY:(CGFloat)y width:(CGFloat)W
             title:(NSString *)title
             value:(NSString *)value
        valueColor:(NSColor *)vc
                in:(NSView *)cv {
    NSView *card = [[NSView alloc] initWithFrame:NSMakeRect(16, y, W - 32, 56)];
    card.wantsLayer = YES;
    card.layer.cornerRadius  = 10;
    card.layer.backgroundColor =
        [NSColor colorWithWhite:1 alpha:0.06].CGColor;
    card.layer.borderWidth = 0.5;
    card.layer.borderColor =
        [NSColor colorWithWhite:1 alpha:0.12].CGColor;
    card.autoresizingMask = NSViewWidthSizable | NSViewMinYMargin;

    NSTextField *tLabel = [NSTextField labelWithString:title];
    tLabel.font = [NSFont fontWithName:@"SF Mono" size:9]
               ?: [NSFont monospacedSystemFontOfSize:9 weight:NSFontWeightMedium];
    tLabel.textColor = [NSColor colorWithWhite:0.5 alpha:1];
    tLabel.frame = NSMakeRect(12, 30, card.bounds.size.width - 24, 14);
    tLabel.autoresizingMask = NSViewWidthSizable;
    [card addSubview:tLabel];

    NSTextField *vLabel = [NSTextField labelWithString:value];
    vLabel.font = [NSFont fontWithName:@"SF Pro Rounded" size:14]
               ?: [NSFont systemFontOfSize:14 weight:NSFontWeightSemibold];
    vLabel.textColor = vc;
    vLabel.frame = NSMakeRect(12, 8, card.bounds.size.width - 24, 20);
    vLabel.autoresizingMask = NSViewWidthSizable;
    [card addSubview:vLabel];

    [cv addSubview:card];
}

// ── Button helper ───────────────────────────
- (void)addButtonAtY:(CGFloat)y width:(CGFloat)W
               label:(NSString *)label
              action:(SEL)action
                  in:(NSView *)cv {
    PulseButton *btn = [[PulseButton alloc]
                         initWithFrame:NSMakeRect(16, y, W - 32, 36)];
    btn.title = label;
    btn.font  = [NSFont fontWithName:@"SF Pro Rounded" size:13]
             ?: [NSFont systemFontOfSize:13 weight:NSFontWeightMedium];
    NSMutableAttributedString *atStr = [[NSMutableAttributedString alloc]
        initWithString:label
            attributes:@{
                NSForegroundColorAttributeName:
                    [NSColor colorWithWhite:0.92 alpha:1],
                NSFontAttributeName: btn.font
            }];
    [btn setAttributedTitle:atStr];
    btn.target = self;
    btn.action = action;
    btn.autoresizingMask = NSViewWidthSizable;
    [cv addSubview:btn];
}

// ── Actions ─────────────────────────────────
- (void)doReload {
    // Animate a brief flash then re-show
    [NSAnimationContext runAnimationGroup:^(NSAnimationContext *ctx) {
        ctx.duration = 0.15;
        self.animator.alphaValue = 0.3;
    } completionHandler:^{
        [NSAnimationContext runAnimationGroup:^(NSAnimationContext *ctx) {
            ctx.duration = 0.25;
            self.animator.alphaValue = 1.0;
        } completionHandler:nil];
    }];
}

- (void)doHide {
    [self orderOut:nil];
    // Re-show after 3 s so it's not lost forever during testing
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, 3 * NSEC_PER_SEC),
                   dispatch_get_main_queue(), ^{
        [self makeKeyAndOrderFront:nil];
    });
}

// Allow dragging from background
- (BOOL)isMovableByWindowBackground { return YES; }
@end

// ─────────────────────────────────────────────
// YeepsController
// ─────────────────────────────────────────────
@implementation YeepsController

- (void)launch {
    _window = [YeepsWindow new];

    // Slide-in animation from right
    NSRect final = _window.frame;
    NSRect start = NSMakeRect(final.origin.x + 60,
                              final.origin.y - 20,
                              final.size.width,
                              final.size.height);
    [_window setFrame:start display:NO];
    _window.alphaValue = 0;
    [_window makeKeyAndOrderFront:nil];

    [NSAnimationContext runAnimationGroup:^(NSAnimationContext *ctx) {
        ctx.duration = 0.45;
        ctx.timingFunction = [CAMediaTimingFunction
            functionWithName:kCAMediaTimingFunctionEaseOut];
        [_window.animator setFrame:final display:YES];
        _window.animator.alphaValue = 1.0;
    } completionHandler:nil];

    NSLog(@"[YeepsCompanion] GUI launched in process: %@",
          [[NSProcessInfo processInfo] processName]);
}

@end
