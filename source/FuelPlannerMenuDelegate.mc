import Toybox.Lang;
import Toybox.WatchUi;

//! Menu delegate for settings
(:full)
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
        _strModeAuto = loadString(Rez.Strings.ModeAuto, "Auto");
        _strModeFixed = loadString(Rez.Strings.ModeFixed, "Fixed");
        _strModeCalorieAuto = loadString(Rez.Strings.ModeCalorieAuto, "Auto (Calories)");
        _strSettingCarbsTarget = loadString(Rez.Strings.SettingCarbsTarget, "Carbs target");
        _strSettingDoseSize = loadString(Rez.Strings.SettingDoseSize, "Dose size");
        _strSettingCarbFraction = loadString(Rez.Strings.SettingCarbFraction, "Carb fraction");
        _strSettingFixedInterval = loadString(Rez.Strings.SettingFixedInterval, "Fixed interval");
        _strSettingStartDelay = loadString(Rez.Strings.SettingStartDelay, "Start delay");
        _strSettingSnoozeTime = loadString(Rez.Strings.SettingSnoozeTime, "Snooze time");
        _strLabelConfirmClear = loadString(Rez.Strings.LabelConfirmClear, "Clear session?");
        _strUnitGramsPerHour = loadString(Rez.Strings.UnitGramsPerHour, "g/h");
        _strUnitGrams = loadString(Rez.Strings.UnitGrams, "g");
        _strUnitMinutes = loadString(Rez.Strings.UnitMinutes, "min");
        _suffixGph = " " + _strUnitGramsPerHour;
        _suffixGrams = " " + _strUnitGrams;
        _suffixMinutes = " " + _strUnitMinutes;
    }

    private function clampSetting(value as Number, min as Number, max as Number) as Number {
        if (value < min) { return min; }
        if (value > max) { return max; }
        return value;
    }

    //! Returns the localized display label for a reminder mode value
    private function modeLabel(mode as Number, intervalMin as Number) as String {
        if (mode == 0) { return _strModeAuto; }
        if (mode == 1) {
            return _strModeFixed + " " + intervalMin.format("%d") + _suffixMinutes;
        }
        return _strModeCalorieAuto;
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
                        _storage.MIN_CARBS_TARGET_GPH, _storage.MAX_CARBS_TARGET_GPH));
                break;

            case :doseSize:
                pushNumberPicker(_strSettingDoseSize,
                    _storage.getDoseG(),
                    _storage.MIN_DOSE_G,
                    _storage.MAX_DOSE_G,
                    5,
                    new NumberPickerDelegate(_fuelMenu.doseItem,
                        new Lang.Method(_storage, :setDoseG), _suffixGrams,
                        _storage.MIN_DOSE_G, _storage.MAX_DOSE_G));
                break;

            case :reminderMode:
                var currentMode = clampSetting(
                    _storage.getReminderMode(),
                    _storage.MIN_REMINDER_MODE,
                    _storage.MAX_REMINDER_MODE
                );
                var modeCount = _storage.MAX_REMINDER_MODE - _storage.MIN_REMINDER_MODE + 1;
                var newMode = (currentMode + 1) % modeCount;
                _storage.setReminderMode(newMode);
                item.setSubLabel(modeLabel(newMode, _storage.getFixedIntervalMin()));
                break;

            case :carbFraction:
                pushNumberPicker(_strSettingCarbFraction,
                    _storage.getCarbFractionPct(),
                    _storage.MIN_CARB_FRACTION_PCT,
                    _storage.MAX_CARB_FRACTION_PCT,
                    5,
                    new NumberPickerDelegate(_fuelMenu.carbFracItem,
                        new Lang.Method(_storage, :setCarbFractionPct), "%",
                        _storage.MIN_CARB_FRACTION_PCT, _storage.MAX_CARB_FRACTION_PCT));
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
                                             _strModeCalorieAuto, _strUnitMinutes));
                break;

            case :startDelay:
                pushNumberPicker(_strSettingStartDelay,
                    _storage.getStartDelayMin(),
                    _storage.MIN_START_DELAY_MIN,
                    _storage.MAX_START_DELAY_MIN,
                    5,
                    new NumberPickerDelegate(_fuelMenu.delayItem,
                        new Lang.Method(_storage, :setStartDelayMin), _suffixMinutes,
                        _storage.MIN_START_DELAY_MIN, _storage.MAX_START_DELAY_MIN));
                break;

            case :snoozeTime:
                pushNumberPicker(_strSettingSnoozeTime,
                    _storage.getMaxSnoozeMin(),
                    _storage.MIN_MAX_SNOOZE_MIN,
                    _storage.MAX_MAX_SNOOZE_MIN,
                    1,
                    new NumberPickerDelegate(_fuelMenu.snoozeItem,
                        new Lang.Method(_storage, :setMaxSnoozeMin), _suffixMinutes,
                        _storage.MIN_MAX_SNOOZE_MIN, _storage.MAX_MAX_SNOOZE_MIN));
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
        _storage.setCarbsTargetGph(carbsGph);
        _storage.setDoseG(doseG);
        _storage.setReminderMode(0);
        _storage.setStartDelayMin(15);

        var safeCarbs = _storage.getCarbsTargetGph();
        var safeDose = _storage.getDoseG();
        var safeDelay = _storage.getStartDelayMin();

        // Refresh affected items
        _fuelMenu.carbsItem.setSubLabel(safeCarbs.format("%d") + _suffixGph);
        _fuelMenu.doseItem.setSubLabel(safeDose.format("%d") + _suffixGrams);
        _fuelMenu.modeItem.setSubLabel(modeLabel(0, _storage.getFixedIntervalMin()));
        _fuelMenu.delayItem.setSubLabel(safeDelay.format("%d") + _suffixMinutes);
    }

    function onBack() as Void {
        WatchUi.popView(WatchUi.SLIDE_RIGHT);
    }
}

//! Generic number picker delegate - handles all simple setting pickers
(:full)
class NumberPickerDelegate extends WatchUi.Menu2InputDelegate {
    private var _item   as WatchUi.MenuItem;
    private var _setter as Lang.Method;
    private var _suffix as String = "";
    private var _min as Number;
    private var _max as Number;

    function initialize(item as WatchUi.MenuItem,
                        setter as Lang.Method,
                        suffix as String,
                        min as Number,
                        max as Number) {
        Menu2InputDelegate.initialize();
        _item   = item;
        _setter = setter;
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
            _setter.invoke(value);
            didPersist = true;
        } catch (e) {}
        if (didPersist) {
            _item.setSubLabel(value.format("%d") + _suffix);
        }
        WatchUi.popView(WatchUi.SLIDE_RIGHT);
    }

    function onBack() as Void {
        WatchUi.popView(WatchUi.SLIDE_RIGHT);
    }
}

//! Fixed interval picker - also refreshes the mode label (which embeds the interval)
(:full)
class FixedIntervalDelegate extends WatchUi.Menu2InputDelegate {
    private var _storage  as StorageManager;
    private var _item     as WatchUi.MenuItem;
    private var _modeItem as WatchUi.MenuItem;
    private var _strModeAuto as String = "";
    private var _strModeFixed as String = "";
    private var _strModeCalorieAuto as String = "";
    private var _strUnitMinutes as String = "";

    function initialize(storage as StorageManager, item as WatchUi.MenuItem,
                        modeItem as WatchUi.MenuItem,
                        modeAuto as String, modeFixed as String,
                        modeCalorieAuto as String, unitMinutes as String) {
        Menu2InputDelegate.initialize();
        _storage  = storage;
        _item     = item;
        _modeItem = modeItem;
        _strModeAuto = modeAuto;
        _strModeFixed = modeFixed;
        _strModeCalorieAuto = modeCalorieAuto;
        _strUnitMinutes = unitMinutes;
    }

    private function modeLabel(mode as Number, intervalMin as Number) as String {
        if (mode == 0) { return _strModeAuto; }
        if (mode == 1) {
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

        _storage.setFixedIntervalMin(value);
        var storedValue = _storage.getFixedIntervalMin();
        _item.setSubLabel(storedValue.format("%d") + " " + _strUnitMinutes);
        _modeItem.setSubLabel(modeLabel(_storage.getReminderMode(), storedValue));
        WatchUi.popView(WatchUi.SLIDE_RIGHT);
    }

    function onBack() as Void {
        WatchUi.popView(WatchUi.SLIDE_RIGHT);
    }
}

//! Clear session confirmation delegate
(:full)
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
