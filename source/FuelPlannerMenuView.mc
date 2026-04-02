import Toybox.Lang;
import Toybox.WatchUi;

//! Main settings menu
(:full)
class FuelPlannerMenu extends WatchUi.Menu2 {

    // Direct item references so delegates can update sub-labels without findItemById
    var carbsItem   as WatchUi.MenuItem;
    var doseItem    as WatchUi.MenuItem;
    var modeItem    as WatchUi.MenuItem;
    var carbFracItem as WatchUi.MenuItem;
    var intervalItem as WatchUi.MenuItem;
    var delayItem   as WatchUi.MenuItem;
    var snoozeItem  as WatchUi.MenuItem;
    var alertItem   as WatchUi.MenuItem?;

    private var _strLabelMenuTitle as String = "";
    private var _strSettingCarbsTarget as String = "";
    private var _strSettingDoseSize as String = "";
    private var _strSettingReminderMode as String = "";
    private var _strSettingCarbFraction as String = "";
    private var _strSettingFixedInterval as String = "";
    private var _strSettingStartDelay as String = "";
    private var _strSettingSnoozeTime as String = "";
    private var _strSettingFullScreenAlerts as String = "";
    private var _strLabelPresets as String = "";
    private var _strPresetRun as String = "";
    private var _strPresetRunSub as String = "";
    private var _strPresetBike as String = "";
    private var _strPresetBikeSub as String = "";
    private var _strPresetHike as String = "";
    private var _strPresetHikeSub as String = "";
    private var _strLabelClearSession as String = "";
    private var _strLabelClearSessionSub as String = "";
    private var _strModeAuto as String = "";
    private var _strModeFixed as String = "";
    private var _strModeCalorieAuto as String = "";
    private var _strEnabled as String = "";
    private var _strDisabled as String = "";
    private var _strUnitGramsPerHour as String = "";
    private var _strUnitGrams as String = "";
    private var _strUnitMinutes as String = "";

    function initialize(storage as StorageManager, model as FuelModel?) {
        loadStrings();
        Menu2.initialize({:title => _strLabelMenuTitle});

        carbsItem = new WatchUi.MenuItem(
            _strSettingCarbsTarget,
            storage.getCarbsTargetGph().format("%d") + " " + _strUnitGramsPerHour,
            :carbsTarget, {});
        addItem(carbsItem);

        doseItem = new WatchUi.MenuItem(
            _strSettingDoseSize,
            storage.getDoseG().format("%d") + " " + _strUnitGrams,
            :doseSize, {});
        addItem(doseItem);

        modeItem = new WatchUi.MenuItem(
            _strSettingReminderMode,
            modeLabel(storage.getReminderMode(), storage.getFixedIntervalMin()),
            :reminderMode, {});
        addItem(modeItem);

        carbFracItem = new WatchUi.MenuItem(
            _strSettingCarbFraction,
            storage.getCarbFractionPct().format("%d") + "%",
            :carbFraction, {});
        addItem(carbFracItem);

        intervalItem = new WatchUi.MenuItem(
            _strSettingFixedInterval,
            storage.getFixedIntervalMin().format("%d") + " " + _strUnitMinutes,
            :fixedInterval, {});
        addItem(intervalItem);

        delayItem = new WatchUi.MenuItem(
            _strSettingStartDelay,
            storage.getStartDelayMin().format("%d") + " " + _strUnitMinutes,
            :startDelay, {});
        addItem(delayItem);

        snoozeItem = new WatchUi.MenuItem(
            _strSettingSnoozeTime,
            storage.getMaxSnoozeMin().format("%d") + " " + _strUnitMinutes,
            :snoozeTime, {});
        addItem(snoozeItem);

        if (model != null && (model as FuelModel).supportsNativeDataFieldAlert()) {
            alertItem = new WatchUi.MenuItem(
                _strSettingFullScreenAlerts,
                toggleLabel(storage.getDataFieldAlertEnabled()),
                :fullScreenAlerts, {});
            addItem(alertItem as WatchUi.MenuItem);
        }

        addItem(new WatchUi.MenuItem(
            _strLabelPresets, "", :separator, {}));
        addItem(new WatchUi.MenuItem(
            _strPresetRun,
            _strPresetRunSub,
            :presetRun, {}));
        addItem(new WatchUi.MenuItem(
            _strPresetBike,
            _strPresetBikeSub,
            :presetBike, {}));
        addItem(new WatchUi.MenuItem(
            _strPresetHike,
            _strPresetHikeSub,
            :presetHike, {}));

        if (storage.hasActiveSession()) {
            addItem(new WatchUi.MenuItem(
                _strLabelClearSession,
                _strLabelClearSessionSub,
                :clearSession, {}));
        }
    }

    private function loadString(resourceId as Lang.ResourceId?, fallback as String) as String {
        if (resourceId == null) {
            return fallback;
        }
        try {
            var value = WatchUi.loadResource(resourceId);
            if (value instanceof String) {
                return value as String;
            }
        } catch (e) {}
        return fallback;
    }

    private function loadStrings() as Void {
        _strLabelMenuTitle = loadString(Rez.Strings.LabelMenuTitle, "FuelPlanner");
        _strSettingCarbsTarget = loadString(Rez.Strings.SettingCarbsTarget, "Carbs target");
        _strSettingDoseSize = loadString(Rez.Strings.SettingDoseSize, "Dose size");
        _strSettingReminderMode = loadString(Rez.Strings.SettingReminderMode, "Reminder mode");
        _strSettingCarbFraction = loadString(Rez.Strings.SettingCarbFraction, "Carb fraction");
        _strSettingFixedInterval = loadString(Rez.Strings.SettingFixedInterval, "Fixed interval");
        _strSettingStartDelay = loadString(Rez.Strings.SettingStartDelay, "Start delay");
        _strSettingSnoozeTime = loadString(Rez.Strings.SettingSnoozeTime, "Snooze time");
        _strSettingFullScreenAlerts = loadString(Rez.Strings.SettingFullScreenAlerts, "Full-screen alerts");
        _strLabelPresets = loadString(Rez.Strings.LabelPresets, "Presets");
        _strPresetRun = loadString(Rez.Strings.PresetRun, "Run");
        _strPresetRunSub = loadString(Rez.Strings.PresetRunSub, "60 g/h, 25 g");
        _strPresetBike = loadString(Rez.Strings.PresetBike, "Bike");
        _strPresetBikeSub = loadString(Rez.Strings.PresetBikeSub, "90 g/h, 30 g");
        _strPresetHike = loadString(Rez.Strings.PresetHike, "Hike");
        _strPresetHikeSub = loadString(Rez.Strings.PresetHikeSub, "40 g/h, 20 g");
        _strLabelClearSession = loadString(Rez.Strings.LabelClearSession, "Clear session");
        _strLabelClearSessionSub = loadString(Rez.Strings.LabelClearSessionSub, "Delete current data");
        _strModeAuto = loadString(Rez.Strings.ModeAuto, "Auto");
        _strModeFixed = loadString(Rez.Strings.ModeFixed, "Fixed");
        _strModeCalorieAuto = loadString(Rez.Strings.ModeCalorieAuto, "Auto (Calories)");
        _strEnabled = loadString(Rez.Strings.LabelEnabled, "Enabled");
        _strDisabled = loadString(Rez.Strings.LabelDisabled, "Disabled");
        _strUnitGramsPerHour = loadString(Rez.Strings.UnitGramsPerHour, "g/h");
        _strUnitGrams = loadString(Rez.Strings.UnitGrams, "g");
        _strUnitMinutes = loadString(Rez.Strings.UnitMinutes, "min");
    }

    private function modeLabel(mode as Number, intervalMin as Number) as String {
        if (mode == 0) { return _strModeAuto; }
        if (mode == 1) {
            return _strModeFixed + " " + intervalMin.format("%d") + " " + _strUnitMinutes;
        }
        return _strModeCalorieAuto;
    }

    private function toggleLabel(value as Number) as String {
        return (value != 0) ? _strEnabled : _strDisabled;
    }
}

//! Number picker for settings
(:full)
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
