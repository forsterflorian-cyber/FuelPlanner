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

        var w = dc.getWidth();
        var h = dc.getHeight();
        var cx = w / 2;
        var y = (h * 0.10).toNumber();
        var rowH = (h * 0.13).toNumber();

        // Title
        dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_TRANSPARENT);
        dc.drawText(cx, y, Graphics.FONT_MEDIUM, "FuelPlanner", Graphics.TEXT_JUSTIFY_CENTER);
        y += (h * 0.17).toNumber();

        var mode = _storage.getReminderMode();
        var modeText = FuelPlannerMenuDelegate.modeLabel(mode, _storage.getFixedIntervalMin());

        // Helper: draw a label/value row
        // Row: Reminder Mode
        drawRow(dc, w, y, "Mode:", modeText);
        y += rowH;

        // Row: Carbs Target (only relevant in Auto/Fixed modes)
        if (mode != 2) {
            drawRow(dc, w, y, "Target:",
                _storage.getCarbsTargetGph().format("%d") + " g/h");
        } else {
            drawRow(dc, w, y, "Carb %:",
                _storage.getCarbFractionPct().format("%d") + "%");
        }
        y += rowH;

        // Row: Gel Size
        drawRow(dc, w, y, "Gel:", _storage.getDoseG().format("%d") + " g");
        y += rowH;

        // Row: Start Delay
        drawRow(dc, w, y, "Delay:", _storage.getStartDelayMin().format("%d") + " min");
        y += rowH;

        // Row: Snooze
        drawRow(dc, w, y, "Snooze:", _storage.getMaxSnoozeMin().format("%d") + " min");

        // Bottom hint
        dc.setColor(Graphics.COLOR_DK_GRAY, Graphics.COLOR_TRANSPARENT);
        dc.drawText(cx, h - (h * 0.10).toNumber(), Graphics.FONT_XTINY,
                    "SELECT to configure", Graphics.TEXT_JUSTIFY_CENTER);
    }

    private function drawRow(dc as Dc, w as Number, y as Number,
                              label as String, value as String) as Void {
        dc.setColor(Graphics.COLOR_LT_GRAY, Graphics.COLOR_TRANSPARENT);
        dc.drawText(20, y, Graphics.FONT_SMALL, label, Graphics.TEXT_JUSTIFY_LEFT);
        dc.setColor(Graphics.COLOR_BLUE, Graphics.COLOR_TRANSPARENT);
        dc.drawText(w - 20, y, Graphics.FONT_SMALL, value, Graphics.TEXT_JUSTIFY_RIGHT);
    }

    function onHide() as Void {
    }
}
