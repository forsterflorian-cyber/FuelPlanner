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

    //! Returns the display label for a reminder mode value
    static function modeLabel(mode as Number, intervalMin as Number) as String {
        if (mode == 0) { return "Auto (deficit)"; }
        if (mode == 1) { return "Fixed " + intervalMin.format("%d") + "min"; }
        return "Calorie Auto";
    }

    function onSelect(item as WatchUi.MenuItem) as Void {
        var id = item.getId();

        switch (id) {
            case :carbsTarget:
                pushNumberPicker("Carbs (g/h)", _storage.getCarbsTargetGph(), 20, 120, 10,
                    new CarbsTargetDelegate(_storage, _fuelMenu.carbsItem));
                break;

            case :doseSize:
                pushNumberPicker("Gel Size (g)", _storage.getDoseG(), 5, 60, 5,
                    new DoseSizeDelegate(_storage, _fuelMenu.doseItem));
                break;

            case :reminderMode:
                var newMode = (_storage.getReminderMode() + 1) % 3;
                _storage.setReminderMode(newMode);
                item.setSubLabel(modeLabel(newMode, _storage.getFixedIntervalMin()));
                break;

            case :carbFraction:
                pushNumberPicker("Carb % of kcal", _storage.getCarbFractionPct(), 40, 80, 5,
                    new CarbFractionDelegate(_storage, _fuelMenu.carbFracItem));
                break;

            case :fixedInterval:
                pushNumberPicker("Interval (min)", _storage.getFixedIntervalMin(), 5, 60, 5,
                    new FixedIntervalDelegate(_storage, _fuelMenu.intervalItem,
                                             _fuelMenu.modeItem));
                break;

            case :startDelay:
                pushNumberPicker("Delay (min)", _storage.getStartDelayMin(), 0, 30, 5,
                    new StartDelayDelegate(_storage, _fuelMenu.delayItem));
                break;

            case :snoozeTime:
                pushNumberPicker("Snooze (min)", _storage.getMaxSnoozeMin(), 1, 10, 1,
                    new SnoozeTimeDelegate(_storage, _fuelMenu.snoozeItem));
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

//! Carbs target picker delegate
class CarbsTargetDelegate extends WatchUi.Menu2InputDelegate {
    private var _storage as StorageManager;
    private var _item as WatchUi.MenuItem;

    function initialize(storage as StorageManager, item as WatchUi.MenuItem) {
        Menu2InputDelegate.initialize();
        _storage = storage;
        _item = item;
    }

    function onSelect(item as WatchUi.MenuItem) as Void {
        var value = item.getId() as Number;
        _storage.setCarbsTargetGph(value);
        _item.setSubLabel(value.format("%d") + " g/h");
        WatchUi.popView(WatchUi.SLIDE_RIGHT);
    }

    function onBack() as Void {
        WatchUi.popView(WatchUi.SLIDE_RIGHT);
    }
}

//! Dose size picker delegate
class DoseSizeDelegate extends WatchUi.Menu2InputDelegate {
    private var _storage as StorageManager;
    private var _item as WatchUi.MenuItem;

    function initialize(storage as StorageManager, item as WatchUi.MenuItem) {
        Menu2InputDelegate.initialize();
        _storage = storage;
        _item = item;
    }

    function onSelect(item as WatchUi.MenuItem) as Void {
        var value = item.getId() as Number;
        _storage.setDoseG(value);
        _item.setSubLabel(value.format("%d") + " g");
        WatchUi.popView(WatchUi.SLIDE_RIGHT);
    }

    function onBack() as Void {
        WatchUi.popView(WatchUi.SLIDE_RIGHT);
    }
}

//! Fixed interval picker delegate
class FixedIntervalDelegate extends WatchUi.Menu2InputDelegate {
    private var _storage as StorageManager;
    private var _item as WatchUi.MenuItem;
    private var _modeItem as WatchUi.MenuItem;

    function initialize(storage as StorageManager, item as WatchUi.MenuItem,
                        modeItem as WatchUi.MenuItem) {
        Menu2InputDelegate.initialize();
        _storage = storage;
        _item = item;
        _modeItem = modeItem;
    }

    function onSelect(item as WatchUi.MenuItem) as Void {
        var value = item.getId() as Number;
        _storage.setFixedIntervalMin(value);
        _item.setSubLabel(value.format("%d") + " min");
        // Refresh mode label — it embeds the interval when mode is Fixed
        _modeItem.setSubLabel(FuelPlannerMenuDelegate.modeLabel(
            _storage.getReminderMode(), value));
        WatchUi.popView(WatchUi.SLIDE_RIGHT);
    }

    function onBack() as Void {
        WatchUi.popView(WatchUi.SLIDE_RIGHT);
    }
}

//! Start delay picker delegate
class StartDelayDelegate extends WatchUi.Menu2InputDelegate {
    private var _storage as StorageManager;
    private var _item as WatchUi.MenuItem;

    function initialize(storage as StorageManager, item as WatchUi.MenuItem) {
        Menu2InputDelegate.initialize();
        _storage = storage;
        _item = item;
    }

    function onSelect(item as WatchUi.MenuItem) as Void {
        var value = item.getId() as Number;
        _storage.setStartDelayMin(value);
        _item.setSubLabel(value.format("%d") + " min");
        WatchUi.popView(WatchUi.SLIDE_RIGHT);
    }

    function onBack() as Void {
        WatchUi.popView(WatchUi.SLIDE_RIGHT);
    }
}

//! Snooze time picker delegate
class SnoozeTimeDelegate extends WatchUi.Menu2InputDelegate {
    private var _storage as StorageManager;
    private var _item as WatchUi.MenuItem;

    function initialize(storage as StorageManager, item as WatchUi.MenuItem) {
        Menu2InputDelegate.initialize();
        _storage = storage;
        _item = item;
    }

    function onSelect(item as WatchUi.MenuItem) as Void {
        var value = item.getId() as Number;
        _storage.setMaxSnoozeMin(value);
        _item.setSubLabel(value.format("%d") + " min");
        WatchUi.popView(WatchUi.SLIDE_RIGHT);
    }

    function onBack() as Void {
        WatchUi.popView(WatchUi.SLIDE_RIGHT);
    }
}

//! Carb fraction picker delegate
class CarbFractionDelegate extends WatchUi.Menu2InputDelegate {
    private var _storage as StorageManager;
    private var _item as WatchUi.MenuItem;

    function initialize(storage as StorageManager, item as WatchUi.MenuItem) {
        Menu2InputDelegate.initialize();
        _storage = storage;
        _item = item;
    }

    function onSelect(item as WatchUi.MenuItem) as Void {
        var value = item.getId() as Number;
        _storage.setCarbFractionPct(value);
        _item.setSubLabel(value.format("%d") + "%");
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
