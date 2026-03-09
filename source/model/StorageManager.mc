import Toybox.Application;
import Toybox.Application.Storage;
import Toybox.Application.Properties;
import Toybox.Lang;

class StorageBackend {
    function initialize() {
    }

    function getValue(key as String) as Lang.Object? {
        return Storage.getValue(key);
    }

    function setValue(key as String, value as Lang.Object?) as Void {
        Storage.setValue(key, value);
    }

    function deleteValue(key as String) as Void {
        Storage.deleteValue(key);
    }
}

class PropertiesBackend {
    function initialize() {
    }

    function getValue(key as String) as Lang.Object? {
        return Properties.getValue(key);
    }

    function setValue(key as String, value as Lang.Object?) as Void {
        Properties.setValue(key, value);
    }
}

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
    private const KEY_PAUSED_TIMER_OFFSET_S = "pause_off_s";
    private const KEY_PAUSE_START_TIMER_S = "pause_start_s";
    private const KEY_LAST_LAP_SNAPSHOT = "lap_snap";

    // Defaults
    public const MIN_CARBS_TARGET_GPH       = 20;
    public const MAX_CARBS_TARGET_GPH       = 120;
    public const MIN_DOSE_G                 = 5;
    public const MAX_DOSE_G                 = 100;
    public const MIN_REMINDER_MODE          = 0;
    public const MAX_REMINDER_MODE          = 2;
    public const MIN_FIXED_INTERVAL_MIN     = 5;
    public const MAX_FIXED_INTERVAL_MIN     = 60;
    public const MIN_START_DELAY_MIN        = 0;
    public const MAX_START_DELAY_MIN        = 60;
    public const MIN_MAX_SNOOZE_MIN         = 1;
    public const MAX_MAX_SNOOZE_MIN         = 15;
    public const MIN_CARB_FRACTION_PCT      = 40;
    public const MAX_CARB_FRACTION_PCT      = 80;

    public const DEFAULT_CARBS_TARGET_GPH   = 60;
    public const DEFAULT_DOSE_G             = 25;
    public const DEFAULT_REMINDER_MODE      = 0;
    public const DEFAULT_FIXED_INTERVAL_MIN = 20;
    public const DEFAULT_START_DELAY_MIN    = 15;
    public const DEFAULT_MAX_SNOOZE_MIN     = 5;
    public const DEFAULT_CARB_FRACTION_PCT  = 60;  // 60% of kcal from carbs

    private const MAX_INTAKE_LOG_ENTRIES = 50;

    private var _storageBackend as StorageBackend;
    private var _propertiesBackend as PropertiesBackend;

    function initialize(storageBackend as StorageBackend?,
                        propertiesBackend as PropertiesBackend?) {
        _storageBackend = (storageBackend != null) ? storageBackend : new StorageBackend();
        _propertiesBackend = (propertiesBackend != null) ? propertiesBackend : new PropertiesBackend();
    }

    private function clamp(value as Number, min as Number, max as Number) as Number {
        if (value < min) { return min; }
        if (value > max) { return max; }
        return value;
    }

    private function nonNegative(value as Number) as Number {
        return (value < 0) ? 0 : value;
    }

    private function roundToInt(value as Number) as Number {
        var floatValue = value.toFloat();
        if (floatValue >= 0.0f) {
            return (floatValue + 0.5f).toNumber();
        }
        return (floatValue - 0.5f).toNumber();
    }

    private function getClampedProperty(key as String, defaultValue as Number,
                                        min as Number, max as Number) as Number {
        try {
            var value = _propertiesBackend.getValue(key);
            if (value instanceof Number) {
                var clamped = clamp(value, min, max);
                var normalized = roundToInt(clamped);
                if (normalized != value) {
                    _propertiesBackend.setValue(key, normalized);
                }
                return normalized;
            }
        } catch (e) {}
        return defaultValue;
    }

    private function setClampedProperty(key as String, value as Number,
                                        min as Number, max as Number) as Void {
        try {
            _propertiesBackend.setValue(key, roundToInt(clamp(value, min, max)));
        } catch (e) {}
    }

    // ========== Settings from Properties (synced via Garmin Connect) ==========

    function getCarbsTargetGph() as Number {
        return getClampedProperty(
            "carbsTargetGph",
            DEFAULT_CARBS_TARGET_GPH,
            MIN_CARBS_TARGET_GPH,
            MAX_CARBS_TARGET_GPH
        );
    }

    function setCarbsTargetGph(value as Number) as Void {
        setClampedProperty("carbsTargetGph", value, MIN_CARBS_TARGET_GPH, MAX_CARBS_TARGET_GPH);
    }

    function getDoseG() as Number {
        return getClampedProperty(
            "doseG",
            DEFAULT_DOSE_G,
            MIN_DOSE_G,
            MAX_DOSE_G
        );
    }

    function setDoseG(value as Number) as Void {
        setClampedProperty("doseG", value, MIN_DOSE_G, MAX_DOSE_G);
    }

    function getReminderMode() as Number {
        return getClampedProperty(
            "reminderMode",
            DEFAULT_REMINDER_MODE,
            MIN_REMINDER_MODE,
            MAX_REMINDER_MODE
        );
    }

    function setReminderMode(value as Number) as Void {
        setClampedProperty("reminderMode", value, MIN_REMINDER_MODE, MAX_REMINDER_MODE);
    }

    function getFixedIntervalMin() as Number {
        return getClampedProperty(
            "fixedIntervalMin",
            DEFAULT_FIXED_INTERVAL_MIN,
            MIN_FIXED_INTERVAL_MIN,
            MAX_FIXED_INTERVAL_MIN
        );
    }

    function setFixedIntervalMin(value as Number) as Void {
        setClampedProperty("fixedIntervalMin", value, MIN_FIXED_INTERVAL_MIN, MAX_FIXED_INTERVAL_MIN);
    }

    function getStartDelayMin() as Number {
        return getClampedProperty(
            "startDelayMin",
            DEFAULT_START_DELAY_MIN,
            MIN_START_DELAY_MIN,
            MAX_START_DELAY_MIN
        );
    }

    function setStartDelayMin(value as Number) as Void {
        setClampedProperty("startDelayMin", value, MIN_START_DELAY_MIN, MAX_START_DELAY_MIN);
    }

    function getMaxSnoozeMin() as Number {
        return getClampedProperty(
            "maxSnoozeMin",
            DEFAULT_MAX_SNOOZE_MIN,
            MIN_MAX_SNOOZE_MIN,
            MAX_MAX_SNOOZE_MIN
        );
    }

    function setMaxSnoozeMin(value as Number) as Void {
        setClampedProperty("maxSnoozeMin", value, MIN_MAX_SNOOZE_MIN, MAX_MAX_SNOOZE_MIN);
    }

    function getCarbFractionPct() as Number {
        return getClampedProperty(
            "carbFractionPct",
            DEFAULT_CARB_FRACTION_PCT,
            MIN_CARB_FRACTION_PCT,
            MAX_CARB_FRACTION_PCT
        );
    }

    function setCarbFractionPct(value as Number) as Void {
        setClampedProperty("carbFractionPct", value, MIN_CARB_FRACTION_PCT, MAX_CARB_FRACTION_PCT);
    }


    // ========== Session Data (in Storage) ==========

    function getSessionId() as Number? {
        var value = _storageBackend.getValue(KEY_SESSION_ID);
        if (value instanceof Number && value > 0) {
            return value;
        }
        return null;
    }

    function setSessionId(value as Number) as Void {
        if (value > 0) {
            _storageBackend.setValue(KEY_SESSION_ID, value);
        } else {
            _storageBackend.deleteValue(KEY_SESSION_ID);
        }
    }

    function getStartTimestamp() as Number? {
        var value = _storageBackend.getValue(KEY_START_TIMESTAMP);
        if (value instanceof Number && value > 0) {
            return value;
        }
        return null;
    }

    function setStartTimestamp(value as Number) as Void {
        if (value > 0) {
            _storageBackend.setValue(KEY_START_TIMESTAMP, value);
        } else {
            _storageBackend.deleteValue(KEY_START_TIMESTAMP);
        }
    }

    function getIsStartTimestampConfirmed() as Boolean {
        var value = _storageBackend.getValue(KEY_START_TS_CONFIRMED);
        if (value instanceof Boolean) {
            return value;
        }
        return false;
    }

    function setIsStartTimestampConfirmed(value as Boolean) as Void {
        _storageBackend.setValue(KEY_START_TS_CONFIRMED, value);
    }

    function getConsumedTotal() as Number {
        var value = _storageBackend.getValue(KEY_CONSUMED_TOTAL);
        if (value instanceof Number) {
            return nonNegative(value);
        }
        return 0;
    }

    function setConsumedTotal(value as Number) as Void {
        _storageBackend.setValue(KEY_CONSUMED_TOTAL, nonNegative(value));
    }

    function getConsumedTotalG10() as Number {
        var value = _storageBackend.getValue(KEY_CONSUMED_TOTAL_G10);
        if (value instanceof Number) {
            return nonNegative(value);
        }
        // Backward compatibility for older versions that stored grams.
        return nonNegative(getConsumedTotal() * 10);
    }

    function setConsumedTotalG10(value as Number) as Void {
        var clamped = nonNegative(value);
        _storageBackend.setValue(KEY_CONSUMED_TOTAL_G10, clamped);
        // Keep legacy key in sync for downgrade compatibility.
        _storageBackend.setValue(KEY_CONSUMED_TOTAL, clamped / 10);
    }

    function getLastIntakeTimestamp() as Number? {
        var value = _storageBackend.getValue(KEY_LAST_INTAKE_TS);
        if (value instanceof Number && value > 0) {
            return value;
        }
        return null;
    }

    function setLastIntakeTimestamp(value as Number) as Void {
        if (value > 0) {
            _storageBackend.setValue(KEY_LAST_INTAKE_TS, value);
        } else {
            _storageBackend.deleteValue(KEY_LAST_INTAKE_TS);
        }
    }

    function getIsPaused() as Boolean {
        var value = _storageBackend.getValue(KEY_IS_PAUSED);
        if (value instanceof Boolean) {
            return value;
        }
        return false;
    }

    function setIsPaused(value as Boolean) as Void {
        _storageBackend.setValue(KEY_IS_PAUSED, value);
    }

    function getElapsedActiveSec() as Number {
        var value = _storageBackend.getValue(KEY_ELAPSED_SEC);
        if (value instanceof Number) {
            return nonNegative(value);
        }
        return 0;
    }

    function setElapsedActiveSec(value as Number) as Void {
        _storageBackend.setValue(KEY_ELAPSED_SEC, nonNegative(value));
    }

    function getPausedTimerOffsetSec() as Number {
        var value = _storageBackend.getValue(KEY_PAUSED_TIMER_OFFSET_S);
        if (value instanceof Number) {
            return nonNegative(value);
        }
        return 0;
    }

    function setPausedTimerOffsetSec(value as Number) as Void {
        _storageBackend.setValue(KEY_PAUSED_TIMER_OFFSET_S, nonNegative(value));
    }

    function getPauseStartTimerSec() as Number? {
        var value = _storageBackend.getValue(KEY_PAUSE_START_TIMER_S);
        if (value instanceof Number) {
            var sanitized = nonNegative(value);
            if (sanitized > 0) {
                return sanitized;
            }
        }
        return null;
    }

    function setPauseStartTimerSec(value as Number?) as Void {
        if (value == null || value <= 0) {
            _storageBackend.deleteValue(KEY_PAUSE_START_TIMER_S);
            return;
        }
        _storageBackend.setValue(KEY_PAUSE_START_TIMER_S, nonNegative(value));
    }

    function getLastLapSnapshot() as Dictionary? {
        var value = _storageBackend.getValue(KEY_LAST_LAP_SNAPSHOT);
        if (value instanceof Dictionary) {
            return value;
        }
        return null;
    }

    function setLastLapSnapshot(sessionId as Number, elapsedActiveSec as Number,
                                consumedTotalG10 as Number, deficitG10 as Number) as Void {
        _storageBackend.setValue(KEY_LAST_LAP_SNAPSHOT, {
            "sessionId" => nonNegative(sessionId),
            "elapsedActiveSec" => nonNegative(elapsedActiveSec),
            "consumedTotalG10" => nonNegative(consumedTotalG10),
            "deficitG10" => deficitG10
        });
    }

    // ========== Intake Log ==========

    function getIntakeLog() as Array<Dictionary> {
        var value = _storageBackend.getValue(KEY_INTAKE_LOG);
        if (value instanceof Array) {
            var rawLog = value as Array;
            var sanitizedLog = [] as Array<Dictionary>;
            for (var i = 0; i < rawLog.size(); i += 1) {
                var entry = rawLog[i];
                if (entry instanceof Dictionary) {
                    sanitizedLog.add(entry);
                }
            }
            return sanitizedLog;
        }
        return [] as Array<Dictionary>;
    }

    function getIntakeCount() as Number {
        var value = _storageBackend.getValue(KEY_INTAKE_COUNT);
        if (value instanceof Number) {
            return value;
        }
        return 0;
    }

    function addIntakeEntry(timestamp as Number, grams as Number, intakeType as String) as Void {
        var safeTs = nonNegative(timestamp);
        var safeGrams = nonNegative(grams);
        if (safeGrams <= 0) {
            return;
        }

        var log = getIntakeLog();

        var entry = {
            "t" => safeTs,
            "g" => safeGrams,
            "type" => (intakeType == "") ? "manual" : intakeType
        };

        log.add(entry);

        // Cap at MAX entries (rolling)
        while (log.size() > MAX_INTAKE_LOG_ENTRIES) {
            log.remove(log[0]);
        }

        _storageBackend.setValue(KEY_INTAKE_LOG, log);
        _storageBackend.setValue(KEY_INTAKE_COUNT, log.size());
    }

    function removeLastIntakeEntry() as Boolean {
        var log = getIntakeLog();
        var count = log.size();
        if (count <= 0) {
            return false;
        }

        log.remove(log[count - 1]);
        if (log.size() > 0) {
            _storageBackend.setValue(KEY_INTAKE_LOG, log);
        } else {
            _storageBackend.deleteValue(KEY_INTAKE_LOG);
        }
        _storageBackend.setValue(KEY_INTAKE_COUNT, log.size());
        return true;
    }

    function clearIntakeLog() as Void {
        _storageBackend.deleteValue(KEY_INTAKE_LOG);
        _storageBackend.setValue(KEY_INTAKE_COUNT, 0);
    }

    // ========== Session Management ==========

    function clearSession() as Void {
        _storageBackend.deleteValue(KEY_SESSION_ID);
        _storageBackend.deleteValue(KEY_START_TIMESTAMP);
        _storageBackend.deleteValue(KEY_START_TS_CONFIRMED);
        _storageBackend.deleteValue(KEY_CONSUMED_TOTAL);
        _storageBackend.deleteValue(KEY_CONSUMED_TOTAL_G10);
        _storageBackend.deleteValue(KEY_LAST_INTAKE_TS);
        _storageBackend.deleteValue(KEY_INTAKE_LOG);
        _storageBackend.deleteValue(KEY_INTAKE_COUNT);
        _storageBackend.deleteValue(KEY_IS_PAUSED);
        _storageBackend.deleteValue(KEY_ELAPSED_SEC);
        _storageBackend.deleteValue(KEY_PAUSED_TIMER_OFFSET_S);
        _storageBackend.deleteValue(KEY_PAUSE_START_TIMER_S);
        _storageBackend.deleteValue(KEY_LAST_LAP_SNAPSHOT);
    }

    function hasActiveSession() as Boolean {
        return getSessionId() != null && getStartTimestamp() != null;
    }
}
