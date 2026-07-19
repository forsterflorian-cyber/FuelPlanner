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
    static function stoppedTimerRestoresAsPausedActiveSession(logger as Test.Logger) as Boolean {
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

        model.onTimerStop();
        info.timerState = Activity.TIMER_STATE_STOPPED;
        model.compute(info);
        model.saveSession();

        logger.debug("stoppedTimerStorageActive=" + boolToAscii(storage.hasActiveSession()));
        logger.debug("stoppedTimerSnapshotAvailable=" + boolToAscii(storage.hasRecoverySnapshot()));
        logger.debug("stoppedTimerSessionState=" + ((storage.getSessionState() != null) ? (storage.getSessionState() as Number).format("%d") : "null"));

        Test.assertMessage(storage.hasActiveSession(), "A stopped timer must retain the active session in storage.");
        Test.assertMessage(!storage.hasRecoverySnapshot(), "A stopped timer must not persist terminal recovery state.");
        Test.assertEqual(model.STATE_PAUSED, storage.getSessionState());
        Test.assertEqual(250, model.getConsumedTotalG10());

        var restoredStorage = buildStorage(props, storageBackend);
        var restoredModel = buildModel(restoredStorage, new MockClock(5200));
        restoredModel.loadSession();

        Test.assertMessage(restoredModel.isSessionActive(), "A manually stopped session must reload as active and resumable.");
        Test.assertMessage(restoredModel.isPaused(), "A manually stopped session must reload in paused state.");
        Test.assertMessage(!restoredModel.isStoppedSession(), "Manual stop must not load the recovery layout.");
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

        model.onTimerStop();
        info.timerState = Activity.TIMER_STATE_STOPPED;
        model.compute(info);

        var deletesAfterStop = storageBackend.getDeleteCount();
        Test.assertMessage(model.isSessionActive(), "Manual stop must remain active until reset.");
        Test.assertMessage(!storage.hasRecoverySnapshot(), "Manual stop must not create recovery state.");

        model.onTimerReset();

        var deletesAfterFirstReset = storageBackend.getDeleteCount();
        var recoveryAfterFirstReset = model.getRecoveryDeficit();
        var snapshotAvailableAfterFirstReset = storage.hasRecoverySnapshot();

        model.onTimerReset();

        var deletesAfterSecondReset = storageBackend.getDeleteCount();
        var recoveryAfterSecondReset = model.getRecoveryDeficit();
        var snapshotAvailableAfterSecondReset = storage.hasRecoverySnapshot();

        logger.debug("deletesBeforeFinish=" + deletesBeforeFinish.format("%d"));
        logger.debug("deletesAfterStop=" + deletesAfterStop.format("%d"));
        logger.debug("deletesAfterFirstReset=" + deletesAfterFirstReset.format("%d"));
        logger.debug("deletesAfterSecondReset=" + deletesAfterSecondReset.format("%d"));
        logger.debug("snapshotAvailableAfterFirstReset=" + boolToAscii(snapshotAvailableAfterFirstReset));
        logger.debug("snapshotAvailableAfterSecondReset=" + boolToAscii(snapshotAvailableAfterSecondReset));

        Test.assertMessage(!storage.hasActiveSession(), "Reset should clear active state after recovery commits.");
        Test.assertMessage(snapshotAvailableAfterFirstReset, "Reset should persist a frozen recovery snapshot.");
        Test.assertMessage(deletesAfterFirstReset > deletesAfterStop, "The first reset should clear the active payload.");
        Test.assertMessage(
            deletesAfterSecondReset == deletesAfterFirstReset,
            "Repeated timer reset callbacks must not rerun destructive session cleanup."
        );
        Test.assertEqual(snapshotAvailableAfterFirstReset, snapshotAvailableAfterSecondReset);
        Test.assertMessage(recoveryAfterFirstReset != null, "Reset sessions should keep the recovery summary available.");
        Test.assertEqual(recoveryAfterFirstReset, recoveryAfterSecondReset);
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

    (:test)
    static function recoverySnapshotV2RoundTripsAsSingleValue(logger as Test.Logger) as Boolean {
        var storageBackend = new MockStorageBackend();
        var props = new MockPropertiesBackend();
        var storage = buildStorage(props, storageBackend);

        var saved = storage.saveRecoverySnapshot(300, 200, 1800, 2);
        var rawSnapshot = storageBackend.getValue("recovery_v2");

        Test.assertMessage(saved, "A valid V2 recovery snapshot should commit successfully.");
        Test.assertMessage(rawSnapshot instanceof Dictionary, "Recovery must be stored as one aggregate value.");

        var restored = buildStorage(props, storageBackend);
        Test.assertMessage(restored.hasRecoverySnapshot(), "A committed V2 snapshot must survive manager reconstruction.");
        Test.assertEqual(300, restored.getRecoveryTargetG10());
        Test.assertEqual(200, restored.getRecoveryConsumedG10());
        Test.assertEqual(1800, restored.getRecoveryElapsedSec());
        Test.assertEqual(2, restored.getRecoveryIntakeCount());
        return true;
    }

    (:test)
    static function recoverySnapshotThrownWriteIsRejected(logger as Test.Logger) as Boolean {
        var storageBackend = new MockStorageBackend();
        var storage = buildStorage(new MockPropertiesBackend(), storageBackend);
        storageBackend.throwOnNextSet("recovery_v2");

        var saved = storage.saveRecoverySnapshot(300, 200, 1800, 2);

        Test.assertMessage(!saved, "A thrown aggregate write must fail the recovery commit.");
        Test.assertMessage(!storage.hasRecoverySnapshot(), "A failed write must not look like committed recovery.");
        Test.assertEqual(1, storage.getWriteFailureCount());
        Test.assertEqual("recovery_v2", storage.getLastWriteFailureKey());
        Test.assertMessage(storageBackend.getValue("recovery_v2") == null, "A thrown write must leave no partial V2 payload.");
        return true;
    }

    (:test)
    static function recoverySnapshotDroppedWriteFailsReadback(logger as Test.Logger) as Boolean {
        var storageBackend = new MockStorageBackend();
        var storage = buildStorage(new MockPropertiesBackend(), storageBackend);
        storageBackend.dropOnNextSet("recovery_v2");

        var saved = storage.saveRecoverySnapshot(300, 200, 1800, 2);

        Test.assertMessage(!saved, "A silently dropped aggregate write must fail readback verification.");
        Test.assertMessage(!storage.hasRecoverySnapshot(), "A dropped write must not look like committed recovery.");
        Test.assertEqual(1, storage.getWriteFailureCount());
        Test.assertEqual("recovery_v2", storage.getLastWriteFailureKey());
        return true;
    }

    (:test)
    static function failedResetRetainsActivePayloadAndRetriesOnLoad(logger as Test.Logger) as Boolean {
        var storageBackend = new MockStorageBackend();
        var props = new MockPropertiesBackend();
        props.setValue("carbsTargetGph", 60);
        props.setValue("doseG", 25);
        props.setValue("startDelayMin", 0);
        var storage = buildStorage(props, storageBackend);
        var model = buildModel(storage, new MockClock(9000));
        var info = new MockActivityInfo(9000);
        info.setTimerSeconds(1800);
        model.compute(info);
        model.recordIntake(20);

        storageBackend.throwOnNextSet("recovery_v2");
        model.onTimerReset();

        Test.assertMessage(storage.hasActiveSession(), "A failed recovery commit must retain the active source-of-truth payload.");
        Test.assertMessage(!storage.hasRecoverySnapshot(), "A failed recovery commit must not expose partial recovery.");
        Test.assertEqual(model.STATE_FINISHED, storage.getSessionState());
        Test.assertEqual(200, storage.getConsumedTotalG10());
        Test.assertEqual(1800, storage.getElapsedActiveSec());
        Test.assertEqual(1, storage.getIntakeCount());
        Test.assertEqual("recovery_v2", storage.getLastWriteFailureKey());

        var restoredStorage = buildStorage(props, storageBackend);
        var restoredModel = buildModel(restoredStorage, new MockClock(9100));
        restoredModel.loadSession();

        logger.debug("retriedRecoveryElapsed=" + restoredModel.getElapsedActiveSec().format("%d"));
        Test.assertMessage(!restoredStorage.hasActiveSession(), "Reload should retry and complete the recovery commit.");
        Test.assertMessage(restoredStorage.hasRecoverySnapshot(), "Reload retry should produce committed recovery.");
        Test.assertMessage(restoredModel.isStoppedSession(), "Reloaded finished state should present recovery after retry.");
        Test.assertEqual(200, restoredModel.getConsumedTotalG10());
        Test.assertEqual(1800, restoredModel.getElapsedActiveSec());
        Test.assertEqual(1, restoredModel.getIntakeCount());
        return true;
    }

    (:test)
    static function legacyRecoveryKeysRemainReadable(logger as Test.Logger) as Boolean {
        var storageBackend = new MockStorageBackend();
        storageBackend.setValue("snap_tgt10", 450);
        storageBackend.setValue("snap_con10", 250);
        storageBackend.setValue("snap_elapsed", 2700);
        storageBackend.setValue("snap_count", 3);

        var storage = buildStorage(new MockPropertiesBackend(), storageBackend);
        Test.assertMessage(storage.hasRecoverySnapshot(), "Legacy recovery keys must remain readable after the V2 upgrade.");
        Test.assertEqual(450, storage.getRecoveryTargetG10());
        Test.assertEqual(250, storage.getRecoveryConsumedG10());
        Test.assertEqual(2700, storage.getRecoveryElapsedSec());
        Test.assertEqual(3, storage.getRecoveryIntakeCount());
        return true;
    }

    (:test)
    static function malformedV2FallsBackToLegacySnapshot(logger as Test.Logger) as Boolean {
        var storageBackend = new MockStorageBackend();
        storageBackend.setValue("recovery_v2", {
            "v" => 99,
            "t" => 999,
            "c" => 999,
            "e" => 999,
            "n" => 9
        });
        storageBackend.setValue("snap_tgt10", 300);
        storageBackend.setValue("snap_con10", 100);
        storageBackend.setValue("snap_elapsed", 1200);
        storageBackend.setValue("snap_count", 1);

        var storage = buildStorage(new MockPropertiesBackend(), storageBackend);
        Test.assertMessage(storage.hasRecoverySnapshot(), "Malformed V2 data should not hide a valid legacy snapshot.");
        Test.assertEqual(300, storage.getRecoveryTargetG10());
        Test.assertEqual(100, storage.getRecoveryConsumedG10());
        Test.assertEqual(1200, storage.getRecoveryElapsedSec());
        Test.assertEqual(1, storage.getRecoveryIntakeCount());
        return true;
    }

    (:test)
    static function malformedV2WithoutLegacyIsRejected(logger as Test.Logger) as Boolean {
        var storageBackend = new MockStorageBackend();
        storageBackend.setValue("recovery_v2", {
            "v" => 2,
            "t" => 300,
            "c" => 100,
            "e" => 0
        });

        var storage = buildStorage(new MockPropertiesBackend(), storageBackend);
        Test.assertMessage(!storage.hasRecoverySnapshot(), "Incomplete or zero-duration V2 data must be rejected.");
        Test.assertEqual(0, storage.getRecoveryTargetG10());
        Test.assertEqual(0, storage.getRecoveryConsumedG10());
        Test.assertEqual(0, storage.getRecoveryElapsedSec());
        Test.assertEqual(0, storage.getRecoveryIntakeCount());
        return true;
    }

    (:test)
    static function propertySetterReportsThrownWrite(logger as Test.Logger) as Boolean {
        var props = new MockPropertiesBackend();
        var storage = buildStorage(props, new MockStorageBackend());
        props.throwOnNextSet("doseG");

        var saved = storage.setDoseG(30);

        Test.assertMessage(!saved, "A property backend exception must be reported to the caller.");
        Test.assertEqual(1, storage.getWriteFailureCount());
        Test.assertEqual("doseG", storage.getLastWriteFailureKey());
        Test.assertEqual(storage.DEFAULT_DOSE_G, storage.getDoseG());
        return true;
    }
}
