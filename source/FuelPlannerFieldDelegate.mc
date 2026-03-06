import Toybox.Lang;
import Toybox.WatchUi;

class FuelPlannerFieldDelegate extends WatchUi.InputDelegate {
    
    private var _model as FuelModel;
    private var _reminder as ReminderManager;
    private var _view as FuelPlannerFieldView;
    
    function initialize(model as FuelModel, reminder as ReminderManager, view as FuelPlannerFieldView) {
        InputDelegate.initialize();
        _model = model;
        _reminder = reminder;
        _view = view;
    }
    
    function onTap(clickEvent as WatchUi.ClickEvent) as Boolean {
        if (!_model.isSessionActive()) {
            return true;
        }
        
        var coords = clickEvent.getCoordinates();
        var y = coords[1];
        var fieldHeight = _view.getFieldHeight();
        
        // Top 25%: Snooze or small dose
        if (y < fieldHeight / 4) {
            if (_model.isReminderDue()) {
                _model.snoozeReminder();
                _reminder.triggerSnooze();
            } else {
                var halfDose = _model.getDoseG() / 2;
                if (halfDose < 5) { halfDose = 5; }
                _model.recordIntake(halfDose);
                _reminder.triggerConfirmation();
            }
            WatchUi.requestUpdate();
            return true;
        }
        
        // Bottom 25%: Double dose
        if (y > fieldHeight * 3 / 4) {
            var doubleDose = _model.getDoseG() * 2;
            _model.recordIntake(doubleDose);
            _reminder.triggerConfirmation();
            WatchUi.requestUpdate();
            return true;
        }
        
        // Middle 50%: Default dose
        _model.recordDefaultIntake();
        _reminder.triggerConfirmation();
        WatchUi.requestUpdate();
        return true;
    }
}
