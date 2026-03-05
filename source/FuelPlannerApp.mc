import Toybox.Application;
import Toybox.Lang;
import Toybox.WatchUi;

class FuelPlannerApp extends Application.AppBase {
    
    private var _model as FuelModel?;
    private var _storage as StorageManager?;
    private var _reminder as ReminderManager?;
    
    function initialize() {
        AppBase.initialize();
    }
    
    function onStart(state as Dictionary?) as Void {
        _storage = new StorageManager();
        _model = new FuelModel(_storage);
        _reminder = new ReminderManager();
        _model.loadSession();
    }
    
    function onStop(state as Dictionary?) as Void {
        if (_model != null) {
            _model.saveSession();
        }
    }
    
    function getInitialView() as [Views] or [Views, InputDelegates] {
        if (_model == null || _storage == null || _reminder == null) {
            _storage = new StorageManager();
            _model = new FuelModel(_storage);
            _reminder = new ReminderManager();
        }
        
        var view = new FuelPlannerFieldView(_model, _reminder);
        var delegate = new FuelPlannerFieldDelegate(_model, _reminder);
        return [view, delegate];
    }
}