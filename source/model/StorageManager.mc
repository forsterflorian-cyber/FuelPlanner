import Toybox.Application;
import Toybox.Application.Storage;
import Toybox.Application.Properties;
import Toybox.Lang;
import Toybox.Time;

//! Manages persistent storage for settings and session data
class StorageManager {
    
    // Storage keys for SESSION data
    private const KEY_SESSION_ID = "sess_id";
    private const KEY_START_TIMESTAMP = "start_ts";
    private const KEY_CONSUMED_TOTAL = "consumed";
    private const KEY_LAST_INTAKE_TS = "last_int";
    private const KEY_INTAKE_LOG = "int_log";
    private const KEY_IS_PAUSED = "is_paused";
    
    // Defaults
    public const DEFAULT_CARBS_TARGET_GPH   = 60;
    public const DEFAULT_DOSE_G             = 25;
    public const DEFAULT_REMINDER_MODE      = 0;
    public const DEFAULT_FIXED_INTERVAL_MIN = 20;
    public const DEFAULT_START_DELAY_MIN    = 15;
    public const DEFAULT_MAX_SNOOZE_MIN     = 5;
    public const DEFAULT_CARB_FRACTION_PCT  = 60;  // 60% of kcal from carbs
    
    private const MAX_INTAKE_LOG_ENTRIES = 50;
    
    function initialize() {
    }
    
    // ========== Settings from Properties (synced via Garmin Connect) ==========
    
    function getCarbsTargetGph() as Number {
        try {
            var value = Properties.getValue("carbsTargetGph");
            if (value instanceof Number) {
                return value;
            }
        } catch (e) {}
        return DEFAULT_CARBS_TARGET_GPH;
    }
    
    function setCarbsTargetGph(value as Number) as Void {
        try {
            Properties.setValue("carbsTargetGph", value);
        } catch (e) {}
    }
    
    function getDoseG() as Number {
        try {
            var value = Properties.getValue("doseG");
            if (value instanceof Number) {
                return value;
            }
        } catch (e) {}
        return DEFAULT_DOSE_G;
    }
    
    function setDoseG(value as Number) as Void {
        try {
            Properties.setValue("doseG", value);
        } catch (e) {}
    }
    
    function getReminderMode() as Number {
        try {
            var value = Properties.getValue("reminderMode");
            if (value instanceof Number) {
                return value;
            }
        } catch (e) {}
        return DEFAULT_REMINDER_MODE;
    }
    
    function setReminderMode(value as Number) as Void {
        try {
            Properties.setValue("reminderMode", value);
        } catch (e) {}
    }
    
    function getFixedIntervalMin() as Number {
        try {
            var value = Properties.getValue("fixedIntervalMin");
            if (value instanceof Number) {
                return value;
            }
        } catch (e) {}
        return DEFAULT_FIXED_INTERVAL_MIN;
    }
    
    function setFixedIntervalMin(value as Number) as Void {
        try {
            Properties.setValue("fixedIntervalMin", value);
        } catch (e) {}
    }
    
    function getStartDelayMin() as Number {
        try {
            var value = Properties.getValue("startDelayMin");
            if (value instanceof Number) {
                return value;
            }
        } catch (e) {}
        return DEFAULT_START_DELAY_MIN;
    }
    
    function setStartDelayMin(value as Number) as Void {
        try {
            Properties.setValue("startDelayMin", value);
        } catch (e) {}
    }
    
    function getMaxSnoozeMin() as Number {
        try {
            var value = Properties.getValue("maxSnoozeMin");
            if (value instanceof Number) {
                return value;
            }
        } catch (e) {}
        return DEFAULT_MAX_SNOOZE_MIN;
    }
    
    function setMaxSnoozeMin(value as Number) as Void {
        try {
            Properties.setValue("maxSnoozeMin", value);
        } catch (e) {}
    }

    function getCarbFractionPct() as Number {
        try {
            var value = Properties.getValue("carbFractionPct");
            if (value instanceof Number) {
                return value;
            }
        } catch (e) {}
        return DEFAULT_CARB_FRACTION_PCT;
    }

    function setCarbFractionPct(value as Number) as Void {
        try {
            Properties.setValue("carbFractionPct", value);
        } catch (e) {}
    }


    // ========== Session Data (in Storage) ==========
    
    function getSessionId() as Number? {
        var value = Storage.getValue(KEY_SESSION_ID);
        if (value instanceof Number) {
            return value;
        }
        return null;
    }
    
    function setSessionId(value as Number) as Void {
        Storage.setValue(KEY_SESSION_ID, value);
    }
    
    function getStartTimestamp() as Number? {
        var value = Storage.getValue(KEY_START_TIMESTAMP);
        if (value instanceof Number) {
            return value;
        }
        return null;
    }
    
    function setStartTimestamp(value as Number) as Void {
        Storage.setValue(KEY_START_TIMESTAMP, value);
    }
    
    function getConsumedTotal() as Number {
        var value = Storage.getValue(KEY_CONSUMED_TOTAL);
        if (value instanceof Number) {
            return value;
        }
        return 0;
    }
    
    function setConsumedTotal(value as Number) as Void {
        Storage.setValue(KEY_CONSUMED_TOTAL, value);
    }
    
    function getLastIntakeTimestamp() as Number? {
        var value = Storage.getValue(KEY_LAST_INTAKE_TS);
        if (value instanceof Number) {
            return value;
        }
        return null;
    }
    
    function setLastIntakeTimestamp(value as Number) as Void {
        Storage.setValue(KEY_LAST_INTAKE_TS, value);
    }
    
    function getIsPaused() as Boolean {
        var value = Storage.getValue(KEY_IS_PAUSED);
        if (value instanceof Boolean) {
            return value;
        }
        return false;
    }
    
    function setIsPaused(value as Boolean) as Void {
        Storage.setValue(KEY_IS_PAUSED, value);
    }
    
    // ========== Intake Log ==========
    
    function getIntakeLog() as Array {
        var value = Storage.getValue(KEY_INTAKE_LOG);
        if (value instanceof Array) {
            return value;
        }
        return [];
    }
    
    function addIntakeEntry(timestamp as Number, grams as Number, intakeType as String) as Void {
        var log = getIntakeLog();
        
        var entry = {
            "t" => timestamp,
            "g" => grams,
            "type" => intakeType
        };
        
        log.add(entry);
        
        // Cap at MAX entries (rolling)
        while (log.size() > MAX_INTAKE_LOG_ENTRIES) {
            log = log.slice(1, log.size());
        }
        
        Storage.setValue(KEY_INTAKE_LOG, log);
    }
    
    function clearIntakeLog() as Void {
        Storage.setValue(KEY_INTAKE_LOG, []);
    }
    
    // ========== Session Management ==========
    
    function clearSession() as Void {
        Storage.deleteValue(KEY_SESSION_ID);
        Storage.deleteValue(KEY_START_TIMESTAMP);
        Storage.deleteValue(KEY_CONSUMED_TOTAL);
        Storage.deleteValue(KEY_LAST_INTAKE_TS);
        Storage.deleteValue(KEY_INTAKE_LOG);
        Storage.deleteValue(KEY_IS_PAUSED);
    }
    
    function hasActiveSession() as Boolean {
        return getSessionId() != null && getStartTimestamp() != null;
    }
}