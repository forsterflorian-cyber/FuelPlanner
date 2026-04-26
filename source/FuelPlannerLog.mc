import Toybox.System;
import Toybox.Lang;

//! Debug-Logging für Device-Debugging
//! In Production-Builds: No-Op (kein Code generiert)
//! In Debug-Builds: System.println Ausgabe
module FuelPlannerLog {

    (:debug)
    function printLine(level as String, tag as String, msg as String) as Void {
        try {
            System.println("FP " + level + " [" + tag + "]: " + msg);
        } catch (e) {}
    }

    (:debug)
    function logError(tag as String, msg as String) as Void {
        printLine("ERR", tag, msg);
    }

    (:debug)
    function logWarn(tag as String, msg as String) as Void {
        printLine("WRN", tag, msg);
    }

    (:debug)
    function logInfo(tag as String, msg as String) as Void {
        printLine("INF", tag, msg);
    }

    (:release)
    function logError(tag as String, msg as String) as Void {
    }

    (:release)
    function logWarn(tag as String, msg as String) as Void {
    }

    (:release)
    function logInfo(tag as String, msg as String) as Void {
    }
}
