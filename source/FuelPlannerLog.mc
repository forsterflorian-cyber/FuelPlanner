import Toybox.System;
import Toybox.Lang;

//! Debug-Logging für Device-Debugging
//! In Production-Builds: No-Op (kein Code generiert)
//! In Debug-Builds: System.println Ausgabe
module FuelPlannerLog {

    // Debug-Builds: Logging aktiv
    (:debug)
    function dError(tag as String, msg as String) as Void {
        try {
            System.println("FP ERR [" + tag + "]: " + msg);
        } catch (e) {}
    }

    (:debug)
    function dWarn(tag as String, msg as String) as Void {
        try {
            System.println("FP WRN [" + tag + "]: " + msg);
        } catch (e) {}
    }

    (:debug)
    function dInfo(tag as String, msg as String) as Void {
        try {
            System.println("FP INF [" + tag + "]: " + msg);
        } catch (e) {}
    }

    // Production-Builds: No-Op (wird vom Compiler weggelassen)
    function logError(tag as String, msg as String) as Void {
        // No-op in production - no code generated
    }

    function logWarn(tag as String, msg as String) as Void {
        // No-op in production - no code generated
    }

    function logInfo(tag as String, msg as String) as Void {
        // No-op in production - no code generated
    }
}
