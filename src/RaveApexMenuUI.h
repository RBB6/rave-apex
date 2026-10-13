// ==============================================================================
// ARCHITECT CORE: RAVE APEX MENU UI (RESILIENT KEY-WINDOW CONTROL SURFACE)
// Dedicated Zero-Collision Overlay Window Architecture
// ==============================================================================

#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

@interface RaveApexMenuUI : NSObject

@property (nonatomic, strong, nullable) UIWindow *overlayWindow;
@property (nonatomic, strong, nullable) UIButton *floatingButton;
@property (nonatomic, strong, nullable) UIVisualEffectView *menuContainer;
@property (nonatomic, assign) BOOL isMenuOpen;

+ (instancetype)sharedInstance;
- (void)initializeOverlay;
- (void)launchMenuWithApp;
- (void)openMenuAnimated:(BOOL)animated;
- (void)closeMenuAnimated:(BOOL)animated;
- (void)ensureFloatingButtonOnTop;
- (void)attachToWindow:(nullable UIWindow *)window;
- (void)toggleMenuVisibility;
- (void)toggleNativeDebugOverlay;
- (void)updateTelemetryCPU:(float)cpu;
- (void)updateLiveTelemetryCPU:(float)cpuFraction memoryMB:(double)memMB fps:(double)fps;
- (void)updateBandwidthTelemetry:(NSString *)results;
- (void)showToast:(NSString *)message;
- (void)triggerVoipSFX;
- (void)resetVideoQueue;
- (void)dumpEngineDiagnostics;
- (void)panicHide;
- (void)cycleFloatingButtonIcon;
- (void)toggleMinimalPillMode;
- (void)sniffActiveStream;
- (void)triggerChatFlooder;
- (void)broadcastFakeSystemMessage;
- (void)togglePlayPauseStream;
- (void)copyAllDiagnosticsToClipboard;
- (void)toggleRoomPrivacyAction;
- (void)triggerTurboPreamp;
- (void)playBeepSFX;
- (void)playBoopSFX;
- (void)speedPresetSelected:(UISegmentedControl *)sender;
- (void)triggerMegaPreamp30x;
- (void)toggleKickReflector;
- (void)randomizePhantomIdentity;
- (void)cycleVocalPitchShift;
- (void)toggleUltraBassquake;
- (void)toggleAntiAfkImmortalizer;
- (void)toggleVoteHijacker;
- (void)jumpPercentage25;
- (void)jumpPercentage50;
- (void)jumpPercentage75;
- (void)stepFrameBackward;
- (void)stepFrameForward;
- (void)triggerSonicJammer32x;
- (void)triggerEvictionReflector2;
- (void)triggerRoomFreezeStrobe;
- (void)toggleStealthAudioSnooper;
- (void)toggleQuantumGhostPresence;

@end

NS_ASSUME_NONNULL_END
