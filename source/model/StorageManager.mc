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
    private const KEY_ACTIVE_SESSION_V2 = "active_v2";

    public const ACTIVE_SESSION_KEY_VERSION = "v";
    public const ACTIVE_SESSION_KEY_SESSION_ID = "i";
    public const ACTIVE_SESSION_KEY_START_TIMESTAMP = "s";
    public const ACTIVE_SESSION_KEY_START_CONFIRMED = "f";
    public const ACTIVE_SESSION_KEY_CONSUMED_G10 = "c";
    public const ACTIVE_SESSION_KEY_STATE = "q";
    public const ACTIVE_SESSION_KEY_LAST_INTAKE = "l";
    public const ACTIVE_SESSION_KEY_LAST_REMINDER = "r";
    public const ACTIVE_SESSION_KEY_INTAKE_COUNT = "n";
    public const ACTIVE_SESSION_KEY_PAUSED = "p";
    public const ACTIVE_SESSION_KEY_ELAPSED_SEC = "e";
    public const ACTIVE_SESSION_KEY_PAUSED_OFFSET_SEC = "o";
    public const ACTIVE_SESSION_KEY_PAUSE_START_TIMER = "t";
    public const ACTIVE_SESSION_KEY_PAUSE_START_CLOCK = "k";
    public const ACTIVE_SESSION_KEY_USING_ELAPSED = "u";
    public const ACTIVE_SESSION_KEY_LATEST_CALORIES = "a";
    public const ACTIVE_SESSION_KEY_LATEST_ENERGY_RATE = "g";
    public const ACTIVE_SESSION_KEY_CALORIES_AVAILABLE = "d";
    public const ACTIVE_SESSION_KEY_FINAL_TARGET_G10 = "x";
    public const ACTIVE_SESSION_VERSION = 2;
    public const ACTIVE_SESSION_UNKNOWN_STATE = -1;
    public const ACTIVE_SESSION_UNKNOWN_TARGET_G10 = -1;

    private const KEY_RECOVERY_TARGET_G10 = "snap_tgt10";
    private const KEY_RECOVERY_CONSUMED_G10 = "snap_con10";
    private const KEY_RECOVERY_ELAPSED_SEC = "snap_elapsed";
    private const KEY_RECOVERY_INTAKE_COUNT = "snap_count";
    private const KEY_RECOVERY_SNAPSHOT_V2 = "recovery_v2";
    private const SNAPSHOT_KEY_VERSION = "v";
    private const SNAPSHOT_KEY_TARGET = "t";
    private const SNAPSHOT_KEY_CONSUMED = "c";
    private const SNAPSHOT_KEY_ELAPSED = "e";
    private const SNAPSHOT_KEY_COUNT = "n";
    private const SNAPSHOT_KEY_SESSION_ID = "i";
    private const RECOVERY_SNAPSHOT_LEGACY_VERSION = 2;
    private const RECOVERY_SNAPSHOT_VERSION = 3;

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
    private var _activeSnapshotCache as Dictionary? = null;
    private var _activeSnapshotCacheLoaded as Boolean = false;
    private var _legacyActiveValuesRetired as Boolean = false;
    private var _recoverySnapshotCache as Dictionary? = null;
    private var _recoverySnapshotCacheLoaded as Boolean = false;

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
                                        min as Number, max as Number) as Boolean {
        try {
            _propertiesBackend.setValue(key, roundToInt(clamp(value, min, max)));
            return true;
        } catch (e) {
            recordWriteFailure(key, "set property");
        }
        return false;
    }

    private function deleteStorageValue(key as String) as Boolean {
        try {
            _storageBackend.deleteValue(key);
            if (_storageBackend.getValue(key) == null) {
                return true;
            }
        } catch (e) {
            recordWriteFailure(key, "delete value");
            return false;
        }
        recordWriteFailure(key, "verify deletion");
        return false;
    }

    private function getDictionaryNumber(value as Dictionary, key as String) as Number? {
        var entry = value[key];
        if (entry instanceof Number) {
            return entry;
        }
        return null;
    }

    private function getDictionaryFloat(value as Dictionary, key as String) as Float? {
        var entry = value[key];
        if (entry instanceof Float) {
            return entry;
        }
        if (entry instanceof Number) {
            return entry.toFloat();
        }
        return null;
    }

    private function getDictionaryBoolean(value as Dictionary, key as String) as Boolean? {
        var entry = value[key];
        if (entry instanceof Boolean) {
            return entry;
        }
        return null;
    }

    private function isValidActiveSessionSnapshot(snapshot as Dictionary) as Boolean {
        var version = getDictionaryNumber(snapshot, ACTIVE_SESSION_KEY_VERSION);
        var sessionId = getDictionaryNumber(snapshot, ACTIVE_SESSION_KEY_SESSION_ID);
        var startTimestamp = getDictionaryNumber(snapshot, ACTIVE_SESSION_KEY_START_TIMESTAMP);
        var consumedG10 = getDictionaryNumber(snapshot, ACTIVE_SESSION_KEY_CONSUMED_G10);
        var state = getDictionaryNumber(snapshot, ACTIVE_SESSION_KEY_STATE);
        var lastIntake = getDictionaryNumber(snapshot, ACTIVE_SESSION_KEY_LAST_INTAKE);
        var lastReminder = getDictionaryNumber(snapshot, ACTIVE_SESSION_KEY_LAST_REMINDER);
        var intakeCount = getDictionaryNumber(snapshot, ACTIVE_SESSION_KEY_INTAKE_COUNT);
        var elapsedSec = getDictionaryNumber(snapshot, ACTIVE_SESSION_KEY_ELAPSED_SEC);
        var pausedOffsetSec = getDictionaryNumber(snapshot, ACTIVE_SESSION_KEY_PAUSED_OFFSET_SEC);
        var pauseStartTimer = getDictionaryNumber(snapshot, ACTIVE_SESSION_KEY_PAUSE_START_TIMER);
        var pauseStartClock = getDictionaryNumber(snapshot, ACTIVE_SESSION_KEY_PAUSE_START_CLOCK);
        var latestCalories = getDictionaryNumber(snapshot, ACTIVE_SESSION_KEY_LATEST_CALORIES);
        var latestEnergyRate = getDictionaryFloat(snapshot, ACTIVE_SESSION_KEY_LATEST_ENERGY_RATE);
        var finalTargetG10 = getDictionaryNumber(snapshot, ACTIVE_SESSION_KEY_FINAL_TARGET_G10);

        if (version == null || version != ACTIVE_SESSION_VERSION ||
            sessionId == null || sessionId <= 0 ||
            startTimestamp == null || startTimestamp <= 0 ||
            consumedG10 == null || consumedG10 < 0 ||
            state == null || state < ACTIVE_SESSION_UNKNOWN_STATE ||
            lastIntake == null || lastIntake < 0 ||
            lastReminder == null || lastReminder < 0 ||
            intakeCount == null || intakeCount < 0 ||
            elapsedSec == null || elapsedSec < 0 ||
            pausedOffsetSec == null || pausedOffsetSec < 0 ||
            pauseStartTimer == null || pauseStartTimer < 0 ||
            pauseStartClock == null || pauseStartClock < 0 ||
            latestCalories == null || latestCalories < 0 ||
            latestEnergyRate == null || latestEnergyRate < 0.0f ||
            finalTargetG10 == null ||
            finalTargetG10 < ACTIVE_SESSION_UNKNOWN_TARGET_G10) {
            return false;
        }

        return getDictionaryBoolean(snapshot, ACTIVE_SESSION_KEY_START_CONFIRMED) != null &&
               getDictionaryBoolean(snapshot, ACTIVE_SESSION_KEY_PAUSED) != null &&
               getDictionaryBoolean(snapshot, ACTIVE_SESSION_KEY_USING_ELAPSED) != null &&
               getDictionaryBoolean(snapshot, ACTIVE_SESSION_KEY_CALORIES_AVAILABLE) != null;
    }

    private function activeSessionSnapshotMatches(expected as Dictionary,
                                                   actual as Dictionary) as Boolean {
        return getDictionaryNumber(expected, ACTIVE_SESSION_KEY_VERSION) ==
                   getDictionaryNumber(actual, ACTIVE_SESSION_KEY_VERSION) &&
               getDictionaryNumber(expected, ACTIVE_SESSION_KEY_SESSION_ID) ==
                   getDictionaryNumber(actual, ACTIVE_SESSION_KEY_SESSION_ID) &&
               getDictionaryNumber(expected, ACTIVE_SESSION_KEY_START_TIMESTAMP) ==
                   getDictionaryNumber(actual, ACTIVE_SESSION_KEY_START_TIMESTAMP) &&
               getDictionaryBoolean(expected, ACTIVE_SESSION_KEY_START_CONFIRMED) ==
                   getDictionaryBoolean(actual, ACTIVE_SESSION_KEY_START_CONFIRMED) &&
               getDictionaryNumber(expected, ACTIVE_SESSION_KEY_CONSUMED_G10) ==
                   getDictionaryNumber(actual, ACTIVE_SESSION_KEY_CONSUMED_G10) &&
               getDictionaryNumber(expected, ACTIVE_SESSION_KEY_STATE) ==
                   getDictionaryNumber(actual, ACTIVE_SESSION_KEY_STATE) &&
               getDictionaryNumber(expected, ACTIVE_SESSION_KEY_LAST_INTAKE) ==
                   getDictionaryNumber(actual, ACTIVE_SESSION_KEY_LAST_INTAKE) &&
               getDictionaryNumber(expected, ACTIVE_SESSION_KEY_LAST_REMINDER) ==
                   getDictionaryNumber(actual, ACTIVE_SESSION_KEY_LAST_REMINDER) &&
               getDictionaryNumber(expected, ACTIVE_SESSION_KEY_INTAKE_COUNT) ==
                   getDictionaryNumber(actual, ACTIVE_SESSION_KEY_INTAKE_COUNT) &&
               getDictionaryBoolean(expected, ACTIVE_SESSION_KEY_PAUSED) ==
                   getDictionaryBoolean(actual, ACTIVE_SESSION_KEY_PAUSED) &&
               getDictionaryNumber(expected, ACTIVE_SESSION_KEY_ELAPSED_SEC) ==
                   getDictionaryNumber(actual, ACTIVE_SESSION_KEY_ELAPSED_SEC) &&
               getDictionaryNumber(expected, ACTIVE_SESSION_KEY_PAUSED_OFFSET_SEC) ==
                   getDictionaryNumber(actual, ACTIVE_SESSION_KEY_PAUSED_OFFSET_SEC) &&
               getDictionaryNumber(expected, ACTIVE_SESSION_KEY_PAUSE_START_TIMER) ==
                   getDictionaryNumber(actual, ACTIVE_SESSION_KEY_PAUSE_START_TIMER) &&
               getDictionaryNumber(expected, ACTIVE_SESSION_KEY_PAUSE_START_CLOCK) ==
                   getDictionaryNumber(actual, ACTIVE_SESSION_KEY_PAUSE_START_CLOCK) &&
               getDictionaryBoolean(expected, ACTIVE_SESSION_KEY_USING_ELAPSED) ==
                   getDictionaryBoolean(actual, ACTIVE_SESSION_KEY_USING_ELAPSED) &&
               getDictionaryNumber(expected, ACTIVE_SESSION_KEY_LATEST_CALORIES) ==
                   getDictionaryNumber(actual, ACTIVE_SESSION_KEY_LATEST_CALORIES) &&
               getDictionaryFloat(expected, ACTIVE_SESSION_KEY_LATEST_ENERGY_RATE) ==
                   getDictionaryFloat(actual, ACTIVE_SESSION_KEY_LATEST_ENERGY_RATE) &&
               getDictionaryBoolean(expected, ACTIVE_SESSION_KEY_CALORIES_AVAILABLE) ==
                   getDictionaryBoolean(actual, ACTIVE_SESSION_KEY_CALORIES_AVAILABLE) &&
               getDictionaryNumber(expected, ACTIVE_SESSION_KEY_FINAL_TARGET_G10) ==
                   getDictionaryNumber(actual, ACTIVE_SESSION_KEY_FINAL_TARGET_G10);
    }

    private function loadStoredActiveSessionSnapshot() as Dictionary? {
        if (_activeSnapshotCacheLoaded) {
            return _activeSnapshotCache;
        }

        _activeSnapshotCacheLoaded = true;
        var storedValue = getStorageValue(KEY_ACTIVE_SESSION_V2);
        if (!(storedValue instanceof Dictionary) ||
            !isValidActiveSessionSnapshot(storedValue as Dictionary)) {
            _activeSnapshotCache = null;
            return null;
        }

        _activeSnapshotCache = storedValue as Dictionary;
        return _activeSnapshotCache;
    }

    private function getActiveSnapshotNumber(key as String) as Number? {
        var snapshot = loadStoredActiveSessionSnapshot();
        return (snapshot != null) ?
            getDictionaryNumber(snapshot as Dictionary, key) : null;
    }

    private function getActiveSnapshotBoolean(key as String) as Boolean? {
        var snapshot = loadStoredActiveSessionSnapshot();
        return (snapshot != null) ?
            getDictionaryBoolean(snapshot as Dictionary, key) : null;
    }

    private function retireLegacyActiveSessionValues() as Void {
        if (_legacyActiveValuesRetired) {
            return;
        }
        // A verified aggregate is now the sole active-session generation.
        // Cleanup is best effort: failure must not invalidate the committed
        // aggregate, but it is recorded for diagnostics.
        var success = true;
        if (!deleteStorageValue(KEY_SESSION_ID)) { success = false; }
        if (!deleteStorageValue(KEY_START_TIMESTAMP)) { success = false; }
        if (!deleteStorageValue(KEY_START_TS_CONFIRMED)) { success = false; }
        if (!deleteStorageValue(KEY_CONSUMED_TOTAL)) { success = false; }
        if (!deleteStorageValue(KEY_CONSUMED_TOTAL_G10)) { success = false; }
        if (!deleteStorageValue(KEY_SESSION_STATE)) { success = false; }
        if (!deleteStorageValue(KEY_LAST_INTAKE_TS)) { success = false; }
        if (!deleteStorageValue(KEY_LAST_REMINDER_TS)) { success = false; }
        if (!deleteStorageValue(KEY_INTAKE_COUNT)) { success = false; }
        if (!deleteStorageValue(KEY_IS_PAUSED)) { success = false; }
        if (!deleteStorageValue(KEY_ELAPSED_SEC)) { success = false; }
        if (!deleteStorageValue(KEY_PAUSED_TIMER_OFFSET_S)) { success = false; }
        if (!deleteStorageValue(KEY_PAUSE_START_TIMER_S)) { success = false; }
        if (!deleteStorageValue(KEY_PAUSE_START_CLOCK_TS)) { success = false; }
        if (!deleteStorageValue(LEGACY_KEY_INTAKE_LOG)) { success = false; }
        if (!deleteStorageValue(LEGACY_KEY_LAST_LAP_SNAPSHOT)) { success = false; }
        _legacyActiveValuesRetired = success;
    }

    function saveActiveSessionSnapshot(snapshot as Dictionary) as Boolean {
        snapshot[ACTIVE_SESSION_KEY_VERSION] = ACTIVE_SESSION_VERSION;
        if (!isValidActiveSessionSnapshot(snapshot)) {
            FuelPlannerLog.logWarn("Storage", "Rejected invalid active session snapshot");
            return false;
        }
        if (!setStorageValue(KEY_ACTIVE_SESSION_V2, snapshot)) {
            return false;
        }

        try {
            var storedValue = _storageBackend.getValue(KEY_ACTIVE_SESSION_V2);
            if (storedValue instanceof Dictionary) {
                var storedSnapshot = storedValue as Dictionary;
                if (isValidActiveSessionSnapshot(storedSnapshot) &&
                    activeSessionSnapshotMatches(snapshot, storedSnapshot)) {
                    _activeSnapshotCache = storedSnapshot;
                    _activeSnapshotCacheLoaded = true;
                    retireLegacyActiveSessionValues();
                    return true;
                }
            }
        } catch (e) {
            recordWriteFailure(KEY_ACTIVE_SESSION_V2, "verify snapshot");
            _activeSnapshotCacheLoaded = false;
            return false;
        }

        recordWriteFailure(KEY_ACTIVE_SESSION_V2, "verify snapshot");
        _activeSnapshotCacheLoaded = false;
        return false;
    }

    private function buildLegacyActiveSessionSnapshot() as Dictionary? {
        var sessionId = getSessionId();
        var startTimestamp = getStartTimestamp();
        if (sessionId == null || startTimestamp == null) {
            return null;
        }

        var state = getSessionState();
        var lastIntake = getLastIntakeTimestamp();
        var pauseStartTimer = getPauseStartTimerSec();
        var pauseStartClock = getPauseStartClockSec();
        var elapsedSec = getElapsedActiveSec();
        var pausedOffsetSec = getPausedTimerOffsetSec();
        return {
            ACTIVE_SESSION_KEY_VERSION => ACTIVE_SESSION_VERSION,
            ACTIVE_SESSION_KEY_SESSION_ID => sessionId,
            ACTIVE_SESSION_KEY_START_TIMESTAMP => startTimestamp,
            ACTIVE_SESSION_KEY_START_CONFIRMED => getIsStartTimestampConfirmed(),
            ACTIVE_SESSION_KEY_CONSUMED_G10 => getConsumedTotalG10(),
            ACTIVE_SESSION_KEY_STATE => (state != null) ? state : ACTIVE_SESSION_UNKNOWN_STATE,
            ACTIVE_SESSION_KEY_LAST_INTAKE => (lastIntake != null) ? lastIntake : 0,
            ACTIVE_SESSION_KEY_LAST_REMINDER => getLastReminderTimestamp(),
            ACTIVE_SESSION_KEY_INTAKE_COUNT => getIntakeCount(),
            ACTIVE_SESSION_KEY_PAUSED => getIsPaused(),
            ACTIVE_SESSION_KEY_ELAPSED_SEC => elapsedSec,
            ACTIVE_SESSION_KEY_PAUSED_OFFSET_SEC => pausedOffsetSec,
            ACTIVE_SESSION_KEY_PAUSE_START_TIMER => (pauseStartTimer != null) ? pauseStartTimer : 0,
            ACTIVE_SESSION_KEY_PAUSE_START_CLOCK => (pauseStartClock != null) ? pauseStartClock : 0,
            ACTIVE_SESSION_KEY_USING_ELAPSED => pauseStartTimer != null,
            ACTIVE_SESSION_KEY_LATEST_CALORIES => 0,
            ACTIVE_SESSION_KEY_LATEST_ENERGY_RATE => 0.0f,
            ACTIVE_SESSION_KEY_CALORIES_AVAILABLE => false,
            ACTIVE_SESSION_KEY_FINAL_TARGET_G10 => ACTIVE_SESSION_UNKNOWN_TARGET_G10
        };
    }

    function loadActiveSessionSnapshot() as Dictionary? {
        var storedSnapshot = loadStoredActiveSessionSnapshot();
        if (storedSnapshot != null) {
            return storedSnapshot;
        }

        var legacySnapshot = buildLegacyActiveSessionSnapshot();
        if (legacySnapshot == null) {
            return null;
        }

        // Migration is best effort; the validated legacy value remains readable
        // even when a device storage write temporarily fails.
        saveActiveSessionSnapshot(legacySnapshot as Dictionary);
        return legacySnapshot;
    }

    private function isValidRecoverySnapshot(snapshot as Dictionary) as Boolean {
        var version = getDictionaryNumber(snapshot, SNAPSHOT_KEY_VERSION);
        if (version == null ||
            (version != RECOVERY_SNAPSHOT_LEGACY_VERSION &&
             version != RECOVERY_SNAPSHOT_VERSION)) {
            return false;
        }

        if (version == RECOVERY_SNAPSHOT_VERSION) {
            var sessionId = getDictionaryNumber(snapshot, SNAPSHOT_KEY_SESSION_ID);
            if (sessionId == null || sessionId <= 0) {
                return false;
            }
        }

        var target = getDictionaryNumber(snapshot, SNAPSHOT_KEY_TARGET);
        if (target == null || target < 0) {
            return false;
        }

        var consumed = getDictionaryNumber(snapshot, SNAPSHOT_KEY_CONSUMED);
        if (consumed == null || consumed < 0) {
            return false;
        }

        var elapsed = getDictionaryNumber(snapshot, SNAPSHOT_KEY_ELAPSED);
        if (elapsed == null || elapsed <= 0) {
            return false;
        }

        var count = getDictionaryNumber(snapshot, SNAPSHOT_KEY_COUNT);
        if (count == null || count < 0) {
            return false;
        }
        return true;
    }

    private function recoverySnapshotMatches(snapshot as Dictionary,
                                             version as Number,
                                             sessionId as Number?,
                                             targetG10 as Number,
                                             consumedG10 as Number,
                                             elapsedSec as Number,
                                             intakeCount as Number) as Boolean {
        var storedVersion = getDictionaryNumber(snapshot, SNAPSHOT_KEY_VERSION);
        if (storedVersion == null || storedVersion != version) {
            return false;
        }
        if (version == RECOVERY_SNAPSHOT_VERSION) {
            var storedSessionId = getDictionaryNumber(snapshot, SNAPSHOT_KEY_SESSION_ID);
            if (sessionId == null || storedSessionId == null ||
                storedSessionId != sessionId) {
                return false;
            }
        }
        var target = getDictionaryNumber(snapshot, SNAPSHOT_KEY_TARGET);
        if (target == null || target != nonNegative(targetG10)) {
            return false;
        }
        var consumed = getDictionaryNumber(snapshot, SNAPSHOT_KEY_CONSUMED);
        if (consumed == null || consumed != nonNegative(consumedG10)) {
            return false;
        }
        var elapsed = getDictionaryNumber(snapshot, SNAPSHOT_KEY_ELAPSED);
        if (elapsed == null || elapsed != nonNegative(elapsedSec)) {
            return false;
        }
        var count = getDictionaryNumber(snapshot, SNAPSHOT_KEY_COUNT);
        if (count == null) {
            return false;
        }
        return count == nonNegative(intakeCount);
    }

    private function loadRecoverySnapshotV2() as Dictionary? {
        if (_recoverySnapshotCacheLoaded) {
            return _recoverySnapshotCache;
        }

        _recoverySnapshotCacheLoaded = true;
        var value = getStorageValue(KEY_RECOVERY_SNAPSHOT_V2);
        if (!(value instanceof Dictionary)) {
            _recoverySnapshotCache = null;
            return null;
        }

        var snapshot = value as Dictionary;
        if (!isValidRecoverySnapshot(snapshot)) {
            _recoverySnapshotCache = null;
            return null;
        }

        _recoverySnapshotCache = snapshot;
        return snapshot;
    }

    private function saveRecoverySnapshotInternal(version as Number,
                                                  sessionId as Number?,
                                                  targetG10 as Number,
                                                  consumedG10 as Number,
                                                  elapsedSec as Number,
                                                  intakeCount as Number) as Boolean {
        if (elapsedSec <= 0) {
            return false;
        }
        var snapshot = {
            SNAPSHOT_KEY_VERSION => version,
            SNAPSHOT_KEY_TARGET => nonNegative(targetG10),
            SNAPSHOT_KEY_CONSUMED => nonNegative(consumedG10),
            SNAPSHOT_KEY_ELAPSED => nonNegative(elapsedSec),
            SNAPSHOT_KEY_COUNT => nonNegative(intakeCount)
        };
        if (version == RECOVERY_SNAPSHOT_VERSION) {
            if (sessionId == null || sessionId <= 0) {
                return false;
            }
            snapshot[SNAPSHOT_KEY_SESSION_ID] = sessionId;
        }
        if (!setStorageValue(KEY_RECOVERY_SNAPSHOT_V2, snapshot)) {
            return false;
        }

        try {
            var storedValue = _storageBackend.getValue(KEY_RECOVERY_SNAPSHOT_V2);
            if (storedValue instanceof Dictionary) {
                var storedSnapshot = storedValue as Dictionary;
                if (isValidRecoverySnapshot(storedSnapshot) &&
                    recoverySnapshotMatches(storedSnapshot, version, sessionId,
                                            targetG10, consumedG10,
                                            elapsedSec, intakeCount)) {
                    _recoverySnapshotCache = storedSnapshot;
                    _recoverySnapshotCacheLoaded = true;
                    if (version == RECOVERY_SNAPSHOT_VERSION) {
                        // The verified aggregate is already authoritative. Stale
                        // legacy values must not reappear if it is later damaged.
                        deleteStorageValue(KEY_RECOVERY_TARGET_G10);
                        deleteStorageValue(KEY_RECOVERY_CONSUMED_G10);
                        deleteStorageValue(KEY_RECOVERY_ELAPSED_SEC);
                        deleteStorageValue(KEY_RECOVERY_INTAKE_COUNT);
                    }
                    return true;
                }
            }
        } catch (e) {
            recordWriteFailure(KEY_RECOVERY_SNAPSHOT_V2, "verify snapshot");
            _recoverySnapshotCacheLoaded = false;
            return false;
        }

        recordWriteFailure(KEY_RECOVERY_SNAPSHOT_V2, "verify snapshot");
        _recoverySnapshotCacheLoaded = false;
        return false;
    }

    function saveRecoverySnapshot(targetG10 as Number, consumedG10 as Number,
                                  elapsedSec as Number, intakeCount as Number) as Boolean {
        return saveRecoverySnapshotInternal(
            RECOVERY_SNAPSHOT_LEGACY_VERSION,
            null,
            targetG10,
            consumedG10,
            elapsedSec,
            intakeCount
        );
    }

    function saveRecoverySnapshotForSession(sessionId as Number,
                                            targetG10 as Number,
                                            consumedG10 as Number,
                                            elapsedSec as Number,
                                            intakeCount as Number) as Boolean {
        return saveRecoverySnapshotInternal(
            RECOVERY_SNAPSHOT_VERSION,
            sessionId,
            targetG10,
            consumedG10,
            elapsedSec,
            intakeCount
        );
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

    function setCarbsTargetGph(value as Number) as Boolean {
        return setClampedProperty("carbsTargetGph", value, MIN_CARBS_TARGET_GPH, MAX_CARBS_TARGET_GPH);
    }

    function getDoseG() as Number {
        return getClampedProperty(
            "doseG",
            DEFAULT_DOSE_G,
            MIN_DOSE_G,
            MAX_DOSE_G
        );
    }

    function setDoseG(value as Number) as Boolean {
        return setClampedProperty("doseG", value, MIN_DOSE_G, MAX_DOSE_G);
    }

    function getReminderMode() as Number {
        return getClampedProperty(
            "reminderMode",
            DEFAULT_REMINDER_MODE,
            MIN_REMINDER_MODE,
            MAX_REMINDER_MODE
        );
    }

    function setReminderMode(value as Number) as Boolean {
        return setClampedProperty("reminderMode", value, MIN_REMINDER_MODE, MAX_REMINDER_MODE);
    }

    function getFixedIntervalMin() as Number {
        return getClampedProperty(
            "fixedIntervalMin",
            DEFAULT_FIXED_INTERVAL_MIN,
            MIN_FIXED_INTERVAL_MIN,
            MAX_FIXED_INTERVAL_MIN
        );
    }

    function setFixedIntervalMin(value as Number) as Boolean {
        return setClampedProperty("fixedIntervalMin", value, MIN_FIXED_INTERVAL_MIN, MAX_FIXED_INTERVAL_MIN);
    }

    function getStartDelayMin() as Number {
        return getClampedProperty(
            "startDelayMin",
            DEFAULT_START_DELAY_MIN,
            MIN_START_DELAY_MIN,
            MAX_START_DELAY_MIN
        );
    }

    function setStartDelayMin(value as Number) as Boolean {
        return setClampedProperty("startDelayMin", value, MIN_START_DELAY_MIN, MAX_START_DELAY_MIN);
    }

    function getMaxSnoozeMin() as Number {
        return getClampedProperty(
            "maxSnoozeMin",
            DEFAULT_MAX_SNOOZE_MIN,
            MIN_MAX_SNOOZE_MIN,
            MAX_MAX_SNOOZE_MIN
        );
    }

    function setMaxSnoozeMin(value as Number) as Boolean {
        return setClampedProperty("maxSnoozeMin", value, MIN_MAX_SNOOZE_MIN, MAX_MAX_SNOOZE_MIN);
    }

    function getDataFieldAlertEnabled() as Number {
        return getClampedProperty(
            "dataFieldAlertEnabled",
            DEFAULT_DATA_FIELD_ALERT_ENABLED,
            MIN_DATA_FIELD_ALERT_ENABLED,
            MAX_DATA_FIELD_ALERT_ENABLED
        );
    }

    function setDataFieldAlertEnabled(value as Number) as Boolean {
        return setClampedProperty(
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

    function setCarbFractionPct(value as Number) as Boolean {
        return setClampedProperty("carbFractionPct", value, MIN_CARB_FRACTION_PCT, MAX_CARB_FRACTION_PCT);
    }


    // ========== Session Data (in Storage) ==========

    function getSessionId() as Number? {
        var activeValue = getActiveSnapshotNumber(ACTIVE_SESSION_KEY_SESSION_ID);
        if (activeValue != null && activeValue > 0) {
            return activeValue;
        }
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
        var activeValue = getActiveSnapshotNumber(ACTIVE_SESSION_KEY_START_TIMESTAMP);
        if (activeValue != null && activeValue > 0) {
            return activeValue;
        }
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
        var activeValue = getActiveSnapshotBoolean(ACTIVE_SESSION_KEY_START_CONFIRMED);
        if (activeValue != null) {
            return activeValue;
        }
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
        var activeValue = getActiveSnapshotNumber(ACTIVE_SESSION_KEY_CONSUMED_G10);
        if (activeValue != null) {
            return nonNegative(activeValue + 5) / 10;
        }
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
        var activeValue = getActiveSnapshotNumber(ACTIVE_SESSION_KEY_CONSUMED_G10);
        if (activeValue != null) {
            return nonNegative(activeValue);
        }
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
        var activeValue = getActiveSnapshotNumber(ACTIVE_SESSION_KEY_STATE);
        if (activeValue != null) {
            return (activeValue >= 0) ? activeValue : null;
        }
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
        var activeValue = getActiveSnapshotNumber(ACTIVE_SESSION_KEY_LAST_INTAKE);
        if (activeValue != null) {
            return (activeValue > 0) ? activeValue : null;
        }
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
        var activeValue = getActiveSnapshotNumber(ACTIVE_SESSION_KEY_LAST_REMINDER);
        if (activeValue != null) {
            return nonNegative(activeValue);
        }
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
        var activeValue = getActiveSnapshotBoolean(ACTIVE_SESSION_KEY_PAUSED);
        if (activeValue != null) {
            return activeValue;
        }
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
        var activeValue = getActiveSnapshotNumber(ACTIVE_SESSION_KEY_ELAPSED_SEC);
        if (activeValue != null) {
            return nonNegative(activeValue);
        }
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
        var activeValue = getActiveSnapshotNumber(ACTIVE_SESSION_KEY_PAUSED_OFFSET_SEC);
        if (activeValue != null) {
            return nonNegative(activeValue);
        }
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
        var activeValue = getActiveSnapshotNumber(ACTIVE_SESSION_KEY_PAUSE_START_TIMER);
        if (activeValue != null) {
            return (activeValue > 0) ? activeValue : null;
        }
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
        var activeValue = getActiveSnapshotNumber(ACTIVE_SESSION_KEY_PAUSE_START_CLOCK);
        if (activeValue != null) {
            return (activeValue > 0) ? activeValue : null;
        }
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
        var activeValue = getActiveSnapshotNumber(ACTIVE_SESSION_KEY_INTAKE_COUNT);
        if (activeValue != null) {
            return nonNegative(activeValue);
        }
        var value = getStorageValue(KEY_INTAKE_COUNT);
        if (value instanceof Number) {
            return nonNegative(value);
        }
        return 0;
    }

    function setIntakeCount(value as Number) as Void {
        setStorageValue(KEY_INTAKE_COUNT, nonNegative(value));
    }

    function getRecoverySessionId() as Number? {
        var snapshot = loadRecoverySnapshotV2();
        if (snapshot == null) {
            return null;
        }
        var version = getDictionaryNumber(snapshot as Dictionary, SNAPSHOT_KEY_VERSION);
        if (version != RECOVERY_SNAPSHOT_VERSION) {
            return null;
        }
        var sessionId = getDictionaryNumber(snapshot as Dictionary, SNAPSHOT_KEY_SESSION_ID);
        return (sessionId != null && sessionId > 0) ? sessionId : null;
    }

    function getRecoveryTargetG10() as Number {
        var snapshot = loadRecoverySnapshotV2();
        if (snapshot != null) {
            var snapshotValue = getDictionaryNumber(snapshot as Dictionary, SNAPSHOT_KEY_TARGET);
            if (snapshotValue != null) {
                return nonNegative(snapshotValue);
            }
        }
        var value = getStorageValue(KEY_RECOVERY_TARGET_G10);
        if (value instanceof Number) {
            return nonNegative(value);
        }
        return 0;
    }

    function setRecoveryTargetG10(value as Number) as Void {
        deleteStorageValue(KEY_RECOVERY_SNAPSHOT_V2);
        _recoverySnapshotCache = null;
        _recoverySnapshotCacheLoaded = true;
        setStorageValue(KEY_RECOVERY_TARGET_G10, nonNegative(value));
    }

    function getRecoveryConsumedG10() as Number {
        var snapshot = loadRecoverySnapshotV2();
        if (snapshot != null) {
            var snapshotValue = getDictionaryNumber(snapshot as Dictionary, SNAPSHOT_KEY_CONSUMED);
            if (snapshotValue != null) {
                return nonNegative(snapshotValue);
            }
        }
        var value = getStorageValue(KEY_RECOVERY_CONSUMED_G10);
        if (value instanceof Number) {
            return nonNegative(value);
        }
        return 0;
    }

    function setRecoveryConsumedG10(value as Number) as Void {
        deleteStorageValue(KEY_RECOVERY_SNAPSHOT_V2);
        _recoverySnapshotCache = null;
        _recoverySnapshotCacheLoaded = true;
        setStorageValue(KEY_RECOVERY_CONSUMED_G10, nonNegative(value));
    }

    function getRecoveryElapsedSec() as Number {
        var snapshot = loadRecoverySnapshotV2();
        if (snapshot != null) {
            var snapshotValue = getDictionaryNumber(snapshot as Dictionary, SNAPSHOT_KEY_ELAPSED);
            if (snapshotValue != null) {
                return nonNegative(snapshotValue);
            }
        }
        var value = getStorageValue(KEY_RECOVERY_ELAPSED_SEC);
        if (value instanceof Number) {
            return nonNegative(value);
        }
        return 0;
    }

    function setRecoveryElapsedSec(value as Number) as Void {
        deleteStorageValue(KEY_RECOVERY_SNAPSHOT_V2);
        _recoverySnapshotCache = null;
        _recoverySnapshotCacheLoaded = true;
        setStorageValue(KEY_RECOVERY_ELAPSED_SEC, nonNegative(value));
    }

    function getRecoveryIntakeCount() as Number {
        var snapshot = loadRecoverySnapshotV2();
        if (snapshot != null) {
            var snapshotValue = getDictionaryNumber(snapshot as Dictionary, SNAPSHOT_KEY_COUNT);
            if (snapshotValue != null) {
                return nonNegative(snapshotValue);
            }
        }
        var value = getStorageValue(KEY_RECOVERY_INTAKE_COUNT);
        if (value instanceof Number) {
            return nonNegative(value);
        }
        return 0;
    }

    function setRecoveryIntakeCount(value as Number) as Void {
        deleteStorageValue(KEY_RECOVERY_SNAPSHOT_V2);
        _recoverySnapshotCache = null;
        _recoverySnapshotCacheLoaded = true;
        setStorageValue(KEY_RECOVERY_INTAKE_COUNT, nonNegative(value));
    }

    function hasRecoverySnapshot() as Boolean {
        return loadRecoverySnapshotV2() != null || getRecoveryElapsedSec() > 0;
    }

    function clearRecoverySnapshot() as Boolean {
        var success = true;
        if (!deleteStorageValue(KEY_RECOVERY_TARGET_G10)) { success = false; }
        if (!deleteStorageValue(KEY_RECOVERY_CONSUMED_G10)) { success = false; }
        if (!deleteStorageValue(KEY_RECOVERY_ELAPSED_SEC)) { success = false; }
        if (!deleteStorageValue(KEY_RECOVERY_INTAKE_COUNT)) { success = false; }

        // Keep the aggregate source of truth until all legacy cleanup succeeds.
        if (success && !deleteStorageValue(KEY_RECOVERY_SNAPSHOT_V2)) {
            success = false;
        }
        if (success) {
            _recoverySnapshotCache = null;
            _recoverySnapshotCacheLoaded = true;
        } else {
            _recoverySnapshotCacheLoaded = false;
        }
        return success;
    }

    // ========== Session Management ==========

    function clearActiveSession() as Boolean {
        var success = true;
        if (!deleteStorageValue(KEY_SESSION_ID)) { success = false; }
        if (!deleteStorageValue(KEY_START_TIMESTAMP)) { success = false; }
        if (!deleteStorageValue(KEY_START_TS_CONFIRMED)) { success = false; }
        if (!deleteStorageValue(KEY_CONSUMED_TOTAL)) { success = false; }
        if (!deleteStorageValue(KEY_CONSUMED_TOTAL_G10)) { success = false; }
        if (!deleteStorageValue(KEY_SESSION_STATE)) { success = false; }
        if (!deleteStorageValue(KEY_LAST_INTAKE_TS)) { success = false; }
        if (!deleteStorageValue(KEY_LAST_REMINDER_TS)) { success = false; }
        if (!deleteStorageValue(KEY_INTAKE_COUNT)) { success = false; }
        if (!deleteStorageValue(KEY_IS_PAUSED)) { success = false; }
        if (!deleteStorageValue(KEY_ELAPSED_SEC)) { success = false; }
        if (!deleteStorageValue(KEY_PAUSED_TIMER_OFFSET_S)) { success = false; }
        if (!deleteStorageValue(KEY_PAUSE_START_TIMER_S)) { success = false; }
        if (!deleteStorageValue(KEY_PAUSE_START_CLOCK_TS)) { success = false; }
        if (!deleteStorageValue(LEGACY_KEY_INTAKE_LOG)) { success = false; }
        if (!deleteStorageValue(LEGACY_KEY_LAST_LAP_SNAPSHOT)) { success = false; }

        // A valid aggregate prevents partially cleared legacy keys from becoming
        // the source of truth after a failed cleanup.
        if (success && !deleteStorageValue(KEY_ACTIVE_SESSION_V2)) {
            success = false;
        }
        if (success) {
            _activeSnapshotCache = null;
            _activeSnapshotCacheLoaded = true;
            _legacyActiveValuesRetired = true;
        } else {
            _activeSnapshotCacheLoaded = false;
            _legacyActiveValuesRetired = false;
        }
        return success;
    }

    function clearSession() as Boolean {
        var activeCleared = clearActiveSession();
        var recoveryCleared = clearRecoverySnapshot();
        return activeCleared && recoveryCleared;
    }

    function hasActiveSession() as Boolean {
        return loadActiveSessionSnapshot() != null;
    }
}
