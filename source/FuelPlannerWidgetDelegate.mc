import Toybox.Lang;
import Toybox.WatchUi;

//! Widget input delegate
class FuelPlannerWidgetDelegate extends WatchUi.BehaviorDelegate {
    
    private var _storage as StorageManager;
    
    function initialize(storage as StorageManager) {
        BehaviorDelegate.initialize();
        _storage = storage;
    }
    
    //! Handle menu button or tap
    function onSelect() as Boolean {
        // Open settings menu
        var menu = new FuelPlannerMenu(_storage);
        var delegate = new FuelPlannerMenuDelegate(_storage, menu);
        WatchUi.pushView(menu, delegate, WatchUi.SLIDE_UP);
        return true;
    }
    
    //! Handle back button
    function onBack() as Boolean {
        WatchUi.popView(WatchUi.SLIDE_DOWN);
        return true;
    }
    
    //! Handle tap
    function onTap(clickEvent as WatchUi.ClickEvent) as Boolean {
        return onSelect();
    }
}