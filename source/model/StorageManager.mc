import Toybox.Application.Storage;
import Toybox.Application.Properties;
import Toybox.Lang;
import FuelPlannerLog;
import FuelReminderModes;

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
    private const KEY_SESSION_STATE = "sess_state";
    private const KEY_LAST_INTAKE_TS = "last_int";
    private const KEY_LAST_REMINDER_TS = "last_rem";
    private const KEY_INTAKE_COUNT = "int_cnt";
    private const KEY_IS_PAUSED = "is_paused";
    private const KEY_ELAPSED_SEC = "elapsed_s";
    private const KEY_PAUSED_TIMER_OFFSET_S = "pause_off_s";
    private const KEY_PAUSE_START_TIMER_S = "pause_start_s";
    private const KEY_PAUSE_START_CLOCK_TS = "pause_clock_s";
    private const KEY_RECOVERY_TARGET_G10 = "snap_tgt10";
    private const KEY_RECOVERY_CONSUMED_G10 = "snap_con10";
    private const KEY_RECOVERY_ELAPSED_SEC = "snap_elapsed";
    private const KEY_RECOVERY_INTAKE_COUNT = "snap_count";

    // Legacy keys kept only so reset paths can clean up older installs.
    private const LEGACY_KEY_INTAKE_LOG = "int_log";
    private const LEGACY_KEY_LAST_LAP_SNAPSHOT = "lap_snap";

    // Defaults
    public const MIN_CARBS_TARGET_GPH       = 20;
    public const MAX_CARBS_TARGET_GPH       = 120;
    public const MIN_DOSE_G                 = 5;
    public const MAX_DOSE_G                 = 100;
    public const MIN_REMINDER_MODE          = FuelReminderModes.AUTO;
    public const MAX_REMINDER_MODE          = FuelReminderModes.CALORIE_AUTO;
    public const MIN_FIXED_INTERVAL_MIN     = 5;
    public const MAX_FIXED_INTERVAL_MIN     = 60;
    public const MIN_START_DELAY_MIN        = 0;
    public const MAX_START_DELAY_MIN        = 60;
    public const MIN_MAX_SNOOZE_MIN         = 1;
    public const MAX_MAX_SNOOZE_MIN         = 15;
    public const MIN_DATA_FIELD_ALERT_ENABLED = 0;
    public const MAX_DATA_FIELD_ALERT_ENABLED = 1;
    public const MIN_CARB_FRACTION_PCT      = 40;
    public const MAX_CARB_FRACTION_PCT      = 80;

    public const DEFAULT_CARBS_TARGET_GPH   = 60;
    public const DEFAULT_DOSE_G             = 25;
    public const DEFAULT_REMINDER_MODE      = FuelReminderModes.AUTO;
    public const DEFAULT_FIXED_INTERVAL_MIN = 20;
    public const DEFAULT_START_DELAY_MIN    = 15;
    public const DEFAULT_MAX_SNOOZE_MIN     = 5;
    public const DEFAULT_DATA_FIELD_ALERT_ENABLED = 0;
    public const DEFAULT_CARB_FRACTION_PCT  = 60;  // 60% of kcal from carbs

    private var _storageBackend as StorageBackend;
    private var _propertiesBackend as PropertiesBackend;
    private var _writeFailureCount as Number = 0;
    private var _lastWriteFailureKey as String = "";

    function initialize(storageBackend as StorageBackend?,
                        propertiesBackend as PropertiesBackend?) {
        _storageBackend = (storageBackend != null) ? storageBackend : new StorageBackend();
        _propertiesBackend = (propertiesBackend != null) ? propertiesBackend : new PropertiesBackend();
    }

    function getWriteFailureCount() as Number {
        return _writeFailureCount;
    }

    function getLastWriteFailureKey() as String {
        return _lastWriteFailureKey;
    }

    function resetWriteFailureCount() as Void {
        _writeFailureCount = 0;
        _lastWriteFailureKey = "";
    }

    private function recordWriteFailure(key as String, action as String) as Void {
        _writeFailureCount += 1;
        _lastWriteFailureKey = key;
        FuelPlannerLog.logError("Storage", "Failed to " + action + ": " + key);
    }

    private function setStorageValue(key as String, value as Lang.Object?) as Boolean {
        try {
            _storageBackend.setValue(key, value);
            return true;
        } catch (e) {
            recordWriteFailure(key, "set value");
        }
        return false;
    }

    private function getStorageValue(key as String) as Lang.Object? {
        try {
            return _storageBackend.getValue(key);
        } catch (e) {
            FuelPlannerLog.logWarn("Storage", "Failed to get value: " + key);
        }
        return null;
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
                    try {
                        _propertiesBackend.setValue(key, normalized);
                    } catch (writeError) {
                        recordWriteFailure(key, "normalize property");
                    }
                }
                return normalized;
            }
        } catch (e) {
            FuelPlannerLog.logWarn("Storage", "Failed to get property: " + key);
        }
        return defaultValue;
    }

    private function setClampedProperty(key as String, value as Number,
                                        min as Number, max as Number) as Void {
        try {
            _propertiesBackend.setValue(key, roundToInt(clamp(value, min, max)));
        } catch (e) {
            recordWriteFailure(key, "set property");
        }
    }

    private function deleteStorageValue(key as String) as Void {
        try {
            _storageBackend.deleteValue(key);
        } catch (e) {
            recordWriteFailure(key, "delete value");
        }
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

    function getDataFieldAlertEnabled() as Number {
        return getClampedProperty(
            "dataFieldAlertEnabled",
            DEFAULT_DATA_FIELD_ALERT_ENABLED,
            MIN_DATA_FIELD_ALERT_ENABLED,
            MAX_DATA_FIELD_ALERT_ENABLED
        );
    }

    function setDataFieldAlertEnabled(value as Number) as Void {
        setClampedProperty(
            "dataFieldAlertEnabled",
            value,
            MIN_DATA_FIELD_ALERT_ENABLED,
            MAX_DATA_FIELD_ALERT_ENABLED
        );
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
        var value = getStorageValue(KEY_SESSION_ID);
        if (value instanceof Number && value > 0) {
            return value;
        }
        return null;
    }

    function setSessionId(value as Number) as Void {
        if (value > 0) {
            setStorageValue(KEY_SESSION_ID, value);
        } else {
            deleteStorageValue(KEY_SESSION_ID);
        }
    }

    function getStartTimestamp() as Number? {
        var value = getStorageValue(KEY_START_TIMESTAMP);
        if (value instanceof Number && value > 0) {
            return value;
        }
        return null;
    }

    function setStartTimestamp(value as Number) as Void {
        if (value > 0) {
            setStorageValue(KEY_START_TIMESTAMP, value);
        } else {
            deleteStorageValue(KEY_START_TIMESTAMP);
        }
    }

    function getIsStartTimestampConfirmed() as Boolean {
        var value = getStorageValue(KEY_START_TS_CONFIRMED);
        if (value instanceof Boolean) {
            return value;
        }
        return false;
    }

    function setIsStartTimestampConfirmed(value as Boolean) as Void {
        setStorageValue(KEY_START_TS_CONFIRMED, value);
    }

    function getConsumedTotal() as Number {
        var value = getStorageValue(KEY_CONSUMED_TOTAL);
        if (value instanceof Number) {
            return nonNegative(value);
        }
        return 0;
    }

    function setConsumedTotal(value as Number) as Void {
        setStorageValue(KEY_CONSUMED_TOTAL, nonNegative(value));
    }

    function getConsumedTotalG10() as Number {
        var value = getStorageValue(KEY_CONSUMED_TOTAL_G10);
        if (value instanceof Number) {
            return nonNegative(value);
        }
        // Backward compatibility for older versions that stored grams.
        return nonNegative(getConsumedTotal() * 10);
    }

    function setConsumedTotalG10(value as Number) as Void {
        var clamped = nonNegative(value);
        // Legacy-Write mit Rounding statt Truncation: (256+5)/10 = 26 statt 256/10 = 25
        var legacyValue = (clamped + 5) / 10;

        // Beide Werte schreiben - bei Fehlschlag Inkonsistenz vermeiden
        var newKeySuccess = false;
        var legacyKeySuccess = false;

        newKeySuccess = setStorageValue(KEY_CONSUMED_TOTAL_G10, clamped);

        legacyKeySuccess = setStorageValue(KEY_CONSUMED_TOTAL, legacyValue);

        // Wenn neuer Key fehlschlägt, Legacy aufräumen um Inkonsistenz zu vermeiden
        if (!newKeySuccess && legacyKeySuccess) {
            try {
                _storageBackend.deleteValue(KEY_CONSUMED_TOTAL);
            } catch (e) {
                recordWriteFailure(KEY_CONSUMED_TOTAL, "delete inconsistent legacy value");
            }
        }
    }

    function getSessionState() as Number? {
        var value = getStorageValue(KEY_SESSION_STATE);
        if (value instanceof Number) {
            return nonNegative(value);
        }
        return null;
    }

    function setSessionState(value as Number?) as Void {
        if (value == null || value < 0) {
            deleteStorageValue(KEY_SESSION_STATE);
            return;
        }
        setStorageValue(KEY_SESSION_STATE, nonNegative(value));
    }

    function getLastIntakeTimestamp() as Number? {
        var value = getStorageValue(KEY_LAST_INTAKE_TS);
        if (value instanceof Number && value > 0) {
            return value;
        }
        return null;
    }

    function setLastIntakeTimestamp(value as Number) as Void {
        if (value > 0) {
            setStorageValue(KEY_LAST_INTAKE_TS, value);
        } else {
            deleteStorageValue(KEY_LAST_INTAKE_TS);
        }
    }

    function getLastReminderTimestamp() as Number {
        var value = getStorageValue(KEY_LAST_REMINDER_TS);
        if (value instanceof Number && value > 0) {
            return value;
        }
        return 0;
    }

    function setLastReminderTimestamp(value as Number) as Void {
        if (value > 0) {
            setStorageValue(KEY_LAST_REMINDER_TS, value);
        } else {
            deleteStorageValue(KEY_LAST_REMINDER_TS);
        }
    }

    function getIsPaused() as Boolean {
        var value = getStorageValue(KEY_IS_PAUSED);
        if (value instanceof Boolean) {
            return value;
        }
        return false;
    }

    function setIsPaused(value as Boolean) as Void {
        setStorageValue(KEY_IS_PAUSED, value);
    }

    function getElapsedActiveSec() as Number {
        var value = getStorageValue(KEY_ELAPSED_SEC);
        if (value instanceof Number) {
            return nonNegative(value);
        }
        return 0;
    }

    function setElapsedActiveSec(value as Number) as Void {
        setStorageValue(KEY_ELAPSED_SEC, nonNegative(value));
    }

    function getPausedTimerOffsetSec() as Number {
        var value = getStorageValue(KEY_PAUSED_TIMER_OFFSET_S);
        if (value instanceof Number) {
            return nonNegative(value);
        }
        return 0;
    }

    function setPausedTimerOffsetSec(value as Number) as Void {
        setStorageValue(KEY_PAUSED_TIMER_OFFSET_S, nonNegative(value));
    }

    function getPauseStartTimerSec() as Number? {
        var value = getStorageValue(KEY_PAUSE_START_TIMER_S);
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
            deleteStorageValue(KEY_PAUSE_START_TIMER_S);
            return;
        }
        setStorageValue(KEY_PAUSE_START_TIMER_S, nonNegative(value));
    }

    function getPauseStartClockSec() as Number? {
        var value = getStorageValue(KEY_PAUSE_START_CLOCK_TS);
        if (value instanceof Number) {
            var sanitized = nonNegative(value);
            if (sanitized > 0) {
                return sanitized;
            }
        }
        return null;
    }

    function setPauseStartClockSec(value as Number?) as Void {
        if (value == null || value <= 0) {
            deleteStorageValue(KEY_PAUSE_START_CLOCK_TS);
            return;
        }
        setStorageValue(KEY_PAUSE_START_CLOCK_TS, nonNegative(value));
    }

    function getIntakeCount() as Number {
        var value = getStorageValue(KEY_INTAKE_COUNT);
        if (value instanceof Number) {
            return nonNegative(value);
        }
        return 0;
    }

    function setIntakeCount(value as Number) as Void {
        setStorageValue(KEY_INTAKE_COUNT, nonNegative(value));
    }

    function getRecoveryTargetG10() as Number {
        var value = getStorageValue(KEY_RECOVERY_TARGET_G10);
        if (value instanceof Number) {
            return nonNegative(value);
        }
        return 0;
    }

    function setRecoveryTargetG10(value as Number) as Void {
        setStorageValue(KEY_RECOVERY_TARGET_G10, nonNegative(value));
    }

    function getRecoveryConsumedG10() as Number {
        var value = getStorageValue(KEY_RECOVERY_CONSUMED_G10);
        if (value instanceof Number) {
            return nonNegative(value);
        }
        return 0;
    }

    function setRecoveryConsumedG10(value as Number) as Void {
        setStorageValue(KEY_RECOVERY_CONSUMED_G10, nonNegative(value));
    }

    function getRecoveryElapsedSec() as Number {
        var value = getStorageValue(KEY_RECOVERY_ELAPSED_SEC);
        if (value instanceof Number) {
            return nonNegative(value);
        }
        return 0;
    }

    function setRecoveryElapsedSec(value as Number) as Void {
        setStorageValue(KEY_RECOVERY_ELAPSED_SEC, nonNegative(value));
    }

    function getRecoveryIntakeCount() as Number {
        var value = getStorageValue(KEY_RECOVERY_INTAKE_COUNT);
        if (value instanceof Number) {
            return nonNegative(value);
        }
        return 0;
    }

    function setRecoveryIntakeCount(value as Number) as Void {
        setStorageValue(KEY_RECOVERY_INTAKE_COUNT, nonNegative(value));
    }

    function hasRecoverySnapshot() as Boolean {
        return getRecoveryElapsedSec() > 0;
    }

    function clearRecoverySnapshot() as Void {
        deleteStorageValue(KEY_RECOVERY_TARGET_G10);
        deleteStorageValue(KEY_RECOVERY_CONSUMED_G10);
        deleteStorageValue(KEY_RECOVERY_ELAPSED_SEC);
        deleteStorageValue(KEY_RECOVERY_INTAKE_COUNT);
    }

    // ========== Session Management ==========

    function clearActiveSession() as Void {
        deleteStorageValue(KEY_SESSION_ID);
        deleteStorageValue(KEY_START_TIMESTAMP);
        deleteStorageValue(KEY_START_TS_CONFIRMED);
        deleteStorageValue(KEY_CONSUMED_TOTAL);
        deleteStorageValue(KEY_CONSUMED_TOTAL_G10);
        deleteStorageValue(KEY_SESSION_STATE);
        deleteStorageValue(KEY_LAST_INTAKE_TS);
        deleteStorageValue(KEY_LAST_REMINDER_TS);
        deleteStorageValue(KEY_INTAKE_COUNT);
        deleteStorageValue(KEY_IS_PAUSED);
        deleteStorageValue(KEY_ELAPSED_SEC);
        deleteStorageValue(KEY_PAUSED_TIMER_OFFSET_S);
        deleteStorageValue(KEY_PAUSE_START_TIMER_S);
        deleteStorageValue(KEY_PAUSE_START_CLOCK_TS);
        deleteStorageValue(LEGACY_KEY_INTAKE_LOG);
        deleteStorageValue(LEGACY_KEY_LAST_LAP_SNAPSHOT);
    }

    function clearSession() as Void {
        clearActiveSession();
        clearRecoverySnapshot();
    }

    function hasActiveSession() as Boolean {
        return getSessionId() != null && getStartTimestamp() != null;
    }
}
