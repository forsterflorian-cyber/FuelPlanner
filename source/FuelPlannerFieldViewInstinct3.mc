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
    private const CONTENT_SIDE_RATIO = 0.08f;
    private const CONTENT_TOP_RATIO = 0.09f;
    private const CONTENT_GAP_RATIO = 0.025f;
    private const CONTENT_MIN_SIDE_PX = 10;
    private const CONTENT_MIN_TOP_PX = 10;
    private const CONTENT_MIN_BOTTOM_PX = 14;
    private const STATUS_ROW_RATIO = 0.13f;
    private const PRIMARY_ROW_RATIO = 0.26f;
    private const DEFICIT_ROW_RATIO = 0.12f;
    private const META_ROW_RATIO = 0.10f;
    private const RATE_ROW_RATIO = 0.09f;
    private const RING_STROKE_RATIO = 0.045f;
    private const RING_STROKE_MIN_PX = 7;
    private const RING_STROKE_MAX_PX = 16;
    private const RING_PADDING_MIN_PX = 4;
    private const RING_PADDING_MAX_PX = 10;

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

        if (_showRecoveryLayout) {
            drawRecovery(dc, w, h, bgColor);
            return;
        }

        if (!_model.isSessionActive()) {
            drawWaiting(dc, w, h, bgColor);
            return;
        }

        drawMain(dc, w, h, bgColor);
    }

    private function drawOverlay(dc as Dc, w as Number, h as Number) as Void {
        dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_WHITE);
        dc.fillRectangle(0, 0, w, h);
        dc.setColor(Graphics.COLOR_BLACK, Graphics.COLOR_TRANSPARENT);
        var contentW = w - (getContentSideInset(w) * 2);
        var titleText = loadString(Rez.Strings.LabelFuelNow, "FUEL NOW");
        var doseText = _model.getDoseG().format("%d") + UNIT_G;
        var titleFont = getBestFontForBox(dc, titleText, contentW, getScaledValue(h, 0.18f, 18, 44), false);
        var doseFont = getBestFontForBox(dc, doseText, contentW, getScaledValue(h, 0.12f, 14, 30), true);
        var gap = getRowGap(h);
        var titleH = dc.getTextDimensions(titleText, titleFont)[1];
        var doseH = dc.getTextDimensions(doseText, doseFont)[1];
        var y = (h - (titleH + gap + doseH)) / 2;
        if (y < 0) {
            y = 0;
        }
        dc.drawText(w / 2, y, titleFont, titleText, Graphics.TEXT_JUSTIFY_CENTER);
        dc.drawText(w / 2, y + titleH + gap, doseFont, doseText, Graphics.TEXT_JUSTIFY_CENTER);
    }

    private function drawWaiting(dc as Dc, w as Number, h as Number, bgColor as Number) as Void {
        var textColor = (bgColor == Graphics.COLOR_BLACK) ? Graphics.COLOR_WHITE : Graphics.COLOR_BLACK;
        var contentW = w - (getContentSideInset(w) * 2);
        var titleText = loadString(Rez.Strings.AppName, "FuelPlanner");
        var noteText = loadString(Rez.Strings.LabelWaiting, "Waiting");
        var titleFont = getBestFontForBox(dc, titleText, contentW, getScaledValue(h, 0.18f, 18, 38), false);
        var noteFont = getBestFontForBox(dc, noteText, contentW, getScaledValue(h, 0.10f, 12, 22), false);
        var gap = getRowGap(h);
        var titleH = dc.getTextDimensions(titleText, titleFont)[1];
        var noteH = dc.getTextDimensions(noteText, noteFont)[1];
        var y = (h - (titleH + gap + noteH)) / 2;
        if (y < 0) {
            y = 0;
        }
        dc.setColor(textColor, Graphics.COLOR_TRANSPARENT);
        dc.drawText(w / 2, y, titleFont, titleText, Graphics.TEXT_JUSTIFY_CENTER);
        dc.drawText(w / 2, y + titleH + gap, noteFont, noteText, Graphics.TEXT_JUSTIFY_CENTER);
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

        var contentW = w - (getContentSideInset(w) * 2);
        var titleHeight = (value != "")
            ? getScaledValue(h, 0.14f, 16, 34)
            : getScaledValue(h, 0.17f, 20, 40);
        var titleFont = getBestFontForBox(dc, title, contentW, titleHeight, false);
        var valueFont = getBestFontForBox(dc, value, contentW, getScaledValue(h, 0.20f, 20, 52), true);
        var gap = getRowGap(h);
        var titleH = dc.getTextDimensions(title, titleFont)[1];
        var valueH = (value != "") ? dc.getTextDimensions(value, valueFont)[1] : 0;
        var totalH = titleH;
        if (valueH > 0) {
            totalH += gap + valueH;
        }
        var y = (h - totalH) / 2;
        if (y < 0) {
            y = 0;
        }

        dc.setColor(textColor, Graphics.COLOR_TRANSPARENT);
        dc.drawText(w / 2, y, titleFont, title, Graphics.TEXT_JUSTIFY_CENTER);
        if (value != "") {
            dc.drawText(w / 2, y + titleH + gap, valueFont, value, Graphics.TEXT_JUSTIFY_CENTER);
        }
    }

    private function drawMain(dc as Dc, w as Number, h as Number, bgColor as Number) as Void {
        var textColor = (bgColor == Graphics.COLOR_BLACK) ? Graphics.COLOR_WHITE : Graphics.COLOR_BLACK;
        var dimColor = (bgColor == Graphics.COLOR_BLACK) ? Graphics.COLOR_LT_GRAY : Graphics.COLOR_DK_GRAY;
        var cx = w / 2;
        var sideInset = getContentSideInset(w);
        var contentW = w - (sideInset * 2);
        var contentTop = getContentTopInset(h);
        var contentBottom = h - getContentBottomInset(h);
        var contentH = contentBottom - contentTop;
        var gap = getRowGap(h);

        var statusText = buildStatusText();
        var consumedG = (_model.getConsumedTotalG10() + 5) / 10;
        var targetG = (_model.getTargetTotalG10() + 5) / 10;
        var primaryText = consumedG.format("%d") + "/" + targetG.format("%d");
        var deficitText = buildDeficitText();
        var elapsedMin = _model.getElapsedActiveSec() / 60;
        var hrs = elapsedMin / 60;
        var mins = elapsedMin % 60;
        var timeText = (hrs > 0 ? hrs.format("%d") + "h" + mins.format("%02d") : mins.format("%d") + "m") +
            SEP_PIPE + _model.getIntakeCount().format("%d") + "x";
        var rateText = buildRateText();
        var showRateRow = contentH >= 150;

        var statusFont = getBestFontForBox(dc, statusText, contentW, getScaledValue(contentH, STATUS_ROW_RATIO, 12, 28), false);
        var primaryFont = getBestFontForBox(dc, primaryText, contentW, getScaledValue(contentH, PRIMARY_ROW_RATIO, 20, 52), true);
        var deficitFont = getBestFontForBox(dc, deficitText, contentW, getScaledValue(contentH, DEFICIT_ROW_RATIO, 12, 24), false);
        var metaFont = getBestFontForBox(dc, timeText, contentW, getScaledValue(contentH, META_ROW_RATIO, 10, 20), false);
        var rateFont = getBestFontForBox(dc, rateText, contentW, getScaledValue(contentH, RATE_ROW_RATIO, 10, 18), false);

        var statusH = dc.getTextDimensions(statusText, statusFont)[1];
        var primaryH = dc.getTextDimensions(primaryText, primaryFont)[1];
        var deficitH = dc.getTextDimensions(deficitText, deficitFont)[1];
        var metaH = dc.getTextDimensions(timeText, metaFont)[1];
        var rateH = showRateRow ? dc.getTextDimensions(rateText, rateFont)[1] : 0;
        var totalH = statusH + primaryH + deficitH + metaH + (gap * 3);
        if (showRateRow && rateH > 0) {
            totalH += gap + rateH;
        } else {
            showRateRow = false;
        }
        var y = contentTop + ((contentH - totalH) / 2);
        if (y < contentTop) {
            y = contentTop;
        }

        dc.setColor(textColor, Graphics.COLOR_TRANSPARENT);
        dc.drawText(cx, y, statusFont, statusText, Graphics.TEXT_JUSTIFY_CENTER);
        y += statusH + gap;
        dc.drawText(cx, y, primaryFont, primaryText, Graphics.TEXT_JUSTIFY_CENTER);
        y += primaryH + gap;
        dc.drawText(cx, y, deficitFont, deficitText, Graphics.TEXT_JUSTIFY_CENTER);
        y += deficitH + gap;
        dc.setColor(dimColor, Graphics.COLOR_TRANSPARENT);
        dc.drawText(cx, y, metaFont, timeText, Graphics.TEXT_JUSTIFY_CENTER);
        if (showRateRow) {
            y += metaH + gap;
            dc.drawText(cx, y, rateFont, rateText, Graphics.TEXT_JUSTIFY_CENTER);
        }

        drawOuterRing(dc, w, h, bgColor);
    }

    private function drawOuterRing(dc as Dc, w as Number, h as Number, bgColor as Number) as Void {
        var diameter = (w < h) ? w : h;
        if (diameter < 90) {
            return;
        }

        var stroke = getRingStrokeWidth(diameter);
        var padding = getRingPadding(diameter);
        var radius = (diameter / 2) - padding - (stroke / 2);
        if (radius <= 0) {
            return;
        }

        var baseColor = (bgColor == Graphics.COLOR_BLACK) ? Graphics.COLOR_LT_GRAY : Graphics.COLOR_DK_GRAY;
        var alertTone = _model.getRingTone();
        var ringColor = getRingColor(alertTone);
        var cx = w / 2;
        var cy = h / 2;

        dc.setPenWidth(stroke);
        dc.setColor(baseColor, Graphics.COLOR_TRANSPARENT);
        dc.drawCircle(cx, cy, radius);

        dc.setColor(ringColor, Graphics.COLOR_TRANSPARENT);
        dc.drawCircle(cx, cy, radius);
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

    private function buildRateText() as String {
        if (_model.isCalorieModeActive()) {
            if (_model.isCaloriesAvailable()) {
                return "Auto " + _model.getCarbFractionPct().format("%d") + "%";
            }
            return loadString(Rez.Strings.LabelRateAutoNoData, "Auto (no cal data)");
        }
        return loadString(Rez.Strings.LabelRateTargetPrefix, "Plan") + " " + _model.getCarbsTargetGph().format("%d") + " g/h";
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
        return FuelPlannerUtils.isTimerStateStoppedOrOff(info);
    }

    private function formatDuration(seconds as Number) as String {
        if (seconds < 0) { seconds = 0; }
        return (seconds / 60).format("%d") + ":" + (seconds % 60).format("%02d");
    }

    private function getScaledValue(total as Number, ratio as Float,
                                    minValue as Number, maxValue as Number) as Number {
        var scaled = (total.toFloat() * ratio).toNumber();
        if (scaled < minValue) {
            return minValue;
        }
        if (scaled > maxValue) {
            return maxValue;
        }
        return scaled;
    }

    private function getBestFontForBox(dc as Dc, text as String,
                                       maxWidth as Number, maxHeight as Number,
                                       allowNumber as Boolean) {
        var widthLimit = (maxWidth < 1) ? 1 : maxWidth;
        var heightLimit = (maxHeight < 1) ? 1 : maxHeight;
        var bestFont = Graphics.FONT_XTINY;
        var bestHeight = 0;
        var dims = dc.getTextDimensions(text, Graphics.FONT_XTINY);

        if (dims[0] <= widthLimit && dims[1] <= heightLimit) {
            bestHeight = dims[1];
        }

        dims = dc.getTextDimensions(text, Graphics.FONT_TINY);
        if (dims[0] <= widthLimit && dims[1] <= heightLimit && dims[1] >= bestHeight) {
            bestFont = Graphics.FONT_TINY;
            bestHeight = dims[1];
        }

        dims = dc.getTextDimensions(text, Graphics.FONT_MEDIUM);
        if (dims[0] <= widthLimit && dims[1] <= heightLimit && dims[1] >= bestHeight) {
            bestFont = Graphics.FONT_MEDIUM;
            bestHeight = dims[1];
        }

        if (allowNumber) {
            dims = dc.getTextDimensions(text, Graphics.FONT_NUMBER_MILD);
            if (dims[0] <= widthLimit && dims[1] <= heightLimit && dims[1] >= bestHeight) {
                bestFont = Graphics.FONT_NUMBER_MILD;
            }
        }

        return bestFont;
    }

    private function getContentSideInset(w as Number) as Number {
        return getScaledValue(w, CONTENT_SIDE_RATIO, CONTENT_MIN_SIDE_PX, 28);
    }

    private function getContentTopInset(h as Number) as Number {
        return getScaledValue(h, CONTENT_TOP_RATIO, CONTENT_MIN_TOP_PX, 24);
    }

    private function getContentBottomInset(h as Number) as Number {
        return getScaledValue(h, CONTENT_TOP_RATIO, CONTENT_MIN_BOTTOM_PX, 28);
    }

    private function getRowGap(h as Number) as Number {
        return getScaledValue(h, CONTENT_GAP_RATIO, 4, 10);
    }

    private function getRingStrokeWidth(size as Number) as Number {
        return getScaledValue(size, RING_STROKE_RATIO, RING_STROKE_MIN_PX, RING_STROKE_MAX_PX);
    }

    private function getRingPadding(size as Number) as Number {
        return getScaledValue(size, 0.02f, RING_PADDING_MIN_PX, RING_PADDING_MAX_PX);
    }

    private function getRingColor(tone as Number) as Number {
        if (tone >= 2) {
            return Graphics.COLOR_RED;
        }
        if (tone == 1) {
            return Graphics.COLOR_YELLOW;
        }
        return Graphics.COLOR_GREEN;
    }
}
