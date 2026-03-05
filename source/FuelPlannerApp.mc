import Toybox.Application;
import Toybox.Lang;
import Toybox.WatchUi;

class FuelPlannerApp extends Application.AppBase {

    private var _model;
    private var _storage;
    private var _reminder;

    public function initialize() {
        AppBase.initialize();
    }

    public function onStart(state as Dictionary?) as Void {
        _storage = new StorageManager();
        _model = new FuelModel(_storage);
        _reminder = new ReminderManager();
        (_model as FuelModel).loadSession();
    }

    public function onStop(state as Dictionary?) as Void {
        if (_model != null) {
            (_model as FuelModel).saveSession();
        }
    }

    public function getInitialView() as [Views] or [Views, InputDelegates] {
        if (_model == null || _storage == null || _reminder == null) {
            _storage = new StorageManager();
            _model = new FuelModel(_storage);
            _reminder = new ReminderManager();
        }

        var model = _model as FuelModel;
        var reminder = _reminder as ReminderManager;
        var view = new FuelPlannerFieldView(model, reminder);
        var delegate = new FuelPlannerFieldDelegate(model, reminder, view);
        return [view, delegate];
    }

    public function getSettingsView() as [Views] or [Views, InputDelegates] or Null {
        var storage = new StorageManager();
        var menu = new FuelPlannerMenu(storage);
        var delegate = new FuelPlannerMenuDelegate(storage, menu);
        return [menu, delegate];
    }
}
