import Toybox.Lang;
import Toybox.WatchUi;

//! Menu delegate for settings
class FuelPlannerMenuDelegate extends WatchUi.Menu2InputDelegate {

    private var _storage as StorageManager;
    private var _fuelMenu as FuelPlannerMenu;
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

    function initialize(storage as StorageManager, menu as FuelPlannerMenu) {
        Menu2InputDelegate.initialize();
        _storage = storage;
        _fuelMenu = menu;
        loadStrings();
    }

    private function loadStrings() as Void {
        _strModeAuto = WatchUi.loadResource(Rez.Strings.ModeAuto) as String;
        _strModeFixed = WatchUi.loadResource(Rez.Strings.ModeFixed) as String;
        _strModeCalorieAuto = WatchUi.loadResource(Rez.Strings.ModeCalorieAuto) as String;
        _strSettingCarbsTarget = WatchUi.loadResource(Rez.Strings.SettingCarbsTarget) as String;
        _strSettingDoseSize = WatchUi.loadResource(Rez.Strings.SettingDoseSize) as String;
        _strSettingCarbFraction = WatchUi.loadResource(Rez.Strings.SettingCarbFraction) as String;
        _strSettingFixedInterval = WatchUi.loadResource(Rez.Strings.SettingFixedInterval) as String;
        _strSettingStartDelay = WatchUi.loadResource(Rez.Strings.SettingStartDelay) as String;
        _strSettingSnoozeTime = WatchUi.loadResource(Rez.Strings.SettingSnoozeTime) as String;
        _strLabelConfirmClear = WatchUi.loadResource(Rez.Strings.LabelConfirmClear) as String;
        _strUnitGramsPerHour = WatchUi.loadResource(Rez.Strings.UnitGramsPerHour) as String;
        _strUnitGrams = WatchUi.loadResource(Rez.Strings.UnitGrams) as String;
        _strUnitMinutes = WatchUi.loadResource(Rez.Strings.UnitMinutes) as String;
        _suffixGph = " " + _strUnitGramsPerHour;
        _suffixGrams = " " + _strUnitGrams;
        _suffixMinutes = " " + _strUnitMinutes;
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
                pushNumberPicker(_strSettingCarbsTarget, _storage.getCarbsTargetGph(), 20, 120, 10,
                    new NumberPickerDelegate(_fuelMenu.carbsItem,
                        new Lang.Method(_storage, :setCarbsTargetGph), _suffixGph));
                break;

            case :doseSize:
                pushNumberPicker(_strSettingDoseSize, _storage.getDoseG(), 5, 100, 5,
                    new NumberPickerDelegate(_fuelMenu.doseItem,
                        new Lang.Method(_storage, :setDoseG), _suffixGrams));
                break;

            case :reminderMode:
                var newMode = (_storage.getReminderMode() + 1) % 3;
                _storage.setReminderMode(newMode);
                item.setSubLabel(modeLabel(newMode, _storage.getFixedIntervalMin()));
                break;

            case :carbFraction:
                pushNumberPicker(_strSettingCarbFraction, _storage.getCarbFractionPct(), 40, 80, 5,
                    new NumberPickerDelegate(_fuelMenu.carbFracItem,
                        new Lang.Method(_storage, :setCarbFractionPct), "%"));
                break;

            case :fixedInterval:
                pushNumberPicker(_strSettingFixedInterval, _storage.getFixedIntervalMin(), 5, 60, 5,
                    new FixedIntervalDelegate(_storage, _fuelMenu.intervalItem,
                                             _fuelMenu.modeItem,
                                             _strModeAuto, _strModeFixed,
                                             _strModeCalorieAuto, _strUnitMinutes));
                break;

            case :startDelay:
                pushNumberPicker(_strSettingStartDelay, _storage.getStartDelayMin(), 0, 60, 5,
                    new NumberPickerDelegate(_fuelMenu.delayItem,
                        new Lang.Method(_storage, :setStartDelayMin), _suffixMinutes));
                break;

            case :snoozeTime:
                pushNumberPicker(_strSettingSnoozeTime, _storage.getMaxSnoozeMin(), 1, 15, 1,
                    new NumberPickerDelegate(_fuelMenu.snoozeItem,
                        new Lang.Method(_storage, :setMaxSnoozeMin), _suffixMinutes));
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
                WatchUi.pushView(confirm, new ClearConfirmDelegate(_storage), WatchUi.SLIDE_UP);
                break;

            case :separator:
                break;
        }
    }

    private function pushNumberPicker(title as String, current as Number, min as Number,
                                       max as Number, step as Number,
                                       delegate as WatchUi.Menu2InputDelegate) as Void {
        WatchUi.pushView(new NumberPickerView(title, current, min, max, step),
                         delegate, WatchUi.SLIDE_LEFT);
    }

    private function applyPreset(carbsGph as Number, doseG as Number) as Void {
        _storage.setCarbsTargetGph(carbsGph);
        _storage.setDoseG(doseG);
        _storage.setReminderMode(0);
        _storage.setStartDelayMin(15);
        // Refresh affected items
        _fuelMenu.carbsItem.setSubLabel(carbsGph.format("%d") + _suffixGph);
        _fuelMenu.doseItem.setSubLabel(doseG.format("%d") + _suffixGrams);
        _fuelMenu.modeItem.setSubLabel(modeLabel(0, _storage.getFixedIntervalMin()));
        _fuelMenu.delayItem.setSubLabel("15" + _suffixMinutes);
    }

    function onBack() as Void {
        WatchUi.popView(WatchUi.SLIDE_RIGHT);
    }
}

//! Generic number picker delegate - handles all simple setting pickers
class NumberPickerDelegate extends WatchUi.Menu2InputDelegate {
    private var _item   as WatchUi.MenuItem;
    private var _setter as Lang.Method;
    private var _suffix as String = "";

    function initialize(item as WatchUi.MenuItem,
                        setter as Lang.Method,
                        suffix as String) {
        Menu2InputDelegate.initialize();
        _item   = item;
        _setter = setter;
        _suffix = suffix;
    }

    function onSelect(item as WatchUi.MenuItem) as Void {
        var value = item.getId() as Number;
        _setter.invoke(value);
        _item.setSubLabel(value.format("%d") + _suffix);
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
        var value = item.getId() as Number;
        _storage.setFixedIntervalMin(value);
        _item.setSubLabel(value.format("%d") + " " + _strUnitMinutes);
        _modeItem.setSubLabel(modeLabel(_storage.getReminderMode(), value));
        WatchUi.popView(WatchUi.SLIDE_RIGHT);
    }

    function onBack() as Void {
        WatchUi.popView(WatchUi.SLIDE_RIGHT);
    }
}

//! Clear session confirmation delegate
class ClearConfirmDelegate extends WatchUi.ConfirmationDelegate {
    private var _storage as StorageManager;

    function initialize(storage as StorageManager) {
        ConfirmationDelegate.initialize();
        _storage = storage;
    }

    function onResponse(response as WatchUi.Confirm) as Boolean {
        if (response == WatchUi.CONFIRM_YES) {
            _storage.clearSession();
            _storage.clearIntakeLog();
        }
        WatchUi.popView(WatchUi.SLIDE_DOWN);
        return true;
    }
}
