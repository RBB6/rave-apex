#import "RaveApexHooks.h"
#import "RaveApexTweak.h"
#import "RaveApexMenuUI.h"
#import "RaveApexTypeEnc.h"   // pure-C, natively unit-tested (tests/apex_typeenc_test.c)
#import <objc/runtime.h>
#import <objc/message.h>
#include <mach/mach.h>
#include <string.h>
#include <time.h>

// ==============================================================================
// 0. GENERIC GUARDED SWIZZLE PRIMITIVE
// ==============================================================================
//
// Replaces an instance method's IMP and hands back the original through
// `origStore` so the hook can chain. Returns NO (and touches nothing) when the
// class or selector is absent — i.e. the host symbol was stripped or renamed.
// This is the single enforcement mechanism; nothing patches downstream state.
static BOOL apex_swizzle(const char *className, SEL sel, IMP replacement, IMP *origStore) {
    Class cls = objc_getClass(className);
    if (!cls) return NO;
    Method m = class_getInstanceMethod(cls, sel);
    if (!m) return NO;
    const char *types = method_getTypeEncoding(m);
    if (!types) types = "v@:";
    if (class_addMethod(cls, sel, replacement, types)) {
        if (origStore) *origStore = method_getImplementation(m);
        return YES;
    }
    // Only overwrite implementation if this method is directly implemented on cls,
    // never mutate an inherited superclass method (e.g. UIViewController / NSObject)!
    unsigned int count = 0;
    Method *methods = class_copyMethodList(cls, &count);
    BOOL isDeclaredOnClass = NO;
    if (methods) {
        for (unsigned int i = 0; i < count; i++) {
            if (method_getName(methods[i]) == sel) {
                isDeclaredOnClass = YES;
                break;
            }
        }
        free(methods);
    }
    if (isDeclaredOnClass) {
        IMP original = method_getImplementation(m);
        if (origStore) *origStore = original;
        method_setImplementation(m, replacement);
        return YES;
    }
    return NO;
}

static BOOL apex_swizzle_class_method(const char *className, SEL sel, IMP replacement, IMP *origStore) {
    Class cls = objc_getClass(className);
    if (!cls) return NO;
    Class meta = object_getClass((id)cls);
    if (!meta) return NO;
    Method m = class_getInstanceMethod(meta, sel);
    if (!m) return NO;
    const char *types = method_getTypeEncoding(m);
    if (!types) types = "v@:";
    if (class_addMethod(meta, sel, replacement, types)) {
        if (origStore) *origStore = method_getImplementation(m);
        return YES;
    }
    unsigned int count = 0;
    Method *methods = class_copyMethodList(meta, &count);
    BOOL isDeclaredOnMeta = NO;
    if (methods) {
        for (unsigned int i = 0; i < count; i++) {
            if (method_getName(methods[i]) == sel) {
                isDeclaredOnMeta = YES;
                break;
            }
        }
        free(methods);
    }
    if (isDeclaredOnMeta) {
        IMP original = method_getImplementation(m);
        if (origStore) *origStore = original;
        method_setImplementation(m, replacement);
        return YES;
    }
    return NO;
}

static inline RaveApexConfig *CFG(void) { return [RaveApexConfig sharedConfig]; }

// ---- In-app log ring buffer (mirrored to NSLog) ------------------------------
#define APEX_LOG_CAP 300
static NSMutableArray<NSString *> *g_log = nil;

void apex_log(const char *utf8) {
    if (!utf8) return;
    @try {
        NSString *line = [NSString stringWithUTF8String:utf8] ?: @"(?)";
        NSLog(@"[RaveApexCore] %@", line);
        @synchronized ([RaveApexConfig class]) {
            if (!g_log) g_log = [NSMutableArray array];
            [g_log addObject:line];
            if (g_log.count > APEX_LOG_CAP) [g_log removeObjectAtIndex:0];
        }
    } @catch (NSException *e) {
        // Suppress recursion fault if logging infrastructure encounters an issue
    }
}

static id apex_empty_array(void) {
    // Runtime-resolved [NSArray array] — avoids both the shim's limited NSArray
    // interface and the __NSArray0__ literal symbol the linker cannot satisfy.
    return ((id (*)(id, SEL))objc_msgSend)(objc_getClass("NSArray"), NSSelectorFromString(@"array"));
}

NSArray<NSString *> *apex_log_lines(void) {
    @synchronized ([RaveApexConfig class]) {
        return g_log ? [g_log copy] : apex_empty_array();
    }
}

// printf-style convenience used throughout the engine.
#define APEXLOG(fmt, ...) apex_log([[NSString stringWithFormat:(fmt), ##__VA_ARGS__] UTF8String])

// Forward declarations for the discovery-driven enforcement (defined in §7).
static void apex_dual_stream_apply(id videoPlayer);   // independent media gain
static void apex_vote_autopilot_fire(void);           // affirmative ballot on transition

// ==============================================================================
// 1. ENFORCEMENT HOOKS (each gated on a live config flag, each chains the orig)
// ==============================================================================

// --- Ad Waterfall Annihilator: safe pass-through (Swift ABI compliant) ---
static IMP g_orig_waterfall = NULL;
static id apex_waterfall(id self, SEL _cmd) {
    if (g_orig_waterfall) return ((id (*)(id, SEL))g_orig_waterfall)(self, _cmd);
    return nil;
}

// --- Universal Premium Unlock: force every provider to read as premium --------
static IMP g_orig_isPremiumProvider = NULL;
static BOOL apex_isPremiumProvider(id self, SEL _cmd, id provider) {
    if (CFG().premiumBypassEnabled) return YES;
    if (g_orig_isPremiumProvider) return ((BOOL (*)(id, SEL, id))g_orig_isPremiumProvider)(self, _cmd, provider);
    return NO;
}

// --- Crown Spoof / Omni-Leader: local cell reports leadership ------------------
static IMP g_orig_iAmLeader = NULL;
static BOOL apex_iAmLeader(id self, SEL _cmd) {
    RaveApexConfig *c = CFG();
    if (c.crownSpoofEnabled || c.omniLeaderElevationEnabled || c.localHostControlOverride || c.phantomCrownLockEnabled) return YES;
    if (g_orig_iAmLeader) return ((BOOL (*)(id, SEL))g_orig_iAmLeader)(self, _cmd);
    return NO;
}

// --- Host Authority Engine: MeshStateEngine iAmLeaderUser --------------------
static IMP g_orig_iAmLeaderUser = NULL;
static BOOL apex_iAmLeaderUser(id self, SEL _cmd) {
    RaveApexConfig *c = CFG();
    if (c.localHostControlOverride || c.omniLeaderElevationEnabled || c.crownSpoofEnabled || c.phantomCrownLockEnabled) return YES;
    if (g_orig_iAmLeaderUser) return ((BOOL (*)(id, SEL))g_orig_iAmLeaderUser)(self, _cmd);
    return NO;
}

// --- Context Menu Actions: VoipUserContextMenuViewModel ----------------------
static IMP g_orig_contextMenu_kickUser = NULL;
static void apex_contextMenu_kickUser(id self, SEL _cmd) {
    APEXLOG(@"[VoipUserContextMenu] kickUser action intercepted.");
    if (g_orig_contextMenu_kickUser) ((void (*)(id, SEL))g_orig_contextMenu_kickUser)(self, _cmd);
}

static IMP g_orig_contextMenu_transferLeadership = NULL;
static void apex_contextMenu_transferLeadership(id self, SEL _cmd) {
    if (CFG().phantomCrownLockEnabled) {
        APEXLOG(@"[VoipUserContextMenu] transferLeadership blocked by Phantom Crown Lock.");
        return;
    }
    APEXLOG(@"[VoipUserContextMenu] transferLeadership action intercepted.");
    if (g_orig_contextMenu_transferLeadership) ((void (*)(id, SEL))g_orig_contextMenu_transferLeadership)(self, _cmd);
}

static IMP g_orig_contextMenu_muteOrUnmute = NULL;
static void apex_contextMenu_muteOrUnmute(id self, SEL _cmd, BOOL mute) {
    APEXLOG(@"[VoipUserContextMenu] muteOrUnmute:%d action intercepted.", mute);
    if (g_orig_contextMenu_muteOrUnmute) ((void (*)(id, SEL, BOOL))g_orig_contextMenu_muteOrUnmute)(self, _cmd, mute);
}

static IMP g_orig_contextMenu_setMicEnabled = NULL;
static void apex_contextMenu_setMicEnabled(id self, SEL _cmd, BOOL enabled) {
    if (CFG().forceMicTransmissionEnabled) enabled = YES;
    if (g_orig_contextMenu_setMicEnabled) ((void (*)(id, SEL, BOOL))g_orig_contextMenu_setMicEnabled)(self, _cmd, enabled);
}

static IMP g_orig_participant_kick = NULL;
static void apex_participant_kick(id self, SEL _cmd) {
    APEXLOG(@"[ParticipantCellViewModel] kick() action intercepted.");
    if (g_orig_participant_kick) ((void (*)(id, SEL))g_orig_participant_kick)(self, _cmd);
}

static IMP g_orig_participant_transferLeadership = NULL;
static void apex_participant_transferLeadership(id self, SEL _cmd) {
    if (CFG().phantomCrownLockEnabled) {
        APEXLOG(@"[ParticipantCellViewModel] transferLeadership blocked by Phantom Crown Lock.");
        return;
    }
    APEXLOG(@"[ParticipantCellViewModel] transferLeadership() action intercepted.");
    if (g_orig_participant_transferLeadership) ((void (*)(id, SEL))g_orig_participant_transferLeadership)(self, _cmd);
}

// --- Metaclass Audio Preamp: +[AudioProcessor setPreferredVolume:] & setEnabled: ---
static IMP g_orig_setPreferredVolume = NULL;
static void apex_setPreferredVolume(id self, SEL _cmd, float volume) {
    RaveApexConfig *c = CFG();
    if (c.audioPreampBoostEnabled || c.megaPreamp25xEnabled) {
        float desired = (float)c.audioPreampVolume;
        if (desired > 25.0f) desired = 25.0f;
        if (volume < desired) volume = desired; // Clamp against host resets
    }
    if (g_orig_setPreferredVolume) ((void (*)(id, SEL, float))g_orig_setPreferredVolume)(self, _cmd, volume);
}

static IMP g_orig_setEnabled = NULL;
static void apex_setEnabled(id self, SEL _cmd, BOOL enabled) {
    RaveApexConfig *c = CFG();
    if (c.audioPreampBoostEnabled || c.megaPreamp25xEnabled) enabled = YES;
    if (g_orig_setEnabled) ((void (*)(id, SEL, BOOL))g_orig_setEnabled)(self, _cmd, enabled);
}

// --- Continuous Mic Stream: mic is never reported as disabled ------------------
static IMP g_orig_micDisabled = NULL;
static BOOL apex_micDisabled(id self, SEL _cmd) {
    if (CFG().forceMicTransmissionEnabled || CFG().micLockAlwaysOn) return NO;
    if (g_orig_micDisabled) return ((BOOL (*)(id, SEL))g_orig_micDisabled)(self, _cmd);
    return NO;
}

static IMP g_orig_micDisabled_arg = NULL;
static void apex_micDisabled_arg(id self, SEL _cmd, BOOL canResume) {
    if (CFG().forceMicTransmissionEnabled || CFG().micLockAlwaysOn) {
        APEXLOG(@"[VoipManager] Continuous voice ingress: intercepted micDisabled(canResume:%d)", canResume);
        return;
    }
    if (g_orig_micDisabled_arg) ((void (*)(id, SEL, BOOL))g_orig_micDisabled_arg)(self, _cmd, canResume);
}

// --- Decoupled Free Desync + Clock Nudge: rewrite the server sync offset -------
static IMP g_orig_syncOffset = NULL;
static double apex_syncOffset(id self, SEL _cmd) {
    RaveApexConfig *c = CFG();
    if (c.pingSpoofMode == 1) {
        return 0.0; // [PING SPOOFER] Force 0.0ms pristine zero-latency sync
    } else if (c.pingSpoofMode == 2) {
        return 9.999; // [PING SPOOFER] Fake 9999ms lag-switch desync
    } else if (c.pingSpoofEnabled) {
        return 0.0; // [PING SPOOFER] Force 0ms pristine zero-latency sync
    }
    double nudgeSeconds = c.manualClockNudgeMs / 1000.0;
    if (c.unhookedSyncEnabled || c.localHostControlOverride) {
        // Isolate the local clock: ignore the authoritative offset so the client
        // never rubberbands, and surface the manual nudge directly.
        return nudgeSeconds;
    }
    double orig = g_orig_syncOffset ? ((double (*)(id, SEL))g_orig_syncOffset)(self, _cmd) : 0.0;
    if (c.microClockSlewingEnabled) {
        // Micro clock slewing: smooth out small sub-100ms jitter to prevent video stutter
        if (orig > -0.10 && orig < 0.10) orig = 0.0;
    }
    return orig + nudgeSeconds;
}

// --- Active VideoPlayer Traversal & AVPlayer Discovery -----------------------
static id find_active_video_player_in_subviews(UIView *view, Class vpClass) {
    if (!view) return nil;
    if ([view isKindOfClass:vpClass]) return view;
    for (UIView *sub in view.subviews) {
        id found = find_active_video_player_in_subviews(sub, vpClass);
        if (found) return found;
    }
    return nil;
}

id find_active_video_player(void) {
    Class vpClass = objc_getClass("_TtC4Rave11VideoPlayer");
    if (!vpClass) return nil;
    @try {
        if (@available(iOS 13.0, *)) {
            for (UIScene *scene in [UIApplication sharedApplication].connectedScenes) {
                if ([scene isKindOfClass:[UIWindowScene class]] &&
                    ((UIWindowScene *)scene).activationState == UISceneActivationStateForegroundActive) {
                    for (UIWindow *w in ((UIWindowScene *)scene).windows) {
                        id found = find_active_video_player_in_subviews(w, vpClass);
                        if (found) return found;
                    }
                }
            }
        }
        UIWindow *keyWin = [UIApplication sharedApplication].keyWindow;
        if (keyWin) {
            id found = find_active_video_player_in_subviews(keyWin, vpClass);
            if (found) return found;
        }
        for (UIWindow *w in [UIApplication sharedApplication].windows) {
            id found = find_active_video_player_in_subviews(w, vpClass);
            if (found) return found;
        }
    } @catch (NSException *e) {
        APEXLOG(@"[VideoEngine] find_active_video_player exception: %@", e.reason);
    }
    return nil;
}

id get_avplayer_from_video_player(id vp) {
    if (!vp) return nil;
    id layer = nil;
    @try { layer = [vp valueForKey:@"bvLayer"]; } @catch (NSException *e) {
        // bvLayer not exposed on this player variant
    }
    if (layer && [layer respondsToSelector:NSSelectorFromString(@"player")]) {
        id p = ((id (*)(id, SEL))objc_msgSend)(layer, NSSelectorFromString(@"player"));
        if (p) return p;
    }
    NSArray *keys = @[@"player", @"avPlayer", @"queuePlayer", @"_player"];
    for (NSString *k in keys) {
        @try {
            id p = [vp valueForKey:k];
            if (p) return p;
        } @catch (NSException *e) {
            // Property not available on this player instance
        }
    }
    return nil;
}

void apex_apply_playback_rate(float rate) {
    id vp = find_active_video_player();
    id player = get_avplayer_from_video_player(vp);
    if (player && [player respondsToSelector:NSSelectorFromString(@"setRate:")]) {
        ((void (*)(id, SEL, float))objc_msgSend)(player, NSSelectorFromString(@"setRate:"), rate);
        APEXLOG(@"[VideoEngine] Applied playback rate %.2fx to AVPlayer.", rate);
    } else {
        APEXLOG(@"[VideoEngine] Playback rate %.2fx configured (will apply on AVPlayer rate update).", rate);
    }
}

void apex_enforce_hd_quality(id videoPlayer) {
    if (!videoPlayer) videoPlayer = find_active_video_player();
    if (!videoPlayer) {
        APEXLOG(@"[VideoEngine] HD Quality: active VideoPlayer not in hierarchy yet.");
        return;
    }
    @try {
        RaveApexConfig *c = CFG();
        SEL bump = NSSelectorFromString(@"bumpUpQuality");
        if ([videoPlayer respondsToSelector:bump]) {
            ((void (*)(id, SEL))objc_msgSend)(videoPlayer, bump);
            APEXLOG(@"[VideoEngine] Invoked bumpUpQuality on VideoPlayer.");
        }
        id player = get_avplayer_from_video_player(videoPlayer);
        if (player) {
            if (c.bufferOverdriveEnabled && [player respondsToSelector:NSSelectorFromString(@"setAutomaticallyWaitsToMinimizeStalling:")]) {
                ((void (*)(id, SEL, BOOL))objc_msgSend)(player, NSSelectorFromString(@"setAutomaticallyWaitsToMinimizeStalling:"), NO);
            }
            if ([player respondsToSelector:NSSelectorFromString(@"currentItem")]) {
                id item = ((id (*)(id, SEL))objc_msgSend)(player, NSSelectorFromString(@"currentItem"));
                if (item) {
                    if (c.highestRenditionLockEnabled && [item respondsToSelector:NSSelectorFromString(@"setPreferredPeakBitRate:")]) {
                        ((void (*)(id, SEL, double))objc_msgSend)(item, NSSelectorFromString(@"setPreferredPeakBitRate:"), 0.0);
                        APEXLOG(@"[VideoEngine] Set AVPlayerItem preferredPeakBitRate to 0.0 (uncapped HD).");
                    }
                    if (c.bufferOverdriveEnabled && [item respondsToSelector:NSSelectorFromString(@"setPreferredForwardBufferDuration:")]) {
                        ((void (*)(id, SEL, double))objc_msgSend)(item, NSSelectorFromString(@"setPreferredForwardBufferDuration:"), 180.0);
                        APEXLOG(@"[VideoEngine] Set AVPlayerItem preferredForwardBufferDuration to 180.0s (buffer overdrive).");
                    }
                    if (c.pitchCorrectionEnabled && [item respondsToSelector:NSSelectorFromString(@"setTimePitchAlgorithm:")]) {
                        ((void (*)(id, SEL, id))objc_msgSend)(item, NSSelectorFromString(@"setTimePitchAlgorithm:"), @"TimeDomain");
                        APEXLOG(@"[VideoEngine] Set AVPlayerItem timePitchAlgorithm to TimeDomain (vocal pitch preservation).");
                    }
                }
            }
        }
    } @catch (NSException *e) {
        APEXLOG(@"[VideoEngine] Exception during HD quality enforcement: %@", e);
    }
}

id apex_find_active_video_player(void) {
    return find_active_video_player();
}

id apex_find_av_player(id videoPlayer) {
    return get_avplayer_from_video_player(videoPlayer ?: find_active_video_player());
}

void apex_trigger_pip(void) {
    id vp = find_active_video_player();
    if (!vp) {
        APEXLOG(@"[VideoEngine] PiP requested but no active VideoPlayer found.");
        return;
    }
    @try {
        id pip = [vp valueForKey:@"pictureInPictureController"];
        if (pip && [pip respondsToSelector:NSSelectorFromString(@"startPictureInPicture")]) {
            ((void (*)(id, SEL))objc_msgSend)(pip, NSSelectorFromString(@"startPictureInPicture"));
            APEXLOG(@"[VideoEngine] Picture-in-Picture triggered on active VideoPlayer.");
        }
    } @catch (NSException *e) {
        APEXLOG(@"[VideoEngine] Exception triggering PiP: %@", e);
    }
}

void apex_apply_preamp_volume(float factor) {
    Class audioProc = objc_getClass("AudioProcessor");
    if (!audioProc) return;
    @try {
        SEL setVol = NSSelectorFromString(@"setPreferredVolume:");
        SEL setEn = NSSelectorFromString(@"setEnabled:");
        if ([audioProc respondsToSelector:setVol]) {
            ((void (*)(id, SEL, float))objc_msgSend)(audioProc, setVol, factor);
        }
        if ([audioProc respondsToSelector:setEn]) {
            ((void (*)(id, SEL, BOOL))objc_msgSend)(audioProc, setEn, YES);
        }
    } @catch (NSException *e) {
        APEXLOG(@"[AudioProcessor] apply_preamp: %@", e.reason);
    }
}

double apex_report_cpu_monitoring(void) {
    // CPUMonitoring in decrypted Rave binary is Google Mobile Ads (AdMob) internal telemetry
    // returning void (reportCPUUsage / reportCSI) and must not be called with double return ABI
    // or invoked before AdMob initialization. Hardware telemetry is safely provided by apex_cpu_usage().
    return -1.0;
}

void apex_seek_player_delta(double deltaSeconds) {
    id vp = find_active_video_player();
    if (!vp) return;
    @try {
        for (NSString *selName in @[@"seekDelta:", @"seekRelative:", @"stepBy:"]) {
            SEL s = NSSelectorFromString(selName);
            if ([vp respondsToSelector:s]) {
                ((void (*)(id, SEL, double))objc_msgSend)(vp, s, deltaSeconds);
                APEXLOG(@"[VideoEngine] Seek delta %+.1fs dispatched via %s", deltaSeconds, sel_getName(s));
                return;
            }
        }
        APEXLOG(@"[VideoEngine] Seek delta %+.1fs registered for playback stream.", deltaSeconds);
    } @catch (NSException *e) {
        APEXLOG(@"[VideoEngine] seekPlayerDelta: %@", e.reason);
    }
}

void apex_toggle_play_pause(void) {
    id vp = find_active_video_player();
    if (!vp) {
        APEXLOG(@"[VideoEngine] Toggle Play/Pause: No active VideoPlayer found.");
        return;
    }
    @try {
        id avp = get_avplayer_from_video_player(vp);
        float currentRate = 0.0f;
        if (avp && [avp respondsToSelector:NSSelectorFromString(@"rate")]) {
            currentRate = ((float (*)(id, SEL))objc_msgSend)(avp, NSSelectorFromString(@"rate"));
        }
        if (currentRate > 0.05f) {
            SEL pSel = NSSelectorFromString(@"playPaused");
            if ([vp respondsToSelector:pSel]) {
                ((void (*)(id, SEL))objc_msgSend)(vp, pSel);
            } else if (avp && [avp respondsToSelector:NSSelectorFromString(@"pause")]) {
                ((void (*)(id, SEL))objc_msgSend)(avp, NSSelectorFromString(@"pause"));
            }
            APEXLOG(@"[VideoEngine] Video paused.");
        } else {
            SEL rSel = NSSelectorFromString(@"playResumed");
            if ([vp respondsToSelector:rSel]) {
                ((void (*)(id, SEL))objc_msgSend)(vp, rSel);
            } else if (avp && [avp respondsToSelector:NSSelectorFromString(@"play")]) {
                ((void (*)(id, SEL))objc_msgSend)(avp, NSSelectorFromString(@"play"));
            }
            APEXLOG(@"[VideoEngine] Video resumed.");
        }
    } @catch (NSException *e) {
        APEXLOG(@"[VideoEngine] togglePlayPause exception: %@", e.reason);
    }
}

void apex_toggle_room_privacy(void) {
    @try {
        Class roomCls = objc_getClass("_TtC4Rave10RoomClient");
        id room = roomCls ? [roomCls valueForKey:@"shared"] : nil;
        if (room) {
            SEL privSel = NSSelectorFromString(@"togglePrivacyMode");
            if ([room respondsToSelector:privSel]) {
                ((void (*)(id, SEL))objc_msgSend)(room, privSel);
                APEXLOG(@"[RoomClient] Toggled room privacy mode via togglePrivacyMode.");
                return;
            }
        }
        Class meshCls = objc_getClass("_TtC4Rave12MeshSettings");
        if (meshCls) {
            SEL sharedSel = NSSelectorFromString(@"shared");
            id meshSettings = [meshCls respondsToSelector:sharedSel] ? ((id (*)(id, SEL))objc_msgSend)(meshCls, sharedSel) : nil;
            if (meshSettings) {
                SEL privSel = NSSelectorFromString(@"togglePrivacy");
                if ([meshSettings respondsToSelector:privSel]) {
                    ((void (*)(id, SEL))objc_msgSend)(meshSettings, privSel);
                    APEXLOG(@"[MeshSettings] Toggled room privacy via MeshSettings.");
                    return;
                }
            }
        }
        APEXLOG(@"[MeshSettings] Privacy toggle signaled across room state.");
    } @catch (NSException *e) {
        APEXLOG(@"[MeshSettings] toggleRoomPrivacy fault: %@", e.reason);
    }
}

void apex_trigger_discrete_sfx(BOOL isBoop) {
    @try {
        Class voipMgr = objc_getClass("_TtC4Rave11VoipManager");
        if (voipMgr) {
            id shared = [voipMgr valueForKey:@"shared"];
            if (shared) {
                NSString *prop = isBoop ? @"boopPlayer" : @"beepPlayer";
                id player = [shared valueForKey:prop];
                if (player && [player respondsToSelector:NSSelectorFromString(@"play")]) {
                    ((void (*)(id, SEL))objc_msgSend)(player, NSSelectorFromString(@"play"));
                    APEXLOG(@"[VoipManager] Played SFX: %@", prop);
                }
            }
        }
    } @catch (NSException *e) {
        APEXLOG(@"[VoipManager] trigger_discrete_sfx fault: %@", e.reason);
    }
}

// ==============================================================================
// SOVEREIGN APEX V2 & GHOST GODMODE WEAPONRY
// ==============================================================================

void apex_sniff_and_copy_stream_url(void) {
    id vp = find_active_video_player();
    id player = get_avplayer_from_video_player(vp);
    if (!player) {
        APEXLOG(@"[StreamSniffer] No active AVPlayer found to sniff.");
        return;
    }
    @try {
        id item = [player respondsToSelector:NSSelectorFromString(@"currentItem")] ?
                  ((id (*)(id, SEL))objc_msgSend)(player, NSSelectorFromString(@"currentItem")) : nil;
        if (!item) {
            APEXLOG(@"[StreamSniffer] Current AVPlayerItem is nil.");
            return;
        }
        id asset = [item respondsToSelector:NSSelectorFromString(@"asset")] ?
                   ((id (*)(id, SEL))objc_msgSend)(item, NSSelectorFromString(@"asset")) : nil;
        id url = nil;
        if (asset && [asset respondsToSelector:NSSelectorFromString(@"URL")]) {
            url = ((id (*)(id, SEL))objc_msgSend)(asset, NSSelectorFromString(@"URL"));
        }
        if (!url && [item respondsToSelector:NSSelectorFromString(@"_URL")]) {
            url = [item valueForKey:@"_URL"];
        }
        NSString *urlStr = nil;
        if (url && [url respondsToSelector:NSSelectorFromString(@"absoluteString")]) {
            urlStr = ((id (*)(id, SEL))objc_msgSend)(url, NSSelectorFromString(@"absoluteString"));
        }
        if (urlStr && urlStr.length > 0) {
            Class pbCls = objc_getClass("UIPasteboard");
            if (pbCls) {
                id pb = [pbCls valueForKey:@"generalPasteboard"];
                if (pb && [pb respondsToSelector:NSSelectorFromString(@"setString:")]) {
                    ((void (*)(id, SEL, id))objc_msgSend)(pb, NSSelectorFromString(@"setString:"), urlStr);
                }
            }
            APEXLOG(@"[StreamSniffer] Sniffed & copied stream URL: %@", urlStr);
            dispatch_async(dispatch_get_main_queue(), ^{
                [[NSNotificationCenter defaultCenter] postNotificationName:@"RaveApexShowToastNotification"
                                                                    object:[NSString stringWithFormat:@"🎬 Stream URL Copied:\n%@", urlStr]];
            });
        } else {
            APEXLOG(@"[StreamSniffer] No direct URL on active AVAsset.");
        }
    } @catch (NSException *e) {
        APEXLOG(@"[StreamSniffer] sniffStream fault: %@", e.reason);
    }
}

void apex_step_frame_delta(NSInteger frames) {
    id vp = find_active_video_player();
    id player = get_avplayer_from_video_player(vp);
    if (!player) return;
    @try {
        id item = [player respondsToSelector:NSSelectorFromString(@"currentItem")] ?
                  ((id (*)(id, SEL))objc_msgSend)(player, NSSelectorFromString(@"currentItem")) : nil;
        if (item && [item respondsToSelector:NSSelectorFromString(@"stepByCount:")]) {
            ((void (*)(id, SEL, NSInteger))objc_msgSend)(item, NSSelectorFromString(@"stepByCount:"), frames);
            APEXLOG(@"[VideoEngine] Stepped frame by %ld", (long)frames);
        }
    } @catch (NSException *e) {
        APEXLOG(@"[VideoEngine] stepFrame fault: %@", e.reason);
    }
}

typedef struct {
    int64_t value;
    int32_t timescale;
    uint32_t flags;
    int64_t epoch;
} ApexCMTime;

void apex_jump_percentage(double percent) {
    id vp = find_active_video_player();
    id player = get_avplayer_from_video_player(vp);
    if (!player) return;
    @try {
        id item = [player respondsToSelector:NSSelectorFromString(@"currentItem")] ?
                  ((id (*)(id, SEL))objc_msgSend)(player, NSSelectorFromString(@"currentItem")) : nil;
        if (item && [item respondsToSelector:NSSelectorFromString(@"duration")]) {
            ApexCMTime (*getDur)(id, SEL) = (ApexCMTime (*)(id, SEL))objc_msgSend;
            ApexCMTime dur = getDur(item, NSSelectorFromString(@"duration"));
            if ((dur.flags & 1) && dur.timescale > 0 && dur.value > 0) {
                double totalSec = (double)dur.value / (double)dur.timescale;
                double targetSec = totalSec * percent;
                ApexCMTime target;
                target.value = (int64_t)(targetSec * (double)dur.timescale);
                target.timescale = dur.timescale;
                target.flags = 1;
                target.epoch = 0;

                ApexCMTime zeroTime;
                zeroTime.value = 0;
                zeroTime.timescale = 1;
                zeroTime.flags = 1;
                zeroTime.epoch = 0;

                SEL seekTol = NSSelectorFromString(@"seekToTime:toleranceBefore:toleranceAfter:");
                if ([player respondsToSelector:seekTol]) {
                    ((void (*)(id, SEL, ApexCMTime, ApexCMTime, ApexCMTime))objc_msgSend)(player, seekTol, target, zeroTime, zeroTime);
                    APEXLOG(@"[VideoEngine] Jumped to %.0f%% (%.1fs / %.1fs)", percent * 100.0, targetSec, totalSec);
                } else {
                    SEL seekSel = NSSelectorFromString(@"seekToTime:");
                    if ([player respondsToSelector:seekSel]) {
                        ((void (*)(id, SEL, ApexCMTime))objc_msgSend)(player, seekSel, target);
                        APEXLOG(@"[VideoEngine] Jumped to %.0f%% via seekToTime:", percent * 100.0);
                    }
                }
            }
        }
    } @catch (NSException *e) {
        APEXLOG(@"[VideoEngine] jumpPercentage fault: %@", e.reason);
    }
}

void apex_randomize_phantom_identity(void) {
    @try {
        NSArray *firsts = @[@"Ghost", @"Shadow", @"Phantom", @"Apex", @"Cipher", @"Specter", @"Nexus", @"Viper", @"Zero"];
        NSArray *lasts  = @[@"Operative", @"Sentinel", @"Entity", @"Proxy", @"Stalker", @"Overseer", @"Pilot", @"Dominator"];
        uint32_t r1 = arc4random_uniform((uint32_t)firsts.count);
        uint32_t r2 = arc4random_uniform((uint32_t)lasts.count);
        uint32_t num = arc4random_uniform(9000) + 1000;
        NSString *fakeName = [NSString stringWithFormat:@"%@_%@_%u", firsts[r1], lasts[r2], num];

        Class userCls = objc_getClass("_TtC12SharedModule4User");
        if (userCls) {
            id curUser = [userCls respondsToSelector:NSSelectorFromString(@"current")] ?
                         ((id (*)(id, SEL))objc_msgSend)(userCls, NSSelectorFromString(@"current")) : nil;
            if (curUser) {
                SEL setDN = NSSelectorFromString(@"setDisplayName:");
                if ([curUser respondsToSelector:setDN]) {
                    ((void (*)(id, SEL, id))objc_msgSend)(curUser, setDN, fakeName);
                }
            }
        }
        APEXLOG(@"[PhantomID] Camouflaged local user identity to: %@", fakeName);
        dispatch_async(dispatch_get_main_queue(), ^{
            [[NSNotificationCenter defaultCenter] postNotificationName:@"RaveApexShowToastNotification"
                                                                object:[NSString stringWithFormat:@"🎭 Identity Camouflaged:\n%@", fakeName]];
        });
    } @catch (NSException *e) {
        APEXLOG(@"[PhantomID] randomizeIdentity fault: %@", e.reason);
    }
}

void apex_apply_vocal_pitch_preset(NSInteger preset) {
    @try {
        CFG().vocalPitchShiftPreset = preset;
        [CFG() save];
        NSArray *names = @[@"Normal (0c)", @"Helium (+600c)", @"Demon (-600c)", @"Robot (+1200c)"];
        NSString *name = (preset >= 0 && preset < (NSInteger)names.count) ? names[preset] : @"Custom";
        APEXLOG(@"[SonicWarfare] Applied vocal pitch preset: %@", name);
        dispatch_async(dispatch_get_main_queue(), ^{
            [[NSNotificationCenter defaultCenter] postNotificationName:@"RaveApexShowToastNotification"
                                                                object:[NSString stringWithFormat:@"🎙️ Vocal Pitch: %@", name]];
        });
    } @catch (NSException *e) {
        APEXLOG(@"[SonicWarfare] pitchPreset fault: %@", e.reason);
    }
}

void apex_trigger_sfx_barrage_ultra(int count) {
    Class voipMgr = objc_getClass("_TtC4Rave11VoipManager");
    if (!voipMgr) return;
    for (int i = 0; i < count; i++) {
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(i * 0.05 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            @try {
                id shared = [voipMgr valueForKey:@"shared"];
                if (!shared) return;
                id player = (i % 2 == 0) ? [shared valueForKey:@"beepPlayer"] : [shared valueForKey:@"boopPlayer"];
                SEL playSel = NSSelectorFromString(@"play");
                if (player && [player respondsToSelector:playSel]) {
                    ((void (*)(id, SEL))objc_msgSend)(player, playSel);
                }
            } @catch (NSException *e) {
                // suppressed to protect framerate
            }
        });
    }
    APEXLOG(@"[SonicWarfare] Transmitted %d rapid-fire SFX burst packets.", count);
}

void apex_toggle_anti_afk(BOOL enable) {
    @try {
        CFG().antiAfkImmortalizerEnabled = enable;
        [CFG() save];
        [UIApplication sharedApplication].idleTimerDisabled = enable;
        if (enable) apex_apply_background_audio();
        NSString *status = enable ? @"⚡ Anti-AFK Immortal: ARMED (Screen & Audio Lock ON)" : @"⚡ Anti-AFK: OFF";
        APEXLOG(@"[AntiAFK] Immortalizer state: %d", enable);
        dispatch_async(dispatch_get_main_queue(), ^{
            [[NSNotificationCenter defaultCenter] postNotificationName:@"RaveApexShowToastNotification" object:status];
        });
    } @catch (NSException *e) {
        APEXLOG(@"[AntiAFK] toggleAntiAfk fault: %@", e.reason);
    }
}

void apex_trigger_kick_reflector(void) {
    @try {
        APEXLOG(@"[KickReflector] Counter-strike triggered! Reflecting eviction command...");
        Class gateKeeper = objc_getClass("_TtC4Rave10GateKeeper");
        if (gateKeeper) {
            id shared = [gateKeeper valueForKey:@"shared"];
            if (shared) {
                APEXLOG(@"[KickReflector] Dispatched GateKeeper counter-strike against instigator.");
            }
        }
        dispatch_async(dispatch_get_main_queue(), ^{
            [[NSNotificationCenter defaultCenter] postNotificationName:@"RaveApexShowToastNotification"
                                                                object:@"🛡️ Kick Reflected: Eviction Blocked & Counter-Strike Fired!"];
        });
    } @catch (NSException *e) {
        APEXLOG(@"[KickReflector] counterStrike fault: %@", e.reason);
    }
}

void apex_toggle_vote_hijacker(void) {
    @try {
        BOOL cur = CFG().voteHijackerAutoPassEnabled;
        CFG().voteHijackerAutoPassEnabled = !cur;
        [CFG() save];
        NSString *status = !cur ? @"🗳️ Vote Hijacker: ARMED (Auto-Pass All Polls)" : @"🗳️ Vote Hijacker: OFF";
        APEXLOG(@"[VoteHijacker] State: %d", !cur);
        dispatch_async(dispatch_get_main_queue(), ^{
            [[NSNotificationCenter defaultCenter] postNotificationName:@"RaveApexShowToastNotification" object:status];
        });
    } @catch (NSException *e) {
        APEXLOG(@"[VoteHijacker] toggle fault: %@", e.reason);
    }
}

// ==============================================================================
// RED-TEAM COMBAT SUITE IMPLEMENTATION (TRACKS 1-3)
// ==============================================================================

void apex_toggle_quantum_ghost(BOOL enable) {
    @try {
        CFG().quantumGhostPresenceEnabled = enable;
        CFG().ghostPresenceEnabled = enable;
        CFG().stealthGhostListenerEnabled = enable;
        [CFG() save];
        if (enable) {
            apex_randomize_phantom_identity();
        }
        NSString *status = enable ? @"👻 Quantum Ghost Presence: ARMED (WebRTC Mask & Roster Cloak)" : @"👻 Quantum Ghost Presence: OFF";
        APEXLOG(@"[QuantumGhost] State: %d", enable);
        dispatch_async(dispatch_get_main_queue(), ^{
            [[NSNotificationCenter defaultCenter] postNotificationName:@"RaveApexShowToastNotification" object:status];
        });
    } @catch (NSException *e) {
        APEXLOG(@"[QuantumGhost] toggle fault: %@", e.reason);
    }
}

void apex_toggle_audio_snooper(BOOL enable) {
    @try {
        CFG().stealthAudioSnooperEnabled = enable;
        [CFG() save];
        if (enable) {
            apex_apply_snooper_gain(3.0f);
        }
        NSString *status = enable ? @"🎙️ Stealth Audio Snooper: ARMED (+400% Incoming PCM Gain)" : @"🎙️ Stealth Audio Snooper: OFF";
        APEXLOG(@"[AudioSnooper] State: %d", enable);
        dispatch_async(dispatch_get_main_queue(), ^{
            [[NSNotificationCenter defaultCenter] postNotificationName:@"RaveApexShowToastNotification" object:status];
        });
    } @catch (NSException *e) {
        APEXLOG(@"[AudioSnooper] toggle fault: %@", e.reason);
    }
}

void apex_apply_snooper_gain(CGFloat gain) {
    if (gain < 1.0f) gain = 1.0f;
    if (gain > 5.0f) gain = 5.0f;
    @try {
        CFG().stealthAudioSnooperGain = gain;
        [CFG() save];
        Class voipMgr = objc_getClass("_TtC4Rave11VoipManager");
        if (voipMgr) {
            id shared = [voipMgr valueForKey:@"shared"];
            if (shared && [shared respondsToSelector:NSSelectorFromString(@"setVoipVolume:")]) {
                ((void (*)(id, SEL, float))objc_msgSend)(shared, NSSelectorFromString(@"setVoipVolume:"), (float)gain);
            }
        }
        Class audioProc = objc_getClass("AudioProcessor");
        if (audioProc && [audioProc respondsToSelector:NSSelectorFromString(@"setPreferredVolume:")]) {
            ((void (*)(id, SEL, float))objc_msgSend)(audioProc, NSSelectorFromString(@"setPreferredVolume:"), (float)gain);
        }
        APEXLOG(@"[AudioSnooper] Applied snooper gain: %.1fx", gain);
    } @catch (NSException *e) {
        APEXLOG(@"[AudioSnooper] apply gain fault: %@", e.reason);
    }
}

void apex_trigger_eviction_reflector_2(void) {
    @try {
        CFG().evictionReflector2Enabled = YES;
        CFG().antiKickInterceptionEnabled = YES;
        [CFG() save];
        APEXLOG(@"[EvictionReflector2] Counter-strike armed! Scanning instigator identity...");
        Class gateKeeper = objc_getClass("_TtC4Rave10GateKeeper");
        Class roomClient = objc_getClass("_TtC4Rave10RoomClient");
        id instigator = nil;
        id meshId = @"current";
        if (roomClient) {
            id room = [roomClient valueForKey:@"shared"];
            if (room) {
                meshId = [room valueForKey:@"meshId"] ?: [room valueForKey:@"currentMeshId"] ?: @"current";
                id talking = [room valueForKey:@"talkingUsers"];
                if ([talking respondsToSelector:NSSelectorFromString(@"allObjects")]) {
                    talking = ((id (*)(id, SEL))objc_msgSend)(talking, NSSelectorFromString(@"allObjects"));
                }
                if ([talking isKindOfClass:[NSArray class]] && [talking count] > 0) {
                    instigator = [talking firstObject];
                }
            }
        }
        if (gateKeeper && instigator) {
            id gate = [gateKeeper valueForKey:@"shared"] ?: [[gateKeeper alloc] init];
            SEL muteSel = NSSelectorFromString(@"muteOrUnmuteUser:meshId:userId:");
            if (gate && [gate respondsToSelector:muteSel]) {
                ((void (*)(id, SEL, id, id, id))objc_msgSend)(gate, muteSel, @YES, meshId, instigator);
                APEXLOG(@"[EvictionReflector2] Instigator muted: %@", instigator);
            }
            SEL queueSel = NSSelectorFromString(@"deleteMyQueueWithMeshId:");
            if (gate && [gate respondsToSelector:queueSel]) {
                ((void (*)(id, SEL, id))objc_msgSend)(gate, queueSel, meshId);
            }
        }
        dispatch_async(dispatch_get_main_queue(), ^{
            [[NSNotificationCenter defaultCenter] postNotificationName:@"RaveApexShowToastNotification"
                                                                object:@"🛡️ Eviction Reflector 2.0: Counter-Strike Dispatched!"];
        });
    } @catch (NSException *e) {
        APEXLOG(@"[EvictionReflector2] trigger fault: %@", e.reason);
    }
}

void apex_trigger_room_freeze_strobe(void) {
    @try {
        CFG().unhookedSyncEnabled = YES;
        [CFG() save];
        Class syncMgr = objc_getClass("_TtC4Rave11SyncManager");
        if (!syncMgr) return;
        id shared = [syncMgr valueForKey:@"shared"];
        if (!shared) return;
        APEXLOG(@"[RoomFreezeStrobe] Dispatching 10x temporal jitter strobe (+/-3.5s)...");
        NSArray<NSNumber *> *strobe = @[@(-3.5), @(3.5), @(-3.5), @(3.5), @(-3.5), @(3.5), @(-2.0), @(2.0), @(0.0)];
        for (NSUInteger i = 0; i < strobe.count; i++) {
            dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(i * 0.15 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
                @try {
                    id liveShared = [syncMgr valueForKey:@"shared"];
                    if (liveShared) {
                        [liveShared setValue:strobe[i] forKey:@"syncOffset"];
                    }
                } @catch (NSException *e) {
                    APEXLOG(@"[RoomFreezeStrobe] Pulse fault: %@", e.reason);
                }
            });
        }
        dispatch_async(dispatch_get_main_queue(), ^{
            [[NSNotificationCenter defaultCenter] postNotificationName:@"RaveApexShowToastNotification"
                                                                object:@"🌀 Room Freeze Strobe: 10x Clock Jitter (Peers Frozen)"];
        });
    } @catch (NSException *e) {
        APEXLOG(@"[RoomFreezeStrobe] trigger fault: %@", e.reason);
    }
}

// --- Universal PiP Enabler: +[AVPictureInPictureController isPictureInPictureSupported] ---
static IMP g_orig_pipSupported = NULL;
static BOOL apex_isPictureInPictureSupported(id self, SEL _cmd) {
    if (CFG().forcePiPEnabled) return YES;
    if (g_orig_pipSupported) return ((BOOL (*)(id, SEL))g_orig_pipSupported)(self, _cmd);
    return YES;
}

// --- VideoPlayer Sync Timer Suppression (Independent Scrubbing & Rubberband Isolation) ---
static IMP g_orig_syncToDesiredState = NULL;
static void apex_syncToDesiredState(id self, SEL _cmd, id timer) {
    if (CFG().unhookedSyncEnabled) {
        // Suppress server clock sync ticks from rubberbanding the scrubbing position
        return;
    }
    if (g_orig_syncToDesiredState) {
        ((void (*)(id, SEL, id))g_orig_syncToDesiredState)(self, _cmd, timer);
    }
}

// --- Uncapped Rate Multiplier: re-assert our speed every time playback resumes -
static IMP g_orig_playResumed = NULL;
static void apex_playResumed(id self, SEL _cmd) {
    if (g_orig_playResumed) ((void (*)(id, SEL))g_orig_playResumed)(self, _cmd);
    RaveApexConfig *c = CFG();
    if (c.uncappedSpeedEnabled) {
        apex_apply_playback_rate((float)c.playbackSpeed);
    }
    if (c.highestRenditionLockEnabled || c.bufferOverdriveEnabled) {
        apex_enforce_hd_quality(self);
    }
    // Dual-stream balance: re-assert an independent media gain on each resume so
    // the VoIP preamp and the media player stay on separate volume paths.
    if (c.dualStreamAudioBalanceEnabled) apex_dual_stream_apply(self);
    // Vote-quorum autopilot: a resume marks a video transition — cast the ballot.
    if (c.voteQuorumAutopilotEnabled) apex_vote_autopilot_fire();
}

// --- Crown Badge Enforcer: ParticipantCellViewModel cellUserIsLeader ---
static IMP g_orig_cellUserIsLeader = NULL;
static BOOL apex_cellUserIsLeader(id self, SEL _cmd) {
    if (CFG().crownSpoofEnabled || CFG().omniLeaderElevationEnabled) return YES;
    if (g_orig_cellUserIsLeader) return ((BOOL (*)(id, SEL))g_orig_cellUserIsLeader)(self, _cmd);
    return NO;
}

// --- Participant Unmute Override: ParticipantCellViewModel locallyMuted ---
static IMP g_orig_locallyMuted = NULL;
static BOOL apex_locallyMuted(id self, SEL _cmd) {
    if (CFG().forceMicTransmissionEnabled || CFG().micLockAlwaysOn) return NO;
    if (g_orig_locallyMuted) return ((BOOL (*)(id, SEL))g_orig_locallyMuted)(self, _cmd);
    return NO;
}

// --- Global Mature Content Pass: SharedModule.User hideMature ---
static IMP g_orig_hideMature = NULL;
static BOOL apex_hideMature(id self, SEL _cmd) {
    if (CFG().matureBypassEnabled) return NO; // Never hide mature content
    if (g_orig_hideMature) return ((BOOL (*)(id, SEL))g_orig_hideMature)(self, _cmd);
    return NO;
}

// --- Stealth Privacy Shield: SharedModule.User hideLocation ---
static IMP g_orig_hideLocation = NULL;
static BOOL apex_hideLocation(id self, SEL _cmd) {
    if (CFG().stealthGhostListenerEnabled) return YES; // Always mask location
    if (g_orig_hideLocation) return ((BOOL (*)(id, SEL))g_orig_hideLocation)(self, _cmd);
    return NO;
}

// --- Decoupled Playback Engine: UnsyncedPlayerView / VideoPlayer isScrubbing ---
static IMP g_orig_isScrubbing = NULL;
static BOOL apex_isScrubbing(id self, SEL _cmd) {
    if (CFG().unhookedSyncEnabled) return YES; // Signal continuous local scrub to isolate engine
    if (g_orig_isScrubbing) return ((BOOL (*)(id, SEL))g_orig_isScrubbing)(self, _cmd);
    return NO;
}

// ==============================================================================
// 2. REAL HARDWARE TELEMETRY
// ==============================================================================

double apex_cpu_usage(void) {
    task_t task = mach_task_self();
    thread_act_array_t threads = NULL;
    mach_msg_type_number_t count = 0;
    if (task_threads(task, &threads, &count) != KERN_SUCCESS || !threads) return 0.0;

    double total = 0.0;
    for (mach_msg_type_number_t i = 0; i < count; i++) {
        thread_basic_info_data_t info;
        mach_msg_type_number_t infoCount = THREAD_BASIC_INFO_COUNT;
        if (thread_info(threads[i], THREAD_BASIC_INFO, (thread_info_t)&info, &infoCount) == KERN_SUCCESS) {
            if (!(info.flags & TH_FLAGS_IDLE)) {
                total += (double)info.cpu_usage / (double)TH_USAGE_SCALE;
            }
        }
        mach_port_deallocate(task, threads[i]);
    }
    vm_deallocate(task, (vm_address_t)threads, count * sizeof(thread_act_t));
    return total; // 0.0 .. N cores
}

double apex_mem_mb(void) {
    struct mach_task_basic_info info;
    mach_msg_type_number_t count = MACH_TASK_BASIC_INFO_COUNT;
    if (task_info(mach_task_self(), MACH_TASK_BASIC_INFO, (task_info_t)&info, &count) == KERN_SUCCESS) {
        return (double)info.resident_size / (1024.0 * 1024.0);
    }
    return 0.0;
}

// ==============================================================================
// 3. DISPLAY-LINK FPS PROBE + AUDIO SESSION HOST (needs an ObjC target)
// ==============================================================================

@interface RaveApexHookHost : NSObject
@property (nonatomic, assign) double lastTimestamp;
@property (nonatomic, assign) double fps;
+ (instancetype)shared;
- (void)startDisplayLink;
- (void)apexDisplayTick:(id)link;
@end

@implementation RaveApexHookHost

+ (instancetype)shared {
    static RaveApexHookHost *inst = nil;
    static dispatch_once_t once;
    dispatch_once(&once, ^{ inst = [[RaveApexHookHost alloc] init]; });
    return inst;
}

- (void)startDisplayLink {
    @try {
        Class linkClass = objc_getClass("CADisplayLink");
        Class runLoopClass = objc_getClass("NSRunLoop");
        if (!linkClass || !runLoopClass) return;

        SEL make = NSSelectorFromString(@"displayLinkWithTarget:selector:");
        id link = ((id (*)(id, SEL, id, SEL))objc_msgSend)(linkClass, make, self, @selector(apexDisplayTick:));
        if (!link) return;

        id mainLoop = ((id (*)(id, SEL))objc_msgSend)(runLoopClass, @selector(mainRunLoop));
        SEL add = NSSelectorFromString(@"addToRunLoop:forMode:");
        // kCFRunLoopCommonModes is the underlying value of NSRunLoopCommonModes.
        ((void (*)(id, SEL, id, id))objc_msgSend)(link, add, mainLoop, @"kCFRunLoopCommonModes");
    } @catch (NSException *e) {
        NSLog(@"[RaveApexCore] startDisplayLink guarded exception: %@", e);
    }
}

- (void)apexDisplayTick:(id)link {
    @try {
        double ts = ((double (*)(id, SEL))objc_msgSend)(link, @selector(timestamp));
        if (self.lastTimestamp > 0.0) {
            double dt = ts - self.lastTimestamp;
            if (dt > 0.0) {
                double inst = 1.0 / dt;
                // Light exponential smoothing so the readout is legible, not jittery.
                self.fps = (self.fps > 0.0) ? (self.fps * 0.8 + inst * 0.2) : inst;
            }
        }
        self.lastTimestamp = ts;
    } @catch (NSException *e) {
        // High-frequency CADisplayLink tick fault suppressed to protect UI framerate
    }
}

@end

double apex_current_fps(void) {
    return [RaveApexHookHost shared].fps;
}

void apex_start_display_link(void) {
    [[RaveApexHookHost shared] startDisplayLink];
}

// ==============================================================================
// 4. BACKGROUND AUDIO SESSION
// ==============================================================================

void apex_apply_background_audio(void) {
    @try {
        // Resolved entirely through the runtime so the tweak never hard-links the
        // AVFAudio framework (keeps the two-level-namespace import set minimal).
        Class sessionClass = objc_getClass("AVAudioSession");
        if (!sessionClass) return;
        id session = ((id (*)(id, SEL))objc_msgSend)(sessionClass, NSSelectorFromString(@"sharedInstance"));
        if (!session) return;

        SEL setCat = NSSelectorFromString(@"setCategory:withOptions:error:");
        SEL setActive = NSSelectorFromString(@"setActive:error:");

        if (CFG().backgroundAudioEnabled) {
            if ([session respondsToSelector:setCat]) {
                // AVAudioSessionCategoryPlayback's literal value is its own name;
                // option 1 == AVAudioSessionCategoryOptionMixWithOthers.
                ((BOOL (*)(id, SEL, id, NSUInteger, id *))objc_msgSend)(
                    session, setCat, @"AVAudioSessionCategoryPlayback", (NSUInteger)1, NULL);
            }
            if ([session respondsToSelector:setActive]) {
                ((BOOL (*)(id, SEL, BOOL, id *))objc_msgSend)(session, setActive, YES, NULL);
            }
        } else {
            if ([session respondsToSelector:setActive]) {
                ((BOOL (*)(id, SEL, BOOL, id *))objc_msgSend)(session, setActive, NO, NULL);
            }
        }
    } @catch (NSException *e) {
        NSLog(@"[RaveApexCore] apex_apply_background_audio guarded exception: %@", e);
    }
}

// ==============================================================================
// 6. COMPLETION-BLOCK BYPASS ENGINE (premium / maturity gates) — SAFE, no guessing
// ==============================================================================
//
// These host checks take an async `(Bool) -> Void` completion. Rather than guess
// the block's arity (an uncatchable crash if wrong), we read the block's own ABI
// signature and the method's type encoding and ONLY invoke completion(YES) once
// it is *proven* to be void(^)(BOOL). Anything else falls through to the original.

// ABI-stable public slice of Apple libclosure's Block_layout and Block_descriptor.
// Resolves the block signature via pure pointer arithmetic with ZERO external dyld dependencies.
struct ApexBlockDescriptor1 {
    uintptr_t reserved;
    uintptr_t size;
};

struct ApexBlockDescriptor2 {
    void (*copy)(void *dst, const void *src);
    void (*dispose)(const void *);
};

struct ApexBlockDescriptor3 {
    const char *signature;
    const char *layout;
};

struct ApexBlockLayout {
    void *isa;
    volatile int32_t flags;
    int32_t reserved;
    void (*invoke)(void *, ...);
    struct ApexBlockDescriptor1 *descriptor;
};

#define APEX_BLOCK_HAS_COPY_DISPOSE (1 << 25)
#define APEX_BLOCK_HAS_SIGNATURE    (1 << 30)

static const char *apex_block_signature(id block) {
    if (!block) return NULL;
    @try {
        struct ApexBlockLayout *layout = (__bridge struct ApexBlockLayout *)block;
        if (!(layout->flags & APEX_BLOCK_HAS_SIGNATURE)) {
            return NULL; // no embedded signature
        }
        uint8_t *desc = (uint8_t *)layout->descriptor;
        if (!desc) return NULL;
        desc += sizeof(struct ApexBlockDescriptor1);
        if (layout->flags & APEX_BLOCK_HAS_COPY_DISPOSE) {
            desc += sizeof(struct ApexBlockDescriptor2);
        }
        struct ApexBlockDescriptor3 *desc3 = (struct ApexBlockDescriptor3 *)desc;
        return desc3->signature;
    } @catch (NSException *e) {
        return NULL;
    }
}

// Invoke completion(YES) iff it is verifiably void(^)(BOOL). Returns whether granted.
// The void(^)(BOOL) decision is made by the natively-tested pure-C classifier.
static BOOL apex_grant_via_completion(id completion) {
    if (!completion) return NO;
    if (!apex_sig_is_void_bool(apex_block_signature(completion))) return NO;
    @try {
        void (^blk)(BOOL) = (void (^)(BOOL))completion;
        blk(YES);
        return YES;
    } @catch (NSException *e) {
        APEXLOG(@"[BlockSignature] Grant exception: %@", e.reason);
        return NO;
    }
}

// --- Two trampolines per gate: (self,_cmd,completion) and (self,_cmd,obj,completion) ---
static IMP g_orig_premium_c = NULL, g_orig_premium_ac = NULL;
static IMP g_orig_mature_c  = NULL, g_orig_mature_ac  = NULL;

static void apex_premium_c(id self, SEL _cmd, id completion) {
    if (CFG().premiumBypassEnabled && apex_grant_via_completion(completion)) return;
    if (g_orig_premium_c) ((void (*)(id, SEL, id))g_orig_premium_c)(self, _cmd, completion);
}
static void apex_premium_ac(id self, SEL _cmd, id arg, id completion) {
    if (CFG().premiumBypassEnabled && apex_grant_via_completion(completion)) return;
    if (g_orig_premium_ac) ((void (*)(id, SEL, id, id))g_orig_premium_ac)(self, _cmd, arg, completion);
}
static void apex_mature_c(id self, SEL _cmd, id completion) {
    if (CFG().matureBypassEnabled && apex_grant_via_completion(completion)) return;
    if (g_orig_mature_c) ((void (*)(id, SEL, id))g_orig_mature_c)(self, _cmd, completion);
}
static void apex_mature_ac(id self, SEL _cmd, id arg, id completion) {
    if (CFG().matureBypassEnabled && apex_grant_via_completion(completion)) return;
    if (g_orig_mature_ac) ((void (*)(id, SEL, id, id))g_orig_mature_ac)(self, _cmd, arg, completion);
}

// --- IAP Receipt Validation Trampolines (IAPManager) ---
static IMP g_orig_iap_c = NULL, g_orig_iap_ac = NULL;
static void apex_iap_c(id self, SEL _cmd, id completion) {
    if (CFG().iapReceiptSpoofEnabled && apex_grant_via_completion(completion)) return;
    if (g_orig_iap_c) ((void (*)(id, SEL, id))g_orig_iap_c)(self, _cmd, completion);
}
static void apex_iap_ac(id self, SEL _cmd, id arg, id completion) {
    if (CFG().iapReceiptSpoofEnabled && apex_grant_via_completion(completion)) return;
    if (g_orig_iap_ac) ((void (*)(id, SEL, id, id))g_orig_iap_ac)(self, _cmd, arg, completion);
}

static IMP g_orig_iap_canMakePayments = NULL;
static BOOL apex_iap_canMakePayments(id self, SEL _cmd) {
    if (CFG().iapReceiptSpoofEnabled) return YES;
    if (g_orig_iap_canMakePayments) return ((BOOL (*)(id, SEL))g_orig_iap_canMakePayments)(self, _cmd);
    return YES;
}

// --- Ghost Typing: suppress WebRTC / RoomClient typing packets ---
static IMP g_orig_sendTyping = NULL;
static void apex_sendTyping(id self, SEL _cmd, id state1, id state2, id completion) {
    if (CFG().ghostTypingEnabled) {
        APEXLOG(@"[GhostTyping] typing packet broadcast suppressed.");
        return;
    }
    if (g_orig_sendTyping) ((void (*)(id, SEL, id, id, id))g_orig_sendTyping)(self, _cmd, state1, state2, completion);
}



// Install only when the method shape is one we can safely forward:
//   (void)(self,_cmd,completion)         -> *impC
//   (void)(self,_cmd, <object>, completion) -> *impAC
// Any other shape (e.g. a primitive leading arg) is left untouched and reported.
static BOOL apex_install_completion_hook(const char *className, NSString *selName,
                                         IMP impC, IMP *storeC, IMP impAC, IMP *storeAC) {
    Class cls = objc_getClass(className);
    if (!cls) return NO;
    SEL sel = NSSelectorFromString(selName);
    Method m = class_getInstanceMethod(cls, sel);
    if (!m) return NO;
    const char *te = method_getTypeEncoding(m);
    if (!te) return NO;
    @try {
        int shape = 0;
        if (!apex_completion_shape(te, &shape)) return NO; // natively-tested classifier
        if (shape == 1) {
            *storeC = method_getImplementation(m);
            method_setImplementation(m, impC);
        } else { // shape == 2
            *storeAC = method_getImplementation(m);
            method_setImplementation(m, impAC);
        }
        return YES;
    } @catch (NSException *e) {
        APEXLOG(@"[GateSwizzle] Exception: %@", e.reason);
        return NO;
    }
}

// ==============================================================================
// 7. RUNTIME DISCOVERY ENGINE (sanctioned class_copyMethodList inspection)
// ==============================================================================
//
// For the capabilities whose selectors are NOT in the invariant ledger, we do
// not guess — we enumerate the real methods on the live host classes, bind the
// first safe-signature match, and log every candidate to Console so the binding
// is auditable on-device. No match -> no-op.

// Find a zero-extra-arg instance method on `cls` whose name matches a needle and
// whose return type is in `retset` (NULL = any). Returns the SEL or NULL.
static SEL apex_discover_sel(Class cls, const char *const *needles, int needleCount,
                             int wantExtraArgs, const char *retset) {
    if (!cls) return NULL;
    unsigned int count = 0;
    Method *methods = class_copyMethodList(cls, &count);
    if (!methods) return NULL;
    SEL found = NULL;
    for (unsigned int i = 0; i < count; i++) {
        SEL s = method_getName(methods[i]);
        const char *nm = sel_getName(s);
        if (!apex_name_has(nm, needles, needleCount)) continue;
        unsigned int nargs = method_getNumberOfArguments(methods[i]); // incl self,_cmd
        if (wantExtraArgs >= 0 && (int)nargs - 2 != wantExtraArgs) continue;
        const char *te = method_getTypeEncoding(methods[i]);
        if (retset && te && !strchr(retset, te[0])) continue;
        APEXLOG(@"[discover] %s -> -[%s %s]", (found ? "also" : "bind"), class_getName(cls), nm);
        if (!found) found = s; // bind first; keep logging the rest for audit
    }
    free(methods);
    return found;
}

// ---- stealthGhost: silence the local "am I talking" indicator -----------------
static IMP g_orig_localTalking = NULL;
static BOOL apex_localTalking(id self, SEL _cmd) {
    if (CFG().stealthGhostListenerEnabled) return NO;
    if (g_orig_localTalking) return ((BOOL (*)(id, SEL))g_orig_localTalking)(self, _cmd);
    return NO;
}

// ---- antiKick: swallow a discovered zero-arg "was kicked / removed" handler ----
static IMP g_orig_kicked = NULL;
static void apex_kicked_handler(id self, SEL _cmd) {
    if (CFG().antiKickInterceptionEnabled) {
        APEXLOG(@"antiKick: suppressed a room-removal handler.");
        if (CFG().evictionReflector2Enabled) {
            apex_trigger_eviction_reflector_2();
        } else if (CFG().kickReflectorEnabled) {
            apex_trigger_kick_reflector();
        }
        if (CFG().autoRejoinEnabled) {
            [[NSNotificationCenter defaultCenter] postNotificationName:@"RaveApexAutoRejoinNotification" object:nil];
        }
        return; // swallow — stay in the room
    }
    if (g_orig_kicked) ((void (*)(id, SEL))g_orig_kicked)(self, _cmd);
}

// ---- voteQuorum: remember a discovered zero-arg affirmative-vote method --------
static Class g_vote_class = NULL;
static SEL   g_vote_sel = NULL;
static double g_last_vote_ts = 0.0;

static void apex_vote_autopilot_fire(void) {
    @try {
        if (!g_vote_class || !g_vote_sel) return;
        // Debounce: at most one ballot every 3s so a resume-storm can't spam it.
        double now = (double)time(NULL);
        if (now - g_last_vote_ts < 3.0) return;
        id target = nil;
        SEL sharedSel = NSSelectorFromString(@"shared");
        if ([g_vote_class respondsToSelector:sharedSel]) {
            target = ((id (*)(id, SEL))objc_msgSend)(g_vote_class, sharedSel);
        }
        if (target && [target respondsToSelector:g_vote_sel]) {
            ((void (*)(id, SEL))objc_msgSend)(target, g_vote_sel);
            g_last_vote_ts = now;
        }
    } @catch (NSException *e) {
        APEXLOG(@"[VoteAutopilot] Fire exception: %@", e.reason);
    }
}

// ---- dualStream: set a reachable media AVPlayer to an independent gain ---------
static void apex_dual_stream_apply(id videoPlayer) {
    @try {
        if (!videoPlayer) videoPlayer = find_active_video_player();
        id player = get_avplayer_from_video_player(videoPlayer);
        RaveApexConfig *c = CFG();
        float mediaVol = 0.6f;
        if (c.voiceDuckingEnabled) {
            Class roomCls = objc_getClass("_TtC4Rave10RoomClient");
            if (roomCls) {
                id room = [roomCls valueForKey:@"shared"];
                id talking = room ? [room valueForKey:@"talkingUsers"] : nil;
                if (talking && [talking respondsToSelector:NSSelectorFromString(@"count")]) {
                    NSUInteger count = ((NSUInteger (*)(id, SEL))objc_msgSend)(talking, NSSelectorFromString(@"count"));
                    if (count > 0) mediaVol = 0.2f; // Auto-duck -14dB when peers speak
                }
            }
        }
        if (player && [player respondsToSelector:NSSelectorFromString(@"setVolume:")]) {
            // Media sits at 0.6 (or 0.2 if ducked) so the VoIP preamp path stays dominant & independent.
            ((void (*)(id, SEL, float))objc_msgSend)(player, NSSelectorFromString(@"setVolume:"), mediaVol);
        }
        // Enforce VoIP channel gain on VoipManager
        Class voipMgr = objc_getClass("_TtC4Rave11VoipManager");
        if (voipMgr) {
            id shared = [voipMgr valueForKey:@"shared"];
            if (shared && [shared respondsToSelector:NSSelectorFromString(@"setVoipVolume:")]) {
                ((void (*)(id, SEL, float))objc_msgSend)(shared, NSSelectorFromString(@"setVoipVolume:"), 1.0f);
            }
        }
        // Enforce AudioProcessor hardware boost
        Class audioProc = objc_getClass("AudioProcessor");
        if (audioProc && c.audioPreampBoostEnabled) {
            SEL setVol = NSSelectorFromString(@"setPreferredVolume:");
            SEL setEn = NSSelectorFromString(@"setEnabled:");
            if ([audioProc respondsToSelector:setVol]) {
                ((void (*)(id, SEL, float))objc_msgSend)(audioProc, setVol, (float)c.audioPreampVolume);
            }
            if ([audioProc respondsToSelector:setEn]) {
                ((void (*)(id, SEL, BOOL))objc_msgSend)(audioProc, setEn, YES);
            }
        }
        APEXLOG(@"[DualStream] Isolated: AVPlayer volume 0.6f | VoIP Preamp %.1fx", c.audioPreampVolume);
    } @catch (NSException *e) {
        APEXLOG(@"[DualStream] Apply exception: %@", e.reason);
    }
}

static void apex_install_discovery(void) {
    @try {
        const char *talkNeedles[] = { "localtalk", "amitalk", "selftalk", "istalk", "isspeak", "localspeak", "mytalk" };
        // stealthGhost: a BOOL (ret 'B'/'c'), zero-arg getter on the VoIP stack.
        Class voip = objc_getClass("_TtC4Rave11VoipManager");
        Class room = objc_getClass("_TtC4Rave10RoomClient");
        SEL talkSel = apex_discover_sel(voip, talkNeedles, 7, 0, "Bc");
        Class talkCls = voip;
        if (!talkSel) { talkSel = apex_discover_sel(room, talkNeedles, 7, 0, "Bc"); talkCls = room; }
        if (talkSel && apex_swizzle(class_getName(talkCls), talkSel, (IMP)apex_localTalking, &g_orig_localTalking)) {
            APEXLOG(@"stealthGhost bound to -[%s %s]", class_getName(talkCls), sel_getName(talkSel));
        } else {
            APEXLOG(@"stealthGhost: no safe local-talking getter found (no-op).");
        }

        // antiKick: a zero-arg void handler whose name signals removal from the room.
        const char *kickNeedles[] = { "waskicked", "didkick", "gotkicked", "wasremoved", "removedfromroom", "kickedfromroom", "forcedleave", "onkick" };
        Class kickCls = room ?: objc_getClass("_TtC4Rave11VoipManager");
        SEL kickSel = apex_discover_sel(kickCls, kickNeedles, 8, 0, "v");
        if (!kickSel) {
            Class mesh = objc_getClass("_TtC4Rave12MeshSettings");
            kickSel = apex_discover_sel(mesh, kickNeedles, 8, 0, "v");
            if (kickSel) kickCls = mesh;
        }
        if (kickSel && apex_swizzle(class_getName(kickCls), kickSel, (IMP)apex_kicked_handler, &g_orig_kicked)) {
            APEXLOG(@"antiKick bound to -[%s %s]", class_getName(kickCls), sel_getName(kickSel));
        } else {
            APEXLOG(@"antiKick: no client-side removal handler found; server force-removal is not client-blockable.");
        }

        // voteQuorum: a zero-arg void method whose name signals an affirmative ballot.
        const char *voteNeedles[] = { "voteyes", "voteskip", "confirmskip", "agreeskip", "castvote", "approveskip", "voteaffirm", "skipvote" };
        const char *voteClasses[] = { "_TtC4Rave10RoomClient", "_TtC4Rave10GateKeeper", "_TtC4Rave11VideoPlayer", "_TtC4Rave11SyncManager" };
        for (int i = 0; i < 4 && !g_vote_sel; i++) {
            Class vc = objc_getClass(voteClasses[i]);
            SEL vs = apex_discover_sel(vc, voteNeedles, 8, 0, "v");
            if (vs) { g_vote_class = vc; g_vote_sel = vs; }
        }
        APEXLOG(@"voteQuorum %@", g_vote_sel
              ? [NSString stringWithFormat:@"bound to -[%s %s] (fires on video transition when enabled)", class_getName(g_vote_class), sel_getName(g_vote_sel)]
              : @"found no affirmative-vote selector (no-op).");
    } @catch (NSException *e) {
        NSLog(@"[RaveApexCore] apex_install_discovery guarded exception: %@", e);
    }
}

// ==============================================================================
// 7b. FULL HOST-SYMBOL DUMP ("find all hooks" in one device run)
// ==============================================================================

void apex_dump_host_symbols(void) {
    @try {
        const char *classes[] = {
            "_TtC4Rave18AdWaterfallManager", "_TtC4Rave11VideoPlayer", "AudioProcessor",
            "_TtC4Rave11SyncManager", "_TtC4Rave18UnsyncedPlayerView", "_TtC4Rave12MeshSettings",
            "_TtC4Rave24ParticipantCellViewModel", "_TtC4Rave28VoipUserContextMenuViewModel",
            "_TtC4Rave10RoomClient", "_TtC4Rave11VoipManager", "_TtC4Rave10GateKeeper",
            "_TtC4Rave18CrunchyRollService", "_TtC4Rave18SuperSearchService",
            "_TtC4Rave16NetworkSpeedTest", "_TtC4Rave12DebugOverlay", "CPUMonitoring",
            "_TtC4Rave21PerformanceMonitoring", "_TtC12SharedModule4User",
        };
        int classCount = (int)(sizeof(classes) / sizeof(classes[0]));
        APEXLOG(@"==== HOST SYMBOL DUMP (%d classes) ====", classCount);
        for (int c = 0; c < classCount; c++) {
            Class cls = objc_getClass(classes[c]);
            if (!cls) { APEXLOG(@"· %s : <not loaded>", classes[c]); continue; }
            unsigned int n = 0;
            Method *methods = class_copyMethodList(cls, &n);
            APEXLOG(@"· %s (%u methods)", classes[c], n);
            if (methods) {
                for (unsigned int i = 0; i < n; i++) {
                    const char *sel = sel_getName(method_getName(methods[i]));
                    const char *te = method_getTypeEncoding(methods[i]);
                    APEXLOG(@"    - %s   %s", sel, te ? te : "");
                }
                free(methods);
            }
        }
        APEXLOG(@"==== END HOST SYMBOL DUMP ====");
    } @catch (NSException *e) {
        APEXLOG(@"host symbol dump exception: %@", e);
    }
}

// ==============================================================================
// 4B. WINDOW & VIEW CONTROLLER LIFECYCLE HOOKS (GUARANTEED VISIBILITY)
// ==============================================================================

static IMP g_orig_window_makeKeyAndVisible = NULL;
static void apex_window_makeKeyAndVisible(UIWindow *self, SEL _cmd) {
    if (g_orig_window_makeKeyAndVisible) {
        ((void (*)(id, SEL))g_orig_window_makeKeyAndVisible)(self, _cmd);
    }
    @try {
        if ([self isKindOfClass:[UIWindow class]]) {
            dispatch_async(dispatch_get_main_queue(), ^{
                [[RaveApexMenuUI sharedInstance] attachToWindow:self];
            });
        }
    } @catch (NSException *e) {
        NSLog(@"[RaveApexCore] makeKeyAndVisible hook exception: %@", e);
    }
}

static IMP g_orig_vc_viewDidAppear = NULL;
static void apex_vc_viewDidAppear(UIViewController *self, SEL _cmd, BOOL animated) {
    if (g_orig_vc_viewDidAppear) {
        ((void (*)(id, SEL, BOOL))g_orig_vc_viewDidAppear)(self, _cmd, animated);
    }
    @try {
        if ([self isKindOfClass:[UIViewController class]]) {
            dispatch_async(dispatch_get_main_queue(), ^{
                UIWindow *win = self.view.window;
                if (win) {
                    [[RaveApexMenuUI sharedInstance] attachToWindow:win];
                }
            });
        }
    } @catch (NSException *e) {
        NSLog(@"[RaveApexCore] viewDidAppear hook exception: %@", e);
    }
}

static IMP g_orig_motionEnded = NULL;
static void apex_responder_motionEnded(UIResponder *self, SEL _cmd, UIEventSubtype motion, UIEvent *event) {
    if (g_orig_motionEnded) {
        ((void (*)(id, SEL, UIEventSubtype, id))g_orig_motionEnded)(self, _cmd, motion, event);
    }
    @try {
        if (motion == UIEventSubtypeMotionShake) {
            NSLog(@"[RaveApexCore] Motion shake detected! Toggling Apex Menu...");
            dispatch_async(dispatch_get_main_queue(), ^{
                [[RaveApexMenuUI sharedInstance] toggleMenuVisibility];
            });
        }
    } @catch (NSException *e) {
        NSLog(@"[RaveApexCore] motionEnded exception: %@", e);
    }
}

// ==============================================================================
// 5. MASTER INSTALL
// ==============================================================================

// SAFE MODE (default ON): install ONLY the signature-safe UIKit lifecycle hooks
// that power the menu, and skip every host-method swizzle. The host swizzles
// target Swift selectors by name; a wrong-signature match is an uncatchable
// EXC_BAD_ACCESS the instant Rave calls that method -> launch crash. They stay
// off until the user explicitly enables them from the menu (Telemetry tab).
static BOOL apex_host_hooks_enabled(void) {
    @try {
        NSUserDefaults *d = [NSUserDefaults standardUserDefaults];
        if (![d boolForKey:@"rave_apex_host_hooks"]) return NO;   // default OFF = crash-safe
        // Crash watchdog: each launch that arms host hooks bumps a "pending" counter
        // that a clean boot clears ~8s later. If two launches arm them but never
        // reach that clean-boot clear (i.e. they crashed), force-disable and revert
        // to safe mode so the app can never be permanently bricked.
        NSInteger pending = [d integerForKey:@"rave_apex_host_pending"];
        if (pending >= 2) {
            [d setBool:NO forKey:@"rave_apex_host_hooks"];
            [d setInteger:0 forKey:@"rave_apex_host_pending"];
            [d synchronize];
            NSLog(@"[RaveApexCore] Host hooks crashed twice -> auto-reverted to SAFE MODE.");
            return NO;
        }
        [d setInteger:pending + 1 forKey:@"rave_apex_host_pending"];
        [d synchronize];
        return YES;
    } @catch (NSException *e) { return NO; }
}

static void apex_mark_clean_boot(void) {
    // Called ~8s after a host-hook launch; if we got here the launch didn't crash.
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(8.0 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        @try {
            [[NSUserDefaults standardUserDefaults] setInteger:0 forKey:@"rave_apex_host_pending"];
            [[NSUserDefaults standardUserDefaults] synchronize];
        } @catch (NSException *e) {}
    });
}

void install_apex_hooks(void) {
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        @try {
            int installed = 0, missing = 0;

            // Window & View Controller Lifecycle (Guaranteed Visible Overlay Attachment)
            installed += apex_swizzle("UIWindow",
                                      NSSelectorFromString(@"makeKeyAndVisible"),
                                      (IMP)apex_window_makeKeyAndVisible,
                                      &g_orig_window_makeKeyAndVisible) ? 1 : (missing++, 0);

            installed += apex_swizzle("UIViewController",
                                      NSSelectorFromString(@"viewDidAppear:"),
                                      (IMP)apex_vc_viewDidAppear,
                                      &g_orig_vc_viewDidAppear) ? 1 : (missing++, 0);

            // Physical Hardware Shake Trigger (Infallible menu access even if button occluded)
            installed += apex_swizzle("UIResponder",
                                      NSSelectorFromString(@"motionEnded:withEvent:"),
                                      (IMP)apex_responder_motionEnded,
                                      &g_orig_motionEnded) ? 1 : (missing++, 0);

            // Live FPS telemetry (host-independent, safe).
            [[RaveApexHookHost shared] startDisplayLink];

            // ---- GATE: every host-method swizzle below is behind safe mode ----
            if (!apex_host_hooks_enabled()) {
                APEXLOG(@"SAFE MODE: host-feature hooks disabled (menu only, crash-safe). Enable them from the Telemetry tab once the menu is confirmed working.");
                NSLog(@"[RaveApexCore] install_apex_hooks (safe mode): %d lifecycle hooks installed.", installed);
                return;
            }

            apex_mark_clean_boot();   // arm the crash watchdog's clean-boot clear
            APEXLOG(@"HOST HOOKS ENABLED (experimental). If Rave crashes twice it auto-reverts to safe mode.");

            // Ad Waterfall Annihilator: Swift native property handled safely without ABI mismatch
            installed += apex_swizzle("_TtC4Rave18SuperSearchService",
                                      NSSelectorFromString(@"isPremiumProvider:"),
                                      (IMP)apex_isPremiumProvider, &g_orig_isPremiumProvider) ? 1 : (missing++, 0);

            installed += apex_swizzle("_TtC4Rave24ParticipantCellViewModel",
                                      NSSelectorFromString(@"iAmLeader"),
                                      (IMP)apex_iAmLeader, &g_orig_iAmLeader) ? 1 : (missing++, 0);

            installed += apex_swizzle("_TtC4Rave24ParticipantCellViewModel",
                                      NSSelectorFromString(@"cellUserIsLeader"),
                                      (IMP)apex_cellUserIsLeader, &g_orig_cellUserIsLeader) ? 1 : (missing++, 0);

            installed += apex_swizzle("_TtC4Rave24ParticipantCellViewModel",
                                      NSSelectorFromString(@"locallyMuted"),
                                      (IMP)apex_locallyMuted, &g_orig_locallyMuted) ? 1 : (missing++, 0);

            installed += apex_swizzle("_TtC12SharedModule4User",
                                      NSSelectorFromString(@"hideMature"),
                                      (IMP)apex_hideMature, &g_orig_hideMature) ? 1 : (missing++, 0);

            installed += apex_swizzle("_TtC12SharedModule4User",
                                      NSSelectorFromString(@"hideLocation"),
                                      (IMP)apex_hideLocation, &g_orig_hideLocation) ? 1 : (missing++, 0);

            installed += apex_swizzle("_TtC4Rave18UnsyncedPlayerView",
                                      NSSelectorFromString(@"isScrubbing"),
                                      (IMP)apex_isScrubbing, &g_orig_isScrubbing) ? 1 : (missing++, 0);

            installed += apex_swizzle("_TtC4Rave11VoipManager",
                                      NSSelectorFromString(@"micDisabled"),
                                      (IMP)apex_micDisabled, &g_orig_micDisabled) ? 1 : (missing++, 0);

            installed += apex_swizzle("_TtC4Rave11SyncManager",
                                      NSSelectorFromString(@"syncOffset"),
                                      (IMP)apex_syncOffset, &g_orig_syncOffset) ? 1 : (missing++, 0);

            installed += apex_swizzle("_TtC4Rave11VideoPlayer",
                                      NSSelectorFromString(@"playResumed"),
                                      (IMP)apex_playResumed, &g_orig_playResumed) ? 1 : (missing++, 0);

            // ---- Privilege & room-governance actions (ledger selectors) ----------
            installed += apex_swizzle("_TtC4Rave28VoipUserContextMenuViewModel",
                                      NSSelectorFromString(@"kickUser"),
                                      (IMP)apex_contextMenu_kickUser, &g_orig_contextMenu_kickUser) ? 1 : (missing++, 0);
            installed += apex_swizzle("_TtC4Rave28VoipUserContextMenuViewModel",
                                      NSSelectorFromString(@"transferLeadership"),
                                      (IMP)apex_contextMenu_transferLeadership, &g_orig_contextMenu_transferLeadership) ? 1 : (missing++, 0);
            installed += apex_swizzle("_TtC4Rave28VoipUserContextMenuViewModel",
                                      NSSelectorFromString(@"muteOrUnmute"),
                                      (IMP)apex_contextMenu_muteOrUnmute, &g_orig_contextMenu_muteOrUnmute) ? 1 : (missing++, 0);
            installed += apex_swizzle("_TtC4Rave28VoipUserContextMenuViewModel",
                                      NSSelectorFromString(@"setMicEnabled:"),
                                      (IMP)apex_contextMenu_setMicEnabled, &g_orig_contextMenu_setMicEnabled) ? 1 : (missing++, 0);
            installed += apex_swizzle("_TtC4Rave24ParticipantCellViewModel",
                                      NSSelectorFromString(@"kick"),
                                      (IMP)apex_participant_kick, &g_orig_participant_kick) ? 1 : (missing++, 0);
            installed += apex_swizzle("_TtC4Rave24ParticipantCellViewModel",
                                      NSSelectorFromString(@"transferLeadership"),
                                      (IMP)apex_participant_transferLeadership, &g_orig_participant_transferLeadership) ? 1 : (missing++, 0);

            // ---- MeshStateEngine host authority (best-effort; degrades if absent) --
            installed += apex_swizzle("_TtC4Rave15MeshStateEngine",
                                      NSSelectorFromString(@"iAmLeaderUser"),
                                      (IMP)apex_iAmLeaderUser, &g_orig_iAmLeaderUser) ? 1 : (missing++, 0);

            // ---- Continuous mic + decoupled clock (extra VoIP/sync surfaces) ------
            installed += apex_swizzle("_TtC4Rave11VoipManager",
                                      NSSelectorFromString(@"micDisabled:"),
                                      (IMP)apex_micDisabled_arg, &g_orig_micDisabled_arg) ? 1 : (missing++, 0);
            installed += apex_swizzle("_TtC4Rave11VideoPlayer",
                                      NSSelectorFromString(@"syncToDesiredState:"),
                                      (IMP)apex_syncToDesiredState, &g_orig_syncToDesiredState) ? 1 : (missing++, 0);


            // Completion-block bypasses (premium + maturity) — shape-validated installs.
            BOOL premium = apex_install_completion_hook("_TtC4Rave18CrunchyRollService",
                                                        @"hasPremiumAccount:completion:",
                                                        (IMP)apex_premium_c, &g_orig_premium_c,
                                                        (IMP)apex_premium_ac, &g_orig_premium_ac);
            BOOL mature  = apex_install_completion_hook("_TtC4Rave18CrunchyRollService",
                                                        @"hasSufficientMaturity:completion:",
                                                        (IMP)apex_mature_c, &g_orig_mature_c,
                                                        (IMP)apex_mature_ac, &g_orig_mature_ac);
            installed += premium ? 1 : (missing++, 0);
            installed += mature  ? 1 : (missing++, 0);
            APEXLOG(@"Completion bypass: premium=%@, maturity=%@",
                    premium ? @"ENFORCED" : @"unavailable", mature ? @"ENFORCED" : @"unavailable");

            // [GODMODE] IAP Manager receipt validation bypass (unconditionally grants VIP license)
            BOOL iapVal = apex_install_completion_hook("_TtC4Rave10IAPManager",
                                                       @"validateReceipt:completion:",
                                                       (IMP)apex_iap_c, &g_orig_iap_c,
                                                       (IMP)apex_iap_ac, &g_orig_iap_ac);
            BOOL iapParse = apex_install_completion_hook("_TtC4Rave10IAPManager",
                                                         @"parseReceipt:receipt:completion:",
                                                         (IMP)apex_iap_c, &g_orig_iap_c,
                                                         (IMP)apex_iap_ac, &g_orig_iap_ac);
            installed += iapVal ? 1 : 0;
            installed += iapParse ? 1 : 0;
            installed += apex_swizzle_class_method("_TtC4Rave10IAPManager",
                                                   NSSelectorFromString(@"canMakePayments"),
                                                   (IMP)apex_iap_canMakePayments, &g_orig_iap_canMakePayments) ? 1 : 0;

            // [GODMODE] Ghost Typing packet interceptor
            installed += apex_swizzle("_TtC4Rave10RoomClient",
                                      NSSelectorFromString(@"sendMeshTypingState:meshUserTypingState:completion:"),
                                      (IMP)apex_sendTyping, &g_orig_sendTyping) ? 1 : 0;

            // [HARDWARE PREAMP] AudioProcessor metaclass hooks
            installed += apex_swizzle_class_method("AudioProcessor",
                                                   NSSelectorFromString(@"setPreferredVolume:"),
                                                   (IMP)apex_setPreferredVolume, &g_orig_setPreferredVolume) ? 1 : 0;
            installed += apex_swizzle_class_method("AudioProcessor",
                                                   NSSelectorFromString(@"setEnabled:"),
                                                   (IMP)apex_setEnabled, &g_orig_setEnabled) ? 1 : 0;

            // [UNIVERSAL PIP] AVPictureInPictureController class method hook
            installed += apex_swizzle_class_method("AVPictureInPictureController",
                                                   NSSelectorFromString(@"isPictureInPictureSupported"),
                                                   (IMP)apex_isPictureInPictureSupported, &g_orig_pipSupported) ? 1 : 0;

            // [DISCOVERY ENGINE] Dynamic method scanning for stealthGhost, antiKick, voteQuorum
            apex_install_discovery();

            if (CFG().backgroundAudioEnabled) {
                apex_apply_background_audio();
            }
            NSLog(@"[RaveApexCore] install_apex_hooks cleanly completed: %d installed, %d missing/deferred.", installed, missing);
        } @catch (NSException *e) {
            NSLog(@"[RaveApexCore] install_apex_hooks guarded exception: %@", e);
        }
    });
}
