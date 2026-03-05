import Toybox.Lang;
import Toybox.WatchUi;
import Toybox.System;

class FuelPlannerFieldDelegate extends WatchUi.InputDelegate {
    
    private var _model as FuelModel;
    private var _reminder as ReminderManager;
    private var _view as FuelPlannerFieldView;
    private var _downPressedAt as Number? = null;
    private var _downHandled as Boolean = false;
    private var _lapPressedAt as Number? = null;
    private var _lapHandled as Boolean = false;
    private const DOWN_HOLD_MS = 700;
    private const LAP_HOLD_UNDO_MS = 1000;
    
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

    function onKeyPressed(keyEvent as WatchUi.KeyEvent) as Boolean {
        if (!_model.isSessionActive()) {
            return false;
        }

        var key = keyEvent.getKey();
        if (key == WatchUi.KEY_DOWN) {
            _downPressedAt = System.getTimer();
            _downHandled = false;
            return false;
        }

        if (key == WatchUi.KEY_LAP) {
            _lapPressedAt = System.getTimer();
            _lapHandled = false;
            return false;
        }

        return false;
    }

    function onKeyReleased(keyEvent as WatchUi.KeyEvent) as Boolean {
        if (!_model.isSessionActive()) {
            return false;
        }

        var key = keyEvent.getKey();
        if (key == WatchUi.KEY_DOWN) {
            if (_downHandled) {
                _downPressedAt = null;
                _downHandled = false;
                return true;
            }

            if (_downPressedAt == null) {
                return false;
            }

            var downHoldMs = System.getTimer() - _downPressedAt;
            _downPressedAt = null;

            if (downHoldMs < DOWN_HOLD_MS) {
                return false;
            }

            _downHandled = true;
            return handleDownHold();
        }

        if (key == WatchUi.KEY_LAP) {
            if (_lapHandled) {
                _lapPressedAt = null;
                _lapHandled = false;
                return true;
            }

            if (_lapPressedAt == null) {
                return false;
            }

            var lapHoldMs = System.getTimer() - _lapPressedAt;
            _lapPressedAt = null;

            if (lapHoldMs < LAP_HOLD_UNDO_MS) {
                return false;
            }

            _lapHandled = true;
            return handleLapHold();
        }

        if (key != WatchUi.KEY_DOWN && key != WatchUi.KEY_LAP) {
            return false;
        }
        return false;
    }

    function onKey(keyEvent as WatchUi.KeyEvent) as Boolean {
        if (!_model.isSessionActive()) {
            return false;
        }

        var key = keyEvent.getKey();
        if (key == WatchUi.KEY_DOWN) {
            if (_downHandled) {
                return true;
            }

            if (_downPressedAt == null) {
                return false;
            }

            var downHoldMs = System.getTimer() - _downPressedAt;
            if (downHoldMs < DOWN_HOLD_MS) {
                return false;
            }

            _downPressedAt = null;
            _downHandled = true;
            return handleDownHold();
        }

        if (key == WatchUi.KEY_LAP) {
            if (_lapHandled) {
                return true;
            }

            if (_lapPressedAt == null) {
                return false;
            }

            var lapHoldMs = System.getTimer() - _lapPressedAt;
            if (lapHoldMs < LAP_HOLD_UNDO_MS) {
                return false;
            }

            _lapPressedAt = null;
            _lapHandled = true;
            return handleLapHold();
        }

        return false;
    }

    private function handleDownHold() as Boolean {
        _model.recordDefaultIntake();
        _reminder.triggerConfirmation();
        WatchUi.requestUpdate();
        return true;
    }

    private function handleLapHold() as Boolean {
        if (_model.undoLastIntake()) {
            _reminder.triggerConfirmation();
            WatchUi.requestUpdate();
        } else {
            // Distinct feedback when there is nothing left to undo.
            _reminder.triggerSnooze();
        }
        return true;
    }
}
