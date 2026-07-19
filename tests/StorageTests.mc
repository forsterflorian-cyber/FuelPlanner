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

    static function buildActiveSnapshot(storage as StorageManager) as Dictionary {
        return {
            storage.ACTIVE_SESSION_KEY_SESSION_ID => 42,
            storage.ACTIVE_SESSION_KEY_START_TIMESTAMP => 1000,
            storage.ACTIVE_SESSION_KEY_START_CONFIRMED => true,
            storage.ACTIVE_SESSION_KEY_CONSUMED_G10 => 250,
            storage.ACTIVE_SESSION_KEY_STATE => 2,
            storage.ACTIVE_SESSION_KEY_LAST_INTAKE => 1200,
            storage.ACTIVE_SESSION_KEY_LAST_REMINDER => 1300,
            storage.ACTIVE_SESSION_KEY_INTAKE_COUNT => 1,
            storage.ACTIVE_SESSION_KEY_PAUSED => true,
            storage.ACTIVE_SESSION_KEY_ELAPSED_SEC => 900,
            storage.ACTIVE_SESSION_KEY_PAUSED_OFFSET_SEC => 120,
            storage.ACTIVE_SESSION_KEY_PAUSE_START_TIMER => 900,
            storage.ACTIVE_SESSION_KEY_PAUSE_START_CLOCK => 1400,
            storage.ACTIVE_SESSION_KEY_USING_ELAPSED => true,
            storage.ACTIVE_SESSION_KEY_LATEST_CALORIES => 600,
            storage.ACTIVE_SESSION_KEY_LATEST_ENERGY_RATE => 12.5f,
            storage.ACTIVE_SESSION_KEY_CALORIES_AVAILABLE => true,
            storage.ACTIVE_SESSION_KEY_FINAL_TARGET_G10 => 900
        };
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
    static function activeSessionV2RoundTripsAsSingleValue(logger as Test.Logger) as Boolean {
        var storageBackend = new MockStorageBackend();
        var props = new MockPropertiesBackend();
        var storage = buildStorage(props, storageBackend);
        var saved = storage.saveActiveSessionSnapshot(buildActiveSnapshot(storage));
        var rawSnapshot = storageBackend.getValue("active_v2");

        Test.assertMessage(saved, "A valid active snapshot should commit successfully.");
        Test.assertMessage(rawSnapshot instanceof Dictionary, "Active state must be stored as one aggregate value.");

        var restored = buildStorage(props, storageBackend);
        var snapshot = restored.loadActiveSessionSnapshot();
        Test.assertMessage(snapshot != null, "A committed active snapshot must survive reconstruction.");
        Test.assertEqual(42, restored.getSessionId());
        Test.assertEqual(1000, restored.getStartTimestamp());
        Test.assertMessage(restored.getIsStartTimestampConfirmed(), "Confirmed start state must survive reconstruction.");
        Test.assertEqual(250, restored.getConsumedTotalG10());
        Test.assertEqual(2, restored.getSessionState());
        Test.assertEqual(1200, restored.getLastIntakeTimestamp());
        Test.assertEqual(1300, restored.getLastReminderTimestamp());
        Test.assertEqual(1, restored.getIntakeCount());
        Test.assertMessage(restored.getIsPaused(), "Paused state must survive reconstruction.");
        Test.assertEqual(900, restored.getElapsedActiveSec());
        Test.assertEqual(120, restored.getPausedTimerOffsetSec());
        Test.assertEqual(900, restored.getPauseStartTimerSec());
        Test.assertEqual(1400, restored.getPauseStartClockSec());
        Test.assertEqual(600, (snapshot as Dictionary)[restored.ACTIVE_SESSION_KEY_LATEST_CALORIES] as Number);
        Test.assertEqual(900, (snapshot as Dictionary)[restored.ACTIVE_SESSION_KEY_FINAL_TARGET_G10] as Number);
        return true;
    }

    (:test)
    static function activeSessionWriteFailuresAreRejected(logger as Test.Logger) as Boolean {
        var thrownBackend = new MockStorageBackend();
        var thrownStorage = buildStorage(new MockPropertiesBackend(), thrownBackend);
        thrownBackend.throwOnNextSet("active_v2");

        Test.assertMessage(
            !thrownStorage.saveActiveSessionSnapshot(buildActiveSnapshot(thrownStorage)),
            "A thrown active snapshot write must fail."
        );
        Test.assertMessage(!thrownStorage.hasActiveSession(), "A thrown write must not expose active state.");
        Test.assertEqual("active_v2", thrownStorage.getLastWriteFailureKey());

        var droppedBackend = new MockStorageBackend();
        var droppedStorage = buildStorage(new MockPropertiesBackend(), droppedBackend);
        droppedBackend.dropOnNextSet("active_v2");
        Test.assertMessage(
            !droppedStorage.saveActiveSessionSnapshot(buildActiveSnapshot(droppedStorage)),
            "A silently dropped active snapshot write must fail verification."
        );
        Test.assertMessage(!droppedStorage.hasActiveSession(), "A dropped write must not expose active state.");
        Test.assertEqual("active_v2", droppedStorage.getLastWriteFailureKey());
        return true;
    }

    (:test)
    static function legacyActiveSessionMigratesToV2(logger as Test.Logger) as Boolean {
        var storageBackend = new MockStorageBackend();
        storageBackend.setValue("sess_id", 77);
        storageBackend.setValue("start_ts", 2000);
        storageBackend.setValue("start_ts_ok", true);
        storageBackend.setValue("consum10", 300);
        storageBackend.setValue("sess_state", 3);
        storageBackend.setValue("elapsed_s", 1200);
        storageBackend.setValue("pause_off_s", 200);
        storageBackend.setValue("is_paused", true);
        storageBackend.setValue("int_cnt", 2);

        var storage = buildStorage(new MockPropertiesBackend(), storageBackend);
        var snapshot = storage.loadActiveSessionSnapshot();

        Test.assertMessage(snapshot != null, "A valid legacy active session must remain readable.");
        Test.assertMessage(storageBackend.getValue("active_v2") instanceof Dictionary,
                           "Reading valid legacy state should migrate it to one aggregate value.");
        Test.assertMessage(storageBackend.getValue("sess_id") == null &&
                           storageBackend.getValue("start_ts") == null &&
                           storageBackend.getValue("consum10") == null,
                           "A verified aggregate migration must retire stale scalar generations.");
        Test.assertEqual(77, storage.getSessionId());
        Test.assertEqual(300, storage.getConsumedTotalG10());
        Test.assertEqual(1200, storage.getElapsedActiveSec());
        Test.assertEqual(200, storage.getPausedTimerOffsetSec());
        Test.assertEqual(0, (snapshot as Dictionary)[storage.ACTIVE_SESSION_KEY_LATEST_CALORIES] as Number);
        Test.assertMessage(
            !((snapshot as Dictionary)[storage.ACTIVE_SESSION_KEY_CALORIES_AVAILABLE] as Boolean),
            "Fields unavailable in legacy storage need safe migration defaults."
        );
        return true;
    }

    (:test)
    static function legacyActiveRetirementRetriesAfterTransientFailure(logger as Test.Logger) as Boolean {
        var storageBackend = new MockStorageBackend();
        storageBackend.setValue("sess_id", 77);
        var storage = buildStorage(new MockPropertiesBackend(), storageBackend);
        storageBackend.throwOnNextDelete("sess_id");

        Test.assertMessage(storage.saveActiveSessionSnapshot(buildActiveSnapshot(storage)),
                           "Legacy cleanup failure must not undo the verified aggregate.");
        Test.assertEqual(77, storageBackend.getValue("sess_id") as Number);

        Test.assertMessage(storage.saveActiveSessionSnapshot(buildActiveSnapshot(storage)),
                           "A later verified save should retry legacy retirement.");
        Test.assertMessage(storageBackend.getValue("sess_id") == null,
                           "Transient legacy cleanup failure should be retired on retry.");
        return true;
    }

    (:test)
    static function activeSessionClearReportsDeleteFailures(logger as Test.Logger) as Boolean {
        var storageBackend = new MockStorageBackend();
        var storage = buildStorage(new MockPropertiesBackend(), storageBackend);
        Test.assertMessage(storage.saveActiveSessionSnapshot(buildActiveSnapshot(storage)),
                           "Test setup must persist active state.");

        storageBackend.throwOnNextDelete("sess_id");
        Test.assertMessage(!storage.clearActiveSession(), "A thrown legacy cleanup must be reported.");
        Test.assertMessage(storage.hasActiveSession(), "Aggregate state must survive partial legacy cleanup.");
        Test.assertEqual("sess_id", storage.getLastWriteFailureKey());

        Test.assertMessage(storage.clearActiveSession(), "A retry should complete cleanup.");
        Test.assertMessage(!storage.hasActiveSession(), "Successful cleanup must remove active state.");

        Test.assertMessage(storage.saveActiveSessionSnapshot(buildActiveSnapshot(storage)),
                           "Test setup must restore active state.");
        storageBackend.dropOnNextDelete("active_v2");
        Test.assertMessage(!storage.clearActiveSession(), "A silently dropped aggregate delete must fail verification.");
        Test.assertMessage(storage.hasActiveSession(), "A failed aggregate delete must remain recoverable.");
        Test.assertEqual("active_v2", storage.getLastWriteFailureKey());
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
        Test.assertMessage(restored.getRecoverySessionId() == null,
                           "Legacy V2 recovery snapshots do not carry session identity.");
        return true;
    }

    (:test)
    static function recoverySnapshotV3CarriesSessionIdentity(logger as Test.Logger) as Boolean {
        var storageBackend = new MockStorageBackend();
        var props = new MockPropertiesBackend();
        var storage = buildStorage(props, storageBackend);
        storageBackend.setValue("snap_tgt10", 999);
        storageBackend.setValue("snap_con10", 999);
        storageBackend.setValue("snap_elapsed", 999);
        storageBackend.setValue("snap_count", 9);

        Test.assertMessage(
            storage.saveRecoverySnapshotForSession(42, 500, 300, 2400, 3),
            "A session-aware recovery snapshot should commit successfully."
        );

        var restored = buildStorage(props, storageBackend);
        Test.assertMessage(restored.hasRecoverySnapshot(), "V3 recovery must survive reconstruction.");
        Test.assertEqual(42, restored.getRecoverySessionId());
        Test.assertEqual(500, restored.getRecoveryTargetG10());
        Test.assertEqual(300, restored.getRecoveryConsumedG10());
        Test.assertEqual(2400, restored.getRecoveryElapsedSec());
        Test.assertEqual(3, restored.getRecoveryIntakeCount());
        Test.assertMessage(storageBackend.getValue("snap_tgt10") == null,
                           "A verified V3 commit must retire stale legacy recovery values.");
        Test.assertMessage(storageBackend.getValue("snap_con10") == null,
                           "A verified V3 commit must retire stale legacy recovery values.");
        Test.assertMessage(storageBackend.getValue("snap_elapsed") == null,
                           "A verified V3 commit must retire stale legacy recovery values.");
        Test.assertMessage(storageBackend.getValue("snap_count") == null,
                           "A verified V3 commit must retire stale legacy recovery values.");
        return true;
    }

    (:test)
    static function recoveryV3LegacyCleanupFailureDoesNotUndoCommit(logger as Test.Logger) as Boolean {
        var storageBackend = new MockStorageBackend();
        storageBackend.setValue("snap_tgt10", 999);
        storageBackend.throwOnNextDelete("snap_tgt10");
        var storage = buildStorage(new MockPropertiesBackend(), storageBackend);

        var saved = storage.saveRecoverySnapshotForSession(43, 500, 300, 2400, 3);

        Test.assertMessage(saved, "Legacy cleanup failure must not undo a verified V3 commit.");
        Test.assertEqual(43, storage.getRecoverySessionId());
        Test.assertEqual(500, storage.getRecoveryTargetG10());
        Test.assertEqual("snap_tgt10", storage.getLastWriteFailureKey());
        Test.assertMessage(storageBackend.getValue("snap_tgt10") != null,
                           "The injected failed delete should leave its legacy value available for retry.");
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
    static function recoveryReadbackFailureInvalidatesLoadedCache(logger as Test.Logger) as Boolean {
        var storageBackend = new MockStorageBackend();
        var storage = buildStorage(new MockPropertiesBackend(), storageBackend);
        Test.assertMessage(storage.saveRecoverySnapshotForSession(41, 300, 200, 1800, 2),
                           "Initial recovery should commit.");
        Test.assertEqual(300, storage.getRecoveryTargetG10());

        storageBackend.throwOnNextGet("recovery_v2");
        Test.assertMessage(
            !storage.saveRecoverySnapshotForSession(42, 500, 250, 2400, 3),
            "A failed readback must report an unverified commit."
        );

        Test.assertEqual(42, storage.getRecoverySessionId());
        Test.assertEqual(500, storage.getRecoveryTargetG10());
        Test.assertEqual(2400, storage.getRecoveryElapsedSec());
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
    static function committedRecoveryWinsWhenFinalActiveCleanupWasInterrupted(logger as Test.Logger) as Boolean {
        var storageBackend = new MockStorageBackend();
        var props = new MockPropertiesBackend();
        props.setValue("carbsTargetGph", 60);
        props.setValue("doseG", 25);
        props.setValue("startDelayMin", 0);
        props.setValue("reminderMode", FuelReminderModes.CALORIE_AUTO);
        props.setValue("carbFractionPct", 60);
        var storage = buildStorage(props, storageBackend);
        var model = buildModel(storage, new MockClock(10000));
        var info = new MockActivityInfo(10000);
        info.setTimerSeconds(1800);
        info.setElapsedSeconds(1800);
        info.setCalories(1000);
        info.setEnergyExpenditure(10.0f);
        model.compute(info);

        // Recovery commits, but the final aggregate active-record deletion is
        // interrupted. Both records are intentionally left for reload.
        storageBackend.throwOnNextDelete("active_v2");
        model.onTimerReset();
        Test.assertMessage(storage.hasRecoverySnapshot(),
                           "The session-aware recovery must already be committed.");
        Test.assertMessage(storage.hasActiveSession(),
                           "Interrupted cleanup must leave the final active source intact.");
        Test.assertEqual(1500, model.getTargetTotalG10());

        // Changed settings must not recalculate and overwrite the committed
        // Calorie Auto result during cleanup recovery.
        props.setValue("reminderMode", FuelReminderModes.AUTO);
        props.setValue("carbsTargetGph", 20);
        var restoredStorage = buildStorage(props, storageBackend);
        var restoredModel = buildModel(restoredStorage, new MockClock(10100));
        restoredModel.loadSession();

        logger.debug("committedRecoveryTarget=" +
                     restoredModel.getTargetTotalG10().format("%d"));
        Test.assertMessage(restoredModel.isStoppedSession(),
                           "Matching committed recovery must win after interrupted cleanup.");
        Test.assertEqual(1500, restoredModel.getTargetTotalG10());
        Test.assertMessage(!restoredStorage.hasActiveSession(),
                           "Reload should retry and finish active-record cleanup.");
        return true;
    }

    (:test)
    static function committedRecoveryWinsOverOlderActiveGeneration(logger as Test.Logger) as Boolean {
        var storageBackend = new MockStorageBackend();
        var props = new MockPropertiesBackend();
        props.setValue("carbsTargetGph", 60);
        props.setValue("doseG", 25);
        props.setValue("startDelayMin", 0);
        var storage = buildStorage(props, storageBackend);
        var model = buildModel(storage, new MockClock(10500));
        var info = new MockActivityInfo(10500);
        info.setTimerSeconds(1200);
        model.compute(info);
        model.recordIntake(20);

        // Leave the last verified active generation in STATE_ACTIVE while the
        // newer recovery commits and aggregate cleanup is also interrupted.
        storageBackend.dropOnNextSet("active_v2");
        storageBackend.dropOnNextDelete("active_v2");
        model.onTimerReset();
        Test.assertMessage(storage.hasActiveSession(),
                           "Interrupted final write and cleanup should retain the older active aggregate.");
        Test.assertMessage(storage.hasRecoverySnapshot(),
                           "The newer session-aware recovery should still commit.");

        var restoredStorage = buildStorage(props, storageBackend);
        var restoredModel = buildModel(restoredStorage, new MockClock(10600));
        restoredModel.loadSession();

        Test.assertMessage(restoredModel.isStoppedSession(),
                           "Matching committed recovery must beat an older active generation.");
        Test.assertEqual(200, restoredModel.getConsumedTotalG10());
        Test.assertEqual(1200, restoredModel.getElapsedActiveSec());
        Test.assertMessage(!restoredStorage.hasActiveSession(),
                           "Reload should retry aggregate cleanup after choosing recovery.");
        return true;
    }

    (:test)
    static function zeroDurationResetDoesNotLeaveFinishedPayload(logger as Test.Logger) as Boolean {
        var storageBackend = new MockStorageBackend();
        var storage = buildStorage(new MockPropertiesBackend(), storageBackend);
        var model = buildModel(storage, new MockClock(11000));
        var info = new MockActivityInfo(11000);
        info.timerState = Activity.TIMER_STATE_ON;
        info.setTimerSeconds(0);

        model.onTimerStart();
        model.compute(info);
        Test.assertMessage(model.isSessionActive(),
                           "Timer start should create the zero-duration session candidate.");
        model.onTimerReset();

        Test.assertMessage(!storage.hasActiveSession(),
                           "A zero-duration reset must not leave an uncommittable final payload.");
        Test.assertMessage(!storage.hasRecoverySnapshot(),
                           "A zero-duration reset should not create a recovery summary.");
        Test.assertMessage(!model.isSessionActive() && !model.isStoppedSession(),
                           "The zero-duration session should return to idle.");
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
