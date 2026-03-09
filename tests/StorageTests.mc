using Toybox.Test;
import Toybox.Lang;

class StorageTests {

    static function buildStorage(props as MockPropertiesBackend,
                                 storageBackend as MockStorageBackend) as StorageManager {
        return new StorageManager(storageBackend, props);
    }

    static function buildModel(storage as StorageManager, clock as MockClock) as FuelModel {
        var model = new FuelModel(storage, clock);
        model.setTouchForTest(true);
        return model;
    }

    (:test)
    static function lapStorageWritesCurrentValues(logger as Test.Logger) as Boolean {
        var storageBackend = new MockStorageBackend();
        var props = new MockPropertiesBackend();
        props.setValue("carbsTargetGph", 60);
        props.setValue("doseG", 25);
        props.setValue("startDelayMin", 0);

        var storage = buildStorage(props, storageBackend);
        var clock = new MockClock(1000);
        var model = buildModel(storage, clock);
        var info = new MockActivityInfo(1000);

        info.setTimerSeconds(1800);
        model.compute(info);

        clock.setNow(1300);
        model.recordIntake(20);
        model.compute(info);
        model.onTimerLap();

        var snapshot = storage.getLastLapSnapshot();
        Test.assertMessage(snapshot != null, "onTimerLap should persist a lap snapshot.");
        if (snapshot == null) {
            return false;
        }

        var sessionId = snapshot["sessionId"] as Number;
        var elapsedActiveSec = snapshot["elapsedActiveSec"] as Number;
        var consumedTotalG10 = snapshot["consumedTotalG10"] as Number;
        var deficitG10 = snapshot["deficitG10"] as Number;

        logger.debug("lapSessionId=" + sessionId.format("%d"));
        logger.debug("lapDeficitG10=" + deficitG10.format("%d"));

        Test.assertMessage(sessionId == 1000, "Lap snapshot should keep the session id.");
        Test.assertEqual(1000, sessionId);
        Test.assertMessage(elapsedActiveSec == 1800, "Lap snapshot should keep the active elapsed time.");
        Test.assertEqual(1800, elapsedActiveSec);
        Test.assertMessage(consumedTotalG10 == 200, "Lap snapshot should keep consumed carbs in g10.");
        Test.assertEqual(200, consumedTotalG10);
        Test.assertMessage(deficitG10 == 100, "Lap snapshot should keep the current deficit in g10.");
        Test.assertEqual(100, deficitG10);
        return true;
    }

    (:test)
    static function sessionReloadRestoresRunningActivity(logger as Test.Logger) as Boolean {
        var storageBackend = new MockStorageBackend();
        var props = new MockPropertiesBackend();
        props.setValue("carbsTargetGph", 60);
        props.setValue("doseG", 25);
        props.setValue("startDelayMin", 0);

        var firstStorage = buildStorage(props, storageBackend);
        var firstClock = new MockClock(5000);
        var firstModel = buildModel(firstStorage, firstClock);
        var info = new MockActivityInfo(1234);

        info.setTimerSeconds(1200);
        firstModel.compute(info);
        firstClock.setNow(5100);
        firstModel.recordIntake(25);
        firstModel.compute(info);
        firstModel.saveSession();

        var secondStorage = buildStorage(props, storageBackend);
        var secondModel = buildModel(secondStorage, new MockClock(5200));
        secondModel.loadSession();

        logger.debug("restoredElapsedActiveSec=" + secondModel.getElapsedActiveSec().format("%d"));
        logger.debug("restoredConsumedTotalG10=" + secondModel.getConsumedTotalG10().format("%d"));

        Test.assertMessage(secondModel.isSessionActive(), "Reloaded model should detect an active session.");
        Test.assertMessage(secondModel.getElapsedActiveSec() == 1200, "Elapsed active seconds must survive a crash/reload.");
        Test.assertEqual(1200, secondModel.getElapsedActiveSec());
        Test.assertMessage(secondModel.getConsumedTotalG10() == 250, "Consumed carbs must survive a crash/reload.");
        Test.assertEqual(250, secondModel.getConsumedTotalG10());
        Test.assertMessage(secondModel.getIntakeCount() == 1, "Intake count must survive a crash/reload.");
        Test.assertEqual(1, secondModel.getIntakeCount());
        Test.assertMessage(secondStorage.getStartTimestamp() == 1234, "Start timestamp must survive a crash/reload.");
        Test.assertEqual(1234, secondStorage.getStartTimestamp());
        return true;
    }
}
