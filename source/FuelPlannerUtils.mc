import Toybox.Activity;
import Toybox.Lang;
import Toybox.WatchUi;
import FuelPlannerLog;

//! Gemeinsame Utility-Funktionen für FuelPlaner
//! Vermeidet Code-Duplikation zwischen Model-, View- und Menu-Code
module FuelPlannerUtils {

    //! A stopped timer still belongs to an active recording. Only OFF is
    //! terminal; DataField.onTimerReset() remains the authoritative end event.
    function isTimerStateOff(info as Activity.Info) as Boolean {
        try {
            if (!(info has :timerState)) {
                return false;
            }
            if (Activity has :TIMER_STATE_OFF &&
                info.timerState == Activity.TIMER_STATE_OFF) {
                return true;
            }
        } catch (e) {
            return false;
        }
        return false;
    }

    //! Zentrale Resource-String-Ladefunktion
    //! Haelt Fallback-Handling an einer Stelle
    function loadString(resourceId as Lang.ResourceId?, fallback as String) as String {
        if (resourceId == null) {
            return fallback;
        }
        try {
            var value = WatchUi.loadResource(resourceId);
            if (value instanceof String) {
                return value as String;
            }
        } catch (e) {
            FuelPlannerLog.logWarn("Resources", "Failed to load string resource");
        }
        return fallback;
    }
}
