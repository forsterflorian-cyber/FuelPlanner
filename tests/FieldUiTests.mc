using Toybox.Test;
import Toybox.Graphics;
import Toybox.Lang;

class FieldUiReminderManager extends ReminderManager {
    private var _snoozeCount as Number = 0;
    private var _confirmationCount as Number = 0;
    private var _undoCount as Number = 0;

    function initialize() {
        ReminderManager.initialize();
    }

    function triggerSnooze() as Boolean {
        _snoozeCount += 1;
        return true;
    }

    function triggerConfirmation() as Boolean {
        _confirmationCount += 1;
        return true;
    }

    function triggerUndo() as Boolean {
        _undoCount += 1;
        return true;
    }

    function getSnoozeCount() as Number { return _snoozeCount; }
    function getConfirmationCount() as Number { return _confirmationCount; }
    function getUndoCount() as Number { return _undoCount; }
}

class FieldUiTestView extends FuelPlannerFieldView {
    private var _testTimerMs as Number = 0;

    function initialize(model as FuelModel, reminder as ReminderManager) {
        FuelPlannerFieldView.initialize(model, reminder);
    }

    function setTestTimerMs(value as Number) as Void {
        _testTimerMs = value;
    }

    function getOverlayTimerMs() as Number {
        return _testTimerMs;
    }
}

class FieldUiTests {
    static function buildContext() as Dictionary {
        var clock = new MockClock(1000);
        var props = new MockPropertiesBackend();
        props.setValue("carbsTargetGph", 60);
        props.setValue("doseG", 25);
        props.setValue("startDelayMin", 0);
        props.setValue("maxSnoozeMin", 5);
        props.setValue("reminderMode", 0);
        var storage = new StorageManager(new MockStorageBackend(), props);
        var model = new FuelModel(storage, clock);
        model.setTouchForTest(true);

        var info = new MockActivityInfo(1000);
        info.setTimerSeconds(60);
        model.compute(info);

        var reminder = new FieldUiReminderManager();
        var view = new FieldUiTestView(model, reminder);
        view.setTestTimerMs(1000);
        view.setFieldSizeForTest(260, 64);
        var delegate = new FuelPlannerFieldDelegate(model, reminder, view);
        return {
            "model" => model,
            "reminder" => reminder,
            "view" => view,
            "delegate" => delegate
        };
    }

    static function createRenderSurface(width as Number,
                                        height as Number) as Graphics.BufferedBitmap {
        return Graphics.createBufferedBitmap({
            :width => width,
            :height => height,
            :palette => [
                Graphics.COLOR_BLACK,
                Graphics.COLOR_WHITE,
                Graphics.COLOR_RED,
                Graphics.COLOR_DK_RED,
                Graphics.COLOR_YELLOW,
                Graphics.COLOR_GREEN,
                Graphics.COLOR_DK_GREEN,
                Graphics.COLOR_ORANGE,
                Graphics.COLOR_LT_GRAY,
                Graphics.COLOR_DK_GRAY
            ]
        }).get() as Graphics.BufferedBitmap;
    }

    (:test)
    static function nativeAlertDefersInteractiveOverlayWindow(logger as Test.Logger) as Boolean {
        var ctx = buildContext();
        var view = ctx["view"] as FieldUiTestView;

        view.deferReminderOverlayForTest();
        view.onHide();
        Test.assertMessage(!view.isReminderOverlayActive(),
                           "Deferred overlay must stay inactive behind the native alert.");

        view.setTestTimerMs(11000);
        Test.assertMessage(!view.isReminderOverlayActive(),
                           "Native alert lifetime must not consume the custom overlay window.");

        view.onShow();
        Test.assertMessage(view.isReminderOverlayActive(),
                           "Returning from the native alert must start the interactive overlay.");
        view.setTestTimerMs(13999);
        Test.assertMessage(view.isReminderOverlayActive(),
                           "Interactive overlay must retain its complete three-second window.");
        view.setTestTimerMs(14000);
        Test.assertMessage(!view.isReminderOverlayActive(),
                           "Interactive overlay must end at the configured boundary.");
        return true;
    }

    (:test)
    static function suppressedNativeAlertFallsBackWhileFieldStaysVisible(logger as Test.Logger) as Boolean {
        var ctx = buildContext();
        var view = ctx["view"] as FieldUiTestView;
        var surface = createRenderSurface(260, 64);
        var dc = surface.getDc();

        view.deferReminderOverlayForTest();
        view.setTestTimerMs(1249);
        view.onUpdate(dc);
        Test.assertMessage(!view.isReminderOverlayActive(),
                           "Native alert grace period must not arm the overlay early.");

        view.setTestTimerMs(1250);
        view.onUpdate(dc);
        Test.assertMessage(view.isReminderOverlayActive(),
                           "A suppressed native alert must fall back to the inline overlay.");
        view.setTestTimerMs(4249);
        Test.assertMessage(view.isReminderOverlayActive(),
                           "Fallback overlay must receive its full three-second window.");
        view.setTestTimerMs(4250);
        Test.assertMessage(!view.isReminderOverlayActive(),
                           "Fallback overlay must end at the configured boundary.");
        return true;
    }

    (:test)
    static function compactReminderRoutesSnoozeAndIntake(logger as Test.Logger) as Boolean {
        var snoozeCtx = buildContext();
        var snoozeModel = snoozeCtx["model"] as FuelModel;
        var snoozeReminder = snoozeCtx["reminder"] as FieldUiReminderManager;
        var snoozeView = snoozeCtx["view"] as FieldUiTestView;
        var snoozeDelegate = snoozeCtx["delegate"] as FuelPlannerFieldDelegate;

        snoozeView.armReminderOverlayForTest();
        Test.assertEqual(24, snoozeView.getSnoozeTapBottom());
        snoozeDelegate.routeTap(130, 12);
        Test.assertEqual(1, snoozeReminder.getSnoozeCount());
        Test.assertEqual(0, snoozeModel.getIntakeCount());
        Test.assertMessage(!snoozeView.isReminderOverlayActive(),
                           "Snooze must dismiss the reminder overlay.");

        var intakeCtx = buildContext();
        var intakeModel = intakeCtx["model"] as FuelModel;
        var intakeReminder = intakeCtx["reminder"] as FieldUiReminderManager;
        var intakeView = intakeCtx["view"] as FieldUiTestView;
        var intakeDelegate = intakeCtx["delegate"] as FuelPlannerFieldDelegate;
        intakeView.armReminderOverlayForTest();
        intakeDelegate.routeTap(130, 40);
        Test.assertEqual(1, intakeReminder.getConfirmationCount());
        Test.assertEqual(1, intakeModel.getIntakeCount());
        return true;
    }

    (:test)
    static function lowerBandRoutesUndoOutsideReminder(logger as Test.Logger) as Boolean {
        var ctx = buildContext();
        var model = ctx["model"] as FuelModel;
        var reminder = ctx["reminder"] as FieldUiReminderManager;
        var delegate = ctx["delegate"] as FuelPlannerFieldDelegate;

        delegate.routeTap(130, 32);
        Test.assertEqual(1, model.getIntakeCount());
        Test.assertEqual(1, reminder.getConfirmationCount());

        delegate.routeTap(130, 60);
        Test.assertEqual(0, model.getIntakeCount());
        Test.assertEqual(1, reminder.getUndoCount());
        return true;
    }

    (:test)
    static function nonTouchModeRejectsRoutedTapActions(logger as Test.Logger) as Boolean {
        var ctx = buildContext();
        var model = ctx["model"] as FuelModel;
        var reminder = ctx["reminder"] as FieldUiReminderManager;
        var view = ctx["view"] as FieldUiTestView;
        var delegate = ctx["delegate"] as FuelPlannerFieldDelegate;

        model.setTouchForTest(false);
        view.armReminderOverlayForTest();
        delegate.routeTap(130, 40);

        Test.assertEqual(0, model.getIntakeCount());
        Test.assertEqual(0, reminder.getConfirmationCount());
        Test.assertMessage(view.isReminderOverlayActive(),
                           "Unsupported tap delivery must not mutate reminder state.");
        return true;
    }

    (:test)
    static function representativeFieldLayoutsRenderAndKeepUsableSnoozeBand(logger as Test.Logger) as Boolean {
        var ctx = buildContext();
        var view = ctx["view"] as FieldUiTestView;
        view.armReminderOverlayForTest();
        var layouts = [
            [260, 64],
            [282, 94],
            [148, 148],
            [260, 260]
        ];

        for (var i = 0; i < layouts.size(); i += 1) {
            var layout = layouts[i];
            var width = layout[0];
            var height = layout[1];
            var surface = createRenderSurface(width, height);
            var dc = surface.getDc();
            view.onLayout(dc);
            view.onUpdate(dc);
            var snoozeBottom = view.getSnoozeTapBottom();
            Test.assertMessage(dc.getWidth() == width && dc.getHeight() == height,
                               "Representative field surface dimensions must remain intact.");
            Test.assertMessage(snoozeBottom >= 24,
                               "Supported field layouts need a usable snooze target.");
            Test.assertMessage(snoozeBottom < height,
                               "Snooze target must leave space for the intake action.");
            if (height == 260) {
                Test.assertEqual(52, snoozeBottom);
            }
            surface = null;
        }
        return true;
    }
}
