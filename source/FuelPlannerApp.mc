import Toybox.Application;
import Toybox.FitContributor;
import Toybox.Lang;
import Toybox.WatchUi;

class FuelPlannerApp extends Application.AppBase {

    private var _model as FuelModel? = null;
    private var _storage as StorageManager? = null;
    private var _reminder as ReminderManager? = null;
    private var _fieldDeficit as FitContributor.Field? = null;
    private var _fieldConsumed as FitContributor.Field? = null;

    private const FIT_FIELD_ID_DEFICIT = 0;
    private const FIT_FIELD_ID_CONSUMED = 1;
    private const FIT_UNIT_GRAMS = "g";

    public function initialize() {
        AppBase.initialize();
    }

    public function onStart(state as Dictionary?) as Void {
        _storage = new StorageManager();
        var storage = _storage as StorageManager;
        _model = new FuelModel(storage);
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
        var storage = _storage as StorageManager;

        if (_model == null) {
            _model = new FuelModel(storage);
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
            var storage = _storage as StorageManager;
            _model = new FuelModel(storage);
            _reminder = new ReminderManager();
        }

        var model = _model as FuelModel;
        var reminder = _reminder as ReminderManager;
        var view = new FuelPlannerFieldView(model, reminder);
        ensureFitFields(view);
        model.setFitFields(_fieldDeficit, _fieldConsumed);
        var inputDelegate = new FuelPlannerFieldDelegate(model, reminder, view);
        return [view, inputDelegate];
    }

    private function ensureFitFields(view as FuelPlannerFieldView) as Void {
        if (_fieldDeficit == null) {
            try {
                _fieldDeficit = view.createField(
                    "Aktuelles Defizit",
                    FIT_FIELD_ID_DEFICIT,
                    FitContributor.DATA_TYPE_FLOAT,
                    { :mesgType => FitContributor.MESG_TYPE_RECORD, :units => FIT_UNIT_GRAMS }
                );
            } catch (e) {
                _fieldDeficit = null;
            }
        }

        if (_fieldConsumed == null) {
            try {
                _fieldConsumed = view.createField(
                    "Gesamtaufnahme",
                    FIT_FIELD_ID_CONSUMED,
                    FitContributor.DATA_TYPE_FLOAT,
                    { :mesgType => FitContributor.MESG_TYPE_RECORD, :units => FIT_UNIT_GRAMS }
                );
            } catch (e) {
                _fieldConsumed = null;
            }
        }
    }

    public function getSettingsView() as [Views] or [Views, InputDelegates] or Null {
        var storage = new StorageManager();
        var menu = new FuelPlannerMenu(storage);
        var inputDelegate = new FuelPlannerMenuDelegate(storage, menu);
        return [menu, inputDelegate];
    }

}
