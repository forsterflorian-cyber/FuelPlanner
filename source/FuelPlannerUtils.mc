import Toybox.Activity;
import Toybox.Lang;

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
        } catch (e) {}
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
}