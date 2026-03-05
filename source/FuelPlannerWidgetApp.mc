import Toybox.Application;
import Toybox.Lang;
import Toybox.WatchUi;

//! Widget application entry - allows users to adjust FuelPlanner settings on the watch
class FuelPlannerWidgetApp extends Application.AppBase {

    function initialize() {
        AppBase.initialize();
    }

    //! Return the initial view for the widget
    function getInitialView() as [Views] or [Views, InputDelegates] {
        var storage = new StorageManager();
        var view = new FuelPlannerWidgetView(storage);
        var delegate = new FuelPlannerWidgetDelegate(storage);
        return [view, delegate];
    }

    //! Return the glance view for the widget list (only on devices that support glance)
    (:glance)
    function getGlanceView() as [WatchUi.GlanceView] or [WatchUi.GlanceView, WatchUi.GlanceViewDelegate] or Null {
        var storage = new StorageManager();
        return [new FuelPlannerGlanceView(storage)];
    }
}
