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
@property (atomic, assign) BOOL crownSpoofEnabled;
@property (atomic, assign) BOOL localHostControlOverride;
@property (atomic, assign) BOOL antiKickInterceptionEnabled;
@property (atomic, assign) BOOL voteQuorumAutopilotEnabled;
@property (atomic, assign) BOOL unhookedSyncEnabled;
@property (atomic, assign) BOOL omniLeaderElevationEnabled;
@property (atomic, assign) BOOL ghostPresenceEnabled; // [GODMODE] Hide from participant & talking rosters
@property (atomic, assign) BOOL phantomCrownLockEnabled;

// GROUP 2: SONIC WARFARE & AUDIO DSP
@property (atomic, assign) BOOL audioPreampBoostEnabled;
@property (atomic, assign) CGFloat audioPreampVolume; // 1.0 - 10.0x (up to 1000% gain)
@property (atomic, assign) BOOL voiceDuckingEnabled; // Auto-duck video -14dB when participants speak
@property (atomic, assign) BOOL dialogueEqEnabled; // 3-Band vocal clarity EQ
@property (atomic, assign) BOOL forceMicTransmissionEnabled;
@property (atomic, assign) BOOL stealthGhostListenerEnabled;
@property (atomic, assign) BOOL backgroundAudioEnabled;
@property (atomic, assign) BOOL dualStreamAudioBalanceEnabled;

// GROUP 3: VIDEO DEITIES & PLAYBACK CONTROL
@property (atomic, assign) BOOL uncappedSpeedEnabled;
@property (atomic, assign) CGFloat playbackSpeed; // 0.10 - 10.0x (Extreme Slow-mo to Hyper-speed)
@property (atomic, assign) BOOL microClockSlewingEnabled; // Smooth pitch-corrected ±2% rate slewing instead of stutter seek
@property (atomic, assign) BOOL forcePiPEnabled;
@property (atomic, assign) BOOL highestRenditionLockEnabled; // 4K / 1080p 60fps lock
@property (atomic, assign) BOOL bufferOverdriveEnabled; // 180s forward buffer cache
@property (atomic, assign) BOOL adBlockEnabled;

// GROUP 4: GHOST INTELLIGENCE & SOCIAL BYPASS
@property (atomic, assign) BOOL ghostTypingEnabled; // [GODMODE] Conceal typing indicator packets
@property (atomic, assign) BOOL antiRecallChatEnabled; // [GODMODE] Retain deleted messages
@property (atomic, assign) BOOL autoUnblurChatImagesEnabled; // [GODMODE] Unblur all chat media attachments
@property (atomic, assign) BOOL autoTranslateChatEnabled; // [GODMODE] Real-time auto-translate incoming messages
@property (atomic, assign) BOOL matureBypassEnabled;
@property (atomic, assign) BOOL premiumBypassEnabled;
@property (atomic, assign) BOOL iapReceiptSpoofEnabled; // [GODMODE] Spoof IAPManager receipt validation
@property (atomic, assign) BOOL oledBlackoutThemeEnabled; // Pure #000000 OLED theme

// GROUP 5: TACTICAL HUD, PROFILER & EMERGENCY
@property (atomic, assign) BOOL telemetryHUDEnabled;
@property (atomic, assign) BOOL tacticalPillEnabled; // Floating Dynamic Island status pill
@property (atomic, assign) BOOL nativeDebugOverlayVisible;
@property (atomic, assign) double manualClockNudgeMs;
@property (atomic, assign) BOOL cpuMonitoringEnabled;
@property (atomic, assign) BOOL panicButtonEnabled; // Triple-tap corner for instant 0ms hide

// GROUP 6: EXTENDED APEX EXPANSION (FULL BUNDLE & TROLL PACK)
@property (atomic, assign) BOOL autoRejoinEnabled;            // Auto-reconnect to room on unexpected kick/demote
@property (atomic, assign) NSInteger audioEqPreset;           // 0=Flat, 1=Bass Boost (+6dB), 2=Vocal Clarity, 3=Treble Boost
@property (atomic, assign) BOOL pingSpoofEnabled;             // Force 0ms display on room latency meters
@property (nonatomic, strong) NSString *customButtonEmoji;    // Floating button icon (⚡, 👑, 🛡️, 🔥, 🛸, 💎)
@property (atomic, assign) BOOL minimalPillModeEnabled;       // Compact pill mode when docked to edge
@property (atomic, assign) BOOL autoPiPOnBackground;          // Trigger PiP automatically on app backgrounding
@property (nonatomic, strong, nullable) NSString *lastKnownMeshId; // Saved active room ID for auto-rejoin

// GROUP 7: FRANKG MASTER EXPANSION (MEDIA LOOP, PITCH PRESERVATION & TURBO PREAMP)
@property (atomic, assign) BOOL autoLoopPlaybackEnabled;          // Auto-loop video back to 0s on finish
@property (atomic, assign) BOOL pitchCorrectionEnabled;           // Preserve natural voice pitch during rate multiplier
@property (atomic, assign) BOOL turboPreampEnabled;               // Extreme +1400% (15.0x) Audio Boost

// GROUP 8: CHAOS & SOVEREIGN GODMODE SUITE (EXTREME EXPANSION)
@property (atomic, assign) BOOL megaPreamp25xEnabled;              // Extreme +2400% (25.0x) Mega-Preamp Overdrive
@property (atomic, assign) NSInteger pingSpoofMode;                // 0=Off, 1=0ms God Ping, 2=9999ms Fake Lag-Switch
@property (atomic, assign) BOOL sonicJammerUltraActive;            // 24x Ultra VoIP SFX Barrage
@property (atomic, assign) BOOL micLockAlwaysOn;                   // Hardware-locked microphone transmission

// GROUP 9: SOVEREIGN APEX V2 & GHOST WEAPONRY (EXTREME GODMODE MATRIX)
@property (atomic, assign) BOOL megaPreamp30xEnabled;              // Extreme +2900% (30.0x) Max Preamp Overdrive
@property (atomic, assign) BOOL kickReflectorEnabled;              // Eviction Immunity & Automatic Counter-Kick Reflector
@property (atomic, assign) BOOL phantomIdentityCamouflageEnabled; // Dynamic anonymous handle / guest disguise
@property (atomic, assign) NSInteger vocalPitchShiftPreset;        // 0=Off, 1=Helium (+600c), 2=Demon (-600c), 3=Robot (+1200c)
@property (atomic, assign) BOOL ultraBassquakeEnabled;             // +12dB Subwoofer resonance DSP boost
@property (atomic, assign) BOOL antiAfkImmortalizerEnabled;        // Prevent idle sleep & background disconnects
@property (atomic, assign) BOOL voteHijackerAutoPassEnabled;       // Auto-pass active vote polls
@property (atomic, assign) BOOL streamSnifferAutoCopyEnabled;      // Auto-copy decrypted stream M3U8 on load

// GROUP 10: RED-TEAM COMBAT SUITE (TRACKS 1-3)
@property (atomic, assign) BOOL quantumGhostPresenceEnabled;      // Track 1: WebRTC peer SDP & roster cloak
@property (atomic, assign) BOOL stealthAudioSnooperEnabled;        // Track 2: Raw PCM tap & independent participant gain (+400%)
@property (atomic, assign) CGFloat stealthAudioSnooperGain;       // Track 2: Snooper gain factor (1.0x - 5.0x)
@property (atomic, assign) BOOL evictionReflector2Enabled;        // Track 3: Automatic instigator identification & counter-kick reflection
@property (atomic, assign) BOOL roomFreezeStrobeEnabled;          // Track 3: Clock jitter strobe (peers freeze, local plays smooth)

- (void)save;
- (void)load;
- (void)resetToDefaults;

@end

// Live telemetry pump (CPU + sync readout). Idempotent: safe to call repeatedly;
// starts exactly once. Declared here so the control surface can arm it on mount.
void start_telemetry_monitor(void);

NS_ASSUME_NONNULL_END
