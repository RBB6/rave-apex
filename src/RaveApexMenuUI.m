#import "RaveApexMenuUI.h"
#import "RaveApexTweak.h"
#import "RaveApexHooks.h"
#include <time.h>
#include <sys/time.h>

@interface NSThread (ApexThreading)
+ (BOOL)isMainThread;
@end

// ==============================================================================
// 1. DEDICATED ZERO-COLLISION OVERLAY WINDOW ARCHITECTURE
// ==============================================================================

@interface ApexPassthroughView : UIView
@end

@implementation ApexPassthroughView
- (UIView *)hitTest:(CGPoint)point withEvent:(UIEvent *)event {
    UIView *hit = [super hitTest:point withEvent:event];
    if (hit == self) return nil; // Passthrough empty space to Rave!
    return hit;
}
@end

@interface ApexOverlayViewController : UIViewController
@end

@implementation ApexOverlayViewController
- (void)loadView {
    ApexPassthroughView *view = [[ApexPassthroughView alloc] initWithFrame:[UIScreen mainScreen].bounds];
    view.backgroundColor = [UIColor clearColor];
    view.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    view.userInteractionEnabled = YES;
    self.view = view;
}
- (BOOL)shouldAutorotate { return YES; }
- (NSUInteger)supportedInterfaceOrientations { return 0x1E; /* All except upside down */ }
- (BOOL)prefersStatusBarHidden { return NO; }
- (BOOL)canBecomeFirstResponder { return YES; }
- (void)motionEnded:(UIEventSubtype)motion withEvent:(UIEvent *)event {
    if (motion == UIEventSubtypeMotionShake) {
        [[RaveApexMenuUI sharedInstance] toggleMenuVisibility];
    }
}
@end

@interface ApexOverlayWindow : UIWindow
@property (nonatomic, unsafe_unretained) RaveApexMenuUI *menuUI;
@end

@implementation ApexOverlayWindow
- (BOOL)canBecomeKeyWindow {
    return (self.menuUI && self.menuUI.isMenuOpen);
}
- (BOOL)canBecomeFirstResponder {
    return (self.menuUI && self.menuUI.isMenuOpen);
}

- (BOOL)pointInside:(CGPoint)point withEvent:(UIEvent *)event {
    if (self.menuUI && self.menuUI.isMenuOpen) {
        return YES;
    }
    if (self.menuUI && self.menuUI.floatingButton && !self.menuUI.floatingButton.hidden) {
        CGPoint btnPt = [self convertPoint:point toView:self.menuUI.floatingButton];
        if ([self.menuUI.floatingButton pointInside:btnPt withEvent:event]) {
            return YES;
        }
    }
    return NO;
}

- (UIView *)hitTest:(CGPoint)point withEvent:(UIEvent *)event {
    UIView *hitView = [super hitTest:point withEvent:event];
    // CRITICAL: Point-inside passthrough so this overlay window NEVER intercepts
    // touches meant for the host application underneath when menu is not hit.
    if (hitView == self || hitView == self.rootViewController.view) {
        return nil; // Pass straight through to Rave!
    }
    return hitView;
}
@end

@interface RaveApexMenuUI () <UIGestureRecognizerDelegate>

@property (nonatomic, strong, nullable) UIWindow *cachedHostWindow;
@property (nonatomic, strong) UIView *backdropView;
@property (nonatomic, strong) UISegmentedControl *tabSelector;
@property (nonatomic, strong) NSArray<UIView *> *tabViews;
@property (nonatomic, strong) UILabel *telemetryLabel;

// Interactive Sliders & Readouts
@property (nonatomic, strong) UISlider *speedSlider;
@property (nonatomic, strong) UILabel *speedValueLabel;
@property (nonatomic, strong) UISlider *preampSlider;
@property (nonatomic, strong) UILabel *preampValueLabel;
@property (nonatomic, strong) UILabel *clockNudgeLabel;

// Native Overlay Instance
@property (nonatomic, strong) UIView *hudCardView;

// Live log console
@property (nonatomic, strong) UIView *logPanel;
@property (nonatomic, strong) UITextView *logTextView;

// Guide panel
@property (nonatomic, strong) UIView *guidePanel;

// Pro-feature state
@property (nonatomic, assign) BOOL autoChaosActive;
@property (nonatomic, assign) BOOL autoLeaderActive;
@property (nonatomic, assign) CGPoint menuDragStart;
@property (nonatomic, strong) UILabel *tacticalPill;

@end

@implementation RaveApexMenuUI

+ (instancetype)sharedInstance {
    static RaveApexMenuUI *instance = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        instance = [[RaveApexMenuUI alloc] init];
    });
    return instance;
}

- (void)initializeOverlay {
    [self mountOverlayWithAttemptsRemaining:60];
}

// Public entrypoint: bring the control surface up alongside the host app. Safe to
// call repeatedly and from any thread; mounting is idempotent on the main queue.
- (void)launchMenuWithApp {
    if (![NSThread isMainThread]) {
        dispatch_async(dispatch_get_main_queue(), ^{ [self launchMenuWithApp]; });
        return;
    }
    [self initializeOverlay];
    [self ensureFloatingButtonOnTop];
}

- (void)openMenuAnimated:(BOOL)animated {
    if (![NSThread isMainThread]) {
        dispatch_async(dispatch_get_main_queue(), ^{ [self openMenuAnimated:animated]; });
        return;
    }
    if (!self.isMenuOpen) [self toggleMenuVisibility];
}

- (void)closeMenuAnimated:(BOOL)animated {
    if (![NSThread isMainThread]) {
        dispatch_async(dispatch_get_main_queue(), ^{ [self closeMenuAnimated:animated]; });
        return;
    }
    if (self.isMenuOpen) [self toggleMenuVisibility];
}

- (void)ensureFloatingButtonOnTop {
    @try {
        UIView *parent = self.floatingButton.superview;
        if (parent && self.floatingButton) {
            self.floatingButton.hidden = NO;
            self.floatingButton.alpha = 1.0;
            self.floatingButton.layer.zPosition = 9999.0;
            [parent bringSubviewToFront:self.floatingButton];
        }
    } @catch (NSException *e) {}
}

- (id)findActiveWindowScene {
    @try {
        Class sceneCls = objc_getClass("UIWindowScene");
        if (!sceneCls) return nil;

        // Check cached or active host window
        UIWindow *host = [self findHostWindow];
        if (host && [host respondsToSelector:NSSelectorFromString(@"windowScene")]) {
            id s = ((id (*)(id, SEL))objc_msgSend)(host, NSSelectorFromString(@"windowScene"));
            if (s && [s isKindOfClass:sceneCls]) return s;
        }

        UIApplication *app = [UIApplication sharedApplication];
        if (app && [app respondsToSelector:NSSelectorFromString(@"connectedScenes")]) {
            id scenes = ((id (*)(id, SEL))objc_msgSend)(app, NSSelectorFromString(@"connectedScenes"));
            if ([scenes respondsToSelector:@selector(countByEnumeratingWithState:objects:count:)]) {
                // Pass 1: Foreground Active
                for (id scene in scenes) {
                    if ([scene isKindOfClass:sceneCls]) {
                        SEL actSel = NSSelectorFromString(@"activationState");
                        NSInteger state = [scene respondsToSelector:actSel] ? ((NSInteger (*)(id, SEL))objc_msgSend)(scene, actSel) : -1;
                        if (state == 0 /* UISceneActivationStateForegroundActive */) {
                            return scene;
                        }
                    }
                }
                // Pass 2: Foreground Inactive
                for (id scene in scenes) {
                    if ([scene isKindOfClass:sceneCls]) {
                        SEL actSel = NSSelectorFromString(@"activationState");
                        NSInteger state = [scene respondsToSelector:actSel] ? ((NSInteger (*)(id, SEL))objc_msgSend)(scene, actSel) : -1;
                        if (state == 1 /* UISceneActivationStateForegroundInactive */) {
                            return scene;
                        }
                    }
                }
                // Pass 3: Any scene
                for (id scene in scenes) {
                    if ([scene isKindOfClass:sceneCls]) return scene;
                }
            }
        }
    } @catch (NSException *e) {
        NSLog(@"[RaveApexCore] findActiveWindowScene exception: %@", e);
    }
    return nil;
}

- (UIWindow *)findHostWindow {
    @try {
        Class apexWinCls = objc_getClass("ApexOverlayWindow");
        if (self.cachedHostWindow && [self.cachedHostWindow isKindOfClass:[UIWindow class]]) {
            if (self.cachedHostWindow != self.overlayWindow && !(apexWinCls && [self.cachedHostWindow isKindOfClass:apexWinCls])) {
                if (!self.cachedHostWindow.hidden && self.cachedHostWindow.alpha > 0.05) {
                    return self.cachedHostWindow;
                }
            }
        }
        UIApplication *app = [UIApplication sharedApplication];
        if (!app) return self.cachedHostWindow;

        // Pass 0: Key Window
        UIWindow *kw = app.keyWindow;
        if (kw && kw != self.overlayWindow && !(apexWinCls && [kw isKindOfClass:apexWinCls]) && !kw.hidden && kw.alpha > 0.05) {
            self.cachedHostWindow = kw;
            return kw;
        }

        // Pass 1: Connected scenes
        if ([app respondsToSelector:NSSelectorFromString(@"connectedScenes")]) {
            id scenes = ((id (*)(id, SEL))objc_msgSend)(app, NSSelectorFromString(@"connectedScenes"));
            if ([scenes respondsToSelector:@selector(countByEnumeratingWithState:objects:count:)]) {
                Class wsCls = objc_getClass("UIWindowScene");
                // 1A: Foreground Active Scenes
                for (id scene in scenes) {
                    if (wsCls && [scene isKindOfClass:wsCls]) {
                        SEL actSel = NSSelectorFromString(@"activationState");
                        NSInteger actState = [scene respondsToSelector:actSel] ? ((NSInteger (*)(id, SEL))objc_msgSend)(scene, actSel) : -1;
                        if (actState == 0 /* UISceneActivationStateForegroundActive */) {
                            SEL winSel = NSSelectorFromString(@"windows");
                            if ([scene respondsToSelector:winSel]) {
                                NSArray *sceneWins = ((id (*)(id, SEL))objc_msgSend)(scene, winSel);
                                if ([sceneWins respondsToSelector:@selector(countByEnumeratingWithState:objects:count:)]) {
                                    for (UIWindow *w in sceneWins) {
                                        if ([w isKindOfClass:[UIWindow class]] && w != self.overlayWindow && !(apexWinCls && [w isKindOfClass:apexWinCls])) {
                                            if (!w.hidden && w.alpha > 0.05 && w.rootViewController != nil) {
                                                self.cachedHostWindow = w;
                                                return w;
                                            }
                                        }
                                    }
                                    for (UIWindow *w in sceneWins) {
                                        if ([w isKindOfClass:[UIWindow class]] && w != self.overlayWindow && !(apexWinCls && [w isKindOfClass:apexWinCls])) {
                                            if (!w.hidden && w.alpha > 0.05) {
                                                self.cachedHostWindow = w;
                                                return w;
                                            }
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
                // 1B: Fallback to any connected scene
                for (id scene in scenes) {
                    if (wsCls && [scene isKindOfClass:wsCls]) {
                        SEL winSel = NSSelectorFromString(@"windows");
                        if ([scene respondsToSelector:winSel]) {
                            NSArray *sceneWins = ((id (*)(id, SEL))objc_msgSend)(scene, winSel);
                            if ([sceneWins respondsToSelector:@selector(countByEnumeratingWithState:objects:count:)]) {
                                for (UIWindow *w in sceneWins) {
                                    if ([w isKindOfClass:[UIWindow class]] && w != self.overlayWindow && !(apexWinCls && [w isKindOfClass:apexWinCls])) {
                                        if (!w.hidden && w.alpha > 0.05) {
                                            self.cachedHostWindow = w;
                                            return w;
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }

        // Pass 2: app.windows
        for (UIWindow *w in app.windows) {
            if ([w isKindOfClass:[UIWindow class]] && w != self.overlayWindow && !(apexWinCls && [w isKindOfClass:apexWinCls]) && !w.hidden && w.alpha > 0.05 && w.rootViewController != nil) {
                self.cachedHostWindow = w;
                return w;
            }
        }
        for (UIWindow *w in app.windows) {
            if ([w isKindOfClass:[UIWindow class]] && w != self.overlayWindow && !(apexWinCls && [w isKindOfClass:apexWinCls]) && !w.hidden && w.alpha > 0.05) {
                self.cachedHostWindow = w;
                return w;
            }
        }

        // Pass 3: app.delegate.window
        if ([app.delegate respondsToSelector:@selector(window)]) {
            UIWindow *w = ((UIWindow * (*)(id, SEL))objc_msgSend)(app.delegate, @selector(window));
            if (w && w != self.overlayWindow && !(apexWinCls && [w isKindOfClass:apexWinCls])) {
                self.cachedHostWindow = w;
                return w;
            }
        }

        // Pass 4: Unconditional fallback to ANY window in app.windows or keyWindow
        for (UIWindow *w in app.windows) {
            if ([w isKindOfClass:[UIWindow class]] && w != self.overlayWindow && !(apexWinCls && [w isKindOfClass:apexWinCls])) {
                self.cachedHostWindow = w;
                return w;
            }
        }
        if (kw && kw != self.overlayWindow && !(apexWinCls && [kw isKindOfClass:apexWinCls])) {
            self.cachedHostWindow = kw;
            return kw;
        }
    } @catch (NSException *e) {
        NSLog(@"[RaveApexCore] findHostWindow guarded exception: %@", e);
    }
    return self.cachedHostWindow;
}

- (UIWindow *)ensureOverlayWindow {
    @try {
        Class sceneCls = objc_getClass("UIWindowScene");
        id targetScene = [self findActiveWindowScene];

        CGRect screenBounds = [UIScreen mainScreen].bounds;
        if (screenBounds.size.width <= 0.0 || screenBounds.size.height <= 0.0) {
            screenBounds = CGRectMake(0, 0, 393, 852);
        }

        // If self.overlayWindow already exists:
        if (self.overlayWindow) {
            id currentScene = nil;
            if (sceneCls && [self.overlayWindow respondsToSelector:NSSelectorFromString(@"windowScene")]) {
                currentScene = ((id (*)(id, SEL))objc_msgSend)(self.overlayWindow, NSSelectorFromString(@"windowScene"));
            }

            // CRITICAL FIX: If overlayWindow was created sceneless (orphaned), but now targetScene exists:
            // Destroy orphaned window and re-create cleanly attached to active scene!
            if (sceneCls && targetScene && currentScene != targetScene) {
                NSLog(@"[RaveApexCore] Upgrading overlay from orphaned/mismatched state to active UIWindowScene (%p)...", targetScene);
                if (self.floatingButton && self.floatingButton.superview == self.overlayWindow.rootViewController.view) {
                    [self.floatingButton removeFromSuperview];
                }
                self.overlayWindow.hidden = YES;
                self.overlayWindow = nil;
            } else {
                // Window is healthy
                if (self.overlayWindow.frame.size.width <= 0.0 || self.overlayWindow.frame.size.height <= 0.0) {
                    self.overlayWindow.frame = screenBounds;
                }
                if (self.overlayWindow.rootViewController && self.overlayWindow.rootViewController.view) {
                    self.overlayWindow.rootViewController.view.frame = self.overlayWindow.bounds;
                }
                self.overlayWindow.windowLevel = 2100.0; // UIWindowLevelAlert + 100.0 (Hardened safe level)
                if (self.overlayWindow.hidden) {
                    self.overlayWindow.hidden = NO;
                }
                [self.overlayWindow makeKeyAndVisible];
                return self.overlayWindow;
            }
        }

        ApexOverlayWindow *overlay = nil;
        if (sceneCls && targetScene) {
            overlay = [[ApexOverlayWindow alloc] initWithWindowScene:targetScene];
            NSLog(@"[RaveApexCore] Instantiated ApexOverlayWindow with targetScene (%p)", targetScene);
        } else {
            overlay = [[ApexOverlayWindow alloc] initWithFrame:screenBounds];
            NSLog(@"[RaveApexCore] Instantiated ApexOverlayWindow with frame fallback (%p)", overlay);
        }

        if (!overlay) {
            return nil;
        }

        overlay.frame = screenBounds;
        overlay.menuUI = self;
        overlay.windowLevel = 2100.0; // UIWindowLevelAlert + 100.0 (Hardened safe level)
        overlay.backgroundColor = [UIColor clearColor];
        overlay.userInteractionEnabled = YES;
        overlay.alpha = 1.0;

        ApexOverlayViewController *rootVC = [[ApexOverlayViewController alloc] init];
        overlay.rootViewController = rootVC;
        if (rootVC.view) {
            rootVC.view.backgroundColor = [UIColor clearColor];
            rootVC.view.userInteractionEnabled = YES;
            rootVC.view.frame = overlay.bounds;
        }
        overlay.hidden = NO;
        [overlay makeKeyAndVisible];

        self.overlayWindow = overlay;
        return overlay;
    } @catch (NSException *e) {
        NSLog(@"[RaveApexCore] ensureOverlayWindow guarded exception: %@", e);
        return nil;
    }
}

- (void)installFailsafeGestureOnWindow:(id)target {
    if (!target) return;
    @try {
        Class tapCls = objc_getClass("UITapGestureRecognizer");
        Class swipeCls = objc_getClass("UIScreenEdgePanGestureRecognizer");

        // 1. Two-finger Double-Tap
        if (tapCls) {
            id doubleTapTwoFinger = [[tapCls alloc] initWithTarget:self action:@selector(toggleMenuVisibility)];
            SEL setTaps = NSSelectorFromString(@"setNumberOfTapsRequired:");
            SEL setTouches = NSSelectorFromString(@"setNumberOfTouchesRequired:");
            SEL setCancels = NSSelectorFromString(@"setCancelsTouchesInView:");
            if ([doubleTapTwoFinger respondsToSelector:setTaps]) {
                ((void (*)(id, SEL, NSUInteger))objc_msgSend)(doubleTapTwoFinger, setTaps, 2);
            }
            if ([doubleTapTwoFinger respondsToSelector:setTouches]) {
                ((void (*)(id, SEL, NSUInteger))objc_msgSend)(doubleTapTwoFinger, setTouches, 2);
            }
            if ([doubleTapTwoFinger respondsToSelector:setCancels]) {
                ((void (*)(id, SEL, BOOL))objc_msgSend)(doubleTapTwoFinger, setCancels, NO);
            }
            if ([doubleTapTwoFinger respondsToSelector:@selector(setDelegate:)]) {
                ((void (*)(id, SEL, id))objc_msgSend)(doubleTapTwoFinger, @selector(setDelegate:), (id)self);
            }
            if ([target respondsToSelector:@selector(addGestureRecognizer:)]) {
                [target addGestureRecognizer:doubleTapTwoFinger];
            }

            // 2. Three-finger Single-Tap (Effortless direct emergency ingress)
            id tripleFinger = [[tapCls alloc] initWithTarget:self action:@selector(toggleMenuVisibility)];
            if ([tripleFinger respondsToSelector:setTaps]) {
                ((void (*)(id, SEL, NSUInteger))objc_msgSend)(tripleFinger, setTaps, 1);
            }
            if ([tripleFinger respondsToSelector:setTouches]) {
                ((void (*)(id, SEL, NSUInteger))objc_msgSend)(tripleFinger, setTouches, 3);
            }
            if ([tripleFinger respondsToSelector:setCancels]) {
                ((void (*)(id, SEL, BOOL))objc_msgSend)(tripleFinger, setCancels, NO);
            }
            if ([tripleFinger respondsToSelector:@selector(setDelegate:)]) {
                ((void (*)(id, SEL, id))objc_msgSend)(tripleFinger, @selector(setDelegate:), (id)self);
            }
            if ([target respondsToSelector:@selector(addGestureRecognizer:)]) {
                [target addGestureRecognizer:tripleFinger];
            }
        }

        // 3. Screen Edge Pan (Right Edge Swipe)
        if (swipeCls && [target isKindOfClass:[UIWindow class]]) {
            id edgePan = [[swipeCls alloc] initWithTarget:self action:@selector(toggleMenuVisibility)];
            SEL setEdges = NSSelectorFromString(@"setEdges:");
            SEL setCancels = NSSelectorFromString(@"setCancelsTouchesInView:");
            if ([edgePan respondsToSelector:setEdges]) {
                ((void (*)(id, SEL, NSUInteger))objc_msgSend)(edgePan, setEdges, 1 << 3 /* UIRectEdgeRight */);
            }
            if ([edgePan respondsToSelector:setCancels]) {
                ((void (*)(id, SEL, BOOL))objc_msgSend)(edgePan, setCancels, NO);
            }
            if ([edgePan respondsToSelector:@selector(setDelegate:)]) {
                ((void (*)(id, SEL, id))objc_msgSend)(edgePan, @selector(setDelegate:), (id)self);
            }
            if ([target respondsToSelector:@selector(addGestureRecognizer:)]) {
                [target addGestureRecognizer:edgePan];
            }
        }
    } @catch (NSException *e) {
        NSLog(@"[RaveApexCore] installFailsafeGestureOnWindow exception: %@", e);
    }
}

- (void)mountOverlayWithAttemptsRemaining:(NSInteger)attempts {
    dispatch_async(dispatch_get_main_queue(), ^{
        UIWindow *hostWindow = [self findHostWindow];
        UIWindow *overlay = [self ensureOverlayWindow];

        // Resilient mount target:
        // Dedicated overlay window requires an active windowScene on iOS 13-18.
        // If overlay window has an active scene, use overlay.rootViewController.view.
        // If not, mount DIRECTLY onto hostWindow so the button is 100% visible and interactive!
        BOOL overlayHasScene = (overlay && [overlay respondsToSelector:NSSelectorFromString(@"windowScene")] && [overlay windowScene] != nil);
        UIView *targetView = (overlay && overlayHasScene && overlay.rootViewController.view) ? overlay.rootViewController.view : (hostWindow.rootViewController.view ?: hostWindow);

        if (targetView) {
            [self setupFloatingButtonInView:targetView];
            if (self.floatingButton) {
                self.floatingButton.hidden = NO;
                self.floatingButton.alpha = 1.0;
                [targetView bringSubviewToFront:self.floatingButton];
            }
            NSLog(@"[RaveApexCore] Dedicated ApexOverlay floating button mounted cleanly on (%@)", [targetView class]);
        }

        @try {
            if (hostWindow) [self installFailsafeGestureOnWindow:hostWindow];
            if (overlay) [self installFailsafeGestureOnWindow:overlay];
            if (hostWindow.rootViewController.view) [self installFailsafeGestureOnWindow:hostWindow.rootViewController.view];

            // Start repeating maintenance timer (heartbeat) to ensure button is never lost or occluded
            static dispatch_once_t heartbeatOnce;
            dispatch_once(&heartbeatOnce, ^{
                [self startHeartbeatMonitor];
            });
        } @catch (NSException *e) {
            NSLog(@"[RaveApexCore] Overlay mount exception: %@", e);
        }

        if (!targetView && attempts > 0) {
            dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.25 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
                [self mountOverlayWithAttemptsRemaining:attempts - 1];
            });
            return;
        }

        if (!targetView) {
            NSLog(@"[RaveApexCore] Host window / overlay nil after retries, will mount when window appears.");
            return;
        }
    });
}

- (void)startHeartbeatMonitor {
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1.5 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        @try {
            UIWindow *overlay = [self ensureOverlayWindow];
            BOOL overlayHasScene = (overlay && [overlay respondsToSelector:NSSelectorFromString(@"windowScene")] && [overlay windowScene] != nil);
            UIWindow *host = [self findHostWindow];
            UIView *targetView = (overlay && overlayHasScene && overlay.rootViewController.view) ? overlay.rootViewController.view : (host.rootViewController.view ?: host);
            if (targetView && self.floatingButton) {
                if (self.floatingButton.superview != targetView) {
                    NSLog(@"[RaveApexCore] Heartbeat: Reparenting floating button to active targetView (%@)", [targetView class]);
                    [self.floatingButton removeFromSuperview];
                    [targetView addSubview:self.floatingButton];
                }
                [targetView bringSubviewToFront:self.floatingButton];
                self.floatingButton.hidden = NO;
                self.floatingButton.alpha = 1.0;
            } else if (targetView && !self.floatingButton) {
                [self setupFloatingButtonInView:targetView];
            }
            if (self.overlayWindow) {
                if (self.overlayWindow.hidden) self.overlayWindow.hidden = NO;
                [self.overlayWindow makeKeyAndVisible];
            }
        } @catch (NSException *e) {
            apex_log([[NSString stringWithFormat:@"[FAULT] Heartbeat: %@", e.reason] UTF8String]);
        }
        [self startHeartbeatMonitor];
    });
}

- (void)attachToWindow:(UIWindow *)window {
    if (!window || window == self.overlayWindow) return;

    if (![NSThread isMainThread]) {
        dispatch_async(dispatch_get_main_queue(), ^{
            [self attachToWindow:window];
        });
        return;
    }

    @try {
        self.cachedHostWindow = window;
        UIWindow *overlay = [self ensureOverlayWindow];
        BOOL overlayHasScene = (overlay && [overlay respondsToSelector:NSSelectorFromString(@"windowScene")] && [overlay windowScene] != nil);
        UIView *targetView = (overlay && overlayHasScene && overlay.rootViewController.view) ? overlay.rootViewController.view : (window.rootViewController.view ?: window);
        if (targetView) {
            [self setupFloatingButtonInView:targetView];
            if (self.floatingButton) {
                self.floatingButton.hidden = NO;
                self.floatingButton.alpha = 1.0;
                [targetView bringSubviewToFront:self.floatingButton];
            }
        }
        [self installFailsafeGestureOnWindow:window];
        if (window.rootViewController.view) [self installFailsafeGestureOnWindow:window.rootViewController.view];
    } @catch (NSException *e) {
        NSLog(@"[RaveApexCore] attachToWindow guarded exception: %@", e);
    }
}

- (void)setupFloatingButtonInView:(UIView *)parentView {
    if (!parentView) return;
    if (self.floatingButton) {
        if (self.floatingButton.superview != parentView) {
            [self.floatingButton removeFromSuperview];
            [parentView addSubview:self.floatingButton];
        }
        self.floatingButton.layer.zPosition = 9999.0;
        self.floatingButton.hidden = NO;
        self.floatingButton.alpha = 1.0;
        self.floatingButton.userInteractionEnabled = YES;
        self.floatingButton.enabled = YES;
        [parentView bringSubviewToFront:self.floatingButton];
        return;
    }

    self.floatingButton = [UIButton buttonWithType:UIButtonTypeCustom];
    self.floatingButton.frame = CGRectMake(16, 140, 56, 56);
    self.floatingButton.layer.cornerRadius = 28;
    self.floatingButton.layer.zPosition = 9999.0;
    // High-visibility vibrant royal neon purple
    self.floatingButton.backgroundColor = [UIColor colorWithRed:0.48 green:0.18 blue:0.92 alpha:0.98];
    self.floatingButton.layer.borderColor = [UIColor colorWithWhite:1.0 alpha:0.95].CGColor;
    self.floatingButton.layer.borderWidth = 2.0;
    self.floatingButton.layer.shadowColor = [UIColor colorWithRed:0.65 green:0.30 blue:1.0 alpha:0.9].CGColor;
    self.floatingButton.layer.shadowOpacity = 0.85;
    self.floatingButton.layer.shadowOffset = CGSizeMake(0, 4);
    self.floatingButton.layer.shadowRadius = 12;
    self.floatingButton.clipsToBounds = NO;
    self.floatingButton.userInteractionEnabled = YES;
    self.floatingButton.enabled = YES;

    NSString *initialEmoji = [RaveApexConfig sharedConfig].customButtonEmoji ?: @"⚡";
    [self.floatingButton setTitle:initialEmoji forState:UIControlStateNormal];
    [self.floatingButton setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
    self.floatingButton.titleLabel.font = [UIFont systemFontOfSize:26 weight:UIFontWeightBold];
    [parentView addSubview:self.floatingButton];
    [self applyButtonDimensions];

    UIPanGestureRecognizer *pan = [[UIPanGestureRecognizer alloc] initWithTarget:self action:@selector(handlePan:)];
    pan.cancelsTouchesInView = NO;
    if ([pan respondsToSelector:@selector(setDelegate:)]) {
        ((void (*)(id, SEL, id))objc_msgSend)(pan, @selector(setDelegate:), (id)self);
    }
    [self.floatingButton addGestureRecognizer:pan];

    [self.floatingButton addTarget:self action:@selector(toggleMenuVisibility) forControlEvents:UIControlEventTouchUpInside];
    [parentView bringSubviewToFront:self.floatingButton];

    // One-time, impossible-to-miss load proof. If the dylib is loading at all,
    // this banner flashes on screen once, independent of scenes/Flutter z-order.
    static dispatch_once_t beaconOnce;
    dispatch_once(&beaconOnce, ^{
        [self showLoadBeaconInView:parentView];
    });
}

- (void)showLoadBeaconInView:(UIView *)parentView {
    @try {
        UIView *host = parentView.window ?: parentView;
        CGFloat w = host.bounds.size.width > 0 ? host.bounds.size.width : 390.0;
        UILabel *beacon = [[UILabel alloc] initWithFrame:CGRectMake(0, 0, w, 54)];
        beacon.text = @"⚡ RAVE APEX LOADED — tap ⚡ or 2-finger double-tap";
        beacon.textAlignment = NSTextAlignmentCenter;
        beacon.textColor = [UIColor whiteColor];
        beacon.font = [UIFont systemFontOfSize:13 weight:UIFontWeightHeavy];
        beacon.backgroundColor = [UIColor colorWithRed:0.42 green:0.12 blue:0.85 alpha:0.98];
        beacon.numberOfLines = 1;
        beacon.layer.zPosition = 100000.0;
        beacon.center = CGPointMake(w / 2.0, 70.0);
        [host addSubview:beacon];
        [host bringSubviewToFront:beacon];
        [UIView animateWithDuration:0.4 delay:5.0 options:0 animations:^{
            beacon.alpha = 0.0;
        } completion:^(BOOL finished) {
            [beacon removeFromSuperview];
        }];
    } @catch (NSException *e) {}
}

- (BOOL)gestureRecognizer:(UIGestureRecognizer *)gestureRecognizer shouldRecognizeSimultaneouslyWithGestureRecognizer:(UIGestureRecognizer *)otherGestureRecognizer {
    return YES;
}

- (BOOL)gestureRecognizer:(UIGestureRecognizer *)gestureRecognizer shouldReceiveTouch:(UITouch *)touch {
    return YES;
}

- (void)applyButtonDimensions {
    if (!self.floatingButton) return;
    BOOL isMinimal = [RaveApexConfig sharedConfig].minimalPillModeEnabled;
    CGFloat size = isMinimal ? 34.0 : 52.0;
    CGFloat fontSize = isMinimal ? 16.0 : 24.0;
    CGPoint currentCenter = self.floatingButton.center;
    self.floatingButton.bounds = CGRectMake(0, 0, size, size);
    self.floatingButton.layer.cornerRadius = size / 2.0;
    self.floatingButton.titleLabel.font = [UIFont systemFontOfSize:fontSize weight:UIFontWeightBold];
    if (self.floatingButton.superview) {
        self.floatingButton.center = currentCenter;
    }
}

- (void)handlePan:(UIPanGestureRecognizer *)pan {
    UIView *view = self.floatingButton;
    if (!view || !view.superview) return;

    CGPoint translation = [pan translationInView:view.superview];
    if (pan.state == UIGestureRecognizerStateChanged) {
        view.center = CGPointMake(view.center.x + translation.x, view.center.y + translation.y);
        [pan setTranslation:CGPointZero inView:view.superview];
    } else if (pan.state == UIGestureRecognizerStateEnded) {
        CGRect bounds = view.superview.bounds;
        CGFloat targetX = (view.center.x > bounds.size.width / 2.0) ? bounds.size.width - 36 : 36;
        CGFloat targetY = MIN(MAX(view.center.y, 80), bounds.size.height - 80);
        [UIView animateWithDuration:0.35 delay:0 usingSpringWithDamping:0.75 initialSpringVelocity:0 options:UIViewAnimationOptionCurveEaseOut animations:^{
            view.center = CGPointMake(targetX, targetY);
        } completion:nil];
    }
}

- (void)setupMenuContainerInView:(UIView *)parentView {
  @try {
    CGFloat rootW = parentView.bounds.size.width;
    CGFloat rootH = parentView.bounds.size.height;
    if (rootW < 320) rootW = [UIScreen mainScreen].bounds.size.width;
    if (rootH < 480) rootH = [UIScreen mainScreen].bounds.size.height;
    if (rootW < 320) rootW = 375;
    if (rootH < 480) rootH = 667;

    NSInteger sizePref = [[NSUserDefaults standardUserDefaults] integerForKey:@"rave_apex_menu_size"]; // 0=Compact 1=Normal 2=Large
    CGFloat targetW = (sizePref == 0) ? 304 : (sizePref == 2) ? 372 : 340;
    CGFloat targetH = (sizePref == 0) ? 484 : (sizePref == 2) ? 648 : 560;
    if (targetW > rootW - 16) targetW = MAX(280, rootW - 16);
    if (targetH > rootH - 90) targetH = MAX(400, rootH - 90);

    UIBlurEffect *blur = [UIBlurEffect effectWithStyle:UIBlurEffectStyleDark];
    self.menuContainer = [[UIVisualEffectView alloc] initWithEffect:blur];
    self.menuContainer.frame = CGRectMake((rootW - targetW) / 2.0, 90, targetW, targetH);
    self.menuContainer.layer.cornerRadius = 24;
    self.menuContainer.layer.borderWidth = 1.0;
    self.menuContainer.layer.borderColor = [UIColor colorWithWhite:1.0 alpha:0.18].CGColor;
    self.menuContainer.layer.zPosition = 9998.0;
    self.menuContainer.clipsToBounds = YES;
    self.menuContainer.alpha = 0.0;
    self.menuContainer.transform = CGAffineTransformMakeScale(0.88, 0.88);

    UIView *content = self.menuContainer.contentView;

    // Draggable header strip (grab the top to move the whole menu).
    UIView *dragStrip = [[UIView alloc] initWithFrame:CGRectMake(0, 0, targetW, 50)];
    dragStrip.backgroundColor = [UIColor clearColor];
    UIPanGestureRecognizer *drag = [[UIPanGestureRecognizer alloc] initWithTarget:self action:@selector(handleMenuDrag:)];
    [dragStrip addGestureRecognizer:drag];
    [content addSubview:dragStrip];
    UIView *grabber = [[UIView alloc] initWithFrame:CGRectMake((targetW - 36) / 2.0, 5, 36, 4)];
    grabber.backgroundColor = [UIColor colorWithWhite:1.0 alpha:0.3];
    grabber.layer.cornerRadius = 2.0;
    grabber.userInteractionEnabled = NO;
    [dragStrip addSubview:grabber];

    // Header
    UILabel *title = [[UILabel alloc] initWithFrame:CGRectMake(20, 14, 300, 22)];
    title.text = @"⚡ RAVE APEX ARBITRATION v5.0";
    title.textColor = [UIColor whiteColor];
    title.font = [UIFont systemFontOfSize:15.5 weight:UIFontWeightHeavy];
    [content addSubview:title];

    UILabel *sub = [[UILabel alloc] initWithFrame:CGRectMake(20, 36, 260, 14)];
    sub.text = @"Tap ❓ for a simple guide to everything";
    sub.textColor = [UIColor colorWithRed:0.7 green:0.45 blue:1.0 alpha:1.0];
    sub.font = [UIFont systemFontOfSize:10 weight:UIFontWeightMedium];
    [content addSubview:sub];

    // Header ❓ Guide button (top-right)
    UIButton *guideBtn = [UIButton buttonWithType:UIButtonTypeSystem];
    guideBtn.frame = CGRectMake(targetW - 46, 12, 34, 26);
    [guideBtn setTitle:@"❓" forState:UIControlStateNormal];
    guideBtn.titleLabel.font = [UIFont systemFontOfSize:18 weight:UIFontWeightBold];
    [guideBtn addTarget:self action:@selector(showGuide) forControlEvents:UIControlEventTouchUpInside];
    [content addSubview:guideBtn];

    // Segmented Tab Selector (6 Distinct Tabs)
    NSArray *tabs = @[@"Roles", @"Audio", @"Media", @"Telem", @"Troll", @"⚙️"];
    self.tabSelector = [[UISegmentedControl alloc] initWithItems:tabs];
    self.tabSelector.frame = CGRectMake(14, 56, 312, 28);
    self.tabSelector.selectedSegmentIndex = 0;
    self.tabSelector.backgroundColor = [UIColor colorWithWhite:0.1 alpha:0.8];
    self.tabSelector.selectedSegmentTintColor = [UIColor colorWithRed:0.52 green:0.25 blue:0.95 alpha:1.0];
    [self.tabSelector setTitleTextAttributes:@{@"NSColor": [UIColor whiteColor], @"NSFont": [UIFont systemFontOfSize:10.5 weight:UIFontWeightBold]} forState:UIControlStateNormal];
    [self.tabSelector addTarget:self action:@selector(tabChanged:) forControlEvents:UIControlEventValueChanged];
    [content addSubview:self.tabSelector];

    // Create 6 scrollable tab views (Roles / Audio / Media / Telemetry / Troll / Pro)
    CGRect tabFrame = CGRectMake(0, 90, targetW, targetH - 150);
    UIScrollView *roleView = [[UIScrollView alloc] initWithFrame:tabFrame];
    UIScrollView *audioView = [[UIScrollView alloc] initWithFrame:tabFrame];
    UIScrollView *mediaView = [[UIScrollView alloc] initWithFrame:tabFrame];
    UIScrollView *telemetryView = [[UIScrollView alloc] initWithFrame:tabFrame];
    UIScrollView *trollView = [[UIScrollView alloc] initWithFrame:tabFrame];
    UIScrollView *proView = [[UIScrollView alloc] initWithFrame:tabFrame];

    for (UIScrollView *sv in @[roleView, audioView, mediaView, telemetryView, trollView, proView]) {
        sv.showsVerticalScrollIndicator = YES;
        sv.alwaysBounceVertical = YES;
    }

    [self setupRolesTab:roleView];
    [self setupAudioTab:audioView];
    [self setupMediaTab:mediaView];
    [self setupTelemetryTab:telemetryView];
    [self setupTrollTab:trollView];
    [self setupProTab:proView];

    audioView.hidden = YES;
    mediaView.hidden = YES;
    telemetryView.hidden = YES;
    trollView.hidden = YES;
    proView.hidden = YES;

    self.tabViews = @[roleView, audioView, mediaView, telemetryView, trollView, proView];
    for (UIView *tv in self.tabViews) {
        [content addSubview:tv];
    }

    // Telemetry Footer
    self.telemetryLabel = [[UILabel alloc] initWithFrame:CGRectMake(14, 502, 312, 48)];
    self.telemetryLabel.numberOfLines = 2;
    self.telemetryLabel.textColor = [UIColor colorWithRed:0.4 green:0.95 blue:0.65 alpha:1.0];
    self.telemetryLabel.font = [UIFont monospacedSystemFontOfSize:9.5 weight:UIFontWeightRegular];
    self.telemetryLabel.text = @"SYNC TELEMETRY: SyncManager STANDBY\nDrift: +0.00ms | Health: OK | CPU: 0.0%";
    self.telemetryLabel.backgroundColor = [UIColor colorWithWhite:0.0 alpha:0.45];
    self.telemetryLabel.layer.cornerRadius = 8;
    self.telemetryLabel.clipsToBounds = YES;
    [content addSubview:self.telemetryLabel];

    [parentView addSubview:self.menuContainer];

    // Apply the user's saved menu theme to the freshly-built surface.
    [self applyMenuTheme];
  } @catch (NSException *e) {
    NSLog(@"[RaveApexCore] setupMenuContainerInView guarded exception: %@", e);
    // Discard any partially-built surface so toggleMenuVisibility's circuit breaker
    // trips and a later tap can retry a clean build instead of animating a dead view.
    @try { [self.menuContainer removeFromSuperview]; } @catch (NSException *ignored) {
        apex_log([[NSString stringWithFormat:@"[FAULT] setupMenuContainer tear-down: %@", ignored.reason] UTF8String]);
    }
    self.menuContainer = nil;
    self.tabSelector = nil;
    self.tabViews = nil;
    self.telemetryLabel = nil;
  }
}

- (void)tabChanged:(UISegmentedControl *)seg {
    if (!seg || self.tabViews.count == 0) return;
    [self fireHaptic];
    NSInteger sel = seg.selectedSegmentIndex;
    for (NSUInteger i = 0; i < self.tabViews.count; i++) {
        UIView *tv = self.tabViews[i];
        if ((NSInteger)i == sel) {
            tv.hidden = NO;
            tv.alpha = 0.0;
            [UIView animateWithDuration:0.22 animations:^{ tv.alpha = 1.0; }];
        } else {
            tv.hidden = YES;
            tv.alpha = 1.0;
        }
    }
}

// ------------------------------------------------------------------------------
// TAB 0: ROLES & ROOM ARBITRATION (7 TOGGLES)
// ------------------------------------------------------------------------------
- (void)setupRolesTab:(UIView *)view {
    CGFloat y = 4;
    y = [self addToggle:@"Crown Badge Spoof" sub:@"Force leader badge rendering on local avatar" state:[RaveApexConfig sharedConfig].crownSpoofEnabled tag:301 y:y inView:view];
    y = [self addToggle:@"Local Playback Authority" sub:@"Bypass follower seek/pause locks in room" state:[RaveApexConfig sharedConfig].localHostControlOverride tag:302 y:y inView:view];
    y = [self addToggle:@"Anti-Kick Guard" sub:@"Intercept remote kick events & retain room session" state:[RaveApexConfig sharedConfig].antiKickInterceptionEnabled tag:303 y:y inView:view];
    y = [self addToggle:@"Auto-Rejoin Guard" sub:@"Auto-reconnect to room on unexpected kick/demote" state:[RaveApexConfig sharedConfig].autoRejoinEnabled tag:338 y:y inView:view];
    y = [self addToggle:@"Vote Quorum Autopilot" sub:@"Auto-cast affirmative ballots on video transitions" state:[RaveApexConfig sharedConfig].voteQuorumAutopilotEnabled tag:304 y:y inView:view];
    y = [self addToggle:@"Decoupled Free Desync" sub:@"Isolate client clock to scrub without rubberband" state:[RaveApexConfig sharedConfig].unhookedSyncEnabled tag:305 y:y inView:view];
    y = [self addToggle:@"Omni-Leader Elevation" sub:@"Unlock Kick & Transfer Crown on all users" state:[RaveApexConfig sharedConfig].omniLeaderElevationEnabled tag:306 y:y inView:view];
    y = [self addToggle:@"Ghost Room Presence" sub:@"Conceal presence & speaking state in room" state:[RaveApexConfig sharedConfig].ghostPresenceEnabled tag:324 y:y inView:view];
    y = [self addToggle:@"Phantom Crown Lock" sub:@"Permanent sovereign lock; ignore demote/transfer" state:[RaveApexConfig sharedConfig].phantomCrownLockEnabled tag:325 y:y inView:view];

    UIButton *privBtn = [UIButton buttonWithType:UIButtonTypeSystem];
    privBtn.frame = CGRectMake(20, y + 4, 300, 32);
    privBtn.backgroundColor = [UIColor colorWithRed:0.35 green:0.2 blue:0.55 alpha:0.85];
    privBtn.layer.cornerRadius = 8;
    privBtn.layer.borderColor = [UIColor colorWithRed:0.6 green:0.4 blue:0.95 alpha:0.6].CGColor;
    privBtn.layer.borderWidth = 1.0;
    [privBtn setTitle:@"🔒 Toggle Room Privacy (Public/Private)" forState:UIControlStateNormal];
    [privBtn setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
    privBtn.titleLabel.font = [UIFont systemFontOfSize:11 weight:UIFontWeightBold];
    [privBtn addTarget:self action:@selector(toggleRoomPrivacyAction) forControlEvents:UIControlEventTouchUpInside];
    [view addSubview:privBtn];
    y += 42;

    if ([view isKindOfClass:[UIScrollView class]]) ((UIScrollView *)view).contentSize = CGSizeMake(340, y + 20);
}

// ------------------------------------------------------------------------------
// TAB 1: AUDIO & VOIP STREAM PIPELINE (10.0x HARDWARE PREAMP + CONTROLS)
// ------------------------------------------------------------------------------
- (void)setupAudioTab:(UIView *)view {
    CGFloat y = 4;

    UILabel *pLbl = [[UILabel alloc] initWithFrame:CGRectMake(20, y, 190, 16)];
    pLbl.text = @"AudioProcessor Preamp Boost";
    pLbl.textColor = [UIColor whiteColor];
    pLbl.font = [UIFont systemFontOfSize:12 weight:UIFontWeightSemibold];
    [view addSubview:pLbl];

    self.preampValueLabel = [[UILabel alloc] initWithFrame:CGRectMake(215, y, 105, 16)];
    self.preampValueLabel.text = [NSString stringWithFormat:@"%.1fx (+%d%%)", [RaveApexConfig sharedConfig].audioPreampVolume, (int)(([RaveApexConfig sharedConfig].audioPreampVolume - 1.0) * 100)];
    self.preampValueLabel.textColor = [UIColor colorWithRed:0.3 green:0.85 blue:1.0 alpha:1.0];
    self.preampValueLabel.textAlignment = NSTextAlignmentRight;
    self.preampValueLabel.font = [UIFont monospacedDigitSystemFontOfSize:11.5 weight:UIFontWeightBold];
    [view addSubview:self.preampValueLabel];
    y += 20;

    self.preampSlider = [[UISlider alloc] initWithFrame:CGRectMake(20, y, 300, 24)];
    self.preampSlider.minimumValue = 1.0;
    self.preampSlider.maximumValue = 10.0; // [GODMODE] Boost up to 1000%
    self.preampSlider.value = [RaveApexConfig sharedConfig].audioPreampVolume;
    self.preampSlider.tintColor = [UIColor colorWithRed:0.25 green:0.75 blue:1.0 alpha:1.0];
    [self.preampSlider addTarget:self action:@selector(preampChanged:) forControlEvents:UIControlEventValueChanged];
    [view addSubview:self.preampSlider];
    y += 32;

    y = [self addToggle:@"Hardware Preamp Enabler" sub:@"Activate CoreAudio gain booster pipeline" state:[RaveApexConfig sharedConfig].audioPreampBoostEnabled tag:307 y:y inView:view];
    y = [self addToggle:@"Continuous Mic Stream" sub:@"Override push-to-talk locks & local mute gating" state:[RaveApexConfig sharedConfig].forceMicTransmissionEnabled tag:308 y:y inView:view];
    y = [self addToggle:@"Stealth Ghost Listener" sub:@"Suppress talkingUsers broadcast while receiving" state:[RaveApexConfig sharedConfig].stealthGhostListenerEnabled tag:309 y:y inView:view];
    y = [self addToggle:@"Background Audio Lock" sub:@"Keep AVAudioSession alive when screen is locked" state:[RaveApexConfig sharedConfig].backgroundAudioEnabled tag:310 y:y inView:view];
    y = [self addToggle:@"Dual Stream Audio Routing" sub:@"Separate VoIP stream from media stream gain" state:[RaveApexConfig sharedConfig].dualStreamAudioBalanceEnabled tag:311 y:y inView:view];
    y = [self addToggle:@"Dynamic Voice Ducking" sub:@"Auto-attenuate media -14dB when peers speak" state:[RaveApexConfig sharedConfig].voiceDuckingEnabled tag:326 y:y inView:view];
    y = [self addToggle:@"Dialogue Vocal EQ" sub:@"Boost speech clarity & mid frequencies" state:[RaveApexConfig sharedConfig].dialogueEqEnabled tag:327 y:y inView:view];

    UILabel *eqLbl = [[UILabel alloc] initWithFrame:CGRectMake(20, y, 190, 16)];
    eqLbl.text = @"Audio DSP EQ Preset";
    eqLbl.textColor = [UIColor whiteColor];
    eqLbl.font = [UIFont systemFontOfSize:12 weight:UIFontWeightSemibold];
    [view addSubview:eqLbl];
    y += 20;

    NSArray *eqItems = @[@"Flat", @"Bass+6dB", @"Vocal", @"Treble"];
    UISegmentedControl *eqSeg = [[UISegmentedControl alloc] initWithItems:eqItems];
    eqSeg.frame = CGRectMake(20, y, 300, 28);
    eqSeg.selectedSegmentIndex = [RaveApexConfig sharedConfig].audioEqPreset;
    eqSeg.backgroundColor = [UIColor colorWithWhite:0.1 alpha:0.8];
    eqSeg.selectedSegmentTintColor = [UIColor colorWithRed:0.25 green:0.65 blue:0.95 alpha:1.0];
    [eqSeg setTitleTextAttributes:@{@"NSColor": [UIColor whiteColor], @"NSFont": [UIFont systemFontOfSize:10 weight:UIFontWeightBold]} forState:UIControlStateNormal];
    [eqSeg addTarget:self action:@selector(audioEqPresetChanged:) forControlEvents:UIControlEventValueChanged];
    [view addSubview:eqSeg];
    y += 36;

    UIButton *sfxBtn = [UIButton buttonWithType:UIButtonTypeSystem];
    sfxBtn.frame = CGRectMake(20, y + 2, 300, 32);
    sfxBtn.backgroundColor = [UIColor colorWithRed:0.18 green:0.35 blue:0.55 alpha:0.85];
    sfxBtn.layer.cornerRadius = 8;
    sfxBtn.layer.borderColor = [UIColor colorWithRed:0.3 green:0.6 blue:0.95 alpha:0.6].CGColor;
    sfxBtn.layer.borderWidth = 1.0;
    [sfxBtn setTitle:@"Trigger VoIP SFX (Beep/Boop)" forState:UIControlStateNormal];
    [sfxBtn setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
    sfxBtn.titleLabel.font = [UIFont systemFontOfSize:11 weight:UIFontWeightBold];
    [sfxBtn addTarget:self action:@selector(triggerVoipSFX) forControlEvents:UIControlEventTouchUpInside];
    [view addSubview:sfxBtn];

    UIButton *unmuteBtn = [UIButton buttonWithType:UIButtonTypeSystem];
    unmuteBtn.frame = CGRectMake(20, y + 40, 300, 32);
    unmuteBtn.backgroundColor = [UIColor colorWithRed:0.15 green:0.45 blue:0.3 alpha:0.85];
    unmuteBtn.layer.cornerRadius = 8;
    unmuteBtn.layer.borderColor = [UIColor colorWithRed:0.3 green:0.85 blue:0.55 alpha:0.6].CGColor;
    unmuteBtn.layer.borderWidth = 1.0;
    [unmuteBtn setTitle:@"Force Unmute Everyone" forState:UIControlStateNormal];
    [unmuteBtn setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
    unmuteBtn.titleLabel.font = [UIFont systemFontOfSize:11 weight:UIFontWeightBold];
    [unmuteBtn addTarget:self action:@selector(forceUnmuteAll) forControlEvents:UIControlEventTouchUpInside];
    [view addSubview:unmuteBtn];

    UIButton *turboBtn = [UIButton buttonWithType:UIButtonTypeSystem];
    turboBtn.frame = CGRectMake(20, y + 78, 300, 32);
    turboBtn.backgroundColor = [UIColor colorWithRed:0.65 green:0.15 blue:0.25 alpha:0.85];
    turboBtn.layer.cornerRadius = 8;
    turboBtn.layer.borderColor = [UIColor colorWithRed:1.0 green:0.3 blue:0.4 alpha:0.6].CGColor;
    turboBtn.layer.borderWidth = 1.0;
    [turboBtn setTitle:@"💥 Turbo Preamp Boost (15.0x / +1400%)" forState:UIControlStateNormal];
    [turboBtn setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
    turboBtn.titleLabel.font = [UIFont systemFontOfSize:11 weight:UIFontWeightBold];
    [turboBtn addTarget:self action:@selector(triggerTurboPreamp) forControlEvents:UIControlEventTouchUpInside];
    [view addSubview:turboBtn];

    UIButton *beepBtn = [UIButton buttonWithType:UIButtonTypeSystem];
    beepBtn.frame = CGRectMake(20, y + 116, 145, 30);
    beepBtn.backgroundColor = [UIColor colorWithRed:0.2 green:0.35 blue:0.55 alpha:0.85];
    beepBtn.layer.cornerRadius = 8;
    [beepBtn setTitle:@"🔊 Play Beep SFX" forState:UIControlStateNormal];
    [beepBtn setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
    beepBtn.titleLabel.font = [UIFont systemFontOfSize:10.5 weight:UIFontWeightBold];
    [beepBtn addTarget:self action:@selector(playBeepSFX) forControlEvents:UIControlEventTouchUpInside];
    [view addSubview:beepBtn];

    UIButton *boopBtn = [UIButton buttonWithType:UIButtonTypeSystem];
    boopBtn.frame = CGRectMake(175, y + 116, 145, 30);
    boopBtn.backgroundColor = [UIColor colorWithRed:0.2 green:0.35 blue:0.55 alpha:0.85];
    boopBtn.layer.cornerRadius = 8;
    [boopBtn setTitle:@"🔊 Play Boop SFX" forState:UIControlStateNormal];
    [boopBtn setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
    boopBtn.titleLabel.font = [UIFont systemFontOfSize:10.5 weight:UIFontWeightBold];
    [boopBtn addTarget:self action:@selector(playBoopSFX) forControlEvents:UIControlEventTouchUpInside];
    [view addSubview:boopBtn];

    y += 156;
    if ([view isKindOfClass:[UIScrollView class]]) ((UIScrollView *)view).contentSize = CGSizeMake(340, y + 20);
}

// ------------------------------------------------------------------------------
// TAB 2: MEDIA ENGINE, CHAT & PREMIUM GODMODE
// ------------------------------------------------------------------------------
- (void)setupMediaTab:(UIView *)view {
    CGFloat y = 4;

    UILabel *sLbl = [[UILabel alloc] initWithFrame:CGRectMake(20, y, 190, 16)];
    sLbl.text = @"Hardware AVPlayer Speed";
    sLbl.textColor = [UIColor whiteColor];
    sLbl.font = [UIFont systemFontOfSize:12 weight:UIFontWeightSemibold];
    [view addSubview:sLbl];

    self.speedValueLabel = [[UILabel alloc] initWithFrame:CGRectMake(215, y, 105, 16)];
    self.speedValueLabel.text = [NSString stringWithFormat:@"%.2fx", [RaveApexConfig sharedConfig].playbackSpeed];
    self.speedValueLabel.textColor = [UIColor colorWithRed:0.75 green:0.4 blue:1.0 alpha:1.0];
    self.speedValueLabel.textAlignment = NSTextAlignmentRight;
    self.speedValueLabel.font = [UIFont monospacedDigitSystemFontOfSize:11.5 weight:UIFontWeightBold];
    [view addSubview:self.speedValueLabel];
    y += 20;

    self.speedSlider = [[UISlider alloc] initWithFrame:CGRectMake(20, y, 300, 24)];
    self.speedSlider.minimumValue = 0.10; // [GODMODE] 0.10x slow-mo
    self.speedSlider.maximumValue = 10.0; // [GODMODE] 10.0x hyper-speed
    self.speedSlider.value = [RaveApexConfig sharedConfig].playbackSpeed;
    self.speedSlider.tintColor = [UIColor colorWithRed:0.6 green:0.3 blue:1.0 alpha:1.0];
    [self.speedSlider addTarget:self action:@selector(speedChanged:) forControlEvents:UIControlEventValueChanged];
    [view addSubview:self.speedSlider];
    y += 32;

    UILabel *spLbl = [[UILabel alloc] initWithFrame:CGRectMake(20, y, 190, 14)];
    spLbl.text = @"Speed Quick Presets";
    spLbl.textColor = [UIColor whiteColor];
    spLbl.font = [UIFont systemFontOfSize:11 weight:UIFontWeightMedium];
    [view addSubview:spLbl];
    y += 18;

    NSArray *speedItems = @[@"0.5x", @"1.0x", @"1.25x", @"1.5x", @"2.0x", @"3.0x"];
    UISegmentedControl *speedSeg = [[UISegmentedControl alloc] initWithItems:speedItems];
    speedSeg.frame = CGRectMake(20, y, 300, 26);
    speedSeg.backgroundColor = [UIColor colorWithWhite:0.1 alpha:0.8];
    speedSeg.selectedSegmentTintColor = [UIColor colorWithRed:0.6 green:0.3 blue:0.95 alpha:1.0];
    [speedSeg setTitleTextAttributes:@{@"NSColor": [UIColor whiteColor], @"NSFont": [UIFont systemFontOfSize:9.5 weight:UIFontWeightBold]} forState:UIControlStateNormal];
    [speedSeg addTarget:self action:@selector(speedPresetSelected:) forControlEvents:UIControlEventValueChanged];
    [view addSubview:speedSeg];
    y += 34;

    y = [self addToggle:@"Ad Waterfall Annihilator" sub:@"Zero-cost placement suppressor" state:[RaveApexConfig sharedConfig].adBlockEnabled tag:312 y:y inView:view];
    y = [self addToggle:@"Mature Content Auto-Clear" sub:@"Strip rating prompts & mature blur" state:[RaveApexConfig sharedConfig].matureBypassEnabled tag:313 y:y inView:view];
    y = [self addToggle:@"Universal PiP Enabler" sub:@"Force AVPictureInPictureController on all feeds" state:[RaveApexConfig sharedConfig].forcePiPEnabled tag:314 y:y inView:view];
    y = [self addToggle:@"Uncapped Rate Multiplier" sub:@"Enforce custom playback clock across resumptions" state:[RaveApexConfig sharedConfig].uncappedSpeedEnabled tag:315 y:y inView:view];
    y = [self addToggle:@"Universal Premium Unlock" sub:@"Bypass Crunchyroll & SuperSearch paywalls" state:[RaveApexConfig sharedConfig].premiumBypassEnabled tag:316 y:y inView:view];
    y = [self addToggle:@"Auto-Unblur Chat Media" sub:@"Auto-decode & display blurred chat images" state:[RaveApexConfig sharedConfig].autoUnblurChatImagesEnabled tag:320 y:y inView:view];
    y = [self addToggle:@"Auto-Translate Chat" sub:@"Real-time auto-translate incoming messages" state:[RaveApexConfig sharedConfig].autoTranslateChatEnabled tag:321 y:y inView:view];
    y = [self addToggle:@"Ghost Typing Mode" sub:@"Conceal typing indicator packets" state:[RaveApexConfig sharedConfig].ghostTypingEnabled tag:322 y:y inView:view];
    y = [self addToggle:@"IAP Premium Spoof" sub:@"Force StoreKit receipt validation pass" state:[RaveApexConfig sharedConfig].iapReceiptSpoofEnabled tag:323 y:y inView:view];
    y = [self addToggle:@"Micro-Clock Slewing" sub:@"Seamless ±2% rate slewing instead of jerky seeks" state:[RaveApexConfig sharedConfig].microClockSlewingEnabled tag:328 y:y inView:view];
    y = [self addToggle:@"Highest Rendition Lock" sub:@"Force 4K/1080p60 & uncap peak bitrate" state:[RaveApexConfig sharedConfig].highestRenditionLockEnabled tag:329 y:y inView:view];
    y = [self addToggle:@"Buffer Overdrive (180s)" sub:@"Expand AVPlayerItem forward buffer cache" state:[RaveApexConfig sharedConfig].bufferOverdriveEnabled tag:330 y:y inView:view];
    y = [self addToggle:@"Auto-PiP on Background" sub:@"Trigger PiP automatically on app backgrounding" state:[RaveApexConfig sharedConfig].autoPiPOnBackground tag:339 y:y inView:view];
    y = [self addToggle:@"Auto-Loop Playback" sub:@"Restart video from 0.0s automatically on finish" state:[RaveApexConfig sharedConfig].autoLoopPlaybackEnabled tag:342 y:y inView:view];
    y = [self addToggle:@"Audio Pitch Correction" sub:@"Maintain natural vocal pitch during rate multiplier" state:[RaveApexConfig sharedConfig].pitchCorrectionEnabled tag:343 y:y inView:view];
    y = [self addToggle:@"Anti-Recall Chat Vault" sub:@"Retain deleted room messages & un-hide" state:[RaveApexConfig sharedConfig].antiRecallChatEnabled tag:331 y:y inView:view];
    y = [self addToggle:@"Pure OLED Blackout" sub:@"Force true #000000 background for power save" state:[RaveApexConfig sharedConfig].oledBlackoutThemeEnabled tag:332 y:y inView:view];

    // Jump Seek 4-Button Grid (-60s, -15s, +15s, +60s)
    UIButton *jM60 = [UIButton buttonWithType:UIButtonTypeSystem];
    jM60.frame = CGRectMake(20, y + 4, 68, 30);
    jM60.backgroundColor = [UIColor colorWithRed:0.2 green:0.25 blue:0.4 alpha:0.85];
    jM60.layer.cornerRadius = 6;
    [jM60 setTitle:@"⏮️ -60s" forState:UIControlStateNormal];
    [jM60 setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
    jM60.titleLabel.font = [UIFont systemFontOfSize:10.5 weight:UIFontWeightBold];
    [jM60 addTarget:self action:@selector(jumpBackwards60) forControlEvents:UIControlEventTouchUpInside];
    [view addSubview:jM60];

    UIButton *jM15 = [UIButton buttonWithType:UIButtonTypeSystem];
    jM15.frame = CGRectMake(94, y + 4, 68, 30);
    jM15.backgroundColor = [UIColor colorWithRed:0.2 green:0.25 blue:0.4 alpha:0.85];
    jM15.layer.cornerRadius = 6;
    [jM15 setTitle:@"⏪ -15s" forState:UIControlStateNormal];
    [jM15 setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
    jM15.titleLabel.font = [UIFont systemFontOfSize:10.5 weight:UIFontWeightBold];
    [jM15 addTarget:self action:@selector(jumpBackwards) forControlEvents:UIControlEventTouchUpInside];
    [view addSubview:jM15];

    UIButton *jP15 = [UIButton buttonWithType:UIButtonTypeSystem];
    jP15.frame = CGRectMake(168, y + 4, 68, 30);
    jP15.backgroundColor = [UIColor colorWithRed:0.2 green:0.25 blue:0.4 alpha:0.85];
    jP15.layer.cornerRadius = 6;
    [jP15 setTitle:@"⏩ +15s" forState:UIControlStateNormal];
    [jP15 setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
    jP15.titleLabel.font = [UIFont systemFontOfSize:10.5 weight:UIFontWeightBold];
    [jP15 addTarget:self action:@selector(jumpForwards) forControlEvents:UIControlEventTouchUpInside];
    [view addSubview:jP15];

    UIButton *jP60 = [UIButton buttonWithType:UIButtonTypeSystem];
    jP60.frame = CGRectMake(242, y + 4, 78, 30);
    jP60.backgroundColor = [UIColor colorWithRed:0.2 green:0.25 blue:0.4 alpha:0.85];
    jP60.layer.cornerRadius = 6;
    [jP60 setTitle:@"⏭️ +60s" forState:UIControlStateNormal];
    [jP60 setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
    jP60.titleLabel.font = [UIFont systemFontOfSize:10.5 weight:UIFontWeightBold];
    [jP60 addTarget:self action:@selector(jumpForwards60) forControlEvents:UIControlEventTouchUpInside];
    [view addSubview:jP60];
    y += 38;

    // Frame Micro-Step (CustomAVPlayer)
    UIButton *fBack = [UIButton buttonWithType:UIButtonTypeSystem];
    fBack.frame = CGRectMake(20, y + 4, 142, 28);
    fBack.backgroundColor = [UIColor colorWithRed:0.15 green:0.25 blue:0.35 alpha:0.85];
    fBack.layer.cornerRadius = 6;
    [fBack setTitle:@"⏮️ Frame -1" forState:UIControlStateNormal];
    [fBack setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
    fBack.titleLabel.font = [UIFont systemFontOfSize:10 weight:UIFontWeightBold];
    [fBack addTarget:self action:@selector(stepBackFrame) forControlEvents:UIControlEventTouchUpInside];
    [view addSubview:fBack];

    UIButton *fFwd = [UIButton buttonWithType:UIButtonTypeSystem];
    fFwd.frame = CGRectMake(178, y + 4, 142, 28);
    fFwd.backgroundColor = [UIColor colorWithRed:0.15 green:0.25 blue:0.35 alpha:0.85];
    fFwd.layer.cornerRadius = 6;
    [fFwd setTitle:@"⏭️ Frame +1" forState:UIControlStateNormal];
    [fFwd setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
    fFwd.titleLabel.font = [UIFont systemFontOfSize:10 weight:UIFontWeightBold];
    [fFwd addTarget:self action:@selector(stepForwardFrame) forControlEvents:UIControlEventTouchUpInside];
    [view addSubview:fFwd];
    y += 36;

    UIButton *qBtn = [UIButton buttonWithType:UIButtonTypeSystem];
    qBtn.frame = CGRectMake(20, y + 4, 300, 32);
    qBtn.backgroundColor = [UIColor colorWithRed:0.45 green:0.15 blue:0.25 alpha:0.85];
    qBtn.layer.cornerRadius = 8;
    qBtn.layer.borderColor = [UIColor colorWithRed:0.9 green:0.3 blue:0.4 alpha:0.6].CGColor;
    qBtn.layer.borderWidth = 1.0;
    [qBtn setTitle:@"Wipe Shared Video Queue" forState:UIControlStateNormal];
    [qBtn setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
    qBtn.titleLabel.font = [UIFont systemFontOfSize:11 weight:UIFontWeightBold];
    [qBtn addTarget:self action:@selector(resetVideoQueue) forControlEvents:UIControlEventTouchUpInside];
    [view addSubview:qBtn];

    UIButton *pipBtn = [UIButton buttonWithType:UIButtonTypeSystem];
    pipBtn.frame = CGRectMake(20, y + 42, 300, 32);
    pipBtn.backgroundColor = [UIColor colorWithRed:0.2 green:0.3 blue:0.5 alpha:0.85];
    pipBtn.layer.cornerRadius = 8;
    pipBtn.layer.borderColor = [UIColor colorWithRed:0.4 green:0.6 blue:0.95 alpha:0.6].CGColor;
    pipBtn.layer.borderWidth = 1.0;
    [pipBtn setTitle:@"Force Picture-in-Picture Now" forState:UIControlStateNormal];
    [pipBtn setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
    pipBtn.titleLabel.font = [UIFont systemFontOfSize:11 weight:UIFontWeightBold];
    [pipBtn addTarget:self action:@selector(forcePictureInPicture) forControlEvents:UIControlEventTouchUpInside];
    [view addSubview:pipBtn];

    UIButton *hdBtn = [UIButton buttonWithType:UIButtonTypeSystem];
    hdBtn.frame = CGRectMake(20, y + 80, 300, 32);
    hdBtn.backgroundColor = [UIColor colorWithRed:0.3 green:0.22 blue:0.5 alpha:0.85];
    hdBtn.layer.cornerRadius = 8;
    hdBtn.layer.borderColor = [UIColor colorWithRed:0.6 green:0.4 blue:0.95 alpha:0.6].CGColor;
    hdBtn.layer.borderWidth = 1.0;
    [hdBtn setTitle:@"Force Max HD Quality" forState:UIControlStateNormal];
    [hdBtn setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
    hdBtn.titleLabel.font = [UIFont systemFontOfSize:11 weight:UIFontWeightBold];
    [hdBtn addTarget:self action:@selector(forceHDQuality) forControlEvents:UIControlEventTouchUpInside];
    [view addSubview:hdBtn];

    UIButton *sniffBtn = [UIButton buttonWithType:UIButtonTypeSystem];
    sniffBtn.frame = CGRectMake(20, y + 118, 300, 32);
    sniffBtn.backgroundColor = [UIColor colorWithRed:0.12 green:0.42 blue:0.55 alpha:0.85];
    sniffBtn.layer.cornerRadius = 8;
    sniffBtn.layer.borderColor = [UIColor colorWithRed:0.25 green:0.75 blue:0.95 alpha:0.6].CGColor;
    sniffBtn.layer.borderWidth = 1.0;
    [sniffBtn setTitle:@"🎬 Sniff & Copy Stream URL" forState:UIControlStateNormal];
    [sniffBtn setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
    sniffBtn.titleLabel.font = [UIFont systemFontOfSize:11 weight:UIFontWeightBold];
    [sniffBtn addTarget:self action:@selector(sniffActiveStream) forControlEvents:UIControlEventTouchUpInside];
    [view addSubview:sniffBtn];

    UIButton *playPauseBtn = [UIButton buttonWithType:UIButtonTypeSystem];
    playPauseBtn.frame = CGRectMake(20, y + 156, 300, 32);
    playPauseBtn.backgroundColor = [UIColor colorWithRed:0.18 green:0.38 blue:0.58 alpha:0.85];
    playPauseBtn.layer.cornerRadius = 8;
    playPauseBtn.layer.borderColor = [UIColor colorWithRed:0.3 green:0.65 blue:0.95 alpha:0.6].CGColor;
    playPauseBtn.layer.borderWidth = 1.0;
    [playPauseBtn setTitle:@"⏯️ Toggle Play / Pause Stream" forState:UIControlStateNormal];
    [playPauseBtn setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
    playPauseBtn.titleLabel.font = [UIFont systemFontOfSize:11 weight:UIFontWeightBold];
    [playPauseBtn addTarget:self action:@selector(togglePlayPauseStream) forControlEvents:UIControlEventTouchUpInside];
    [view addSubview:playPauseBtn];
    y += 198;

    if ([view isKindOfClass:[UIScrollView class]]) ((UIScrollView *)view).contentSize = CGSizeMake(340, y + 20);
}

// ------------------------------------------------------------------------------
// TAB 3: EXTENDED TELEMETRY & HARDWARE PROFILER (3 TOGGLES + 2 ACTIONS)
// ------------------------------------------------------------------------------
- (void)setupTelemetryTab:(UIView *)view {
    CGFloat y = 4;
    y = [self addToggle:@"Floating Telemetry HUD" sub:@"Mount custom high-frequency telemetry card" state:[RaveApexConfig sharedConfig].nativeDebugOverlayVisible tag:317 y:y inView:view];
    y = [self addToggle:@"Sync Drift Monitor" sub:@"Poll playback synchronization clock" state:[RaveApexConfig sharedConfig].telemetryHUDEnabled tag:318 y:y inView:view];
    y = [self addToggle:@"CPUMonitoring Diagnostics" sub:@"Live processor metrics" state:[RaveApexConfig sharedConfig].cpuMonitoringEnabled tag:319 y:y inView:view];
    y = [self addToggle:@"Tactical Status Pill" sub:@"Compact floating HUD pill status view" state:[RaveApexConfig sharedConfig].tacticalPillEnabled tag:333 y:y inView:view];
    y = [self addToggle:@"Minimal Pill Mode" sub:@"Ultra-compact 34px micro floating button" state:[RaveApexConfig sharedConfig].minimalPillModeEnabled tag:340 y:y inView:view];
    y = [self addToggle:@"0ms Ping Spoofer" sub:@"Force 0.0ms sync display across all peers" state:[RaveApexConfig sharedConfig].pingSpoofEnabled tag:341 y:y inView:view];
    y = [self addToggle:@"Emergency Panic Shield" sub:@"Triple-tap gesture / 0ms instant cloaking" state:[RaveApexConfig sharedConfig].panicButtonEnabled tag:334 y:y inView:view];

    // Clock Skew Nudge Controls
    UILabel *nudgeTitle = [[UILabel alloc] initWithFrame:CGRectMake(20, y, 180, 16)];
    nudgeTitle.text = @"Clock Drift Nudge";
    nudgeTitle.textColor = [UIColor whiteColor];
    nudgeTitle.font = [UIFont systemFontOfSize:12 weight:UIFontWeightSemibold];
    [view addSubview:nudgeTitle];

    self.clockNudgeLabel = [[UILabel alloc] initWithFrame:CGRectMake(200, y, 120, 16)];
    self.clockNudgeLabel.text = [NSString stringWithFormat:@"%+.0fms", [RaveApexConfig sharedConfig].manualClockNudgeMs];
    self.clockNudgeLabel.textColor = [UIColor colorWithRed:0.95 green:0.8 blue:0.3 alpha:1.0];
    self.clockNudgeLabel.textAlignment = NSTextAlignmentRight;
    self.clockNudgeLabel.font = [UIFont monospacedDigitSystemFontOfSize:11.5 weight:UIFontWeightBold];
    [view addSubview:self.clockNudgeLabel];
    y += 20;

    UIButton *nudgeMinus = [UIButton buttonWithType:UIButtonTypeSystem];
    nudgeMinus.frame = CGRectMake(20, y, 80, 26);
    nudgeMinus.backgroundColor = [UIColor colorWithWhite:0.15 alpha:0.8];
    nudgeMinus.layer.cornerRadius = 6;
    [nudgeMinus setTitle:@"-50ms" forState:UIControlStateNormal];
    [nudgeMinus setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
    nudgeMinus.titleLabel.font = [UIFont systemFontOfSize:11 weight:UIFontWeightBold];
    [nudgeMinus addTarget:self action:@selector(nudgeMinusTapped) forControlEvents:UIControlEventTouchUpInside];
    [view addSubview:nudgeMinus];

    UIButton *nudgeReset = [UIButton buttonWithType:UIButtonTypeSystem];
    nudgeReset.frame = CGRectMake(110, y, 100, 26);
    nudgeReset.backgroundColor = [UIColor colorWithWhite:0.15 alpha:0.8];
    nudgeReset.layer.cornerRadius = 6;
    [nudgeReset setTitle:@"Reset (0ms)" forState:UIControlStateNormal];
    [nudgeReset setTitleColor:[UIColor colorWithWhite:0.8 alpha:1.0] forState:UIControlStateNormal];
    nudgeReset.titleLabel.font = [UIFont systemFontOfSize:11 weight:UIFontWeightBold];
    [nudgeReset addTarget:self action:@selector(nudgeResetTapped) forControlEvents:UIControlEventTouchUpInside];
    [view addSubview:nudgeReset];

    UIButton *nudgePlus = [UIButton buttonWithType:UIButtonTypeSystem];
    nudgePlus.frame = CGRectMake(220, y, 80, 26);
    nudgePlus.backgroundColor = [UIColor colorWithWhite:0.15 alpha:0.8];
    nudgePlus.layer.cornerRadius = 6;
    [nudgePlus setTitle:@"+50ms" forState:UIControlStateNormal];
    [nudgePlus setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
    nudgePlus.titleLabel.font = [UIFont systemFontOfSize:11 weight:UIFontWeightBold];
    [nudgePlus addTarget:self action:@selector(nudgePlusTapped) forControlEvents:UIControlEventTouchUpInside];
    [view addSubview:nudgePlus];
    y += 34;

    UIButton *benchBtn = [UIButton buttonWithType:UIButtonTypeSystem];
    benchBtn.frame = CGRectMake(20, y, 145, 32);
    benchBtn.backgroundColor = [UIColor colorWithRed:0.25 green:0.15 blue:0.45 alpha:0.85];
    benchBtn.layer.cornerRadius = 8;
    benchBtn.layer.borderColor = [UIColor colorWithRed:0.6 green:0.3 blue:1.0 alpha:0.6].CGColor;
    benchBtn.layer.borderWidth = 1.0;
    [benchBtn setTitle:@"Probe Bandwidth" forState:UIControlStateNormal];
    [benchBtn setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
    benchBtn.titleLabel.font = [UIFont systemFontOfSize:11 weight:UIFontWeightBold];
    [benchBtn addTarget:self action:@selector(runSpeedBenchmark) forControlEvents:UIControlEventTouchUpInside];
    [view addSubview:benchBtn];

    UIButton *diagBtn = [UIButton buttonWithType:UIButtonTypeSystem];
    diagBtn.frame = CGRectMake(175, y, 145, 32);
    diagBtn.backgroundColor = [UIColor colorWithRed:0.15 green:0.35 blue:0.35 alpha:0.85];
    diagBtn.layer.cornerRadius = 8;
    diagBtn.layer.borderColor = [UIColor colorWithRed:0.3 green:0.8 blue:0.7 alpha:0.6].CGColor;
    diagBtn.layer.borderWidth = 1.0;
    [diagBtn setTitle:@"Engine Profile" forState:UIControlStateNormal];
    [diagBtn setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
    diagBtn.titleLabel.font = [UIFont systemFontOfSize:11 weight:UIFontWeightBold];
    [diagBtn addTarget:self action:@selector(dumpEngineDiagnostics) forControlEvents:UIControlEventTouchUpInside];
    [view addSubview:diagBtn];
    y += 42;

    // ---- [NEW] Menu Opacity control -----------------------------------------
    UILabel *opLbl = [[UILabel alloc] initWithFrame:CGRectMake(20, y, 190, 16)];
    opLbl.text = @"Control Surface Opacity";
    opLbl.textColor = [UIColor whiteColor];
    opLbl.font = [UIFont systemFontOfSize:12 weight:UIFontWeightSemibold];
    [view addSubview:opLbl];
    y += 20;

    UISlider *opSlider = [[UISlider alloc] initWithFrame:CGRectMake(20, y, 300, 24)];
    opSlider.minimumValue = 0.35;
    opSlider.maximumValue = 1.0;
    opSlider.value = [self currentMenuOpacity];
    opSlider.tintColor = [UIColor colorWithRed:0.4 green:0.9 blue:0.7 alpha:1.0];
    [opSlider addTarget:self action:@selector(menuOpacityChanged:) forControlEvents:UIControlEventValueChanged];
    [view addSubview:opSlider];
    y += 34;

    // ---- [NEW] Panic Hide + Reset All ---------------------------------------
    UIButton *panicBtn = [UIButton buttonWithType:UIButtonTypeSystem];
    panicBtn.frame = CGRectMake(20, y, 145, 32);
    panicBtn.backgroundColor = [UIColor colorWithRed:0.4 green:0.3 blue:0.1 alpha:0.85];
    panicBtn.layer.cornerRadius = 8;
    [panicBtn setTitle:@"Panic Hide (8s)" forState:UIControlStateNormal];
    [panicBtn setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
    panicBtn.titleLabel.font = [UIFont systemFontOfSize:11 weight:UIFontWeightBold];
    [panicBtn addTarget:self action:@selector(panicHideOverlay) forControlEvents:UIControlEventTouchUpInside];
    [view addSubview:panicBtn];

    UIButton *resetBtn = [UIButton buttonWithType:UIButtonTypeSystem];
    resetBtn.frame = CGRectMake(175, y, 145, 32);
    resetBtn.backgroundColor = [UIColor colorWithRed:0.45 green:0.12 blue:0.12 alpha:0.85];
    resetBtn.layer.cornerRadius = 8;
    [resetBtn setTitle:@"Reset All Settings" forState:UIControlStateNormal];
    [resetBtn setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
    resetBtn.titleLabel.font = [UIFont systemFontOfSize:11 weight:UIFontWeightBold];
    [resetBtn addTarget:self action:@selector(resetAllSettings) forControlEvents:UIControlEventTouchUpInside];
    [view addSubview:resetBtn];
    y += 40;

    // ---- [NEW] Apex Log viewer + full host-symbol dump ----------------------
    UIButton *logBtn = [UIButton buttonWithType:UIButtonTypeSystem];
    logBtn.frame = CGRectMake(20, y, 145, 32);
    logBtn.backgroundColor = [UIColor colorWithRed:0.12 green:0.3 blue:0.2 alpha:0.85];
    logBtn.layer.cornerRadius = 8;
    [logBtn setTitle:@"📜 Apex Log" forState:UIControlStateNormal];
    [logBtn setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
    logBtn.titleLabel.font = [UIFont systemFontOfSize:11 weight:UIFontWeightBold];
    [logBtn addTarget:self action:@selector(showApexLog) forControlEvents:UIControlEventTouchUpInside];
    [view addSubview:logBtn];

    UIButton *symBtn = [UIButton buttonWithType:UIButtonTypeSystem];
    symBtn.frame = CGRectMake(175, y, 145, 32);
    symBtn.backgroundColor = [UIColor colorWithRed:0.2 green:0.18 blue:0.35 alpha:0.85];
    symBtn.layer.cornerRadius = 8;
    [symBtn setTitle:@"🧬 Dump Symbols" forState:UIControlStateNormal];
    [symBtn setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
    symBtn.titleLabel.font = [UIFont systemFontOfSize:11 weight:UIFontWeightBold];
    [symBtn addTarget:self action:@selector(dumpHostSymbols) forControlEvents:UIControlEventTouchUpInside];
    [view addSubview:symBtn];
    y += 40;

    BOOL hostOn = [[NSUserDefaults standardUserDefaults] boolForKey:@"rave_apex_host_hooks"];
    UIButton *hostBtn = [UIButton buttonWithType:UIButtonTypeSystem];
    hostBtn.frame = CGRectMake(20, y, 300, 32);
    hostBtn.backgroundColor = hostOn ? [UIColor colorWithRed:0.5 green:0.15 blue:0.15 alpha:0.9]
                                     : [UIColor colorWithRed:0.15 green:0.35 blue:0.2 alpha:0.9];
    hostBtn.layer.cornerRadius = 8;
    [hostBtn setTitle:(hostOn ? @"⚠️ Host Hooks: ON — tap to disable" : @"Host Hooks: OFF (safe) — tap to enable")
             forState:UIControlStateNormal];
    [hostBtn setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
    hostBtn.titleLabel.font = [UIFont systemFontOfSize:11 weight:UIFontWeightBold];
    hostBtn.tag = 7777;
    [hostBtn addTarget:self action:@selector(toggleHostHooks:) forControlEvents:UIControlEventTouchUpInside];
    [view addSubview:hostBtn];
    y += 40;

    UIButton *emojiBtn = [UIButton buttonWithType:UIButtonTypeSystem];
    emojiBtn.frame = CGRectMake(20, y, 300, 32);
    emojiBtn.backgroundColor = [UIColor colorWithRed:0.35 green:0.22 blue:0.5 alpha:0.85];
    emojiBtn.layer.cornerRadius = 8;
    emojiBtn.layer.borderColor = [UIColor colorWithRed:0.6 green:0.4 blue:0.95 alpha:0.6].CGColor;
    emojiBtn.layer.borderWidth = 1.0;
    [emojiBtn setTitle:@"⚡ Cycle Button Icon (⚡/👑/🛡️/🔥/🛸/💎)" forState:UIControlStateNormal];
    [emojiBtn setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
    emojiBtn.titleLabel.font = [UIFont systemFontOfSize:11 weight:UIFontWeightBold];
    [emojiBtn addTarget:self action:@selector(cycleFloatingButtonIcon) forControlEvents:UIControlEventTouchUpInside];
    [view addSubview:emojiBtn];
    y += 40;

    UIButton *copyRepBtn = [UIButton buttonWithType:UIButtonTypeSystem];
    copyRepBtn.frame = CGRectMake(20, y, 300, 32);
    copyRepBtn.backgroundColor = [UIColor colorWithRed:0.18 green:0.42 blue:0.38 alpha:0.85];
    copyRepBtn.layer.cornerRadius = 8;
    copyRepBtn.layer.borderColor = [UIColor colorWithRed:0.3 green:0.85 blue:0.7 alpha:0.6].CGColor;
    copyRepBtn.layer.borderWidth = 1.0;
    [copyRepBtn setTitle:@"📋 Copy Diagnostics & Logs to Clipboard" forState:UIControlStateNormal];
    [copyRepBtn setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
    copyRepBtn.titleLabel.font = [UIFont systemFontOfSize:11 weight:UIFontWeightBold];
    [copyRepBtn addTarget:self action:@selector(copyAllDiagnosticsToClipboard) forControlEvents:UIControlEventTouchUpInside];
    [view addSubview:copyRepBtn];
    y += 42;

    if ([view isKindOfClass:[UIScrollView class]]) ((UIScrollView *)view).contentSize = CGSizeMake(340, y + 20);
}

// ==============================================================================
// [NEW] FEATURE ACTIONS (low-crash-risk, main-thread, fully guarded)
// ==============================================================================

- (void)fireHaptic {
    @try {
        if (@available(iOS 10.0, *)) {
            UIImpactFeedbackGenerator *gen = [[UIImpactFeedbackGenerator alloc] initWithStyle:UIImpactFeedbackStyleLight];
            [gen prepare];
            [gen impactOccurred];
        }
    } @catch (NSException *e) {
        apex_log([[NSString stringWithFormat:@"[FAULT] Haptic: %@", e.reason] UTF8String]);
    }
}

- (CGFloat)currentMenuOpacity {
    double v = [[NSUserDefaults standardUserDefaults] doubleForKey:@"rave_apex_menu_opacity"];
    return (v >= 0.35 && v <= 1.0) ? (CGFloat)v : 1.0;
}

- (void)menuOpacityChanged:(UISlider *)slider {
    CGFloat v = roundf(slider.value * 100.0) / 100.0;
    [[NSUserDefaults standardUserDefaults] setDouble:v forKey:@"rave_apex_menu_opacity"];
    if (self.menuContainer && self.isMenuOpen) {
        self.menuContainer.alpha = v;
    }
    [self fireHaptic];
}

- (void)panicHideOverlay {
    if (self.isMenuOpen) [self toggleMenuVisibility];
    if (self.floatingButton) self.floatingButton.hidden = YES;
    if (self.backdropView) self.backdropView.hidden = YES;
    if (self.menuContainer) self.menuContainer.hidden = YES;
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(8.0 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        if (self.floatingButton) self.floatingButton.hidden = NO;
    });
}

- (void)resetAllSettings {
    @try {
        NSUserDefaults *d = [NSUserDefaults standardUserDefaults];
        for (NSString *k in @[@"rave_apex_crown_spoof", @"rave_apex_local_host", @"rave_apex_anti_kick",
                              @"rave_apex_vote_autopilot", @"rave_apex_unhooked_sync", @"rave_apex_omni_leader",
                              @"rave_apex_ghost_presence", @"rave_apex_phantom_crown",
                              @"rave_apex_preamp_en", @"rave_apex_preamp_vol", @"rave_apex_force_mic",
                              @"rave_apex_stealth_ghost", @"rave_apex_bg_audio", @"rave_apex_dual_stream",
                              @"rave_apex_voice_ducking", @"rave_apex_dialogue_eq",
                              @"rave_apex_adblock", @"rave_apex_mature_bypass", @"rave_apex_force_pip",
                              @"rave_apex_speed_en", @"rave_apex_playback_speed", @"rave_apex_premium_bypass",
                              @"rave_apex_auto_unblur", @"rave_apex_auto_translate", @"rave_apex_ghost_typing",
                              @"rave_apex_anti_recall", @"rave_apex_iap_spoof", @"rave_apex_oled_theme",
                              @"rave_apex_micro_slewing", @"rave_apex_hd_lock", @"rave_apex_buffer_overdrive",
                              @"unblurAllChatImages", @"autoTranslate",
                              @"rave_apex_telemetry_hud", @"rave_apex_tactical_pill", @"rave_apex_native_dbg_visible",
                              @"rave_apex_clock_nudge", @"rave_apex_cpu_mon", @"rave_apex_panic_btn", @"rave_apex_menu_opacity",
                              @"rave_apex_auto_rejoin", @"rave_apex_audio_eq", @"rave_apex_ping_spoof",
                              @"rave_apex_btn_emoji", @"rave_apex_minimal_pill", @"rave_apex_auto_pip_bg", @"rave_apex_last_mesh_id"]) {
            [d removeObjectForKey:k];
        }
        [d synchronize];

        // Restore the LIVE config singleton too. Clearing NSUserDefaults alone left the
        // in-memory flags stale, so "Reset All" changed nothing observable until the next
        // app launch — the root defect behind the dead Reset button.
        [[RaveApexConfig sharedConfig] resetToDefaults];
        [[RaveApexConfig sharedConfig] save];

        // Reflect the live-driven features immediately so the UI and host agree.
        [self toggleNativeDebugOverlay]; // default is hidden -> tears the HUD card down
        [[NSNotificationCenter defaultCenter] postNotificationName:@"RaveApexPreampChangedNotification"
                                                            object:@([RaveApexConfig sharedConfig].audioPreampVolume)];

        // Collapse menu state first, THEN tear the surface down on the next runloop turn.
        // The button that fired this reset lives inside menuContainer, so freeing that
        // subtree synchronously would pull the view out from under an in-flight action.
        self.isMenuOpen = NO;
        [self.floatingButton setTitle:[RaveApexConfig sharedConfig].customButtonEmoji ?: @"⚡" forState:UIControlStateNormal];
        [self applyButtonDimensions];
        dispatch_async(dispatch_get_main_queue(), ^{
            @try { [self.menuContainer removeFromSuperview]; } @catch (NSException *ignored) {
                apex_log([[NSString stringWithFormat:@"[FAULT] resetAllSettings tear-down: %@", ignored.reason] UTF8String]);
            }
            self.menuContainer = nil;
            self.tabSelector = nil;
            self.tabViews = nil;
            self.telemetryLabel = nil;
            self.speedSlider = nil;
            self.speedValueLabel = nil;
            self.preampSlider = nil;
            self.preampValueLabel = nil;
            self.clockNudgeLabel = nil;
        });

        [self showToast:@"♻️ Settings restored to defaults"];
        [self fireHaptic];
    } @catch (NSException *e) {
        [self showToast:@"⚠️ Reset failed"];
    }
}

// ==============================================================================
// [NEW] TAB 4: TROLL / PRANK DECK (each action drives a verified Rave symbol)
// ==============================================================================
- (UIButton *)trollButton:(NSString *)title sub:(NSString *)sub y:(CGFloat)y color:(UIColor *)color action:(SEL)sel inView:(UIView *)view {
    UIButton *btn = [UIButton buttonWithType:UIButtonTypeSystem];
    btn.frame = CGRectMake(20, y, 300, 40);
    btn.backgroundColor = color;
    btn.layer.cornerRadius = 9;
    btn.layer.borderColor = [UIColor colorWithWhite:1.0 alpha:0.25].CGColor;
    btn.layer.borderWidth = 1.0;
    btn.contentHorizontalAlignment = UIControlContentHorizontalAlignmentLeft;
    btn.contentEdgeInsets = UIEdgeInsetsMake(0, 12, 0, 8);
    [btn setTitle:title forState:UIControlStateNormal];
    [btn setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
    btn.titleLabel.font = [UIFont systemFontOfSize:12.5 weight:UIFontWeightBold];
    [btn addTarget:self action:sel forControlEvents:UIControlEventTouchUpInside];
    [view addSubview:btn];

    UILabel *subLbl = [[UILabel alloc] initWithFrame:CGRectMake(24, y + 24, 292, 12)];
    subLbl.text = sub;
    subLbl.textColor = [UIColor colorWithWhite:0.8 alpha:0.9];
    subLbl.font = [UIFont systemFontOfSize:9 weight:UIFontWeightRegular];
    subLbl.userInteractionEnabled = NO;
    [view addSubview:subLbl];
    return btn;
}

- (void)setupTrollTab:(UIView *)view {
    CGFloat y = 4;
    // Section 1: Room Governance & Eviction Arsenal (The Combat Suite)
    [self trollButton:@"🛡️ Eviction Reflector 2.0" sub:@"Automatic instigator counter-kick & mute lock" y:y color:[UIColor colorWithRed:0.75 green:0.18 blue:0.25 alpha:0.95] action:@selector(triggerEvictionReflector2) inView:view]; y += 50;
    [self trollButton:@"👢 Omni-Kick Active Target" sub:@"Evict target participant from active room session" y:y color:[UIColor colorWithRed:0.7 green:0.1 blue:0.2 alpha:0.9] action:@selector(kickActiveTarget) inView:view]; y += 50;
    [self trollButton:@"🌪️ Eviction Storm (Mass Kick)" sub:@"Mass evict all participants from room" y:y color:[UIColor colorWithRed:0.75 green:0.05 blue:0.15 alpha:0.95] action:@selector(massKickRoom) inView:view]; y += 50;
    [self trollButton:@"🔒 Room Lockdown (Revoke Invites)" sub:@"Delete invite links & enforce private mode" y:y color:[UIColor colorWithRed:0.4 green:0.15 blue:0.55 alpha:0.9] action:@selector(lockdownRoom) inView:view]; y += 50;
    [self trollButton:@"👑 Sovereign Crown Seizure" sub:@"Force leader elevation & repaint host crown" y:y color:[UIColor colorWithRed:0.65 green:0.45 blue:0.1 alpha:0.9] action:@selector(seizeCrown) inView:view]; y += 50;
    [self trollButton:@"🔇 Vocal Mute Storm (Omni Mute)" sub:@"GateKeeper mute sweep across talking users" y:y color:[UIColor colorWithRed:0.35 green:0.15 blue:0.35 alpha:0.9] action:@selector(chaosMassMute) inView:view]; y += 50;
    [self trollButton:@"🔊 Force Unmute Everyone" sub:@"GateKeeper unmute sweep across room participants" y:y color:[UIColor colorWithRed:0.15 green:0.45 blue:0.3 alpha:0.9] action:@selector(forceUnmuteAll) inView:view]; y += 50;
    [self trollButton:@"🎙️ Mute Invalidation & Mic Lock" sub:@"Override host mutes & lock mic stream always open" y:y color:[UIColor colorWithRed:0.18 green:0.52 blue:0.35 alpha:0.9] action:@selector(toggleMicLock) inView:view]; y += 50;
    [self trollButton:@"🔄 Kamikaze Auto-Rejoin Loop" sub:@"Instant 200ms auto-reconnect on room eviction" y:y color:[UIColor colorWithRed:0.62 green:0.25 blue:0.1 alpha:0.9] action:@selector(triggerKamikazeRejoin) inView:view]; y += 50;

    // Section 2: Direct Playback & Stream Authority
    [self trollButton:@"⏭️ Instant Video Skip" sub:@"Force immediate skip via VideoPlayer.playSkipButtonTap" y:y color:[UIColor colorWithRed:0.18 green:0.48 blue:0.38 alpha:0.9] action:@selector(instantSkipVideo) inView:view]; y += 50;
    [self trollButton:@"🛑 Vote Anarchy (Veto Ballot)" sub:@"Terminate VoteManager session & auto-advance stream" y:y color:[UIColor colorWithRed:0.62 green:0.18 blue:0.1 alpha:0.9] action:@selector(chaosEndVoteSession) inView:view]; y += 50;
    [self trollButton:@"🗑️ Obliterate Video Queue" sub:@"GateKeeper deleteMyQueue on current mesh" y:y color:[UIColor colorWithRed:0.45 green:0.12 blue:0.25 alpha:0.9] action:@selector(resetVideoQueue) inView:view]; y += 50;
    [self trollButton:@"🌊 Reaction Flood (10x Likes)" sub:@"Rapid-fire 10x like button pulse cascade" y:y color:[UIColor colorWithRed:0.2 green:0.45 blue:0.65 alpha:0.9] action:@selector(reactionFlood) inView:view]; y += 50;
    [self trollButton:@"❤️ Send Room Like Pulse" sub:@"Trigger VideoPlayer.likeButtonPressed on stream" y:y color:[UIColor colorWithRed:0.65 green:0.15 blue:0.35 alpha:0.9] action:@selector(sendRoomLike) inView:view]; y += 50;
    [self trollButton:@"⚡ Toggle Fullscreen Mode" sub:@"Drive VideoPlayer.fullOrUnfullScreen action" y:y color:[UIColor colorWithRed:0.25 green:0.35 blue:0.6 alpha:0.9] action:@selector(toggleFullscreen) inView:view]; y += 50;

    // Section 3: Audio & Signal Warfare
    [self trollButton:@"🎙️ Stealth Audio Snooper" sub:@"Raw incoming PCM audio tap & +400% independent gain" y:y color:[UIColor colorWithRed:0.2 green:0.55 blue:0.4 alpha:0.9] action:@selector(toggleStealthAudioSnooper) inView:view]; y += 50;
    [self trollButton:@"💥 25.0x Mega-Preamp (+2400%)" sub:@"Slam AudioProcessor hardware volume to 25.0x maximum" y:y color:[UIColor colorWithRed:0.85 green:0.05 blue:0.1 alpha:0.95] action:@selector(triggerMegaPreamp) inView:view]; y += 50;
    [self trollButton:@"💥 Extreme 10.0x Earrape" sub:@"Slam AudioProcessor CoreAudio gain to 1000% maximum" y:y color:[UIColor colorWithRed:0.75 green:0.1 blue:0.15 alpha:0.9] action:@selector(chaosExtremeEarrape) inView:view]; y += 50;
    [self trollButton:@"📡 Sonic Jammer Ultra (x24 SFX)" sub:@"Barrage of 24 rapid-fire VoIP SFX burst packets" y:y color:[UIColor colorWithRed:0.65 green:0.18 blue:0.15 alpha:0.9] action:@selector(triggerSonicJammerUltra) inView:view]; y += 50;
    [self trollButton:@"📡 Sonic Jammer (x12 SFX Barrage)" sub:@"Rapid-fire 12x VoIP SFX packet storm" y:y color:[UIColor colorWithRed:0.55 green:0.25 blue:0.1 alpha:0.9] action:@selector(sonicJammer) inView:view]; y += 50;
    [self trollButton:@"📢 VoIP SFX Barrage (x8)" sub:@"Spam VoipManager beep/boop SFX x8 in room" y:y color:[UIColor colorWithRed:0.2 green:0.4 blue:0.6 alpha:0.9] action:@selector(trollBeepBarrage) inView:view]; y += 50;

    // Section 4: Clock & Stream Manipulation
    [self trollButton:@"🌀 Room Freeze Strobe" sub:@"10x temporal jitter desync: freeze remote players" y:y color:[UIColor colorWithRed:0.55 green:0.1 blue:0.55 alpha:0.9] action:@selector(triggerRoomFreezeStrobe) inView:view]; y += 50;
    [self trollButton:@"🌀 Desync Tornado 2.0 (+/-5s Warp)" sub:@"Oscillate SyncManager clock by +/-5.0s to warp clients" y:y color:[UIColor colorWithRed:0.55 green:0.1 blue:0.45 alpha:0.9] action:@selector(triggerDesyncTornado5s) inView:view]; y += 50;
    [self trollButton:@"🌀 Desync Tornado (+/-3s Warp)" sub:@"Rapidly oscillate syncOffset to desync room clients" y:y color:[UIColor colorWithRed:0.5 green:0.15 blue:0.4 alpha:0.9] action:@selector(desyncTornado) inView:view]; y += 50;
    [self trollButton:@"🕐 Chaos Clock Desync" sub:@"Randomize SyncManager syncOffset (+/- 2.0s)" y:y color:[UIColor colorWithRed:0.45 green:0.3 blue:0.1 alpha:0.9] action:@selector(trollChaosClock) inView:view]; y += 50;
    [self trollButton:@"⏯️ Poltergeist Extreme (x12)" sub:@"Rapid 12x play/pause strobe on active video stream" y:y color:[UIColor colorWithRed:0.4 green:0.1 blue:0.5 alpha:0.9] action:@selector(triggerPoltergeistExtreme) inView:view]; y += 50;
    [self trollButton:@"⏯️ Playback Poltergeist" sub:@"Rapid play/pause strobe on active VideoPlayer x8" y:y color:[UIColor colorWithRed:0.35 green:0.15 blue:0.45 alpha:0.9] action:@selector(chaosPoltergeist) inView:view]; y += 50;
    [self trollButton:@"🎛️ Speed Rave Wave" sub:@"Sweep AVPlayer rate (0.25x -> 5.0x -> 1.0x)" y:y color:[UIColor colorWithRed:0.1 green:0.4 blue:0.45 alpha:0.9] action:@selector(chaosSpeedRave) inView:view]; y += 50;

    // Section 5: Frame & Fast Seek Authority
    [self trollButton:@"⏩ Fast Forward +60s" sub:@"Seek forward one full minute on active stream" y:y color:[UIColor colorWithRed:0.2 green:0.35 blue:0.55 alpha:0.9] action:@selector(jumpForwards60) inView:view]; y += 50;
    [self trollButton:@"⏪ Fast Rewind -60s" sub:@"Seek backwards one full minute on active stream" y:y color:[UIColor colorWithRed:0.45 green:0.25 blue:0.2 alpha:0.9] action:@selector(jumpBackwards60) inView:view]; y += 50;
    [self trollButton:@"🎞️ Step Frame Forward" sub:@"Micro-step playback forward exactly +1 video frame" y:y color:[UIColor colorWithRed:0.18 green:0.45 blue:0.35 alpha:0.9] action:@selector(stepForwardFrame) inView:view]; y += 50;
    [self trollButton:@"🎞️ Step Frame Backward" sub:@"Micro-step playback backwards exactly -1 video frame" y:y color:[UIColor colorWithRed:0.35 green:0.25 blue:0.45 alpha:0.9] action:@selector(stepBackFrame) inView:view]; y += 50;

    // Section 6: Extended Godmode & Signal Operations
    [self trollButton:@"👻 Quantum Ghost Presence" sub:@"WebRTC peer mask & complete room roster invisibility" y:y color:[UIColor colorWithRed:0.28 green:0.25 blue:0.65 alpha:0.95] action:@selector(toggleQuantumGhostPresence) inView:view]; y += 50;
    [self trollButton:@"👻 Ghost Invisibility Cloak" sub:@"Stealth presence: listen to room without appearing on roster" y:y color:[UIColor colorWithRed:0.22 green:0.22 blue:0.5 alpha:0.9] action:@selector(toggleGhostCloak) inView:view]; y += 50;
    [self trollButton:@"👁️ Chat Anti-Recall & Sniffer" sub:@"Retain deleted/recalled messages in chat [DELETED]" y:y color:[UIColor colorWithRed:0.38 green:0.15 blue:0.52 alpha:0.9] action:@selector(toggleAntiRecall) inView:view]; y += 50;
    [self trollButton:@"⚡ Ping Spoofer Matrix (0ms/9999ms)" sub:@"Cycle latency telemetry: 0ms God-Ping / 9999ms Lag-Switch" y:y color:[UIColor colorWithRed:0.15 green:0.48 blue:0.62 alpha:0.9] action:@selector(cyclePingSpoofer) inView:view]; y += 50;
    [self trollButton:@"⚡ Rapid Chat / Reaction Flooder" sub:@"5x rapid typing pulse + reaction flood + copy text" y:y color:[UIColor colorWithRed:0.7 green:0.2 blue:0.5 alpha:0.9] action:@selector(triggerChatFlooder) inView:view]; y += 50;
    [self trollButton:@"📢 Fake System Announcement" sub:@"Broadcast authoritative system message toast" y:y color:[UIColor colorWithRed:0.4 green:0.25 blue:0.65 alpha:0.9] action:@selector(broadcastFakeSystemMessage) inView:view]; y += 50;
    [self trollButton:@"🔄 Reconnect & Auto-Rejoin Room" sub:@"Dispatch instant RoomClient reconnect sequence" y:y color:[UIColor colorWithRed:0.2 green:0.45 blue:0.55 alpha:0.9] action:@selector(triggerAutoRejoin) inView:view]; y += 50;
    [self trollButton:@"🧛 Session Vampire" sub:@"Extract Room Mesh ID, WebRTC Peer & stream URL to clipboard" y:y color:[UIColor colorWithRed:0.45 green:0.1 blue:0.45 alpha:0.9] action:@selector(ripSessionCredentials) inView:view]; y += 50;
    [self trollButton:@"🛡️ Emergency Panic Cloak" sub:@"Instant 0ms teardown of all overlay surfaces" y:y color:[UIColor colorWithRed:0.6 green:0.1 blue:0.1 alpha:0.9] action:@selector(panicHide) inView:view]; y += 50;

    if ([view isKindOfClass:[UIScrollView class]]) ((UIScrollView *)view).contentSize = CGSizeMake(340, y + 20);
}

// ==============================================================================
// SHARED HELPERS + ⚙️ PRO TAB (power/design features) + GUIDE
// ==============================================================================
- (UIView *)effectsHostView {
    UIView *v = self.floatingButton.superview;
    if (!v) v = self.menuContainer.superview;
    if (!v) v = self.menuContainer;
    return v;
}

- (void)nukeEverything {
    [self fireHaptic];
    @try { [self trollBeepBarrage]; } @catch (NSException *e) {}
    @try { [self chaosPoltergeist]; } @catch (NSException *e) {}
    @try { [self chaosMassMute]; } @catch (NSException *e) {}
    @try { [self desyncTornado]; } @catch (NSException *e) {}
    @try { [self chaosSpeedRave]; } @catch (NSException *e) {}
    [self showToast:@"💣 TOTAL CHAOS UNLEASHED"];
}

- (void)autoChaosTick {
    if (!self.autoChaosActive) return;
    NSArray<NSString *> *sels = @[@"trollBeepBarrage", @"chaosPoltergeist", @"chaosMassMute", @"desyncTornado", @"chaosSpeedRave", @"trollChaosClock"];
    NSString *selName = sels[arc4random_uniform((uint32_t)sels.count)];
    SEL sel = NSSelectorFromString(selName);
    if ([self respondsToSelector:sel]) {
        @try { ((void (*)(id, SEL))objc_msgSend)(self, sel); } @catch (NSException *e) {}
    }
    double delay = 10.0 + (double)arc4random_uniform(6); // 10-15s
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(delay * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{ [self autoChaosTick]; });
}

- (void)toggleAutoChaos:(UIButton *)sender {
    [self fireHaptic];
    self.autoChaosActive = !self.autoChaosActive;
    [sender setTitle:(self.autoChaosActive ? @"🤖 Auto-Chaos: ON (every ~12s)" : @"🤖 Auto-Chaos: OFF") forState:UIControlStateNormal];
    sender.backgroundColor = self.autoChaosActive ? [UIColor colorWithRed:0.6 green:0.12 blue:0.12 alpha:0.95]
                                                  : [UIColor colorWithRed:0.25 green:0.2 blue:0.4 alpha:0.9];
    if (self.autoChaosActive) { [self autoChaosTick]; [self showToast:@"🤖 Auto-Chaos armed"]; }
    else { [self showToast:@"🤖 Auto-Chaos stopped"]; }
}

// ---- Menu theme (OLED blackout) ----------------------------------------------
- (void)applyMenuTheme {
    @try {
        if (!self.menuContainer) return;
        UIView *content = self.menuContainer.contentView;
        UIView *oledBg = [content viewWithTag:4242];
        if ([RaveApexConfig sharedConfig].oledBlackoutThemeEnabled) {
            if (!oledBg) {
                oledBg = [[UIView alloc] initWithFrame:CGRectMake(0, 0, self.menuContainer.bounds.size.width, self.menuContainer.bounds.size.height)];
                oledBg.tag = 4242;
                oledBg.backgroundColor = [UIColor colorWithWhite:0.0 alpha:0.97];
                oledBg.userInteractionEnabled = NO;
                [content insertSubview:oledBg atIndex:0];
            }
            self.menuContainer.layer.borderColor = [UIColor colorWithRed:0.2 green:0.9 blue:0.6 alpha:0.7].CGColor;
        } else {
            [oledBg removeFromSuperview];
            self.menuContainer.layer.borderColor = [UIColor colorWithWhite:1.0 alpha:0.18].CGColor;
        }
    } @catch (NSException *e) {}
}

// ---- Draggable menu (pan the header strip) -----------------------------------
- (void)handleMenuDrag:(UIPanGestureRecognizer *)pan {
    if (!self.menuContainer || !self.menuContainer.superview) return;
    CGPoint t = [pan translationInView:self.menuContainer.superview];
    if (pan.state == UIGestureRecognizerStateBegan) self.menuDragStart = self.menuContainer.center;
    self.menuContainer.center = CGPointMake(self.menuDragStart.x + t.x, self.menuDragStart.y + t.y);
}

// ---- Tactical status pill (floating CPU/FPS chip) ----------------------------
- (void)updateTacticalPillCPU:(float)cpu fps:(double)fps {
    if (!self.tacticalPill || self.tacticalPill.hidden) return;
    self.tacticalPill.text = [NSString stringWithFormat:@"⚡ %.0f%%  %.0f fps", cpu, fps];
}

- (void)toggleTacticalPill:(UIButton *)sender {
    [self fireHaptic];
    RaveApexConfig *c = [RaveApexConfig sharedConfig];
    c.tacticalPillEnabled = !c.tacticalPillEnabled;
    [c save];
    [sender setTitle:(c.tacticalPillEnabled ? @"🏷️ Tactical Pill: ON" : @"🏷️ Tactical Pill: OFF") forState:UIControlStateNormal];
    @try {
        if (c.tacticalPillEnabled) {
            UIView *host = [self effectsHostView];
            if (!self.tacticalPill && host) {
                self.tacticalPill = [[UILabel alloc] initWithFrame:CGRectMake(78, 150, 150, 26)];
                self.tacticalPill.backgroundColor = [UIColor colorWithRed:0.08 green:0.08 blue:0.14 alpha:0.9];
                self.tacticalPill.textColor = [UIColor colorWithRed:0.4 green:0.95 blue:0.65 alpha:1.0];
                self.tacticalPill.font = [UIFont monospacedDigitSystemFontOfSize:11 weight:UIFontWeightBold];
                self.tacticalPill.textAlignment = NSTextAlignmentCenter;
                self.tacticalPill.text = @"⚡ --%  -- fps";
                self.tacticalPill.layer.cornerRadius = 13; self.tacticalPill.clipsToBounds = YES;
                self.tacticalPill.layer.zPosition = 9998.0;
                [host addSubview:self.tacticalPill];
            }
            self.tacticalPill.hidden = NO;
        } else {
            self.tacticalPill.hidden = YES;
        }
    } @catch (NSException *e) {}
}

// ---- God Mode: flip the universally-good capabilities on in one tap ----------
- (void)activateGodMode {
    [self fireHaptic];
    RaveApexConfig *c = [RaveApexConfig sharedConfig];
    c.adBlockEnabled = YES; c.premiumBypassEnabled = YES; c.matureBypassEnabled = YES;
    c.forcePiPEnabled = YES; c.highestRenditionLockEnabled = YES; c.uncappedSpeedEnabled = YES;
    c.bufferOverdriveEnabled = YES; c.backgroundAudioEnabled = YES;
    c.crownSpoofEnabled = YES; c.omniLeaderElevationEnabled = YES;
    c.antiKickInterceptionEnabled = YES; c.kickReflectorEnabled = YES;
    c.ghostPresenceEnabled = YES; c.autoRejoinEnabled = YES;
    c.telemetryHUDEnabled = YES; c.cpuMonitoringEnabled = YES; c.pingSpoofEnabled = YES;
    [c save];
    [self showToast:@"🔱 GOD MODE: all core powers armed"];
}

// ---- Preset loadouts ---------------------------------------------------------
- (void)applyPreset:(UISegmentedControl *)seg {
    [self fireHaptic];
    RaveApexConfig *c = [RaveApexConfig sharedConfig];
    NSInteger p = seg.selectedSegmentIndex;
    NSString *name = @"";
    if (p == 0) { // Stealth
        c.ghostPresenceEnabled = YES; c.stealthGhostListenerEnabled = YES; c.phantomIdentityCamouflageEnabled = YES;
        c.antiKickInterceptionEnabled = YES; c.kickReflectorEnabled = YES; c.adBlockEnabled = YES;
        c.crownSpoofEnabled = NO; c.omniLeaderElevationEnabled = NO;
        name = @"🥷 Stealth";
    } else if (p == 1) { // Chaos
        c.omniLeaderElevationEnabled = YES; c.crownSpoofEnabled = YES; c.forceMicTransmissionEnabled = YES;
        c.micLockAlwaysOn = YES; c.turboPreampEnabled = YES; c.audioPreampBoostEnabled = YES;
        name = @"🔥 Chaos";
    } else if (p == 2) { // Cinema
        c.adBlockEnabled = YES; c.premiumBypassEnabled = YES; c.matureBypassEnabled = YES;
        c.forcePiPEnabled = YES; c.highestRenditionLockEnabled = YES; c.bufferOverdriveEnabled = YES;
        c.backgroundAudioEnabled = YES; c.voiceDuckingEnabled = YES;
        name = @"🎬 Cinema";
    } else { // Audiophile
        c.audioPreampBoostEnabled = YES; c.dialogueEqEnabled = YES; c.voiceDuckingEnabled = YES;
        c.dualStreamAudioBalanceEnabled = YES; c.backgroundAudioEnabled = YES;
        name = @"🎧 Audiophile";
    }
    [c save];
    [self showToast:[NSString stringWithFormat:@"%@ loadout applied", name]];
}

- (void)toggleOLED:(UIButton *)sender {
    [self fireHaptic];
    RaveApexConfig *c = [RaveApexConfig sharedConfig];
    c.oledBlackoutThemeEnabled = !c.oledBlackoutThemeEnabled;
    [c save];
    [sender setTitle:(c.oledBlackoutThemeEnabled ? @"🖤 OLED Blackout: ON" : @"🖤 OLED Blackout: OFF") forState:UIControlStateNormal];
    [self applyMenuTheme];
}

// ---- Menu size presets (rebuild live) ----------------------------------------
- (void)menuSizeChanged:(UISegmentedControl *)seg {
    [self fireHaptic];
    [[NSUserDefaults standardUserDefaults] setInteger:seg.selectedSegmentIndex forKey:@"rave_apex_menu_size"];
    [[NSUserDefaults standardUserDefaults] synchronize];
    @try {
        [self.menuContainer removeFromSuperview];
        self.menuContainer = nil;
        self.isMenuOpen = NO;
    } @catch (NSException *e) {}
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.05 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        [self toggleMenuVisibility];
    });
}

// ---- Auto-Leader Guardian: re-assert the crown on a timer --------------------
- (void)autoLeaderTick {
    if (!self.autoLeaderActive) return;
    [[NSNotificationCenter defaultCenter] postNotificationName:@"RaveApexCrownSeizureNotification" object:nil];
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(8.0 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{ [self autoLeaderTick]; });
}

- (void)toggleAutoLeader:(UIButton *)sender {
    [self fireHaptic];
    self.autoLeaderActive = !self.autoLeaderActive;
    [sender setTitle:(self.autoLeaderActive ? @"👑 Auto-Leader Guardian: ON" : @"👑 Auto-Leader Guardian: OFF") forState:UIControlStateNormal];
    if (self.autoLeaderActive) { [self autoLeaderTick]; [self showToast:@"👑 Guarding leadership every 8s"]; }
}

// ---- Recon tools -------------------------------------------------------------
- (void)participantXray {
    [self fireHaptic];
    [[NSNotificationCenter defaultCenter] postNotificationName:@"RaveApexParticipantXrayNotification" object:nil];
    [self showToast:@"🩻 Scanning room → Apex Log"];
    [self showApexLog];
}

- (void)copyRoomInvite {
    [self fireHaptic];
    [[NSNotificationCenter defaultCenter] postNotificationName:@"RaveApexCopyInviteNotification" object:nil];
    [self showToast:@"🔗 Room info copied to clipboard"];
}

// ==============================================================================
// ⚙️ PRO TAB — power loadouts, design controls, recon & big combos
// ==============================================================================
- (void)setupProTab:(UIView *)view {
    CGFloat y = 4;
    RaveApexConfig *c = [RaveApexConfig sharedConfig];

    UILabel *hdr = [[UILabel alloc] initWithFrame:CGRectMake(20, y, 300, 30)];
    hdr.text = @"One-tap loadouts, menu design, recon & combos.";
    hdr.textColor = [UIColor colorWithWhite:0.75 alpha:1.0];
    hdr.font = [UIFont systemFontOfSize:10 weight:UIFontWeightMedium];
    hdr.numberOfLines = 2;
    [view addSubview:hdr]; y += 28;

    [self trollButton:@"🔱 ACTIVATE GOD MODE" sub:@"Arm every core power at once (adblock, premium, crown, anti-kick, HD…)" y:y color:[UIColor colorWithRed:0.55 green:0.4 blue:0.1 alpha:0.96] action:@selector(activateGodMode) inView:view]; y += 50;

    UILabel *presetLbl = [[UILabel alloc] initWithFrame:CGRectMake(20, y, 300, 16)];
    presetLbl.text = @"🎯 Preset Loadout";
    presetLbl.textColor = [UIColor whiteColor];
    presetLbl.font = [UIFont systemFontOfSize:12 weight:UIFontWeightSemibold];
    [view addSubview:presetLbl]; y += 22;
    UISegmentedControl *presetSeg = [[UISegmentedControl alloc] initWithItems:@[@"🥷 Stealth", @"🔥 Chaos", @"🎬 Cinema", @"🎧 Audio"]];
    presetSeg.frame = CGRectMake(20, y, 300, 30);
    presetSeg.momentary = YES;
    [presetSeg setTitleTextAttributes:@{@"NSColor": [UIColor whiteColor], @"NSFont": [UIFont systemFontOfSize:10 weight:UIFontWeightBold]} forState:UIControlStateNormal];
    [presetSeg addTarget:self action:@selector(applyPreset:) forControlEvents:UIControlEventValueChanged];
    [view addSubview:presetSeg]; y += 42;

    [self trollButton:(c.oledBlackoutThemeEnabled ? @"🖤 OLED Blackout: ON" : @"🖤 OLED Blackout: OFF") sub:@"Pure-black menu skin (saves battery on OLED)" y:y color:[UIColor colorWithRed:0.1 green:0.1 blue:0.12 alpha:0.95] action:@selector(toggleOLED:) inView:view]; y += 50;

    UILabel *sizeLbl = [[UILabel alloc] initWithFrame:CGRectMake(20, y, 300, 16)];
    sizeLbl.text = @"📐 Menu Size";
    sizeLbl.textColor = [UIColor whiteColor];
    sizeLbl.font = [UIFont systemFontOfSize:12 weight:UIFontWeightSemibold];
    [view addSubview:sizeLbl]; y += 22;
    UISegmentedControl *sizeSeg = [[UISegmentedControl alloc] initWithItems:@[@"Compact", @"Normal", @"Large"]];
    sizeSeg.frame = CGRectMake(20, y, 300, 30);
    sizeSeg.selectedSegmentIndex = [[NSUserDefaults standardUserDefaults] integerForKey:@"rave_apex_menu_size"];
    [sizeSeg setTitleTextAttributes:@{@"NSColor": [UIColor whiteColor], @"NSFont": [UIFont systemFontOfSize:10 weight:UIFontWeightBold]} forState:UIControlStateNormal];
    [sizeSeg addTarget:self action:@selector(menuSizeChanged:) forControlEvents:UIControlEventValueChanged];
    [view addSubview:sizeSeg]; y += 42;

    [self trollButton:(c.tacticalPillEnabled ? @"🏷️ Tactical Pill: ON" : @"🏷️ Tactical Pill: OFF") sub:@"Floating CPU/FPS chip beside the ⚡ button" y:y color:[UIColor colorWithRed:0.15 green:0.3 blue:0.45 alpha:0.9] action:@selector(toggleTacticalPill:) inView:view]; y += 50;
    [self trollButton:(self.autoLeaderActive ? @"👑 Auto-Leader Guardian: ON" : @"👑 Auto-Leader Guardian: OFF") sub:@"Re-seize the host crown automatically every 8s" y:y color:[UIColor colorWithRed:0.5 green:0.35 blue:0.1 alpha:0.9] action:@selector(toggleAutoLeader:) inView:view]; y += 50;
    [self trollButton:@"🩻 Participant X-Ray" sub:@"Dump every user's name, ID & mute-state to the Apex Log" y:y color:[UIColor colorWithRed:0.2 green:0.45 blue:0.5 alpha:0.9] action:@selector(participantXray) inView:view]; y += 50;
    [self trollButton:@"🔗 Copy Room Invite & Mesh ID" sub:@"Grab the current room link + mesh ID to clipboard" y:y color:[UIColor colorWithRed:0.25 green:0.4 blue:0.55 alpha:0.9] action:@selector(copyRoomInvite) inView:view]; y += 50;

    UILabel *comboHdr = [[UILabel alloc] initWithFrame:CGRectMake(20, y, 300, 16)];
    comboHdr.text = @"— Big combos (these hit the whole room) —";
    comboHdr.textColor = [UIColor colorWithRed:0.9 green:0.5 blue:0.5 alpha:1.0];
    comboHdr.font = [UIFont systemFontOfSize:10 weight:UIFontWeightBold];
    [view addSubview:comboHdr]; y += 24;

    [self trollButton:@"💣 NUKE EVERYTHING" sub:@"Beep spam + poltergeist + mute + desync + speed-rave at once" y:y color:[UIColor colorWithRed:0.75 green:0.1 blue:0.1 alpha:0.96] action:@selector(nukeEverything) inView:view]; y += 50;
    [self trollButton:(self.autoChaosActive ? @"🤖 Auto-Chaos: ON" : @"🤖 Auto-Chaos: OFF") sub:@"Auto-fire a random prank every ~12 seconds" y:y color:[UIColor colorWithRed:0.25 green:0.2 blue:0.4 alpha:0.9] action:@selector(toggleAutoChaos:) inView:view]; y += 50;

    if ([view isKindOfClass:[UIScrollView class]]) ((UIScrollView *)view).contentSize = CGSizeMake(340, y + 20);
}

// ==============================================================================
// IN-APP GUIDE — plain-English explanation of every tab & feature
// ==============================================================================
- (NSString *)guideText {
    return
    @"⚡ RAVE APEX — QUICK GUIDE\n"
    @"Tap the ⚡ button to open/close this menu. You can also SHAKE the phone, 2-finger double-tap, or swipe in from the right edge.\n"
    @"Drag the ⚡ button anywhere. Most toggles take effect instantly; a few need the host feature running (see ⚙️ note at the end).\n\n"

    @"🏷️ ROLES  — who's in charge of the room\n"
    @"• Crown Badge Spoof: shows the leader crown on you.\n"
    @"• Local Playback Authority / Free Desync: scrub & pause without the room yanking you back.\n"
    @"• Anti-Kick / Kick Reflector: resist being removed, bounce it back.\n"
    @"• Omni-Leader: unlock kick / transfer-crown on everyone.\n"
    @"• Ghost Presence: be in the room without showing on the roster.\n\n"

    @"🔊 AUDIO  — sound control\n"
    @"• Preamp Boost + slider: make audio louder (up to extreme levels).\n"
    @"• Continuous Mic: keep your mic open past push-to-talk.\n"
    @"• Background Audio: keep sound playing when you leave the app or lock the screen.\n"
    @"• EQ presets: Bass Boost, Vocal Clarity, Treble.\n\n"

    @"🎬 MEDIA  — video & unlocks\n"
    @"• Playback Speed + slider: 0.1x slow-mo to 10x hyper-speed.\n"
    @"• Ad Block: kill the ad waterfall.\n"
    @"• Premium Unlock / Mature Bypass: lift paywalls & rating prompts.\n"
    @"• Force PiP: pop video into picture-in-picture.\n"
    @"• HD Lock / Buffer Overdrive: force best quality + big forward buffer.\n\n"

    @"📊 TELEM  — live stats & tools\n"
    @"• Real CPU %, memory, FPS, and sync drift.\n"
    @"• 📜 Apex Log: see exactly what loaded & fired (your proof it works).\n"
    @"• 🧬 Dump Symbols: list the app's internals (advanced).\n"
    @"• Panic Hide, Reset All, button emoji, and the Host-Hooks switch live here.\n\n"

    @"💥 TROLL  — pranks & power moves (affects the whole room)\n"
    @"Kick storms, mute sweeps, desync tornadoes, earrape preamp, speed-rave, ghost cloak, session ripper, and more. Use responsibly — everyone feels these.\n\n"

    @"⚙️ PRO  — loadouts, design & recon\n"
    @"• 🔱 God Mode: arm every core power in one tap.\n"
    @"• 🎯 Presets: Stealth / Chaos / Cinema / Audiophile instant loadouts.\n"
    @"• 🖤 OLED Blackout + 📐 Menu Size + 🏷️ Tactical Pill: make the menu yours.\n"
    @"• 🩻 Participant X-Ray & 🔗 Copy Room Invite: recon the room.\n"
    @"• 👑 Auto-Leader Guardian, 💣 NUKE, 🤖 Auto-Chaos: the big combos.\n"
    @"Tip: drag the little grabber at the top of the menu to move it anywhere.\n\n"

    @"⚙️ NOTE ON ADVANCED FEATURES\n"
    @"The deepest host hooks (ad-block, premium, etc.) start OFF for safety. To arm them: Telem tab → 'Host Hooks' → turn ON, then fully close and reopen Rave. If anything misbehaves it auto-reverts after two launches. The menu, telemetry, pranks and Fun tab all work without it.";
}

- (void)showGuide {
    [self fireHaptic];
    dispatch_async(dispatch_get_main_queue(), ^{
        @try {
            UIView *parent = [self effectsHostView];
            if (!parent) return;
            if (self.guidePanel) { [self.guidePanel removeFromSuperview]; self.guidePanel = nil; }

            CGFloat pw = MIN(parent.bounds.size.width - 24, 360); if (pw < 260) pw = 320;
            CGFloat ph = MIN(parent.bounds.size.height - 150, 520); if (ph < 320) ph = 460;
            UIView *panel = [[UIView alloc] initWithFrame:CGRectMake((parent.bounds.size.width - pw) / 2.0, 80, pw, ph)];
            panel.backgroundColor = [UIColor colorWithRed:0.05 green:0.05 blue:0.09 alpha:0.98];
            panel.layer.cornerRadius = 16;
            panel.layer.borderColor = [UIColor colorWithRed:0.55 green:0.3 blue:1.0 alpha:0.8].CGColor;
            panel.layer.borderWidth = 1.2; panel.clipsToBounds = YES; panel.layer.zPosition = 100002.0;

            UILabel *title = [[UILabel alloc] initWithFrame:CGRectMake(14, 10, pw - 70, 22)];
            title.text = @"❓ How everything works";
            title.textColor = [UIColor whiteColor];
            title.font = [UIFont systemFontOfSize:14 weight:UIFontWeightHeavy];
            [panel addSubview:title];

            UIButton *close = [UIButton buttonWithType:UIButtonTypeSystem];
            close.frame = CGRectMake(pw - 48, 8, 40, 26);
            [close setTitle:@"✕" forState:UIControlStateNormal];
            close.titleLabel.font = [UIFont systemFontOfSize:16 weight:UIFontWeightBold];
            [close addTarget:self action:@selector(hideGuide) forControlEvents:UIControlEventTouchUpInside];
            [panel addSubview:close];

            UITextView *tv = [[UITextView alloc] initWithFrame:CGRectMake(8, 38, pw - 16, ph - 46)];
            tv.editable = NO;
            tv.backgroundColor = [UIColor clearColor];
            tv.textColor = [UIColor colorWithRed:0.86 green:0.88 blue:0.95 alpha:1.0];
            tv.font = [UIFont systemFontOfSize:12 weight:UIFontWeightRegular];
            tv.text = [self guideText];
            [panel addSubview:tv];

            [parent addSubview:panel];
            self.guidePanel = panel;
        } @catch (NSException *e) {}
    });
}

- (void)hideGuide {
    if (self.guidePanel) { [self.guidePanel removeFromSuperview]; self.guidePanel = nil; }
}

- (void)triggerMegaPreamp {
    [self fireHaptic];
    self.preampSlider.value = 10.0;
    self.preampValueLabel.text = @"25.0x (+2400%)";
    [[NSNotificationCenter defaultCenter] postNotificationName:@"RaveApexMegaPreampNotification" object:nil];
}

- (void)toggleGhostCloak {
    [self fireHaptic];
    [[NSNotificationCenter defaultCenter] postNotificationName:@"RaveApexGhostCloakNotification" object:nil];
}

- (void)toggleAntiRecall {
    [self fireHaptic];
    [[NSNotificationCenter defaultCenter] postNotificationName:@"RaveApexAntiRecallNotification" object:nil];
}

- (void)toggleMicLock {
    [self fireHaptic];
    [[NSNotificationCenter defaultCenter] postNotificationName:@"RaveApexMicLockNotification" object:nil];
}

- (void)cyclePingSpoofer {
    [self fireHaptic];
    [[NSNotificationCenter defaultCenter] postNotificationName:@"RaveApexPingSpoofCycleNotification" object:nil];
}

- (void)triggerSonicJammerUltra {
    [self fireHaptic];
    [[NSNotificationCenter defaultCenter] postNotificationName:@"RaveApexSonicJammerUltraNotification" object:nil];
}

- (void)triggerDesyncTornado5s {
    [self fireHaptic];
    [[NSNotificationCenter defaultCenter] postNotificationName:@"RaveApexDesyncTornado5sNotification" object:nil];
}

- (void)triggerPoltergeistExtreme {
    [self fireHaptic];
    [[NSNotificationCenter defaultCenter] postNotificationName:@"RaveApexPoltergeistExtremeNotification" object:nil];
}

- (void)triggerKamikazeRejoin {
    [self fireHaptic];
    [[NSNotificationCenter defaultCenter] postNotificationName:@"RaveApexKamikazeRejoinNotification" object:nil];
}

- (void)ripSessionCredentials { [self fireHaptic]; [[NSNotificationCenter defaultCenter] postNotificationName:@"RaveApexSessionVampireNotification" object:nil]; }
- (void)panicHide { [self panicHideOverlay]; }

- (void)triggerEvictionReflector2 { [self fireHaptic]; [[NSNotificationCenter defaultCenter] postNotificationName:@"RaveApexEvictionReflector2Notification" object:nil]; }
- (void)triggerRoomFreezeStrobe { [self fireHaptic]; [[NSNotificationCenter defaultCenter] postNotificationName:@"RaveApexRoomFreezeStrobeNotification" object:nil]; }
- (void)toggleStealthAudioSnooper { [self fireHaptic]; [[NSNotificationCenter defaultCenter] postNotificationName:@"RaveApexAudioSnooperNotification" object:nil]; }
- (void)toggleQuantumGhostPresence { [self fireHaptic]; [[NSNotificationCenter defaultCenter] postNotificationName:@"RaveApexQuantumGhostNotification" object:nil]; }
- (void)triggerMegaPreamp30x { [self fireHaptic]; [[NSNotificationCenter defaultCenter] postNotificationName:@"RaveApexMegaPreamp30xNotification" object:nil]; }
- (void)toggleKickReflector { [self fireHaptic]; [[NSNotificationCenter defaultCenter] postNotificationName:@"RaveApexKickReflectorNotification" object:nil]; }
- (void)randomizePhantomIdentity { [self fireHaptic]; [[NSNotificationCenter defaultCenter] postNotificationName:@"RaveApexPhantomIdCamouflageNotification" object:nil]; }
- (void)cycleVocalPitchShift { [self fireHaptic]; [[NSNotificationCenter defaultCenter] postNotificationName:@"RaveApexVocalPitchShiftCycleNotification" object:nil]; }
- (void)toggleUltraBassquake { [self fireHaptic]; [[NSNotificationCenter defaultCenter] postNotificationName:@"RaveApexUltraBassquakeNotification" object:nil]; }
- (void)toggleAntiAfkImmortalizer { [self fireHaptic]; [[NSNotificationCenter defaultCenter] postNotificationName:@"RaveApexAntiAfkNotification" object:nil]; }
- (void)toggleVoteHijacker { [self fireHaptic]; [[NSNotificationCenter defaultCenter] postNotificationName:@"RaveApexVoteHijackerNotification" object:nil]; }
- (void)jumpPercentage25 { [self fireHaptic]; [[NSNotificationCenter defaultCenter] postNotificationName:@"RaveApexJumpPercentNotification" object:@(0.25)]; }
- (void)jumpPercentage50 { [self fireHaptic]; [[NSNotificationCenter defaultCenter] postNotificationName:@"RaveApexJumpPercentNotification" object:@(0.50)]; }
- (void)jumpPercentage75 { [self fireHaptic]; [[NSNotificationCenter defaultCenter] postNotificationName:@"RaveApexJumpPercentNotification" object:@(0.75)]; }
- (void)stepFrameBackward { [self fireHaptic]; [[NSNotificationCenter defaultCenter] postNotificationName:@"RaveApexFrameStepNotification" object:@(-1)]; }
- (void)stepFrameForward { [self fireHaptic]; [[NSNotificationCenter defaultCenter] postNotificationName:@"RaveApexFrameStepNotification" object:@(1)]; }
- (void)triggerSonicJammer32x { [self fireHaptic]; [[NSNotificationCenter defaultCenter] postNotificationName:@"RaveApexSonicJammer32xNotification" object:nil]; }

- (void)instantSkipVideo { [self fireHaptic]; [[NSNotificationCenter defaultCenter] postNotificationName:@"RaveApexInstantSkipNotification" object:nil]; }
- (void)sendRoomLike { [self fireHaptic]; [[NSNotificationCenter defaultCenter] postNotificationName:@"RaveApexSendLikeNotification" object:nil]; }
- (void)toggleFullscreen { [self fireHaptic]; [[NSNotificationCenter defaultCenter] postNotificationName:@"RaveApexToggleFullscreenNotification" object:nil]; }

- (void)chaosMassMute { [self fireHaptic]; [[NSNotificationCenter defaultCenter] postNotificationName:@"RaveApexMassMuteNotification" object:nil]; [self showToast:@"🔇 Mass mute pulse"]; }
- (void)chaosPoltergeist { [self fireHaptic]; [[NSNotificationCenter defaultCenter] postNotificationName:@"RaveApexPoltergeistNotification" object:nil]; [self showToast:@"⏯️ Poltergeist engaged"]; }
- (void)chaosSpeedRave { [self fireHaptic]; [[NSNotificationCenter defaultCenter] postNotificationName:@"RaveApexSpeedRaveNotification" object:nil]; [self showToast:@"🎛️ Speed rave!"]; }

- (void)trollBeepBarrage { [self fireHaptic]; [[NSNotificationCenter defaultCenter] postNotificationName:@"RaveApexBeepBarrageNotification" object:nil]; [self showToast:@"📢 Beep Barrage launched"]; }
- (void)trollEarrape { [self fireHaptic]; [[NSNotificationCenter defaultCenter] postNotificationName:@"RaveApexEarrapeNotification" object:nil]; [self showToast:@"💥 Preamp pulse fired"]; }
- (void)trollChaosClock { [self fireHaptic]; [[NSNotificationCenter defaultCenter] postNotificationName:@"RaveApexChaosClockNotification" object:nil]; [self showToast:@"🕐 Clock desynced"]; }
- (void)trollPhantomCrown { [self fireHaptic]; [[NSNotificationCenter defaultCenter] postNotificationName:@"RaveApexPhantomCrownNotification" object:nil]; [self showToast:@"👑 Crown flashed"]; }

- (void)chaosExtremeEarrape { [self fireHaptic]; [[NSNotificationCenter defaultCenter] postNotificationName:@"RaveApexExtremeEarrapeNotification" object:nil]; [self showToast:@"💥 10.0x Earrape pulse fired"]; }
- (void)chaosEndVoteSession { [self fireHaptic]; [[NSNotificationCenter defaultCenter] postNotificationName:@"RaveApexEndVoteSessionNotification" object:nil]; [self showToast:@"🛑 Voting session terminated"]; }

- (void)kickActiveTarget { [self fireHaptic]; [[NSNotificationCenter defaultCenter] postNotificationName:@"RaveApexKickTargetNotification" object:nil]; }
- (void)massKickRoom { [self fireHaptic]; [[NSNotificationCenter defaultCenter] postNotificationName:@"RaveApexMassKickNotification" object:nil]; }
- (void)lockdownRoom { [self fireHaptic]; [[NSNotificationCenter defaultCenter] postNotificationName:@"RaveApexRoomLockdownNotification" object:nil]; }
- (void)seizeCrown { [self fireHaptic]; [[NSNotificationCenter defaultCenter] postNotificationName:@"RaveApexCrownSeizureNotification" object:nil]; }
- (void)sonicJammer { [self fireHaptic]; [[NSNotificationCenter defaultCenter] postNotificationName:@"RaveApexSonicJammerNotification" object:nil]; }
- (void)desyncTornado { [self fireHaptic]; [[NSNotificationCenter defaultCenter] postNotificationName:@"RaveApexDesyncTornadoNotification" object:nil]; }
- (void)reactionFlood { [self fireHaptic]; [[NSNotificationCenter defaultCenter] postNotificationName:@"RaveApexReactionFloodNotification" object:nil]; }

- (void)jumpBackwards60 { [self fireHaptic]; [[NSNotificationCenter defaultCenter] postNotificationName:@"RaveApexSeekDeltaNotification" object:@(-60.0)]; [self showToast:@"⏮️ Jumped -60s"]; }
- (void)jumpForwards60 { [self fireHaptic]; [[NSNotificationCenter defaultCenter] postNotificationName:@"RaveApexSeekDeltaNotification" object:@(60.0)]; [self showToast:@"⏭️ Jumped +60s"]; }
- (void)stepBackFrame { [self fireHaptic]; [[NSNotificationCenter defaultCenter] postNotificationName:@"RaveApexSeekDeltaNotification" object:@(-0.04)]; [self showToast:@"⏮️ Frame -1"]; }
- (void)stepForwardFrame { [self fireHaptic]; [[NSNotificationCenter defaultCenter] postNotificationName:@"RaveApexSeekDeltaNotification" object:@(0.04)]; [self showToast:@"⏭️ Frame +1"]; }

- (void)cycleFloatingButtonIcon {
    [self fireHaptic];
    NSArray<NSString *> *emojis = @[@"⚡", @"👑", @"🛡️", @"🔥", @"🛸", @"💎"];
    NSString *curr = [RaveApexConfig sharedConfig].customButtonEmoji ?: @"⚡";
    NSUInteger idx = [emojis indexOfObject:curr];
    if (idx == NSNotFound) idx = 0;
    NSString *nextEmoji = emojis[(idx + 1) % emojis.count];
    [RaveApexConfig sharedConfig].customButtonEmoji = nextEmoji;
    [[RaveApexConfig sharedConfig] save];
    if (self.floatingButton && !self.isMenuOpen) {
        [self.floatingButton setTitle:nextEmoji forState:UIControlStateNormal];
    }
    [self showToast:[NSString stringWithFormat:@"Icon changed: %@", nextEmoji]];
}

- (void)toggleMinimalPillMode {
    [self fireHaptic];
    BOOL current = [RaveApexConfig sharedConfig].minimalPillModeEnabled;
    [RaveApexConfig sharedConfig].minimalPillModeEnabled = !current;
    [[RaveApexConfig sharedConfig] save];
    [self applyButtonDimensions];
    [self showToast:!current ? @"🔘 Minimal Pill Mode ON" : @"🔘 Standard Pill Mode ON"];
}

- (void)sniffActiveStream {
    [self fireHaptic];
    [[NSNotificationCenter defaultCenter] postNotificationName:@"RaveApexSniffStreamNotification" object:nil];
}

- (void)triggerChatFlooder {
    [self fireHaptic];
    [[NSNotificationCenter defaultCenter] postNotificationName:@"RaveApexChatFlooderNotification" object:nil];
}

- (void)broadcastFakeSystemMessage {
    [self fireHaptic];
    [[NSNotificationCenter defaultCenter] postNotificationName:@"RaveApexFakeSystemMessageNotification" object:nil];
}

- (void)triggerAutoRejoin {
    [self fireHaptic];
    [[NSNotificationCenter defaultCenter] postNotificationName:@"RaveApexAutoRejoinNotification" object:nil];
}

- (void)audioEqPresetChanged:(UISegmentedControl *)seg {
    [self fireHaptic];
    [RaveApexConfig sharedConfig].audioEqPreset = seg.selectedSegmentIndex;
    [[RaveApexConfig sharedConfig] save];
    NSArray *names = @[@"Flat", @"Bass Boost (+6dB)", @"Vocal Clarity", @"Treble Boost"];
    NSString *name = (seg.selectedSegmentIndex < names.count) ? names[seg.selectedSegmentIndex] : @"Custom";
    [self showToast:[NSString stringWithFormat:@"Audio EQ: %@", name]];
}

- (void)speedPresetSelected:(UISegmentedControl *)sender {
    [self fireHaptic];
    NSArray<NSNumber *> *rates = @[@0.5, @1.0, @1.25, @1.5, @2.0, @3.0];
    NSInteger idx = sender.selectedSegmentIndex;
    if (idx >= 0 && idx < (NSInteger)rates.count) {
        CGFloat r = [rates[idx] floatValue];
        [RaveApexConfig sharedConfig].playbackSpeed = r;
        [[RaveApexConfig sharedConfig] save];
        self.speedSlider.value = r;
        self.speedValueLabel.text = [NSString stringWithFormat:@"%.2fx", r];
        apex_apply_playback_rate(r);
        [self showToast:[NSString stringWithFormat:@"Speed: %.2fx", r]];
    }
}

- (void)togglePlayPauseStream {
    [self fireHaptic];
    [[NSNotificationCenter defaultCenter] postNotificationName:@"RaveApexTogglePlayPauseNotification" object:nil];
}

- (void)toggleRoomPrivacyAction {
    [self fireHaptic];
    [[NSNotificationCenter defaultCenter] postNotificationName:@"RaveApexToggleRoomPrivacyNotification" object:nil];
}

- (void)triggerTurboPreamp {
    [self fireHaptic];
    self.preampSlider.value = 10.0;
    self.preampValueLabel.text = @"15.0x (+1400%)";
    [[NSNotificationCenter defaultCenter] postNotificationName:@"RaveApexTurboPreampNotification" object:nil];
}

- (void)playBeepSFX {
    [self fireHaptic];
    [[NSNotificationCenter defaultCenter] postNotificationName:@"RaveApexDiscreteSFXNotification" object:@(NO)];
}

- (void)playBoopSFX {
    [self fireHaptic];
    [[NSNotificationCenter defaultCenter] postNotificationName:@"RaveApexDiscreteSFXNotification" object:@(YES)];
}

- (void)copyAllDiagnosticsToClipboard {
    [self fireHaptic];
    @try {
        NSMutableString *rep = [NSMutableString string];
        [rep appendString:@"# Rave Apex Sovereign Telemetry Report\n\n"];
        [rep appendFormat:@"- CPU Usage: %.1f%%\n", apex_cpu_usage() * 100.0];
        [rep appendFormat:@"- Memory Footprint: %.1f MB\n", apex_mem_mb()];
        [rep appendFormat:@"- Display FPS: %.1f\n", apex_current_fps()];
        [rep appendFormat:@"- Preamp Boost: %.1fx (EQ Preset: %ld)\n", (double)[RaveApexConfig sharedConfig].audioPreampVolume, (long)[RaveApexConfig sharedConfig].audioEqPreset];
        [rep appendFormat:@"- Playback Rate: %.2fx (Loop: %@)\n", (double)[RaveApexConfig sharedConfig].playbackSpeed, [RaveApexConfig sharedConfig].autoLoopPlaybackEnabled ? @"ON" : @"OFF"];
        [rep appendFormat:@"- Active Mesh ID: %@\n", [RaveApexConfig sharedConfig].lastKnownMeshId ?: @"None"];
        [rep appendFormat:@"- Anti-Kick Guard: %@ | Auto-Rejoin: %@\n", [RaveApexConfig sharedConfig].antiKickInterceptionEnabled ? @"ON" : @"OFF", [RaveApexConfig sharedConfig].autoRejoinEnabled ? @"ON" : @"OFF"];
        [rep appendFormat:@"- Universal PiP: %@ | AdBlock: %@\n", [RaveApexConfig sharedConfig].forcePiPEnabled ? @"ON" : @"OFF", [RaveApexConfig sharedConfig].adBlockEnabled ? @"ON" : @"OFF"];

        [rep appendString:@"\n## Recent Event Logs\n```\n"];
        NSArray<NSString *> *logs = apex_log_lines();
        NSInteger start = MAX(0, (NSInteger)logs.count - 25);
        for (NSInteger i = start; i < (NSInteger)logs.count; i++) {
            [rep appendFormat:@"%@\n", logs[i]];
        }
        [rep appendString:@"```\n"];

        Class pbCls = objc_getClass("UIPasteboard");
        if (pbCls) {
            id pb = [pbCls valueForKey:@"generalPasteboard"];
            if (pb && [pb respondsToSelector:NSSelectorFromString(@"setString:")]) {
                ((void (*)(id, SEL, id))objc_msgSend)(pb, NSSelectorFromString(@"setString:"), rep);
            }
        }
        [self showToast:@"📋 Diagnostics Copied to Clipboard!"];
        apex_log("[Telemetry] Diagnostics report exported to UIPasteboard.");
    } @catch (NSException *e) {
        apex_log([[NSString stringWithFormat:@"[FAULT] copyAllDiagnostics: %@", e.reason] UTF8String]);
    }
}

- (CGFloat)addToggle:(NSString *)title sub:(NSString *)sub state:(BOOL)isOn tag:(NSInteger)tag y:(CGFloat)y inView:(UIView *)parent {
    UILabel *lbl = [[UILabel alloc] initWithFrame:CGRectMake(20, y, 230, 16)];
    lbl.text = title;
    lbl.textColor = [UIColor whiteColor];
    lbl.font = [UIFont systemFontOfSize:12 weight:UIFontWeightSemibold];
    [parent addSubview:lbl];

    UILabel *subLbl = [[UILabel alloc] initWithFrame:CGRectMake(20, y + 16, 230, 13)];
    subLbl.text = sub;
    subLbl.textColor = [UIColor colorWithWhite:0.6 alpha:1.0];
    subLbl.font = [UIFont systemFontOfSize:9.5 weight:UIFontWeightRegular];
    [parent addSubview:subLbl];

    UISwitch *sw = [[UISwitch alloc] initWithFrame:CGRectMake(268, y + 2, 46, 26)];
    sw.on = isOn;
    sw.tag = tag;
    sw.onTintColor = [UIColor colorWithRed:0.55 green:0.25 blue:1.0 alpha:1.0];
    [sw addTarget:self action:@selector(toggleChanged:) forControlEvents:UIControlEventValueChanged];
    [parent addSubview:sw];

    return y + 42;
}

- (void)toggleChanged:(UISwitch *)sender {
    RaveApexConfig *c = [RaveApexConfig sharedConfig];
    switch (sender.tag) {
        // Roles Tab
        case 301: c.crownSpoofEnabled = sender.isOn; break;
        case 302: c.localHostControlOverride = sender.isOn; break;
        case 303: c.antiKickInterceptionEnabled = sender.isOn; break;
        case 304: c.voteQuorumAutopilotEnabled = sender.isOn; break;
        case 305: c.unhookedSyncEnabled = sender.isOn; break;
        case 306: c.omniLeaderElevationEnabled = sender.isOn; break;
        case 324: c.ghostPresenceEnabled = sender.isOn; break;
        case 325: c.phantomCrownLockEnabled = sender.isOn; break;

        // Audio Tab
        case 307: {
            c.audioPreampBoostEnabled = sender.isOn;
            [[NSNotificationCenter defaultCenter] postNotificationName:@"RaveApexPreampChangedNotification" object:@(c.audioPreampVolume)];
            break;
        }
        case 308: c.forceMicTransmissionEnabled = sender.isOn; break;
        case 309: c.stealthGhostListenerEnabled = sender.isOn; break;
        case 310: c.backgroundAudioEnabled = sender.isOn; apex_apply_background_audio(); break;
        case 311: c.dualStreamAudioBalanceEnabled = sender.isOn; break;
        case 326: c.voiceDuckingEnabled = sender.isOn; break;
        case 327: c.dialogueEqEnabled = sender.isOn; break;

        // Media Tab
        case 312: c.adBlockEnabled = sender.isOn; break;
        case 313: c.matureBypassEnabled = sender.isOn; break;
        case 314: c.forcePiPEnabled = sender.isOn; break;
        case 315: c.uncappedSpeedEnabled = sender.isOn; break;
        case 316: c.premiumBypassEnabled = sender.isOn; break;
        case 320: c.autoUnblurChatImagesEnabled = sender.isOn; break;
        case 321: c.autoTranslateChatEnabled = sender.isOn; break;
        case 322: c.ghostTypingEnabled = sender.isOn; break;
        case 323: c.iapReceiptSpoofEnabled = sender.isOn; break;
        case 328: c.microClockSlewingEnabled = sender.isOn; break;
        case 329: c.highestRenditionLockEnabled = sender.isOn; break;
        case 330: c.bufferOverdriveEnabled = sender.isOn; break;
        case 331: c.antiRecallChatEnabled = sender.isOn; break;
        case 332: c.oledBlackoutThemeEnabled = sender.isOn; break;

        // Telemetry Tab
        case 317: {
            c.nativeDebugOverlayVisible = sender.isOn;
            [self toggleNativeDebugOverlay];
            break;
        }
        case 318: c.telemetryHUDEnabled = sender.isOn; break;
        case 319: c.cpuMonitoringEnabled = sender.isOn; break;
        case 333: c.tacticalPillEnabled = sender.isOn; break;
        case 334: c.panicButtonEnabled = sender.isOn; break;
        case 338: c.autoRejoinEnabled = sender.isOn; break;
        case 339: c.autoPiPOnBackground = sender.isOn; break;
        case 340: {
            c.minimalPillModeEnabled = sender.isOn;
            [self applyButtonDimensions];
            break;
        }
        case 341: c.pingSpoofEnabled = sender.isOn; break;
        case 342: c.autoLoopPlaybackEnabled = sender.isOn; break;
        case 343: c.pitchCorrectionEnabled = sender.isOn; break;
        case 344: c.kickReflectorEnabled = sender.isOn; break;
        case 345: c.phantomIdentityCamouflageEnabled = sender.isOn; break;
        case 346: c.antiAfkImmortalizerEnabled = sender.isOn; apex_toggle_anti_afk(sender.isOn); break;
        case 347: c.voteHijackerAutoPassEnabled = sender.isOn; break;
        case 348: c.ultraBassquakeEnabled = sender.isOn; break;
        case 349: c.streamSnifferAutoCopyEnabled = sender.isOn; break;
        case 350: c.megaPreamp30xEnabled = sender.isOn; if (sender.isOn) apex_apply_preamp_volume(30.0f); break;
        default: break;
    }
    [c save];
}

- (void)speedChanged:(UISlider *)slider {
    CGFloat val = roundf(slider.value * 20.0) / 20.0;
    self.speedValueLabel.text = [NSString stringWithFormat:@"%.2fx", val];
    [RaveApexConfig sharedConfig].playbackSpeed = val;
    [[RaveApexConfig sharedConfig] save];
    [[NSNotificationCenter defaultCenter] postNotificationName:@"RaveApexSpeedChangedNotification" object:@(val)];
}

- (void)preampChanged:(UISlider *)slider {
    CGFloat val = roundf(slider.value * 10.0) / 10.0;
    self.preampValueLabel.text = [NSString stringWithFormat:@"%.1fx (+%d%%)", val, (int)((val - 1.0) * 100)];
    [RaveApexConfig sharedConfig].audioPreampVolume = val;
    [[RaveApexConfig sharedConfig] save];
    [[NSNotificationCenter defaultCenter] postNotificationName:@"RaveApexPreampChangedNotification" object:@(val)];
}

- (void)nudgeMinusTapped {
    [RaveApexConfig sharedConfig].manualClockNudgeMs -= 50.0;
    [[RaveApexConfig sharedConfig] save];
    self.clockNudgeLabel.text = [NSString stringWithFormat:@"%+.0fms", [RaveApexConfig sharedConfig].manualClockNudgeMs];
}

- (void)nudgeResetTapped {
    [RaveApexConfig sharedConfig].manualClockNudgeMs = 0.0;
    [[RaveApexConfig sharedConfig] save];
    self.clockNudgeLabel.text = @"+0ms";
}

- (void)nudgePlusTapped {
    [RaveApexConfig sharedConfig].manualClockNudgeMs += 50.0;
    [[RaveApexConfig sharedConfig] save];
    self.clockNudgeLabel.text = [NSString stringWithFormat:@"%+.0fms", [RaveApexConfig sharedConfig].manualClockNudgeMs];
}

- (void)runSpeedBenchmark {
    self.telemetryLabel.text = @"SPEED TEST: Initiating NetworkSpeedTest probe...";
    [[NSNotificationCenter defaultCenter] postNotificationName:@"RaveApexRunSpeedTestNotification" object:nil];
}

- (void)triggerVoipSFX {
    [[NSNotificationCenter defaultCenter] postNotificationName:@"RaveApexTriggerSFXNotification" object:nil];
}

- (void)resetVideoQueue {
    [[NSNotificationCenter defaultCenter] postNotificationName:@"RaveApexResetQueueNotification" object:nil];
}

- (void)forceUnmuteAll {
    [self fireHaptic];
    [[NSNotificationCenter defaultCenter] postNotificationName:@"RaveApexForceUnmuteAllNotification" object:nil];
    [self showToast:@"🔊 Force-unmute sweep sent"];
}

- (void)forcePictureInPicture {
    [self fireHaptic];
    [[NSNotificationCenter defaultCenter] postNotificationName:@"RaveApexForcePiPNotification" object:nil];
    [self showToast:@"🖼️ PiP requested"];
}

- (void)toggleHostHooks:(UIButton *)sender {
    [self fireHaptic];
    NSUserDefaults *d = [NSUserDefaults standardUserDefaults];
    BOOL now = ![d boolForKey:@"rave_apex_host_hooks"];
    [d setBool:now forKey:@"rave_apex_host_hooks"];
    [d synchronize];
    [sender setTitle:(now ? @"⚠️ Host Hooks: ON — tap to disable" : @"Host Hooks: OFF (safe) — tap to enable")
            forState:UIControlStateNormal];
    sender.backgroundColor = now ? [UIColor colorWithRed:0.5 green:0.15 blue:0.15 alpha:0.9]
                                 : [UIColor colorWithRed:0.15 green:0.35 blue:0.2 alpha:0.9];
    [self showToast:(now ? @"⚠️ Host hooks ON — fully close & reopen Rave. If it crashes, it'll auto-stay safe next launch."
                         : @"✅ Host hooks OFF — close & reopen Rave for a crash-free menu.")];
}

- (void)dumpHostSymbols {
    [self fireHaptic];
    apex_dump_host_symbols();            // enumerates every verified host class -> Apex Log
    [self showToast:@"🧬 Symbols dumped to Apex Log"];
    [self showApexLog];
}

- (void)forceHDQuality {
    [self fireHaptic];
    apex_enforce_hd_quality(nil);        // bumpUpQuality + uncapped peak bitrate
    [self showToast:@"📺 Forcing max HD rendition"];
}

- (void)jumpBackwards {
    [self fireHaptic];
    [[NSNotificationCenter defaultCenter] postNotificationName:@"RaveApexSeekDeltaNotification" object:@(-15.0)];
    [self showToast:@"⏪ Jumped -15s"];
}

- (void)jumpForwards {
    [self fireHaptic];
    [[NSNotificationCenter defaultCenter] postNotificationName:@"RaveApexSeekDeltaNotification" object:@(15.0)];
    [self showToast:@"⏩ Jumped +15s"];
}

- (NSString *)apexLogText {
    NSArray<NSString *> *lines = apex_log_lines();
    if (lines.count == 0) return @"(Apex Log empty — hooks log here as they bind & fire.)";
    return [lines componentsJoinedByString:@"\n"];
}

- (void)showApexLog {
    dispatch_async(dispatch_get_main_queue(), ^{
        @try {
            BOOL overlayHasScene = (self.overlayWindow && [self.overlayWindow respondsToSelector:NSSelectorFromString(@"windowScene")] && [self.overlayWindow windowScene] != nil);
            UIView *parent = (overlayHasScene && self.overlayWindow.rootViewController.view) ? self.overlayWindow.rootViewController.view : (self.floatingButton.superview ?: [self findHostWindow]);
            if (!parent) {
                NSArray *windows = [UIApplication sharedApplication].windows;
                if (windows && windows.count > 0) parent = windows.firstObject;
            }
            if (!parent) return;

            if (!self.logPanel) {
                CGRect pb = parent.bounds;
                CGFloat w = MIN(pb.size.width - 24, 360);
                CGFloat h = MIN(pb.size.height - 160, 460);
                self.logPanel = [[UIView alloc] initWithFrame:CGRectMake((pb.size.width - w) / 2.0, 80, w, h)];
                self.logPanel.backgroundColor = [UIColor colorWithRed:0.04 green:0.04 blue:0.08 alpha:0.97];
                self.logPanel.layer.cornerRadius = 16;
                self.logPanel.layer.borderColor = [UIColor colorWithRed:0.4 green:0.9 blue:0.6 alpha:0.7].CGColor;
                self.logPanel.layer.borderWidth = 1.2;
                self.logPanel.clipsToBounds = YES;

                UILabel *hdr = [[UILabel alloc] initWithFrame:CGRectMake(14, 10, w - 100, 20)];
                hdr.text = @"📜 APEX LIVE LOG";
                hdr.textColor = [UIColor colorWithRed:0.4 green:0.95 blue:0.65 alpha:1.0];
                hdr.font = [UIFont systemFontOfSize:13 weight:UIFontWeightHeavy];
                [self.logPanel addSubview:hdr];

                UIButton *refresh = [UIButton buttonWithType:UIButtonTypeSystem];
                refresh.frame = CGRectMake(w - 96, 8, 44, 24);
                [refresh setTitle:@"↻" forState:UIControlStateNormal];
                refresh.titleLabel.font = [UIFont systemFontOfSize:17 weight:UIFontWeightBold];
                [refresh addTarget:self action:@selector(refreshApexLog) forControlEvents:UIControlEventTouchUpInside];
                [self.logPanel addSubview:refresh];

                UIButton *close = [UIButton buttonWithType:UIButtonTypeSystem];
                close.frame = CGRectMake(w - 48, 8, 40, 24);
                [close setTitle:@"✕" forState:UIControlStateNormal];
                close.titleLabel.font = [UIFont systemFontOfSize:15 weight:UIFontWeightBold];
                [close addTarget:self action:@selector(hideApexLog) forControlEvents:UIControlEventTouchUpInside];
                [self.logPanel addSubview:close];

                self.logTextView = [[UITextView alloc] initWithFrame:CGRectMake(8, 36, w - 16, h - 44)];
                self.logTextView.editable = NO;
                self.logTextView.backgroundColor = [UIColor clearColor];
                self.logTextView.textColor = [UIColor colorWithRed:0.8 green:0.95 blue:0.85 alpha:1.0];
                self.logTextView.font = [UIFont monospacedSystemFontOfSize:9.5 weight:UIFontWeightRegular];
                [self.logPanel addSubview:self.logTextView];

                [parent addSubview:self.logPanel];
            }
            self.logPanel.hidden = NO;
            [parent bringSubviewToFront:self.logPanel];
            [self refreshApexLog];
        } @catch (NSException *e) {
            apex_log([[NSString stringWithFormat:@"[FAULT] showApexLog: %@", e.reason] UTF8String]);
        }
    });
}

- (void)refreshApexLog {
    self.logTextView.text = [self apexLogText];
    // Scroll to the newest line.
    NSUInteger len = self.logTextView.text.length;
    if (len > 0) [self.logTextView scrollRangeToVisible:NSMakeRange(len - 1, 1)];
}

- (void)hideApexLog {
    self.logPanel.hidden = YES;
}

- (void)dumpEngineDiagnostics {
    [[NSNotificationCenter defaultCenter] postNotificationName:@"RaveApexDumpDiagnosticsNotification" object:nil];
}

- (void)toggleNativeDebugOverlay {
    dispatch_async(dispatch_get_main_queue(), ^{
        if ([RaveApexConfig sharedConfig].nativeDebugOverlayVisible) {
            BOOL overlayHasScene = (self.overlayWindow && [self.overlayWindow respondsToSelector:NSSelectorFromString(@"windowScene")] && [self.overlayWindow windowScene] != nil);
            UIView *parent = (overlayHasScene && self.overlayWindow.rootViewController.view) ? self.overlayWindow.rootViewController.view : (self.floatingButton.superview ?: [self findHostWindow]);
            if (!self.hudCardView && parent) {
                Class dbgCls = objc_getClass("_TtC4Rave12DebugOverlay");
                UIView *dbgView = nil;
                if (dbgCls) {
                    @try {
                        dbgView = [[dbgCls alloc] initWithFrame:CGRectMake(16, 55, 270, 160)];
                    } @catch (NSException *e) {
                        apex_log([[NSString stringWithFormat:@"[FAULT] DebugOverlay init: %@", e.reason] UTF8String]);
                    }
                }
                if (!dbgView) {
                    dbgView = [[UIView alloc] initWithFrame:CGRectMake(16, 55, 270, 110)];
                    dbgView.backgroundColor = [UIColor colorWithRed:0.05 green:0.05 blue:0.1 alpha:0.92];
                    dbgView.layer.cornerRadius = 14;
                    dbgView.layer.borderColor = [UIColor colorWithRed:0.4 green:0.2 blue:0.8 alpha:0.7].CGColor;
                    dbgView.layer.borderWidth = 1.2;
                    dbgView.clipsToBounds = YES;

                    UILabel *lbl = [[UILabel alloc] initWithFrame:CGRectMake(12, 8, 246, 94)];
                    lbl.numberOfLines = 5;
                    lbl.textColor = [UIColor colorWithRed:0.4 green:0.95 blue:0.65 alpha:1.0];
                    lbl.font = [UIFont monospacedSystemFontOfSize:10 weight:UIFontWeightMedium];
                    lbl.text = @"[RAVE TELEMETRY HUD]\nStatus: Active\nCPU Load: 0.0%";
                    lbl.tag = 999;
                    [dbgView addSubview:lbl];
                }
                self.hudCardView = dbgView;
                [parent addSubview:self.hudCardView];
                [parent bringSubviewToFront:self.hudCardView];
            }
            self.hudCardView.hidden = NO;
        } else {
            if (self.hudCardView) {
                self.hudCardView.hidden = YES;
            }
        }
    });
}

- (void)toggleMenuVisibility {
    if (![NSThread isMainThread]) {
        dispatch_async(dispatch_get_main_queue(), ^{
            [self toggleMenuVisibility];
        });
        return;
    }
    @try {
        static double lastToggleTime = 0.0;
        struct timeval tv;
        gettimeofday(&tv, NULL);
        double now = (double)tv.tv_sec + (double)tv.tv_usec / 1000000.0;
        if (now - lastToggleTime < 0.25) return;
        lastToggleTime = now;

        UIWindow *overlay = [self ensureOverlayWindow];
        BOOL overlayHasScene = (overlay && [overlay respondsToSelector:NSSelectorFromString(@"windowScene")] && [overlay windowScene] != nil);
        UIWindow *host = [self findHostWindow];
        UIView *rootView = self.floatingButton.superview;
        if (!rootView) {
            rootView = (overlay && overlayHasScene && overlay.rootViewController.view) ? overlay.rootViewController.view : host;
        }
        if (!rootView) {
            rootView = [UIApplication sharedApplication].keyWindow;
        }
        if (!rootView) {
            NSArray *windows = [UIApplication sharedApplication].windows;
            if (windows && windows.count > 0) rootView = windows.firstObject;
        }
        if (!rootView) return;

        if (!self.backdropView) {
            UIButton *bd = [UIButton buttonWithType:UIButtonTypeCustom];
            bd.frame = rootView.bounds;
            bd.backgroundColor = [UIColor colorWithWhite:0.0 alpha:0.45];
            bd.layer.zPosition = 9997.0;
            [bd addTarget:self action:@selector(toggleMenuVisibility) forControlEvents:UIControlEventTouchUpInside];
            self.backdropView = bd;
        }
        if (self.backdropView.superview != rootView) {
            [self.backdropView removeFromSuperview];
            [rootView addSubview:self.backdropView];
        }
        self.backdropView.frame = rootView.bounds;
        self.backdropView.layer.zPosition = 9997.0;

        if (!self.menuContainer) {
            [self setupMenuContainerInView:rootView];
        } else if (self.menuContainer.superview != rootView) {
            [self.menuContainer removeFromSuperview];
            [rootView addSubview:self.menuContainer];
            CGFloat targetW = 340;
            CGFloat targetH = 560;
            if (rootView.bounds.size.width < 350) targetW = MAX(280, rootView.bounds.size.width - 20);
            if (rootView.bounds.size.height < 580) targetH = MAX(400, rootView.bounds.size.height - 100);
            self.menuContainer.frame = CGRectMake((rootView.bounds.size.width - targetW) / 2.0, 90, targetW, targetH);
        }
        if (self.menuContainer) {
            self.menuContainer.layer.zPosition = 9998.0;
        }

        if (self.floatingButton && self.floatingButton.superview != rootView) {
            [self.floatingButton removeFromSuperview];
            [rootView addSubview:self.floatingButton];
        }
        if (self.floatingButton) {
            self.floatingButton.layer.zPosition = 9999.0;
        }

        if (!self.menuContainer) {
            self.isMenuOpen = NO;
            [self.floatingButton setTitle:[RaveApexConfig sharedConfig].customButtonEmoji ?: @"⚡" forState:UIControlStateNormal];
            return;
        }

        self.isMenuOpen = !self.isMenuOpen;

        // Honor the user's saved Control-Surface Opacity on open instead of forcing 1.0.
        CGFloat openAlpha = [self currentMenuOpacity];

        if (self.isMenuOpen) {
            self.backdropView.hidden = NO;
            self.menuContainer.hidden = NO;
            [rootView bringSubviewToFront:self.backdropView];
            [rootView bringSubviewToFront:self.menuContainer];
            if (self.floatingButton) [rootView bringSubviewToFront:self.floatingButton];
            apex_start_display_link();
            start_telemetry_monitor();
        }

        [UIView animateWithDuration:0.3 delay:0 usingSpringWithDamping:0.85 initialSpringVelocity:0 options:UIViewAnimationOptionCurveEaseInOut animations:^{
            if (self.isMenuOpen) {
                self.backdropView.alpha = 1.0;
                self.menuContainer.alpha = openAlpha;
                self.menuContainer.transform = CGAffineTransformIdentity;
                [self.floatingButton setTitle:@"✕" forState:UIControlStateNormal];
            } else {
                self.backdropView.alpha = 0.0;
                self.menuContainer.alpha = 0.0;
                self.menuContainer.transform = CGAffineTransformMakeScale(0.88, 0.88);
                [self.floatingButton setTitle:[RaveApexConfig sharedConfig].customButtonEmoji ?: @"⚡" forState:UIControlStateNormal];
            }
        } completion:^(BOOL finished) {
            if (!self.isMenuOpen) {
                if (self.menuContainer) self.menuContainer.hidden = YES;
                if (self.backdropView) {
                    self.backdropView.hidden = YES;
                    [self.backdropView removeFromSuperview];
                }
            }
        }];
    } @catch (NSException *e) {
        NSLog(@"[RaveApexCore] toggleMenuVisibility guarded exception: %@", e);
    }
}

- (void)updateTelemetryCPU:(float)cpu {
    dispatch_async(dispatch_get_main_queue(), ^{
        double nudge = [RaveApexConfig sharedConfig].manualClockNudgeMs;
        NSString *telemetryText = [NSString stringWithFormat:@"SYNC TELEMETRY: System Nominal (Nudge: %+.0fms)\nCPU: %.1f%% | Audio Preamp: %.1fx", nudge, cpu * 100.0f, [RaveApexConfig sharedConfig].audioPreampVolume];

        if (self.telemetryLabel) {
            self.telemetryLabel.text = telemetryText;
        }

        if (self.hudCardView && !self.hudCardView.hidden) {
            UILabel *hudLbl = (UILabel *)[self.hudCardView viewWithTag:999];
            if (hudLbl && [hudLbl isKindOfClass:[UILabel class]]) {
                hudLbl.text = [NSString stringWithFormat:@"[RAVE TELEMETRY HUD]\nStatus: Nominal\nCPU Load: %.1f%%", cpu * 100.0f];
            }
        }
    });
}

- (void)updateLiveTelemetryCPU:(float)cpuFraction memoryMB:(double)memMB fps:(double)fps {
    dispatch_async(dispatch_get_main_queue(), ^{
        RaveApexConfig *c = [RaveApexConfig sharedConfig];
        double nudge = c.manualClockNudgeMs;
        float cpuPct = cpuFraction * 100.0f;

        [self updateTacticalPillCPU:cpuPct fps:fps];

        if (self.telemetryLabel) {
            // Only the drift line is gated by the Sync Drift Monitor toggle; the live
            // hardware readout stays on so the footer is never stale.
            NSString *driftLine = c.telemetryHUDEnabled
                ? [NSString stringWithFormat:@"Sync Nudge: %+.0fms | Preamp: %.1fx", nudge, c.audioPreampVolume]
                : @"Sync Monitor: OFF";
            self.telemetryLabel.text = [NSString stringWithFormat:@"CPU %.1f%%  |  MEM %.0f MB  |  %.0f FPS\n%@",
                                        cpuPct, memMB, fps, driftLine];
        }

        if (self.hudCardView && !self.hudCardView.hidden) {
            @try {
                if ([self.hudCardView respondsToSelector:NSSelectorFromString(@"driftLabel")]) {
                    id drift = [self.hudCardView valueForKey:@"driftLabel"];
                    if (drift && [drift respondsToSelector:NSSelectorFromString(@"setText:")]) {
                        ((void (*)(id, SEL, id))objc_msgSend)(drift, NSSelectorFromString(@"setText:"), [NSString stringWithFormat:@"Drift: %+.0fms", nudge]);
                    }
                }
                if ([self.hudCardView respondsToSelector:NSSelectorFromString(@"clockStatusLabel")]) {
                    id clock = [self.hudCardView valueForKey:@"clockStatusLabel"];
                    if (clock && [clock respondsToSelector:NSSelectorFromString(@"setText:")]) {
                        ((void (*)(id, SEL, id))objc_msgSend)(clock, NSSelectorFromString(@"setText:"), @"Clock: Locked (Apex)");
                    }
                }
                if ([self.hudCardView respondsToSelector:NSSelectorFromString(@"stateLabel")]) {
                    id state = [self.hudCardView valueForKey:@"stateLabel"];
                    if (state && [state respondsToSelector:NSSelectorFromString(@"setText:")]) {
                        ((void (*)(id, SEL, id))objc_msgSend)(state, NSSelectorFromString(@"setText:"), [NSString stringWithFormat:@"FPS: %.0f | Preamp: %.1fx", fps, c.audioPreampVolume]);
                    }
                }
            } @catch (NSException *e) {
                apex_log([[NSString stringWithFormat:@"[FAULT] updateLiveTelemetry: %@", e.reason] UTF8String]);
            }

            UILabel *hudLbl = (UILabel *)[self.hudCardView viewWithTag:999];
            if (hudLbl && [hudLbl isKindOfClass:[UILabel class]]) {
                hudLbl.text = [NSString stringWithFormat:@"[RAVE TELEMETRY HUD]\nCPU %.1f%%  MEM %.0f MB\nRender: %.0f FPS", cpuPct, memMB, fps];
            }
        }
    });
}

- (void)updateBandwidthTelemetry:(NSString *)results {
    dispatch_async(dispatch_get_main_queue(), ^{
        if (!self.telemetryLabel) return;
        self.telemetryLabel.text = [NSString stringWithFormat:@"SPEED TEST COMPLETED\nThroughput: %@", results];
    });
}

- (void)showToast:(NSString *)message {
    dispatch_async(dispatch_get_main_queue(), ^{
        BOOL overlayHasScene = (self.overlayWindow && [self.overlayWindow respondsToSelector:NSSelectorFromString(@"windowScene")] && [self.overlayWindow windowScene] != nil);
        UIView *parent = (overlayHasScene && self.overlayWindow.rootViewController.view) ? self.overlayWindow.rootViewController.view : (self.floatingButton.superview ?: [self findHostWindow]);
        if (!parent) return;

        UILabel *toast = [[UILabel alloc] initWithFrame:CGRectMake((parent.bounds.size.width - 260) / 2.0, 70, 260, 34)];
        toast.text = message;
        toast.textAlignment = NSTextAlignmentCenter;
        toast.textColor = [UIColor whiteColor];
        toast.font = [UIFont systemFontOfSize:11.5 weight:UIFontWeightBold];
        toast.backgroundColor = [UIColor colorWithRed:0.2 green:0.1 blue:0.4 alpha:0.9];
        toast.layer.cornerRadius = 17;
        toast.clipsToBounds = YES;
        toast.alpha = 0.0;
        [parent addSubview:toast];
        [parent bringSubviewToFront:toast];

        [UIView animateWithDuration:0.3 animations:^{ toast.alpha = 1.0; } completion:^(BOOL finished) {
            [UIView animateWithDuration:0.3 delay:1.8 options:0 animations:^{ toast.alpha = 0.0; } completion:^(BOOL f) {
                [toast removeFromSuperview];
            }];
        }];
    });
}

@end
