import Toybox.Lang;
import Toybox.WatchUi;
import FuelReminderModes;

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

    private function loadStrings() as Void {
        _strLabelMenuTitle = FuelPlannerUtils.loadString(Rez.Strings.LabelMenuTitle, "FuelPlanner");
        _strSettingCarbsTarget = FuelPlannerUtils.loadString(Rez.Strings.SettingCarbsTarget, "Carbs target");
        _strSettingDoseSize = FuelPlannerUtils.loadString(Rez.Strings.SettingDoseSize, "Dose size");
        _strSettingReminderMode = FuelPlannerUtils.loadString(Rez.Strings.SettingReminderMode, "Reminder mode");
        _strSettingCarbFraction = FuelPlannerUtils.loadString(Rez.Strings.SettingCarbFraction, "Carb fraction");
        _strSettingFixedInterval = FuelPlannerUtils.loadString(Rez.Strings.SettingFixedInterval, "Fixed interval");
        _strSettingStartDelay = FuelPlannerUtils.loadString(Rez.Strings.SettingStartDelay, "Start delay");
        _strSettingSnoozeTime = FuelPlannerUtils.loadString(Rez.Strings.SettingSnoozeTime, "Snooze time");
        _strSettingFullScreenAlerts = FuelPlannerUtils.loadString(Rez.Strings.SettingFullScreenAlerts, "Full-screen alerts");
        _strLabelPresets = FuelPlannerUtils.loadString(Rez.Strings.LabelPresets, "Presets");
        _strPresetRun = FuelPlannerUtils.loadString(Rez.Strings.PresetRun, "Run");
        _strPresetRunSub = FuelPlannerUtils.loadString(Rez.Strings.PresetRunSub, "60 g/h, 25 g");
        _strPresetBike = FuelPlannerUtils.loadString(Rez.Strings.PresetBike, "Bike");
        _strPresetBikeSub = FuelPlannerUtils.loadString(Rez.Strings.PresetBikeSub, "90 g/h, 30 g");
        _strPresetHike = FuelPlannerUtils.loadString(Rez.Strings.PresetHike, "Hike");
        _strPresetHikeSub = FuelPlannerUtils.loadString(Rez.Strings.PresetHikeSub, "40 g/h, 20 g");
        _strLabelClearSession = FuelPlannerUtils.loadString(Rez.Strings.LabelClearSession, "Clear session");
        _strLabelClearSessionSub = FuelPlannerUtils.loadString(Rez.Strings.LabelClearSessionSub, "Delete current data");
        _strModeAuto = FuelPlannerUtils.loadString(Rez.Strings.ModeAuto, "Auto");
        _strModeFixed = FuelPlannerUtils.loadString(Rez.Strings.ModeFixed, "Fixed");
        _strModeCalorieAuto = FuelPlannerUtils.loadString(Rez.Strings.ModeCalorieAuto, "Auto (Calories)");
        _strEnabled = FuelPlannerUtils.loadString(Rez.Strings.LabelEnabled, "Enabled");
        _strDisabled = FuelPlannerUtils.loadString(Rez.Strings.LabelDisabled, "Disabled");
        _strUnitGramsPerHour = FuelPlannerUtils.loadString(Rez.Strings.UnitGramsPerHour, "g/h");
        _strUnitGrams = FuelPlannerUtils.loadString(Rez.Strings.UnitGrams, "g");
        _strUnitMinutes = FuelPlannerUtils.loadString(Rez.Strings.UnitMinutes, "min");
    }

    private function modeLabel(mode as Number, intervalMin as Number) as String {
        if (mode == FuelReminderModes.AUTO) { return _strModeAuto; }
        if (mode == FuelReminderModes.FIXED) {
            return _strModeFixed + " " + intervalMin.format("%d") + " " + _strUnitMinutes;
        }
        return _strModeCalorieAuto;
    }

    private function toggleLabel(value as Number) as String {
        return (value != 0) ? _strEnabled : _strDisabled;
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
