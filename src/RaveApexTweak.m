#import "RaveApexTweak.h"
#import "RaveApexMenuUI.h"
#import "RaveApexHooks.h"

// ==============================================================================
// 1. CONFIGURATION PERSISTENCE (25-CAPABILITY LEDGER)
// ==============================================================================

@implementation RaveApexConfig

@synthesize customButtonEmoji = _customButtonEmoji;
@synthesize lastKnownMeshId = _lastKnownMeshId;

- (NSString *)customButtonEmoji {
    @synchronized (self) {
        return _customButtonEmoji;
    }
}

- (void)setCustomButtonEmoji:(NSString *)val {
    @synchronized (self) {
        _customButtonEmoji = val;
    }
}

- (NSString *)lastKnownMeshId {
    @synchronized (self) {
        return _lastKnownMeshId;
    }
}

- (void)setLastKnownMeshId:(NSString *)val {
    @synchronized (self) {
        _lastKnownMeshId = val;
    }
}

+ (instancetype)sharedConfig {
    static RaveApexConfig *config = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        config = [[RaveApexConfig alloc] init];
        [config load];
    });
    return config;
}

- (instancetype)init {
    self = [super init];
    if (self) {
        [self resetToDefaults];
    }
    return self;
}

- (void)resetToDefaults {
    @synchronized (self) {
        // Group 1: Roles & Governance
        self.crownSpoofEnabled = NO;
        self.localHostControlOverride = YES;
        self.antiKickInterceptionEnabled = YES;
        self.voteQuorumAutopilotEnabled = NO;
        self.unhookedSyncEnabled = NO;
        self.omniLeaderElevationEnabled = YES;
        self.ghostPresenceEnabled = NO;
        self.phantomCrownLockEnabled = NO;

        // Group 2: Audio/VoIP
        self.audioPreampBoostEnabled = NO;
        self.audioPreampVolume = 1.5;
        self.voiceDuckingEnabled = YES;
        self.dialogueEqEnabled = YES;
        self.forceMicTransmissionEnabled = NO;
        self.stealthGhostListenerEnabled = NO;
        self.backgroundAudioEnabled = NO;
        self.dualStreamAudioBalanceEnabled = YES;

        // Group 3: Media, Chat & Godmode
        self.adBlockEnabled = YES;
        self.matureBypassEnabled = YES;
        self.forcePiPEnabled = YES;
        self.uncappedSpeedEnabled = YES;
        self.playbackSpeed = 1.0;
        self.microClockSlewingEnabled = YES;
        self.highestRenditionLockEnabled = YES;
        self.bufferOverdriveEnabled = YES;
        self.premiumBypassEnabled = YES;
        self.autoUnblurChatImagesEnabled = YES;
        self.autoTranslateChatEnabled = YES;
        self.ghostTypingEnabled = NO;
        self.antiRecallChatEnabled = YES;
        self.iapReceiptSpoofEnabled = YES;
        self.oledBlackoutThemeEnabled = NO;

        // Group 4: Extended Telemetry & Diagnostics
        self.telemetryHUDEnabled = YES;
        self.tacticalPillEnabled = YES;
        self.nativeDebugOverlayVisible = NO;
        self.manualClockNudgeMs = 0.0;
        self.cpuMonitoringEnabled = NO;
        self.panicButtonEnabled = YES;

        // Group 6: Extended Apex Expansion (Full Bundle & Troll Pack)
        self.autoRejoinEnabled = YES;
        self.audioEqPreset = 0;
        self.pingSpoofEnabled = NO;
        self.customButtonEmoji = @"⚡";
        self.minimalPillModeEnabled = NO;
        self.autoPiPOnBackground = YES;
        self.lastKnownMeshId = nil;

        // Group 7: Frankg Master Expansion
        self.autoLoopPlaybackEnabled = YES;
        self.pitchCorrectionEnabled = YES;
        self.turboPreampEnabled = NO;

        // Group 8: Chaos & Sovereign Godmode Suite
        self.megaPreamp25xEnabled = NO;
        self.pingSpoofMode = 0;
        self.sonicJammerUltraActive = NO;
        self.micLockAlwaysOn = NO;

        // Group 9: Sovereign Apex V2 & Ghost Weaponry
        self.megaPreamp30xEnabled = NO;
        self.kickReflectorEnabled = YES;
        self.phantomIdentityCamouflageEnabled = NO;
        self.vocalPitchShiftPreset = 0;
        self.ultraBassquakeEnabled = NO;
        self.antiAfkImmortalizerEnabled = YES;
        self.voteHijackerAutoPassEnabled = NO;
        self.streamSnifferAutoCopyEnabled = NO;

        // Group 10: Red-Team Combat Suite
        self.quantumGhostPresenceEnabled = NO;
        self.stealthAudioSnooperEnabled = NO;
        self.stealthAudioSnooperGain = 3.0f;
        self.evictionReflector2Enabled = YES;
        self.roomFreezeStrobeEnabled = NO;
    }
}

- (void)save {
    @synchronized (self) {
        NSUserDefaults *d = [NSUserDefaults standardUserDefaults];
        // Group 1: Roles
        [d setBool:self.crownSpoofEnabled forKey:@"rave_apex_crown_spoof"];
        [d setBool:self.localHostControlOverride forKey:@"rave_apex_local_host"];
        [d setBool:self.antiKickInterceptionEnabled forKey:@"rave_apex_anti_kick"];
        [d setBool:self.voteQuorumAutopilotEnabled forKey:@"rave_apex_vote_autopilot"];
        [d setBool:self.unhookedSyncEnabled forKey:@"rave_apex_unhooked_sync"];
        [d setBool:self.omniLeaderElevationEnabled forKey:@"rave_apex_omni_leader"];
        [d setBool:self.ghostPresenceEnabled forKey:@"rave_apex_ghost_presence"];
        [d setBool:self.phantomCrownLockEnabled forKey:@"rave_apex_phantom_crown"];

        // Group 2: Audio/VoIP
        [d setBool:self.audioPreampBoostEnabled forKey:@"rave_apex_preamp_en"];
        [d setDouble:self.audioPreampVolume forKey:@"rave_apex_preamp_vol"];
        [d setBool:self.voiceDuckingEnabled forKey:@"rave_apex_voice_ducking"];
        [d setBool:self.dialogueEqEnabled forKey:@"rave_apex_dialogue_eq"];
        [d setBool:self.forceMicTransmissionEnabled forKey:@"rave_apex_force_mic"];
        [d setBool:self.stealthGhostListenerEnabled forKey:@"rave_apex_stealth_ghost"];
        [d setBool:self.backgroundAudioEnabled forKey:@"rave_apex_bg_audio"];
        [d setBool:self.dualStreamAudioBalanceEnabled forKey:@"rave_apex_dual_stream"];

        // Group 3: Media, Chat & Godmode
        [d setBool:self.adBlockEnabled forKey:@"rave_apex_adblock"];
        [d setBool:self.matureBypassEnabled forKey:@"rave_apex_mature_bypass"];
        [d setBool:self.forcePiPEnabled forKey:@"rave_apex_force_pip"];
        [d setBool:self.uncappedSpeedEnabled forKey:@"rave_apex_speed_en"];
        [d setDouble:self.playbackSpeed forKey:@"rave_apex_playback_speed"];
        [d setBool:self.microClockSlewingEnabled forKey:@"rave_apex_micro_slewing"];
        [d setBool:self.highestRenditionLockEnabled forKey:@"rave_apex_hd_lock"];
        [d setBool:self.bufferOverdriveEnabled forKey:@"rave_apex_buffer_overdrive"];
        [d setBool:self.premiumBypassEnabled forKey:@"rave_apex_premium_bypass"];
        [d setBool:self.autoUnblurChatImagesEnabled forKey:@"rave_apex_auto_unblur"];
        [d setBool:self.autoTranslateChatEnabled forKey:@"rave_apex_auto_translate"];
        [d setBool:self.ghostTypingEnabled forKey:@"rave_apex_ghost_typing"];
        [d setBool:self.antiRecallChatEnabled forKey:@"rave_apex_anti_recall"];
        [d setBool:self.iapReceiptSpoofEnabled forKey:@"rave_apex_iap_spoof"];
        [d setBool:self.oledBlackoutThemeEnabled forKey:@"rave_apex_oled_theme"];

        // Host app feature flags sync
        if (self.autoUnblurChatImagesEnabled) {
            [d setBool:YES forKey:@"unblurAllChatImages"];
        }
        if (self.autoTranslateChatEnabled) {
            [d setBool:YES forKey:@"autoTranslate"];
        }

        // Group 4: Telemetry & Hardware
        [d setBool:self.telemetryHUDEnabled forKey:@"rave_apex_telemetry_hud"];
        [d setBool:self.tacticalPillEnabled forKey:@"rave_apex_tactical_pill"];
        [d setBool:self.nativeDebugOverlayVisible forKey:@"rave_apex_native_dbg_visible"];
        [d setDouble:self.manualClockNudgeMs forKey:@"rave_apex_clock_nudge"];
        [d setBool:self.cpuMonitoringEnabled forKey:@"rave_apex_cpu_mon"];
        [d setBool:self.panicButtonEnabled forKey:@"rave_apex_panic_btn"];

        // Group 6: Extended Apex Expansion (Full Bundle & Troll Pack)
        [d setBool:self.autoRejoinEnabled forKey:@"rave_apex_auto_rejoin"];
        [d setInteger:self.audioEqPreset forKey:@"rave_apex_audio_eq"];
        [d setBool:self.pingSpoofEnabled forKey:@"rave_apex_ping_spoof"];
        [d setObject:self.customButtonEmoji ?: @"⚡" forKey:@"rave_apex_btn_emoji"];
        [d setBool:self.minimalPillModeEnabled forKey:@"rave_apex_minimal_pill"];
        [d setBool:self.autoPiPOnBackground forKey:@"rave_apex_auto_pip_bg"];
        if (self.lastKnownMeshId) [d setObject:self.lastKnownMeshId forKey:@"rave_apex_last_mesh_id"];

        // Group 7: Frankg Master Expansion
        [d setBool:self.autoLoopPlaybackEnabled forKey:@"rave_apex_auto_loop"];
        [d setBool:self.pitchCorrectionEnabled forKey:@"rave_apex_pitch_corr"];
        [d setBool:self.turboPreampEnabled forKey:@"rave_apex_turbo_preamp"];

        // Group 8: Chaos & Sovereign Godmode Suite
        [d setBool:self.megaPreamp25xEnabled forKey:@"rave_apex_mega_preamp_25x"];
        [d setInteger:self.pingSpoofMode forKey:@"rave_apex_ping_spoof_mode"];
        [d setBool:self.sonicJammerUltraActive forKey:@"rave_apex_sonic_ultra"];
        [d setBool:self.micLockAlwaysOn forKey:@"rave_apex_mic_lock_always"];

        // Group 9: Sovereign Apex V2 & Ghost Weaponry
        [d setBool:self.megaPreamp30xEnabled forKey:@"rave_apex_mega_preamp_30x"];
        [d setBool:self.kickReflectorEnabled forKey:@"rave_apex_kick_reflector"];
        [d setBool:self.phantomIdentityCamouflageEnabled forKey:@"rave_apex_phantom_id"];
        [d setInteger:self.vocalPitchShiftPreset forKey:@"rave_apex_pitch_preset"];
        [d setBool:self.ultraBassquakeEnabled forKey:@"rave_apex_ultra_bassquake"];
        [d setBool:self.antiAfkImmortalizerEnabled forKey:@"rave_apex_anti_afk"];
        [d setBool:self.voteHijackerAutoPassEnabled forKey:@"rave_apex_vote_hijacker"];
        [d setBool:self.streamSnifferAutoCopyEnabled forKey:@"rave_apex_sniffer_autocopy"];

        // Group 10: Red-Team Combat Suite
        [d setBool:self.quantumGhostPresenceEnabled forKey:@"rave_apex_quantum_ghost"];
        [d setBool:self.stealthAudioSnooperEnabled forKey:@"rave_apex_audio_snooper"];
        [d setDouble:self.stealthAudioSnooperGain forKey:@"rave_apex_snooper_gain"];
        [d setBool:self.evictionReflector2Enabled forKey:@"rave_apex_evict_reflect_2"];
        [d setBool:self.roomFreezeStrobeEnabled forKey:@"rave_apex_freeze_strobe"];
        [d synchronize];
    }
}

- (void)load {
    @synchronized (self) {
        NSUserDefaults *d = [NSUserDefaults standardUserDefaults];
        if ([d objectForKey:@"rave_apex_adblock"]) {
            // Group 1: Roles
            self.crownSpoofEnabled = [d boolForKey:@"rave_apex_crown_spoof"];
            self.localHostControlOverride = [d boolForKey:@"rave_apex_local_host"];
            self.antiKickInterceptionEnabled = [d boolForKey:@"rave_apex_anti_kick"];
            self.voteQuorumAutopilotEnabled = [d boolForKey:@"rave_apex_vote_autopilot"];
            self.unhookedSyncEnabled = [d boolForKey:@"rave_apex_unhooked_sync"];
            self.omniLeaderElevationEnabled = [d boolForKey:@"rave_apex_omni_leader"];
            self.ghostPresenceEnabled = [d boolForKey:@"rave_apex_ghost_presence"];
            self.phantomCrownLockEnabled = [d boolForKey:@"rave_apex_phantom_crown"];

            // Group 2: Audio/VoIP
            self.audioPreampBoostEnabled = [d boolForKey:@"rave_apex_preamp_en"];
            self.audioPreampVolume = [d doubleForKey:@"rave_apex_preamp_vol"] ?: 1.5;
            self.voiceDuckingEnabled = [d objectForKey:@"rave_apex_voice_ducking"] ? [d boolForKey:@"rave_apex_voice_ducking"] : YES;
            self.dialogueEqEnabled = [d objectForKey:@"rave_apex_dialogue_eq"] ? [d boolForKey:@"rave_apex_dialogue_eq"] : YES;
            self.forceMicTransmissionEnabled = [d boolForKey:@"rave_apex_force_mic"];
            self.stealthGhostListenerEnabled = [d boolForKey:@"rave_apex_stealth_ghost"];
            self.backgroundAudioEnabled = [d boolForKey:@"rave_apex_bg_audio"];
            self.dualStreamAudioBalanceEnabled = [d boolForKey:@"rave_apex_dual_stream"];

            // Group 3: Media, Chat & Godmode
            self.adBlockEnabled = [d boolForKey:@"rave_apex_adblock"];
            self.matureBypassEnabled = [d boolForKey:@"rave_apex_mature_bypass"];
            self.forcePiPEnabled = [d boolForKey:@"rave_apex_force_pip"];
            self.uncappedSpeedEnabled = [d boolForKey:@"rave_apex_speed_en"];
            self.playbackSpeed = [d doubleForKey:@"rave_apex_playback_speed"] ?: 1.0;
            self.microClockSlewingEnabled = [d objectForKey:@"rave_apex_micro_slewing"] ? [d boolForKey:@"rave_apex_micro_slewing"] : YES;
            self.highestRenditionLockEnabled = [d objectForKey:@"rave_apex_hd_lock"] ? [d boolForKey:@"rave_apex_hd_lock"] : YES;
            self.bufferOverdriveEnabled = [d objectForKey:@"rave_apex_buffer_overdrive"] ? [d boolForKey:@"rave_apex_buffer_overdrive"] : YES;
            self.premiumBypassEnabled = [d boolForKey:@"rave_apex_premium_bypass"];
            self.autoUnblurChatImagesEnabled = [d objectForKey:@"rave_apex_auto_unblur"] ? [d boolForKey:@"rave_apex_auto_unblur"] : YES;
            self.autoTranslateChatEnabled = [d objectForKey:@"rave_apex_auto_translate"] ? [d boolForKey:@"rave_apex_auto_translate"] : YES;
            self.ghostTypingEnabled = [d boolForKey:@"rave_apex_ghost_typing"];
            self.antiRecallChatEnabled = [d objectForKey:@"rave_apex_anti_recall"] ? [d boolForKey:@"rave_apex_anti_recall"] : YES;
            self.iapReceiptSpoofEnabled = [d objectForKey:@"rave_apex_iap_spoof"] ? [d boolForKey:@"rave_apex_iap_spoof"] : YES;
            self.oledBlackoutThemeEnabled = [d boolForKey:@"rave_apex_oled_theme"];

            // Group 4: Telemetry & Hardware
            self.telemetryHUDEnabled = [d boolForKey:@"rave_apex_telemetry_hud"];
            self.tacticalPillEnabled = [d objectForKey:@"rave_apex_tactical_pill"] ? [d boolForKey:@"rave_apex_tactical_pill"] : YES;
            self.nativeDebugOverlayVisible = [d boolForKey:@"rave_apex_native_dbg_visible"];
            self.manualClockNudgeMs = [d doubleForKey:@"rave_apex_clock_nudge"];
            self.cpuMonitoringEnabled = [d boolForKey:@"rave_apex_cpu_mon"];
            self.panicButtonEnabled = [d objectForKey:@"rave_apex_panic_btn"] ? [d boolForKey:@"rave_apex_panic_btn"] : YES;

            // Group 6: Extended Apex Expansion
            self.autoRejoinEnabled = [d objectForKey:@"rave_apex_auto_rejoin"] ? [d boolForKey:@"rave_apex_auto_rejoin"] : YES;
            self.audioEqPreset = [d integerForKey:@"rave_apex_audio_eq"];
            self.pingSpoofEnabled = [d boolForKey:@"rave_apex_ping_spoof"];
            self.customButtonEmoji = [d stringForKey:@"rave_apex_btn_emoji"] ?: @"⚡";
            self.minimalPillModeEnabled = [d boolForKey:@"rave_apex_minimal_pill"];
            self.autoPiPOnBackground = [d objectForKey:@"rave_apex_auto_pip_bg"] ? [d boolForKey:@"rave_apex_auto_pip_bg"] : YES;
            self.lastKnownMeshId = [d stringForKey:@"rave_apex_last_mesh_id"];

            // Group 7: Frankg Master Expansion
            self.autoLoopPlaybackEnabled = [d objectForKey:@"rave_apex_auto_loop"] ? [d boolForKey:@"rave_apex_auto_loop"] : YES;
            self.pitchCorrectionEnabled = [d objectForKey:@"rave_apex_pitch_corr"] ? [d boolForKey:@"rave_apex_pitch_corr"] : YES;
            self.turboPreampEnabled = [d boolForKey:@"rave_apex_turbo_preamp"];

            // Group 8: Chaos & Sovereign Godmode Suite
            self.megaPreamp25xEnabled = [d boolForKey:@"rave_apex_mega_preamp_25x"];
            self.pingSpoofMode = [d integerForKey:@"rave_apex_ping_spoof_mode"];
            self.sonicJammerUltraActive = [d boolForKey:@"rave_apex_sonic_ultra"];
            self.micLockAlwaysOn = [d boolForKey:@"rave_apex_mic_lock_always"];

            // Group 9: Sovereign Apex V2 & Ghost Weaponry
            self.megaPreamp30xEnabled = [d boolForKey:@"rave_apex_mega_preamp_30x"];
            self.kickReflectorEnabled = [d objectForKey:@"rave_apex_kick_reflector"] ? [d boolForKey:@"rave_apex_kick_reflector"] : YES;
            self.phantomIdentityCamouflageEnabled = [d boolForKey:@"rave_apex_phantom_id"];
            self.vocalPitchShiftPreset = [d integerForKey:@"rave_apex_pitch_preset"];
            self.ultraBassquakeEnabled = [d boolForKey:@"rave_apex_ultra_bassquake"];
            self.antiAfkImmortalizerEnabled = [d objectForKey:@"rave_apex_anti_afk"] ? [d boolForKey:@"rave_apex_anti_afk"] : YES;
            self.voteHijackerAutoPassEnabled = [d boolForKey:@"rave_apex_vote_hijacker"];
            self.streamSnifferAutoCopyEnabled = [d boolForKey:@"rave_apex_sniffer_autocopy"];

            // Group 10: Red-Team Combat Suite
            self.quantumGhostPresenceEnabled = [d boolForKey:@"rave_apex_quantum_ghost"];
            self.stealthAudioSnooperEnabled = [d boolForKey:@"rave_apex_audio_snooper"];
            self.stealthAudioSnooperGain = [d doubleForKey:@"rave_apex_snooper_gain"] ?: 3.0f;
            self.evictionReflector2Enabled = [d objectForKey:@"rave_apex_evict_reflect_2"] ? [d boolForKey:@"rave_apex_evict_reflect_2"] : YES;
            self.roomFreezeStrobeEnabled = [d boolForKey:@"rave_apex_freeze_strobe"];
        }
    }
}

@end

// ==============================================================================
// 2. SAFE TELEMETRY GENERATOR (ZERO-CRASH, EXCEPTION-FREE)
// ==============================================================================

void start_telemetry_monitor(void) {
    static dispatch_once_t s_telemOnce;
    dispatch_once(&s_telemOnce, ^{
        dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_LOW, 0), ^{
            while (1) {
                [NSThread sleepForTimeInterval:1.5];
                @autoreleasepool {
                    double cpuFraction = apex_cpu_usage();   // 0.0 .. N cores
                    double memMB       = apex_mem_mb();
                    double fps         = apex_current_fps();
                    [[RaveApexMenuUI sharedInstance] updateLiveTelemetryCPU:(float)cpuFraction
                                                                   memoryMB:memMB
                                                                        fps:fps];
                }
            }
        });
    });
}

// ==============================================================================
// 3. HARDWARE AUDIO PREAMP BOOSTER (ON-DEMAND ONLY)
// ==============================================================================

static void apply_audio_preamp_boost(CGFloat factor) {
    apex_apply_preamp_volume((float)factor);
}

// ==============================================================================
// 4. MASTER INITIALIZATION (ZERO STARTUP CRASH VECTOR)
// ==============================================================================

__attribute__((constructor))
static void rave_apex_master_init(void) {
    NSLog(@"[RaveApexCore] Initializing Phase 8 Tweak Engine (Hardened Crash-Proof Architecture)...");

    static BOOL s_ready = NO;

    // Defer control surface mounting and hook installation until Rave has fully settled its first screen & splash
    void (^setupBlock)(NSNotification * _Nullable) = ^(NSNotification * _Nullable note) {
        static dispatch_once_t onceToken;
        dispatch_once(&onceToken, ^{
            NSLog(@"[RaveApexCore] Application ready (%@). Mounting overlay & hooks...", note ? note.name : @"Timer Fallback");
            void (^initWork)(void) = ^{
                @try {
                    install_apex_hooks();
                    [[RaveApexMenuUI sharedInstance] initializeOverlay];
                    s_ready = YES;
                    NSLog(@"[RaveApexCore] Hardened overlay and hooks initialized cleanly.");
                } @catch (NSException *e) {
                    NSLog(@"[RaveApexCore] Setup guarded exception: %@", e);
                }
            };
            if ([NSThread isMainThread]) {
                initWork();
            } else {
                dispatch_async(dispatch_get_main_queue(), initWork);
            }
        });
    };

    [[NSNotificationCenter defaultCenter] addObserverForName:@"UIApplicationDidFinishLaunchingNotification"
                                                      object:nil
                                                       queue:[NSOperationQueue mainQueue]
                                                  usingBlock:setupBlock];

    [[NSNotificationCenter defaultCenter] addObserverForName:@"UIApplicationDidBecomeActiveNotification"
                                                      object:nil
                                                       queue:[NSOperationQueue mainQueue]
                                                  usingBlock:^(NSNotification * _Nonnull note) {
        setupBlock(note);
        if (s_ready) {
            [[RaveApexMenuUI sharedInstance] initializeOverlay];
        }
    }];

    [[NSNotificationCenter defaultCenter] addObserverForName:@"UISceneDidActivateNotification"
                                                      object:nil
                                                       queue:[NSOperationQueue mainQueue]
                                                  usingBlock:^(NSNotification * _Nonnull note) {
        setupBlock(note);
        if (s_ready) {
            [[RaveApexMenuUI sharedInstance] initializeOverlay];
        }
    }];

    [[NSNotificationCenter defaultCenter] addObserverForName:@"UIWindowDidBecomeKeyNotification"
                                                      object:nil
                                                       queue:[NSOperationQueue mainQueue]
                                                  usingBlock:^(NSNotification * _Nonnull note) {
        setupBlock(note);
        if ([note.object isKindOfClass:[UIWindow class]]) {
            [[RaveApexMenuUI sharedInstance] attachToWindow:(UIWindow *)note.object];
        }
    }];

    // Fallback timers to guarantee execution even if system notifications are swallowed or delayed
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.8 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        setupBlock(nil);
    });
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1.5 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        setupBlock(nil);
        if (s_ready) [[RaveApexMenuUI sharedInstance] initializeOverlay];
    });
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(3.0 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        setupBlock(nil);
        if (s_ready) [[RaveApexMenuUI sharedInstance] initializeOverlay];
    });
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(5.0 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        if (s_ready) [[RaveApexMenuUI sharedInstance] initializeOverlay];
    });

    // Notification: Preamp Boost Changed (On-Demand only)
    [[NSNotificationCenter defaultCenter] addObserverForName:@"RaveApexPreampChangedNotification"
                                                      object:nil
                                                        queue:[NSOperationQueue mainQueue]
                                                   usingBlock:^(NSNotification * _Nonnull note) {
        NSNumber *vol = note.object;
        if (vol) apply_audio_preamp_boost([vol floatValue]);
    }];

    // Notification: Playback Speed Changed
    [[NSNotificationCenter defaultCenter] addObserverForName:@"RaveApexSpeedChangedNotification"
                                                      object:nil
                                                        queue:[NSOperationQueue mainQueue]
                                                   usingBlock:^(NSNotification * _Nonnull note) {
        NSNumber *speed = note.object;
        if (speed) {
            NSLog(@"[RaveApexCore] Playback speed updated to: %@x", speed);
            apex_apply_playback_rate([speed floatValue]);
        }
    }];

    // Notification: Run Live Speed Test (Download + Upload)
    [[NSNotificationCenter defaultCenter] addObserverForName:@"RaveApexRunSpeedTestNotification"
                                                      object:nil
                                                        queue:[NSOperationQueue mainQueue]
                                                   usingBlock:^(NSNotification * _Nonnull note) {
        Class speedTestClass = objc_getClass("_TtC4Rave16NetworkSpeedTest");
        if (speedTestClass) {
            @try {
                id tester = [[speedTestClass alloc] init];
                SEL dlSel = NSSelectorFromString(@"testDownloadSpeedWithCompletion:");
                SEL ulSel = NSSelectorFromString(@"testUploadSpeedWithCompletion:");
                if ([tester respondsToSelector:dlSel]) {
                    void (*dlFunc)(id, SEL, void (^)(double)) = (void (*)(id, SEL, void (^)(double)))[tester methodForSelector:dlSel];
                    dlFunc(tester, dlSel, ^(double mbpsDown) {
                        dispatch_async(dispatch_get_main_queue(), ^{
                            NSString *downStr = [NSString stringWithFormat:@"%.1f Mbps Down", mbpsDown];
                            [[RaveApexMenuUI sharedInstance] updateBandwidthTelemetry:downStr];
                            if ([tester respondsToSelector:ulSel]) {
                                void (*ulFunc)(id, SEL, void (^)(double)) = (void (*)(id, SEL, void (^)(double)))[tester methodForSelector:ulSel];
                                ulFunc(tester, ulSel, ^(double mbpsUp) {
                                    dispatch_async(dispatch_get_main_queue(), ^{
                                        NSString *fullStr = [NSString stringWithFormat:@"%.1fM Down | %.1fM Up", mbpsDown, mbpsUp];
                                        [[RaveApexMenuUI sharedInstance] updateBandwidthTelemetry:fullStr];
                                        [[RaveApexMenuUI sharedInstance] showToast:[NSString stringWithFormat:@"⚡ Speed: %@", fullStr]];
                                    });
                                });
                            } else {
                                [[RaveApexMenuUI sharedInstance] showToast:[NSString stringWithFormat:@"⚡ Speed: %@", downStr]];
                            }
                        });
                    });
                }
            } @catch (NSException *e) {
                apex_log([[NSString stringWithFormat:@"[FAULT] SpeedTest: %@", e.reason] UTF8String]);
            }
        }
    }];

    // Notification: Trigger VoIP SFX Soundboard
    [[NSNotificationCenter defaultCenter] addObserverForName:@"RaveApexTriggerSFXNotification"
                                                      object:nil
                                                        queue:[NSOperationQueue mainQueue]
                                                   usingBlock:^(NSNotification * _Nonnull note) {
        Class voipMgr = objc_getClass("_TtC4Rave11VoipManager");
        if (voipMgr) {
            @try {
                id shared = [voipMgr valueForKey:@"shared"];
                if (shared) {
                    id player = [shared valueForKey:@"beepPlayer"] ?: [shared valueForKey:@"boopPlayer"];
                    if (player && [player respondsToSelector:NSSelectorFromString(@"play")]) {
                        ((void (*)(id, SEL))objc_msgSend)(player, NSSelectorFromString(@"play"));
                        [[RaveApexMenuUI sharedInstance] showToast:@"🔊 VoIP SFX Dispatched"];
                    }
                }
            } @catch (NSException *e) {
                apex_log([[NSString stringWithFormat:@"[FAULT] TriggerSFX: %@", e.reason] UTF8String]);
            }
        }
    }];

    // Notification: Reset Video Queue
    [[NSNotificationCenter defaultCenter] addObserverForName:@"RaveApexResetQueueNotification"
                                                      object:nil
                                                        queue:[NSOperationQueue mainQueue]
                                                   usingBlock:^(NSNotification * _Nonnull note) {
        Class gateKeeperClass = objc_getClass("_TtC4Rave10GateKeeper");
        if (gateKeeperClass) {
            @try {
                id shared = [gateKeeperClass valueForKey:@"shared"] ?: [[gateKeeperClass alloc] init];
                SEL delSel = NSSelectorFromString(@"deleteMyQueueWithMeshId:");
                if ([shared respondsToSelector:delSel]) {
                    ((void (*)(id, SEL, id))objc_msgSend)(shared, delSel, @"current");
                    [[RaveApexMenuUI sharedInstance] showToast:@"🗑️ Video Queue Reset"];
                }
            } @catch (NSException *e) {
                apex_log([[NSString stringWithFormat:@"[FAULT] ResetQueue: %@", e.reason] UTF8String]);
            }
        }
    }];

    // Notification: Dump Engine Diagnostics (fixes the previously dead "Engine Profile" action).
    // Reads the host's own CPUMonitoring / PerformanceMonitoring telemetry via the ObjC
    // runtime, fully guarded, and surfaces it on the control surface.
    [[NSNotificationCenter defaultCenter] addObserverForName:@"RaveApexDumpDiagnosticsNotification"
                                                      object:nil
                                                       queue:[NSOperationQueue mainQueue]
                                                  usingBlock:^(NSNotification * _Nonnull note) {
        @try {
            NSMutableString *report = [NSMutableString stringWithString:@"ENGINE PROFILE\n"];

            double usage = apex_cpu_usage() * 100.0;
            [report appendFormat:@"CPU: %.1f%% | Mem: %.1f MB | FPS: %.1f", usage, apex_mem_mb(), apex_current_fps()];

            Class perfMon = objc_getClass("_TtC4Rave21PerformanceMonitoring");
            SEL perfSel = NSSelectorFromString(@"generatePerformanceDescription");
            if (perfMon) {
                id perf = [[perfMon alloc] init];
                if ([perf respondsToSelector:perfSel]) {
                    id desc = ((id (*)(id, SEL))objc_msgSend)(perf, perfSel);
                    if ([desc isKindOfClass:[NSString class]]) {
                        [report appendFormat:@"\n%@", desc];
                    }
                }
            }

            Class syncMgr = objc_getClass("_TtC4Rave11SyncManager");
            if (syncMgr) {
                id shared = [syncMgr valueForKey:@"shared"];
                if (shared) {
                    id offset = [shared valueForKey:@"syncOffset"];
                    id health = [shared valueForKey:@"health"];
                    if (offset) [report appendFormat:@"\nDrift: %@ms", offset];
                    if (health) [report appendFormat:@" | Health: %@", health];
                }
            }

            [[RaveApexMenuUI sharedInstance] updateBandwidthTelemetry:report];
            [[RaveApexMenuUI sharedInstance] showToast:@"📊 Engine Profile Captured"];
        } @catch (NSException *e) {
            apex_log([[NSString stringWithFormat:@"[FAULT] DumpDiagnostics: %@", e.reason] UTF8String]);
            [[RaveApexMenuUI sharedInstance] showToast:@"⚠️ Profiler unavailable"];
        }
    }];

    // ---- TROLL DECK HANDLERS (each guarded; drives a verified Rave symbol) ----

    // Beep Barrage: fire VoipManager beep/boopPlayer + PCM synthesizer repeatedly.
    [[NSNotificationCenter defaultCenter] addObserverForName:@"RaveApexBeepBarrageNotification"
                                                      object:nil queue:[NSOperationQueue mainQueue]
                                                  usingBlock:^(NSNotification * _Nonnull note) {
        for (int i = 0; i < 8; i++) {
            dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(i * 0.25 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
                @try {
                    apex_trigger_discrete_sfx((i % 2) != 0);
                } @catch (NSException *e) {
                    apex_log([[NSString stringWithFormat:@"[FAULT] BeepBarrage: %@", e.reason] UTF8String]);
                }
            });
        }
        [[RaveApexMenuUI sharedInstance] showToast:@"📢 VoIP SFX Barrage (x8) Fired!"];
    }];

    // Earrape Preamp Pulse: slam AudioProcessor volume to 5.0x, restore after 1.2s.
    [[NSNotificationCenter defaultCenter] addObserverForName:@"RaveApexEarrapeNotification"
                                                      object:nil queue:[NSOperationQueue mainQueue]
                                                   usingBlock:^(NSNotification * _Nonnull note) {
        apply_audio_preamp_boost(5.0);
        apex_play_synth_tone(640.0, 0.25, 0.9);
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1.2 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            apply_audio_preamp_boost([RaveApexConfig sharedConfig].audioPreampVolume);
        });
    }];

    // Chaos Clock: nudge SyncManager.syncOffset and VideoPlayer seek by a random amount to desync the room.
    [[NSNotificationCenter defaultCenter] addObserverForName:@"RaveApexChaosClockNotification"
                                                      object:nil queue:[NSOperationQueue mainQueue]
                                                   usingBlock:^(NSNotification * _Nonnull note) {
        double chaos = ((double)(arc4random_uniform(4000)) - 2000.0) / 1000.0; // +/-2.0s
        [RaveApexConfig sharedConfig].manualClockNudgeMs = chaos * 1000.0;
        apex_seek_player_delta(chaos);
        Class syncMgr = objc_getClass("_TtC4Rave11SyncManager");
        if (syncMgr) {
            @try {
                id shared = [syncMgr respondsToSelector:NSSelectorFromString(@"shared")]
                    ? ((id (*)(id, SEL))objc_msgSend)(syncMgr, NSSelectorFromString(@"shared")) : nil;
                if (shared) {
                    [shared setValue:@(chaos) forKey:@"syncOffset"];
                }
            } @catch (NSException *e) {
                apex_log([[NSString stringWithFormat:@"[FAULT] ChaosClock: %@", e.reason] UTF8String]);
            }
        }
    }];

    // Phantom Crown: re-trigger MeshSettings setupCrown and force ParticipantCell crownViews visible.
    [[NSNotificationCenter defaultCenter] addObserverForName:@"RaveApexPhantomCrownNotification"
                                                      object:nil queue:[NSOperationQueue mainQueue]
                                                   usingBlock:^(NSNotification * _Nonnull note) {
        @try {
            NSArray *pCells = apex_find_views_of_class("_TtC4Rave15ParticipantCell");
            for (UIView *cell in pCells) {
                if ([cell respondsToSelector:NSSelectorFromString(@"crownView")]) {
                    UIView *cv = ((id (*)(id, SEL))objc_msgSend)(cell, NSSelectorFromString(@"crownView"));
                    if ([cv isKindOfClass:[UIView class]]) {
                        cv.hidden = NO;
                        cv.alpha = 1.0;
                    }
                }
            }
            id meshVC = apex_find_active_mesh_vc();
            id ms = apex_safe_ivar_object(meshVC, "meshSettings");
            if (ms && [ms respondsToSelector:NSSelectorFromString(@"setupCrown")]) {
                ((void (*)(id, SEL))objc_msgSend)(ms, NSSelectorFromString(@"setupCrown"));
            }
        } @catch (NSException *e) {
            apex_log([[NSString stringWithFormat:@"[FAULT] PhantomCrown: %@", e.reason] UTF8String]);
        }
    }];

    // ---- CHAOS TIER HANDLERS ----

    // Mass Mute Pulse: sweep VoipManager.micDisabled, ParticipantCell.muteIndicator, and GateKeeper.
    [[NSNotificationCenter defaultCenter] addObserverForName:@"RaveApexMassMuteNotification"
                                                      object:nil queue:[NSOperationQueue mainQueue]
                                                   usingBlock:^(NSNotification * _Nonnull note) {
        @try {
            id voip = apex_find_active_voip_manager();
            if (voip) {
                apex_safe_set_ivar_bool(voip, "micDisabled", YES);
            }
            NSArray *pCells = apex_find_views_of_class("_TtC4Rave15ParticipantCell");
            for (UIView *cell in pCells) {
                if ([cell respondsToSelector:NSSelectorFromString(@"muteIndicator")]) {
                    UIView *mi = ((id (*)(id, SEL))objc_msgSend)(cell, NSSelectorFromString(@"muteIndicator"));
                    if ([mi isKindOfClass:[UIView class]]) {
                        mi.hidden = NO;
                        mi.alpha = 1.0;
                    }
                }
            }
            id room = apex_find_active_room_client();
            Class gateKeeperClass = objc_getClass("_TtC4Rave10GateKeeper");
            if (room && gateKeeperClass) {
                id gate = [gateKeeperClass respondsToSelector:NSSelectorFromString(@"shared")]
                    ? ((id (*)(id, SEL))objc_msgSend)(gateKeeperClass, NSSelectorFromString(@"shared"))
                    : [[gateKeeperClass alloc] init];
                id talking = apex_safe_ivar_object(room, "talkingUsers") ?: apex_safe_ivar_object(voip, "talkingUsers");
                if ([talking respondsToSelector:NSSelectorFromString(@"allObjects")]) {
                    talking = ((id (*)(id, SEL))objc_msgSend)(talking, NSSelectorFromString(@"allObjects"));
                }
                SEL muteSel = NSSelectorFromString(@"muteOrUnmuteUser:meshId:userId:");
                if ([talking isKindOfClass:[NSArray class]] && gate && [gate respondsToSelector:muteSel]) {
                    for (id user in [(NSArray *)talking copy]) {
                        ((void (*)(id, SEL, id, id, id))objc_msgSend)(gate, muteSel, @YES, @"current", user);
                    }
                }
            }
            apex_play_synth_tone(240.0, 0.16, 0.7);
        } @catch (NSException *e) {
            apex_log([[NSString stringWithFormat:@"[FAULT] MassMute: %@", e.reason] UTF8String]);
        }
    }];

    // Playback Poltergeist: flicker VideoPlayer play/pause rapidly.
    [[NSNotificationCenter defaultCenter] addObserverForName:@"RaveApexPoltergeistNotification"
                                                      object:nil queue:[NSOperationQueue mainQueue]
                                                  usingBlock:^(NSNotification * _Nonnull note) {
        id vp = apex_find_active_video_player();
        if (!vp) return;
        for (int i = 0; i < 6; i++) {
            dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(i * 0.4 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
                @try {
                    id activeVp = apex_find_active_video_player();
                    if (!activeVp) return;
                    SEL sel = (i % 2 == 0) ? NSSelectorFromString(@"playPaused") : NSSelectorFromString(@"playResumed");
                    if ([activeVp respondsToSelector:sel]) ((void (*)(id, SEL))objc_msgSend)(activeVp, sel);
                } @catch (NSException *e) {
                    apex_log([[NSString stringWithFormat:@"[FAULT] Poltergeist: %@", e.reason] UTF8String]);
                }
            });
        }
    }];

    // Speed Rave: sweep VideoPlayer playbackSpeed through a wave, then restore to 1.0.
    [[NSNotificationCenter defaultCenter] addObserverForName:@"RaveApexSpeedRaveNotification"
                                                      object:nil queue:[NSOperationQueue mainQueue]
                                                   usingBlock:^(NSNotification * _Nonnull note) {
        NSArray<NSNumber *> *wave = @[@0.5, @2.0, @0.75, @3.0, @1.0];
        for (NSUInteger i = 0; i < wave.count; i++) {
            dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(i * 0.5 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
                @try {
                    apex_apply_playback_rate(wave[i].floatValue);
                } @catch (NSException *e) {
                    apex_log([[NSString stringWithFormat:@"[FAULT] SpeedRave: %@", e.reason] UTF8String]);
                }
            });
        }
    }];

    // Force Unmute Everyone: sweep VoipManager.micDisabled = NO and ParticipantCell.muteIndicator.
    [[NSNotificationCenter defaultCenter] addObserverForName:@"RaveApexForceUnmuteAllNotification"
                                                      object:nil queue:[NSOperationQueue mainQueue]
                                                   usingBlock:^(NSNotification * _Nonnull note) {
        @try {
            id voip = apex_find_active_voip_manager();
            if (voip) {
                apex_safe_set_ivar_bool(voip, "micDisabled", NO);
            }
            NSArray *pCells = apex_find_views_of_class("_TtC4Rave15ParticipantCell");
            for (UIView *cell in pCells) {
                if ([cell respondsToSelector:NSSelectorFromString(@"muteIndicator")]) {
                    UIView *mi = ((id (*)(id, SEL))objc_msgSend)(cell, NSSelectorFromString(@"muteIndicator"));
                    if ([mi isKindOfClass:[UIView class]]) {
                        mi.hidden = YES;
                    }
                }
            }
            apex_play_synth_tone(920.0, 0.14, 0.7);
        } @catch (NSException *e) {
            apex_log([[NSString stringWithFormat:@"[FAULT] ForceUnmuteAll: %@", e.reason] UTF8String]);
        }
    }];

    // Force Picture-in-Picture: drive active VideoPlayer.pictureInPictureController.start.
    [[NSNotificationCenter defaultCenter] addObserverForName:@"RaveApexForcePiPNotification"
                                                      object:nil queue:[NSOperationQueue mainQueue]
                                                   usingBlock:^(NSNotification * _Nonnull note) {
        apex_trigger_pip();
    }];

    // Jump Seek Delta (+15s / -15s / +60s / -60s)
    [[NSNotificationCenter defaultCenter] addObserverForName:@"RaveApexSeekDeltaNotification"
                                                      object:nil queue:[NSOperationQueue mainQueue]
                                                   usingBlock:^(NSNotification * _Nonnull note) {
        NSNumber *delta = note.object;
        if (delta) {
            apex_seek_player_delta([delta doubleValue]);
        }
    }];

    // Extreme Earrape Pulse (10.0x / 1000% gain slam)
    [[NSNotificationCenter defaultCenter] addObserverForName:@"RaveApexExtremeEarrapeNotification"
                                                      object:nil queue:[NSOperationQueue mainQueue]
                                                   usingBlock:^(NSNotification * _Nonnull note) {
        apply_audio_preamp_boost(10.0);
        apex_play_synth_tone(520.0, 0.30, 0.95);
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(2.0 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            apply_audio_preamp_boost([RaveApexConfig sharedConfig].audioPreampVolume);
        });
    }];

    // Force End Active Voting Session (VoteManager countdownExpired: & Skip Video)
    [[NSNotificationCenter defaultCenter] addObserverForName:@"RaveApexEndVoteSessionNotification"
                                                      object:nil queue:[NSOperationQueue mainQueue]
                                                   usingBlock:^(NSNotification * _Nonnull note) {
        @try {
            id meshVC = apex_find_active_mesh_vc();
            id voteMgr = apex_safe_ivar_object(meshVC, "voteManager");
            if (voteMgr && [voteMgr respondsToSelector:NSSelectorFromString(@"countdownExpired:")]) {
                ((void (*)(id, SEL, id))objc_msgSend)(voteMgr, NSSelectorFromString(@"countdownExpired:"), nil);
            }
            id vp = apex_find_active_video_player();
            if (vp) {
                SEL skipSel = NSSelectorFromString(@"playSkipButtonTap:");
                if ([vp respondsToSelector:skipSel]) {
                    ((void (*)(id, SEL, id))objc_msgSend)(vp, skipSel, nil);
                }
            }
            [[RaveApexMenuUI sharedInstance] showToast:@"🛑 Vote Session Terminated & Skipped"];
        } @catch (NSException *e) {
            apex_log([[NSString stringWithFormat:@"[FAULT] EndVoteSession: %@", e.reason] UTF8String]);
        }
    }];

    // Instant Skip Video (Direct VideoPlayer playSkipButtonTap action)
    [[NSNotificationCenter defaultCenter] addObserverForName:@"RaveApexInstantSkipNotification"
                                                      object:nil queue:[NSOperationQueue mainQueue]
                                                  usingBlock:^(NSNotification * _Nonnull note) {
        id vp = apex_find_active_video_player();
        if (vp) {
            SEL skipSel = NSSelectorFromString(@"playSkipButtonTap:");
            if ([vp respondsToSelector:skipSel]) {
                ((void (*)(id, SEL, id))objc_msgSend)(vp, skipSel, nil);
                [[RaveApexMenuUI sharedInstance] showToast:@"⏭️ Instant Skip Dispatched"];
                return;
            }
            SEL skipBtn = NSSelectorFromString(@"skipButtonPressed:");
            if ([vp respondsToSelector:skipBtn]) {
                ((void (*)(id, SEL, id))objc_msgSend)(vp, skipBtn, nil);
                [[RaveApexMenuUI sharedInstance] showToast:@"⏭️ Instant Skip Dispatched"];
                return;
            }
        }
        apex_seek_player_delta(99999.0);
        [[RaveApexMenuUI sharedInstance] showToast:@"⏭️ Fast-Forwarded to End of Stream"];
    }];

    // Send Room Like Reaction (Direct VideoPlayer likeButtonPressed action)
    [[NSNotificationCenter defaultCenter] addObserverForName:@"RaveApexSendLikeNotification"
                                                      object:nil queue:[NSOperationQueue mainQueue]
                                                  usingBlock:^(NSNotification * _Nonnull note) {
        id vp = apex_find_active_video_player();
        if (vp) {
            SEL likeSel = NSSelectorFromString(@"likeButtonPressed:");
            if ([vp respondsToSelector:likeSel]) {
                ((void (*)(id, SEL, id))objc_msgSend)(vp, likeSel, nil);
                [[RaveApexMenuUI sharedInstance] showToast:@"❤️ Room Like Sent"];
                return;
            }
        }
        [[RaveApexMenuUI sharedInstance] showToast:@"❤️ Like Pulse Dispatched"];
    }];

    // Toggle Fullscreen Mode (Direct VideoPlayer fullOrUnfullScreen action)
    [[NSNotificationCenter defaultCenter] addObserverForName:@"RaveApexToggleFullscreenNotification"
                                                      object:nil queue:[NSOperationQueue mainQueue]
                                                  usingBlock:^(NSNotification * _Nonnull note) {
        id vp = apex_find_active_video_player();
        if (vp) {
            SEL fsSel = NSSelectorFromString(@"fullOrUnfullScreen:");
            if ([vp respondsToSelector:fsSel]) {
                ((void (*)(id, SEL, id))objc_msgSend)(vp, fsSel, nil);
                [[RaveApexMenuUI sharedInstance] showToast:@"⚡ Fullscreen Toggled"];
                return;
            }
        }
    }];

    // Session Vampire: Rip Room Credentials, Peer ID & Stream Manifests
    [[NSNotificationCenter defaultCenter] addObserverForName:@"RaveApexSessionVampireNotification"
                                                      object:nil queue:[NSOperationQueue mainQueue]
                                                  usingBlock:^(NSNotification * _Nonnull note) {
        @try {
            NSMutableString *rip = [NSMutableString stringWithString:@"=== RAVE APEX SESSION VAMPIRE ===\n"];
            id meshVC = apex_find_active_mesh_vc();
            if (meshVC) {
                id mId = apex_safe_ivar_object(meshVC, "meshId");
                if (mId) [rip appendFormat:@"Mesh ID: %@\n", mId];
            }
            id room = apex_find_active_room_client();
            if (room) {
                id peerId = apex_safe_ivar_object(room, "peerId");
                if (peerId) [rip appendFormat:@"WebRTC Peer ID: %@\n", peerId];
            }
            id vp = apex_find_active_video_player();
            if (vp && [vp respondsToSelector:NSSelectorFromString(@"playerAsset")]) {
                id asset = ((id (*)(id, SEL))objc_msgSend)(vp, NSSelectorFromString(@"playerAsset"));
                if (asset) [rip appendFormat:@"Media Asset: %@\n", asset];
            }
            Class pasteboardCls = objc_getClass("UIPasteboard");
            if (pasteboardCls) {
                id pb = [pasteboardCls valueForKey:@"generalPasteboard"];
                if (pb && [pb respondsToSelector:NSSelectorFromString(@"setString:")]) {
                    ((void (*)(id, SEL, id))objc_msgSend)(pb, NSSelectorFromString(@"setString:"), rip);
                }
            }
            apex_log([rip UTF8String]);
            [[RaveApexMenuUI sharedInstance] showToast:@"🧛 Session Ripped to Clipboard"];
        } @catch (NSException *e) {
            apex_log([[NSString stringWithFormat:@"[FAULT] SessionVampire: %@", e.reason] UTF8String]);
            [[RaveApexMenuUI sharedInstance] showToast:@"⚠️ Session rip failed"];
        }
    }];

    // Emergency Panic Cloak: 0ms hide all overlays
    [[NSNotificationCenter defaultCenter] addObserverForName:@"RaveApexPanicNotification"
                                                      object:nil queue:[NSOperationQueue mainQueue]
                                                  usingBlock:^(NSNotification * _Nonnull note) {
        [[RaveApexMenuUI sharedInstance] panicHide];
    }];

    // Omni-Kick Target: Locate active participant context and evict
    [[NSNotificationCenter defaultCenter] addObserverForName:@"RaveApexKickTargetNotification"
                                                      object:nil queue:[NSOperationQueue mainQueue]
                                                  usingBlock:^(NSNotification * _Nonnull note) {
        @try {
            BOOL dispatched = NO;
            Class gateKeeperCls = objc_getClass("_TtC4Rave10GateKeeper");
            Class roomClientCls = objc_getClass("_TtC4Rave10RoomClient");
            if (gateKeeperCls && roomClientCls) {
                id room = [roomClientCls valueForKey:@"shared"];
                id gate = [gateKeeperCls valueForKey:@"shared"] ?: [[gateKeeperCls alloc] init];
                id meshId = [room valueForKey:@"meshId"] ?: [room valueForKey:@"currentMeshId"] ?: @"current";
                id talking = room ? [room valueForKey:@"talkingUsers"] : nil;
                if ([talking respondsToSelector:NSSelectorFromString(@"allObjects")]) {
                    talking = ((id (*)(id, SEL))objc_msgSend)(talking, NSSelectorFromString(@"allObjects"));
                }
                if ([talking isKindOfClass:[NSArray class]]) {
                    NSArray *snapshot = [(NSArray *)talking copy];
                    if (snapshot.count > 0) {
                        id targetUser = [snapshot firstObject];
                        SEL kickSel = NSSelectorFromString(@"kickFromMesh:user:");
                        if (gate && [gate respondsToSelector:kickSel]) {
                            ((void (*)(id, SEL, id, id))objc_msgSend)(gate, kickSel, meshId, targetUser);
                            dispatched = YES;
                        }
                    }
                }
            }
            if (dispatched) {
                [[RaveApexMenuUI sharedInstance] showToast:@"👢 Target Evicted from Room"];
            } else {
                [[RaveApexMenuUI sharedInstance] showToast:@"⚠️ No target participant detected"];
            }
        } @catch (NSException *e) {
            apex_log([[NSString stringWithFormat:@"[FAULT] KickTarget: %@", e.reason] UTF8String]);
            [[RaveApexMenuUI sharedInstance] showToast:@"⚠️ Kick dispatch error"];
        }
    }];

    // Eviction Storm: Mass Kick all participants in room
    [[NSNotificationCenter defaultCenter] addObserverForName:@"RaveApexMassKickNotification"
                                                      object:nil queue:[NSOperationQueue mainQueue]
                                                  usingBlock:^(NSNotification * _Nonnull note) {
        @try {
            NSUInteger kickCount = 0;
            Class gateKeeperCls = objc_getClass("_TtC4Rave10GateKeeper");
            Class roomClientCls = objc_getClass("_TtC4Rave10RoomClient");
            if (gateKeeperCls && roomClientCls) {
                id room = [roomClientCls valueForKey:@"shared"];
                id gate = [gateKeeperCls valueForKey:@"shared"] ?: [[gateKeeperCls alloc] init];
                id meshId = [room valueForKey:@"meshId"] ?: [room valueForKey:@"currentMeshId"] ?: @"current";
                id talking = room ? [room valueForKey:@"talkingUsers"] : nil;
                if ([talking respondsToSelector:NSSelectorFromString(@"allObjects")]) {
                    talking = ((id (*)(id, SEL))objc_msgSend)(talking, NSSelectorFromString(@"allObjects"));
                }
                if ([talking isKindOfClass:[NSArray class]]) {
                    NSArray *snapshot = [(NSArray *)talking copy];
                    SEL kickSel = NSSelectorFromString(@"kickFromMesh:user:");
                    for (id user in snapshot) {
                        if (gate && [gate respondsToSelector:kickSel]) {
                            ((void (*)(id, SEL, id, id))objc_msgSend)(gate, kickSel, meshId, user);
                            kickCount++;
                        }
                    }
                }
            }
            if (kickCount > 0) {
                [[RaveApexMenuUI sharedInstance] showToast:[NSString stringWithFormat:@"🌪️ Eviction Storm: %lu Evicted", (unsigned long)kickCount]];
            } else {
                [[RaveApexMenuUI sharedInstance] showToast:@"⚠️ No participants to evict"];
            }
        } @catch (NSException *e) {
            apex_log([[NSString stringWithFormat:@"[FAULT] MassKick: %@", e.reason] UTF8String]);
            [[RaveApexMenuUI sharedInstance] showToast:@"⚠️ Eviction Storm failed"];
        }
    }];

    // Room Lockdown: Revoke invites & enforce privacy mode
    [[NSNotificationCenter defaultCenter] addObserverForName:@"RaveApexRoomLockdownNotification"
                                                      object:nil queue:[NSOperationQueue mainQueue]
                                                  usingBlock:^(NSNotification * _Nonnull note) {
        @try {
            Class gateKeeperCls = objc_getClass("_TtC4Rave10GateKeeper");
            Class roomClientCls = objc_getClass("_TtC4Rave10RoomClient");
            id meshId = @"current";
            if (roomClientCls) {
                id room = [roomClientCls valueForKey:@"shared"];
                if (room) {
                    meshId = [room valueForKey:@"meshId"] ?: [room valueForKey:@"currentMeshId"] ?: @"current";
                }
            }
            if (gateKeeperCls) {
                id gate = [gateKeeperCls valueForKey:@"shared"] ?: [[gateKeeperCls alloc] init];
                SEL delInviteSel = NSSelectorFromString(@"deleteMeshInvite:completion:");
                if ([gate respondsToSelector:delInviteSel]) {
                    void (*delFunc)(id, SEL, id, void (^)(BOOL)) = (void (*)(id, SEL, id, void (^)(BOOL)))[gate methodForSelector:delInviteSel];
                    delFunc(gate, delInviteSel, meshId, ^(BOOL success){});
                }
            }
            Class meshSettings = objc_getClass("_TtC4Rave12MeshSettings");
            if (meshSettings) {
                id shared = [meshSettings valueForKey:@"shared"] ?: [[meshSettings alloc] init];
                SEL setPrivacy = NSSelectorFromString(@"setPrivacyMode:");
                if (shared && [shared respondsToSelector:setPrivacy]) {
                    ((void (*)(id, SEL, NSInteger))objc_msgSend)(shared, setPrivacy, 2 /* Private */);
                }
            }
            [[RaveApexMenuUI sharedInstance] showToast:@"🔒 Room Lockdown Enforced"];
        } @catch (NSException *e) {
            [[RaveApexMenuUI sharedInstance] showToast:@"⚠️ Lockdown error"];
        }
    }];

    // Crown Seizure: Force Leader authority across view models & repaint crown badge
    [[NSNotificationCenter defaultCenter] addObserverForName:@"RaveApexCrownSeizureNotification"
                                                      object:nil queue:[NSOperationQueue mainQueue]
                                                  usingBlock:^(NSNotification * _Nonnull note) {
        @try {
            [RaveApexConfig sharedConfig].crownSpoofEnabled = YES;
            [RaveApexConfig sharedConfig].omniLeaderElevationEnabled = YES;
            [RaveApexConfig sharedConfig].phantomCrownLockEnabled = YES;
            [[RaveApexConfig sharedConfig] save];

            Class meshSettings = objc_getClass("_TtC4Rave12MeshSettings");
            if (meshSettings) {
                id shared = [meshSettings valueForKey:@"shared"] ?: [[meshSettings alloc] init];
                SEL crownSel = NSSelectorFromString(@"setupCrown");
                if (shared && [shared respondsToSelector:crownSel]) {
                    ((void (*)(id, SEL))objc_msgSend)(shared, crownSel);
                }
                SEL leaderLbl = NSSelectorFromString(@"leaderLabel");
                if (shared && [shared respondsToSelector:leaderLbl]) {
                    id lbl = ((id (*)(id, SEL))objc_msgSend)(shared, leaderLbl);
                    if (lbl && [lbl respondsToSelector:NSSelectorFromString(@"setText:")]) {
                        ((void (*)(id, SEL, id))objc_msgSend)(lbl, NSSelectorFromString(@"setText:"), @"👑 APEX SOVEREIGN");
                    }
                }
            }
            [[RaveApexMenuUI sharedInstance] showToast:@"👑 Sovereign Crown Seized!"];
        } @catch (NSException *e) {
            [[RaveApexMenuUI sharedInstance] showToast:@"⚠️ Crown seizure failed"];
        }
    }];

    // Sonic Jammer: 12x rapid-fire VoIP SFX burst packets
    [[NSNotificationCenter defaultCenter] addObserverForName:@"RaveApexSonicJammerNotification"
                                                      object:nil queue:[NSOperationQueue mainQueue]
                                                  usingBlock:^(NSNotification * _Nonnull note) {
        Class voipMgr = objc_getClass("_TtC4Rave11VoipManager");
        if (!voipMgr) return;
        for (int i = 0; i < 12; i++) {
            dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(i * 0.15 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
                @try {
                    id shared = [voipMgr valueForKey:@"shared"];
                    if (!shared) return;
                    id player = (i % 2 == 0) ? [shared valueForKey:@"beepPlayer"] : [shared valueForKey:@"boopPlayer"];
                    SEL playSel = NSSelectorFromString(@"play");
                    if (player && [player respondsToSelector:playSel]) {
                        ((void (*)(id, SEL))objc_msgSend)(player, playSel);
                    }
                } @catch (NSException *e) {
                    apex_log([[NSString stringWithFormat:@"[FAULT] SonicJammer: %@", e.reason] UTF8String]);
                }
            });
        }
        [[RaveApexMenuUI sharedInstance] showToast:@"📡 Sonic Jammer Transmitting (x12)"];
    }];

    // Desync Tornado: Rapidly oscillate syncOffset to desync remote clients
    [[NSNotificationCenter defaultCenter] addObserverForName:@"RaveApexDesyncTornadoNotification"
                                                      object:nil queue:[NSOperationQueue mainQueue]
                                                   usingBlock:^(NSNotification * _Nonnull note) {
        Class syncMgr = objc_getClass("_TtC4Rave11SyncManager");
        if (!syncMgr) return;
        NSArray<NSNumber *> *offsets = @[@(-2.5), @(3.0), @(-1.8), @(2.2), @(0.0)];
        for (NSUInteger i = 0; i < offsets.count; i++) {
            dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(i * 0.6 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
                @try {
                    id shared = [syncMgr valueForKey:@"shared"];
                    if (shared) {
                        [shared setValue:offsets[i] forKey:@"syncOffset"];
                    }
                } @catch (NSException *e) {
                    apex_log([[NSString stringWithFormat:@"[FAULT] DesyncTornado: %@", e.reason] UTF8String]);
                }
            });
        }
        [[RaveApexMenuUI sharedInstance] showToast:@"🌀 Desync Tornado Active (+/-3s)"];
    }];

    // Reaction Flood: Staggered 10x like button pulse
    [[NSNotificationCenter defaultCenter] addObserverForName:@"RaveApexReactionFloodNotification"
                                                      object:nil queue:[NSOperationQueue mainQueue]
                                                   usingBlock:^(NSNotification * _Nonnull note) {
        id vp = apex_find_active_video_player();
        if (!vp) {
            [[RaveApexMenuUI sharedInstance] showToast:@"⚠️ Video player not mounted"];
            return;
        }
        for (int i = 0; i < 10; i++) {
            dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(i * 0.12 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
                @try {
                    id activeVp = apex_find_active_video_player();
                    if (activeVp) {
                        SEL likeSel = NSSelectorFromString(@"likeButtonPressed:");
                        if ([activeVp respondsToSelector:likeSel]) {
                            ((void (*)(id, SEL, id))objc_msgSend)(activeVp, likeSel, nil);
                        }
                    }
                } @catch (NSException *e) {
                    apex_log([[NSString stringWithFormat:@"[FAULT] ReactionFlood: %@", e.reason] UTF8String]);
                }
            });
        }
        [[RaveApexMenuUI sharedInstance] showToast:@"🌊 Reaction Flood: 10 Likes Sent"];
    }];

    // Stream Sniffer: Extract and copy active video stream URL / manifest
    [[NSNotificationCenter defaultCenter] addObserverForName:@"RaveApexSniffStreamNotification"
                                                      object:nil queue:[NSOperationQueue mainQueue]
                                                  usingBlock:^(NSNotification * _Nonnull note) {
        @try {
            id vp = apex_find_active_video_player();
            NSString *urlStr = nil;
            if (vp) {
                SEL assetSel = NSSelectorFromString(@"playerAsset");
                if ([vp respondsToSelector:assetSel]) {
                    id asset = ((id (*)(id, SEL))objc_msgSend)(vp, assetSel);
                    if (asset) {
                        if ([asset respondsToSelector:NSSelectorFromString(@"url")]) {
                            id u = [asset valueForKey:@"url"];
                            if (u) urlStr = [u description];
                        }
                        if (!urlStr && [asset respondsToSelector:NSSelectorFromString(@"mediaUrl")]) {
                            id u = [asset valueForKey:@"mediaUrl"];
                            if (u) urlStr = [u description];
                        }
                    }
                }
                if (!urlStr) {
                    id avp = apex_find_av_player(vp);
                    if (avp && [avp respondsToSelector:NSSelectorFromString(@"currentItem")]) {
                        id item = ((id (*)(id, SEL))objc_msgSend)(avp, NSSelectorFromString(@"currentItem"));
                        if (item && [item respondsToSelector:NSSelectorFromString(@"asset")]) {
                            id avAsset = ((id (*)(id, SEL))objc_msgSend)(item, NSSelectorFromString(@"asset"));
                            if (avAsset && [avAsset respondsToSelector:NSSelectorFromString(@"URL")]) {
                                id u = ((id (*)(id, SEL))objc_msgSend)(avAsset, NSSelectorFromString(@"URL"));
                                if (u) urlStr = [u description];
                            }
                        }
                    }
                }
            }
            if (urlStr && urlStr.length > 0) {
                Class pasteboardCls = objc_getClass("UIPasteboard");
                if (pasteboardCls) {
                    id pb = [pasteboardCls valueForKey:@"generalPasteboard"];
                    if (pb && [pb respondsToSelector:NSSelectorFromString(@"setString:")]) {
                        ((void (*)(id, SEL, id))objc_msgSend)(pb, NSSelectorFromString(@"setString:"), urlStr);
                    }
                }
                apex_log([[NSString stringWithFormat:@"[SNIFFER] Captured stream URL: %@", urlStr] UTF8String]);
                [[RaveApexMenuUI sharedInstance] showToast:@"🎬 Stream URL Copied!"];
            } else {
                [[RaveApexMenuUI sharedInstance] showToast:@"⚠️ No active stream detected"];
            }
        } @catch (NSException *e) {
            apex_log([[NSString stringWithFormat:@"[FAULT] SniffStream: %@", e.reason] UTF8String]);
        }
    }];

    // Chat Flooder / Rapid Signaling Burst
    [[NSNotificationCenter defaultCenter] addObserverForName:@"RaveApexChatFlooderNotification"
                                                      object:nil queue:[NSOperationQueue mainQueue]
                                                  usingBlock:^(NSNotification * _Nonnull note) {
        @try {
            Class roomCls = objc_getClass("_TtC4Rave10RoomClient");
            id room = roomCls ? [roomCls valueForKey:@"shared"] : nil;
            NSString *floodText = @"⚡ Rave Apex Sovereign Engine Active";
            for (int i = 0; i < 5; i++) {
                dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(i * 0.20 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
                    @try {
                        SEL typingSel = NSSelectorFromString(@"sendMeshTypingState:meshUserTypingState:completion:");
                        if (room && [room respondsToSelector:typingSel]) {
                            void (*typeFn)(id, SEL, NSInteger, NSInteger, void (^)(BOOL)) = (void (*)(id, SEL, NSInteger, NSInteger, void (^)(BOOL)))[room methodForSelector:typingSel];
                            typeFn(room, typingSel, 1, 1, ^(BOOL b){});
                        }
                        id vp = apex_find_active_video_player();
                        if (vp && [vp respondsToSelector:NSSelectorFromString(@"likeButtonPressed:")]) {
                            ((void (*)(id, SEL, id))objc_msgSend)(vp, NSSelectorFromString(@"likeButtonPressed:"), nil);
                        }
                    } @catch (NSException *e) {
                        apex_log([[NSString stringWithFormat:@"[FAULT] ChatFlooderPacket: %@", e.reason] UTF8String]);
                    }
                });
            }
            Class pbCls = objc_getClass("UIPasteboard");
            if (pbCls) {
                id pb = [pbCls valueForKey:@"generalPasteboard"];
                if (pb && [pb respondsToSelector:NSSelectorFromString(@"setString:")]) {
                    ((void (*)(id, SEL, id))objc_msgSend)(pb, NSSelectorFromString(@"setString:"), floodText);
                }
            }
            [[RaveApexMenuUI sharedInstance] showToast:@"⚡ Flooder Sent (x5 Packets + Clipboard)"];
        } @catch (NSException *e) {
            apex_log([[NSString stringWithFormat:@"[FAULT] ChatFlooder: %@", e.reason] UTF8String]);
        }
    }];

    // Fake System Announcement Broadcast
    [[NSNotificationCenter defaultCenter] addObserverForName:@"RaveApexFakeSystemMessageNotification"
                                                      object:nil queue:[NSOperationQueue mainQueue]
                                                  usingBlock:^(NSNotification * _Nonnull note) {
        static int s_msgIdx = 0;
        NSArray<NSString *> *spoofs = @[
            @"👑 System: Apex Sovereign seized Host Leadership",
            @"🔒 Room Guard: Participant eviction immunity active",
            @"🛡️ VIP Verified: Premium lossless audio master armed",
            @"⚡ Mesh Arbiter: Zero-drift clock synchronizer locked"
        ];
        NSString *msg = spoofs[s_msgIdx % spoofs.count];
        s_msgIdx++;
        [[RaveApexMenuUI sharedInstance] showToast:msg];
        apex_log([[NSString stringWithFormat:@"[FAKE_SYS_MSG] Broadcast: %@", msg] UTF8String]);
    }];

    // Auto-Rejoin Room Interceptor
    [[NSNotificationCenter defaultCenter] addObserverForName:@"RaveApexAutoRejoinNotification"
                                                      object:nil queue:[NSOperationQueue mainQueue]
                                                  usingBlock:^(NSNotification * _Nonnull note) {
        @try {
            Class roomCls = objc_getClass("_TtC4Rave10RoomClient");
            if (roomCls) {
                id room = [roomCls valueForKey:@"shared"];
                if (room) {
                    SEL recSel = NSSelectorFromString(@"reconnect");
                    if ([room respondsToSelector:recSel]) {
                        ((void (*)(id, SEL))objc_msgSend)(room, recSel);
                        apex_log("[AutoRejoin] Dispatched room reconnect sequence.");
                        [[RaveApexMenuUI sharedInstance] showToast:@"🔄 Auto-Rejoin Dispatched"];
                    }
                }
            }
        } @catch (NSException *e) {
            apex_log([[NSString stringWithFormat:@"[FAULT] AutoRejoin: %@", e.reason] UTF8String]);
        }
    }];

    // Background Auto-PiP Trigger
    [[NSNotificationCenter defaultCenter] addObserverForName:@"UIApplicationDidEnterBackgroundNotification"
                                                      object:nil queue:[NSOperationQueue mainQueue]
                                                  usingBlock:^(NSNotification * _Nonnull note) {
        if ([RaveApexConfig sharedConfig].autoPiPOnBackground && [RaveApexConfig sharedConfig].forcePiPEnabled) {
            apex_trigger_pip();
        }
    }];

    // Video Auto-Loop: Seamlessly seek to 0 and resume on finish
    [[NSNotificationCenter defaultCenter] addObserverForName:@"AVPlayerItemDidPlayToEndTimeNotification"
                                                      object:nil queue:[NSOperationQueue mainQueue]
                                                  usingBlock:^(NSNotification * _Nonnull note) {
        if ([RaveApexConfig sharedConfig].autoLoopPlaybackEnabled) {
            @try {
                id vp = apex_find_active_video_player();
                if (vp) {
                    apex_seek_player_delta(-999999.0);
                    SEL resumeSel = NSSelectorFromString(@"playResumed");
                    if ([vp respondsToSelector:resumeSel]) {
                        ((void (*)(id, SEL))objc_msgSend)(vp, resumeSel);
                    }
                    id avp = apex_find_av_player(vp);
                    if (avp && [avp respondsToSelector:NSSelectorFromString(@"play")]) {
                        ((void (*)(id, SEL))objc_msgSend)(avp, NSSelectorFromString(@"play"));
                    }
                    apex_log("[AutoLoop] Replayed video from start seamlessly.");
                    [[RaveApexMenuUI sharedInstance] showToast:@"🔄 Video Auto-Looped"];
                }
            } @catch (NSException *e) {
                apex_log([[NSString stringWithFormat:@"[FAULT] AutoLoop: %@", e.reason] UTF8String]);
            }
        }
    }];

    // Toggle Play / Pause Stream
    [[NSNotificationCenter defaultCenter] addObserverForName:@"RaveApexTogglePlayPauseNotification"
                                                      object:nil queue:[NSOperationQueue mainQueue]
                                                  usingBlock:^(NSNotification * _Nonnull note) {
        apex_toggle_play_pause();
    }];

    // Toggle Room Privacy (Public <-> Private)
    [[NSNotificationCenter defaultCenter] addObserverForName:@"RaveApexToggleRoomPrivacyNotification"
                                                      object:nil queue:[NSOperationQueue mainQueue]
                                                  usingBlock:^(NSNotification * _Nonnull note) {
        apex_toggle_room_privacy();
        [[RaveApexMenuUI sharedInstance] showToast:@"🔒 Room Privacy Toggled"];
    }];

    // Discrete SFX Trigger
    [[NSNotificationCenter defaultCenter] addObserverForName:@"RaveApexDiscreteSFXNotification"
                                                      object:nil queue:[NSOperationQueue mainQueue]
                                                  usingBlock:^(NSNotification * _Nonnull note) {
        BOOL isBoop = [note.object boolValue];
        apex_trigger_discrete_sfx(isBoop);
        [[RaveApexMenuUI sharedInstance] showToast:isBoop ? @"🔊 Boop SFX Fired" : @"🔊 Beep SFX Fired"];
    }];

    // Turbo Preamp Booster (+1400% / 15.0x)
    [[NSNotificationCenter defaultCenter] addObserverForName:@"RaveApexTurboPreampNotification"
                                                      object:nil queue:[NSOperationQueue mainQueue]
                                                  usingBlock:^(NSNotification * _Nonnull note) {
        [RaveApexConfig sharedConfig].audioPreampVolume = 15.0f;
        [RaveApexConfig sharedConfig].audioPreampBoostEnabled = YES;
        [[RaveApexConfig sharedConfig] save];
        apex_apply_preamp_volume(15.0f);
        [[RaveApexMenuUI sharedInstance] showToast:@"💥 Turbo Preamp (15.0x / +1400%) Armed!"];
        apex_log("[TurboPreamp] Armed maximum 15.0x (+1400%) CoreAudio hardware gain.");
    }];

    // Mega-Preamp Overdrive (+2400% / 25.0x Extreme Boost)
    [[NSNotificationCenter defaultCenter] addObserverForName:@"RaveApexMegaPreampNotification"
                                                      object:nil queue:[NSOperationQueue mainQueue]
                                                  usingBlock:^(NSNotification * _Nonnull note) {
        [RaveApexConfig sharedConfig].audioPreampVolume = 25.0f;
        [RaveApexConfig sharedConfig].audioPreampBoostEnabled = YES;
        [RaveApexConfig sharedConfig].megaPreamp25xEnabled = YES;
        [[RaveApexConfig sharedConfig] save];
        apex_apply_preamp_volume(25.0f);
        [[RaveApexMenuUI sharedInstance] showToast:@"💥 Mega Preamp (25.0x / +2400%) Overdrive!"];
        apex_log("[MegaPreamp] Overdriven CoreAudio gain to 25.0x (+2400%).");
    }];

    // Ghost Invisibility Cloak Toggle
    [[NSNotificationCenter defaultCenter] addObserverForName:@"RaveApexGhostCloakNotification"
                                                      object:nil queue:[NSOperationQueue mainQueue]
                                                  usingBlock:^(NSNotification * _Nonnull note) {
        BOOL current = [RaveApexConfig sharedConfig].ghostPresenceEnabled;
        [RaveApexConfig sharedConfig].ghostPresenceEnabled = !current;
        [RaveApexConfig sharedConfig].stealthGhostListenerEnabled = !current;
        [[RaveApexConfig sharedConfig] save];
        NSString *status = !current ? @"👻 Ghost Cloak: INVISIBLE (Anti-Presence ON)" : @"👻 Ghost Cloak: OFF";
        [[RaveApexMenuUI sharedInstance] showToast:status];
        apex_log([[NSString stringWithFormat:@"[GhostCloak] State: %d", !current] UTF8String]);
    }];

    // Chat Anti-Recall & Undelete Sniffer
    [[NSNotificationCenter defaultCenter] addObserverForName:@"RaveApexAntiRecallNotification"
                                                      object:nil queue:[NSOperationQueue mainQueue]
                                                  usingBlock:^(NSNotification * _Nonnull note) {
        BOOL current = [RaveApexConfig sharedConfig].antiRecallChatEnabled;
        [RaveApexConfig sharedConfig].antiRecallChatEnabled = !current;
        [[RaveApexConfig sharedConfig] save];
        NSString *status = !current ? @"👁️ Chat Anti-Recall: ARMED (Retain Deleted)" : @"👁️ Chat Anti-Recall: OFF";
        [[RaveApexMenuUI sharedInstance] showToast:status];
        apex_log([[NSString stringWithFormat:@"[AntiRecall] State: %d", !current] UTF8String]);
    }];

    // Mute Invalidation & Continuous Mic Lock
    [[NSNotificationCenter defaultCenter] addObserverForName:@"RaveApexMicLockNotification"
                                                      object:nil queue:[NSOperationQueue mainQueue]
                                                  usingBlock:^(NSNotification * _Nonnull note) {
        BOOL current = [RaveApexConfig sharedConfig].micLockAlwaysOn;
        [RaveApexConfig sharedConfig].micLockAlwaysOn = !current;
        [RaveApexConfig sharedConfig].forceMicTransmissionEnabled = !current;
        [[RaveApexConfig sharedConfig] save];
        @try {
            Class voipMgr = objc_getClass("_TtC4Rave11VoipManager");
            if (voipMgr) {
                id shared = [voipMgr valueForKey:@"shared"];
                if (shared && [shared respondsToSelector:NSSelectorFromString(@"setMicEnabled:")]) {
                    ((void (*)(id, SEL, BOOL))objc_msgSend)(shared, NSSelectorFromString(@"setMicEnabled:"), YES);
                }
            }
        } @catch (NSException *e) {
            apex_log([[NSString stringWithFormat:@"[FAULT] MicLock: %@", e.reason] UTF8String]);
        }
        NSString *status = !current ? @"🎙️ Mic Lock: UNMUTABLE (Continuous Voice ON)" : @"🎙️ Mic Lock: OFF";
        [[RaveApexMenuUI sharedInstance] showToast:status];
        apex_log([[NSString stringWithFormat:@"[MicLock] State: %d", !current] UTF8String]);
    }];

    // Ping Spoofer Matrix (Cycle: Normal -> 0ms -> 9999ms)
    [[NSNotificationCenter defaultCenter] addObserverForName:@"RaveApexPingSpoofCycleNotification"
                                                      object:nil queue:[NSOperationQueue mainQueue]
                                                  usingBlock:^(NSNotification * _Nonnull note) {
        NSInteger mode = [RaveApexConfig sharedConfig].pingSpoofMode;
        mode = (mode + 1) % 3;
        [RaveApexConfig sharedConfig].pingSpoofMode = mode;
        [RaveApexConfig sharedConfig].pingSpoofEnabled = (mode != 0);
        [[RaveApexConfig sharedConfig] save];
        NSString *toast = (mode == 1) ? @"⚡ Ping: 0.0ms (God Ping Locked)" :
                          (mode == 2) ? @"⚡ Ping: 9999ms (Fake Lag-Switch Armed)" :
                                        @"⚡ Ping: Normal (Real Latency)";
        [[RaveApexMenuUI sharedInstance] showToast:toast];
        apex_log([[NSString stringWithFormat:@"[PingSpoof] Mode: %ld", (long)mode] UTF8String]);
    }];

    // Sonic Jammer Ultra (x24 Rapid VoIP SFX Storm)
    [[NSNotificationCenter defaultCenter] addObserverForName:@"RaveApexSonicJammerUltraNotification"
                                                      object:nil queue:[NSOperationQueue mainQueue]
                                                  usingBlock:^(NSNotification * _Nonnull note) {
        Class voipMgr = objc_getClass("_TtC4Rave11VoipManager");
        if (!voipMgr) return;
        for (int i = 0; i < 24; i++) {
            dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(i * 0.08 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
                @try {
                    id shared = [voipMgr valueForKey:@"shared"];
                    if (!shared) return;
                    id player = (i % 2 == 0) ? [shared valueForKey:@"beepPlayer"] : [shared valueForKey:@"boopPlayer"];
                    SEL playSel = NSSelectorFromString(@"play");
                    if (player && [player respondsToSelector:playSel]) {
                        ((void (*)(id, SEL))objc_msgSend)(player, playSel);
                    }
                } @catch (NSException *e) {
                    apex_log([[NSString stringWithFormat:@"[FAULT] SonicJammerUltra: %@", e.reason] UTF8String]);
                }
            });
        }
        [[RaveApexMenuUI sharedInstance] showToast:@"📡 Sonic Jammer Ultra Transmitting (x24)"];
    }];

    // Desync Tornado 2.0 (+/-5.0s Temporal Warp)
    [[NSNotificationCenter defaultCenter] addObserverForName:@"RaveApexDesyncTornado5sNotification"
                                                      object:nil queue:[NSOperationQueue mainQueue]
                                                   usingBlock:^(NSNotification * _Nonnull note) {
        Class syncMgr = objc_getClass("_TtC4Rave11SyncManager");
        if (!syncMgr) return;
        NSArray<NSNumber *> *offsets = @[@(-5.0), @(5.0), @(-3.5), @(3.5), @(-1.5), @(0.0)];
        for (NSUInteger i = 0; i < offsets.count; i++) {
            dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(i * 0.40 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
                @try {
                    id shared = [syncMgr valueForKey:@"shared"];
                    if (shared) {
                        [shared setValue:offsets[i] forKey:@"syncOffset"];
                    }
                } @catch (NSException *e) {
                    apex_log([[NSString stringWithFormat:@"[FAULT] DesyncTornado5s: %@", e.reason] UTF8String]);
                }
            });
        }
        [[RaveApexMenuUI sharedInstance] showToast:@"🌀 Desync Tornado 2.0 Active (+/-5s)"];
    }];

    // Playback Poltergeist Extreme (x12 Rapid Strobe)
    [[NSNotificationCenter defaultCenter] addObserverForName:@"RaveApexPoltergeistExtremeNotification"
                                                      object:nil queue:[NSOperationQueue mainQueue]
                                                  usingBlock:^(NSNotification * _Nonnull note) {
        id vp = apex_find_active_video_player();
        if (!vp) return;
        for (int i = 0; i < 12; i++) {
            dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(i * 0.18 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
                @try {
                    id activeVp = apex_find_active_video_player();
                    if (!activeVp) return;
                    SEL sel = (i % 2 == 0) ? NSSelectorFromString(@"playPaused") : NSSelectorFromString(@"playResumed");
                    if ([activeVp respondsToSelector:sel]) ((void (*)(id, SEL))objc_msgSend)(activeVp, sel);
                } @catch (NSException *e) {
                    apex_log([[NSString stringWithFormat:@"[FAULT] PoltergeistExtreme: %@", e.reason] UTF8String]);
                }
            });
        }
        [[RaveApexMenuUI sharedInstance] showToast:@"⏯️ Poltergeist Extreme Active (x12)"];
    }];

    // Kamikaze Auto-Rejoin Loop (Instant Kick/Ban Eviction Re-entry)
    [[NSNotificationCenter defaultCenter] addObserverForName:@"RaveApexKamikazeRejoinNotification"
                                                      object:nil queue:[NSOperationQueue mainQueue]
                                                  usingBlock:^(NSNotification * _Nonnull note) {
        [RaveApexConfig sharedConfig].autoRejoinEnabled = YES;
        [RaveApexConfig sharedConfig].antiKickInterceptionEnabled = YES;
        [[RaveApexConfig sharedConfig] save];
        @try {
            Class roomCls = objc_getClass("_TtC4Rave10RoomClient");
            if (roomCls) {
                id room = [roomCls valueForKey:@"shared"];
                if (room && [room respondsToSelector:NSSelectorFromString(@"reconnect")]) {
                    ((void (*)(id, SEL))objc_msgSend)(room, NSSelectorFromString(@"reconnect"));
                }
            }
        } @catch (NSException *e) {
            apex_log([[NSString stringWithFormat:@"[FAULT] KamikazeRejoin: %@", e.reason] UTF8String]);
        }
        [[RaveApexMenuUI sharedInstance] showToast:@"🔄 Kamikaze Auto-Rejoin Armed (0.2s Loop)"];
    }];

    // Show Toast Generic Notification
    [[NSNotificationCenter defaultCenter] addObserverForName:@"RaveApexShowToastNotification"
                                                      object:nil queue:[NSOperationQueue mainQueue]
                                                  usingBlock:^(NSNotification * _Nonnull note) {
        if ([note.object isKindOfClass:[NSString class]]) {
            [[RaveApexMenuUI sharedInstance] showToast:(NSString *)note.object];
        }
    }];

    // 30.0x Mega-Preamp Overdrive (+2900% Gain)
    [[NSNotificationCenter defaultCenter] addObserverForName:@"RaveApexMegaPreamp30xNotification"
                                                      object:nil queue:[NSOperationQueue mainQueue]
                                                  usingBlock:^(NSNotification * _Nonnull note) {
        [RaveApexConfig sharedConfig].megaPreamp30xEnabled = YES;
        [RaveApexConfig sharedConfig].audioPreampBoostEnabled = YES;
        [RaveApexConfig sharedConfig].audioPreampVolume = 30.0f;
        [[RaveApexConfig sharedConfig] save];
        apex_apply_preamp_volume(30.0f);
        [[RaveApexMenuUI sharedInstance] showToast:@"🔊 30.0x MEGA-PREAMP OVERDRIVE (+2900%)!"];
        apex_log("[Preamp] Overdrive 30.0x engaged.");
    }];

    // Kick Reflector Toggle
    [[NSNotificationCenter defaultCenter] addObserverForName:@"RaveApexKickReflectorNotification"
                                                      object:nil queue:[NSOperationQueue mainQueue]
                                                  usingBlock:^(NSNotification * _Nonnull note) {
        BOOL cur = [RaveApexConfig sharedConfig].kickReflectorEnabled;
        [RaveApexConfig sharedConfig].kickReflectorEnabled = !cur;
        [RaveApexConfig sharedConfig].antiKickInterceptionEnabled = YES;
        [[RaveApexConfig sharedConfig] save];
        NSString *msg = !cur ? @"🛡️ Kick Reflector: ARMED (Eviction Counter-Strike ON)" : @"🛡️ Kick Reflector: OFF";
        [[RaveApexMenuUI sharedInstance] showToast:msg];
        apex_log([[NSString stringWithFormat:@"[KickReflector] State: %d", !cur] UTF8String]);
    }];

    // Phantom Identity Camouflage Scrambler
    [[NSNotificationCenter defaultCenter] addObserverForName:@"RaveApexPhantomIdCamouflageNotification"
                                                      object:nil queue:[NSOperationQueue mainQueue]
                                                  usingBlock:^(NSNotification * _Nonnull note) {
        [RaveApexConfig sharedConfig].phantomIdentityCamouflageEnabled = YES;
        [[RaveApexConfig sharedConfig] save];
        apex_randomize_phantom_identity();
    }];

    // Vocal Pitch Shift Preset Cycle
    [[NSNotificationCenter defaultCenter] addObserverForName:@"RaveApexVocalPitchShiftCycleNotification"
                                                      object:nil queue:[NSOperationQueue mainQueue]
                                                  usingBlock:^(NSNotification * _Nonnull note) {
        NSInteger cur = [RaveApexConfig sharedConfig].vocalPitchShiftPreset;
        cur = (cur + 1) % 4;
        apex_apply_vocal_pitch_preset(cur);
    }];

    // Ultra Bassquake DSP Resonance Boost
    [[NSNotificationCenter defaultCenter] addObserverForName:@"RaveApexUltraBassquakeNotification"
                                                      object:nil queue:[NSOperationQueue mainQueue]
                                                  usingBlock:^(NSNotification * _Nonnull note) {
        BOOL cur = [RaveApexConfig sharedConfig].ultraBassquakeEnabled;
        [RaveApexConfig sharedConfig].ultraBassquakeEnabled = !cur;
        if (!cur) [RaveApexConfig sharedConfig].audioEqPreset = 1; // Bass Boost
        [[RaveApexConfig sharedConfig] save];
        NSString *msg = !cur ? @"🔊 Ultra Bassquake: OVERDRIVE (+12dB Low-End)" : @"🔊 Ultra Bassquake: OFF";
        [[RaveApexMenuUI sharedInstance] showToast:msg];
        apex_log([[NSString stringWithFormat:@"[Bassquake] State: %d", !cur] UTF8String]);
    }];

    // Anti-AFK Immortalizer
    [[NSNotificationCenter defaultCenter] addObserverForName:@"RaveApexAntiAfkNotification"
                                                      object:nil queue:[NSOperationQueue mainQueue]
                                                  usingBlock:^(NSNotification * _Nonnull note) {
        BOOL cur = [RaveApexConfig sharedConfig].antiAfkImmortalizerEnabled;
        apex_toggle_anti_afk(!cur);
    }];

    // Vote Hijacker Auto-Pass
    [[NSNotificationCenter defaultCenter] addObserverForName:@"RaveApexVoteHijackerNotification"
                                                      object:nil queue:[NSOperationQueue mainQueue]
                                                  usingBlock:^(NSNotification * _Nonnull note) {
        apex_toggle_vote_hijacker();
    }];

    // Stream Sniffer & Clipboard Copier
    [[NSNotificationCenter defaultCenter] addObserverForName:@"RaveApexStreamSnifferNotification"
                                                      object:nil queue:[NSOperationQueue mainQueue]
                                                  usingBlock:^(NSNotification * _Nonnull note) {
        apex_sniff_and_copy_stream_url();
    }];

    // Precision Frame Step
    [[NSNotificationCenter defaultCenter] addObserverForName:@"RaveApexFrameStepNotification"
                                                      object:nil queue:[NSOperationQueue mainQueue]
                                                  usingBlock:^(NSNotification * _Nonnull note) {
        NSInteger delta = [note.object respondsToSelector:@selector(integerValue)] ? [((NSNumber *)note.object) integerValue] : 1;
        apex_step_frame_delta(delta);
        [[RaveApexMenuUI sharedInstance] showToast:[NSString stringWithFormat:@"🎞️ Frame %s1", (delta > 0 ? "+" : "")]];
    }];

    // Percentage Jump (25% / 50% / 75%)
    [[NSNotificationCenter defaultCenter] addObserverForName:@"RaveApexJumpPercentNotification"
                                                      object:nil queue:[NSOperationQueue mainQueue]
                                                  usingBlock:^(NSNotification * _Nonnull note) {
        double pct = [note.object respondsToSelector:@selector(doubleValue)] ? [((NSNumber *)note.object) doubleValue] : 0.5;
        apex_jump_percentage(pct);
        [[RaveApexMenuUI sharedInstance] showToast:[NSString stringWithFormat:@"⏩ Jumped to %.0f%%", pct * 100.0]];
    }];

    // Sonic Jammer 32x Barrage
    [[NSNotificationCenter defaultCenter] addObserverForName:@"RaveApexSonicJammer32xNotification"
                                                      object:nil queue:[NSOperationQueue mainQueue]
                                                  usingBlock:^(NSNotification * _Nonnull note) {
        apex_trigger_sfx_barrage_ultra(32);
        [[RaveApexMenuUI sharedInstance] showToast:@"📡 Sonic Jammer Super-Storm (x32 SFX)"];
    }];

    // ==============================================================================
    // RED-TEAM COMBAT SUITE HANDLERS (TRACKS 1-3)
    // ==============================================================================

    // Track 1: Quantum Ghost Presence & WebRTC Identity Cloak
    [[NSNotificationCenter defaultCenter] addObserverForName:@"RaveApexQuantumGhostNotification"
                                                      object:nil queue:[NSOperationQueue mainQueue]
                                                  usingBlock:^(NSNotification * _Nonnull note) {
        BOOL cur = [RaveApexConfig sharedConfig].quantumGhostPresenceEnabled;
        apex_toggle_quantum_ghost(!cur);
    }];

    // Track 2: Stealth Audio Snooper (+400% Incoming PCM Gain)
    [[NSNotificationCenter defaultCenter] addObserverForName:@"RaveApexAudioSnooperNotification"
                                                      object:nil queue:[NSOperationQueue mainQueue]
                                                  usingBlock:^(NSNotification * _Nonnull note) {
        BOOL cur = [RaveApexConfig sharedConfig].stealthAudioSnooperEnabled;
        apex_toggle_audio_snooper(!cur);
    }];

    // Track 3A: Eviction Reflector 2.0 (Instigator Counter-Strike)
    [[NSNotificationCenter defaultCenter] addObserverForName:@"RaveApexEvictionReflector2Notification"
                                                      object:nil queue:[NSOperationQueue mainQueue]
                                                  usingBlock:^(NSNotification * _Nonnull note) {
        apex_trigger_eviction_reflector_2();
    }];

    // Track 3B: Room Freeze Strobe (Temporal Jitter Strobe)
    [[NSNotificationCenter defaultCenter] addObserverForName:@"RaveApexRoomFreezeStrobeNotification"
                                                      object:nil queue:[NSOperationQueue mainQueue]
                                                  usingBlock:^(NSNotification * _Nonnull note) {
        apex_trigger_room_freeze_strobe();
    }];

    // Participant X-Ray: enumerate the room roster and dump to the Apex Log.
    [[NSNotificationCenter defaultCenter] addObserverForName:@"RaveApexParticipantXrayNotification"
                                                      object:nil queue:[NSOperationQueue mainQueue]
                                                  usingBlock:^(NSNotification * _Nonnull note) {
        @try {
            apex_log("[X-RAY] ==== ROOM PARTICIPANT SCAN ====");
            int found = 0;
            for (NSString *cn in @[@"_TtC4Rave11VoipManager", @"_TtC4Rave10RoomClient"]) {
                Class cls = objc_getClass([cn UTF8String]);
                if (!cls) continue;
                id shared = nil;
                @try {
                    if ([cls respondsToSelector:NSSelectorFromString(@"shared")]) {
                        shared = ((id (*)(id, SEL))objc_msgSend)(cls, NSSelectorFromString(@"shared"));
                    } else {
                        shared = [cls valueForKey:@"shared"];
                    }
                } @catch (NSException *e) {
                    apex_log([[NSString stringWithFormat:@"[X-RAY] shared lookup skipped on %@: %@", cn, e.reason] UTF8String]);
                    shared = nil;
                }
                if (!shared) continue;
                for (NSString *k in @[@"participants", @"talkingUsers", @"users", @"members", @"peers"]) {
                    id arr = nil;
                    @try { arr = [shared valueForKey:k]; } @catch (NSException *e) { arr = nil; }
                    if ([arr isKindOfClass:[NSArray class]] && [(NSArray *)arr count] > 0) {
                        NSArray *snapshot = [(NSArray *)arr copy];
                        apex_log([[NSString stringWithFormat:@"[X-RAY] %@.%@ (%lu):", cn, k, (unsigned long)snapshot.count] UTF8String]);
                        for (id u in snapshot) {
                            NSMutableString *line = [NSMutableString stringWithString:@"   • "];
                            for (NSString *prop in @[@"displayName", @"name", @"username", @"userId", @"meshUserId", @"muted", @"micDisabled", @"isLeader"]) {
                                @try {
                                    if ([u respondsToSelector:NSSelectorFromString(prop)]) {
                                        id v = [u valueForKey:prop];
                                        if (v) [line appendFormat:@"%@=%@  ", prop, v];
                                    }
                                } @catch (NSException *e) {
                                    apex_log([[NSString stringWithFormat:@"[X-RAY] prop %@ fault: %@", prop, e.reason] UTF8String]);
                                }
                            }
                            apex_log([line UTF8String]);
                            found++;
                        }
                    }
                }
            }
            if (found == 0) apex_log("[X-RAY] No roster exposed (join a room first).");
            apex_log("[X-RAY] ==== END SCAN ====");
            [[RaveApexMenuUI sharedInstance] showToast:[NSString stringWithFormat:@"🩻 X-Ray: %d users logged", found]];
        } @catch (NSException *e) {
            apex_log([[NSString stringWithFormat:@"[FAULT] X-Ray: %@", e.reason] UTF8String]);
        }
    }];

    // Copy Room Invite & Mesh ID to clipboard.
    [[NSNotificationCenter defaultCenter] addObserverForName:@"RaveApexCopyInviteNotification"
                                                      object:nil queue:[NSOperationQueue mainQueue]
                                                  usingBlock:^(NSNotification * _Nonnull note) {
        @try {
            NSString *meshId = nil;
            for (NSString *cn in @[@"_TtC4Rave10RoomClient", @"_TtC4Rave11VoipManager", @"_TtC4Rave12MeshSettings"]) {
                Class cls = objc_getClass([cn UTF8String]);
                if (!cls) continue;
                id shared = nil;
                @try {
                    if ([cls respondsToSelector:NSSelectorFromString(@"shared")]) {
                        shared = ((id (*)(id, SEL))objc_msgSend)(cls, NSSelectorFromString(@"shared"));
                    } else {
                        shared = [cls valueForKey:@"shared"];
                    }
                } @catch (NSException *e) {
                    apex_log([[NSString stringWithFormat:@"[INVITE] shared lookup skipped on %@: %@", cn, e.reason] UTF8String]);
                    shared = nil;
                }
                if (!shared) continue;
                for (NSString *k in @[@"meshId", @"currentMeshId", @"roomId", @"meshUserId"]) {
                    @try {
                        if ([shared respondsToSelector:NSSelectorFromString(k)]) {
                            id v = [shared valueForKey:k];
                            if (v && [[v description] length] > 0) { meshId = [v description]; break; }
                        }
                    } @catch (NSException *e) {
                        apex_log([[NSString stringWithFormat:@"[INVITE] key %@ fault: %@", k, e.reason] UTF8String]);
                    }
                }
                if (meshId) break;
            }
            if (!meshId) meshId = [RaveApexConfig sharedConfig].lastKnownMeshId;
            NSString *payload = meshId && meshId.length > 0
                ? [NSString stringWithFormat:@"https://rave.io/%@  (mesh: %@)", meshId, meshId]
                : @"(no active room — join one first)";
            Class pbCls = objc_getClass("UIPasteboard");
            if (pbCls) {
                id pb = [pbCls valueForKey:@"generalPasteboard"];
                if (pb && [pb respondsToSelector:NSSelectorFromString(@"setString:")]) {
                    ((void (*)(id, SEL, id))objc_msgSend)(pb, NSSelectorFromString(@"setString:"), payload);
                }
            }
            apex_log([[NSString stringWithFormat:@"[INVITE] %@", payload] UTF8String]);
            [[RaveApexMenuUI sharedInstance] showToast:(meshId.length > 0 ? @"🔗 Invite copied!" : @"⚠️ No active room")];
        } @catch (NSException *e) {
            apex_log([[NSString stringWithFormat:@"[FAULT] CopyInvite: %@", e.reason] UTF8String]);
        }
    }];

    // ==============================================================================
    // FRANKB EXTREME TROLL & PRANK EXPANSION HANDLERS
    // ==============================================================================

    // Voice Chopper Strobe: Rapidly toggle mute/unmute 10x across talking users (helicopter voice)
    [[NSNotificationCenter defaultCenter] addObserverForName:@"RaveApexVoiceChopperNotification"
                                                      object:nil queue:[NSOperationQueue mainQueue]
                                                  usingBlock:^(NSNotification * _Nonnull note) {
        for (int i = 0; i < 10; i++) {
            dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(i * 0.18 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
                @try {
                    Class roomCls = objc_getClass("_TtC4Rave10RoomClient");
                    Class gateCls = objc_getClass("_TtC4Rave10GateKeeper");
                    if (!roomCls || !gateCls) return;
                    id room = [roomCls valueForKey:@"shared"];
                    id gate = [gateCls valueForKey:@"shared"] ?: [[gateCls alloc] init];
                    id talking = room ? [room valueForKey:@"talkingUsers"] : nil;
                    if ([talking respondsToSelector:NSSelectorFromString(@"allObjects")]) {
                        talking = ((id (*)(id, SEL))objc_msgSend)(talking, NSSelectorFromString(@"allObjects"));
                    }
                    SEL muteSel = NSSelectorFromString(@"muteOrUnmuteUser:meshId:userId:");
                    if ([talking isKindOfClass:[NSArray class]] && gate && [gate respondsToSelector:muteSel]) {
                        NSArray *snap = [(NSArray *)talking copy];
                        NSNumber *muteFlag = (i % 2 == 0) ? @YES : @NO;
                        for (id u in snap) {
                            ((void (*)(id, SEL, id, id, id))objc_msgSend)(gate, muteSel, muteFlag, @"current", u);
                        }
                    }
                } @catch (NSException *e) {
                    apex_log([[NSString stringWithFormat:@"[FAULT] VoiceChopper: %@", e.reason] UTF8String]);
                }
            });
        }
        apex_log("[TROLL] Voice Chopper Strobe (10x mute/unmute helicopter) launched.");
        [[RaveApexMenuUI sharedInstance] showToast:@"🚁 Voice Chopper Strobe (x10)!"];
    }];

    // Crown Roulette: Rapidly cycle crown spoof & leader badge 8x
    [[NSNotificationCenter defaultCenter] addObserverForName:@"RaveApexCrownRouletteNotification"
                                                      object:nil queue:[NSOperationQueue mainQueue]
                                                  usingBlock:^(NSNotification * _Nonnull note) {
        for (int i = 0; i < 8; i++) {
            dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(i * 0.25 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
                @try {
                    [RaveApexConfig sharedConfig].crownSpoofEnabled = (i % 2 == 0);
                    [RaveApexConfig sharedConfig].omniLeaderElevationEnabled = YES;
                    Class meshSettings = objc_getClass("_TtC4Rave12MeshSettings");
                    if (meshSettings) {
                        id shared = [meshSettings valueForKey:@"shared"] ?: [[meshSettings alloc] init];
                        SEL crownSel = NSSelectorFromString(@"setupCrown");
                        if (shared && [shared respondsToSelector:crownSel]) {
                            ((void (*)(id, SEL))objc_msgSend)(shared, crownSel);
                        }
                    }
                } @catch (NSException *e) {
                    apex_log([[NSString stringWithFormat:@"[FAULT] CrownRoulette: %@", e.reason] UTF8String]);
                }
            });
        }
        apex_log("[TROLL] Crown Roulette 8x strobe dispatched.");
        [[RaveApexMenuUI sharedInstance] showToast:@"🎰 Crown Roulette Strobe (x8)!"];
    }];

    // Groundhog Day Loop: Jump backwards -15s every 2.0s 6 times so the same clip repeats
    [[NSNotificationCenter defaultCenter] addObserverForName:@"RaveApexGroundhogDayNotification"
                                                      object:nil queue:[NSOperationQueue mainQueue]
                                                  usingBlock:^(NSNotification * _Nonnull note) {
        for (int i = 0; i < 6; i++) {
            dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(i * 2.0 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
                @try {
                    apex_seek_player_delta(-15.0);
                } @catch (NSException *e) {
                    apex_log([[NSString stringWithFormat:@"[FAULT] GroundhogDay: %@", e.reason] UTF8String]);
                }
            });
        }
        apex_log("[TROLL] Groundhog Day Loop (-15s x6) engaged.");
        [[RaveApexMenuUI sharedInstance] showToast:@"🔁 Groundhog Day Time Loop (x6)!"];
    }];

    // Rollercoaster Scrub: Random timeline percentage teleports x8
    [[NSNotificationCenter defaultCenter] addObserverForName:@"RaveApexRollercoasterScrubNotification"
                                                      object:nil queue:[NSOperationQueue mainQueue]
                                                  usingBlock:^(NSNotification * _Nonnull note) {
        NSArray<NSNumber *> *stops = @[@0.10, @0.85, @0.20, @0.92, @0.35, @0.75, @0.15, @0.50];
        for (NSUInteger i = 0; i < stops.count; i++) {
            dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(i * 0.45 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
                @try {
                    apex_jump_percentage([stops[i] doubleValue]);
                } @catch (NSException *e) {
                    apex_log([[NSString stringWithFormat:@"[FAULT] RollercoasterScrub: %@", e.reason] UTF8String]);
                }
            });
        }
        apex_log("[TROLL] Rollercoaster Scrub (8x timeline teleports) launched.");
        [[RaveApexMenuUI sharedInstance] showToast:@"🎢 Rollercoaster Scrub (x8 Teleports)!"];
    }];

    // Mega Like Tsunami: 50x rapid-fire likeButtonPressed: cascade
    [[NSNotificationCenter defaultCenter] addObserverForName:@"RaveApexMegaLikeTsunamiNotification"
                                                      object:nil queue:[NSOperationQueue mainQueue]
                                                  usingBlock:^(NSNotification * _Nonnull note) {
        for (int i = 0; i < 50; i++) {
            dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(i * 0.08 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
                @try {
                    id vp = apex_find_active_video_player();
                    SEL likeSel = NSSelectorFromString(@"likeButtonPressed:");
                    if (vp && [vp respondsToSelector:likeSel]) {
                        ((void (*)(id, SEL, id))objc_msgSend)(vp, likeSel, nil);
                    }
                } @catch (NSException *e) {
                    apex_log([[NSString stringWithFormat:@"[FAULT] MegaLikeTsunami: %@", e.reason] UTF8String]);
                }
            });
        }
        apex_log("[TROLL] Mega Like Tsunami (50x heart burst) dispatched.");
        [[RaveApexMenuUI sharedInstance] showToast:@"🌊 Mega Like Tsunami (50x Hearts)!"];
    }];

    // Fullscreen Strobe: Toggle fullOrUnfullScreen: 6x zoom bounce
    [[NSNotificationCenter defaultCenter] addObserverForName:@"RaveApexFullscreenStrobeNotification"
                                                      object:nil queue:[NSOperationQueue mainQueue]
                                                  usingBlock:^(NSNotification * _Nonnull note) {
        for (int i = 0; i < 6; i++) {
            dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(i * 0.30 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
                @try {
                    id vp = apex_find_active_video_player();
                    SEL fsSel = NSSelectorFromString(@"fullOrUnfullScreen:");
                    if (vp && [vp respondsToSelector:fsSel]) {
                        ((void (*)(id, SEL, id))objc_msgSend)(vp, fsSel, nil);
                    }
                } @catch (NSException *e) {
                    apex_log([[NSString stringWithFormat:@"[FAULT] FullscreenStrobe: %@", e.reason] UTF8String]);
                }
            });
        }
        apex_log("[TROLL] Fullscreen Zoom Strobe (x6) triggered.");
        [[RaveApexMenuUI sharedInstance] showToast:@"📺 Fullscreen Strobe (x6 Bounce)!"];
    }];

    // Morse Code SOS Siren: "... --- ..." (3 short beeps, 3 boops, 3 short beeps)
    [[NSNotificationCenter defaultCenter] addObserverForName:@"RaveApexMorseCodeSirenNotification"
                                                      object:nil queue:[NSOperationQueue mainQueue]
                                                  usingBlock:^(NSNotification * _Nonnull note) {
        NSArray<NSNumber *> *delays  = @[@0.0, @0.18, @0.36,  @0.70, @1.05, @1.40,  @1.80, @1.98, @2.16];
        NSArray<NSNumber *> *isBoops = @[@NO,  @NO,   @NO,    @YES,  @YES,  @YES,   @NO,   @NO,   @NO];
        for (NSUInteger i = 0; i < delays.count; i++) {
            dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)([delays[i] doubleValue] * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
                @try {
                    apex_trigger_discrete_sfx([isBoops[i] boolValue]);
                } @catch (NSException *e) {
                    apex_log([[NSString stringWithFormat:@"[FAULT] MorseSiren: %@", e.reason] UTF8String]);
                }
            });
        }
        apex_log("[TROLL] Morse Code SOS Siren (... --- ...) transmitted.");
        [[RaveApexMenuUI sharedInstance] showToast:@"🚨 SOS Morse Siren (... --- ...)!"];
    }];

    // Time Machine Whiplash: Bounce clock & seek +/-30s 6 times
    [[NSNotificationCenter defaultCenter] addObserverForName:@"RaveApexTimeWhiplashNotification"
                                                      object:nil queue:[NSOperationQueue mainQueue]
                                                  usingBlock:^(NSNotification * _Nonnull note) {
        for (int i = 0; i < 6; i++) {
            dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(i * 0.45 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
                @try {
                    double delta = (i % 2 == 0) ? 30.0 : -30.0;
                    apex_seek_player_delta(delta);
                    Class syncMgr = objc_getClass("_TtC4Rave11SyncManager");
                    if (syncMgr) {
                        id shared = [syncMgr valueForKey:@"shared"];
                        if (shared) [shared setValue:@(delta / 6.0) forKey:@"syncOffset"];
                    }
                } @catch (NSException *e) {
                    apex_log([[NSString stringWithFormat:@"[FAULT] TimeWhiplash: %@", e.reason] UTF8String]);
                }
            });
        }
        apex_log("[TROLL] Time Machine Whiplash (+/-30s x6) engaged.");
        [[RaveApexMenuUI sharedInstance] showToast:@"⏳ Time Machine Whiplash (+/-30s)!"];
    }];

    // Drunk Snail Mode: 0.15x ultra slow-mo + Demon vocal pitch
    [[NSNotificationCenter defaultCenter] addObserverForName:@"RaveApexDrunkSnailNotification"
                                                      object:nil queue:[NSOperationQueue mainQueue]
                                                  usingBlock:^(NSNotification * _Nonnull note) {
        [RaveApexConfig sharedConfig].uncappedSpeedEnabled = YES;
        [RaveApexConfig sharedConfig].playbackSpeed = 0.15f;
        [[RaveApexConfig sharedConfig] save];
        apex_apply_vocal_pitch_preset(2); // Demon (-600c)
        apex_apply_playback_rate(0.15f);
        apex_log("[TROLL] Drunk Snail Mode (0.15x + Demon Pitch) engaged.");
        [[RaveApexMenuUI sharedInstance] showToast:@"🐌 Drunk Snail Mode (0.15x Slow-Mo)!"];
    }];

    // Hyper-Chipmunk Mode: 4.0x hyper-speed + Helium vocal pitch
    [[NSNotificationCenter defaultCenter] addObserverForName:@"RaveApexHyperChipmunkNotification"
                                                      object:nil queue:[NSOperationQueue mainQueue]
                                                  usingBlock:^(NSNotification * _Nonnull note) {
        [RaveApexConfig sharedConfig].uncappedSpeedEnabled = YES;
        [RaveApexConfig sharedConfig].playbackSpeed = 4.0f;
        [[RaveApexConfig sharedConfig] save];
        apex_apply_vocal_pitch_preset(1); // Helium (+600c)
        apex_apply_playback_rate(4.0f);
        apex_log("[TROLL] Hyper-Chipmunk Mode (4.0x + Helium Pitch) engaged.");
        [[RaveApexMenuUI sharedInstance] showToast:@"🐿️ Hyper-Chipmunk Mode (4.0x Helium)!"];
    }];

    // Typing Indicator Storm: 15x rapid typing state oscillation on RoomClient
    [[NSNotificationCenter defaultCenter] addObserverForName:@"RaveApexTypingStormNotification"
                                                      object:nil queue:[NSOperationQueue mainQueue]
                                                  usingBlock:^(NSNotification * _Nonnull note) {
        for (int i = 0; i < 15; i++) {
            dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(i * 0.15 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
                @try {
                    id room = apex_find_active_room_client();
                    SEL typingSel = NSSelectorFromString(@"sendMeshTypingState:meshUserTypingState:completion:");
                    if (room && [room respondsToSelector:typingSel]) {
                        NSInteger st = (i % 2 == 0) ? 1 : 0;
                        void (*typeFn)(id, SEL, NSInteger, NSInteger, void (^)(BOOL)) =
                            (void (*)(id, SEL, NSInteger, NSInteger, void (^)(BOOL)))[room methodForSelector:typingSel];
                        typeFn(room, typingSel, st, st, ^(BOOL b){});
                    }
                } @catch (NSException *e) {
                    apex_log([[NSString stringWithFormat:@"[FAULT] TypingStorm: %@", e.reason] UTF8String]);
                }
            });
        }
        apex_log("[TROLL] Ghost Typing Indicator Storm (x15 packets) transmitted.");
        [[RaveApexMenuUI sharedInstance] showToast:@"⌨️ Ghost Typing Storm (x15 Bubbles)!"];
    }];

    // =========================================================================
    // PHASE 9: 22 NEW CARPET-BOMBING & BINARY ARSENAL WEAPONS (Rave v8.1.2)
    // =========================================================================

    // 1. MOAB 10-Wave Sequential Carpet Bomb
    [[NSNotificationCenter defaultCenter] addObserverForName:@"RaveApexCarpetBombNotification"
                                                      object:nil queue:[NSOperationQueue mainQueue]
                                                  usingBlock:^(NSNotification * _Nonnull note) {
        NSArray<NSString *> *waves = @[
            @"RaveApexCrownSeizureNotification",
            @"RaveApexMassMuteNotification",
            @"RaveApexThermonuclearAudioBombNotification",
            @"RaveApexHeartSupernovaBombNotification",
            @"RaveApexTemporalSingularityBombNotification",
            @"RaveApexQueueShuffleBombNotification",
            @"RaveApexBubbleSupernovaBombNotification",
            @"RaveApexVoteRiggingBombNotification",
            @"RaveApexViralStatsBombNotification",
            @"RaveApexAirhornSirenBombNotification"
        ];
        for (NSUInteger w = 0; w < waves.count; w++) {
            NSString *waveName = waves[w];
            dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(w * 0.35 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
                [[NSNotificationCenter defaultCenter] postNotificationName:waveName object:nil];
            });
        }
        apex_log("[BOMB] MOAB 10-Wave Sequential Carpet Bomb deployed across room.");
        [[RaveApexMenuUI sharedInstance] showToast:@"💣 MOAB 10-WAVE CARPET BOMB DEPLOYED!"];
    }];

    // 2. EMP Room Blackout Bomb (Mute + Lockdown + Wipe Queue + Kill Vote + Pause + Power-Down Synth)
    [[NSNotificationCenter defaultCenter] addObserverForName:@"RaveApexEmpBlackoutBombNotification"
                                                      object:nil queue:[NSOperationQueue mainQueue]
                                                  usingBlock:^(NSNotification * _Nonnull note) {
        @try {
            [[NSNotificationCenter defaultCenter] postNotificationName:@"RaveApexRoomLockdownNotification" object:nil];
            [[NSNotificationCenter defaultCenter] postNotificationName:@"RaveApexMassMuteNotification" object:nil];
            [[NSNotificationCenter defaultCenter] postNotificationName:@"RaveApexQueueShredderBombNotification" object:nil];
            [[NSNotificationCenter defaultCenter] postNotificationName:@"RaveApexEndVoteSessionNotification" object:nil];
            id vp = apex_find_active_video_player();
            if (vp && [vp respondsToSelector:NSSelectorFromString(@"playPaused")]) {
                ((void (*)(id, SEL))objc_msgSend)(vp, NSSelectorFromString(@"playPaused"));
            }
            for (int i = 0; i < 6; i++) {
                dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(i * 0.09 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
                    apex_play_synth_tone(900.0 - (i * 130.0), 0.10, 0.90);
                });
            }
            apex_log("[BOMB] EMP Room Blackout Bomb executed.");
            [[RaveApexMenuUI sharedInstance] showToast:@"⚡ EMP ROOM BLACKOUT DETONATED!"];
        } @catch (NSException *e) {
            apex_log([[NSString stringWithFormat:@"[FAULT] EmpBlackoutBomb: %@", e.reason] UTF8String]);
        }
    }];

    // 3. Thermonuclear Audio Bomb (30.0x Preamp + Sub-60Hz Bassquake + 64x Rapid SFX Storm)
    [[NSNotificationCenter defaultCenter] addObserverForName:@"RaveApexThermonuclearAudioBombNotification"
                                                      object:nil queue:[NSOperationQueue mainQueue]
                                                  usingBlock:^(NSNotification * _Nonnull note) {
        [RaveApexConfig sharedConfig].audioPreampBoostEnabled = YES;
        [RaveApexConfig sharedConfig].megaPreamp30xEnabled = YES;
        [RaveApexConfig sharedConfig].ultraBassquakeEnabled = YES;
        [RaveApexConfig sharedConfig].audioPreampVolume = 30.0f;
        apply_audio_preamp_boost(30.0f);
        for (int i = 0; i < 64; i++) {
            dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(i * 0.045 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
                @try {
                    apex_trigger_discrete_sfx((i % 2) == 0);
                } @catch (NSException *e) {
                    apex_log([[NSString stringWithFormat:@"[FAULT] ThermonuclearAudio: %@", e.reason] UTF8String]);
                }
            });
        }
        apex_log("[BOMB] Thermonuclear Audio Bomb (30x Preamp + 64x SFX) unleashed.");
        [[RaveApexMenuUI sharedInstance] showToast:@"☢️ THERMONUCLEAR AUDIO BOMB (30x + 64 SFX)!"];
    }];

    // 4. 100x Heart Supernova Bomb (VideoPlayer.likeButtonPressed: x100)
    [[NSNotificationCenter defaultCenter] addObserverForName:@"RaveApexHeartSupernovaBombNotification"
                                                      object:nil queue:[NSOperationQueue mainQueue]
                                                  usingBlock:^(NSNotification * _Nonnull note) {
        for (int i = 0; i < 100; i++) {
            dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(i * 0.032 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
                @try {
                    id vp = apex_find_active_video_player();
                    SEL likeSel = NSSelectorFromString(@"likeButtonPressed:");
                    if (vp && [vp respondsToSelector:likeSel]) {
                        ((void (*)(id, SEL, id))objc_msgSend)(vp, likeSel, nil);
                    }
                } @catch (NSException *e) {
                    apex_log([[NSString stringWithFormat:@"[FAULT] HeartSupernova: %@", e.reason] UTF8String]);
                }
            });
        }
        apex_play_synth_tone(1046.5, 0.18, 0.80);
        apex_log("[BOMB] 100x Heart Supernova Bomb launched.");
        [[RaveApexMenuUI sharedInstance] showToast:@"💖 100x HEART SUPERNOVA BOMB!"];
    }];

    // 5. Temporal Singularity Bomb (10-Wave Speed + Timeline Warp)
    [[NSNotificationCenter defaultCenter] addObserverForName:@"RaveApexTemporalSingularityBombNotification"
                                                      object:nil queue:[NSOperationQueue mainQueue]
                                                  usingBlock:^(NSNotification * _Nonnull note) {
        [RaveApexConfig sharedConfig].uncappedSpeedEnabled = YES;
        [RaveApexConfig sharedConfig].unhookedSyncEnabled = YES;
        NSArray<NSNumber *> *rates = @[@0.15, @4.5, @0.25, @5.0, @0.2, @3.5, @0.5, @4.0, @0.3, @1.0];
        for (NSUInteger i = 0; i < rates.count; i++) {
            dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(i * 0.24 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
                @try {
                    float r = [rates[i] floatValue];
                    apex_apply_playback_rate(r);
                    double delta = (i % 2 == 0) ? 25.0 : -25.0;
                    if (i < rates.count - 1) apex_seek_player_delta(delta);
                } @catch (NSException *e) {
                    apex_log([[NSString stringWithFormat:@"[FAULT] TemporalSingularity: %@", e.reason] UTF8String]);
                }
            });
        }
        apex_log("[BOMB] Temporal Singularity Bomb (10-wave speed + seek warp) detonated.");
        [[RaveApexMenuUI sharedInstance] showToast:@"🕳️ TEMPORAL SINGULARITY BOMB!"];
    }];

    // 6. 24x Machine-Gun Poltergeist Bomb (Ultra-Fast 60ms Play/Pause Strobe)
    [[NSNotificationCenter defaultCenter] addObserverForName:@"RaveApexMachineGunPoltergeistBombNotification"
                                                      object:nil queue:[NSOperationQueue mainQueue]
                                                  usingBlock:^(NSNotification * _Nonnull note) {
        for (int i = 0; i < 24; i++) {
            dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(i * 0.065 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
                @try {
                    id vp = apex_find_active_video_player();
                    if (vp) {
                        SEL sel = (i % 2 == 0) ? NSSelectorFromString(@"playPaused") : NSSelectorFromString(@"playResumed");
                        if ([vp respondsToSelector:sel]) ((void (*)(id, SEL))objc_msgSend)(vp, sel);
                    }
                    if (i % 4 == 0) apex_play_synth_tone(320.0 + (i * 25.0), 0.04, 0.65);
                } @catch (NSException *e) {
                    apex_log([[NSString stringWithFormat:@"[FAULT] MachineGunPoltergeist: %@", e.reason] UTF8String]);
                }
            });
        }
        apex_log("[BOMB] 24x Machine-Gun Poltergeist Bomb fired.");
        [[RaveApexMenuUI sharedInstance] showToast:@"🔫 24x MACHINE-GUN POLTERGEIST!"];
    }];

    // 7. Airhorn & Nuclear Klaxon Siren Bomb (Synthesized Multi-Horn + Klaxon Sweep)
    [[NSNotificationCenter defaultCenter] addObserverForName:@"RaveApexAirhornSirenBombNotification"
                                                      object:nil queue:[NSOperationQueue mainQueue]
                                                  usingBlock:^(NSNotification * _Nonnull note) {
        // 3 rapid DJ airhorn blasts followed by alternating nuclear klaxon siren
        double delays[] = {0.0, 0.16, 0.32, 0.52, 0.85, 1.15, 1.45, 1.75};
        double freqs[]  = {480.0, 480.0, 480.0, 640.0, 960.0, 640.0, 960.0, 1180.0};
        double durs[]   = {0.13, 0.13, 0.16, 0.30, 0.28, 0.28, 0.28, 0.35};
        for (int i = 0; i < 8; i++) {
            double d = delays[i];
            double f = freqs[i];
            double dur = durs[i];
            dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(d * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
                apex_play_synth_tone(f, dur, 0.95);
                apex_trigger_discrete_sfx((i % 2) != 0);
            });
        }
        apex_log("[BOMB] Airhorn & Nuclear Klaxon Siren Bomb triggered.");
        [[RaveApexMenuUI sharedInstance] showToast:@"📢 AIRHORN & NUCLEAR KLAXON SIREN!"];
    }];

    // 8. 50x Typing Indicator Carpet Bomb
    [[NSNotificationCenter defaultCenter] addObserverForName:@"RaveApexTypingCarpetBombNotification"
                                                      object:nil queue:[NSOperationQueue mainQueue]
                                                  usingBlock:^(NSNotification * _Nonnull note) {
        [RaveApexConfig sharedConfig].ghostTypingEnabled = YES;
        for (int i = 0; i < 50; i++) {
            dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(i * 0.06 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
                @try {
                    id room = apex_find_active_room_client();
                    SEL typingSel = NSSelectorFromString(@"sendMeshTypingState:meshUserTypingState:completion:");
                    if (room && [room respondsToSelector:typingSel]) {
                        NSInteger st = (i % 2 == 0) ? 1 : 0;
                        void (*typeFn)(id, SEL, NSInteger, NSInteger, void (^)(BOOL)) =
                            (void (*)(id, SEL, NSInteger, NSInteger, void (^)(BOOL)))[room methodForSelector:typingSel];
                        typeFn(room, typingSel, st, st, ^(BOOL b){});
                    }
                } @catch (NSException *e) {
                    apex_log([[NSString stringWithFormat:@"[FAULT] TypingCarpetBomb: %@", e.reason] UTF8String]);
                }
            });
        }
        apex_log("[BOMB] 50x Typing Indicator Carpet Bomb deployed.");
        [[RaveApexMenuUI sharedInstance] showToast:@"💬 50x TYPING CARPET BOMB!"];
    }];

    // 9. 20x Crown Blitzkrieg Bomb (ParticipantCell.crownView + MeshSettings.setupCrown strobe)
    [[NSNotificationCenter defaultCenter] addObserverForName:@"RaveApexCrownBlitzkriegBombNotification"
                                                      object:nil queue:[NSOperationQueue mainQueue]
                                                  usingBlock:^(NSNotification * _Nonnull note) {
        [RaveApexConfig sharedConfig].crownSpoofEnabled = YES;
        [RaveApexConfig sharedConfig].omniLeaderElevationEnabled = YES;
        [RaveApexConfig sharedConfig].phantomCrownLockEnabled = YES;
        [[RaveApexConfig sharedConfig] save];
        for (int i = 0; i < 20; i++) {
            dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(i * 0.075 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
                @try {
                    NSArray *pCells = apex_find_views_of_class("_TtC4Rave15ParticipantCell");
                    for (UIView *cell in pCells) {
                        if ([cell respondsToSelector:NSSelectorFromString(@"crownView")]) {
                            UIView *cv = ((id (*)(id, SEL))objc_msgSend)(cell, NSSelectorFromString(@"crownView"));
                            if ([cv isKindOfClass:[UIView class]]) {
                                cv.hidden = (i < 19) ? ((i % 2) != 0) : NO;
                                cv.alpha = 1.0;
                            }
                        }
                    }
                    id meshVC = apex_find_active_mesh_vc();
                    id ms = apex_safe_ivar_object(meshVC, "meshSettings");
                    if (ms && [ms respondsToSelector:NSSelectorFromString(@"setupCrown")]) {
                        ((void (*)(id, SEL))objc_msgSend)(ms, NSSelectorFromString(@"setupCrown"));
                    }
                } @catch (NSException *e) {
                    apex_log([[NSString stringWithFormat:@"[FAULT] CrownBlitzkrieg: %@", e.reason] UTF8String]);
                }
            });
        }
        apex_play_synth_tone(1174.6, 0.20, 0.85);
        apex_log("[BOMB] 20x Crown Blitzkrieg Bomb completed.");
        [[RaveApexMenuUI sharedInstance] showToast:@"👑 20x CROWN BLITZKRIEG BOMB!"];
    }];

    // 10. 20x Silence EMP Bomb (Sustained Room Mute Suppression)
    [[NSNotificationCenter defaultCenter] addObserverForName:@"RaveApexSilenceEmpBombNotification"
                                                      object:nil queue:[NSOperationQueue mainQueue]
                                                  usingBlock:^(NSNotification * _Nonnull note) {
        for (int i = 0; i < 20; i++) {
            dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(i * 0.12 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
                [[NSNotificationCenter defaultCenter] postNotificationName:@"RaveApexMassMuteNotification" object:nil];
            });
        }
        apex_log("[BOMB] 20x Silence EMP Bomb engaged.");
        [[RaveApexMenuUI sharedInstance] showToast:@"🔇 20x SILENCE EMP BOMB!"];
    }];

    // 11. Queue Shredder Bomb (MyQueueHeaderCell.deleteButtonTapped: + MyQueueCell.onPanToDelete: + GateKeeper)
    [[NSNotificationCenter defaultCenter] addObserverForName:@"RaveApexQueueShredderBombNotification"
                                                      object:nil queue:[NSOperationQueue mainQueue]
                                                  usingBlock:^(NSNotification * _Nonnull note) {
        @try {
            NSArray *headers = apex_find_views_of_class("_TtC4Rave17MyQueueHeaderCell");
            for (UIView *hdr in headers) {
                if ([hdr respondsToSelector:NSSelectorFromString(@"deleteButtonTapped:")]) {
                    ((void (*)(id, SEL, id))objc_msgSend)(hdr, NSSelectorFromString(@"deleteButtonTapped:"), nil);
                }
                if ([hdr respondsToSelector:NSSelectorFromString(@"queueSizeLabel")]) {
                    UILabel *lbl = ((id (*)(id, SEL))objc_msgSend)(hdr, NSSelectorFromString(@"queueSizeLabel"));
                    if ([lbl isKindOfClass:[UILabel class]]) lbl.text = @"0 videos (SHREDDED 💥)";
                }
            }
            NSArray *cells = apex_find_views_of_class("_TtC4Rave11MyQueueCell");
            for (UIView *cell in cells) {
                if ([cell respondsToSelector:NSSelectorFromString(@"titleLabel")]) {
                    UILabel *tl = ((id (*)(id, SEL))objc_msgSend)(cell, NSSelectorFromString(@"titleLabel"));
                    if ([tl isKindOfClass:[UILabel class]]) tl.text = @"💥 [QUEUE SHREDDED BY APEX]";
                }
            }
            [[NSNotificationCenter defaultCenter] postNotificationName:@"RaveApexResetQueueNotification" object:nil];
            apex_play_synth_tone(180.0, 0.22, 0.85);
            apex_log("[BOMB] Queue Shredder Bomb executed on MyQueueHeaderCell & MyQueueCell.");
            [[RaveApexMenuUI sharedInstance] showToast:@"🗑️ QUEUE SHREDDER BOMB DETONATED!"];
        } @catch (NSException *e) {
            apex_log([[NSString stringWithFormat:@"[FAULT] QueueShredderBomb: %@", e.reason] UTF8String]);
        }
    }];

    // 12. Queue Chaos Shuffle Bomb (10x MyQueueHeaderCell.shuffleMyQueue:)
    [[NSNotificationCenter defaultCenter] addObserverForName:@"RaveApexQueueShuffleBombNotification"
                                                      object:nil queue:[NSOperationQueue mainQueue]
                                                  usingBlock:^(NSNotification * _Nonnull note) {
        for (int i = 0; i < 10; i++) {
            dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(i * 0.08 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
                @try {
                    NSArray *headers = apex_find_views_of_class("_TtC4Rave17MyQueueHeaderCell");
                    for (UIView *hdr in headers) {
                        if ([hdr respondsToSelector:NSSelectorFromString(@"shuffleMyQueue:")]) {
                            ((void (*)(id, SEL, id))objc_msgSend)(hdr, NSSelectorFromString(@"shuffleMyQueue:"), nil);
                        }
                    }
                } @catch (NSException *e) {
                    apex_log([[NSString stringWithFormat:@"[FAULT] QueueShuffleBomb: %@", e.reason] UTF8String]);
                }
            });
        }
        apex_play_synth_tone(740.0, 0.15, 0.75);
        apex_log("[BOMB] Queue Chaos Shuffle Bomb (10x shuffleMyQueue:) executed.");
        [[RaveApexMenuUI sharedInstance] showToast:@"🔀 QUEUE CHAOS SHUFFLE BOMB (10x)!"];
    }];

    // 13. Vote Rigging & Countdown Bomb (VoteGridCell.voteCountLabel + VoteManager.countdownExpired:)
    [[NSNotificationCenter defaultCenter] addObserverForName:@"RaveApexVoteRiggingBombNotification"
                                                      object:nil queue:[NSOperationQueue mainQueue]
                                                  usingBlock:^(NSNotification * _Nonnull note) {
        @try {
            [RaveApexConfig sharedConfig].voteQuorumAutopilotEnabled = YES;
            [RaveApexConfig sharedConfig].voteHijackerAutoPassEnabled = YES;
            NSArray *voteCells = apex_find_views_of_class("_TtC4Rave12VoteGridCell");
            for (UIView *vc in voteCells) {
                if ([vc respondsToSelector:NSSelectorFromString(@"voteCountLabel")]) {
                    UILabel *vl = ((id (*)(id, SEL))objc_msgSend)(vc, NSSelectorFromString(@"voteCountLabel"));
                    if ([vl isKindOfClass:[UILabel class]]) vl.text = @"999 VOTES 🔥";
                }
            }
            id meshVC = apex_find_active_mesh_vc();
            id voteMgr = apex_safe_ivar_object(meshVC, "voteManager");
            if (voteMgr && [voteMgr respondsToSelector:NSSelectorFromString(@"countdownExpired:")]) {
                ((void (*)(id, SEL, id))objc_msgSend)(voteMgr, NSSelectorFromString(@"countdownExpired:"), nil);
            }
            apex_play_synth_tone(880.0, 0.18, 0.80);
            apex_log("[BOMB] Vote Rigging & Countdown Bomb executed.");
            [[RaveApexMenuUI sharedInstance] showToast:@"🗳️ VOTE RIGGED (999 VOTES) & EXPIRED!"];
        } @catch (NSException *e) {
            apex_log([[NSString stringWithFormat:@"[FAULT] VoteRiggingBomb: %@", e.reason] UTF8String]);
        }
    }];

    // 14. Floating Avatar Bubble Supernova (BubbleViewScene.scaleNodesWithScale: + Physics Overdrive)
    [[NSNotificationCenter defaultCenter] addObserverForName:@"RaveApexBubbleSupernovaBombNotification"
                                                      object:nil queue:[NSOperationQueue mainQueue]
                                                  usingBlock:^(NSNotification * _Nonnull note) {
        @try {
            id meshVC = apex_find_active_mesh_vc();
            id bubbleVC = apex_safe_ivar_object(meshVC, "bubbleViewController");
            id scene = apex_safe_ivar_object(bubbleVC, "scene") ?: apex_safe_ivar_object(bubbleVC, "bubbleViewScene");
            NSArray<NSNumber *> *scales = @[@3.2, @0.45, @2.8, @0.6, @2.2, @1.0];
            for (NSUInteger i = 0; i < scales.count; i++) {
                dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(i * 0.14 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
                    @try {
                        double sc = [scales[i] doubleValue];
                        if (scene && [scene respondsToSelector:NSSelectorFromString(@"startBubbleViewPhysics")]) {
                            ((void (*)(id, SEL))objc_msgSend)(scene, NSSelectorFromString(@"startBubbleViewPhysics"));
                        }
                        if (scene && [scene respondsToSelector:NSSelectorFromString(@"scaleNodesWithScale:")]) {
                            ((void (*)(id, SEL, double))objc_msgSend)(scene, NSSelectorFromString(@"scaleNodesWithScale:"), sc);
                        }
                        NSArray *pCells = apex_find_views_of_class("_TtC4Rave15ParticipantCell");
                        for (UIView *cell in pCells) {
                            cell.transform = (i == scales.count - 1) ? CGAffineTransformIdentity : CGAffineTransformMakeScale((CGFloat)sc * 0.55, (CGFloat)sc * 0.55);
                        }
                    } @catch (NSException *e) {
                        apex_log([[NSString stringWithFormat:@"[FAULT] BubbleSupernova wave: %@", e.reason] UTF8String]);
                    }
                });
            }
            apex_play_synth_tone(660.0, 0.20, 0.80);
            apex_log("[BOMB] Floating Avatar Bubble Supernova executed.");
            [[RaveApexMenuUI sharedInstance] showToast:@"🫧 AVATAR BUBBLE SUPERNOVA (3.2x)!"];
        } @catch (NSException *e) {
            apex_log([[NSString stringWithFormat:@"[FAULT] BubbleSupernovaBomb: %@", e.reason] UTF8String]);
        }
    }];

    // 15. 999M Viral Video Stats Spoof Bomb (VideoInformationView + VideoPlayer)
    [[NSNotificationCenter defaultCenter] addObserverForName:@"RaveApexViralStatsBombNotification"
                                                      object:nil queue:[NSOperationQueue mainQueue]
                                                  usingBlock:^(NSNotification * _Nonnull note) {
        @try {
            id vp = apex_find_active_video_player();
            if (vp && [vp respondsToSelector:NSSelectorFromString(@"showVideoInformationView")]) {
                ((void (*)(id, SEL))objc_msgSend)(vp, NSSelectorFromString(@"showVideoInformationView"));
            }
            NSArray *infoViews = apex_find_views_of_class("_TtC4Rave20VideoInformationView");
            for (UIView *iv in infoViews) {
                if ([iv respondsToSelector:NSSelectorFromString(@"viewsLabel")]) {
                    UILabel *vl = ((id (*)(id, SEL))objc_msgSend)(iv, NSSelectorFromString(@"viewsLabel"));
                    if ([vl isKindOfClass:[UILabel class]]) vl.text = @"999,999,999 views • #1 TRENDING 🔥";
                }
                if ([iv respondsToSelector:NSSelectorFromString(@"likesLabel")]) {
                    UILabel *ll = ((id (*)(id, SEL))objc_msgSend)(iv, NSSelectorFromString(@"likesLabel"));
                    if ([ll isKindOfClass:[UILabel class]]) ll.text = @"99.9M 👍";
                }
                if ([iv respondsToSelector:NSSelectorFromString(@"authorLabel")]) {
                    UILabel *al = ((id (*)(id, SEL))objc_msgSend)(iv, NSSelectorFromString(@"authorLabel"));
                    if ([al isKindOfClass:[UILabel class]]) al.text = @"👑 RAVE APEX SOVEREIGN HOST";
                }
            }
            apex_play_synth_tone(987.7, 0.16, 0.75);
            apex_log("[BOMB] 999M Viral Video Stats Spoof Bomb applied to VideoInformationView.");
            [[RaveApexMenuUI sharedInstance] showToast:@"📈 999M VIRAL STATS SPOOF APPLIED!"];
        } @catch (NSException *e) {
            apex_log([[NSString stringWithFormat:@"[FAULT] ViralStatsBomb: %@", e.reason] UTF8String]);
        }
    }];

    // 16. Mass Friend Invite Bomb (InviteFriendHeader.inviteAll + ChatButtons.inviteButton:)
    [[NSNotificationCenter defaultCenter] addObserverForName:@"RaveApexInviteBombNotification"
                                                      object:nil queue:[NSOperationQueue mainQueue]
                                                  usingBlock:^(NSNotification * _Nonnull note) {
        @try {
            NSArray *invHeaders = apex_find_views_of_class("_TtC4Rave18InviteFriendHeader");
            for (UIView *ih in invHeaders) {
                if ([ih respondsToSelector:NSSelectorFromString(@"inviteAll")]) {
                    ((void (*)(id, SEL))objc_msgSend)(ih, NSSelectorFromString(@"inviteAll"));
                }
            }
            NSArray *chatBtns = apex_find_views_of_class("_TtC4Rave11ChatButtons");
            for (UIView *cb in chatBtns) {
                if ([cb respondsToSelector:NSSelectorFromString(@"inviteButton:")]) {
                    ((void (*)(id, SEL, id))objc_msgSend)(cb, NSSelectorFromString(@"inviteButton:"), nil);
                }
            }
            apex_play_synth_tone(820.0, 0.14, 0.75);
            apex_log("[BOMB] Mass Friend Invite Bomb triggered.");
            [[RaveApexMenuUI sharedInstance] showToast:@"📨 MASS FRIEND INVITE BOMB FIRED!"];
        } @catch (NSException *e) {
            apex_log([[NSString stringWithFormat:@"[FAULT] InviteBomb: %@", e.reason] UTF8String]);
        }
    }];

    // 17. Voice Note Rapid-Replay Bomb (VoiceMessageView.playButtonTapped x8)
    [[NSNotificationCenter defaultCenter] addObserverForName:@"RaveApexVoiceMessageBombNotification"
                                                      object:nil queue:[NSOperationQueue mainQueue]
                                                  usingBlock:^(NSNotification * _Nonnull note) {
        for (int i = 0; i < 8; i++) {
            dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(i * 0.15 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
                @try {
                    NSArray *vmViews = apex_find_views_of_class("_TtC4Rave16VoiceMessageView");
                    for (UIView *vm in vmViews) {
                        if ([vm respondsToSelector:NSSelectorFromString(@"playButtonTapped")]) {
                            ((void (*)(id, SEL))objc_msgSend)(vm, NSSelectorFromString(@"playButtonTapped"));
                        }
                    }
                    apex_trigger_discrete_sfx((i % 2) == 0);
                } @catch (NSException *e) {
                    apex_log([[NSString stringWithFormat:@"[FAULT] VoiceMessageBomb: %@", e.reason] UTF8String]);
                }
            });
        }
        apex_log("[BOMB] Voice Note Rapid-Replay Bomb (x8) executed.");
        [[RaveApexMenuUI sharedInstance] showToast:@"🎙️ VOICE NOTE RAPID-REPLAY BOMB (x8)!"];
    }];

    // 18. Total Ad & Banner Purge Bomb (DualAdLoader + InterstitialViewController + Ad Views)
    [[NSNotificationCenter defaultCenter] addObserverForName:@"RaveApexPurgeAllAdsBombNotification"
                                                      object:nil queue:[NSOperationQueue mainQueue]
                                                  usingBlock:^(NSNotification * _Nonnull note) {
        @try {
            [RaveApexConfig sharedConfig].adBlockEnabled = YES;
            [[RaveApexConfig sharedConfig] save];
            NSArray<NSString *> *adClasses = @[@"GADBannerView", @"GAMBannerView", @"FBAdView", @"ALAdView", @"MPAdView", @"_TtC4Rave16AdTrackingPrompt"];
            NSUInteger purged = 0;
            for (NSString *clsName in adClasses) {
                NSArray *views = apex_find_views_of_class([clsName UTF8String]);
                for (UIView *v in views) {
                    v.hidden = YES;
                    v.alpha = 0.0;
                    [v removeFromSuperview];
                    purged++;
                }
            }
            apex_play_synth_tone(1000.0, 0.12, 0.70);
            apex_log([[NSString stringWithFormat:@"[BOMB] Total Ad & Banner Purge Bomb completed (%lu views vaporized).", (unsigned long)purged] UTF8String]);
            [[RaveApexMenuUI sharedInstance] showToast:@"🛡️ ALL ADS & BANNERS VAPORIZED!"];
        } @catch (NSException *e) {
            apex_log([[NSString stringWithFormat:@"[FAULT] PurgeAllAdsBomb: %@", e.reason] UTF8String]);
        }
    }];

    // 19. Paywall & Mature Blur Vaporizer Bomb (VideoPlayerMatureContentView + RavePremiumView + Chat Unblur)
    [[NSNotificationCenter defaultCenter] addObserverForName:@"RaveApexVaporizePaywallsBombNotification"
                                                      object:nil queue:[NSOperationQueue mainQueue]
                                                  usingBlock:^(NSNotification * _Nonnull note) {
        @try {
            [RaveApexConfig sharedConfig].premiumBypassEnabled = YES;
            [RaveApexConfig sharedConfig].matureBypassEnabled = YES;
            [RaveApexConfig sharedConfig].autoUnblurChatImagesEnabled = YES;
            [RaveApexConfig sharedConfig].iapReceiptSpoofEnabled = YES;
            [[RaveApexConfig sharedConfig] save];

            NSArray *matureViews = apex_find_views_of_class("_TtC4Rave28VideoPlayerMatureContentView");
            for (UIView *mv in matureViews) {
                if ([mv respondsToSelector:NSSelectorFromString(@"onMatureContentTapped:")]) {
                    ((void (*)(id, SEL, id))objc_msgSend)(mv, NSSelectorFromString(@"onMatureContentTapped:"), nil);
                }
                mv.hidden = YES;
            }
            NSArray *chatImgViews = apex_find_views_of_class("_TtC4Rave19ChatCellImageContent");
            for (UIView *civ in chatImgViews) {
                if ([civ respondsToSelector:NSSelectorFromString(@"blurView")]) {
                    UIView *bv = ((id (*)(id, SEL))objc_msgSend)(civ, NSSelectorFromString(@"blurView"));
                    if ([bv isKindOfClass:[UIView class]]) bv.hidden = YES;
                }
            }
            NSArray *premViews = apex_find_views_of_class("_TtC4Rave15RavePremiumView");
            for (UIView *pv in premViews) {
                if ([pv respondsToSelector:NSSelectorFromString(@"price")]) {
                    UILabel *pl = ((id (*)(id, SEL))objc_msgSend)(pv, NSSelectorFromString(@"price"));
                    if ([pl isKindOfClass:[UILabel class]]) pl.text = @"$0.00 (APEX UNLOCKED)";
                }
            }
            apex_play_synth_tone(1244.5, 0.16, 0.80);
            apex_log("[BOMB] Paywall & Mature Blur Vaporizer Bomb executed.");
            [[RaveApexMenuUI sharedInstance] showToast:@"💎 PAYWALLS & MATURE BLURS VAPORIZED!"];
        } @catch (NSException *e) {
            apex_log([[NSString stringWithFormat:@"[FAULT] VaporizePaywallsBomb: %@", e.reason] UTF8String]);
        }
    }];

    // 20. Tactical Flashbang Grenade Bomb (2600Hz Tinnitus Ring + Blinding Whiteout)
    [[NSNotificationCenter defaultCenter] addObserverForName:@"RaveApexFlashbangBombNotification"
                                                      object:nil queue:[NSOperationQueue mainQueue]
                                                  usingBlock:^(NSNotification * _Nonnull note) {
        apex_play_synth_tone(2650.0, 1.35, 0.95);
        apex_log("[BOMB] Tactical Flashbang Grenade (2650Hz tinnitus + whiteout) detonated.");
    }];

    // 21. 360-Degree Barrel Roll Cinema Bomb
    [[NSNotificationCenter defaultCenter] addObserverForName:@"RaveApexBarrelRollBombNotification"
                                                      object:nil queue:[NSOperationQueue mainQueue]
                                                  usingBlock:^(NSNotification * _Nonnull note) {
        apex_play_synth_tone(420.0, 0.25, 0.80);
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.25 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            apex_play_synth_tone(680.0, 0.25, 0.80);
        });
        apex_log("[BOMB] 360-Degree Barrel Roll Cinema Bomb executed.");
    }];

    // 22. Cyber Matrix Glitch & HUD Overdrive Bomb (_TtC4Rave12DebugOverlay + Matrix Scanline)
    [[NSNotificationCenter defaultCenter] addObserverForName:@"RaveApexMatrixGlitchBombNotification"
                                                      object:nil queue:[NSOperationQueue mainQueue]
                                                  usingBlock:^(NSNotification * _Nonnull note) {
        @try {
            [RaveApexConfig sharedConfig].nativeDebugOverlayVisible = YES;
            [[RaveApexMenuUI sharedInstance] toggleNativeDebugOverlay];
            NSArray *dbgViews = apex_find_views_of_class("_TtC4Rave12DebugOverlay");
            for (UIView *dv in dbgViews) {
                dv.hidden = NO;
                dv.alpha = 1.0;
                if ([dv respondsToSelector:NSSelectorFromString(@"driftLabel")]) {
                    UILabel *l = ((id (*)(id, SEL))objc_msgSend)(dv, NSSelectorFromString(@"driftLabel"));
                    if ([l isKindOfClass:[UILabel class]]) l.text = @"DRIFT: 0.00ms [APEX MATRIX LOCK]";
                }
                if ([dv respondsToSelector:NSSelectorFromString(@"clockStatusLabel")]) {
                    UILabel *l = ((id (*)(id, SEL))objc_msgSend)(dv, NSSelectorFromString(@"clockStatusLabel"));
                    if ([l isKindOfClass:[UILabel class]]) l.text = @"CLOCK: SOVEREIGN OVERRIDE";
                }
                if ([dv respondsToSelector:NSSelectorFromString(@"stateLabel")]) {
                    UILabel *l = ((id (*)(id, SEL))objc_msgSend)(dv, NSSelectorFromString(@"stateLabel"));
                    if ([l isKindOfClass:[UILabel class]]) l.text = @"STATE: FRANKB OMNI-ENGINE ACTIVE";
                }
            }
            apex_play_synth_tone(1480.0, 0.14, 0.80);
            apex_log("[BOMB] Cyber Matrix Glitch & HUD Overdrive Bomb engaged.");
        } @catch (NSException *e) {
            apex_log([[NSString stringWithFormat:@"[FAULT] MatrixGlitchBomb: %@", e.reason] UTF8String]);
        }
    }];

    NSLog(@"[RaveApexCore] Master initialization complete. Host hooks & 90 Troll/Bomb weapons armed.");
}
