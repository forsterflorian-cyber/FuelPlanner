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
    private var _fieldTargetSummary as FitContributor.Field? = null;
    private var _fieldActualSummary as FitContributor.Field? = null;

    private const FIT_FIELD_ID_DEFICIT = 0;
    private const FIT_FIELD_ID_CONSUMED = 1;
    private const FIT_FIELD_ID_TARGET_SUMMARY = 2;
    private const FIT_FIELD_ID_ACTUAL_SUMMARY = 3;
    private const FIT_UNIT_GRAMS = "g";

    public function initialize() {
        AppBase.initialize();
    }

    public function onStart(state as Dictionary?) as Void {
        _storage = new StorageManager(null, null);
        var storage = _storage as StorageManager;
        _model = new FuelModel(storage, null);
        _reminder = new ReminderManager();
        var model = _model as FuelModel;
        model.loadSession();
    }

    public function onStop(state as Dictionary?) as Void {
        if (_model != null) {
            var model = _model as FuelModel;
            model.flushFitSessionSummary();
            model.saveSession();
        }
    }

    public function onSettingsChanged() as Void {
        if (_storage == null) {
            _storage = new StorageManager(null, null);
        }
        var storage = _storage as StorageManager;

        if (_model == null) {
            _model = new FuelModel(storage, null);
            var model = _model as FuelModel;
            model.loadSession();
        }

        var activeModel = _model as FuelModel;
        activeModel.onSettingsChanged();
        WatchUi.requestUpdate();
    }

    public function getInitialView() as [Views] or [Views, InputDelegates] {
        if (_model == null || _storage == null || _reminder == null) {
            _storage = new StorageManager(null, null);
            var storage = _storage as StorageManager;
            _model = new FuelModel(storage, null);
            _reminder = new ReminderManager();
        }

        var model = _model as FuelModel;
        var reminder = _reminder as ReminderManager;
        var view = new FuelPlannerFieldView(model, reminder);
        ensureFitFields(view);
        model.setFitFields(_fieldDeficit, _fieldConsumed, _fieldTargetSummary, _fieldActualSummary);
        var inputDelegate = new FuelPlannerFieldDelegate(model, reminder, view);
        return [view, inputDelegate];
    }

    private function ensureFitFields(view as FuelPlannerFieldView) as Void {
        if (_fieldDeficit == null) {
            try {
                _fieldDeficit = view.createField(
                    FuelPlannerUtils.loadString(Rez.Strings.FitDeficitDataLabel, "Current Deficit"),
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
                    FuelPlannerUtils.loadString(Rez.Strings.FitConsumedDataLabel, "Total Intake"),
                    FIT_FIELD_ID_CONSUMED,
                    FitContributor.DATA_TYPE_FLOAT,
                    { :mesgType => FitContributor.MESG_TYPE_RECORD, :units => FIT_UNIT_GRAMS }
                );
            } catch (e) {
                _fieldConsumed = null;
            }
        }

        if (_fieldTargetSummary == null) {
            try {
                _fieldTargetSummary = view.createField(
                    FuelPlannerUtils.loadString(Rez.Strings.FitTargetCarbsSummaryLabel, "Target Carbs"),
                    FIT_FIELD_ID_TARGET_SUMMARY,
                    FitContributor.DATA_TYPE_FLOAT,
                    { :mesgType => FitContributor.MESG_TYPE_SESSION, :units => FIT_UNIT_GRAMS }
                );
            } catch (e) {
                _fieldTargetSummary = null;
            }
        }

        if (_fieldActualSummary == null) {
            try {
                _fieldActualSummary = view.createField(
                    getActualIntakeSummaryLabel(),
                    FIT_FIELD_ID_ACTUAL_SUMMARY,
                    FitContributor.DATA_TYPE_FLOAT,
                    { :mesgType => FitContributor.MESG_TYPE_SESSION, :units => FIT_UNIT_GRAMS }
                );
            } catch (e) {
                _fieldActualSummary = null;
            }
        }
    }

    private function getActualIntakeSummaryLabel() as String {
        // The same FIT field is used for manual touch logging and the non-touch auto-flow.
        // Keep the label neutral because Connect IQ resource labels are static, while the
        // runtime value can be either a confirmed intake or an estimated/planned intake.
        return FuelPlannerUtils.loadString(Rez.Strings.FitActualIntakeSummaryLabel, "Intake / Estimate");
    }

    public function getSettingsView() as [Views] or [Views, InputDelegates] or Null {
        if (_storage == null) {
            _storage = new StorageManager(null, null);
        }
        var storage = _storage as StorageManager;
        var menu = new FuelPlannerMenu(storage, _model);
        var inputDelegate = new FuelPlannerMenuDelegate(storage, menu, _model);
        return [menu, inputDelegate];
    }

}
