// ==============================================================================
// ARCHITECT CORE: RAVE APEX RECONSTRUCTION TWEAK ENGINE
// PHASE 7: ADVANCED TELEMETRY & RUNTIME PRIVILEGE ARBITRATION (25-CAPABILITY MATRIX)
// TARGET: Rave iOS (sh.weme.wemesh v8.1.2 Build 2723)
// ==============================================================================

#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
#import <AVFoundation/AVFoundation.h>
#import <AVKit/AVKit.h>
#import <objc/runtime.h>
#import <objc/message.h>

NS_ASSUME_NONNULL_BEGIN

@interface RaveApexConfig : NSObject

+ (instancetype)sharedConfig;

// GROUP 1: ROOM GOVERNANCE & SOVEREIGN DOMINANCE
@property (nonatomic, assign) BOOL crownSpoofEnabled;
@property (nonatomic, assign) BOOL localHostControlOverride;
@property (nonatomic, assign) BOOL antiKickInterceptionEnabled;
@property (nonatomic, assign) BOOL voteQuorumAutopilotEnabled;
@property (nonatomic, assign) BOOL unhookedSyncEnabled;
@property (nonatomic, assign) BOOL omniLeaderElevationEnabled;
@property (nonatomic, assign) BOOL ghostPresenceEnabled; // [GODMODE] Hide from participant & talking rosters
@property (nonatomic, assign) BOOL phantomCrownLockEnabled;

// GROUP 2: SONIC WARFARE & AUDIO DSP
@property (nonatomic, assign) BOOL audioPreampBoostEnabled;
@property (nonatomic, assign) CGFloat audioPreampVolume; // 1.0 - 10.0x (up to 1000% gain)
@property (nonatomic, assign) BOOL voiceDuckingEnabled; // Auto-duck video -14dB when participants speak
@property (nonatomic, assign) BOOL dialogueEqEnabled; // 3-Band vocal clarity EQ
@property (nonatomic, assign) BOOL forceMicTransmissionEnabled;
@property (nonatomic, assign) BOOL stealthGhostListenerEnabled;
@property (nonatomic, assign) BOOL backgroundAudioEnabled;
@property (nonatomic, assign) BOOL dualStreamAudioBalanceEnabled;

// GROUP 3: VIDEO DEITIES & PLAYBACK CONTROL
@property (nonatomic, assign) BOOL uncappedSpeedEnabled;
@property (nonatomic, assign) CGFloat playbackSpeed; // 0.10 - 10.0x (Extreme Slow-mo to Hyper-speed)
@property (nonatomic, assign) BOOL microClockSlewingEnabled; // Smooth pitch-corrected ±2% rate slewing instead of stutter seek
@property (nonatomic, assign) BOOL forcePiPEnabled;
@property (nonatomic, assign) BOOL highestRenditionLockEnabled; // 4K / 1080p 60fps lock
@property (nonatomic, assign) BOOL bufferOverdriveEnabled; // 180s forward buffer cache
@property (nonatomic, assign) BOOL adBlockEnabled;

// GROUP 4: GHOST INTELLIGENCE & SOCIAL BYPASS
@property (nonatomic, assign) BOOL ghostTypingEnabled; // [GODMODE] Conceal typing indicator packets
@property (nonatomic, assign) BOOL antiRecallChatEnabled; // [GODMODE] Retain deleted messages
@property (nonatomic, assign) BOOL autoUnblurChatImagesEnabled; // [GODMODE] Unblur all chat media attachments
@property (nonatomic, assign) BOOL autoTranslateChatEnabled; // [GODMODE] Real-time auto-translate incoming messages
@property (nonatomic, assign) BOOL matureBypassEnabled;
@property (nonatomic, assign) BOOL premiumBypassEnabled;
@property (nonatomic, assign) BOOL iapReceiptSpoofEnabled; // [GODMODE] Spoof IAPManager receipt validation
@property (nonatomic, assign) BOOL oledBlackoutThemeEnabled; // Pure #000000 OLED theme

// GROUP 5: TACTICAL HUD, PROFILER & EMERGENCY
@property (nonatomic, assign) BOOL telemetryHUDEnabled;
@property (nonatomic, assign) BOOL tacticalPillEnabled; // Floating Dynamic Island status pill
@property (nonatomic, assign) BOOL nativeDebugOverlayVisible;
@property (nonatomic, assign) double manualClockNudgeMs;
@property (nonatomic, assign) BOOL cpuMonitoringEnabled;
@property (nonatomic, assign) BOOL panicButtonEnabled; // Triple-tap corner for instant 0ms hide

// GROUP 6: EXTENDED APEX EXPANSION (FULL BUNDLE & TROLL PACK)
@property (nonatomic, assign) BOOL autoRejoinEnabled;            // Auto-reconnect to room on unexpected kick/demote
@property (nonatomic, assign) NSInteger audioEqPreset;           // 0=Flat, 1=Bass Boost (+6dB), 2=Vocal Clarity, 3=Treble Boost
@property (nonatomic, assign) BOOL pingSpoofEnabled;             // Force 0ms display on room latency meters
@property (nonatomic, strong) NSString *customButtonEmoji;       // Floating button icon (⚡, 👑, 🛡️, 🔥, 🛸, 💎)
@property (nonatomic, assign) BOOL minimalPillModeEnabled;       // Compact pill mode when docked to edge
@property (nonatomic, assign) BOOL autoPiPOnBackground;          // Trigger PiP automatically on app backgrounding
@property (nonatomic, strong, nullable) NSString *lastKnownMeshId; // Saved active room ID for auto-rejoin

// GROUP 7: FRANKG MASTER EXPANSION (MEDIA LOOP, PITCH PRESERVATION & TURBO PREAMP)
@property (nonatomic, assign) BOOL autoLoopPlaybackEnabled;          // Auto-loop video back to 0s on finish
@property (nonatomic, assign) BOOL pitchCorrectionEnabled;           // Preserve natural voice pitch during rate multiplier
@property (nonatomic, assign) BOOL turboPreampEnabled;               // Extreme +1400% (15.0x) Audio Boost

// GROUP 8: CHAOS & SOVEREIGN GODMODE SUITE (EXTREME EXPANSION)
@property (nonatomic, assign) BOOL megaPreamp25xEnabled;              // Extreme +2400% (25.0x) Mega-Preamp Overdrive
@property (nonatomic, assign) NSInteger pingSpoofMode;                // 0=Off, 1=0ms God Ping, 2=9999ms Fake Lag-Switch
@property (nonatomic, assign) BOOL sonicJammerUltraActive;            // 24x Ultra VoIP SFX Barrage
@property (nonatomic, assign) BOOL micLockAlwaysOn;                   // Hardware-locked microphone transmission

// GROUP 9: SOVEREIGN APEX V2 & GHOST WEAPONRY (EXTREME GODMODE MATRIX)
@property (nonatomic, assign) BOOL megaPreamp30xEnabled;              // Extreme +2900% (30.0x) Max Preamp Overdrive
@property (nonatomic, assign) BOOL kickReflectorEnabled;              // Eviction Immunity & Automatic Counter-Kick Reflector
@property (nonatomic, assign) BOOL phantomIdentityCamouflageEnabled; // Dynamic anonymous handle / guest disguise
@property (nonatomic, assign) NSInteger vocalPitchShiftPreset;        // 0=Off, 1=Helium (+600c), 2=Demon (-600c), 3=Robot (+1200c)
@property (nonatomic, assign) BOOL ultraBassquakeEnabled;             // +12dB Subwoofer resonance DSP boost
@property (nonatomic, assign) BOOL antiAfkImmortalizerEnabled;        // Prevent idle sleep & background disconnects
@property (nonatomic, assign) BOOL voteHijackerAutoPassEnabled;       // Auto-pass active vote polls
@property (nonatomic, assign) BOOL streamSnifferAutoCopyEnabled;      // Auto-copy decrypted stream M3U8 on load

// GROUP 10: RED-TEAM COMBAT SUITE (TRACKS 1-3)
@property (nonatomic, assign) BOOL quantumGhostPresenceEnabled;      // Track 1: WebRTC peer SDP & roster cloak
@property (nonatomic, assign) BOOL stealthAudioSnooperEnabled;        // Track 2: Raw PCM tap & independent participant gain (+400%)
@property (nonatomic, assign) CGFloat stealthAudioSnooperGain;       // Track 2: Snooper gain factor (1.0x - 5.0x)
@property (nonatomic, assign) BOOL evictionReflector2Enabled;        // Track 3: Automatic instigator identification & counter-kick reflection
@property (nonatomic, assign) BOOL roomFreezeStrobeEnabled;          // Track 3: Clock jitter strobe (peers freeze, local plays smooth)

- (void)save;
- (void)load;
- (void)resetToDefaults;

@end

// Live telemetry pump (CPU + sync readout). Idempotent: safe to call repeatedly;
// starts exactly once. Declared here so the control surface can arm it on mount.
void start_telemetry_monitor(void);

NS_ASSUME_NONNULL_END
