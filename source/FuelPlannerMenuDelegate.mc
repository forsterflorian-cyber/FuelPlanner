import Toybox.Lang;
import Toybox.WatchUi;
import FuelPlannerLog;
import FuelReminderModes;

//! Menu delegate for settings
class FuelPlannerMenuDelegate extends WatchUi.Menu2InputDelegate {

    private var _storage as StorageManager;
    private var _fuelMenu as FuelPlannerMenu;
    private var _model as FuelModel?;
    private var _strModeAuto as String = "";
    private var _strModeFixed as String = "";
    private var _strModeCalorieAuto as String = "";
    private var _strSettingCarbsTarget as String = "";
    private var _strSettingDoseSize as String = "";
    private var _strSettingCarbFraction as String = "";
    private var _strSettingFixedInterval as String = "";
    private var _strSettingStartDelay as String = "";
    private var _strSettingSnoozeTime as String = "";
    private var _strLabelConfirmClear as String = "";
    private var _strEnabled as String = "";
    private var _strDisabled as String = "";
    private var _strUnitGramsPerHour as String = "";
    private var _strUnitGrams as String = "";
    private var _strUnitMinutes as String = "";
    private var _suffixGph as String = "";
    private var _suffixGrams as String = "";
    private var _suffixMinutes as String = "";

    function initialize(storage as StorageManager, menu as FuelPlannerMenu, model as FuelModel?) {
        Menu2InputDelegate.initialize();
        _storage = storage;
        _fuelMenu = menu;
        _model = model;
        loadStrings();
    }

    private function loadStrings() as Void {
        _strModeAuto = FuelPlannerUtils.loadString(Rez.Strings.ModeAuto, "Auto");
        _strModeFixed = FuelPlannerUtils.loadString(Rez.Strings.ModeFixed, "Fixed");
        _strModeCalorieAuto = FuelPlannerUtils.loadString(Rez.Strings.ModeCalorieAuto, "Auto (Calories)");
        _strSettingCarbsTarget = FuelPlannerUtils.loadString(Rez.Strings.SettingCarbsTarget, "Carbs target");
        _strSettingDoseSize = FuelPlannerUtils.loadString(Rez.Strings.SettingDoseSize, "Dose size");
        _strSettingCarbFraction = FuelPlannerUtils.loadString(Rez.Strings.SettingCarbFraction, "Carb fraction");
        _strSettingFixedInterval = FuelPlannerUtils.loadString(Rez.Strings.SettingFixedInterval, "Fixed interval");
        _strSettingStartDelay = FuelPlannerUtils.loadString(Rez.Strings.SettingStartDelay, "Start delay");
        _strSettingSnoozeTime = FuelPlannerUtils.loadString(Rez.Strings.SettingSnoozeTime, "Snooze time");
        _strLabelConfirmClear = FuelPlannerUtils.loadString(Rez.Strings.LabelConfirmClear, "Clear session?");
        _strEnabled = FuelPlannerUtils.loadString(Rez.Strings.LabelEnabled, "Enabled");
        _strDisabled = FuelPlannerUtils.loadString(Rez.Strings.LabelDisabled, "Disabled");
        _strUnitGramsPerHour = FuelPlannerUtils.loadString(Rez.Strings.UnitGramsPerHour, "g/h");
        _strUnitGrams = FuelPlannerUtils.loadString(Rez.Strings.UnitGrams, "g");
        _strUnitMinutes = FuelPlannerUtils.loadString(Rez.Strings.UnitMinutes, "min");
        _suffixGph = " " + _strUnitGramsPerHour;
        _suffixGrams = " " + _strUnitGrams;
        _suffixMinutes = " " + _strUnitMinutes;
    }

    private function refreshLiveModel() as Void {
        if (_model != null) {
            (_model as FuelModel).onSettingsChanged();
        }
        WatchUi.requestUpdate();
    }

    private function clampSetting(value as Number, min as Number, max as Number) as Number {
        if (value < min) { return min; }
        if (value > max) { return max; }
        return value;
    }

    //! Returns the localized display label for a reminder mode value
    private function modeLabel(mode as Number, intervalMin as Number) as String {
        if (mode == FuelReminderModes.AUTO) { return _strModeAuto; }
        if (mode == FuelReminderModes.FIXED) {
            return _strModeFixed + " " + intervalMin.format("%d") + _suffixMinutes;
        }
        return _strModeCalorieAuto;
    }

    private function toggleLabel(value as Number) as String {
        return (value != 0) ? _strEnabled : _strDisabled;
    }

    function onSelect(item as WatchUi.MenuItem) as Void {
        var id = item.getId();

        switch (id) {
            case :carbsTarget:
                pushNumberPicker(_strSettingCarbsTarget,
                    _storage.getCarbsTargetGph(),
                    _storage.MIN_CARBS_TARGET_GPH,
                    _storage.MAX_CARBS_TARGET_GPH,
                    10,
                    new NumberPickerDelegate(_fuelMenu.carbsItem,
                        new Lang.Method(_storage, :setCarbsTargetGph), _suffixGph,
                        _storage.MIN_CARBS_TARGET_GPH, _storage.MAX_CARBS_TARGET_GPH,
                        _model));
                break;

            case :doseSize:
                pushNumberPicker(_strSettingDoseSize,
                    _storage.getDoseG(),
                    _storage.MIN_DOSE_G,
                    _storage.MAX_DOSE_G,
                    5,
                    new NumberPickerDelegate(_fuelMenu.doseItem,
                        new Lang.Method(_storage, :setDoseG), _suffixGrams,
                        _storage.MIN_DOSE_G, _storage.MAX_DOSE_G,
                        _model));
                break;

            case :reminderMode:
                var currentMode = clampSetting(
                    _storage.getReminderMode(),
                    _storage.MIN_REMINDER_MODE,
                    _storage.MAX_REMINDER_MODE
                );
                var modeCount = _storage.MAX_REMINDER_MODE - _storage.MIN_REMINDER_MODE + 1;
                var newMode = (currentMode + 1) % modeCount;
                if (_storage.setReminderMode(newMode)) {
                    item.setSubLabel(modeLabel(newMode, _storage.getFixedIntervalMin()));
                    refreshLiveModel();
                }
                break;

            case :carbFraction:
                pushNumberPicker(_strSettingCarbFraction,
                    _storage.getCarbFractionPct(),
                    _storage.MIN_CARB_FRACTION_PCT,
                    _storage.MAX_CARB_FRACTION_PCT,
                    5,
                    new NumberPickerDelegate(_fuelMenu.carbFracItem,
                        new Lang.Method(_storage, :setCarbFractionPct), "%",
                        _storage.MIN_CARB_FRACTION_PCT, _storage.MAX_CARB_FRACTION_PCT,
                        _model));
                break;

            case :fixedInterval:
                pushNumberPicker(_strSettingFixedInterval,
                    _storage.getFixedIntervalMin(),
                    _storage.MIN_FIXED_INTERVAL_MIN,
                    _storage.MAX_FIXED_INTERVAL_MIN,
                    5,
                    new FixedIntervalDelegate(_storage, _fuelMenu.intervalItem,
                                             _fuelMenu.modeItem,
                                             _strModeAuto, _strModeFixed,
                                             _strModeCalorieAuto, _strUnitMinutes,
                                             _model));
                break;

            case :startDelay:
                pushNumberPicker(_strSettingStartDelay,
                    _storage.getStartDelayMin(),
                    _storage.MIN_START_DELAY_MIN,
                    _storage.MAX_START_DELAY_MIN,
                    5,
                    new NumberPickerDelegate(_fuelMenu.delayItem,
                        new Lang.Method(_storage, :setStartDelayMin), _suffixMinutes,
                        _storage.MIN_START_DELAY_MIN, _storage.MAX_START_DELAY_MIN,
                        _model));
                break;

            case :snoozeTime:
                pushNumberPicker(_strSettingSnoozeTime,
                    _storage.getMaxSnoozeMin(),
                    _storage.MIN_MAX_SNOOZE_MIN,
                    _storage.MAX_MAX_SNOOZE_MIN,
                    1,
                    new NumberPickerDelegate(_fuelMenu.snoozeItem,
                        new Lang.Method(_storage, :setMaxSnoozeMin), _suffixMinutes,
                        _storage.MIN_MAX_SNOOZE_MIN, _storage.MAX_MAX_SNOOZE_MIN,
                        _model));
                break;

            case :fullScreenAlerts:
                var newAlertState = (_storage.getDataFieldAlertEnabled() == 0) ? 1 : 0;
                if (_storage.setDataFieldAlertEnabled(newAlertState)) {
                    item.setSubLabel(toggleLabel(_storage.getDataFieldAlertEnabled()));
                    refreshLiveModel();
                }
                break;

            case :presetRun:
                applyPreset(60, 25);
                WatchUi.popView(WatchUi.SLIDE_RIGHT);
                break;

            case :presetBike:
                applyPreset(90, 30);
                WatchUi.popView(WatchUi.SLIDE_RIGHT);
                break;

            case :presetHike:
                applyPreset(40, 20);
                WatchUi.popView(WatchUi.SLIDE_RIGHT);
                break;

            case :clearSession:
                var confirm = new WatchUi.Confirmation(_strLabelConfirmClear);
                WatchUi.pushView(confirm, new ClearConfirmDelegate(_storage, _model), WatchUi.SLIDE_UP);
                break;

            case :separator:
                break;
        }
    }

    private function pushNumberPicker(title as String, current as Number, min as Number,
                                       max as Number, step as Number,
                                       delegate as WatchUi.Menu2InputDelegate) as Void {
        var safeMin = min;
        var safeMax = max;
        if (safeMax < safeMin) {
            safeMax = safeMin;
        }
        var safeCurrent = clampSetting(current, safeMin, safeMax);
        var safeStep = (step <= 0) ? 1 : step;

        WatchUi.pushView(new NumberPickerView(title, safeCurrent, safeMin, safeMax, safeStep),
                         delegate, WatchUi.SLIDE_LEFT);
    }

    private function applyPreset(carbsGph as Number, doseG as Number) as Void {
        var carbsSaved = _storage.setCarbsTargetGph(carbsGph);
        var doseSaved = _storage.setDoseG(doseG);
        var modeSaved = _storage.setReminderMode(FuelReminderModes.AUTO);
        var delaySaved = _storage.setStartDelayMin(15);
        if (!carbsSaved || !doseSaved || !modeSaved || !delaySaved) {
            FuelPlannerLog.logError("Settings", "Preset was only partially persisted");
        }

        var safeCarbs = _storage.getCarbsTargetGph();
        var safeDose = _storage.getDoseG();
        var safeDelay = _storage.getStartDelayMin();

        // Refresh affected items
        _fuelMenu.carbsItem.setSubLabel(safeCarbs.format("%d") + _suffixGph);
        _fuelMenu.doseItem.setSubLabel(safeDose.format("%d") + _suffixGrams);
        _fuelMenu.modeItem.setSubLabel(modeLabel(
            _storage.getReminderMode(),
            _storage.getFixedIntervalMin()
        ));
        _fuelMenu.delayItem.setSubLabel(safeDelay.format("%d") + _suffixMinutes);
        refreshLiveModel();
    }

    function onBack() as Void {
        WatchUi.popView(WatchUi.SLIDE_RIGHT);
    }
}

//! Generic number picker delegate - handles all simple setting pickers
class NumberPickerDelegate extends WatchUi.Menu2InputDelegate {
    private var _item   as WatchUi.MenuItem;
    private var _setter as Lang.Method;
    private var _model as FuelModel?;
    private var _suffix as String = "";
    private var _min as Number;
    private var _max as Number;

    function initialize(item as WatchUi.MenuItem,
                        setter as Lang.Method,
                        suffix as String,
                        min as Number,
                        max as Number,
                        model as FuelModel?) {
        Menu2InputDelegate.initialize();
        _item   = item;
        _setter = setter;
        _model = model;
        _suffix = suffix;
        if (max < min) {
            _min = max;
            _max = min;
        } else {
            _min = min;
            _max = max;
        }
    }

    private function clampSetting(value as Number) as Number {
        if (value < _min) { return _min; }
        if (value > _max) { return _max; }
        return value;
    }

    function onSelect(item as WatchUi.MenuItem) as Void {
        var selected = item.getId();
        if (!(selected instanceof Number)) {
            WatchUi.popView(WatchUi.SLIDE_RIGHT);
            return;
        }

        var value = clampSetting(selected as Number);
        var didPersist = false;
        try {
            var result = _setter.invoke(value);
            if (result instanceof Boolean) {
                didPersist = result;
            }
        } catch (e) {
            FuelPlannerLog.logError("Settings", "Failed to persist picker value");
        }
        if (didPersist) {
            _item.setSubLabel(value.format("%d") + _suffix);
            if (_model != null) {
                (_model as FuelModel).onSettingsChanged();
            }
            WatchUi.requestUpdate();
        }
        WatchUi.popView(WatchUi.SLIDE_RIGHT);
    }

    function onBack() as Void {
        WatchUi.popView(WatchUi.SLIDE_RIGHT);
    }
}

//! Fixed interval picker - also refreshes the mode label (which embeds the interval)
class FixedIntervalDelegate extends WatchUi.Menu2InputDelegate {
    private var _storage  as StorageManager;
    private var _item     as WatchUi.MenuItem;
    private var _modeItem as WatchUi.MenuItem;
    private var _model as FuelModel?;
    private var _strModeAuto as String = "";
    private var _strModeFixed as String = "";
    private var _strModeCalorieAuto as String = "";
    private var _strUnitMinutes as String = "";

    function initialize(storage as StorageManager, item as WatchUi.MenuItem,
                        modeItem as WatchUi.MenuItem,
                        modeAuto as String, modeFixed as String,
                        modeCalorieAuto as String, unitMinutes as String,
                        model as FuelModel?) {
        Menu2InputDelegate.initialize();
        _storage  = storage;
        _item     = item;
        _modeItem = modeItem;
        _model = model;
        _strModeAuto = modeAuto;
        _strModeFixed = modeFixed;
        _strModeCalorieAuto = modeCalorieAuto;
        _strUnitMinutes = unitMinutes;
    }

    private function modeLabel(mode as Number, intervalMin as Number) as String {
        if (mode == FuelReminderModes.AUTO) { return _strModeAuto; }
        if (mode == FuelReminderModes.FIXED) {
            return _strModeFixed + " " + intervalMin.format("%d") + " " + _strUnitMinutes;
        }
        return _strModeCalorieAuto;
    }

    function onSelect(item as WatchUi.MenuItem) as Void {
        var selected = item.getId();
        if (!(selected instanceof Number)) {
            WatchUi.popView(WatchUi.SLIDE_RIGHT);
            return;
        }

        var value = selected as Number;
        if (value < _storage.MIN_FIXED_INTERVAL_MIN) {
            value = _storage.MIN_FIXED_INTERVAL_MIN;
        } else if (value > _storage.MAX_FIXED_INTERVAL_MIN) {
            value = _storage.MAX_FIXED_INTERVAL_MIN;
        }

        if (_storage.setFixedIntervalMin(value)) {
            var storedValue = _storage.getFixedIntervalMin();
            _item.setSubLabel(storedValue.format("%d") + " " + _strUnitMinutes);
            _modeItem.setSubLabel(modeLabel(_storage.getReminderMode(), storedValue));
            if (_model != null) {
                (_model as FuelModel).onSettingsChanged();
            }
            WatchUi.requestUpdate();
        }
        WatchUi.popView(WatchUi.SLIDE_RIGHT);
    }

    function onBack() as Void {
        WatchUi.popView(WatchUi.SLIDE_RIGHT);
    }
}

//! Clear session confirmation delegate
class ClearConfirmDelegate extends WatchUi.ConfirmationDelegate {
    private var _storage as StorageManager;
    private var _model as FuelModel?;

    function initialize(storage as StorageManager, model as FuelModel?) {
        ConfirmationDelegate.initialize();
        _storage = storage;
        _model = model;
    }

    function onResponse(response as WatchUi.Confirm) as Boolean {
        if (response == WatchUi.CONFIRM_YES) {
            _storage.clearSession();
            if (_model != null) {
                (_model as FuelModel).clearSessionState();
            }
        }
        WatchUi.popView(WatchUi.SLIDE_DOWN);
        WatchUi.requestUpdate();
        return true;
    }
}
