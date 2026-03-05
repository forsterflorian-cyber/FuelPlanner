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
        var model = _model as FuelModel;
        model.loadSession();
    }

    public function onStop(state as Dictionary?) as Void {
        if (_model != null) {
            var model = _model as FuelModel;
            model.saveSession();
        }
    }

    public function onSettingsChanged() as Void {
        if (_storage == null) {
            _storage = new StorageManager();
        }
        if (_model == null) {
            _model = new FuelModel(_storage);
            var model = _model as FuelModel;
            model.loadSession();
        }

        var activeModel = _model as FuelModel;
        activeModel.onSettingsChanged();
        WatchUi.requestUpdate();
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
        var inputDelegate = new FuelPlannerFieldDelegate(model, reminder, view);
        return [view, inputDelegate];
    }

    public function getSettingsView() as [Views] or [Views, InputDelegates] or Null {
        var storage = new StorageManager();
        var menu = new FuelPlannerMenu(storage);
        var inputDelegate = new FuelPlannerMenuDelegate(storage, menu);
        return [menu, inputDelegate];
    }

}
