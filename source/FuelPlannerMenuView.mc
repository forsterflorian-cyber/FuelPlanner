import Toybox.Lang;
import Toybox.WatchUi;

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

    private var _strLabelMenuTitle as String = "";
    private var _strSettingCarbsTarget as String = "";
    private var _strSettingDoseSize as String = "";
    private var _strSettingReminderMode as String = "";
    private var _strSettingCarbFraction as String = "";
    private var _strSettingFixedInterval as String = "";
    private var _strSettingStartDelay as String = "";
    private var _strSettingSnoozeTime as String = "";
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
    private var _strUnitGramsPerHour as String = "";
    private var _strUnitGrams as String = "";
    private var _strUnitMinutes as String = "";

    function initialize(storage as StorageManager) {
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
        _strLabelMenuTitle = WatchUi.loadResource(Rez.Strings.LabelMenuTitle) as String;
        _strSettingCarbsTarget = WatchUi.loadResource(Rez.Strings.SettingCarbsTarget) as String;
        _strSettingDoseSize = WatchUi.loadResource(Rez.Strings.SettingDoseSize) as String;
        _strSettingReminderMode = WatchUi.loadResource(Rez.Strings.SettingReminderMode) as String;
        _strSettingCarbFraction = WatchUi.loadResource(Rez.Strings.SettingCarbFraction) as String;
        _strSettingFixedInterval = WatchUi.loadResource(Rez.Strings.SettingFixedInterval) as String;
        _strSettingStartDelay = WatchUi.loadResource(Rez.Strings.SettingStartDelay) as String;
        _strSettingSnoozeTime = WatchUi.loadResource(Rez.Strings.SettingSnoozeTime) as String;
        _strLabelPresets = WatchUi.loadResource(Rez.Strings.LabelPresets) as String;
        _strPresetRun = WatchUi.loadResource(Rez.Strings.PresetRun) as String;
        _strPresetRunSub = WatchUi.loadResource(Rez.Strings.PresetRunSub) as String;
        _strPresetBike = WatchUi.loadResource(Rez.Strings.PresetBike) as String;
        _strPresetBikeSub = WatchUi.loadResource(Rez.Strings.PresetBikeSub) as String;
        _strPresetHike = WatchUi.loadResource(Rez.Strings.PresetHike) as String;
        _strPresetHikeSub = WatchUi.loadResource(Rez.Strings.PresetHikeSub) as String;
        _strLabelClearSession = WatchUi.loadResource(Rez.Strings.LabelClearSession) as String;
        _strLabelClearSessionSub = WatchUi.loadResource(Rez.Strings.LabelClearSessionSub) as String;
        _strModeAuto = WatchUi.loadResource(Rez.Strings.ModeAuto) as String;
        _strModeFixed = WatchUi.loadResource(Rez.Strings.ModeFixed) as String;
        _strModeCalorieAuto = WatchUi.loadResource(Rez.Strings.ModeCalorieAuto) as String;
        _strUnitGramsPerHour = WatchUi.loadResource(Rez.Strings.UnitGramsPerHour) as String;
        _strUnitGrams = WatchUi.loadResource(Rez.Strings.UnitGrams) as String;
        _strUnitMinutes = WatchUi.loadResource(Rez.Strings.UnitMinutes) as String;
    }

    private function modeLabel(mode as Number, intervalMin as Number) as String {
        if (mode == 0) { return _strModeAuto; }
        if (mode == 1) {
            return _strModeFixed + " " + intervalMin.format("%d") + " " + _strUnitMinutes;
        }
        return _strModeCalorieAuto;
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
