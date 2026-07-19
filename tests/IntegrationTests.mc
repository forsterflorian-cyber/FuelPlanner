using Toybox.Test;
import Toybox.Lang;
import Toybox.Activity;
import FuelReminderModes;

//! Integration tests for session lifecycle and component interaction
class IntegrationTests {

    static function buildFullSystem(clock as MockClock, props as MockPropertiesBackend) as Dictionary {
        var storageBackend = new MockStorageBackend();
        var storage = new StorageManager(storageBackend, props);
        var model = new FuelModel(storage, clock);
        model.setTouchForTest(true);
        return {
            "clock" => clock,
            "props" => props,
            "storageBackend" => storageBackend,
            "storage" => storage,
            "model" => model
        };
    }

    // ── Session Lifecycle ──────────────────────────────────

    (:test)
    static function fullSessionLifecycle(logger as Test.Logger) as Boolean {
        var clock = new MockClock(10000);
        var props = new MockPropertiesBackend();
        props.setValue("carbsTargetGph", 60);
        props.setValue("doseG", 25);
        props.setValue("startDelayMin", 0);

        var sys = buildFullSystem(clock, props);
        var model = sys["model"] as FuelModel;
        var storage = sys["storage"] as StorageManager;

        // Phase 1: No session initially
        Test.assertMessage(!model.isSessionActive(), "Should start with no active session");
        Test.assertMessage(!storage.hasActiveSession(), "Storage should have no active session");

        // Phase 2: Start activity
        var info = new MockActivityInfo(10000);
        info.setTimerSeconds(0);
        model.compute(info);

        // Phase 3: Timer starts
        clock.advance(1);
        info.advanceTimerSeconds(1);
        model.compute(info);

        Test.assertMessage(model.isSessionActive(), "Session should be active after timer starts");
        Test.assertMessage(storage.hasActiveSession(), "Storage should have active session");

        // Phase 4: Activity progresses
        for (var i = 0; i < 600; i += 1) {
            clock.advance(1);
            info.advanceTimerSeconds(1);
            model.compute(info);
        }

        // After 10 minutes at 60 g/h = 10g deficit
        var deficitG10 = model.getDeficitG10();
        Test.assertMessage(deficitG10 == 100, "Deficit should be 100 (10g) after 10 minutes");
        logger.debug("deficitG10=" + deficitG10.format("%d"));

        // Phase 5: Record intake
        model.recordIntake(25);
        Test.assertMessage(model.getConsumedTotalG10() == 250, "Consumed should be 250 (25g)");
        Test.assertMessage(model.getIntakeCount() == 1, "Intake count should be 1");

        // Phase 6: Deficit reduced
        deficitG10 = model.getDeficitG10();
        Test.assertMessage(deficitG10 == -150, "Deficit should be -150 (surplus 15g)");
        logger.debug("deficitAfterIntakeG10=" + deficitG10.format("%d"));

        // Phase 7: A manual stop pauses the session but does not end it.
        model.onTimerStop();
        info.timerState = Activity.TIMER_STATE_STOPPED;
        model.compute(info);

        Test.assertMessage(model.isSessionActive(), "A stopped timer must keep the current fueling session active.");
        Test.assertMessage(model.isPaused(), "A stopped timer should present the session as paused.");
        Test.assertMessage(storage.hasActiveSession(), "Manual stop must retain the active session payload.");
        Test.assertMessage(!storage.hasRecoverySnapshot(), "Manual stop must not create a recovery snapshot.");

        // Phase 8: Reset is the terminal activity event.
        model.onTimerReset();

        Test.assertMessage(!model.isSessionActive(), "Timer reset should finish the session.");
        Test.assertMessage(!storage.hasActiveSession(), "A committed reset should clear the active session payload.");
        Test.assertMessage(storage.hasRecoverySnapshot(), "Timer reset should persist a recovery snapshot.");
        Test.assertMessage(model.isStoppedSession(), "Reset sessions should remain visible through the recovery layout.");

        return true;
    }

    (:test)
    static function manualStopResumeKeepsFuelingSession(logger as Test.Logger) as Boolean {
        var clock = new MockClock(15000);
        var props = new MockPropertiesBackend();
        props.setValue("carbsTargetGph", 60);
        props.setValue("doseG", 25);
        props.setValue("startDelayMin", 0);

        var sys = buildFullSystem(clock, props);
        var model = sys["model"] as FuelModel;
        var storage = sys["storage"] as StorageManager;
        var info = new MockActivityInfo(15000);
        info.timerState = Activity.TIMER_STATE_ON;
        info.setTimerSeconds(1200);
        model.compute(info);
        model.recordIntake(25);

        var sessionIdBeforeStop = storage.getSessionId();
        var elapsedBeforeStop = model.getElapsedActiveSec();

        model.onTimerStop();
        info.timerState = Activity.TIMER_STATE_STOPPED;
        model.compute(info);

        Test.assertMessage(model.isSessionActive(), "STOPPED must not split the fueling session.");
        Test.assertMessage(model.isPaused(), "STOPPED must pause the fueling session.");
        Test.assertMessage(storage.hasActiveSession(), "STOPPED must keep active storage intact.");
        Test.assertMessage(!storage.hasRecoverySnapshot(), "STOPPED must not write terminal recovery state.");
        Test.assertEqual(sessionIdBeforeStop, storage.getSessionId());
        Test.assertEqual(250, model.getConsumedTotalG10());
        Test.assertEqual(1, model.getIntakeCount());
        Test.assertEqual(elapsedBeforeStop, model.getElapsedActiveSec());

        clock.advance(30);
        model.onTimerResume();
        info.timerState = Activity.TIMER_STATE_ON;
        info.advanceTimerSeconds(1);
        model.compute(info);

        logger.debug("manualResumeElapsed=" + model.getElapsedActiveSec().format("%d"));
        Test.assertMessage(model.isSessionActive(), "Resume must continue the existing fueling session.");
        Test.assertMessage(!model.isPaused(), "Resume must leave paused state.");
        Test.assertEqual(sessionIdBeforeStop, storage.getSessionId());
        Test.assertEqual(250, model.getConsumedTotalG10());
        Test.assertEqual(1, model.getIntakeCount());
        Test.assertEqual(elapsedBeforeStop + 1, model.getElapsedActiveSec());
        return true;
    }

    (:test)
    static function pauseResumeLifecycle(logger as Test.Logger) as Boolean {
        var clock = new MockClock(20000);
        var props = new MockPropertiesBackend();
        props.setValue("carbsTargetGph", 60);
        props.setValue("doseG", 25);
        props.setValue("startDelayMin", 0);

        var sys = buildFullSystem(clock, props);
        var model = sys["model"] as FuelModel;

        // Start activity
        var info = new MockActivityInfo(20000);
        info.setTimerSeconds(0);
        model.compute(info);

        clock.advance(1);
        info.advanceTimerSeconds(1);
        model.compute(info);

        // Progress 5 minutes
        for (var i = 0; i < 300; i += 1) {
            clock.advance(1);
            info.advanceTimerSeconds(1);
            model.compute(info);
        }

        var deficitBeforePause = model.getDeficitG10();
        var elapsedBeforePause = model.getElapsedActiveSec();
        logger.debug("deficitBeforePauseG10=" + deficitBeforePause.format("%d"));

        // Pause
        model.onTimerPause();
        info.timerState = Activity.TIMER_STATE_PAUSED;
        model.compute(info);

        Test.assertMessage(model.isPaused(), "Should be paused");
        var deficitWhilePaused = model.getDeficitG10();

        // Advance time while paused (should not change deficit)
        for (var i = 0; i < 120; i += 1) {
            clock.advance(1);
            model.compute(info);
        }

        var deficitAfterPauseTime = model.getDeficitG10();
        Test.assertEqual(deficitWhilePaused, deficitAfterPauseTime);

        // Resume
        model.onTimerResume();
        info.timerState = Activity.TIMER_STATE_ON;
        clock.advance(1);
        info.advanceTimerSeconds(1);
        model.compute(info);

        Test.assertMessage(!model.isPaused(), "Should not be paused after resume");
        Test.assertEqual(elapsedBeforePause + 1, model.getElapsedActiveSec());

        // Stop is non-terminal; reset finishes the activity.
        model.onTimerStop();
        info.timerState = Activity.TIMER_STATE_STOPPED;
        model.compute(info);
        Test.assertMessage(model.isSessionActive(), "Manual stop should keep the session active.");

        model.onTimerReset();
        Test.assertMessage(!model.isSessionActive(), "Session should be finished");

        return true;
    }

    (:test)
    static function settingsChangeDuringSession(logger as Test.Logger) as Boolean {
        var clock = new MockClock(30000);
        var props = new MockPropertiesBackend();
        props.setValue("carbsTargetGph", 60);
        props.setValue("doseG", 25);
        props.setValue("startDelayMin", 0);

        var sys = buildFullSystem(clock, props);
        var model = sys["model"] as FuelModel;

        // Start activity
        var info = new MockActivityInfo(30000);
        info.setTimerSeconds(0);
        model.compute(info);

        clock.advance(1);
        info.advanceTimerSeconds(1);
        model.compute(info);

        // Progress 5 minutes
        for (var i = 0; i < 300; i += 1) {
            clock.advance(1);
            info.advanceTimerSeconds(1);
            model.compute(info);
        }

        Test.assertEqual(60, model.getCarbsTargetGph());

        // Change settings externally (e.g., from Garmin Connect)
        props.setValue("carbsTargetGph", 90);
        model.onSettingsChanged();

        Test.assertEqual(90, model.getCarbsTargetGph());
        Test.assertMessage(model.isSessionActive(), "Session should still be active after settings change");

        return true;
    }

    (:test)
    static function reminderCycleIntegration(logger as Test.Logger) as Boolean {
        var clock = new MockClock(40000);
        var props = new MockPropertiesBackend();
        props.setValue("carbsTargetGph", 60);
        props.setValue("doseG", 25);
        props.setValue("startDelayMin", 0);
        props.setValue("reminderMode", 0); // MODE_AUTO

        var sys = buildFullSystem(clock, props);
        var model = sys["model"] as FuelModel;
        model.setTouchForTest(false); // Non-touch for auto-intake

        // Start activity
        var info = new MockActivityInfo(40000);
        info.setTimerSeconds(0);
        model.compute(info);

        clock.advance(1);
        info.advanceTimerSeconds(1);
        model.compute(info);

        // On non-touch devices, auto-flow books the intake during the due compute tick.
        // At 60 g/h, 25 minutes reaches the 25g dose threshold.
        for (var i = 0; i < 1500; i += 1) {
            clock.advance(1);
            info.advanceTimerSeconds(1);
            model.compute(info);

            if (model.getIntakeCount() > 0) {
                logger.debug("Auto intake at tick " + i.format("%d"));
                break;
            }
        }

        Test.assertMessage(model.getIntakeCount() > 0, "Should have recorded at least one intake");
        Test.assertMessage(!model.isReminderDue(), "Reminder should be cleared after auto-intake");

        return true;
    }

    (:test)
    static function sessionRecoveryAfterRestart(logger as Test.Logger) as Boolean {
        var clock = new MockClock(50000);
        var props = new MockPropertiesBackend();
        props.setValue("carbsTargetGph", 60);
        props.setValue("doseG", 25);
        props.setValue("startDelayMin", 0);

        var storageBackend = new MockStorageBackend();
        var storage = new StorageManager(storageBackend, props);

        // Phase 1: Start session and save
        var model1 = new FuelModel(storage, clock);
        model1.setTouchForTest(true);

        var info = new MockActivityInfo(50000);
        info.setTimerSeconds(0);
        model1.compute(info);

        clock.advance(1);
        info.advanceTimerSeconds(1);
        model1.compute(info);

        // Progress 10 minutes
        for (var i = 0; i < 600; i += 1) {
            clock.advance(1);
            info.advanceTimerSeconds(1);
            model1.compute(info);
        }

        // Record some intake
        model1.recordIntake(25);
        model1.recordIntake(25);

        var consumedBeforeCrash = model1.getConsumedTotalG10();
        var elapsedBeforeCrash = model1.getElapsedActiveSec();
        logger.debug("consumedBeforeCrashG10=" + consumedBeforeCrash.format("%d"));
        logger.debug("elapsedBeforeCrash=" + elapsedBeforeCrash.format("%d"));

        // Phase 2: Simulate crash and restart
        var model2 = new FuelModel(storage, clock);
        model2.setTouchForTest(true);
        model2.loadSession();

        // Phase 3: Verify recovery
        Test.assertMessage(model2.isSessionActive(), "Session should be recovered");
        Test.assertEqual(consumedBeforeCrash, model2.getConsumedTotalG10());
        Test.assertEqual(elapsedBeforeCrash, model2.getElapsedActiveSec());
        Test.assertEqual(2, model2.getIntakeCount());

        // Phase 4: Continue session
        info = new MockActivityInfo(50000);
        info.setTimerSeconds(elapsedBeforeCrash + 1);
        model2.compute(info);

        Test.assertMessage(model2.isSessionActive(), "Session should still be active after continuation");

        return true;
    }

    (:test)
    static function resetSessionRecoveryAfterRestart(logger as Test.Logger) as Boolean {
        var clock = new MockClock(55000);
        var props = new MockPropertiesBackend();
        props.setValue("carbsTargetGph", 60);
        props.setValue("doseG", 25);
        props.setValue("startDelayMin", 0);

        var storageBackend = new MockStorageBackend();
        var storage = new StorageManager(storageBackend, props);

        var model1 = new FuelModel(storage, clock);
        model1.setTouchForTest(true);

        var info = new MockActivityInfo(55000);
        info.setTimerSeconds(0);
        model1.compute(info);

        clock.advance(1);
        info.advanceTimerSeconds(1);
        model1.compute(info);

        for (var i = 0; i < 900; i += 1) {
            clock.advance(1);
            info.advanceTimerSeconds(1);
            model1.compute(info);
        }

        model1.onTimerStop();
        info.timerState = Activity.TIMER_STATE_STOPPED;
        model1.compute(info);
        Test.assertMessage(model1.isSessionActive(), "Manual stop must stay recoverable as the active session.");
        model1.onTimerReset();

        var model2 = new FuelModel(storage, clock);
        model2.setTouchForTest(true);
        model2.loadSession();

        Test.assertMessage(model2.isStoppedSession(), "Reset session should restore in recovery after restart.");
        Test.assertMessage(!model2.isSessionActive(), "Reset session should not restore as active.");
        Test.assertMessage(model2.getRecoveryDeficit() != null, "Reset session should keep recovery metrics available after restart.");
        return true;
    }

    (:test)
    static function calorieAutoFallbackIntegration(logger as Test.Logger) as Boolean {
        var clock = new MockClock(60000);
        var props = new MockPropertiesBackend();
        props.setValue("carbsTargetGph", 60);
        props.setValue("doseG", 25);
        props.setValue("reminderMode", 2); // MODE_CALORIE_AUTO
        props.setValue("startDelayMin", 0);

        var sys = buildFullSystem(clock, props);
        var model = sys["model"] as FuelModel;

        // Start activity
        var info = new MockActivityInfo(60000);
        info.setTimerSeconds(0);
        model.compute(info);

        clock.advance(1);
        info.advanceTimerSeconds(1);
        model.compute(info);

        // Initial: MODE_CALORIE_AUTO
        Test.assertEqual(FuelReminderModes.CALORIE_AUTO, model.getReminderMode());

        // Simulate 6 minutes without calorie data (360 ticks)
        // Fallback should happen at tick 300 (5 minutes)
        var fallbackTick = -1;
        for (var i = 0; i < 360; i += 1) {
            clock.advance(1);
            info.advanceTimerSeconds(1);
            model.compute(info);

            if (model.getReminderMode() == FuelReminderModes.AUTO && fallbackTick < 0) {
                fallbackTick = i;
                logger.debug("Fallback at tick " + i.format("%d"));
            }
        }

        Test.assertMessage(fallbackTick >= 0, "Should have fallen back to MODE_AUTO");
        Test.assertMessage(fallbackTick <= 300, "Fallback should happen at or before 300 ticks");
        Test.assertEqual(FuelReminderModes.AUTO, model.getReminderMode());

        // Continue with MODE_AUTO
        Test.assertMessage(model.isSessionActive(), "Session should still be active");

        return true;
    }

    (:test)
    static function multipleIntakesAndDeficitTracking(logger as Test.Logger) as Boolean {
        var clock = new MockClock(70000);
        var props = new MockPropertiesBackend();
        props.setValue("carbsTargetGph", 60);
        props.setValue("doseG", 25);
        props.setValue("startDelayMin", 0);

        var sys = buildFullSystem(clock, props);
        var model = sys["model"] as FuelModel;

        // Start activity
        var info = new MockActivityInfo(70000);
        info.setTimerSeconds(0);
        model.compute(info);

        clock.advance(1);
        info.advanceTimerSeconds(1);
        model.compute(info);

        // Progress 30 minutes = 30g target
        for (var i = 0; i < 1800; i += 1) {
            clock.advance(1);
            info.advanceTimerSeconds(1);
            model.compute(info);
        }

        Test.assertEqual(300, model.getTargetTotalG10());

        // Record 3 intakes of 25g = 75g consumed
        model.recordIntake(25);
        model.recordIntake(25);
        model.recordIntake(25);

        Test.assertEqual(750, model.getConsumedTotalG10());
        Test.assertEqual(3, model.getIntakeCount());

        // Deficit should be negative (surplus)
        var deficitG10 = model.getDeficitG10();
        Test.assertMessage(deficitG10 < 0, "Should have surplus (negative deficit)");
        Test.assertEqual(-450, deficitG10);

        return true;
    }

    (:test)
    static function startDelayPreventsEarlyReminder(logger as Test.Logger) as Boolean {
        var clock = new MockClock(80000);
        var props = new MockPropertiesBackend();
        props.setValue("carbsTargetGph", 60);
        props.setValue("doseG", 25);
        props.setValue("startDelayMin", 15); // 15 minute delay

        var sys = buildFullSystem(clock, props);
        var model = sys["model"] as FuelModel;

        // Start activity
        var info = new MockActivityInfo(80000);
        info.setTimerSeconds(0);
        model.compute(info);

        clock.advance(1);
        info.advanceTimerSeconds(1);
        model.compute(info);

        // Progress 14 minutes (before delay)
        for (var i = 0; i < 840; i += 1) {
            clock.advance(1);
            info.advanceTimerSeconds(1);
            model.compute(info);
        }

        Test.assertMessage(!model.isReminderDue(), "Should not have reminder before start delay");

        // Progress past 15 minutes
        for (var i = 0; i < 60; i += 1) {
            clock.advance(1);
            info.advanceTimerSeconds(1);
            model.compute(info);
        }

        // Now at 15 minutes, but deficit is only 15g < 25g dose
        // So reminder might not be due yet depending on mode
        logger.debug("elapsedSec=" + model.getElapsedActiveSec().format("%d"));
        logger.debug("deficitG10=" + model.getDeficitG10().format("%d"));
        logger.debug("isReminderDue=" + boolToAscii(model.isReminderDue()));

        return true;
    }

    (:test)
    static function fixedIntervalReminderMode(logger as Test.Logger) as Boolean {
        var clock = new MockClock(90000);
        var props = new MockPropertiesBackend();
        props.setValue("carbsTargetGph", 60);
        props.setValue("doseG", 25);
        props.setValue("reminderMode", 1); // MODE_FIXED
        props.setValue("fixedIntervalMin", 20);
        props.setValue("startDelayMin", 0);

        var sys = buildFullSystem(clock, props);
        var model = sys["model"] as FuelModel;
        model.setTouchForTest(false);

        // Start activity
        var info = new MockActivityInfo(90000);
        info.setTimerSeconds(0);
        model.compute(info);

        clock.advance(1);
        info.advanceTimerSeconds(1);
        model.compute(info);

        // Non-touch fixed mode books the planned intake when the interval becomes due.
        for (var i = 0; i < 1200; i += 1) {
            clock.advance(1);
            info.advanceTimerSeconds(1);
            model.compute(info);
        }

        Test.assertMessage(model.getIntakeCount() > 0, "First fixed-interval due tick should auto-book intake.");
        Test.assertMessage(!model.isReminderDue(), "Auto-flow should clear the due reminder.");

        var intakeCountAfterFirstInterval = model.getIntakeCount();
        for (var i = 0; i < 1140; i += 1) {
            clock.advance(1);
            info.advanceTimerSeconds(1);
            model.compute(info);
        }

        Test.assertEqual(intakeCountAfterFirstInterval, model.getIntakeCount());

        for (var i = 0; i < 60; i += 1) {
            clock.advance(1);
            info.advanceTimerSeconds(1);
            model.compute(info);
        }

        Test.assertMessage(model.getIntakeCount() > intakeCountAfterFirstInterval, "Second fixed interval should auto-book another intake.");

        return true;
    }
}
