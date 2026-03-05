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
        Menu2.initialize({:title => WatchUi.loadResource(Rez.Strings.LabelMenuTitle) as String});

        carbsItem = new WatchUi.MenuItem(
            WatchUi.loadResource(Rez.Strings.SettingCarbsTarget) as String,
            storage.getCarbsTargetGph().format("%d") + " " + (WatchUi.loadResource(Rez.Strings.UnitGramsPerHour) as String),
            :carbsTarget, {});
        addItem(carbsItem);

        doseItem = new WatchUi.MenuItem(
            WatchUi.loadResource(Rez.Strings.SettingDoseSize) as String,
            storage.getDoseG().format("%d") + " " + (WatchUi.loadResource(Rez.Strings.UnitGrams) as String),
            :doseSize, {});
        addItem(doseItem);

        modeItem = new WatchUi.MenuItem(
            WatchUi.loadResource(Rez.Strings.SettingReminderMode) as String,
            FuelPlannerMenuDelegate.modeLabel(storage.getReminderMode(),
                                              storage.getFixedIntervalMin()),
            :reminderMode, {});
        addItem(modeItem);

        carbFracItem = new WatchUi.MenuItem(
            WatchUi.loadResource(Rez.Strings.SettingCarbFraction) as String,
            storage.getCarbFractionPct().format("%d") + "%",
            :carbFraction, {});
        addItem(carbFracItem);

        intervalItem = new WatchUi.MenuItem(
            WatchUi.loadResource(Rez.Strings.SettingFixedInterval) as String,
            storage.getFixedIntervalMin().format("%d") + " " + (WatchUi.loadResource(Rez.Strings.UnitMinutes) as String),
            :fixedInterval, {});
        addItem(intervalItem);

        delayItem = new WatchUi.MenuItem(
            WatchUi.loadResource(Rez.Strings.SettingStartDelay) as String,
            storage.getStartDelayMin().format("%d") + " " + (WatchUi.loadResource(Rez.Strings.UnitMinutes) as String),
            :startDelay, {});
        addItem(delayItem);

        snoozeItem = new WatchUi.MenuItem(
            WatchUi.loadResource(Rez.Strings.SettingSnoozeTime) as String,
            storage.getMaxSnoozeMin().format("%d") + " " + (WatchUi.loadResource(Rez.Strings.UnitMinutes) as String),
            :snoozeTime, {});
        addItem(snoozeItem);

        addItem(new WatchUi.MenuItem(
            WatchUi.loadResource(Rez.Strings.LabelPresets) as String, "", :separator, {}));
        addItem(new WatchUi.MenuItem(
            WatchUi.loadResource(Rez.Strings.PresetRun) as String,
            WatchUi.loadResource(Rez.Strings.PresetRunSub) as String,
            :presetRun, {}));
        addItem(new WatchUi.MenuItem(
            WatchUi.loadResource(Rez.Strings.PresetBike) as String,
            WatchUi.loadResource(Rez.Strings.PresetBikeSub) as String,
            :presetBike, {}));
        addItem(new WatchUi.MenuItem(
            WatchUi.loadResource(Rez.Strings.PresetHike) as String,
            WatchUi.loadResource(Rez.Strings.PresetHikeSub) as String,
            :presetHike, {}));

        if (storage.hasActiveSession()) {
            addItem(new WatchUi.MenuItem(
                WatchUi.loadResource(Rez.Strings.LabelClearSession) as String,
                WatchUi.loadResource(Rez.Strings.LabelClearSessionSub) as String,
                :clearSession, {}));
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
