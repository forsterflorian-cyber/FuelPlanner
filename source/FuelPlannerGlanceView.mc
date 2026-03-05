import Toybox.Graphics;
import Toybox.Lang;
import Toybox.WatchUi;

//! Glance view - shown in widget list
(:glance)
class FuelPlannerGlanceView extends WatchUi.GlanceView {
    
    private var _storage as StorageManager;
    
    function initialize(storage as StorageManager) {
        GlanceView.initialize();
        _storage = storage;
    }
    
    function onUpdate(dc as Dc) as Void {
        var height = dc.getHeight();
        
        dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_TRANSPARENT);
        
        // Title
        dc.drawText(0, 2, Graphics.FONT_GLANCE, "FuelPlanner", Graphics.TEXT_JUSTIFY_LEFT);
        
        // Status line
        var targetGph = _storage.getCarbsTargetGph();
        var doseG = _storage.getDoseG();
        var statusText = targetGph.format("%d") + "g/h | " + doseG.format("%d") + "g gel";
        
        dc.setColor(Graphics.COLOR_LT_GRAY, Graphics.COLOR_TRANSPARENT);
        dc.drawText(0, height / 2 + 5, Graphics.FONT_GLANCE, statusText, Graphics.TEXT_JUSTIFY_LEFT);
    }
}