using Toybox.Test;
import Toybox.Activity;
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
    static function onTimerLapBuffersCurrentSession(logger as Test.Logger) as Boolean {
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

        var restoredStorage = buildStorage(props, storageBackend);
        var restoredModel = buildModel(restoredStorage, new MockClock(1400));
        restoredModel.loadSession();

        logger.debug("lapRestoredElapsedActiveSec=" + restoredModel.getElapsedActiveSec().format("%d"));
        logger.debug("lapRestoredDeficitG10=" + restoredModel.getDeficitG10().format("%d"));

        Test.assertMessage(restoredModel.isSessionActive(), "onTimerLap should keep the session recoverable.");
        Test.assertMessage(restoredModel.getElapsedActiveSec() == 1800, "Buffered session should keep active elapsed time.");
        Test.assertEqual(1800, restoredModel.getElapsedActiveSec());
        Test.assertMessage(restoredModel.getConsumedTotalG10() == 200, "Buffered session should keep consumed carbs in g10.");
        Test.assertEqual(200, restoredModel.getConsumedTotalG10());
        Test.assertMessage(restoredModel.getIntakeCount() == 1, "Buffered session should keep the intake count.");
        Test.assertEqual(1, restoredModel.getIntakeCount());
        Test.assertMessage(restoredModel.getDeficitG10() == 100, "Buffered session should recompute the deficit after reload.");
        Test.assertEqual(100, restoredModel.getDeficitG10());
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

    (:test)
    static function pausedReloadKeepsPausedStateWithoutExplicitTimerState(logger as Test.Logger) as Boolean {
        var storageBackend = new MockStorageBackend();
        var props = new MockPropertiesBackend();
        props.setValue("carbsTargetGph", 60);
        props.setValue("doseG", 25);
        props.setValue("startDelayMin", 0);

        var firstStorage = buildStorage(props, storageBackend);
        var firstClock = new MockClock(1000);
        var firstModel = buildModel(firstStorage, firstClock);
        var info = new MockActivityInfo(1000);

        info.setTimerSeconds(600);
        firstModel.compute(info);

        firstClock.setNow(1200);
        info.timerState = Activity.TIMER_STATE_PAUSED;
        info.setTimerSeconds(600);
        firstModel.compute(info);
        firstModel.saveSession();

        var restoredStorage = buildStorage(props, storageBackend);
        var restoredClock = new MockClock(1500);
        var restoredModel = buildModel(restoredStorage, restoredClock);
        restoredModel.loadSession();

        var reloadedInfo = new MockActivityInfo(1000);
        reloadedInfo.setTimerSeconds(600);
        restoredModel.compute(reloadedInfo);

        logger.debug("pausedAfterReload=" + boolToAscii(restoredModel.isPaused()));
        logger.debug("elapsedAfterReload=" + restoredModel.getElapsedActiveSec().format("%d"));

        Test.assertMessage(restoredModel.isPaused(), "A reloaded paused session must stay paused until the timer actually advances again.");
        Test.assertEqual(600, restoredModel.getElapsedActiveSec());
        return true;
    }

    (:test)
    static function stoppedSessionRestoresAfterReload(logger as Test.Logger) as Boolean {
        var storageBackend = new MockStorageBackend();
        var props = new MockPropertiesBackend();
        props.setValue("carbsTargetGph", 60);
        props.setValue("doseG", 25);
        props.setValue("startDelayMin", 0);

        var storage = buildStorage(props, storageBackend);
        var clock = new MockClock(5000);
        var model = buildModel(storage, clock);
        var info = new MockActivityInfo(1234);

        info.setTimerSeconds(1200);
        model.compute(info);
        clock.setNow(5100);
        model.recordIntake(25);

        info.timerState = Activity.TIMER_STATE_STOPPED;
        model.compute(info);
        model.saveSession();

        logger.debug("finishedSessionStorageActive=" + boolToAscii(storage.hasActiveSession()));
        logger.debug("finishedSessionState=" + ((storage.getSessionState() != null) ? (storage.getSessionState() as Number).format("%d") : "null"));
        logger.debug("finishedSessionConsumedG10=" + model.getConsumedTotalG10().format("%d"));

        Test.assertMessage(storage.hasActiveSession(), "A stopped session must remain recoverable in storage.");
        Test.assertEqual(4, storage.getSessionState());
        Test.assertEqual(250, model.getConsumedTotalG10());

        var restoredStorage = buildStorage(props, storageBackend);
        var restoredModel = buildModel(restoredStorage, new MockClock(5200));
        restoredModel.loadSession();

        Test.assertMessage(!restoredModel.isSessionActive(), "Stopped sessions must reload as stopped, not as live sessions.");
        Test.assertEqual(250, restoredModel.getConsumedTotalG10());
        Test.assertEqual(1, restoredModel.getIntakeCount());
        Test.assertEqual(1200, restoredModel.getElapsedActiveSec());
        return true;
    }

    (:test)
    static function finishedSessionCleanupRunsOnceAndKeepsRecovery(logger as Test.Logger) as Boolean {
        var storageBackend = new MockStorageBackend();
        var props = new MockPropertiesBackend();
        props.setValue("carbsTargetGph", 60);
        props.setValue("doseG", 25);
        props.setValue("startDelayMin", 0);

        var storage = buildStorage(props, storageBackend);
        var clock = new MockClock(7000);
        var model = buildModel(storage, clock);
        var info = new MockActivityInfo(7000);

        info.setTimerSeconds(1800);
        model.compute(info);
        clock.setNow(7060);
        model.recordIntake(20);
        model.compute(info);

        var deletesBeforeFinish = storageBackend.getDeleteCount();

        info.timerState = Activity.TIMER_STATE_STOPPED;
        model.compute(info);

        var deletesAfterFirstStop = storageBackend.getDeleteCount();
        var recoveryAfterFirstStop = model.getRecoveryDeficit();
        var sessionStateAfterFirstStop = storage.getSessionState();

        model.compute(info);

        var deletesAfterSecondStop = storageBackend.getDeleteCount();
        var recoveryAfterSecondStop = model.getRecoveryDeficit();
        var sessionStateAfterSecondStop = storage.getSessionState();

        logger.debug("deletesBeforeFinish=" + deletesBeforeFinish.format("%d"));
        logger.debug("deletesAfterFirstStop=" + deletesAfterFirstStop.format("%d"));
        logger.debug("deletesAfterSecondStop=" + deletesAfterSecondStop.format("%d"));
        logger.debug("sessionStateAfterFirstStop=" + ((sessionStateAfterFirstStop != null) ? (sessionStateAfterFirstStop as Number).format("%d") : "null"));
        logger.debug("sessionStateAfterSecondStop=" + ((sessionStateAfterSecondStop != null) ? (sessionStateAfterSecondStop as Number).format("%d") : "null"));
        logger.debug("recoveryAfterFirstStop=" + ((recoveryAfterFirstStop != null) ? recoveryAfterFirstStop.format("%d") : "null"));
        logger.debug("recoveryAfterSecondStop=" + ((recoveryAfterSecondStop != null) ? recoveryAfterSecondStop.format("%d") : "null"));

        Test.assertMessage(storage.hasActiveSession(), "Stopped sessions must remain recoverable.");
        Test.assertEqual(4, sessionStateAfterFirstStop);
        Test.assertMessage(deletesAfterFirstStop == deletesBeforeFinish, "Stopping must not clear the recoverable session from storage.");
        Test.assertMessage(
            deletesAfterSecondStop == deletesAfterFirstStop,
            "Repeated stopped ticks must not rerun destructive session cleanup."
        );
        Test.assertEqual(sessionStateAfterFirstStop, sessionStateAfterSecondStop);
        Test.assertMessage(recoveryAfterFirstStop != null, "Finished sessions should keep the recovery summary available.");
        Test.assertEqual(recoveryAfterFirstStop, recoveryAfterSecondStop);
        return true;
    }

    (:test)
    static function consumedG10SyncsLegacyKey(logger as Test.Logger) as Boolean {
        var storageBackend = new MockStorageBackend();
        var props = new MockPropertiesBackend();
        var storage = buildStorage(props, storageBackend);

        // Set consumed G10 value
        storage.setConsumedTotalG10(250);

        // Verify both keys are in sync
        var g10Value = storageBackend.getValue("consum10");
        var legacyValue = storageBackend.getValue("consumed");

        Test.assertMessage(g10Value instanceof Number, "consum10 key should be set");
        Test.assertEqual(250, g10Value as Number);
        Test.assertMessage(legacyValue instanceof Number, "consumed legacy key should be set");
        Test.assertEqual(25, legacyValue as Number);

        // Verify backward compatibility read
        var readValue = storage.getConsumedTotalG10();
        Test.assertEqual(250, readValue);

        return true;
    }
}
