import Toybox.Activity;
import Toybox.Graphics;
import Toybox.Lang;
import Toybox.Math;
import Toybox.WatchUi;
import Toybox.System;

//! Data Field View for FuelPlanner - responsive, top-to-bottom layout
class FuelPlannerFieldView extends WatchUi.DataField {

    private var _model as FuelModel;
    private var _reminder as ReminderManager;

    // Colors
    private const COLOR_NORMAL  = Graphics.COLOR_WHITE;
    private const COLOR_WARNING = Graphics.COLOR_YELLOW;
    private const COLOR_ALERT   = Graphics.COLOR_RED;
    private const COLOR_GOOD    = Graphics.COLOR_GREEN;
    private const COLOR_DIM     = Graphics.COLOR_LT_GRAY;

    // Vertical flow layout constants (relative to field size)
    private const SAFE_TOP_RATIO = 0.08f;
    private const SAFE_TOP_MIN_PX = 12;
    private const SAFE_TOP_MAX_PX = 36;

    private const SAFE_BOTTOM_TOUCH_RATIO = 0.08f;
    private const SAFE_BOTTOM_BUTTON_RATIO = 0.12f;
    private const SAFE_BOTTOM_SQUARE_BONUS_RATIO = 0.015f;
    private const SAFE_BOTTOM_MIN_PX = 14;
    private const SAFE_BOTTOM_MAX_PX = 48;

    private const ROW_GAP_RATIO = 0.028f;
    private const ROW_GAP_MIN_PX = 4;
    private const ROW_GAP_MAX_PX = 16;

    private const UNIT_GAP_RATIO = 0.01f;
    private const UNIT_GAP_MIN_PX = 1;
    private const UNIT_GAP_MAX_PX = 5;
    private const UNIT_NUDGE_UP_RATIO = 0.006f;
    private const UNIT_NUDGE_UP_MIN_PX = 1;
    private const UNIT_NUDGE_UP_MAX_PX = 3;

    private const ROUND_EDGE_PAD_RATIO = 0.03f;
    private const ROUND_EDGE_PAD_MIN_PX = 6;
    private const ROUND_EDGE_PAD_MAX_PX = 14;

    // Blink state for "FUEL NOW" indicator
    private var _blinkState    as Boolean = false;
    private var _lastBlinkTime as Number  = 0;
    private const BLINK_INTERVAL = 500;

    // Last known field height (for tap zone mapping in multi-field layouts)
    private var _lastFieldHeight as Number = 0;
    private const DEFAULT_SCREEN_HEIGHT = 240;

    function getFieldHeight() as Number {
        if (_lastFieldHeight > 0) {
            return _lastFieldHeight;
        }
        return getScreenHeight();
    }

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
        _lastFieldHeight = h;
        var cx = w / 2;

        var isDark    = (bgColor == Graphics.COLOR_BLACK);
        var textColor = isDark ? COLOR_NORMAL : Graphics.COLOR_BLACK;
        var dimColor  = isDark ? COLOR_DIM    : Graphics.COLOR_DK_GRAY;

        var touchEnabled = isTouchEnabled();

        if (!_model.isSessionActive()) {
            drawNoSession(dc, cx, h, textColor, dimColor);
            return;
        }

        drawMainLayout(dc, w, h, cx, textColor, dimColor, touchEnabled);
    }

    private function isTouchEnabled() as Boolean {
        try {
            var settings = System.getDeviceSettings();
            if (settings != null && settings has :isTouchScreen) {
                return settings.isTouchScreen;
            }
        } catch (e) {}
        return false;
    }

    private function getScreenHeight() as Number {
        try {
            var settings = System.getDeviceSettings();
            if (settings != null && settings has :screenHeight && settings.screenHeight instanceof Number) {
                return settings.screenHeight;
            }
        } catch (e) {}
        return DEFAULT_SCREEN_HEIGHT;
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

    //! Main layout rendered as a vertical flow from top to bottom.
    private function drawMainLayout(dc as Dc, w as Number, h as Number,
                                    cx as Number, textColor as Number,
                                    dimColor as Number, touchEnabled as Boolean) as Void {
        var isReminderDue = _model.isReminderDue();
        var nextDueSec    = _model.getNextDueInSec();
        var isPaused      = _model.isPaused();

        // Choose font sizes based on field height
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

        var showHint  = (h >= 115);
        var showMeta  = (h >= 115);
        var showLabel = (h >= 80);

        // Row 1: status
        var statusText;
        var statusColor;
        if (isPaused) {
            statusText  = WatchUi.loadResource(Rez.Strings.LabelPaused) as String;
            statusColor = COLOR_WARNING;
        } else if (isReminderDue || nextDueSec <= 0) {
            var actionPrefix = touchEnabled
                ? (WatchUi.loadResource(Rez.Strings.LabelTapPrefix) as String)
                : (WatchUi.loadResource(Rez.Strings.LabelHoldPrefix) as String);
            statusText  = _blinkState
                ? WatchUi.loadResource(Rez.Strings.LabelFuelNow) as String
                : actionPrefix + _model.getDoseG() + "g";
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

        // Row 2: consumed / target number
        var consumed = _model.getConsumedTotalG();
        var target   = _model.getTargetTotalG().toNumber();
        var numStr   = consumed.format("%d") + "/" + target.format("%d");
        var numDims  = dc.getTextDimensions(numStr, Graphics.FONT_NUMBER_MILD);
        var unitDims = dc.getTextDimensions("g", fontUnit);
        var unitGap  = getUnitGap(w);
        var totalW   = numDims[0] + unitGap + unitDims[0];
        var numX     = cx - totalW / 2;

        // Row 3: target rate label
        var rateLabel = buildRateLabel();

        // Row 4: deficit/ahead
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

        // Row 5: elapsed time and count
        var timeText = "";
        if (showMeta) {
            var elapsedMin  = _model.getElapsedActiveSec() / 60;
            var hrs         = elapsedMin / 60;
            var mins        = elapsedMin % 60;
            timeText = (hrs > 0)
                ? hrs.format("%d") + "h" + mins.format("%02d")
                : mins.format("%d") + "m";
            var intakeCount = _model.getIntakeCount();
            timeText += " | " + intakeCount.format("%d") + "x";
        }

        // Row 6: interaction hint
        var hintText = "";
        if (showHint) {
            if (touchEnabled) {
                var dose = _model.getDoseG();
                var half = dose / 2;
                if (half < 5) { half = 5; }
                hintText = half.format("%d") + "g / " + dose.format("%d") + "g / " + (dose * 2).format("%d") + "g";
            } else {
                var lapHint = (w <= 300 || h <= 300)
                    ? (WatchUi.loadResource(Rez.Strings.LabelLapUndoShort) as String)
                    : (WatchUi.loadResource(Rez.Strings.LabelLapUndoHint) as String);
                hintText = (WatchUi.loadResource(Rez.Strings.LabelHoldPrefix) as String) +
                           _model.getDoseG() + "g | " + lapHint;
            }
        }

        // Pre-measure row heights for flow layout and overflow handling.
        var statusH  = dc.getTextDimensions(statusText, fontStatus)[1];
        var numberH  = numDims[1];
        if (unitDims[1] > numberH) { numberH = unitDims[1]; }
        var labelH   = dc.getTextDimensions(rateLabel, fontLabel)[1];
        var deficitH = dc.getTextDimensions(deficitText, fontUnit)[1];
        var metaH    = showMeta ? dc.getTextDimensions(timeText, fontMeta)[1] : 0;
        var hintH    = showHint ? dc.getTextDimensions(hintText, fontHint)[1] : 0;

        var gap = getRowGap(h);
        var safeTop = getSafeTopInset(h);
        var safeBottom = getSafeBottomInset(w, h, touchEnabled);
        if (showHint && w == h) {
            var hintWidth = dc.getTextDimensions(hintText, fontHint)[0];
            var roundHintSafeBottom = getRoundHintBottomInset(w, h, hintWidth, hintH);
            if (roundHintSafeBottom > safeBottom) {
                safeBottom = roundHintSafeBottom;
            }
        }
        var availableHeight = h - safeTop - safeBottom;
        if (availableHeight < 0) { availableHeight = 0; }

        // If it does not fit, progressively hide optional rows from bottom.
        var drawLabel = showLabel;
        var drawMeta  = showMeta;
        var drawHint  = showHint;
        var flowGap   = gap;
        while (true) {
            var requiredHeight = getRequiredMainHeight(statusH, numberH, labelH,
                                                       deficitH, metaH, hintH,
                                                       drawLabel, drawMeta, drawHint, flowGap);
            if (requiredHeight <= availableHeight) { break; }
            if (drawMeta) {
                drawMeta = false;
                continue;
            }
            if (drawLabel) {
                drawLabel = false;
                continue;
            }
            if (flowGap > ROW_GAP_MIN_PX) {
                flowGap -= 1;
                continue;
            }
            if (drawHint) {
                drawHint = false;
                continue;
            }
            break;
        }

        // Draw from top to bottom with explicit offsets.
        var y = safeTop;

        dc.setColor(statusColor, Graphics.COLOR_TRANSPARENT);
        dc.drawText(cx, y, fontStatus, statusText, Graphics.TEXT_JUSTIFY_CENTER);
        y += statusH + flowGap;

        // Vertically center the "g" unit against the number row.
        var unitNudge = getUnitVerticalNudge(h);
        var unitY = y + (numberH - unitDims[1]) / 2 - unitNudge;
        dc.setColor(textColor, Graphics.COLOR_TRANSPARENT);
        dc.drawText(numX, y, Graphics.FONT_NUMBER_MILD, numStr, Graphics.TEXT_JUSTIFY_LEFT);
        dc.drawText(numX + numDims[0] + unitGap, unitY, fontUnit, "g", Graphics.TEXT_JUSTIFY_LEFT);
        y += numberH + flowGap;

        if (drawLabel) {
            dc.setColor(dimColor, Graphics.COLOR_TRANSPARENT);
            dc.drawText(cx, y, fontLabel, rateLabel, Graphics.TEXT_JUSTIFY_CENTER);
            y += labelH + flowGap;
        }

        dc.setColor(deficitColor, Graphics.COLOR_TRANSPARENT);
        dc.drawText(cx, y, fontUnit, deficitText, Graphics.TEXT_JUSTIFY_CENTER);
        y += deficitH + flowGap;

        if (drawMeta) {
            dc.setColor(dimColor, Graphics.COLOR_TRANSPARENT);
            dc.drawText(cx, y, fontMeta, timeText, Graphics.TEXT_JUSTIFY_CENTER);
            y += metaH + flowGap;
        }

        if (drawHint) {
            dc.setColor(dimColor, Graphics.COLOR_TRANSPARENT);
            dc.drawText(cx, y, fontHint, hintText, Graphics.TEXT_JUSTIFY_CENTER);
        }
    }

    private function getSafeTopInset(h as Number) as Number {
        var inset = (h * SAFE_TOP_RATIO).toNumber();
        if (inset < SAFE_TOP_MIN_PX) {
            inset = SAFE_TOP_MIN_PX;
        } else if (inset > SAFE_TOP_MAX_PX) {
            inset = SAFE_TOP_MAX_PX;
        }
        return inset;
    }

    private function getSafeBottomInset(w as Number, h as Number, touchEnabled as Boolean) as Number {
        var ratio = touchEnabled ? SAFE_BOTTOM_TOUCH_RATIO : SAFE_BOTTOM_BUTTON_RATIO;
        if (w == h) {
            ratio += SAFE_BOTTOM_SQUARE_BONUS_RATIO;
        }

        var inset = (h * ratio).toNumber();
        if (inset < SAFE_BOTTOM_MIN_PX) {
            inset = SAFE_BOTTOM_MIN_PX;
        } else if (inset > SAFE_BOTTOM_MAX_PX) {
            inset = SAFE_BOTTOM_MAX_PX;
        }
        return inset;
    }

    private function getRowGap(h as Number) as Number {
        var gap = (h * ROW_GAP_RATIO).toNumber();
        if (gap < ROW_GAP_MIN_PX) {
            gap = ROW_GAP_MIN_PX;
        } else if (gap > ROW_GAP_MAX_PX) {
            gap = ROW_GAP_MAX_PX;
        }
        return gap;
    }

    private function getUnitGap(w as Number) as Number {
        var gap = (w * UNIT_GAP_RATIO).toNumber();
        if (gap < UNIT_GAP_MIN_PX) {
            gap = UNIT_GAP_MIN_PX;
        } else if (gap > UNIT_GAP_MAX_PX) {
            gap = UNIT_GAP_MAX_PX;
        }
        return gap;
    }

    private function getUnitVerticalNudge(h as Number) as Number {
        var nudge = (h * UNIT_NUDGE_UP_RATIO).toNumber();
        if (nudge < UNIT_NUDGE_UP_MIN_PX) {
            nudge = UNIT_NUDGE_UP_MIN_PX;
        } else if (nudge > UNIT_NUDGE_UP_MAX_PX) {
            nudge = UNIT_NUDGE_UP_MAX_PX;
        }
        return nudge;
    }

    private function getRoundEdgePadding(w as Number) as Number {
        var pad = (w * ROUND_EDGE_PAD_RATIO).toNumber();
        if (pad < ROUND_EDGE_PAD_MIN_PX) {
            pad = ROUND_EDGE_PAD_MIN_PX;
        } else if (pad > ROUND_EDGE_PAD_MAX_PX) {
            pad = ROUND_EDGE_PAD_MAX_PX;
        }
        return pad;
    }

    //! Additional bottom inset needed on round screens so hint text
    //! remains in the wider part of the circle and avoids side clipping.
    private function getRoundHintBottomInset(w as Number, h as Number,
                                             textWidth as Number, textHeight as Number) as Number {
        if (w != h) { return 0; }

        var radius = (w.toFloat() / 2.0f);
        var halfText = (textWidth.toFloat() / 2.0f) + getRoundEdgePadding(w).toFloat();
        if (halfText >= radius) {
            return SAFE_BOTTOM_MAX_PX;
        }

        var dMax = Math.sqrt((radius * radius) - (halfText * halfText));
        var maxCenterY = radius + dMax;
        var inset = h.toFloat() - maxCenterY - (textHeight.toFloat() / 2.0f);

        var insetPx = inset.toNumber();
        if (insetPx < 0) {
            insetPx = 0;
        } else if (insetPx > SAFE_BOTTOM_MAX_PX) {
            insetPx = SAFE_BOTTOM_MAX_PX;
        }
        return insetPx;
    }

    private function getRequiredMainHeight(statusH as Number, numberH as Number,
                                           labelH as Number, deficitH as Number,
                                           metaH as Number, hintH as Number,
                                           showLabel as Boolean, showMeta as Boolean,
                                           showHint as Boolean, gap as Number) as Number {
        var required = statusH + numberH + deficitH;
        var rows = 3;

        if (showLabel) {
            required += labelH;
            rows += 1;
        }
        if (showMeta) {
            required += metaH;
            rows += 1;
        }
        if (showHint) {
            required += hintH;
            rows += 1;
        }

        required += (rows - 1) * gap;
        return required;
    }

    //! Build localized rate label from model state
    private function buildRateLabel() as String {
        if (_model.isCalorieModeActive()) {
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
