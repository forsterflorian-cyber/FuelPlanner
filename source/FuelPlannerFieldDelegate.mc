import Toybox.Lang;
import Toybox.WatchUi;
import Toybox.System;

class FuelPlannerFieldDelegate extends WatchUi.InputDelegate {
    
    private var _model as FuelModel;
    private var _reminder as ReminderManager;
    
    function initialize(model as FuelModel, reminder as ReminderManager) {
        InputDelegate.initialize();
        _model = model;
        _reminder = reminder;
    }
    
    function onTap(clickEvent as WatchUi.ClickEvent) as Boolean {
        if (!_model.isSessionActive()) {
            return true;
        }
        
        var coords = clickEvent.getCoordinates();
        var y = coords[1];
        var screenHeight = System.getDeviceSettings().screenHeight;
        
        // Top 25%: Snooze or small dose
        if (y < screenHeight / 4) {
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
        if (y > screenHeight * 3 / 4) {
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