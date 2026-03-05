import Toybox.Graphics;
import Toybox.Lang;
import Toybox.WatchUi;

//! Main widget view — shows current settings summary
class FuelPlannerWidgetView extends WatchUi.View {

    private var _storage as StorageManager;

    function initialize(storage as StorageManager) {
        View.initialize();
        _storage = storage;
    }

    function onLayout(dc as Dc) as Void {
    }

    function onShow() as Void {
        WatchUi.requestUpdate();
    }

    function onUpdate(dc as Dc) as Void {
        dc.setColor(Graphics.COLOR_BLACK, Graphics.COLOR_BLACK);
        dc.clear();

        var w  = dc.getWidth();
        var h  = dc.getHeight();
        var cx = w / 2;
        var y  = (h * 0.10).toNumber();
        var rowH = (h * 0.13).toNumber();

        // Scale fonts and margins to screen size
        var fontTitle = (w >= 360) ? Graphics.FONT_MEDIUM : Graphics.FONT_SMALL;
        var fontRow   = (w >= 360) ? Graphics.FONT_SMALL  : Graphics.FONT_TINY;
        var margin    = (w * 0.06).toNumber();  // 6% of width on each side

        // Title
        dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_TRANSPARENT);
        dc.drawText(cx, y, fontTitle,
                    WatchUi.loadResource(Rez.Strings.AppName) as String,
                    Graphics.TEXT_JUSTIFY_CENTER);
        y += (h * 0.17).toNumber();

        var mode = _storage.getReminderMode();
        var modeText = FuelPlannerMenuDelegate.modeLabel(mode, _storage.getFixedIntervalMin());

        // Row: Reminder Mode
        drawRow(dc, w, y, WatchUi.loadResource(Rez.Strings.LabelModeRow) as String, modeText, fontRow, margin);
        y += rowH;

        // Row: Carbs Target (only relevant in Auto/Fixed modes)
        if (mode != 2) {
            drawRow(dc, w, y, WatchUi.loadResource(Rez.Strings.LabelTargetRow) as String,
                _storage.getCarbsTargetGph().format("%d") + " g/h", fontRow, margin);
        } else {
            drawRow(dc, w, y, WatchUi.loadResource(Rez.Strings.LabelCarbPctRow) as String,
                _storage.getCarbFractionPct().format("%d") + "%", fontRow, margin);
        }
        y += rowH;

        // Row: Gel Size
        drawRow(dc, w, y, WatchUi.loadResource(Rez.Strings.LabelGelRow) as String,
                _storage.getDoseG().format("%d") + " g", fontRow, margin);
        y += rowH;

        // Row: Start Delay
        drawRow(dc, w, y, WatchUi.loadResource(Rez.Strings.LabelDelayRow) as String,
                _storage.getStartDelayMin().format("%d") + " min", fontRow, margin);
        y += rowH;

        // Row: Snooze
        drawRow(dc, w, y, WatchUi.loadResource(Rez.Strings.LabelSnoozeRow) as String,
                _storage.getMaxSnoozeMin().format("%d") + " min", fontRow, margin);

        // Bottom hint
        dc.setColor(Graphics.COLOR_DK_GRAY, Graphics.COLOR_TRANSPARENT);
        dc.drawText(cx, h - (h * 0.10).toNumber(), Graphics.FONT_XTINY,
                    WatchUi.loadResource(Rez.Strings.LabelSelectConfig) as String,
                    Graphics.TEXT_JUSTIFY_CENTER);
    }

    private function drawRow(dc as Dc, w as Number, y as Number,
                              label as String, value as String,
                              font as Graphics.FontType, margin as Number) as Void {
        dc.setColor(Graphics.COLOR_LT_GRAY, Graphics.COLOR_TRANSPARENT);
        dc.drawText(margin, y, font, label, Graphics.TEXT_JUSTIFY_LEFT);
        dc.setColor(Graphics.COLOR_BLUE, Graphics.COLOR_TRANSPARENT);
        dc.drawText(w - margin, y, font, value, Graphics.TEXT_JUSTIFY_RIGHT);
    }

    function onHide() as Void {
    }
}
