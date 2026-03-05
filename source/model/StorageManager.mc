import Toybox.Application;
import Toybox.Application.Storage;
import Toybox.Application.Properties;
import Toybox.Lang;

//! Manages persistent storage for settings and session data
class StorageManager {

    // Storage keys for SESSION data
    private const KEY_SESSION_ID = "sess_id";
    private const KEY_START_TIMESTAMP = "start_ts";
    private const KEY_START_TS_CONFIRMED = "start_ts_ok";
    private const KEY_CONSUMED_TOTAL = "consumed";
    private const KEY_CONSUMED_TOTAL_G10 = "consum10";
    private const KEY_LAST_INTAKE_TS = "last_int";
    private const KEY_INTAKE_LOG = "int_log";
    private const KEY_INTAKE_COUNT = "int_cnt";
    private const KEY_IS_PAUSED = "is_paused";
    private const KEY_ELAPSED_SEC = "elapsed_s";

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

    private function clamp(value as Number, min as Number, max as Number) as Number {
        if (value < min) { return min; }
        if (value > max) { return max; }
        return value;
    }

    // ========== Settings from Properties (synced via Garmin Connect) ==========

    function getCarbsTargetGph() as Number {
        try {
            var value = Properties.getValue("carbsTargetGph");
            if (value instanceof Number) {
                return clamp(value, 20, 120);
            }
        } catch (e) {}
        return DEFAULT_CARBS_TARGET_GPH;
    }

    function setCarbsTargetGph(value as Number) as Void {
        try {
            Properties.setValue("carbsTargetGph", clamp(value, 20, 120));
        } catch (e) {}
    }

    function getDoseG() as Number {
        try {
            var value = Properties.getValue("doseG");
            if (value instanceof Number) {
                return clamp(value, 5, 100);
            }
        } catch (e) {}
        return DEFAULT_DOSE_G;
    }

    function setDoseG(value as Number) as Void {
        try {
            Properties.setValue("doseG", clamp(value, 5, 100));
        } catch (e) {}
    }

    function getReminderMode() as Number {
        try {
            var value = Properties.getValue("reminderMode");
            if (value instanceof Number) {
                return clamp(value, 0, 2);
            }
        } catch (e) {}
        return DEFAULT_REMINDER_MODE;
    }

    function setReminderMode(value as Number) as Void {
        try {
            Properties.setValue("reminderMode", clamp(value, 0, 2));
        } catch (e) {}
    }

    function getFixedIntervalMin() as Number {
        try {
            var value = Properties.getValue("fixedIntervalMin");
            if (value instanceof Number) {
                return clamp(value, 5, 60);
            }
        } catch (e) {}
        return DEFAULT_FIXED_INTERVAL_MIN;
    }

    function setFixedIntervalMin(value as Number) as Void {
        try {
            Properties.setValue("fixedIntervalMin", clamp(value, 5, 60));
        } catch (e) {}
    }

    function getStartDelayMin() as Number {
        try {
            var value = Properties.getValue("startDelayMin");
            if (value instanceof Number) {
                return clamp(value, 0, 60);
            }
        } catch (e) {}
        return DEFAULT_START_DELAY_MIN;
    }

    function setStartDelayMin(value as Number) as Void {
        try {
            Properties.setValue("startDelayMin", clamp(value, 0, 60));
        } catch (e) {}
    }

    function getMaxSnoozeMin() as Number {
        try {
            var value = Properties.getValue("maxSnoozeMin");
            if (value instanceof Number) {
                return clamp(value, 1, 15);
            }
        } catch (e) {}
        return DEFAULT_MAX_SNOOZE_MIN;
    }

    function setMaxSnoozeMin(value as Number) as Void {
        try {
            Properties.setValue("maxSnoozeMin", clamp(value, 1, 15));
        } catch (e) {}
    }

    function getCarbFractionPct() as Number {
        try {
            var value = Properties.getValue("carbFractionPct");
            if (value instanceof Number) {
                return clamp(value, 40, 80);
            }
        } catch (e) {}
        return DEFAULT_CARB_FRACTION_PCT;
    }

    function setCarbFractionPct(value as Number) as Void {
        try {
            Properties.setValue("carbFractionPct", clamp(value, 40, 80));
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

    function getIsStartTimestampConfirmed() as Boolean {
        var value = Storage.getValue(KEY_START_TS_CONFIRMED);
        if (value instanceof Boolean) {
            return value;
        }
        return false;
    }

    function setIsStartTimestampConfirmed(value as Boolean) as Void {
        Storage.setValue(KEY_START_TS_CONFIRMED, value);
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

    function getConsumedTotalG10() as Number {
        var value = Storage.getValue(KEY_CONSUMED_TOTAL_G10);
        if (value instanceof Number) {
            return value;
        }
        // Backward compatibility for older versions that stored grams.
        return getConsumedTotal() * 10;
    }

    function setConsumedTotalG10(value as Number) as Void {
        Storage.setValue(KEY_CONSUMED_TOTAL_G10, value);
        // Keep legacy key in sync for downgrade compatibility.
        Storage.setValue(KEY_CONSUMED_TOTAL, value / 10);
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

    function getElapsedActiveSec() as Number {
        var value = Storage.getValue(KEY_ELAPSED_SEC);
        if (value instanceof Number) {
            return value;
        }
        return 0;
    }

    function setElapsedActiveSec(value as Number) as Void {
        Storage.setValue(KEY_ELAPSED_SEC, value);
    }

    // ========== Intake Log ==========

    function getIntakeLog() as Array {
        var value = Storage.getValue(KEY_INTAKE_LOG);
        if (value instanceof Array) {
            return value;
        }
        return [];
    }

    function getIntakeCount() as Number {
        var value = Storage.getValue(KEY_INTAKE_COUNT);
        if (value instanceof Number) {
            return value;
        }
        return 0;
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
            log.remove(0);
        }

        Storage.setValue(KEY_INTAKE_LOG, log);
        Storage.setValue(KEY_INTAKE_COUNT, log.size());
    }

    function removeLastIntakeEntry() as Boolean {
        var log = getIntakeLog();
        var count = log.size();
        if (count <= 0) {
            return false;
        }

        log.remove(count - 1);
        if (log.size() > 0) {
            Storage.setValue(KEY_INTAKE_LOG, log);
        } else {
            Storage.deleteValue(KEY_INTAKE_LOG);
        }
        Storage.setValue(KEY_INTAKE_COUNT, log.size());
        return true;
    }

    function clearIntakeLog() as Void {
        Storage.deleteValue(KEY_INTAKE_LOG);
        Storage.setValue(KEY_INTAKE_COUNT, 0);
    }

    // ========== Session Management ==========

    function clearSession() as Void {
        Storage.deleteValue(KEY_SESSION_ID);
        Storage.deleteValue(KEY_START_TIMESTAMP);
        Storage.deleteValue(KEY_START_TS_CONFIRMED);
        Storage.deleteValue(KEY_CONSUMED_TOTAL);
        Storage.deleteValue(KEY_CONSUMED_TOTAL_G10);
        Storage.deleteValue(KEY_LAST_INTAKE_TS);
        Storage.deleteValue(KEY_INTAKE_LOG);
        Storage.deleteValue(KEY_INTAKE_COUNT);
        Storage.deleteValue(KEY_IS_PAUSED);
        Storage.deleteValue(KEY_ELAPSED_SEC);
    }

    function hasActiveSession() as Boolean {
        return getSessionId() != null && getStartTimestamp() != null;
    }
}
