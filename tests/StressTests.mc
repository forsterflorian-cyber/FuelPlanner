using Toybox.Test;
import Toybox.Lang;

class StressTests {

    static function buildContext(now as Number) as Dictionary {
        var clock = new MockClock(now);
        var props = new MockPropertiesBackend();
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

    static function applyDefaultRaceSettings(props as MockPropertiesBackend,
                                            model as FuelModel) as Void {
        props.setValue("carbsTargetGph", 60);
        props.setValue("doseG", 25);
        props.setValue("startDelayMin", 0);
        props.setValue("maxSnoozeMin", 5);
        props.setValue("reminderMode", 0);
        props.setValue("carbFractionPct", 60);
        model.onSettingsChanged();
    }

    (:test)
    static function surplusScenarioStaysDeterministic(logger as Test.Logger) as Boolean {
        var ctx = buildContext(1000);
        var clock = ctx["clock"] as MockClock;
        var props = ctx["props"] as MockPropertiesBackend;
        var model = ctx["model"] as FuelModel;
        applyDefaultRaceSettings(props, model);

        var info = new MockActivityInfo(1000);
        info.setTimerSeconds(1800);
        model.compute(info);
        logFuelStatus(logger, "surplus_baseline", model);

        model.recordIntake(50);
        clock.advance(1);
        model.recordIntake(50);
        clock.advance(1);
        model.recordIntake(50);
        model.compute(info);
        logFuelStatus(logger, "surplus_after_150g", model);

        var gaugeAfterSurplus = FuelPlannerUtils.getGaugeAlertTone(model.getDeficitG10(), model.getDoseG10());

        info.setTimerSeconds(8940);
        model.compute(info);
        logFuelStatus(logger, "surplus_before_zero_cross", model);
        var gaugeBeforeZero = FuelPlannerUtils.getGaugeAlertTone(model.getDeficitG10(), model.getDoseG10());

        info.setTimerSeconds(9060);
        model.compute(info);
        logFuelStatus(logger, "surplus_after_zero_cross", model);
        var gaugeAfterZero = FuelPlannerUtils.getGaugeAlertTone(model.getDeficitG10(), model.getDoseG10());

        Test.assertMessage(model.getConsumedTotalG10() == 1500, "Three double doses should book exactly 150g.");
        Test.assertEqual(1500, model.getConsumedTotalG10());
        Test.assertEqual(0, gaugeAfterSurplus);  // GREEN = 0
        Test.assertEqual(0, gaugeBeforeZero);    // GREEN = 0
        Test.assertEqual(1, gaugeAfterZero);     // ORANGE = 1
        Test.assertMessage(model.getDeficitG10() == 10, "At 151 minutes the 150g surplus should have decayed to a 1g deficit.");
        Test.assertEqual(10, model.getDeficitG10());
        Test.assertMessage(!model.isReminderDue(), "A small positive deficit after a large surplus must not retrigger reminders early.");
        return true;
    }

    (:test)
    static function modeSwitchStressKeepsCurveContinuous(logger as Test.Logger) as Boolean {
        var ctx = buildContext(2000);
        var clock = ctx["clock"] as MockClock;
        var props = ctx["props"] as MockPropertiesBackend;
        var model = ctx["model"] as FuelModel;
        applyDefaultRaceSettings(props, model);

        var info = new MockActivityInfo(2000);
        info.setTimerSeconds(1800);
        info.setCalories(200);
        info.setEnergyExpenditure(12.0f);

        model.compute(info);
        clock.setNow(2050);
        model.recordIntake(20);
        model.compute(info);
        logFuelStatus(logger, "mode_switch_before", model);
        var deficitBeforeSwitch = model.getDeficitG10();

        props.setValue("reminderMode", 2);
        props.setValue("carbFractionPct", 60);
        model.onSettingsChanged();
        model.compute(info);
        logFuelStatus(logger, "mode_switch_after", model);
        var deficitAfterSwitch = model.getDeficitG10();
        var immediateDelta = absNumber(deficitAfterSwitch - deficitBeforeSwitch);

        info.setTimerSeconds(1860);
        info.setCalories(208);
        info.setEnergyExpenditure(13.0f);
        model.compute(info);
        logFuelStatus(logger, "mode_switch_next_tick", model);
        var nextTickDelta = model.getDeficitG10() - deficitAfterSwitch;

        Test.assertMessage(immediateDelta <= 10, "Switching to calorie mode should not create a visible deficit jump when the targets align.");
        Test.assertMessage(nextTickDelta >= 0, "Deficit should keep moving forward after the mode switch.");
        Test.assertMessage(nextTickDelta <= 20, "The first post-switch tick should stay smooth and bounded.");
        Test.assertMessage(!model.isReminderDue(), "Aligned mode switching should not create a phantom reminder.");
        return true;
    }

    (:test)
    static function crashRecoveryRestoresLastBufferedState(logger as Test.Logger) as Boolean {
        var ctx = buildContext(5000);
        var clock = ctx["clock"] as MockClock;
        var props = ctx["props"] as MockPropertiesBackend;
        var storageBackend = ctx["storageBackend"] as MockStorageBackend;
        var model = ctx["model"] as FuelModel;
        applyDefaultRaceSettings(props, model);

        var info = new MockActivityInfo(1234);
        info.setTimerSeconds(900);
        model.compute(info);
        logFuelStatus(logger, "crash_before_intake", model);

        clock.setNow(5050);
        model.recordIntake(25);
        logger.debug(
            "crash_after_intake consumedG10=" + model.getConsumedTotalG10().format("%d") +
            " intakeCount=" + model.getIntakeCount().format("%d")
        );

        var crashState = simulateCrash(storageBackend, props, 5100);
        var restoredModel = crashState["model"] as FuelModel;
        restoredModel.compute(info);
        logFuelStatus(logger, "crash_after_reload", restoredModel);

        Test.assertMessage(restoredModel.getConsumedTotalG10() == 250, "Booked carbs must survive a crash without onTimerLap.");
        Test.assertEqual(250, restoredModel.getConsumedTotalG10());
        Test.assertMessage(restoredModel.getIntakeCount() == 1, "Intake count must survive the crash.");
        Test.assertEqual(1, restoredModel.getIntakeCount());
        Test.assertMessage(restoredModel.getDeficitG10() == -100, "Reloaded model should recompute the negative surplus correctly after the crash.");
        Test.assertEqual(-100, restoredModel.getDeficitG10());
        return true;
    }

    (:test)
    static function extremeClampingAvoidsDivisionByZero(logger as Test.Logger) as Boolean {
        var ctx = buildContext(7000);
        var props = ctx["props"] as MockPropertiesBackend;
        var model = ctx["model"] as FuelModel;
        applyDefaultRaceSettings(props, model);

        var info = new MockActivityInfo(7000);
        info.setTimerSeconds(600);
        model.compute(info);
        logFuelStatus(logger, "clamp_before", model);

        props.setValue("carbsTargetGph", 0);
        props.setValue("doseG", 0);
        model.onSettingsChanged();
        model.compute(info);
        logFuelStatus(logger, "clamp_after_same_tick", model);

        info.setTimerSeconds(660);
        model.compute(info);
        logFuelStatus(logger, "clamp_after_next_tick", model);

        Test.assertMessage(model.getCarbsTargetGph() == 20, "0 g/h must clamp to the minimum target.");
        Test.assertEqual(20, model.getCarbsTargetGph());
        Test.assertMessage(model.getDoseG() == 5, "0 g gel size must clamp to the minimum dose.");
        Test.assertEqual(5, model.getDoseG());
        Test.assertMessage(model.getNextDueInSec() >= 0, "nextDueInSec must remain finite and non-negative after clamping.");
        Test.assertMessage(!model.isPaused(), "Clamping edge cases must not leave the model in a broken paused state.");
        return true;
    }
}
