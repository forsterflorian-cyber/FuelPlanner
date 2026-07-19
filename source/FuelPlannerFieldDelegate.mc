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
        var coords = clickEvent.getCoordinates();
        if (coords == null || coords.size() < 2) {
            return true;
        }

        return routeTap(coords[0], coords[1]);
    }

    //! Route already-extracted coordinates. Keeping event decoding separate
    //! makes the three field actions deterministic and directly testable.
    function routeTap(x as Number, y as Number) as Boolean {
        if (!_model.isSessionActive() || !_model.isTouchInputEnabled()) {
            return true;
        }

        var fieldWidth = _view.getFieldWidth();
        var fieldHeight = _view.getFieldHeight();
        if (fieldWidth <= 0 || fieldHeight <= 0 ||
            x < 0 || x >= fieldWidth || y < 0 || y >= fieldHeight) {
            return true;
        }

        var reminderActionVisible = _model.isReminderDue() ||
                                    _view.isReminderOverlayActive();
        var snoozeBand = _view.getSnoozeTapBottom();

        if (reminderActionVisible) {
            if (y <= snoozeBand) {
                _model.snoozeReminder();
                _reminder.triggerSnooze();
            } else {
                _model.recordDefaultIntake();
                _reminder.triggerConfirmation();
            }
            _view.dismissOverlay();
            WatchUi.requestUpdate();
            return true;
        }

        var intakeTop = fieldHeight / 6;
        var intakeBottom = fieldHeight - intakeTop;
        var intakeLeft = fieldWidth / 6;
        var intakeRight = fieldWidth - intakeLeft;

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
