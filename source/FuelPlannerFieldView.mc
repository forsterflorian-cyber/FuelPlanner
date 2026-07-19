import Toybox.Activity;
import Toybox.Graphics;
import Toybox.WatchUi;
import Toybox.System;
import Toybox.Lang;
import FuelPlannerLog;
import FuelReminderModes;
//! Data Field View for FuelPlanner - responsive, top-to-bottom layout
class FuelPlannerFieldView extends WatchUi.DataField {

    private var _model as FuelModel;
    private var _reminder as ReminderManager;
    private var _showRecoveryLayout as Boolean = false;

    // Theme-aware foreground colors. The light-background warning uses a
    // darker amber because COLOR_YELLOW and COLOR_ORANGE wash out on white.
    private const COLOR_NORMAL            = Graphics.COLOR_WHITE;
    private const COLOR_WARNING_DARK_BG   = Graphics.COLOR_YELLOW;
    private const COLOR_WARNING_LIGHT_BG  = 0xAA5500;
    private const COLOR_ALERT_DARK_BG     = Graphics.COLOR_RED;
    private const COLOR_ALERT_LIGHT_BG    = Graphics.COLOR_DK_RED;
    private const COLOR_GOOD_DARK_BG      = Graphics.COLOR_GREEN;
    private const COLOR_GOOD_LIGHT_BG     = Graphics.COLOR_DK_GREEN;
    private const COLOR_DIM               = Graphics.COLOR_LT_GRAY;
    private const COLOR_RECOVERY = Graphics.COLOR_ORANGE;

    // Vertical flow layout constants
    private const SAFE_TOP_PX = 16;
    private const SAFE_BOTTOM_PX = 24;
    private const ROW_GAP_PX = 6;

    // Outer ring constants
    private const RING_STROKE_RATIO = 0.045f;
    private const RING_STROKE_MIN_PX = 8;
    private const RING_STROKE_MAX_PX = 18;
    private const RING_PADDING_MIN_PX = 4;
    private const RING_PADDING_MAX_PX = 12;
    private const ROUND_EDGE_PADDING_PX = 8;

    // Last known field size (for tap zone mapping in multi-field layouts)
    private var _lastFieldWidth as Number = 0;
    private var _lastFieldHeight as Number = 0;
    private const DEFAULT_SCREEN_HEIGHT = 240;
    private const DEFAULT_SCREEN_WIDTH = 240;
    private const UNIT_G = "g";
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
    private const COMPACT_MAX_WIDTH_PX = 180;
    private const COMPACT_MAX_HEIGHT_PX = 150;
    private const COMPACT_SHORT_HEIGHT_PX = 78;

    // Timed overlays
    private var _overlayEndTime as Number = 0;
    private var _autoConfirmationEndTime as Number = 0;
    private const OVERLAY_DURATION_MS = 3000;
    private const AUTO_CONFIRMATION_DURATION_MS = 1500;

    // Strings used in the once-per-second draw path are loaded once. This
    // avoids repeated resource lookups without adding a dictionary in memory.
    private var _labelAppName as String = "FuelPlanner";
    private var _labelPaused as String = "PAUSED";
    private var _labelFuelNow as String = "FUEL NOW";
    private var _labelFuelShort as String = "FUEL";
    private var _labelNext as String = "Next";
    private var _labelAutoFlow as String = "AUTO-FLOW";
    private var _labelBehind as String = "Behind";
    private var _labelAhead as String = "Ahead";
    private var _labelOnTarget as String = "On target";
    private var _labelRateTarget as String = "Plan";
    private var _labelRateAutoSuffix as String = "% carbs";
    private var _labelRateAutoNoData as String = "Auto (no cal data)";
    private var _unitGramsPerHour as String = "g/h";
    private var _labelWaiting as String = "Start activity to begin";
    private var _labelWaitStartCompact as String = "WAIT / START";
    private var _labelStarting as String = "STARTING";
    private var _labelWaitingForTimer as String = "Waiting for timer data";
    private var _labelTimerStale as String = "TIMER STALE";
    private var _labelNoTimerCompact as String = "NO TIMER";

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
        loadDrawStrings();
    }

    function onLayout(dc as Dc) as Void {
        _lastFieldWidth = dc.getWidth();
        _lastFieldHeight = dc.getHeight();
    }


    function onTimerLap() as Void {
        _model.onTimerLap();
    }

    function onTimerStart() as Void {
        dismissOverlay();
        _model.onTimerStart();
        WatchUi.requestUpdate();
    }

    function onTimerStop() as Void {
        dismissOverlay();
        _model.onTimerStop();
        WatchUi.requestUpdate();
    }

    function onTimerPause() as Void {
        dismissOverlay();
        _model.onTimerPause();
        WatchUi.requestUpdate();
    }

    function onTimerResume() as Void {
        dismissOverlay();
        _model.onTimerResume();
        WatchUi.requestUpdate();
    }

    function onTimerReset() as Void {
        dismissOverlay();
        _model.onTimerReset();
        _showRecoveryLayout = _model.isStoppedSession();
        WatchUi.requestUpdate();
    }

    function dismissOverlay() as Void {
        _overlayEndTime = 0;
        _autoConfirmationEndTime = 0;
    }

    function isReminderOverlayActive() as Boolean {
        return _overlayEndTime > System.getTimer();
    }

    //! Called every second with activity info
    function compute(info as Activity.Info) as Void {
        _model.compute(info);
        _showRecoveryLayout = _model.isStoppedSession();

        var autoIntakeTriggered = _model.consumeAutoIntakeEvent();
        if (_showRecoveryLayout) {
            _overlayEndTime = 0;
            _autoConfirmationEndTime = 0;
        } else if (autoIntakeTriggered) {
            _overlayEndTime = 0;
            _autoConfirmationEndTime = System.getTimer() + AUTO_CONFIRMATION_DURATION_MS;
            _reminder.triggerAutoIntake();
        }

        // Overlay bei Pause sofort ausblenden
        if (_model.isPaused()) {
            _overlayEndTime = 0;
            _autoConfirmationEndTime = 0;
        }

        if (!_showRecoveryLayout && _model.isReminderDue() && !_model.isPaused()) {
            if (_reminder.triggerReminder()) { // Liefert true, wenn der Alarm gerade ausgelöst wurde
                _model.recordReminderTriggered();
                presentReminderNotification();
            }
        }
    }

    function onUpdate(dc as Dc) as Void {
        var bgColor = getBackgroundColor();
        var now = System.getTimer();
        var w  = dc.getWidth();
        var h  = dc.getHeight();
        _showRecoveryLayout = _model.isStoppedSession();
        _lastFieldWidth = w;
        _lastFieldHeight = h;
        dc.setColor(Graphics.COLOR_TRANSPARENT, bgColor);
        dc.clear();
        // Reminder wins if both events arrive in the same update.
        if (now < _overlayEndTime) {
            drawReminderOverlay(dc);
            return;
        }
        if (now < _autoConfirmationEndTime) {
            drawAutoIntakeConfirmation(dc);
            return;
        }
        var cx = w / 2;

        var isDark    = (bgColor == Graphics.COLOR_BLACK);
        var textColor = isDark ? COLOR_NORMAL : Graphics.COLOR_BLACK;
        var dimColor  = isDark ? COLOR_DIM    : Graphics.COLOR_DK_GRAY;

        var touchEnabled = _model.isTouchInputEnabled();
        var compactLayout = isCompactFieldLayout(w, h);

        if (_showRecoveryLayout) {
            if (compactLayout) {
                drawCompactRecoveryLayout(dc, w, h, cx);
                return;
            }
            drawRecoveryLayout(dc, w, h, cx);
            return;
        }

        if (!_model.isSessionActive()) {
            if (compactLayout) {
                drawCompactNoSession(dc, w, h, cx, textColor, dimColor);
                return;
            }
            drawNoSession(dc, cx, h, textColor, dimColor);
            return;
        }

        if (_model.isPriming()) {
            drawActivityDataState(dc, w, h, cx, textColor, dimColor,
                                  _labelStarting, _labelWaitingForTimer,
                                  _labelStarting);
            return;
        }

        if (!_model.hasValidTimerData()) {
            drawActivityDataState(dc, w, h, cx, textColor, dimColor,
                                  _labelTimerStale, _labelWaitingForTimer,
                                  _labelNoTimerCompact);
            return;
        }

        if (compactLayout) {
            drawCompactMainLayout(dc, w, h, cx, textColor, dimColor,
                                  touchEnabled, isDark);
            return;
        }
        drawMainLayout(dc, w, h, cx, textColor, dimColor, touchEnabled, isDark);
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

    private function isCompactFieldLayout(w as Number, h as Number) as Boolean {
        if (w <= COMPACT_MAX_WIDTH_PX || h <= COMPACT_MAX_HEIGHT_PX) {
            return true;
        }
        return w < 240 && h < 190;
    }


    //! Draw a reminder that adapts down to single-row data fields.
    private function drawReminderOverlay(dc as Dc) as Void {
        var w = dc.getWidth();
        var h = dc.getHeight();
        var contentInset = getScaledValue(w, 0.08f, 12, 30);
        var contentW = w - (contentInset * 2);
        if (contentW < 40) {
            contentW = 40;
            contentInset = (w - contentW) / 2;
        }

        dc.setColor(Graphics.COLOR_RED, Graphics.COLOR_RED);
        dc.fillRectangle(0, 0, w, h);
        dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_TRANSPARENT);

        var doseText = _model.getDoseG().format("%d") + UNIT_G;
        if (isCompactFieldLayout(w, h)) {
            drawCompactReminderContent(dc, w, h, contentW, doseText);
            drawOverlayFrame(dc, w, h, 2);
            return;
        }

        var reasonText = buildReminderReasonText();
        var titleFont = getBestFontForBox(dc, _labelFuelNow, contentW, getScaledValue(h, 0.20f, 24, 56), false);
        var doseFont = getBestFontForBox(dc, doseText, contentW, getScaledValue(h, 0.14f, 18, 40), true);
        var reasonFont = getBestFontForBox(dc, reasonText, contentW, getScaledValue(h, 0.09f, 12, 22), false);
        var gap = getRowGap(h);
        var titleH = Graphics.getFontHeight(titleFont);
        var doseH = Graphics.getFontHeight(doseFont);
        var reasonH = Graphics.getFontHeight(reasonFont);
        var totalHeight = titleH + gap + doseH + gap + reasonH;
        var y = (h - totalHeight) / 2;
        if (y < 0) {
            y = 0;
        }

        dc.drawText(w / 2, y, titleFont, _labelFuelNow, Graphics.TEXT_JUSTIFY_CENTER);
        dc.drawText(w / 2, y + titleH + gap, doseFont, doseText, Graphics.TEXT_JUSTIFY_CENTER);
        dc.drawText(w / 2, y + titleH + gap + doseH + gap, reasonFont, reasonText, Graphics.TEXT_JUSTIFY_CENTER);

        drawOverlayFrame(dc, w, h, 4);
    }

    private function drawCompactReminderContent(dc as Dc, w as Number, h as Number,
                                                contentW as Number, doseText as String) as Void {
        if (h < COMPACT_SHORT_HEIGHT_PX) {
            var summaryText = _labelFuelShort + " +" + doseText;
            var summaryFont = getBestFontForBox(dc, summaryText, contentW, h - 4, false);
            var summaryH = Graphics.getFontHeight(summaryFont);
            dc.drawText(w / 2, (h - summaryH) / 2, summaryFont, summaryText,
                        Graphics.TEXT_JUSTIFY_CENTER);
            return;
        }

        var showReason = h >= 120;
        var reasonText = showReason ? buildReminderReasonText() : "";
        var titleFont = getBestFontForBox(dc, _labelFuelShort, contentW,
                                          getScaledValue(h, 0.23f, 12, 30), false);
        var doseFont = getBestFontForBox(dc, doseText, contentW,
                                         getScaledValue(h, 0.34f, 18, 42), true);
        var reasonFont = getBestFontForBox(dc, reasonText, contentW,
                                           getScaledValue(h, 0.16f, 10, 20), false);
        var gap = getCompactRowGap(h);
        var titleH = Graphics.getFontHeight(titleFont);
        var doseH = Graphics.getFontHeight(doseFont);
        var reasonH = showReason ? Graphics.getFontHeight(reasonFont) : 0;
        var totalHeight = titleH + gap + doseH;
        if (showReason) {
            totalHeight += gap + reasonH;
        }
        var y = (h - totalHeight) / 2;
        if (y < 1) { y = 1; }

        dc.drawText(w / 2, y, titleFont, _labelFuelShort, Graphics.TEXT_JUSTIFY_CENTER);
        y += titleH + gap;
        dc.drawText(w / 2, y, doseFont, doseText, Graphics.TEXT_JUSTIFY_CENTER);
        if (showReason) {
            dc.drawText(w / 2, y + doseH + gap, reasonFont, reasonText,
                        Graphics.TEXT_JUSTIFY_CENTER);
        }
    }

    private function drawOverlayFrame(dc as Dc, w as Number, h as Number,
                                      penWidth as Number) as Void {
        if (w <= 4 || h <= 4) {
            return;
        }
        dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_TRANSPARENT);
        dc.setPenWidth(penWidth);
        dc.drawRectangle(2, 2, w - 4, h - 4);
    }

    private function drawAutoIntakeConfirmation(dc as Dc) as Void {
        var w = dc.getWidth();
        var h = dc.getHeight();
        var contentW = getCompactContentWidth(w);
        var doseText = "+" + _model.getDoseG().format("%d") + UNIT_G;

        dc.setColor(Graphics.COLOR_GREEN, Graphics.COLOR_GREEN);
        dc.fillRectangle(0, 0, w, h);
        dc.setColor(Graphics.COLOR_BLACK, Graphics.COLOR_TRANSPARENT);

        if (h < COMPACT_SHORT_HEIGHT_PX) {
            var summaryText = "AUTO " + doseText;
            var summaryFont = getBestFontForBox(dc, summaryText, contentW, h - 2, false);
            var summaryH = Graphics.getFontHeight(summaryFont);
            dc.drawText(w / 2, (h - summaryH) / 2, summaryFont, summaryText,
                        Graphics.TEXT_JUSTIFY_CENTER);
            return;
        }

        var titleFont = getBestFontForBox(dc, _labelAutoFlow, contentW,
                                          getScaledValue(h, 0.24f, 12, 32), false);
        var doseFont = getBestFontForBox(dc, doseText, contentW,
                                         getScaledValue(h, 0.34f, 18, 46), true);
        var titleH = Graphics.getFontHeight(titleFont);
        var doseH = Graphics.getFontHeight(doseFont);
        var gap = getCompactRowGap(h);
        var y = (h - titleH - gap - doseH) / 2;
        if (y < 0) { y = 0; }

        dc.drawText(w / 2, y, titleFont, _labelAutoFlow, Graphics.TEXT_JUSTIFY_CENTER);
        dc.drawText(w / 2, y + titleH + gap, doseFont, doseText,
                    Graphics.TEXT_JUSTIFY_CENTER);
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

        var titleText = _labelFuelNow;
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
        drawFullDataState(dc, cx, h, textColor, dimColor, _labelAppName, _labelWaiting);
    }

    private function drawFullDataState(dc as Dc, cx as Number, h as Number,
                                       textColor as Number, dimColor as Number,
                                       titleText as String, noteText as String) as Void {
        var w = dc.getWidth();
        var sideInset = getContentSideInset(w);
        var contentW = w - (sideInset * 2);
        var titleFont = getBestFontForBox(dc, titleText, contentW, getScaledValue(h, 0.18f, 20, 42), false);
        var noteFont = getBestFontForBox(dc, noteText, contentW, getScaledValue(h, 0.10f, 12, 24), false);
        var gap = getRowGap(h);
        var titleH = Graphics.getFontHeight(titleFont);
        var noteH = Graphics.getFontHeight(noteFont);
        var y = (h - (titleH + gap + noteH)) / 2;
        if (y < 0) {
            y = 0;
        }

        dc.setColor(textColor, Graphics.COLOR_TRANSPARENT);
        dc.drawText(cx, y, titleFont, titleText, Graphics.TEXT_JUSTIFY_CENTER);
        dc.setColor(dimColor, Graphics.COLOR_TRANSPARENT);
        dc.drawText(cx, y + titleH + gap, noteFont, noteText, Graphics.TEXT_JUSTIFY_CENTER);
    }

    private function drawCompactNoSession(dc as Dc, w as Number, h as Number,
                                          cx as Number, textColor as Number,
                                          dimColor as Number) as Void {
        drawCompactDataState(dc, w, h, cx, textColor, dimColor,
                             _labelAppName, _labelWaiting, _labelWaitStartCompact);
    }

    private function drawActivityDataState(dc as Dc, w as Number, h as Number,
                                           cx as Number, textColor as Number,
                                           dimColor as Number, titleText as String,
                                           noteText as String,
                                           shortTitleText as String) as Void {
        if (isCompactFieldLayout(w, h)) {
            drawCompactDataState(dc, w, h, cx, textColor, dimColor,
                                 titleText, noteText, shortTitleText);
            return;
        }
        drawFullDataState(dc, cx, h, textColor, dimColor, titleText, noteText);
    }

    private function drawCompactDataState(dc as Dc, w as Number, h as Number,
                                          cx as Number, textColor as Number,
                                          dimColor as Number, titleText as String,
                                          noteText as String,
                                          shortTitleText as String) as Void {
        var contentW = getCompactContentWidth(w);
        var showNote = h >= COMPACT_SHORT_HEIGHT_PX;
        if (!showNote) {
            titleText = shortTitleText;
        }
        var titleFont = getBestFontForBox(dc, titleText, contentW, getScaledValue(h, 0.38f, 12, 30), false);
        var noteFont = getBestFontForBox(dc, noteText, contentW, getScaledValue(h, 0.22f, 10, 18), false);
        var gap = getCompactRowGap(h);
        var titleH = Graphics.getFontHeight(titleFont);
        var noteH = showNote ? Graphics.getFontHeight(noteFont) : 0;
        var totalHeight = titleH + noteH;
        if (noteH > 0) {
            totalHeight += gap;
        }
        var y = (h - totalHeight) / 2;
        if (y < 0) { y = 0; }

        dc.setColor(textColor, Graphics.COLOR_TRANSPARENT);
        dc.drawText(cx, y, titleFont, titleText, Graphics.TEXT_JUSTIFY_CENTER);

        if (noteH > 0) {
            dc.setColor(dimColor, Graphics.COLOR_TRANSPARENT);
            dc.drawText(cx, y + titleH + gap, noteFont, noteText, Graphics.TEXT_JUSTIFY_CENTER);
        }
    }

    private function drawRecoveryLayout(dc as Dc, w as Number, h as Number,
                                        cx as Number) as Void {
        var recoveryDeficit = _model.getRecoveryDeficit();
        var showRecoveryHint = false;
        if (recoveryDeficit != null) {
            showRecoveryHint = recoveryDeficit > RECOVERY_MIN_G;
        }
        var panelColor = showRecoveryHint ? COLOR_RECOVERY : COLOR_GOOD_DARK_BG;
        var titleText = showRecoveryHint ? FuelPlannerUtils.loadString(Rez.Strings.LabelRecovery, "Recovery") : FuelPlannerUtils.loadString(Rez.Strings.LabelFuelingOk, "Fueling OK");
        var valueText = "";
        var noteText = "";
        if (showRecoveryHint && recoveryDeficit != null) {
            valueText = "+" + recoveryDeficit.format("%d") + UNIT_G;
            noteText = FuelPlannerUtils.loadString(Rez.Strings.LabelRecoveryAction, "Refuel");
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

        var titleH = Graphics.getFontHeight(titleFont);
        var valueH = (valueText != "") ? Graphics.getFontHeight(valueFont) : 0;
        var noteH  = (noteText != "") ? Graphics.getFontHeight(noteFont) : 0;
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

    private function drawCompactRecoveryLayout(dc as Dc, w as Number, h as Number,
                                               cx as Number) as Void {
        var recoveryDeficit = _model.getRecoveryDeficit();
        var showRecoveryHint = false;
        if (recoveryDeficit != null) {
            showRecoveryHint = recoveryDeficit > RECOVERY_MIN_G;
        }
        var panelColor = showRecoveryHint ? COLOR_RECOVERY : COLOR_GOOD_DARK_BG;
        var titleText = showRecoveryHint ? FuelPlannerUtils.loadString(Rez.Strings.LabelRecovery, "Recovery") : "OK";
        var valueText = "";
        if (showRecoveryHint && recoveryDeficit != null) {
            valueText = "+" + recoveryDeficit.format("%d") + UNIT_G;
        }

        dc.setColor(panelColor, panelColor);
        dc.fillRectangle(0, 0, w, h);

        var contentW = getCompactContentWidth(w);
        var titleFont = getBestFontForBox(dc, titleText, contentW, getScaledValue(h, 0.30f, 12, 28), false);
        var valueFont = getBestFontForBox(dc, valueText, contentW, getScaledValue(h, 0.42f, 16, 40), true);
        var gap = getCompactRowGap(h);
        var titleH = Graphics.getFontHeight(titleFont);
        var valueH = (valueText != "") ? Graphics.getFontHeight(valueFont) : 0;
        var totalHeight = titleH + valueH;
        if (valueH > 0) {
            totalHeight += gap;
        }
        var y = (h - totalHeight) / 2;
        if (y < 0) { y = 0; }

        dc.setColor(Graphics.COLOR_BLACK, Graphics.COLOR_TRANSPARENT);
        dc.drawText(cx, y, titleFont, titleText, Graphics.TEXT_JUSTIFY_CENTER);

        if (valueText != "") {
            dc.drawText(cx, y + titleH + gap, valueFont, valueText, Graphics.TEXT_JUSTIFY_CENTER);
        }
    }

    //! Main layout - simplified for memory optimization
    private function drawMainLayout(dc as Dc, w as Number, h as Number,
                                    cx as Number, textColor as Number,
                                    dimColor as Number, touchEnabled as Boolean,
                                    isDark as Boolean) as Void {
        var sideInset = getContentSideInset(w);
        var contentW = w - (sideInset * 2);
        if (contentW < 40) {
            contentW = 40;
            sideInset = (w - contentW) / 2;
        }
        var contentTop = getContentTopInset(h);
        var contentBottom = h - getContentBottomInset(h);
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
            statusText = _labelPaused;
            statusColor = getWarningColor(isDark);
        } else if (_model.isReminderDue()) {
            statusText = touchEnabled ? _labelFuelNow : _labelAutoFlow;
            statusColor = getAlertColor(isDark);
        } else {
            statusText = _labelNext + " " + formatDuration(_model.getDisplayNextDueInSec());
            statusColor = getGoodColor(isDark);
        }

        // Numbers row
        var consumedG = (_model.getConsumedTotalG10() + 5) / 10;
        var targetG = (_model.getTargetTotalG10() + 5) / 10;
        var numStr = consumedG.format("%d") + "/" + targetG.format("%d");

        // Deficit row
        var deficitG10 = _model.getDeficitG10();
        var deficitText = buildDeficitTextFromG10(deficitG10);
        var deficitColor;
        if (deficitG10 > 5) {
            deficitColor = getWarningColor(isDark);
        } else if (deficitG10 < -5) {
            deficitColor = getGoodColor(isDark);
        } else {
            deficitColor = getGoodColor(isDark);
        }

        // Time row
        var elapsedMin = _model.getElapsedActiveSec() / 60;
        var timeText = (elapsedMin / 60).format("%d") + "h" + (elapsedMin % 60).format("%02d") + SEP_PIPE + _model.getIntakeCount().format("%d") + "x";
        var rateText = buildRateLabel();
        var showRateRow = contentH >= 150;

        // Keep the typography inside a centered inner column so the perimeter
        // ring remains readable without crowding the text.
        var maxRowH = (contentH.toFloat() * STATUS_ROW_RATIO).toNumber();
        if (maxRowH < 14) { maxRowH = 14; }
        if (maxRowH > 32) { maxRowH = 32; }
        var statusFont = getBestFontForBox(dc, statusText, contentW, maxRowH, false);
        maxRowH = (contentH.toFloat() * PRIMARY_ROW_RATIO).toNumber();
        if (maxRowH < 24) { maxRowH = 24; }
        if (maxRowH > 60) { maxRowH = 60; }
        var primaryFont = getBestFontForBox(dc, numStr, contentW, maxRowH, true);
        maxRowH = (contentH.toFloat() * DEFICIT_ROW_RATIO).toNumber();
        if (maxRowH < 14) { maxRowH = 14; }
        if (maxRowH > 28) { maxRowH = 28; }
        var deficitFont = getBestFontForBox(dc, deficitText, contentW, maxRowH, false);
        maxRowH = (contentH.toFloat() * META_ROW_RATIO).toNumber();
        if (maxRowH < 12) { maxRowH = 12; }
        if (maxRowH > 22) { maxRowH = 22; }
        var metaFont = getBestFontForBox(dc, timeText, contentW, maxRowH, false);
        maxRowH = (contentH.toFloat() * RATE_ROW_RATIO).toNumber();
        if (maxRowH < 12) { maxRowH = 12; }
        if (maxRowH > 20) { maxRowH = 20; }
        var rateFont = getBestFontForBox(dc, rateText, contentW, maxRowH, false);

        var statusH = Graphics.getFontHeight(statusFont);
        var primaryH = Graphics.getFontHeight(primaryFont);
        var deficitH = Graphics.getFontHeight(deficitFont);
        var metaH = Graphics.getFontHeight(metaFont);
        var rateH = showRateRow ? Graphics.getFontHeight(rateFont) : 0;

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

        // Keep this inline: Connect IQ data fields have a shallow call stack,
        // and the ring is already reached through onUpdate -> drawMainLayout.
        var ringDiameter = (w < h) ? w : h;
        if (ringDiameter >= 96) {
            var ringStroke = (ringDiameter.toFloat() * RING_STROKE_RATIO).toNumber();
            if (ringStroke < RING_STROKE_MIN_PX) { ringStroke = RING_STROKE_MIN_PX; }
            if (ringStroke > RING_STROKE_MAX_PX) { ringStroke = RING_STROKE_MAX_PX; }
            var ringPadding = (ringDiameter.toFloat() * 0.02f).toNumber();
            if (ringPadding < RING_PADDING_MIN_PX) { ringPadding = RING_PADDING_MIN_PX; }
            if (ringPadding > RING_PADDING_MAX_PX) { ringPadding = RING_PADDING_MAX_PX; }
            var ringRadius = (ringDiameter / 2) - ringPadding - (ringStroke / 2);
            if (ringRadius > 0) {
                var tone = _model.getRingTone();
                var ringColor = isDark ? COLOR_GOOD_DARK_BG : COLOR_GOOD_LIGHT_BG;
                if (tone >= 2) {
                    ringColor = isDark ? COLOR_ALERT_DARK_BG : COLOR_ALERT_LIGHT_BG;
                } else if (tone == 1) {
                    ringColor = isDark ? COLOR_WARNING_DARK_BG : COLOR_WARNING_LIGHT_BG;
                }
                dc.setPenWidth(ringStroke);
                dc.setColor(ringColor, Graphics.COLOR_TRANSPARENT);
                dc.drawCircle(w / 2, h / 2, ringRadius);
            }
        }
    }

    private function drawCompactMainLayout(dc as Dc, w as Number, h as Number,
                                           cx as Number, textColor as Number,
                                           dimColor as Number,
                                           touchEnabled as Boolean,
                                           isDark as Boolean) as Void {
        var contentW = getCompactContentWidth(w);
        var contentTop = (h.toFloat() * 0.06f).toNumber();
        if (contentTop < 2) { contentTop = 2; }
        if (contentTop > 8) { contentTop = 8; }
        var contentH = h - (contentTop * 2);
        if (contentH < 20) {
            contentH = h;
            contentTop = 0;
        }
        var gap = getCompactRowGap(h);

        var statusText = buildCompactStatusText(touchEnabled);
        var statusColor = getStatusColor(isDark);
        var numStr = buildTotalsText();
        var deficitG10 = _model.getDeficitG10();
        var deficitText = buildCompactDeficitTextFromG10(deficitG10);
        var deficitColor = getDeficitColor(deficitG10, isDark);

        var showStatus = true;
        var showDeficit = h >= COMPACT_SHORT_HEIGHT_PX;
        var maxRowH = (contentH.toFloat() * 0.22f).toNumber();
        if (maxRowH < 10) { maxRowH = 10; }
        if (maxRowH > 22) { maxRowH = 22; }
        var statusFont = getBestFontForBox(dc, statusText, contentW, maxRowH, false);
        maxRowH = (contentH.toFloat() * 0.48f).toNumber();
        if (maxRowH < 18) { maxRowH = 18; }
        if (maxRowH > 44) { maxRowH = 44; }
        var primaryFont = getBestFontForBox(dc, numStr, contentW, maxRowH, true);
        maxRowH = (contentH.toFloat() * 0.22f).toNumber();
        if (maxRowH < 10) { maxRowH = 10; }
        if (maxRowH > 20) { maxRowH = 20; }
        var deficitFont = getBestFontForBox(dc, deficitText, contentW, maxRowH, false);

        var statusH = Graphics.getFontHeight(statusFont);
        var primaryH = Graphics.getFontHeight(primaryFont);
        var deficitH = showDeficit ? Graphics.getFontHeight(deficitFont) : 0;
        var totalHeight = primaryH;
        if (showStatus) { totalHeight += statusH + gap; }
        if (showDeficit) { totalHeight += deficitH + gap; }

        if (totalHeight > contentH && showDeficit) {
            showDeficit = false;
            deficitH = 0;
            totalHeight = primaryH + statusH + gap;
        }
        if (totalHeight > contentH && showStatus && !_model.isPaused() && !_model.isReminderDue()) {
            showStatus = false;
            statusH = 0;
            totalHeight = primaryH;
        }

        var y = contentTop + ((contentH - totalHeight) / 2);
        if (y < contentTop) { y = contentTop; }

        if (showStatus) {
            dc.setColor(statusColor, Graphics.COLOR_TRANSPARENT);
            dc.drawText(cx, y, statusFont, statusText, Graphics.TEXT_JUSTIFY_CENTER);
            y += statusH + gap;
        }

        dc.setColor(textColor, Graphics.COLOR_TRANSPARENT);
        dc.drawText(cx, y, primaryFont, numStr, Graphics.TEXT_JUSTIFY_CENTER);

        if (showDeficit) {
            y += primaryH + gap;
            dc.setColor(deficitColor, Graphics.COLOR_TRANSPARENT);
            dc.drawText(cx, y, deficitFont, deficitText, Graphics.TEXT_JUSTIFY_CENTER);
        }
    }

    private function getRowGap(h as Number) as Number {
        var gap = (h.toFloat() * CONTENT_GAP_RATIO).toNumber();
        if (gap < ROW_GAP_PX) { return ROW_GAP_PX; }
        if (gap > 12) { return 12; }
        return gap;
    }

    private function getCompactRowGap(h as Number) as Number {
        var gap = (h.toFloat() * 0.025f).toNumber();
        if (gap < 2) { return 2; }
        if (gap > 6) { return 6; }
        return gap;
    }

    private function getCompactContentWidth(w as Number) as Number {
        var inset = (w.toFloat() * 0.05f).toNumber();
        if (inset < 4) { inset = 4; }
        if (inset > 12) { inset = 12; }
        var contentW = w - (inset * 2);
        if (contentW < 20) {
            return 20;
        }
        return contentW;
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

        var dims;
        if (allowNumber) {
            dims = dc.getTextDimensions(text, Graphics.FONT_NUMBER_MILD);
            if (dims[0] <= widthLimit && dims[1] <= heightLimit) {
                return Graphics.FONT_NUMBER_MILD;
            }
        }

        dims = dc.getTextDimensions(text, Graphics.FONT_MEDIUM);
        if (dims[0] <= widthLimit && dims[1] <= heightLimit) {
            return Graphics.FONT_MEDIUM;
        }

        dims = dc.getTextDimensions(text, Graphics.FONT_TINY);
        if (dims[0] <= widthLimit && dims[1] <= heightLimit) {
            return Graphics.FONT_TINY;
        }

        return Graphics.FONT_XTINY;
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

    private function getStatusColor(isDark as Boolean) as Number {
        if (_model.isPaused()) {
            return isDark ? COLOR_WARNING_DARK_BG : COLOR_WARNING_LIGHT_BG;
        }
        if (_model.isReminderDue()) {
            return isDark ? COLOR_ALERT_DARK_BG : COLOR_ALERT_LIGHT_BG;
        }
        return isDark ? COLOR_GOOD_DARK_BG : COLOR_GOOD_LIGHT_BG;
    }

    private function getDeficitColor(deficitG10 as Number,
                                     isDark as Boolean) as Number {
        if (deficitG10 > 5) {
            return isDark ? COLOR_WARNING_DARK_BG : COLOR_WARNING_LIGHT_BG;
        }
        return isDark ? COLOR_GOOD_DARK_BG : COLOR_GOOD_LIGHT_BG;
    }

    private function getWarningColor(isDark as Boolean) as Number {
        return isDark ? COLOR_WARNING_DARK_BG : COLOR_WARNING_LIGHT_BG;
    }

    private function getAlertColor(isDark as Boolean) as Number {
        return isDark ? COLOR_ALERT_DARK_BG : COLOR_ALERT_LIGHT_BG;
    }

    private function getGoodColor(isDark as Boolean) as Number {
        return isDark ? COLOR_GOOD_DARK_BG : COLOR_GOOD_LIGHT_BG;
    }

    private function getContentSideInset(w as Number) as Number {
        var inset = (w.toFloat() * CONTENT_SIDE_RATIO).toNumber();
        if (inset < CONTENT_MIN_SIDE_PX) { inset = CONTENT_MIN_SIDE_PX; }
        if (inset > 44) { inset = 44; }

        var ringStroke = (w.toFloat() * RING_STROKE_RATIO).toNumber();
        if (ringStroke < RING_STROKE_MIN_PX) { ringStroke = RING_STROKE_MIN_PX; }
        if (ringStroke > RING_STROKE_MAX_PX) { ringStroke = RING_STROKE_MAX_PX; }
        var ringPadding = (w.toFloat() * 0.02f).toNumber();
        if (ringPadding < RING_PADDING_MIN_PX) { ringPadding = RING_PADDING_MIN_PX; }
        if (ringPadding > RING_PADDING_MAX_PX) { ringPadding = RING_PADDING_MAX_PX; }
        var ringInset = ringStroke + ringPadding + ROUND_EDGE_PADDING_PX;
        if (ringInset > inset) {
            inset = ringInset;
        }
        return inset;
    }

    private function getContentTopInset(h as Number) as Number {
        var inset = (h.toFloat() * CONTENT_VERTICAL_RATIO).toNumber();
        if (inset < CONTENT_MIN_TOP_PX) { inset = CONTENT_MIN_TOP_PX; }
        if (inset > 36) { inset = 36; }
        if (SAFE_TOP_PX > inset) {
            inset = SAFE_TOP_PX;
        }
        return inset;
    }

    private function getContentBottomInset(h as Number) as Number {
        var inset = (h.toFloat() * CONTENT_VERTICAL_RATIO).toNumber();
        if (inset < CONTENT_MIN_BOTTOM_PX) { inset = CONTENT_MIN_BOTTOM_PX; }
        if (inset > 40) { inset = 40; }
        if (SAFE_BOTTOM_PX > inset) {
            inset = SAFE_BOTTOM_PX;
        }
        return inset;
    }

    //! Build localized rate label from model state
    private function buildRateLabel() as String {
        if (_model.isCalorieModeActive()) {
            if (_model.isCaloriesAvailable()) {
                return "Auto " + _model.getCarbFractionPct().format("%d") +
                       _labelRateAutoSuffix;
            }
            return _labelRateAutoNoData;
        }
        return _labelRateTarget + " " +
               _model.getCarbsTargetGph().format("%d") + " " +
               _unitGramsPerHour;
    }

    private function buildTotalsText() as String {
        var consumedG = (_model.getConsumedTotalG10() + 5) / 10;
        var targetG = (_model.getTargetTotalG10() + 5) / 10;
        return consumedG.format("%d") + "/" + targetG.format("%d");
    }

    private function buildCompactStatusText(touchEnabled as Boolean) as String {
        if (_model.isPaused()) {
            return _labelPaused;
        }
        if (_model.isReminderDue()) {
            if (touchEnabled) {
                return "+" + _model.getDoseG().format("%d") + UNIT_G;
            }
            return "AUTO";
        }
        return formatDuration(_model.getDisplayNextDueInSec());
    }

    private function buildDeficitText() as String {
        return buildDeficitTextFromG10(_model.getDeficitG10());
    }

    private function buildDeficitTextFromG10(deficitG10 as Number) as String {
        if (deficitG10 > 5) {
            return _labelBehind + " " + ((deficitG10 + 5) / 10).format("%d") + UNIT_G;
        }
        if (deficitG10 < -5) {
            return _labelAhead + " " + (((-deficitG10) + 5) / 10).format("%d") + UNIT_G;
        }
        return _labelOnTarget;
    }

    private function buildCompactDeficitTextFromG10(deficitG10 as Number) as String {
        if (deficitG10 > 5) {
            return "+" + ((deficitG10 + 5) / 10).format("%d") + UNIT_G;
        }
        if (deficitG10 < -5) {
            return "-" + (((-deficitG10) + 5) / 10).format("%d") + UNIT_G;
        }
        return "OK";
    }

    private function buildReminderReasonText() as String {
        if (_model.getReminderMode() == FuelReminderModes.FIXED) {
            return FuelPlannerUtils.loadString(Rez.Strings.ModeFixed, "Fixed") + " " +
                   _model.getFixedIntervalMin().format("%d") + " " +
                   FuelPlannerUtils.loadString(Rez.Strings.UnitMinutes, "min");
        }

        var deficitG10 = _model.getDeficitG10();
        if (deficitG10 > 5 || deficitG10 < -5) {
            return buildDeficitTextFromG10(deficitG10);
        }
        return buildRateLabel();
    }

    private function loadDrawStrings() as Void {
        _labelAppName = FuelPlannerUtils.loadString(Rez.Strings.AppName, "FuelPlanner");
        _labelPaused = FuelPlannerUtils.loadString(Rez.Strings.LabelPaused, "PAUSED");
        _labelFuelNow = FuelPlannerUtils.loadString(Rez.Strings.LabelFuelNow, "FUEL NOW");
        _labelFuelShort = FuelPlannerUtils.loadString(Rez.Strings.LabelFuelShort, "FUEL");
        _labelNext = FuelPlannerUtils.loadString(Rez.Strings.LabelNext, "Next");
        _labelAutoFlow = FuelPlannerUtils.loadString(Rez.Strings.LabelAutoFlowStatus, "AUTO-FLOW");
        _labelBehind = FuelPlannerUtils.loadString(Rez.Strings.LabelBehind, "Behind");
        _labelAhead = FuelPlannerUtils.loadString(Rez.Strings.LabelAhead, "Ahead");
        _labelOnTarget = FuelPlannerUtils.loadString(Rez.Strings.LabelOnTarget, "On target");
        _labelRateTarget = FuelPlannerUtils.loadString(Rez.Strings.LabelRateTargetPrefix, "Plan");
        _labelRateAutoSuffix = FuelPlannerUtils.loadString(Rez.Strings.LabelRateAutoCarbsSuffix, "% carbs");
        _labelRateAutoNoData = FuelPlannerUtils.loadString(Rez.Strings.LabelRateAutoNoData, "Auto (no cal data)");
        _unitGramsPerHour = FuelPlannerUtils.loadString(Rez.Strings.UnitGramsPerHour, "g/h");
        _labelWaiting = FuelPlannerUtils.loadString(Rez.Strings.LabelWaiting, "Start activity to begin");
        _labelWaitStartCompact = FuelPlannerUtils.loadString(Rez.Strings.LabelWaitStartCompact, "WAIT / START");
        _labelStarting = FuelPlannerUtils.loadString(Rez.Strings.LabelStarting, "STARTING");
        _labelWaitingForTimer = FuelPlannerUtils.loadString(Rez.Strings.LabelWaitingForTimer, "Waiting for timer data");
        _labelTimerStale = FuelPlannerUtils.loadString(Rez.Strings.LabelTimerStale, "TIMER STALE");
        _labelNoTimerCompact = FuelPlannerUtils.loadString(Rez.Strings.LabelNoTimerCompact, "NO TIMER");
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
