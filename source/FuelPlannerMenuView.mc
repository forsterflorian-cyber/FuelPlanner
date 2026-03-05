import Toybox.Lang;
import Toybox.WatchUi;
import Toybox.Graphics;

//! Main settings menu
class FuelPlannerMenu extends WatchUi.Menu2 {

    // Direct item references so delegates can update sub-labels without findItemById
    var carbsItem   as WatchUi.MenuItem;
    var doseItem    as WatchUi.MenuItem;
    var modeItem    as WatchUi.MenuItem;
    var carbFracItem as WatchUi.MenuItem;
    var intervalItem as WatchUi.MenuItem;
    var delayItem   as WatchUi.MenuItem;
    var snoozeItem  as WatchUi.MenuItem;

    function initialize(storage as StorageManager) {
        Menu2.initialize({:title => "Settings"});

        carbsItem = new WatchUi.MenuItem(
            "Carbs Target", storage.getCarbsTargetGph().format("%d") + " g/h",
            :carbsTarget, {});
        addItem(carbsItem);

        doseItem = new WatchUi.MenuItem(
            "Gel Size", storage.getDoseG().format("%d") + " g",
            :doseSize, {});
        addItem(doseItem);

        modeItem = new WatchUi.MenuItem(
            "Reminder Mode",
            FuelPlannerMenuDelegate.modeLabel(storage.getReminderMode(),
                                              storage.getFixedIntervalMin()),
            :reminderMode, {});
        addItem(modeItem);

        carbFracItem = new WatchUi.MenuItem(
            "Carb % of kcal", storage.getCarbFractionPct().format("%d") + "%",
            :carbFraction, {});
        addItem(carbFracItem);

        intervalItem = new WatchUi.MenuItem(
            "Fixed Interval", storage.getFixedIntervalMin().format("%d") + " min",
            :fixedInterval, {});
        addItem(intervalItem);

        delayItem = new WatchUi.MenuItem(
            "Start Delay", storage.getStartDelayMin().format("%d") + " min",
            :startDelay, {});
        addItem(delayItem);

        snoozeItem = new WatchUi.MenuItem(
            "Snooze Time", storage.getMaxSnoozeMin().format("%d") + " min",
            :snoozeTime, {});
        addItem(snoozeItem);

        addItem(new WatchUi.MenuItem("--- Presets ---", "", :separator, {}));
        addItem(new WatchUi.MenuItem("Running", "60g/h, 25g gel", :presetRun,  {}));
        addItem(new WatchUi.MenuItem("Cycling", "90g/h, 30g gel", :presetBike, {}));
        addItem(new WatchUi.MenuItem("Hiking",  "40g/h, 20g gel", :presetHike, {}));

        if (storage.hasActiveSession()) {
            addItem(new WatchUi.MenuItem(
                "Clear Session", "Reset tracking data", :clearSession, {}));
        }
    }
}

//! Number picker for settings
class NumberPickerView extends WatchUi.Menu2 {

    function initialize(title as String, current as Number, min as Number,
                        max as Number, step as Number) {
        Menu2.initialize({:title => title});

        var value = min;
        while (value <= max) {
            var label = value.format("%d");
            if (value == current) {
                label = "> " + label + " <";
            }
            addItem(new WatchUi.MenuItem(label, "", value, {}));
            value += step;
        }
    }
}
