import Toybox.Activity;
import Toybox.Lang;
import Toybox.WatchUi;

//! Gemeinsame Utility-Funktionen für FuelPlaner
//! Vermeidet Code-Duplikation zwischen FuelModel, FieldView und FieldViewInstinct3
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

    //! Gauge Alert Tone: 0 = GREEN, 1 = ORANGE, 2 = RED
    function getGaugeAlertTone(deficitG10 as Number, doseG10 as Number) as Number {
        if (deficitG10 <= 0) {
            return 0;
        }
        if (doseG10 <= 0) {
            return 2;
        }
        var ratio = deficitG10.toFloat() / doseG10.toFloat();
        if (ratio >= 1.0f) {
            return 2;
        }
        if (ratio > 0.0f) {
            return 1;
        }
        return 0;
    }

    //! Zentrale Resource-String-Laden-Funktion
    //! Eliminiert Code-Duplikation in 5 Dateien
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
