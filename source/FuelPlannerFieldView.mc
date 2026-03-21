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
    private var _strAppName as String = "";
    private var _strWaiting as String = "";
    private var _strPaused as String = "";
    private var _strFuelNow as String = "";
    private var _strTapPrefix as String = "";
    private var _strNext as String = "";
    private var _strBehind as String = "";
    private var _strAhead as String = "";
    private var _strOnTarget as String = "";
    private var _strRateTargetPrefix as String = "";
    private var _strRateAutoCarbsSuffix as String = "";
    private var _strRateAutoNoData as String = "";
    private var _strAutoFlowStatus as String = "";
    private var _strRecovery as String = "";
    private var _strRecoveryAction as String = "";
    private var _strFuelingOk as String = "";
    private var _showRecoveryLayout as Boolean = false;

    // Colors
    private const COLOR_NORMAL  = Graphics.COLOR_WHITE;
    private const COLOR_WARNING = Graphics.COLOR_YELLOW;
    private const COLOR_ALERT   = Graphics.COLOR_RED;
    private const COLOR_GOOD    = Graphics.COLOR_GREEN;
    private const COLOR_DIM     = Graphics.COLOR_LT_GRAY;
    private const COLOR_RECOVERY = Graphics.COLOR_ORANGE;

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

    // Font measurement cache
    private var _fontCacheRowHeight as Number = -1;
    private var _fontCacheAllowNumber as Boolean = false;
    private var _fontCacheResult as Graphics.FontType = Graphics.FONT_XTINY;

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
        loadStrings();
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

    private function loadStrings() as Void {
        _strAppName = loadString(Rez.Strings.AppName, "FuelPlanner");
        _strWaiting = loadString(Rez.Strings.LabelWaiting, "Waiting for activity...");
        _strPaused = loadString(Rez.Strings.LabelPaused, "PAUSED");
        _strFuelNow = loadString(Rez.Strings.LabelFuelNow, "FUEL NOW");
        _strTapPrefix = loadString(Rez.Strings.LabelTapPrefix, "Tap");
        _strNext = loadString(Rez.Strings.LabelNext, "Next");
        _strBehind = loadString(Rez.Strings.LabelBehind, "Behind");
        _strAhead = loadString(Rez.Strings.LabelAhead, "Ahead");
        _strOnTarget = loadString(Rez.Strings.LabelOnTarget, "On target");
        _strRateTargetPrefix = loadString(Rez.Strings.LabelRateTargetPrefix, "Plan");
        _strRateAutoCarbsSuffix = loadString(Rez.Strings.LabelRateAutoCarbsSuffix, "% carbs");
        _strRateAutoNoData = loadString(Rez.Strings.LabelRateAutoNoData, "Auto (no cal data)");
        _strAutoFlowStatus = loadString(Rez.Strings.LabelAutoFlowStatus, "AUTO-FLOW");
        _strRecovery = loadString(Rez.Strings.LabelRecovery, "Recovery");
        _strRecoveryAction = loadString(Rez.Strings.LabelRecoveryAction, "Refuel");
        _strFuelingOk = loadString(Rez.Strings.LabelFuelingOk, "Fueling OK");
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
        var titleH = dc.getTextDimensions(_strFuelNow, titleFont)[1];
        var doseH = dc.getTextDimensions(doseText, doseFont)[1];
        var totalHeight = titleH + gap + doseH;
        var y = (h - totalHeight) / 2;
        if (y < 0) {
            y = 0;
        }

        // Text zentriert ausgeben
        dc.drawText(w / 2, y, titleFont, _strFuelNow, Graphics.TEXT_JUSTIFY_CENTER);
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
                    _strAppName,
                    Graphics.TEXT_JUSTIFY_CENTER);
        dc.setColor(dimColor, Graphics.COLOR_TRANSPARENT);
        dc.drawText(cx, h / 2 + h / 20, Graphics.FONT_TINY,
                    _strWaiting,
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
        var titleText = showRecoveryHint ? _strRecovery : _strFuelingOk;
        var valueText = "";
        var noteText = "";
        if (showRecoveryHint && recoveryDeficit != null) {
            valueText = "+" + recoveryDeficit.format("%d") + UNIT_G;
            noteText = _strRecoveryAction;
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

    //! Main layout rendered as a vertical flow from top to bottom.
    private function drawMainLayout(dc as Dc, w as Number, h as Number,
                                    cx as Number, textColor as Number,
                                    dimColor as Number, touchEnabled as Boolean) as Void {
        var isReminderDue = _model.isReminderDue();
        var nextDueSec    = _model.getDisplayNextDueInSec();
        var isPaused      = _model.isPaused();
        var doseG         = _model.getDoseG();
        var doseG10       = _model.getDoseG10();

        var showHint  = (touchEnabled && h >= 140);
        var showMeta  = (h >= 115);
        var showLabel = (h >= 90);
        var drawLabel = showLabel;
        var drawMeta  = showMeta;
        var drawHint  = showHint;

        var gap = getRowGap(h);
        var safeTop = getSafeTopInset(h);
        var safeBottom = getSafeBottomInset(w, h, touchEnabled);
        var baseRows = 3;
        if (drawLabel) { baseRows += 1; }
        if (drawMeta) { baseRows += 1; }
        if (drawHint) { baseRows += 1; }

        var rowHeight = h - safeTop - safeBottom - ((baseRows - 1) * gap);
        if (rowHeight < baseRows) {
            rowHeight = baseRows;
        }
        rowHeight = rowHeight / baseRows;

        var fontStatus = getBestFontForHeight(dc, rowHeight, false);
        var fontNumber = getBestFontForHeight(dc, (rowHeight.toFloat() * 1.55f).toNumber(), true);
        var fontUnit   = getBestFontForHeight(dc, (rowHeight.toFloat() * 0.75f).toNumber(), false);
        var fontLabel  = getBestFontForHeight(dc, (rowHeight.toFloat() * 0.65f).toNumber(), false);
        var fontMeta   = getBestFontForHeight(dc, (rowHeight.toFloat() * 0.7f).toNumber(), false);
        var fontHint   = getBestFontForHeight(dc, (rowHeight.toFloat() * 0.65f).toNumber(), false);

        // Row 1: status
        var statusText;
        var statusColor;
        if (isPaused) {
            statusText  = _strPaused;
            statusColor = COLOR_WARNING;
        } else if (isReminderDue) {
            if (touchEnabled) {
                statusText = _blinkState
                    ? _strFuelNow
                    : _strTapPrefix + doseG + UNIT_G;
            } else {
                statusText = _strAutoFlowStatus;
            }
            statusColor = COLOR_ALERT;
        } else {
            statusText  = _strNext + " " + formatDuration(nextDueSec);
            if (nextDueSec < 60) {
                statusColor = COLOR_ALERT;
            } else if (nextDueSec < 180) {
                statusColor = COLOR_WARNING;
            } else {
                statusColor = COLOR_GOOD;
            }
        }

        // Row 2: consumed / target number
        var consumedG10 = _model.getConsumedTotalG10();
        var targetG10   = _model.getTargetTotalG10();
        var consumedG   = (consumedG10 + 5) / 10;
        var targetG     = (targetG10 + 5) / 10;
        var numStr      = consumedG.format("%d") + "/" + targetG.format("%d");
        var numDims  = dc.getTextDimensions(numStr, fontNumber);
        var unitDims = dc.getTextDimensions(UNIT_G, fontUnit);
        var unitGap  = getUnitGap(w);
        var totalW   = numDims[0] + unitGap + unitDims[0];
        var numX     = cx - totalW / 2;

        // Row 3: target rate label
        var rateLabel = "";
        if (showLabel) {
            rateLabel = buildRateLabel();
        }

        // Row 4: deficit/ahead
        var deficitG10 = _model.getDeficitG10();
        var deficitText;
        var deficitColor;
        if (deficitG10 > 5) {
            var behindG = (deficitG10 + 5) / 10;
            deficitText  = _strBehind + " " + behindG.format("%d") + UNIT_G;
            deficitColor = (deficitG10 > doseG10) ? COLOR_ALERT : COLOR_WARNING;
        } else if (deficitG10 < -5) {
            var aheadG = ((-deficitG10) + 5) / 10;
            deficitText  = _strAhead + " " + aheadG.format("%d") + UNIT_G;
            deficitColor = COLOR_GOOD;
        } else {
            deficitText  = _strOnTarget;
            deficitColor = COLOR_GOOD;
        }

        drawDeficitGauge(dc, w, h, deficitG10, doseG10, dimColor, touchEnabled);

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
            timeText += SEP_PIPE + intakeCount.format("%d") + "x";
        }

        // Row 6: interaction hint
        var hintText = "";
        if (drawHint) {
            hintText = _strTapPrefix + doseG + UNIT_G;
        }

        // Pre-measure row heights for flow layout and overflow handling.
        var statusH  = dc.getTextDimensions(statusText, fontStatus)[1];
        var numberH  = numDims[1];
        if (unitDims[1] > numberH) { numberH = unitDims[1]; }
        var labelH   = drawLabel ? dc.getTextDimensions(rateLabel, fontLabel)[1] : 0;
        var deficitH = dc.getTextDimensions(deficitText, fontUnit)[1];
        var metaH    = drawMeta ? dc.getTextDimensions(timeText, fontMeta)[1] : 0;
        var hintH    = (drawHint && hintText != "") ? dc.getTextDimensions(hintText, fontHint)[1] : 0;

        if (drawHint && hintText != "" && w == h) {
            var hintWidth = dc.getTextDimensions(hintText, fontHint)[0];
            var roundHintSafeBottom = getRoundHintBottomInset(w, h, hintWidth, hintH);
            if (roundHintSafeBottom > safeBottom) {
                safeBottom = roundHintSafeBottom;
            }
        }
        var availableHeight = h - safeTop - safeBottom;
        if (availableHeight < 0) { availableHeight = 0; }

        // If it does not fit, progressively hide optional rows from bottom.
        var flowGap   = gap;
        while (true) {
            var requiredHeight = getRequiredMainHeight(
                statusH,
                numberH,
                drawLabel ? labelH : 0,
                deficitH,
                drawMeta ? metaH : 0,
                drawHint ? hintH : 0,
                flowGap
            );
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
        dc.drawText(numX, y, fontNumber, numStr, Graphics.TEXT_JUSTIFY_LEFT);
        dc.drawText(numX + numDims[0] + unitGap, unitY, fontUnit, UNIT_G, Graphics.TEXT_JUSTIFY_LEFT);
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

        if (drawHint && hintText != "") {
            dc.setColor(dimColor, Graphics.COLOR_TRANSPARENT);
            dc.drawText(cx, y, fontHint, hintText, Graphics.TEXT_JUSTIFY_CENTER);
        }
    }

//! Draw responsive edge gauges on both sides: green when on/ahead, red proportional to deficit.
//! Balken füllen sich von unten nach oben: 
//! Oben Grün (Plan), unten Orange/Rot (Defizit), bündig am Displayrand.
private function drawDeficitGauge(dc as Dc, w as Number, h as Number, 
                                  deficitG10 as Number, doseG10 as Number, 
                                  dimColor as Number, touchEnabled as Boolean) as Void {
    if (w < 150 || h < 110) {
        return;
    }
    
    // 1. Breite der Balken
    var gaugeW = (w * GAUGE_WIDTH_RATIO).toNumber();
    if (gaugeW < GAUGE_MIN_W_PX) { gaugeW = GAUGE_MIN_W_PX; }
    else if (gaugeW > GAUGE_MAX_W_PX) { gaugeW = GAUGE_MAX_W_PX; }

    // 2. Vertikaler Bereich (Safe Inset beachten)
    var top = getSafeTopInset(h);
    var bottomInset = getSafeBottomInset(w, h, touchEnabled);
    var gaugeH = h - top - bottomInset;

    if (gaugeH < GAUGE_MIN_H_PX) { return; }

    // 3. X-Positionen OHNE Randabstand (direkt am Displayrand)
    var xLeft = 0;
    var xRight = w - gaugeW;
    var y = top;

    // --- Logik für Farben und Höhen ---
    var ratio = 0.0f;
    if (doseG10 > 0) {
        // Berechnet wie viel % der Portion aktuell fehlen
        ratio = deficitG10.toFloat() / doseG10.toFloat();
    }
    
    // Begrenzung auf 0 bis 100% der Balkenhöhe
    if (ratio < 0.0f) { ratio = 0.0f; }
    if (ratio > 1.0f) { ratio = 1.0f; }

    var redH = (gaugeH.toFloat() * ratio).toNumber();
    var greenH = gaugeH - redH;
    
    // FARB-LOGIK: 
    // Wir fangen bei Orange an, sobald ein Defizit da ist.
    var alertColor = Graphics.COLOR_ORANGE; 
    
    // Wenn wir "ganz hinten" sind (Defizit > Alarm-Schwelle) -> ROT
    if (deficitG10 >= GAUGE_ALERT_G10) {
        alertColor = Graphics.COLOR_RED;
    } 

    // --- Zeichnen ---
    
    // 1. Hintergrund (Hohlraum/Track)
    dc.setColor(dimColor, Graphics.COLOR_TRANSPARENT);
    dc.fillRectangle(xLeft, y, gaugeW, gaugeH);
    dc.fillRectangle(xRight, y, gaugeW, gaugeH);

    // 2. Grüner Bereich (Oberer Teil - steht für "im Plan")
    if (greenH > 0) {
        dc.setColor(COLOR_GOOD, Graphics.COLOR_TRANSPARENT);
        dc.fillRectangle(xLeft, y, gaugeW, greenH);
        dc.fillRectangle(xRight, y, gaugeW, greenH);
    }

    // 3. Warn Bereich (Unterer Teil - füllt sich bei Defizit auf)
    if (redH > 0) {
        dc.setColor(alertColor, Graphics.COLOR_TRANSPARENT);
        dc.fillRectangle(xLeft, y + greenH, gaugeW, redH);
        dc.fillRectangle(xRight, y + greenH, gaugeW, redH);
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

    //! Select best fitting font for a target row height.
    //! If `allowNumber` is true, `FONT_NUMBER_MILD` is also considered.
    private function getBestFontForHeight(dc as Dc, rowHeight as Number,
                                          allowNumber as Boolean) {
        var target = rowHeight;
        if (target < 1) {
            target = 1;
        }

        // Cache: gleiche Höhe und allowNumber = kein erneutes Messen
        if (target == _fontCacheRowHeight && allowNumber == _fontCacheAllowNumber) {
            return _fontCacheResult;
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

        // Cache aktualisieren
        _fontCacheRowHeight = target;
        _fontCacheAllowNumber = allowNumber;
        _fontCacheResult = bestFont;

        return bestFont;
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

        // Math.sqrt() ist in Connect IQ 3.0+ verfügbar
        var radicand = (radius * radius) - (halfText * halfText);
        var dMax = 0.0f;
        if (radicand > 0.0f) {
            dMax = Math.sqrt(radicand);
        }
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
                       _strRateAutoCarbsSuffix;
            }
            return _strRateAutoNoData;
        }
        return _strRateTargetPrefix + " " + _model.getCarbsTargetGph().format("%d") + UNIT_GPH;
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
