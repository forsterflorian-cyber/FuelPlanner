using Toybox.Test;
import Toybox.Lang;
import Toybox.Activity;

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
}
