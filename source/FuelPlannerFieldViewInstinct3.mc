import Toybox.Activity;
import Toybox.Graphics;
import Toybox.System;
import Toybox.WatchUi;
import Toybox.Lang;

(:lite)
class FuelPlannerFieldView extends WatchUi.DataField {

    private var _model as FuelModel;
    private var _reminder as ReminderManager;
    private var _overlayEndTime as Number = 0;
    private var _showRecoveryLayout as Boolean = false;

    private const OVERLAY_DURATION_MS = 3000;
    private const UNIT_G = "g";
    private const SEP_PIPE = " | ";
    private const RECOVERY_MIN_G = 10;

    function initialize(model as FuelModel, reminder as ReminderManager) {
        DataField.initialize();
        _model = model;
        _reminder = reminder;
    }

    function onLayout(dc as Dc) as Void {
    }

    function onTimerLap() as Void {
        _model.onTimerLap();
    }

    function compute(info as Activity.Info) as Void {
        _model.compute(info);
        _showRecoveryLayout = isTimerStateStoppedOrOff(info);

        if (_showRecoveryLayout) {
            _overlayEndTime = 0;
            return;
        }

        if (_model.consumeAutoIntakeEvent()) {
            _reminder.triggerAutoIntake();
        }

        if (_model.isReminderDue() && !_model.isPaused()) {
            if (_reminder.triggerReminder()) {
                _model.recordReminderTriggered();
                _overlayEndTime = System.getTimer() + OVERLAY_DURATION_MS;
            }
        }
    }

    function onUpdate(dc as Dc) as Void {
        var bgColor = getBackgroundColor();
        dc.setColor(Graphics.COLOR_TRANSPARENT, bgColor);
        dc.clear();

        var w = dc.getWidth();
        var h = dc.getHeight();

        if (System.getTimer() < _overlayEndTime) {
            drawOverlay(dc, w, h);
            return;
        }

        if (!_model.isSessionActive()) {
            drawWaiting(dc, w, h, bgColor);
            return;
        }

        if (_showRecoveryLayout) {
            drawRecovery(dc, w, h, bgColor);
            return;
        }

        drawMain(dc, w, h, bgColor);
    }

    private function drawOverlay(dc as Dc, w as Number, h as Number) as Void {
        dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_WHITE);
        dc.fillRectangle(0, 0, w, h);
        dc.setColor(Graphics.COLOR_BLACK, Graphics.COLOR_TRANSPARENT);
        dc.drawText(w / 2, h / 2 - 18, Graphics.FONT_MEDIUM, loadString(Rez.Strings.LabelFuelNow, "FUEL NOW"), Graphics.TEXT_JUSTIFY_CENTER);
        dc.drawText(w / 2, h / 2 + 8, Graphics.FONT_TINY, _model.getDoseG().format("%d") + UNIT_G, Graphics.TEXT_JUSTIFY_CENTER);
    }

    private function drawWaiting(dc as Dc, w as Number, h as Number, bgColor as Number) as Void {
        var textColor = (bgColor == Graphics.COLOR_BLACK) ? Graphics.COLOR_WHITE : Graphics.COLOR_BLACK;
        dc.setColor(textColor, Graphics.COLOR_TRANSPARENT);
        dc.drawText(w / 2, h / 2 - 14, Graphics.FONT_MEDIUM, loadString(Rez.Strings.AppName, "FuelPlanner"), Graphics.TEXT_JUSTIFY_CENTER);
        dc.drawText(w / 2, h / 2 + 10, Graphics.FONT_TINY, loadString(Rez.Strings.LabelWaiting, "Waiting"), Graphics.TEXT_JUSTIFY_CENTER);
    }

    private function drawRecovery(dc as Dc, w as Number, h as Number, bgColor as Number) as Void {
        var textColor = (bgColor == Graphics.COLOR_BLACK) ? Graphics.COLOR_WHITE : Graphics.COLOR_BLACK;
        var recoveryDeficit = _model.getRecoveryDeficit();
        var title = loadString(Rez.Strings.LabelFuelingOk, "Fueling OK");
        var value = "";
        if (recoveryDeficit != null && recoveryDeficit > RECOVERY_MIN_G) {
            title = loadString(Rez.Strings.LabelRecovery, "Recovery");
            value = "+" + recoveryDeficit.format("%d") + UNIT_G;
        }

        dc.setColor(textColor, Graphics.COLOR_TRANSPARENT);
        dc.drawText(w / 2, h / 2 - 18, Graphics.FONT_MEDIUM, title, Graphics.TEXT_JUSTIFY_CENTER);
        if (value != "") {
            dc.drawText(w / 2, h / 2 + 10, Graphics.FONT_MEDIUM, value, Graphics.TEXT_JUSTIFY_CENTER);
        }
    }

    private function drawMain(dc as Dc, w as Number, h as Number, bgColor as Number) as Void {
        var textColor = (bgColor == Graphics.COLOR_BLACK) ? Graphics.COLOR_WHITE : Graphics.COLOR_BLACK;
        var dimColor = (bgColor == Graphics.COLOR_BLACK) ? Graphics.COLOR_LT_GRAY : Graphics.COLOR_DK_GRAY;
        var cx = w / 2;

        var statusText = buildStatusText();
        var consumedG = (_model.getConsumedTotalG10() + 5) / 10;
        var targetG = (_model.getTargetTotalG10() + 5) / 10;
        var deficitText = buildDeficitText();
        var elapsedMin = _model.getElapsedActiveSec() / 60;
        var hrs = elapsedMin / 60;
        var mins = elapsedMin % 60;
        var timeText = (hrs > 0 ? hrs.format("%d") + "h" + mins.format("%02d") : mins.format("%d") + "m") +
            SEP_PIPE + _model.getIntakeCount().format("%d") + "x";

        dc.setColor(textColor, Graphics.COLOR_TRANSPARENT);
        dc.drawText(cx, 8, Graphics.FONT_TINY, statusText, Graphics.TEXT_JUSTIFY_CENTER);
        dc.drawText(cx, h / 2 - 30, Graphics.FONT_MEDIUM, consumedG.format("%d") + "/" + targetG.format("%d"), Graphics.TEXT_JUSTIFY_CENTER);
        dc.drawText(cx, h / 2 + 6, Graphics.FONT_MEDIUM, deficitText, Graphics.TEXT_JUSTIFY_CENTER);
        dc.setColor(dimColor, Graphics.COLOR_TRANSPARENT);
        dc.drawText(cx, h - 22, Graphics.FONT_TINY, timeText, Graphics.TEXT_JUSTIFY_CENTER);

        drawGauge(dc, w, h, bgColor);
    }

    private function drawGauge(dc as Dc, w as Number, h as Number, bgColor as Number) as Void {
        if (h < 100 || w < 100) {
            return;
        }

        var doseG10 = _model.getDoseG10();
        if (doseG10 <= 0) {
            return;
        }

        var gaugeW = 6;
        var gaugeTop = 20;
        var gaugeBottom = h - 28;
        var gaugeH = gaugeBottom - gaugeTop;
        if (gaugeH <= 0) {
            return;
        }

        var deficitG10 = _model.getDeficitG10();
        var ratio = deficitG10.toFloat() / doseG10.toFloat();
        if (ratio < 0.0f) { ratio = 0.0f; }
        if (ratio > 1.0f) { ratio = 1.0f; }
        var fillH = (gaugeH.toFloat() * ratio).toNumber();
        var baseColor = (bgColor == Graphics.COLOR_BLACK) ? Graphics.COLOR_LT_GRAY : Graphics.COLOR_DK_GRAY;
        var alertColor = (bgColor == Graphics.COLOR_BLACK) ? Graphics.COLOR_WHITE : Graphics.COLOR_BLACK;

        dc.setColor(baseColor, Graphics.COLOR_TRANSPARENT);
        dc.fillRectangle(0, gaugeTop, gaugeW, gaugeH);
        dc.fillRectangle(w - gaugeW, gaugeTop, gaugeW, gaugeH);

        if (fillH > 0) {
            dc.setColor(alertColor, Graphics.COLOR_TRANSPARENT);
            dc.fillRectangle(0, gaugeBottom - fillH, gaugeW, fillH);
            dc.fillRectangle(w - gaugeW, gaugeBottom - fillH, gaugeW, fillH);
        }
    }

    private function buildStatusText() as String {
        if (_model.isPaused()) {
            return loadString(Rez.Strings.LabelPaused, "PAUSED");
        }
        if (_model.isReminderDue()) {
            return loadString(Rez.Strings.LabelFuelNow, "FUEL NOW");
        }
        return loadString(Rez.Strings.LabelNext, "Next") + " " + formatDuration(_model.getDisplayNextDueInSec());
    }

    private function buildDeficitText() as String {
        var deficitG10 = _model.getDeficitG10();
        if (deficitG10 > 5) {
            return loadString(Rez.Strings.LabelBehind, "Behind") + " " + ((deficitG10 + 5) / 10).format("%d") + UNIT_G;
        }
        if (deficitG10 < -5) {
            return loadString(Rez.Strings.LabelAhead, "Ahead") + " " + (((-deficitG10) + 5) / 10).format("%d") + UNIT_G;
        }
        return loadString(Rez.Strings.LabelOnTarget, "On target");
    }

    private function loadString(resourceId as Lang.ResourceId?, fallback as String) as String {
        if (resourceId == null) {
            return fallback;
        }
        try {
            var value = WatchUi.loadResource(resourceId);
            if (value instanceof String) {
                return value as String;
            }
        } catch (e) {}
        return fallback;
    }

    private function isTimerStateStoppedOrOff(info as Activity.Info) as Boolean {
        try {
            if (!(info has :timerState)) {
                return false;
            }
            if (Activity has :TIMER_STATE_STOPPED && info.timerState == Activity.TIMER_STATE_STOPPED) {
                return true;
            }
            if (Activity has :TIMER_STATE_OFF && info.timerState == Activity.TIMER_STATE_OFF) {
                return true;
            }
        } catch (e) {}
        return false;
    }

    private function formatDuration(seconds as Number) as String {
        if (seconds < 0) { seconds = 0; }
        return (seconds / 60).format("%d") + ":" + (seconds % 60).format("%02d");
    }
}
