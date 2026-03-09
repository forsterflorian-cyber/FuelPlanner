using Toybox.Test;
import Toybox.Lang;

class ReminderTests {

    static function buildModel(clock as MockClock, props as MockPropertiesBackend) as FuelModel {
        var storage = new StorageManager(new MockStorageBackend(), props);
        var model = new FuelModel(storage, clock);
        model.setTouchForTest(true);
        return model;
    }

    (:test)
    static function thresholdTriggerFiresExactlyAtDose(logger as Test.Logger) as Boolean {
        var clock = new MockClock(2000);
        var props = new MockPropertiesBackend();
        props.setValue("carbsTargetGph", 60);
        props.setValue("doseG", 25);
        props.setValue("startDelayMin", 0);
        props.setValue("maxSnoozeMin", 5);

        var model = buildModel(clock, props);
        var info = new MockActivityInfo(2000);

        info.setTimerSeconds(1499);
        model.compute(info);
        var nextDueBefore = model.getNextDueInSec();
        var beforeTrigger = ReminderManager.shouldVibrate(
            nextDueBefore,
            model.isPaused(),
            model.getConsumedTotalG10(),
            model.getElapsedActiveSec(),
            0,
            0,
            5,
            clock.now()
        );

        info.setTimerSeconds(1500);
        model.compute(info);
        var nextDueAtTrigger = model.getNextDueInSec();
        var atTrigger = ReminderManager.shouldVibrate(
            nextDueAtTrigger,
            model.isPaused(),
            model.getConsumedTotalG10(),
            model.getElapsedActiveSec(),
            0,
            0,
            5,
            clock.now()
        );

        logger.debug("nextDueBefore=" + nextDueBefore.format("%d"));
        logger.debug("deficitAtTriggerG10=" + model.getDeficitG10().format("%d"));

        Test.assertMessage(!beforeTrigger, "Reminder must stay silent before the deficit reaches one full dose.");
        Test.assertMessage(model.getDeficitG10() == 250, "A 25 minute deficit at 60 g/h should equal 25g exactly.");
        Test.assertEqual(250, model.getDeficitG10());
        Test.assertMessage(nextDueAtTrigger == 0, "nextDueInSec must hit zero exactly at the threshold.");
        Test.assertEqual(0, nextDueAtTrigger);
        Test.assertMessage(atTrigger, "Reminder must trigger once deficit >= gel size.");
        return true;
    }

    (:test)
    static function snoozeBlocksUntilExactBoundary(logger as Test.Logger) as Boolean {
        var clock = new MockClock(5000);
        var lastReminderTimestamp = clock.now();

        var immediate = ReminderManager.shouldVibrate(0, false, 250, 1500, 0, lastReminderTimestamp, 5, clock.now());

        clock.advance(299);
        var beforeBoundary = ReminderManager.shouldVibrate(0, false, 250, 1500, 0, lastReminderTimestamp, 5, clock.now());

        clock.advance(1);
        var atBoundary = ReminderManager.shouldVibrate(0, false, 250, 1500, 0, lastReminderTimestamp, 5, clock.now());
        var elapsedSnoozeSec = clock.now() - lastReminderTimestamp;

        logger.debug("secondsSinceReminder=" + elapsedSnoozeSec.format("%d"));

        Test.assertMessage(!immediate, "Snooze should suppress the reminder immediately after it fired.");
        Test.assertMessage(!beforeBoundary, "Snooze should still suppress vibration at 4:59.");
        Test.assertMessage(atBoundary, "Snooze should release the reminder exactly after 5:00.");
        Test.assertMessage(elapsedSnoozeSec == 300, "Snooze should wait exactly 300 seconds at the 5 minute boundary.");
        Test.assertEqual(300, elapsedSnoozeSec);
        return true;
    }
}
