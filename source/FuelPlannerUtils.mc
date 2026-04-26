import Toybox.Activity;
import Toybox.Lang;
import Toybox.WatchUi;

//! Gemeinsame Utility-Funktionen für FuelPlaner
//! Vermeidet Code-Duplikation zwischen Model-, View- und Menu-Code
module FuelPlannerUtils {

    //! Prüft ob der Timer gestoppt oder ausgeschaltet ist
    function isTimerStateStoppedOrOff(info as Activity.Info) as Boolean {
        try {
            if (!(info has :timerState)) {
                return false;
            }
            if (Activity has :TIMER_STATE_STOPPED &&
                info.timerState == Activity.TIMER_STATE_STOPPED) {
                return true;
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
        } catch (e) {}
        return fallback;
    }
}
