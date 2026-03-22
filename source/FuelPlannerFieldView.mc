import Toybox.Activity;
import Toybox.Graphics;
import Toybox.Math;
import Toybox.WatchUi;
import Toybox.System;
import Toybox.Lang;
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

    // Deficit gauge constants (responsive edge indicator)
    private const GAUGE_WIDTH_RATIO = 0.15f;
    private const GAUGE_MIN_W_PX = 6;
    private const GAUGE_MAX_W_PX = 45;
    private const GAUGE_MIN_H_PX = 8;
    private const GAUGE_ALERT_G10 = 200; // 20g

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
                // Starte den Overlay-Timer für 3 Sekunden
                _overlayEndTime = System.getTimer() + OVERLAY_DURATION_MS;
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

        if (!_model.isSessionActive()) {
            drawNoSession(dc, cx, h, textColor, dimColor);
            return;
        }

        if (_showRecoveryLayout) {
            drawRecoveryLayout(dc, w, h, cx);
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
        
        // Hintergrund: Aggressives Rot oder Orange
        dc.setColor(Graphics.COLOR_RED, Graphics.COLOR_RED);
        dc.fillRectangle(0, 0, w, h);
        
        // Text-Farbe Weiß für maximalen Kontrast
        dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_TRANSPARENT);
        
        var doseText = _model.getDoseG().format("%d") + UNIT_G;
        var titleFont = getBestFontForHeight(dc, (h.toFloat() * 0.22f).toNumber(), false);
        var doseFont = getBestFontForHeight(dc, (h.toFloat() * 0.14f).toNumber(), false);
        var gap = getRowGap(h);
        var strFuelNow = loadString(Rez.Strings.LabelFuelNow, "FUEL NOW");
        var titleH = dc.getTextDimensions(strFuelNow, titleFont)[1];
        var doseH = dc.getTextDimensions(doseText, doseFont)[1];
        var totalHeight = titleH + gap + doseH;
        var y = (h - totalHeight) / 2;
        if (y < 0) {
            y = 0;
        }

        // Text zentriert ausgeben
        dc.drawText(w / 2, y, titleFont, strFuelNow, Graphics.TEXT_JUSTIFY_CENTER);
        dc.drawText(w / 2, y + titleH + gap, doseFont, doseText, Graphics.TEXT_JUSTIFY_CENTER);
        
        // Optional: Ein weißer Rahmen zur Abgrenzung
        dc.setPenWidth(4);
        dc.drawRectangle(2, 2, w-4, h-4);
    }
    //! Waiting screen before activity starts
    private function drawNoSession(dc as Dc, cx as Number, h as Number,
                                   textColor as Number, dimColor as Number) as Void {
        dc.setColor(textColor, Graphics.COLOR_TRANSPARENT);
        dc.drawText(cx, h / 2 - h / 13, Graphics.FONT_MEDIUM,
                    loadString(Rez.Strings.AppName, "FuelPlanner"),
                    Graphics.TEXT_JUSTIFY_CENTER);
        dc.setColor(dimColor, Graphics.COLOR_TRANSPARENT);
        dc.drawText(cx, h / 2 + h / 20, Graphics.FONT_TINY,
                    loadString(Rez.Strings.LabelWaiting, "Waiting for activity..."),
                    Graphics.TEXT_JUSTIFY_CENTER);
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

        var titleFont = getBestFontForHeight(dc, (h.toFloat() * 0.15f).toNumber(), false);
        var valueFont = getBestFontForHeight(dc, (h.toFloat() * 0.30f).toNumber(), true);
        var noteFont  = getBestFontForHeight(dc, (h.toFloat() * 0.11f).toNumber(), false);
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
        var safeTop = SAFE_TOP_PX;
        var gap = ROW_GAP_PX;
        var y = safeTop;
        //var doseG = _model.getDoseG();

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
        dc.setColor(statusColor, Graphics.COLOR_TRANSPARENT);
        dc.drawText(cx, y, Graphics.FONT_TINY, statusText, Graphics.TEXT_JUSTIFY_CENTER);
        y += 20 + gap;

        // Numbers row
        var consumedG = (_model.getConsumedTotalG10() + 5) / 10;
        var targetG = (_model.getTargetTotalG10() + 5) / 10;
        var numStr = consumedG.format("%d") + "/" + targetG.format("%d");
        dc.setColor(textColor, Graphics.COLOR_TRANSPARENT);
        dc.drawText(cx, y, Graphics.FONT_MEDIUM, numStr, Graphics.TEXT_JUSTIFY_CENTER);
        y += 30 + gap;

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
        dc.setColor(deficitColor, Graphics.COLOR_TRANSPARENT);
        dc.drawText(cx, y, Graphics.FONT_TINY, deficitText, Graphics.TEXT_JUSTIFY_CENTER);
        y += 20 + gap;

        // Time row
        var elapsedMin = _model.getElapsedActiveSec() / 60;
        var timeText = (elapsedMin / 60).format("%d") + "h" + (elapsedMin % 60).format("%02d") + SEP_PIPE + _model.getIntakeCount().format("%d") + "x";
        dc.setColor(dimColor, Graphics.COLOR_TRANSPARENT);
        dc.drawText(cx, y, Graphics.FONT_TINY, timeText, Graphics.TEXT_JUSTIFY_CENTER);

        drawDeficitGauge(dc, w, h, deficitG10, _model.getDoseG10(), dimColor, touchEnabled);
    }

//! Draw responsive edge gauges on both sides: green when on/ahead, red proportional to deficit.
private function drawDeficitGauge(dc as Dc, w as Number, h as Number, 
                                  deficitG10 as Number, doseG10 as Number, 
                                  dimColor as Number, touchEnabled as Boolean) as Void {
    if (w < 150 || h < 110) { return; }
    
    var gaugeW = (w * GAUGE_WIDTH_RATIO).toNumber();
    if (gaugeW < GAUGE_MIN_W_PX) { gaugeW = GAUGE_MIN_W_PX; }
    else if (gaugeW > GAUGE_MAX_W_PX) { gaugeW = GAUGE_MAX_W_PX; }

    var top = getSafeTopInset(h);
    var bottomInset = getSafeBottomInset(w, h, touchEnabled);
    var gaugeH = h - top - bottomInset;
    if (gaugeH < GAUGE_MIN_H_PX) { return; }

    var xRight = w - gaugeW;
    var y = top;

    // Calculate fill ratio
    var ratio = 0.0f;
    if (doseG10 > 0) {
        ratio = deficitG10.toFloat() / doseG10.toFloat();
        if (ratio < 0.0f) { ratio = 0.0f; }
        if (ratio > 1.0f) { ratio = 1.0f; }
    }

    var redH = (gaugeH.toFloat() * ratio).toNumber();
    var greenH = gaugeH - redH;

    // Draw background track
    dc.setColor(dimColor, Graphics.COLOR_TRANSPARENT);
    dc.fillRectangle(0, y, gaugeW, gaugeH);
    dc.fillRectangle(xRight, y, gaugeW, gaugeH);

    // Draw green portion (on target)
    if (greenH > 0) {
        dc.setColor(COLOR_GOOD, Graphics.COLOR_TRANSPARENT);
        dc.fillRectangle(0, y, gaugeW, greenH);
        dc.fillRectangle(xRight, y, gaugeW, greenH);
    }

    // Draw deficit portion
    if (redH > 0) {
        var alertColor = (deficitG10 >= GAUGE_ALERT_G10) ? Graphics.COLOR_RED : Graphics.COLOR_ORANGE;
        dc.setColor(alertColor, Graphics.COLOR_TRANSPARENT);
        dc.fillRectangle(0, y + greenH, gaugeW, redH);
        dc.fillRectangle(xRight, y + greenH, gaugeW, redH);
    }
}

    private function getSafeTopInset(h as Number) as Number {
        return SAFE_TOP_PX;
    }

    private function getSafeBottomInset(w as Number, h as Number, touchEnabled as Boolean) as Number {
        return SAFE_BOTTOM_PX;
    }

    private function getRowGap(h as Number) as Number {
        return ROW_GAP_PX;
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
