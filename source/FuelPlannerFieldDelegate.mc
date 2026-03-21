import Toybox.Lang;
import Toybox.WatchUi;

(:full)
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
        if (coords == null || coords.size() < 2) {
            return true;
        }

        var x = coords[0];
        var y = coords[1];
        var fieldWidth = _view.getFieldWidth();
        var fieldHeight = _view.getFieldHeight();

        var snoozeBand = fieldHeight / 5;
        var intakeTop = fieldHeight / 6;
        if (intakeTop <= snoozeBand) {
            intakeTop = snoozeBand + 1;
        }
        var intakeBottom = fieldHeight - intakeTop;
        var intakeLeft = fieldWidth / 6;
        var intakeRight = fieldWidth - intakeLeft;

        if (_model.isReminderDue() && y <= snoozeBand) {
            _model.snoozeReminder();
            _reminder.triggerSnooze();
            _view.dismissOverlay();
            WatchUi.requestUpdate();
            return true;
        }

        if (x >= intakeLeft && x <= intakeRight &&
            y >= intakeTop && y <= intakeBottom) {
            _model.recordDefaultIntake();
            _reminder.triggerConfirmation();
            _view.dismissOverlay();
            WatchUi.requestUpdate();
            return true;
        }

        // Undo Zone (unterer 20% - nur wenn Undo verfügbar)
        if (y > intakeBottom && _model.isUndoAvailable()) {
            var success = _model.undoLastIntake();
            if (success) {
                _reminder.triggerUndo();
            }
            WatchUi.requestUpdate();
            return true;
        }

        return true;
    }
}
