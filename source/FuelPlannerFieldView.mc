import Toybox.Activity;
import Toybox.Graphics;
import Toybox.Math;
import Toybox.WatchUi;
import Toybox.System;
import Toybox.Lang;
import FuelPlannerLog;
//! Data Field View for FuelPlanner - responsive, top-to-bottom layout
(:full)
class FuelPlannerFieldView extends WatchUi.DataField {

    private var _model as FuelModel;
    private var _reminder as ReminderManager;
    private var _showRecoveryLayout as Boolean = false;

    // Colors
    private const COLOR_NORMAL  = Graphics.COLOR_WHITE;
    private const COLOR_WARNING = Graphics.COLOR_YELLOW;
    private const COLOR_ALERT   = Graphics.COLOR_RED;
    private const COLOR_GOOD    = Graphics.COLOR_GREEN;
    private const COLOR_DIM     = Graphics.COLOR_LT_GRAY;
    private const COLOR_RECOVERY = Graphics.COLOR_ORANGE;

    // Vertical flow layout constants
    private const SAFE_TOP_PX = 16;
    private const SAFE_BOTTOM_PX = 24;
    private const ROW_GAP_PX = 6;
    private const UNIT_GAP_PX = 3;

    // Outer ring constants
    private const RING_STROKE_RATIO = 0.045f;
    private const RING_STROKE_MIN_PX = 8;
    private const RING_STROKE_MAX_PX = 18;
    private const RING_PADDING_MIN_PX = 4;
    private const RING_PADDING_MAX_PX = 12;

    // Blink state for "FUEL NOW" indicator
    private var _blinkState    as Boolean = false;
    private var _lastBlinkTime as Number  = 0;
    private const BLINK_INTERVAL = 500;


    // Last known field size (for tap zone mapping in multi-field layouts)
    private var _lastFieldWidth as Number = 0;
    private var _lastFieldHeight as Number = 0;
    private const DEFAULT_SCREEN_HEIGHT = 240;
    private const DEFAULT_SCREEN_WIDTH = 240;
    private const UNIT_G = "g";
    private const UNIT_GPH = " g/h";
    private const SEP_PIPE = " | ";
    private const RECOVERY_MIN_G = 10;
    private const CONTENT_SIDE_RATIO = 0.10f;
    private const CONTENT_VERTICAL_RATIO = 0.09f;
    private const CONTENT_GAP_RATIO = 0.025f;
    private const STATUS_ROW_RATIO = 0.13f;
    private const PRIMARY_ROW_RATIO = 0.26f;
    private const DEFICIT_ROW_RATIO = 0.12f;
    private const META_ROW_RATIO = 0.10f;
    private const RATE_ROW_RATIO = 0.09f;
    private const CONTENT_MIN_SIDE_PX = 12;
    private const CONTENT_MIN_TOP_PX = 14;
    private const CONTENT_MIN_BOTTOM_PX = 18;
    private const RATE_ROW_MIN_HEIGHT_PX = 12;

    //Eating overlay config
    private var _overlayEndTime as Number = 0;
    private const OVERLAY_DURATION_MS = 3000; // 3 Sekunden

    function getFieldHeight() as Number {
        if (_lastFieldHeight > 0) {
            return _lastFieldHeight;
        }
        return getScreenHeight();
    }

    function getFieldWidth() as Number {
        if (_lastFieldWidth > 0) {
            return _lastFieldWidth;
        }
        return getScreenWidth();
    }

    function initialize(model as FuelModel, reminder as ReminderManager) {
        DataField.initialize();
        _model    = model;
        _reminder = reminder;
    }

    function onLayout(dc as Dc) as Void {
        _lastFieldWidth = dc.getWidth();
        _lastFieldHeight = dc.getHeight();
    }


    function onTimerLap() as Void {
        _model.onTimerLap();
    }

    function dismissOverlay() as Void {
        _overlayEndTime = 0;
    }

    //! Called every second with activity info
    function compute(info as Activity.Info) as Void {
        _model.compute(info);
        _showRecoveryLayout = isTimerStateStoppedOrOff(info);

        var autoIntakeTriggered = _model.consumeAutoIntakeEvent();
        if (_showRecoveryLayout) {
            _overlayEndTime = 0;
        } else if (autoIntakeTriggered) {
            _reminder.triggerAutoIntake();
        }

        // Overlay bei Pause sofort ausblenden
        if (_model.isPaused()) {
            _overlayEndTime = 0;
        }

        if (!_showRecoveryLayout && _model.isReminderDue() && !_model.isPaused()) {
            if (_reminder.triggerReminder()) { // Liefert true, wenn der Alarm gerade ausgelöst wurde
                _model.recordReminderTriggered();
                presentReminderNotification();
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
        var now = System.getTimer();
        var w  = dc.getWidth();
        var h  = dc.getHeight();
        _lastFieldWidth = w;
        _lastFieldHeight = h;
        dc.setColor(Graphics.COLOR_TRANSPARENT, bgColor);
        dc.clear();
        // Prüfen, ob das Overlay aktiv sein soll
        if (now < _overlayEndTime) {
            drawReminderOverlay(dc);
            return; // Wir brechen hier ab, damit das Overlay die ganze Fläche nutzt
        }
        var cx = w / 2;

        var isDark    = (bgColor == Graphics.COLOR_BLACK);
        var textColor = isDark ? COLOR_NORMAL : Graphics.COLOR_BLACK;
        var dimColor  = isDark ? COLOR_DIM    : Graphics.COLOR_DK_GRAY;

        var touchEnabled = isTouchEnabled();

        if (_showRecoveryLayout) {
            drawRecoveryLayout(dc, w, h, cx);
            return;
        }

        if (!_model.isSessionActive()) {
            drawNoSession(dc, cx, h, textColor, dimColor);
            return;
        }

        drawMainLayout(dc, w, h, cx, textColor, dimColor, touchEnabled);
    }

    private function isTouchEnabled() as Boolean {
        try {
            var settings = System.getDeviceSettings();
            if (settings != null &&
                settings has :isTouchScreen &&
                settings.isTouchScreen instanceof Boolean) {
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

    private function getScreenWidth() as Number {
        try {
            var settings = System.getDeviceSettings();
            if (settings != null && settings has :screenWidth && settings.screenWidth instanceof Number) {
                return settings.screenWidth;
            }
        } catch (e) {}
        return DEFAULT_SCREEN_WIDTH;
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


    //! Zeichnet ein auffälliges Vollbild-Overlay
    private function drawReminderOverlay(dc as Dc) as Void {
        var w = dc.getWidth();
        var h = dc.getHeight();
        var contentInset = getScaledValue(w, 0.08f, 12, 30);
        var contentW = w - (contentInset * 2);
        if (contentW < 40) {
            contentW = 40;
            contentInset = (w - contentW) / 2;
        }
        
        // Hintergrund: Aggressives Rot oder Orange
        dc.setColor(Graphics.COLOR_RED, Graphics.COLOR_RED);
        dc.fillRectangle(0, 0, w, h);
        
        // Text-Farbe Weiß für maximalen Kontrast
        dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_TRANSPARENT);
        
        var strFuelNow = loadString(Rez.Strings.LabelFuelNow, "FUEL NOW");
        var doseText = _model.getDoseG().format("%d") + UNIT_G;
        var reasonText = buildReminderReasonText();
        var titleFont = getBestFontForBox(dc, strFuelNow, contentW, getScaledValue(h, 0.20f, 24, 56), false);
        var doseFont = getBestFontForBox(dc, doseText, contentW, getScaledValue(h, 0.14f, 18, 40), true);
        var reasonFont = getBestFontForBox(dc, reasonText, contentW, getScaledValue(h, 0.09f, 12, 22), false);
        var gap = getRowGap(h);
        var titleH = dc.getTextDimensions(strFuelNow, titleFont)[1];
        var doseH = dc.getTextDimensions(doseText, doseFont)[1];
        var reasonH = dc.getTextDimensions(reasonText, reasonFont)[1];
        var totalHeight = titleH + gap + doseH + gap + reasonH;
        var y = (h - totalHeight) / 2;
        if (y < 0) {
            y = 0;
        }

        // Text zentriert ausgeben
        dc.drawText(w / 2, y, titleFont, strFuelNow, Graphics.TEXT_JUSTIFY_CENTER);
        dc.drawText(w / 2, y + titleH + gap, doseFont, doseText, Graphics.TEXT_JUSTIFY_CENTER);
        dc.drawText(w / 2, y + titleH + gap + doseH + gap, reasonFont, reasonText, Graphics.TEXT_JUSTIFY_CENTER);
        
        // Optional: Ein weißer Rahmen zur Abgrenzung
        dc.setPenWidth(4);
        dc.drawRectangle(2, 2, w-4, h-4);
    }

    private function presentReminderNotification() as Void {
        _overlayEndTime = System.getTimer() + OVERLAY_DURATION_MS;
        if (!_model.isDataFieldAlertEnabled()) {
            return;
        }

        if (!(WatchUi.DataField has :showAlert)) {
            FuelPlannerLog.logError("Alert", "DataField.showAlert unavailable on this device");
            return;
        }

        var titleText = loadString(Rez.Strings.LabelFuelNow, "FUEL NOW");
        var doseText = _model.getDoseG().format("%d") + UNIT_G;
        var reasonText = buildReminderReasonText();

        try {
            showAlert(new FuelPlannerReminderAlert(titleText, doseText, reasonText));
        } catch (e) {
            FuelPlannerLog.logError("Alert", "Failed to show DataFieldAlert");
        }
    }
    //! Waiting screen before activity starts
    private function drawNoSession(dc as Dc, cx as Number, h as Number,
                                   textColor as Number, dimColor as Number) as Void {
        var w = dc.getWidth();
        var sideInset = getContentSideInset(w);
        var contentW = w - (sideInset * 2);
        var titleText = loadString(Rez.Strings.AppName, "FuelPlanner");
        var noteText = loadString(Rez.Strings.LabelWaiting, "Waiting for activity...");
        var titleFont = getBestFontForBox(dc, titleText, contentW, getScaledValue(h, 0.18f, 20, 42), false);
        var noteFont = getBestFontForBox(dc, noteText, contentW, getScaledValue(h, 0.10f, 12, 24), false);
        var gap = getRowGap(h);
        var titleH = dc.getTextDimensions(titleText, titleFont)[1];
        var noteH = dc.getTextDimensions(noteText, noteFont)[1];
        var y = (h - (titleH + gap + noteH)) / 2;
        if (y < 0) {
            y = 0;
        }

        dc.setColor(textColor, Graphics.COLOR_TRANSPARENT);
        dc.drawText(cx, y, titleFont, titleText, Graphics.TEXT_JUSTIFY_CENTER);
        dc.setColor(dimColor, Graphics.COLOR_TRANSPARENT);
        dc.drawText(cx, y + titleH + gap, noteFont, noteText, Graphics.TEXT_JUSTIFY_CENTER);
    }

    private function drawRecoveryLayout(dc as Dc, w as Number, h as Number,
                                        cx as Number) as Void {
        var recoveryDeficit = _model.getRecoveryDeficit();
        var showRecoveryHint = false;
        if (recoveryDeficit != null) {
            showRecoveryHint = recoveryDeficit > RECOVERY_MIN_G;
        }
        var panelColor = showRecoveryHint ? COLOR_RECOVERY : COLOR_GOOD;
        var titleText = showRecoveryHint ? loadString(Rez.Strings.LabelRecovery, "Recovery") : loadString(Rez.Strings.LabelFuelingOk, "Fueling OK");
        var valueText = "";
        var noteText = "";
        if (showRecoveryHint && recoveryDeficit != null) {
            valueText = "+" + recoveryDeficit.format("%d") + UNIT_G;
            noteText = loadString(Rez.Strings.LabelRecoveryAction, "Refuel");
        }

        dc.setColor(panelColor, panelColor);
        dc.fillRectangle(0, 0, w, h);

        var sideInset = getScaledValue(w, CONTENT_SIDE_RATIO, CONTENT_MIN_SIDE_PX, 36);
        var contentW = w - (sideInset * 2);
        var titleHeight = showRecoveryHint
            ? getScaledValue(h, 0.13f, 18, 36)
            : getScaledValue(h, 0.17f, 22, 42);
        var titleFont = getBestFontForBox(dc, titleText, contentW, titleHeight, false);
        var valueFont = getBestFontForBox(dc, valueText, contentW, getScaledValue(h, 0.24f, 24, 64), true);
        var noteFont  = getBestFontForBox(dc, noteText, contentW, getScaledValue(h, 0.10f, 12, 24), false);
        var gap = getRowGap(h);

        var titleH = dc.getTextDimensions(titleText, titleFont)[1];
        var valueH = (valueText != "") ? dc.getTextDimensions(valueText, valueFont)[1] : 0;
        var noteH  = (noteText != "") ? dc.getTextDimensions(noteText, noteFont)[1] : 0;
        var rowCount = 1;
        if (valueH > 0) { rowCount += 1; }
        if (noteH > 0) { rowCount += 1; }

        var totalHeight = titleH + valueH + noteH + ((rowCount - 1) * gap);
        var y = (h - totalHeight) / 2;
        if (y < 0) { y = 0; }

        dc.setColor(Graphics.COLOR_BLACK, Graphics.COLOR_TRANSPARENT);
        dc.drawText(cx, y, titleFont, titleText, Graphics.TEXT_JUSTIFY_CENTER);
        y += titleH;

        if (valueText != "") {
            y += gap;
            dc.drawText(cx, y, valueFont, valueText, Graphics.TEXT_JUSTIFY_CENTER);
            y += valueH;
        }

        if (noteText != "") {
            y += gap;
            dc.drawText(cx, y, noteFont, noteText, Graphics.TEXT_JUSTIFY_CENTER);
        }
    }

    //! Main layout - simplified for memory optimization
    private function drawMainLayout(dc as Dc, w as Number, h as Number,
                                    cx as Number, textColor as Number,
                                    dimColor as Number, touchEnabled as Boolean) as Void {
        var sideInset = getContentSideInset(w);
        var contentW = w - (sideInset * 2);
        if (contentW < 40) {
            contentW = 40;
            sideInset = (w - contentW) / 2;
        }
        var contentTop = getContentTopInset(h);
        var contentBottom = h - getContentBottomInset(w, h, touchEnabled);
        var contentH = contentBottom - contentTop;
        if (contentH < 40) {
            contentH = h;
            contentTop = 0;
        }
        var gap = getRowGap(h);

        // Status row
        var statusText;
        var statusColor;
        if (_model.isPaused()) {
            statusText = loadString(Rez.Strings.LabelPaused, "PAUSED");
            statusColor = COLOR_WARNING;
        } else if (_model.isReminderDue()) {
            statusText = touchEnabled ? loadString(Rez.Strings.LabelFuelNow, "FUEL NOW") : loadString(Rez.Strings.LabelAutoFlowStatus, "AUTO-FLOW");
            statusColor = COLOR_ALERT;
        } else {
            statusText = loadString(Rez.Strings.LabelNext, "Next") + " " + formatDuration(_model.getDisplayNextDueInSec());
            statusColor = COLOR_GOOD;
        }

        // Numbers row
        var consumedG = (_model.getConsumedTotalG10() + 5) / 10;
        var targetG = (_model.getTargetTotalG10() + 5) / 10;
        var numStr = consumedG.format("%d") + "/" + targetG.format("%d");

        // Deficit row
        var deficitG10 = _model.getDeficitG10();
        var deficitText;
        var deficitColor;
        if (deficitG10 > 5) {
            deficitText = loadString(Rez.Strings.LabelBehind, "Behind") + " " + ((deficitG10 + 5) / 10).format("%d") + UNIT_G;
            deficitColor = COLOR_WARNING;
        } else if (deficitG10 < -5) {
            deficitText = loadString(Rez.Strings.LabelAhead, "Ahead") + " " + (((-deficitG10) + 5) / 10).format("%d") + UNIT_G;
            deficitColor = COLOR_GOOD;
        } else {
            deficitText = loadString(Rez.Strings.LabelOnTarget, "On target");
            deficitColor = COLOR_GOOD;
        }

        // Time row
        var elapsedMin = _model.getElapsedActiveSec() / 60;
        var timeText = (elapsedMin / 60).format("%d") + "h" + (elapsedMin % 60).format("%02d") + SEP_PIPE + _model.getIntakeCount().format("%d") + "x";
        var rateText = buildRateLabel();
        var showRateRow = contentH >= 150;

        // Keep the typography inside a centered inner column so we can later
        // swap the side bars for a perimeter ring without moving the text again.
        var statusFont = getBestFontForBox(dc, statusText, contentW, getScaledValue(contentH, STATUS_ROW_RATIO, 14, 32), false);
        var primaryFont = getBestFontForBox(dc, numStr, contentW, getScaledValue(contentH, PRIMARY_ROW_RATIO, 24, 60), true);
        var deficitFont = getBestFontForBox(dc, deficitText, contentW, getScaledValue(contentH, DEFICIT_ROW_RATIO, 14, 28), false);
        var metaFont = getBestFontForBox(dc, timeText, contentW, getScaledValue(contentH, META_ROW_RATIO, 12, 22), false);
        var rateFont = getBestFontForBox(dc, rateText, contentW, getScaledValue(contentH, RATE_ROW_RATIO, 12, 20), false);

        var statusH = dc.getTextDimensions(statusText, statusFont)[1];
        var primaryH = dc.getTextDimensions(numStr, primaryFont)[1];
        var deficitH = dc.getTextDimensions(deficitText, deficitFont)[1];
        var metaH = dc.getTextDimensions(timeText, metaFont)[1];
        var rateH = showRateRow ? dc.getTextDimensions(rateText, rateFont)[1] : 0;

        var totalHeight = statusH + primaryH + deficitH + metaH + (gap * 3);
        if (showRateRow && rateH >= RATE_ROW_MIN_HEIGHT_PX) {
            totalHeight += gap + rateH;
        } else {
            showRateRow = false;
            rateH = 0;
        }

        var y = contentTop + ((contentH - totalHeight) / 2);
        if (y < contentTop) {
            y = contentTop;
        }

        dc.setColor(statusColor, Graphics.COLOR_TRANSPARENT);
        dc.drawText(cx, y, statusFont, statusText, Graphics.TEXT_JUSTIFY_CENTER);
        y += statusH + gap;

        dc.setColor(textColor, Graphics.COLOR_TRANSPARENT);
        dc.drawText(cx, y, primaryFont, numStr, Graphics.TEXT_JUSTIFY_CENTER);
        y += primaryH + gap;

        dc.setColor(deficitColor, Graphics.COLOR_TRANSPARENT);
        dc.drawText(cx, y, deficitFont, deficitText, Graphics.TEXT_JUSTIFY_CENTER);
        y += deficitH + gap;

        dc.setColor(dimColor, Graphics.COLOR_TRANSPARENT);
        dc.drawText(cx, y, metaFont, timeText, Graphics.TEXT_JUSTIFY_CENTER);

        if (showRateRow) {
            y += metaH + gap;
            dc.drawText(cx, y, rateFont, rateText, Graphics.TEXT_JUSTIFY_CENTER);
        }

        drawOuterRing(dc, w, h, dimColor, touchEnabled);
    }

    private function drawOuterRing(dc as Dc, w as Number, h as Number,
                                   dimColor as Number, touchEnabled as Boolean) as Void {
        var diameter = (w < h) ? w : h;
        if (diameter < 96) {
            return;
        }

        var stroke = getRingStrokeWidth(diameter);
        var padding = getRingPadding(diameter);
        var radius = (diameter / 2) - padding - (stroke / 2);
        if (radius <= 0) {
            return;
        }

        var cx = w / 2;
        var cy = h / 2;
        var tone = _model.getRingTone();
        var ringColor = getRingColor(tone);

        dc.setPenWidth(stroke);
        dc.setColor(dimColor, Graphics.COLOR_TRANSPARENT);
        dc.drawCircle(cx, cy, radius);

        dc.setColor(ringColor, Graphics.COLOR_TRANSPARENT);
        dc.drawCircle(cx, cy, radius);
    }

    private function getSafeTopInset(h as Number) as Number {
        return SAFE_TOP_PX;
    }

    private function getSafeBottomInset(w as Number, h as Number, touchEnabled as Boolean) as Number {
        return SAFE_BOTTOM_PX;
    }

    private function getRowGap(h as Number) as Number {
        return getScaledValue(h, CONTENT_GAP_RATIO, ROW_GAP_PX, 12);
    }

    //! Select best fitting font for a target row height.
    //! If `allowNumber` is true, `FONT_NUMBER_MILD` is also considered.
    private function getBestFontForHeight(dc as Dc, rowHeight as Number,
                                          allowNumber as Boolean) {
        var target = rowHeight;
        if (target < 1) {
            target = 1;
        }

        var hXtiny  = dc.getTextDimensions("Ag", Graphics.FONT_XTINY)[1];
        var hTiny   = dc.getTextDimensions("Ag", Graphics.FONT_TINY)[1];
        var hMedium = dc.getTextDimensions("Ag", Graphics.FONT_MEDIUM)[1];
        var hNumber = dc.getTextDimensions("88", Graphics.FONT_NUMBER_MILD)[1];

        var bestFont = Graphics.FONT_XTINY;
        var bestH    = hXtiny;

        if (hTiny <= target && hTiny >= bestH) {
            bestFont = Graphics.FONT_TINY;
            bestH = hTiny;
        }
        if (hMedium <= target && hMedium >= bestH) {
            bestFont = Graphics.FONT_MEDIUM;
            bestH = hMedium;
        }
        if (allowNumber && hNumber <= target && hNumber >= bestH) {
            bestFont = Graphics.FONT_NUMBER_MILD;
        }

        return bestFont;
    }

    private function getBestFontForBox(dc as Dc, text as String,
                                       maxWidth as Number, maxHeight as Number,
                                       allowNumber as Boolean) {
        var widthLimit = maxWidth;
        if (widthLimit < 1) {
            widthLimit = 1;
        }
        var heightLimit = maxHeight;
        if (heightLimit < 1) {
            heightLimit = 1;
        }

        var bestFont = Graphics.FONT_XTINY;
        var bestHeight = 0;

        var dims = dc.getTextDimensions(text, Graphics.FONT_XTINY);
        if (dims[0] <= widthLimit && dims[1] <= heightLimit) {
            bestFont = Graphics.FONT_XTINY;
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

    private function getRingStrokeWidth(size as Number) as Number {
        return getScaledValue(size, RING_STROKE_RATIO, RING_STROKE_MIN_PX, RING_STROKE_MAX_PX);
    }

    private function getRingPadding(size as Number) as Number {
        return getScaledValue(size, 0.02f, RING_PADDING_MIN_PX, RING_PADDING_MAX_PX);
    }

    private function getRingColor(tone as Number) as Number {
        if (tone >= 2) {
            return COLOR_ALERT;
        }
        if (tone == 1) {
            return COLOR_WARNING;
        }
        return COLOR_GOOD;
    }

    private function getUnitGap(w as Number) as Number {
        return UNIT_GAP_PX;
    }

    private function getUnitVerticalNudge(h as Number) as Number {
        return 2;
    }

    private function getRoundEdgePadding(w as Number) as Number {
        return 8;
    }

    private function getRoundHintBottomInset(w as Number, h as Number,
                                             textWidth as Number, textHeight as Number) as Number {
        if (w != h) { return 0; }
        return SAFE_BOTTOM_PX;
    }

    private function getContentSideInset(w as Number) as Number {
        var inset = getScaledValue(w, CONTENT_SIDE_RATIO, CONTENT_MIN_SIDE_PX, 44);
        var ringInset = getRingStrokeWidth(w) + getRingPadding(w) + getRoundEdgePadding(w);
        if (ringInset > inset) {
            inset = ringInset;
        }
        return inset;
    }

    private function getContentTopInset(h as Number) as Number {
        var inset = getScaledValue(h, CONTENT_VERTICAL_RATIO, CONTENT_MIN_TOP_PX, 36);
        var safeTop = getSafeTopInset(h);
        if (safeTop > inset) {
            inset = safeTop;
        }
        return inset;
    }

    private function getContentBottomInset(w as Number, h as Number, touchEnabled as Boolean) as Number {
        var inset = getScaledValue(h, CONTENT_VERTICAL_RATIO, CONTENT_MIN_BOTTOM_PX, 40);
        var safeBottom = getSafeBottomInset(w, h, touchEnabled);
        if (safeBottom > inset) {
            inset = safeBottom;
        }
        return inset;
    }

    private function getRequiredMainHeight(statusH as Number, numberH as Number,
                                           labelH as Number, deficitH as Number,
                                           metaH as Number, hintH as Number,
                                           gap as Number) as Number {
        var required = statusH + numberH + deficitH;
        var rows = 3;

        if (labelH > 0) {
            required += labelH;
            rows += 1;
        }
        if (metaH > 0) {
            required += metaH;
            rows += 1;
        }
        if (hintH > 0) {
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
                return "Auto " + _model.getCarbFractionPct().format("%d") +
                       loadString(Rez.Strings.LabelRateAutoCarbsSuffix, "% carbs");
            }
            return loadString(Rez.Strings.LabelRateAutoNoData, "Auto (no cal data)");
        }
        return loadString(Rez.Strings.LabelRateTargetPrefix, "Plan") + " " + _model.getCarbsTargetGph().format("%d") + UNIT_GPH;
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

    private function buildReminderReasonText() as String {
        if (_model.getReminderMode() == 1) {
            return loadString(Rez.Strings.ModeFixed, "Fixed") + " " +
                   _model.getFixedIntervalMin().format("%d") + " " +
                   loadString(Rez.Strings.UnitMinutes, "min");
        }

        var deficitText = buildDeficitText();
        if (deficitText != loadString(Rez.Strings.LabelOnTarget, "On target")) {
            return deficitText;
        }
        return buildRateLabel();
    }

    private function isTimerStateStoppedOrOff(info as Activity.Info) as Boolean {
        return FuelPlannerUtils.isTimerStateStoppedOrOff(info);
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
