// ==============================================================================
// ARCHITECT CORE: RAVE APEX RUNTIME HOOK ENGINE
// Installs guarded ObjC-runtime method swizzles that ENFORCE the capability
// ledger against verified host symbols (sh.weme.wemesh v8.1.2), plus real
// hardware telemetry (task CPU / resident memory / CADisplayLink FPS).
//
// Every hook consults RaveApexConfig at call time, NULL-checks the resolved
// Method, and falls back to the original IMP — a missing/stripped symbol
// degrades to a no-op instead of a crash (defensive circuit breaker).
// ==============================================================================

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

// Idempotent. Resolves + swizzles every verified host symbol, starts the live
// FPS display link, and applies the background-audio session. Safe to call more
// than once; the actual install runs exactly once.
void install_apex_hooks(void);

// --- Real hardware telemetry (pure Darwin / QuartzCore, no host dependency) ---
double apex_cpu_usage(void);   // Fraction of ONE core summed across live threads (1.0 = a full core).
double apex_mem_mb(void);      // Resident footprint of this process, in MiB.
double apex_current_fps(void); // Most recent CADisplayLink frame rate (0 until the link ticks).
void apex_start_display_link(void); // Idempotently activate CADisplayLink for FPS measurement.

// Applies / releases the AVAudioSession playback category per the live
// backgroundAudioEnabled flag. Guarded; errors are swallowed.
void apex_apply_background_audio(void);

// --- On-device observability (no Mac / Console required) ----------------------
// Append a line to the in-app ring buffer (also mirrored to NSLog). The menu's
// "Apex Log" viewer renders apex_log_lines() so hook activity is visible live.
void apex_log(const char *utf8);
NSArray<NSString *> *apex_log_lines(void);

// Enumerate EVERY method of every verified host class to the log + Console, so a
// single device run captures all candidate selectors ("find all hooks").
void apex_dump_host_symbols(void);

// Force the active VideoPlayer to its highest rendition (bumpUpQuality +
// uncapped AVPlayerItem peak bitrate). Pass nil to auto-locate the player.
void apex_enforce_hd_quality(id _Nullable videoPlayer);

// Swizzle the host UI lifecycle (UIWindow makeKeyAndVisible + UIViewController
// viewDidAppear:) so the control surface mounts onto the host's OWN window the
// instant it appears — no scene detection, no timers. Idempotent; safe to call
// from the dylib constructor (UIKit is already resident at load time).
void install_ui_lifecycle_hooks(void);

// Active VideoPlayer & AVPlayer discovery and rate/seek/PiP control
id _Nullable apex_find_active_video_player(void);
id _Nullable apex_find_av_player(id _Nullable videoPlayer);
void apex_apply_playback_rate(float rate);
void apex_seek_player_delta(double deltaSeconds);
void apex_trigger_pip(void);

// Audio Processor Metaclass Preamp Control
void apex_apply_preamp_volume(float factor);

// Hardware Host CPUMonitoring Readout
double apex_report_cpu_monitoring(void);

// Frankg Master Expansion Functions
void apex_toggle_play_pause(void);
void apex_toggle_room_privacy(void);
void apex_trigger_discrete_sfx(BOOL isBoop);

// Sovereign Apex V2 & Ghost Godmode Weaponry
void apex_sniff_and_copy_stream_url(void);
void apex_step_frame_delta(NSInteger frames);
void apex_jump_percentage(double percent);
void apex_randomize_phantom_identity(void);
void apex_apply_vocal_pitch_preset(NSInteger preset);
void apex_trigger_sfx_barrage_ultra(int count);
void apex_toggle_anti_afk(BOOL enable);
void apex_trigger_kick_reflector(void);
void apex_toggle_vote_hijacker(void);

// Red-Team Combat Suite Functions (Tracks 1-3)
void apex_toggle_quantum_ghost(BOOL enable);
void apex_toggle_audio_snooper(BOOL enable);
void apex_apply_snooper_gain(CGFloat gain);
void apex_trigger_eviction_reflector_2(void);
void apex_trigger_room_freeze_strobe(void);

NS_ASSUME_NONNULL_END
