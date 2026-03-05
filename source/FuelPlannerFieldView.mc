import Toybox.Activity;
import Toybox.Graphics;
import Toybox.Lang;
import Toybox.WatchUi;
import Toybox.System;

//! Data Field View for FuelPlanner — fully responsive layout
class FuelPlannerFieldView extends WatchUi.DataField {

    private var _model as FuelModel;
    private var _reminder as ReminderManager;

    // Colors
    private const COLOR_NORMAL  = Graphics.COLOR_WHITE;
    private const COLOR_WARNING = Graphics.COLOR_YELLOW;
    private const COLOR_ALERT   = Graphics.COLOR_RED;
    private const COLOR_GOOD    = Graphics.COLOR_GREEN;
    private const COLOR_DIM     = Graphics.COLOR_LT_GRAY;

    // Blink state for "FUEL NOW" indicator
    private var _blinkState    as Boolean = false;
    private var _lastBlinkTime as Number  = 0;
    private const BLINK_INTERVAL = 500;

    function initialize(model as FuelModel, reminder as ReminderManager) {
        DataField.initialize();
        _model    = model;
        _reminder = reminder;
    }

    function onLayout(dc as Dc) as Void {
    }

    //! Called every second with activity info
    function compute(info as Activity.Info) as Void {
        _model.compute(info);

        if (_model.isReminderDue() && !_model.isPaused()) {
            if (_reminder.triggerReminder()) {
                _model.recordReminderTriggered();
            }
        }

        var now = System.getTimer();
        if (now - _lastBlinkTime >= BLINK_INTERVAL) {
            _blinkState    = !_blinkState;
            _lastBlinkTime = now;
        }
    }

    function onUpdate(dc as Dc) as Void {
        var bgColor = getBackgroundColor();
        dc.setColor(Graphics.COLOR_TRANSPARENT, bgColor);
        dc.clear();

        var w  = dc.getWidth();
        var h  = dc.getHeight();
        var cx = w / 2;

        var isDark    = (bgColor == Graphics.COLOR_BLACK);
        var textColor = isDark ? COLOR_NORMAL       : Graphics.COLOR_BLACK;
        var dimColor  = isDark ? COLOR_DIM          : Graphics.COLOR_DK_GRAY;

        if (!_model.isSessionActive()) {
            drawNoSession(dc, cx, h, textColor, dimColor);
            return;
        }

        drawMainLayout(dc, w, h, cx, textColor, dimColor);
    }

    //! Waiting screen before activity starts
    private function drawNoSession(dc as Dc, cx as Number, h as Number,
                                   textColor as Number, dimColor as Number) as Void {
        dc.setColor(textColor, Graphics.COLOR_TRANSPARENT);
        dc.drawText(cx, h / 2 - h / 13, Graphics.FONT_MEDIUM,
                    WatchUi.loadResource(Rez.Strings.AppName) as String,
                    Graphics.TEXT_JUSTIFY_CENTER);
        dc.setColor(dimColor, Graphics.COLOR_TRANSPARENT);
        dc.drawText(cx, h / 2 + h / 20, Graphics.FONT_TINY,
                    WatchUi.loadResource(Rez.Strings.LabelWaiting) as String,
                    Graphics.TEXT_JUSTIFY_CENTER);
    }

    //! Main layout — all positions relative to field height/width
    private function drawMainLayout(dc as Dc, w as Number, h as Number,
                                    cx as Number, textColor as Number,
                                    dimColor as Number) as Void {

        var isReminderDue = _model.isReminderDue();
        var nextDueSec    = _model.getNextDueInSec();
        var isPaused      = _model.isPaused();

        // --- Choose font sizes based on available height ---
        // Small field (quadrant / half-screen): h < 130
        // Medium field: 130-180
        // Full screen: > 180
        var fontStatus = Graphics.FONT_MEDIUM;
        var fontUnit   = Graphics.FONT_SMALL;
        var fontLabel  = Graphics.FONT_XTINY;
        var fontMeta   = Graphics.FONT_TINY;
        var fontHint   = Graphics.FONT_XTINY;

        if (h < 130) {
            fontStatus = Graphics.FONT_SMALL;
            fontUnit   = Graphics.FONT_XTINY;
            fontLabel  = Graphics.FONT_XTINY;
            fontMeta   = Graphics.FONT_XTINY;
            fontHint   = Graphics.FONT_XTINY;
        } else if (h < 180) {
            fontStatus = Graphics.FONT_SMALL;
            fontUnit   = Graphics.FONT_TINY;
            fontLabel  = Graphics.FONT_XTINY;
            fontMeta   = Graphics.FONT_XTINY;
            fontHint   = Graphics.FONT_XTINY;
        }

        // Row positions as fractions of height.
        // y1 at 9% (not 5%) keeps status text clear of the circular bezel on round watches —
        // at 5% the usable chord width is ~120px; at 9% it opens to ~160px.
        var y1 = (h * 0.09).toNumber();   // status row
        var y2 = (h * 0.24).toNumber();   // big number row
        var y3 = (h * 0.57).toNumber();   // target rate label
        var y4 = (h * 0.66).toNumber();   // deficit/ahead
        var y5 = (h * 0.79).toNumber();   // time | intakes
        var y6 = (h * 0.88).toNumber();   // tap hint

        // Shrink layout for small fields — skip bottom rows
        var showHint  = (h >= 130);
        var showMeta  = (h >= 100);
        var showLabel = (h >= 80);

        // ── ROW 1: Status ──────────────────────────────────
        var statusText;
        var statusColor;

        if (isPaused) {
            statusText  = WatchUi.loadResource(Rez.Strings.LabelPaused) as String;
            statusColor = COLOR_WARNING;
        } else if (isReminderDue || nextDueSec <= 0) {
            statusText  = _blinkState
                ? WatchUi.loadResource(Rez.Strings.LabelFuelNow) as String
                : (WatchUi.loadResource(Rez.Strings.LabelTapPrefix) as String) + _model.getDoseG() + "g";
            statusColor = COLOR_ALERT;
        } else {
            statusText  = (WatchUi.loadResource(Rez.Strings.LabelNext) as String) + " " + formatDuration(nextDueSec);
            if (nextDueSec < 60) {
                statusColor = COLOR_ALERT;
            } else if (nextDueSec < 180) {
                statusColor = COLOR_WARNING;
            } else {
                statusColor = COLOR_GOOD;
            }
        }

        dc.setColor(statusColor, Graphics.COLOR_TRANSPARENT);
        dc.drawText(cx, y1, fontStatus, statusText, Graphics.TEXT_JUSTIFY_CENTER);

        // ── ROW 2: consumed/target + "g" unit ─────────────
        // FONT_NUMBER_MILD only contains digits/punctuation — draw "g" separately
        var consumed = _model.getConsumedTotalG();
        var target   = _model.getTargetTotalG().toNumber();
        var numStr   = consumed.format("%d") + "/" + target.format("%d");

        var numDims  = dc.getTextDimensions(numStr, Graphics.FONT_NUMBER_MILD);
        var unitDims = dc.getTextDimensions("g",    fontUnit);

        // Centre the number + unit together
        var totalW   = numDims[0] + unitDims[0];
        var numX     = cx - totalW / 2;
        // Align "g" to the baseline of the number font
        var unitY    = y2 + numDims[1] - unitDims[1];

        dc.setColor(textColor, Graphics.COLOR_TRANSPARENT);
        dc.drawText(numX,          y2,    Graphics.FONT_NUMBER_MILD, numStr, Graphics.TEXT_JUSTIFY_LEFT);
        dc.drawText(numX + numDims[0], unitY, fontUnit,              "g",    Graphics.TEXT_JUSTIFY_LEFT);

        // ── ROW 3: target rate ─────────────────────────────
        if (showLabel) {
            dc.setColor(dimColor, Graphics.COLOR_TRANSPARENT);
            dc.drawText(cx, y3, fontLabel,
                        buildRateLabel(),
                        Graphics.TEXT_JUSTIFY_CENTER);
        }

        // ── ROW 4: Deficit / Ahead ─────────────────────────
        var deficit = _model.getDeficitG();
        var deficitText;
        var deficitColor;

        if (deficit > 0.5f) {
            deficitText  = (WatchUi.loadResource(Rez.Strings.LabelBehind) as String) + " " + deficit.toNumber().format("%d") + "g";
            deficitColor = (deficit > _model.getDoseG().toFloat()) ? COLOR_ALERT : COLOR_WARNING;
        } else if (deficit < -0.5f) {
            deficitText  = (WatchUi.loadResource(Rez.Strings.LabelAhead) as String) + " " + (-deficit).toNumber().format("%d") + "g";
            deficitColor = COLOR_GOOD;
        } else {
            deficitText  = WatchUi.loadResource(Rez.Strings.LabelOnTarget) as String;
            deficitColor = COLOR_GOOD;
        }

        dc.setColor(deficitColor, Graphics.COLOR_TRANSPARENT);
        dc.drawText(cx, y4, fontUnit, deficitText, Graphics.TEXT_JUSTIFY_CENTER);

        // ── ROW 5: elapsed time | intake count ────────────
        if (showMeta) {
            var elapsedMin  = _model.getElapsedActiveSec() / 60;
            var hrs         = elapsedMin / 60;
            var mins        = elapsedMin % 60;
            var timeText    = (hrs > 0)
                ? hrs.format("%d") + "h" + mins.format("%02d")
                : mins.format("%d") + "m";
            var intakeCount = _model.getIntakeCount();

            dc.setColor(dimColor, Graphics.COLOR_TRANSPARENT);
            dc.drawText(cx, y5, fontMeta,
                        timeText + " | " + intakeCount.format("%d") + "x",
                        Graphics.TEXT_JUSTIFY_CENTER);
        }

        // ── ROW 6: tap hint — shows all three zones ────────
        // Top 25%: half dose (or snooze)  |  Middle: default  |  Bottom 25%: double
        if (showHint) {
            var dose   = _model.getDoseG();
            var half   = dose / 2;
            if (half < 5) { half = 5; }
            dc.setColor(dimColor, Graphics.COLOR_TRANSPARENT);
            dc.drawText(cx, y6, fontHint,
                        half.format("%d") + "g / " + dose.format("%d") + "g / " + (dose * 2).format("%d") + "g",
                        Graphics.TEXT_JUSTIFY_CENTER);
        }
    }

    //! Build localized rate label from model state
    private function buildRateLabel() as String {
        var mode = _model.getReminderMode();
        if (mode == 2) {  // MODE_CALORIE_AUTO
            if (_model.isCaloriesAvailable()) {
                return "auto " + _model.getCarbFractionPct().format("%d") +
                       (WatchUi.loadResource(Rez.Strings.LabelRateAutoCarbsSuffix) as String);
            }
            return WatchUi.loadResource(Rez.Strings.LabelRateAutoNoData) as String;
        }
        return (WatchUi.loadResource(Rez.Strings.LabelRateTargetPrefix) as String) + " " +
               _model.getCarbsTargetGph().format("%d") + " g/h";
    }

    //! Format seconds as m:ss or Xh:mm
    private function formatDuration(seconds as Number) as String {
        if (seconds < 0) { seconds = 0; }
        if (seconds > 5999) {
            return (seconds / 3600).format("%d") + "h" +
                   ((seconds % 3600) / 60).format("%02d");
        }
        return (seconds / 60).format("%d") + ":" + (seconds % 60).format("%02d");
    }
}
