import Toybox.Lang;
import Toybox.WatchUi;

//! Menu delegate for settings
class FuelPlannerMenuDelegate extends WatchUi.Menu2InputDelegate {

    private var _storage as StorageManager;
    private var _fuelMenu as FuelPlannerMenu;

    function initialize(storage as StorageManager, menu as FuelPlannerMenu) {
        Menu2InputDelegate.initialize();
        _storage = storage;
        _fuelMenu = menu;
    }

    //! Returns the localized display label for a reminder mode value
    static function modeLabel(mode as Number, intervalMin as Number) as String {
        if (mode == 0) { return WatchUi.loadResource(Rez.Strings.ModeAuto) as String; }
        if (mode == 1) {
            return (WatchUi.loadResource(Rez.Strings.ModeFixed) as String) + " " +
                   intervalMin.format("%d") + "min";
        }
        return WatchUi.loadResource(Rez.Strings.ModeCalorieAuto) as String;
    }

    function onSelect(item as WatchUi.MenuItem) as Void {
        var id = item.getId();

        switch (id) {
            case :carbsTarget:
                pushNumberPicker("Carbs (g/h)", _storage.getCarbsTargetGph(), 20, 120, 10,
                    new NumberPickerDelegate(_fuelMenu.carbsItem,
                        new Lang.Method(_storage, :setCarbsTargetGph), " g/h"));
                break;

            case :doseSize:
                pushNumberPicker("Gel Size (g)", _storage.getDoseG(), 5, 60, 5,
                    new NumberPickerDelegate(_fuelMenu.doseItem,
                        new Lang.Method(_storage, :setDoseG), " g"));
                break;

            case :reminderMode:
                var newMode = (_storage.getReminderMode() + 1) % 3;
                _storage.setReminderMode(newMode);
                item.setSubLabel(modeLabel(newMode, _storage.getFixedIntervalMin()));
                break;

            case :carbFraction:
                pushNumberPicker("Carb % of kcal", _storage.getCarbFractionPct(), 40, 80, 5,
                    new NumberPickerDelegate(_fuelMenu.carbFracItem,
                        new Lang.Method(_storage, :setCarbFractionPct), "%"));
                break;

            case :fixedInterval:
                pushNumberPicker("Interval (min)", _storage.getFixedIntervalMin(), 5, 60, 5,
                    new FixedIntervalDelegate(_storage, _fuelMenu.intervalItem,
                                             _fuelMenu.modeItem));
                break;

            case :startDelay:
                pushNumberPicker("Delay (min)", _storage.getStartDelayMin(), 0, 30, 5,
                    new NumberPickerDelegate(_fuelMenu.delayItem,
                        new Lang.Method(_storage, :setStartDelayMin), " min"));
                break;

            case :snoozeTime:
                pushNumberPicker("Snooze (min)", _storage.getMaxSnoozeMin(), 1, 10, 1,
                    new NumberPickerDelegate(_fuelMenu.snoozeItem,
                        new Lang.Method(_storage, :setMaxSnoozeMin), " min"));
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
                var confirm = new WatchUi.Confirmation("Clear session?");
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
        _fuelMenu.carbsItem.setSubLabel(carbsGph.format("%d") + " g/h");
        _fuelMenu.doseItem.setSubLabel(doseG.format("%d") + " g");
        _fuelMenu.modeItem.setSubLabel(modeLabel(0, _storage.getFixedIntervalMin()));
        _fuelMenu.delayItem.setSubLabel("15 min");
    }

    function onBack() as Void {
        WatchUi.popView(WatchUi.SLIDE_RIGHT);
    }
}

//! Generic number picker delegate — handles all simple setting pickers
class NumberPickerDelegate extends WatchUi.Menu2InputDelegate {
    private var _item   as WatchUi.MenuItem;
    private var _setter as Lang.Method;
    private var _suffix as String;

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

//! Fixed interval picker — also refreshes the mode label (which embeds the interval)
class FixedIntervalDelegate extends WatchUi.Menu2InputDelegate {
    private var _storage  as StorageManager;
    private var _item     as WatchUi.MenuItem;
    private var _modeItem as WatchUi.MenuItem;

    function initialize(storage as StorageManager, item as WatchUi.MenuItem,
                        modeItem as WatchUi.MenuItem) {
        Menu2InputDelegate.initialize();
        _storage  = storage;
        _item     = item;
        _modeItem = modeItem;
    }

    function onSelect(item as WatchUi.MenuItem) as Void {
        var value = item.getId() as Number;
        _storage.setFixedIntervalMin(value);
        _item.setSubLabel(value.format("%d") + " min");
        _modeItem.setSubLabel(FuelPlannerMenuDelegate.modeLabel(
            _storage.getReminderMode(), value));
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
