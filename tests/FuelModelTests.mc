using Toybox.Test;
import Toybox.Lang;
import Toybox.Activity;
import FuelReminderModes;

class FuelModelTests {

    static function buildModel(clock as MockClock, props as MockPropertiesBackend) as FuelModel {
        var storageBackend = new MockStorageBackend();
        var storage = new StorageManager(storageBackend, props);
        var model = new FuelModel(storage, clock);
        model.setTouchForTest(true);
        return model;
    }

    (:test)
    static function smartPauseFreezesDeficit(logger as Test.Logger) as Boolean {
        var clock = new MockClock(1000);
        var props = new MockPropertiesBackend();
        props.setValue("carbsTargetGph", 60);
        props.setValue("doseG", 25);
        props.setValue("startDelayMin", 0);

        var model = buildModel(clock, props);
        var info = new MockActivityInfo(1000);
        info.setTimerSeconds(600);

        model.compute(info);
        var deficitBeforePause = model.getDeficitG10();
        logger.debug("deficitBeforePauseG10=" + deficitBeforePause.format("%d"));

        info.timerState = Activity.TIMER_STATE_PAUSED;
        info.setTimerSeconds(600);
        model.compute(info);
        var deficitPausedOnce = model.getDeficitG10();

        info.setTimerSeconds(900);
        model.compute(info);
        var deficitPausedTwice = model.getDeficitG10();

        Test.assertMessage(deficitBeforePause == 100, "Expected 10g deficit after 10 active minutes at 60 g/h.");
        Test.assertEqual(100, deficitBeforePause);
        Test.assertMessage(deficitPausedOnce == deficitBeforePause, "Deficit changed on first paused tick.");
        Test.assertEqual(deficitBeforePause, deficitPausedOnce);
        Test.assertMessage(deficitPausedTwice == deficitBeforePause, "Deficit changed on repeated paused ticks.");
        Test.assertEqual(deficitBeforePause, deficitPausedTwice);
        Test.assertMessage(model.getElapsedActiveSec() == 600, "elapsedActiveSec must stay frozen while timerState is paused.");
        return true;
    }

    (:test)
    static function authoritativeTimerTimeDoesNotSubtractPauseTwice(logger as Test.Logger) as Boolean {
        var clock = new MockClock(1000);
        var props = new MockPropertiesBackend();
        props.setValue("carbsTargetGph", 60);
        props.setValue("doseG", 25);
        props.setValue("startDelayMin", 0);
        var model = buildModel(clock, props);
        var info = new MockActivityInfo(1000);
        info.timerState = Activity.TIMER_STATE_ON;
        info.setTimerSeconds(600);
        info.setElapsedSeconds(600);
        model.compute(info);

        model.onTimerPause();
        info.timerState = Activity.TIMER_STATE_PAUSED;
        model.compute(info);
        clock.advance(300);
        info.setElapsedSeconds(900);
        model.compute(info);

        model.onTimerResume();
        clock.advance(1);
        info.timerState = Activity.TIMER_STATE_ON;
        info.setTimerSeconds(601);
        info.setElapsedSeconds(901);
        model.compute(info);

        logger.debug("authoritativeTimerElapsed=" + model.getElapsedActiveSec().format("%d"));
        Test.assertMessage(!model.isPaused(), "Timer resume should restore active state.");
        Test.assertEqual(601, model.getElapsedActiveSec());
        Test.assertEqual(100, model.getTargetTotalG10());
        return true;
    }

    (:test)
    static function elapsedTimeFallbackSubtractsOnlyPausedDuration(logger as Test.Logger) as Boolean {
        var clock = new MockClock(2000);
        var props = new MockPropertiesBackend();
        props.setValue("carbsTargetGph", 60);
        props.setValue("doseG", 25);
        props.setValue("startDelayMin", 0);
        var model = buildModel(clock, props);
        var info = new MockActivityInfo(2000);
        info.timerState = Activity.TIMER_STATE_ON;
        info.clearTimerTime();
        info.setElapsedSeconds(600);
        model.compute(info);

        model.onTimerPause();
        info.timerState = Activity.TIMER_STATE_PAUSED;
        model.compute(info);
        clock.advance(300);
        info.setElapsedSeconds(900);
        model.compute(info);

        model.onTimerResume();
        clock.advance(1);
        info.timerState = Activity.TIMER_STATE_ON;
        info.setElapsedSeconds(901);
        model.compute(info);

        logger.debug("elapsedFallbackActive=" + model.getElapsedActiveSec().format("%d"));
        Test.assertMessage(!model.isPaused(), "Elapsed fallback should resume after the timer callback.");
        Test.assertEqual(601, model.getElapsedActiveSec());
        Test.assertEqual(100, model.getTargetTotalG10());
        return true;
    }

    (:test)
    static function timerStartCallbackStartsLowTimerWithoutStartTime(logger as Test.Logger) as Boolean {
        var clock = new MockClock(3000);
        var props = new MockPropertiesBackend();
        props.setValue("carbsTargetGph", 60);
        props.setValue("doseG", 25);
        props.setValue("startDelayMin", 0);
        var model = buildModel(clock, props);
        var oldInfo = new MockActivityInfo(3000);
        oldInfo.setTimerSeconds(600);
        model.compute(oldInfo);
        model.recordIntake(25);
        model.onTimerReset();
        Test.assertMessage(model.isStoppedSession(), "The old activity should provide recovery before the next start.");

        clock.setNow(4000);
        var newInfo = new MockActivityInfo(null);
        newInfo.timerState = Activity.TIMER_STATE_ON;
        newInfo.setTimerSeconds(1);
        model.onTimerStart();
        model.compute(newInfo);

        Test.assertMessage(model.isSessionActive(), "onTimerStart must start a fresh session without Activity.Info.startTime.");
        Test.assertMessage(model.isPriming(), "A one-second unconfirmed timer should enter the explicit priming state.");
        Test.assertMessage(model.hasValidTimerData(), "The low positive timer sample is valid timer data.");
        Test.assertMessage(!model.isStoppedSession(), "Fresh activity state must replace the old recovery layout.");
        Test.assertEqual(0, model.getConsumedTotalG10());
        Test.assertEqual(0, model.getIntakeCount());
        return true;
    }

    (:test)
    static function resetFinalizesAfterNullTimerGap(logger as Test.Logger) as Boolean {
        var clock = new MockClock(5000);
        var props = new MockPropertiesBackend();
        props.setValue("carbsTargetGph", 60);
        props.setValue("doseG", 25);
        props.setValue("startDelayMin", 0);
        var model = buildModel(clock, props);
        var info = new MockActivityInfo(5000);
        info.setTimerSeconds(900);
        model.compute(info);
        model.recordIntake(20);

        var missingTimerInfo = new MockActivityInfo(5000);
        model.compute(missingTimerInfo);
        Test.assertMessage(model.isSessionActive(), "A null timer sample must preserve active session state.");
        Test.assertMessage(!model.hasValidTimerData(), "A null timer sample must expose the waiting/invalid state.");
        Test.assertEqual(900, model.getElapsedActiveSec());

        model.onTimerReset();
        Test.assertMessage(!model.isSessionActive(), "Reset must finalize even when the latest timer sample was null.");
        Test.assertMessage(model.isStoppedSession(), "Reset after a timer gap must retain recovery metrics.");
        Test.assertEqual(900, model.getElapsedActiveSec());
        Test.assertEqual(200, model.getConsumedTotalG10());
        Test.assertEqual(1, model.getIntakeCount());
        return true;
    }

    (:test)
    static function offStateWithNullTimerFinalizesOnce(logger as Test.Logger) as Boolean {
        var clock = new MockClock(6000);
        var props = new MockPropertiesBackend();
        props.setValue("carbsTargetGph", 60);
        props.setValue("doseG", 25);
        props.setValue("startDelayMin", 0);
        var model = buildModel(clock, props);
        var info = new MockActivityInfo(6000);
        info.setTimerSeconds(1800);
        model.compute(info);
        model.recordIntake(25);

        var offInfo = new MockActivityInfo(6000);
        offInfo.timerState = Activity.TIMER_STATE_OFF;
        model.compute(offInfo);
        var recoveryAfterOff = model.getRecoveryDeficit();

        Test.assertMessage(!model.isSessionActive(), "OFF is a terminal fallback even when timer values are unavailable.");
        Test.assertMessage(model.isStoppedSession(), "OFF fallback must preserve recovery state.");
        Test.assertEqual(1800, model.getElapsedActiveSec());
        Test.assertEqual(250, model.getConsumedTotalG10());

        model.onTimerReset();
        Test.assertEqual(recoveryAfterOff, model.getRecoveryDeficit());
        Test.assertEqual(1800, model.getElapsedActiveSec());
        return true;
    }

    (:test)
    static function calorieAutoUsesKcalFormula(logger as Test.Logger) as Boolean {
        var deficitG10 = FuelModel.calculateDeficit(
            0,
            0,
            60,
            2,
            360,
            60,
            true,
            20
        );

        logger.debug("calorieAutoDeficitG10=" + deficitG10.format("%d"));
        Test.assertMessage(deficitG10 == 540, "TargetCarbs = kcal * (CarbRatio / 100) / 4 must match 54g.");
        Test.assertEqual(540, deficitG10);
        return true;
    }

    (:test)
    static function deficitClampsAndPreservesSurplus(logger as Test.Logger) as Boolean {
        var clampedRateDeficitG10 = FuelModel.calculateDeficit(
            3600,
            0,
            0,
            0,
            0,
            60,
            false,
            20
        );

        var surplusDeficitG10 = FuelModel.calculateDeficit(
            1800,
            450,
            60,
            0,
            0,
            60,
            false,
            20
        );

        var extremeCalorieDeficitG10 = FuelModel.calculateDeficit(
            0,
            0,
            60,
            2,
            20000,
            80,
            true,
            20
        );

        logger.debug("clampedRateDeficitG10=" + clampedRateDeficitG10.format("%d"));
        logger.debug("surplusDeficitG10=" + surplusDeficitG10.format("%d"));
        logger.debug("extremeCalorieDeficitG10=" + extremeCalorieDeficitG10.format("%d"));

        Test.assertMessage(clampedRateDeficitG10 == 200, "0 g/h target must clamp to the 20 g/h minimum.");
        Test.assertEqual(200, clampedRateDeficitG10);
        Test.assertMessage(surplusDeficitG10 == -150, "Deficit must go negative when intake exceeds target.");
        Test.assertEqual(-150, surplusDeficitG10);
        Test.assertMessage(extremeCalorieDeficitG10 == 40000, "Extreme calorie values should still follow the calorie-auto formula.");
        Test.assertEqual(40000, extremeCalorieDeficitG10);
        Test.assertMessage(surplusDeficitG10 < 0, "Surplus intake must remain visible as a negative deficit.");
        return true;
    }

    (:test)
    static function missingTimerTickKeepsSessionState(logger as Test.Logger) as Boolean {
        var clock = new MockClock(8000);
        var props = new MockPropertiesBackend();
        props.setValue("carbsTargetGph", 60);
        props.setValue("doseG", 25);
        props.setValue("startDelayMin", 0);

        var model = buildModel(clock, props);
        var activeInfo = new MockActivityInfo(8000);
        activeInfo.setTimerSeconds(900);
        model.compute(activeInfo);

        var elapsedBeforeGap = model.getElapsedActiveSec();
        var deficitBeforeGap = model.getDeficitG10();

        var missingTimerInfo = new MockActivityInfo(8000);
        model.compute(missingTimerInfo);

        logger.debug("elapsedBeforeGap=" + elapsedBeforeGap.format("%d"));
        logger.debug("deficitBeforeGapG10=" + deficitBeforeGap.format("%d"));

        Test.assertMessage(model.isSessionActive(), "A missing timer tick must not tear down the active session.");
        Test.assertEqual(elapsedBeforeGap, model.getElapsedActiveSec());
        Test.assertEqual(deficitBeforeGap, model.getDeficitG10());
        Test.assertMessage(!model.isReminderDue(), "A missing timer tick should suppress the reminder instead of retriggering it.");
        return true;
    }

    (:test)
    static function storageFailureTracking(logger as Test.Logger) as Boolean {
        var props = new MockPropertiesBackend();
        var storageBackend = new MockStorageBackend();
        var storage = new StorageManager(storageBackend, props);

        // Initial state: no failures
        Test.assertEqual(0, storage.getWriteFailureCount());
        Test.assertEqual("", storage.getLastWriteFailureKey());

        // Normal write should succeed
        storage.setCarbsTargetGph(60);
        Test.assertEqual(0, storage.getWriteFailureCount());

        return true;
    }

    (:test)
    static function calorieAutoFallback(logger as Test.Logger) as Boolean {
        var clock = new MockClock(1000);
        var props = new MockPropertiesBackend();
        props.setValue("carbsTargetGph", 60);
        props.setValue("doseG", 25);
        props.setValue("reminderMode", 2); // MODE_CALORIE_AUTO
        props.setValue("startDelayMin", 0);

        var model = buildModel(clock, props);
        var info = new MockActivityInfo(1000);
        info.setTimerSeconds(60);

        // Initial: MODE_CALORIE_AUTO
        Test.assertEqual(FuelReminderModes.CALORIE_AUTO, model.getReminderMode());

        // Simulate 5 minutes without calorie data (300 ticks)
        for (var i = 0; i < 305; i += 1) {
            clock.advance(1);
            info.advanceTimerSeconds(1);
            model.compute(info);
        }

        // Should have fallen back to MODE_AUTO
        Test.assertEqual(FuelReminderModes.AUTO, model.getReminderMode());
        return true;
    }

    (:test)
    static function ringToneUsesVisibleDeficitBeforeStartDelay(logger as Test.Logger) as Boolean {
        var clock = new MockClock(1000);
        var props = new MockPropertiesBackend();
        props.setValue("reminderMode", 2);
        props.setValue("doseG", 25);
        props.setValue("carbFractionPct", 60);
        props.setValue("startDelayMin", 15);

        var model = buildModel(clock, props);
        var info = new MockActivityInfo(1000);

        info.setTimerSeconds(600);
        info.setCalories(60);
        info.setEnergyExpenditure(12.0f);
        model.compute(info);
        Test.assertEqual(0, model.getRingTone());

        info.setTimerSeconds(720);
        info.setCalories(153);
        info.setEnergyExpenditure(12.75f);
        model.compute(info);
        Test.assertEqual(1, model.getRingTone());

        info.setTimerSeconds(840);
        info.setCalories(187);
        info.setEnergyExpenditure(13.35f);
        model.compute(info);
        Test.assertEqual(2, model.getRingTone());

        return true;
    }

    (:test)
    static function ringToneUsesFixedIntervalWindow(logger as Test.Logger) as Boolean {
        var clock = new MockClock(2000);
        var props = new MockPropertiesBackend();
        props.setValue("reminderMode", 1);
        props.setValue("fixedIntervalMin", 20);
        props.setValue("doseG", 25);
        props.setValue("startDelayMin", 0);

        var model = buildModel(clock, props);
        var info = new MockActivityInfo(2000);
        info.setTimerSeconds(60);
        model.compute(info);
        model.recordIntake(25);

        clock.setNow(2840);
        info.setTimerSeconds(900);
        model.compute(info);
        Test.assertEqual(0, model.getRingTone());

        clock.setNow(2960);
        info.setTimerSeconds(960);
        model.compute(info);
        Test.assertEqual(1, model.getRingTone());

        clock.setNow(3260);
        info.setTimerSeconds(1260);
        model.compute(info);
        Test.assertEqual(2, model.getRingTone());

        return true;
    }

    (:test)
    static function ringToneCalorieAutoTurnsRedWhenBehindDose(logger as Test.Logger) as Boolean {
        var clock = new MockClock(3000);
        var props = new MockPropertiesBackend();
        props.setValue("reminderMode", 2);
        props.setValue("doseG", 25);
        props.setValue("carbFractionPct", 60);
        props.setValue("startDelayMin", 0);

        var model = buildModel(clock, props);
        var info = new MockActivityInfo(3000);
        info.setTimerSeconds(600);
        info.setCalories(187);
        info.setEnergyExpenditure(12.0f);
        model.compute(info);

        Test.assertEqual(281, model.getDeficitG10());
        Test.assertEqual(2, model.getRingTone());
        return true;
    }

    (:test)
    static function dataFieldAlertRequiresNativeCapability(logger as Test.Logger) as Boolean {
        var clock = new MockClock(3500);
        var props = new MockPropertiesBackend();
        props.setValue("dataFieldAlertEnabled", 1);

        var model = buildModel(clock, props);
        Test.assertMessage(model.supportsNativeDataFieldAlert(), "FR955 full-tier test target should expose native data field alerts.");
        Test.assertMessage(model.isDataFieldAlertEnabled(), "Effective alert state should be enabled on supported devices when the setting is on.");
        return true;
    }

    (:test)
    static function undoIntake(logger as Test.Logger) as Boolean {
        var clock = new MockClock(1000);
        var props = new MockPropertiesBackend();
        props.setValue("carbsTargetGph", 60);
        props.setValue("doseG", 25);
        props.setValue("startDelayMin", 0);

        var model = buildModel(clock, props);
        var info = new MockActivityInfo(1000);
        info.setTimerSeconds(60);
        model.compute(info);

        // Record intake
        model.recordIntake(25);
        Test.assertEqual(250, model.getConsumedTotalG10());
        Test.assertEqual(1, model.getIntakeCount());
        Test.assertMessage(model.isUndoAvailable(), "Undo should be available immediately after intake");

        // Undo within 10 seconds
        clock.advance(5);
        var undoSuccess = model.undoLastIntake();
        Test.assertMessage(undoSuccess, "Undo should succeed within 10 seconds");
        Test.assertEqual(0, model.getConsumedTotalG10());
        Test.assertEqual(0, model.getIntakeCount());
        Test.assertMessage(!model.isUndoAvailable(), "Undo should not be available after undo");

        return true;
    }

    (:test)
    static function undoIntakeTimeout(logger as Test.Logger) as Boolean {
        var clock = new MockClock(2000);
        var props = new MockPropertiesBackend();
        props.setValue("carbsTargetGph", 60);
        props.setValue("doseG", 25);
        props.setValue("startDelayMin", 0);

        var model = buildModel(clock, props);
        var info = new MockActivityInfo(2000);
        info.setTimerSeconds(60);
        model.compute(info);

        // Record intake
        model.recordIntake(25);
        Test.assertMessage(model.isUndoAvailable(), "Undo should be available immediately");

        // Advance time beyond 10 seconds
        clock.advance(11);
        Test.assertMessage(!model.isUndoAvailable(), "Undo should not be available after 10 seconds");

        // Try to undo
        var undoSuccess = model.undoLastIntake();
        Test.assertMessage(!undoSuccess, "Undo should fail after timeout");
        Test.assertEqual(250, model.getConsumedTotalG10());

        return true;
    }

    (:test)
    static function undoMultipleIntakes(logger as Test.Logger) as Boolean {
        var clock = new MockClock(3000);
        var props = new MockPropertiesBackend();
        props.setValue("carbsTargetGph", 60);
        props.setValue("doseG", 25);
        props.setValue("startDelayMin", 0);

        var model = buildModel(clock, props);
        var info = new MockActivityInfo(3000);
        info.setTimerSeconds(60);
        model.compute(info);

        // Record first intake
        model.recordIntake(25);
        Test.assertEqual(250, model.getConsumedTotalG10());
        Test.assertEqual(1, model.getIntakeCount());

        // Undo first intake
        clock.advance(5);
        model.undoLastIntake();
        Test.assertEqual(0, model.getConsumedTotalG10());
        Test.assertEqual(0, model.getIntakeCount());

        // Record second intake
        model.recordIntake(30);
        Test.assertEqual(300, model.getConsumedTotalG10());
        Test.assertEqual(1, model.getIntakeCount());
        Test.assertMessage(model.isUndoAvailable(), "Undo should be available for second intake");

        return true;
    }

    (:test)
    static function undoRemainingSecDecrements(logger as Test.Logger) as Boolean {
        var clock = new MockClock(6000);
        var props = new MockPropertiesBackend();
        props.setValue("carbsTargetGph", 60);
        props.setValue("doseG", 25);
        props.setValue("startDelayMin", 0);

        var model = buildModel(clock, props);
        var info = new MockActivityInfo(6000);
        info.setTimerSeconds(60);
        model.compute(info);

        // Record intake
        model.recordIntake(25);
        var remainingAtStart = model.getUndoRemainingSec();
        Test.assertMessage(remainingAtStart >= 9, "Undo should have at least 9 seconds remaining at start");
        Test.assertMessage(remainingAtStart <= 10, "Undo should have at most 10 seconds remaining at start");

        // Advance 3 seconds
        clock.advance(3);
        var remainingAfter3 = model.getUndoRemainingSec();
        Test.assertMessage(remainingAfter3 >= 6, "Undo should have at least 6 seconds remaining after 3 seconds");
        Test.assertMessage(remainingAfter3 <= 7, "Undo should have at most 7 seconds remaining after 3 seconds");

        // Advance 7 more seconds (total 10)
        clock.advance(7);
        var remainingAfter10 = model.getUndoRemainingSec();
        Test.assertEqual(0, remainingAfter10);

        return true;
    }

    (:test)
    static function undoStateClearsWhenNewSessionStarts(logger as Test.Logger) as Boolean {
        var clock = new MockClock(1000);
        var props = new MockPropertiesBackend();
        props.setValue("carbsTargetGph", 60);
        props.setValue("doseG", 25);
        props.setValue("startDelayMin", 0);

        var model = buildModel(clock, props);
        var info = new MockActivityInfo(1000);
        info.setTimerSeconds(60);
        model.compute(info);

        model.recordIntake(25);
        Test.assertMessage(model.isUndoAvailable(), "Undo should be available after the first-session intake.");

        model.onTimerStop();
        info.timerState = Activity.TIMER_STATE_STOPPED;
        model.compute(info);
        Test.assertMessage(model.isSessionActive(), "Manual stop must not finish the first session.");
        model.onTimerReset();
        Test.assertMessage(model.isStoppedSession(), "Timer reset should leave a recovery snapshot.");

        clock.setNow(1006);
        var nextInfo = new MockActivityInfo(1006);
        nextInfo.setTimerSeconds(1);
        model.compute(nextInfo);

        Test.assertMessage(model.isSessionActive(), "A new activity should start a fresh session.");
        Test.assertMessage(!model.isUndoAvailable(), "Undo state must not carry from the previous session.");
        Test.assertEqual(0, model.getConsumedTotalG10());
        Test.assertEqual(0, model.getIntakeCount());
        return true;
    }

    (:test)
    static function calorieAutoRecovery(logger as Test.Logger) as Boolean {
        var clock = new MockClock(4000);
        var props = new MockPropertiesBackend();
        props.setValue("carbsTargetGph", 60);
        props.setValue("doseG", 25);
        props.setValue("reminderMode", 2); // MODE_CALORIE_AUTO
        props.setValue("startDelayMin", 0);

        var model = buildModel(clock, props);
        var info = new MockActivityInfo(4000);
        info.setTimerSeconds(60);

        // Initial: MODE_CALORIE_AUTO
        Test.assertEqual(FuelReminderModes.CALORIE_AUTO, model.getReminderMode());

        // Simulate 5 minutes without calorie data (300 ticks)
        for (var i = 0; i < 305; i += 1) {
            clock.advance(1);
            info.advanceTimerSeconds(1);
            model.compute(info);
        }

        // Should have fallen back to MODE_AUTO
        Test.assertEqual(FuelReminderModes.AUTO, model.getReminderMode());

        // Simulate 10 more minutes (600 seconds) - recovery window opens
        for (var i = 0; i < 600; i += 1) {
            clock.advance(1);
            info.advanceTimerSeconds(1);
        }

        // Now add calorie data
        info.setCalories(100);
        info.setEnergyExpenditure(10.0f);
        model.compute(info);

        // Should have recovered to MODE_CALORIE_AUTO
        Test.assertEqual(FuelReminderModes.CALORIE_AUTO, model.getReminderMode());

        return true;
    }

    (:test)
    static function timerBacktrackDoesNotResetSession(logger as Test.Logger) as Boolean {
        var clock = new MockClock(5000);
        var props = new MockPropertiesBackend();
        props.setValue("carbsTargetGph", 60);
        props.setValue("doseG", 25);
        props.setValue("startDelayMin", 0);

        var model = buildModel(clock, props);
        var info = new MockActivityInfo(5000);
        info.setTimerSeconds(0);
        model.compute(info);

        clock.advance(1);
        info.advanceTimerSeconds(1);
        model.compute(info);

        // Progress 10 minutes
        for (var i = 0; i < 600; i += 1) {
            clock.advance(1);
            info.advanceTimerSeconds(1);
            model.compute(info);
        }

        var elapsedBeforeGlitch = model.getElapsedActiveSec();
        logger.debug("elapsedBeforeGlitch=" + elapsedBeforeGlitch.format("%d"));

        // Simulate a timer glitch: timer jumps back by 25 seconds for 5 ticks.
        // The 30-second reset delta must reject it regardless of confirmation ticks.
        for (var i = 0; i < 5; i += 1) {
            clock.advance(1);
            info.setTimerSeconds(580); // 25 seconds behind
            model.compute(info);
        }

        // Session should still be active
        Test.assertMessage(model.isSessionActive(), "Session should survive timer glitch with new thresholds");
        Test.assertMessage(elapsedBeforeGlitch == 601, "Elapsed time should not be reset by timer glitch");

        return true;
    }
}
