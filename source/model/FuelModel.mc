import Toybox.Lang;
import Toybox.Time;
import Toybox.Activity;
import Toybox.FitContributor;
import Toybox.System;
import Toybox.WatchUi;
import FuelPlannerLog;
import FuelReminderModes;

// Module-level constants: stored in bytecode, not per-instance heap
module FuelModelConsts {
    const FIT_UPDATE_INTERVAL_MS          = 5000;
    const TIMER_BACKTRACK_RESET_DELTA_SEC = 30;
    const TIMER_BACKTRACK_CONFIRM_TICKS   = 4;
    const TIMER_RESET_LOW_WINDOW_SEC      = 8;
    const MAX_ELAPSED_ACTIVE_SEC          = 604800; // 7 days
    const MAX_TOTAL_G10                   = 200000; // 20,000 g
    const MAX_NEXT_DUE_SEC                = 359999; // 99h 59m 59s
    const MAX_CALORIES_KCAL               = 20000;
    const MAX_ENERGY_RATE_KCAL_MIN        = 40.0f;
    const MAX_MANUAL_INTAKE_G             = 200;
    const TOUCH_REFRESH_INTERVAL_MS       = 15000;
    const TIMER_SOURCE_SWITCH_GRACE_SEC   = 2;
    const PRIMING_CONFIRM_SEC = 3;
    const UNDO_WINDOW_SEC = 10;
}

class FuelClock {
    function initialize() {
    }

    function now() as Number {
        return Time.now().value();
    }
}

//! Core calculation model for fuel planning
class FuelModel {
    // Reminder modes (class-level const — class prototype, not per-instance heap)
    public const MODE_AUTO         = FuelReminderModes.AUTO;         // deficit-based with fixed g/h target
    public const MODE_FIXED        = FuelReminderModes.FIXED;        // fixed interval from last intake
    public const MODE_CALORIE_AUTO = FuelReminderModes.CALORIE_AUTO; // target derived from device calorie data
    public const RING_TONE_GREEN   = 0;
    public const RING_TONE_YELLOW  = 1;
    public const RING_TONE_RED     = 2;

    // Explicit session states
    public const STATE_IDLE = 0;
    public const STATE_PRIMING = 1;
    public const STATE_ACTIVE = 2;
    public const STATE_PAUSED = 3;
    public const STATE_FINISHED = 4;

    // State
    private var _storage              as StorageManager;
    private var _clock                as FuelClock;
    private var _sessionActive        as Boolean = false;
    private var _sessionRecoverable   as Boolean = false;
    private var _startTimestamp       as Number  = 0;
    private var _sessionState as Number = STATE_IDLE;
    private var _sessionFinishHandled as Boolean = false;
    // Internally tracked in tenths of grams (g10)
    private var _consumedTotalG       as Number  = 0;
    private var _lastIntakeTimestamp  as Number  = 0;
    private var _isPaused             as Boolean = false;
    private var _sessionId            as Number  = 0;
    private var _isStartTimestampConfirmed as Boolean = false;
    private var _intakeCount          as Number  = 0;
    private var _isTouch              as Boolean = false;
    private var _lastTouchRefreshMs   as Number = 0;
    private var _autoIntakeLocked     as Boolean = false;
    private var _autoIntakeEventPending as Boolean = false;
    private var _fitFieldDeficit      as FitContributor.Field? = null;
    private var _fitFieldConsumed     as FitContributor.Field? = null;
    private var _fitFieldTargetSummary as FitContributor.Field? = null;
    private var _fitFieldActualSummary as FitContributor.Field? = null;
    private var _lastFitFieldUpdateMs as Number = 0;
    private var _forceNextFitFieldUpdate as Boolean = true;

    // Cached settings (_carbsTargetGph10 / _doseG10 computed on-the-fly to save heap slots)
    private var _carbsTargetGph    as Number = 60;
    private var _doseG             as Number = 25;
    private var _reminderMode      as Number = FuelReminderModes.AUTO;
    private var _fixedIntervalMin  as Number = 20;
    private var _startDelayMin     as Number = 15;
    private var _maxSnoozeMin      as Number = 5;
    private var _dataFieldAlertEnabled as Boolean = false;
    private var _carbFractionPct   as Number = 60;  // % of kcal from carbs (40-80)

    // Last reminder timestamp (for snooze)
    private var _lastReminderTimestamp as Number = 0;

    // Computed values (updated each tick; _elapsedActiveHours derived on-the-fly)
    private var _elapsedActiveSec    as Number  = 0;
    private var _targetTotalG        as Number  = 0; // g10
    private var _deficitG            as Number  = 0; // g10
    private var _nextDueInSec        as Number  = 0;
    private var _isReminderDue       as Boolean = false;
    private var _pauseStartClockTs   as Number? = null;
    private var _recoverySnapshotAvailable as Boolean = false;
    private var _recoverySnapshotTargetG10 as Number = 0;
    private var _recoverySnapshotConsumedG10 as Number = 0;
    private var _recoverySnapshotElapsedSec as Number = 0;
    private var _recoverySnapshotIntakeCount as Number = 0;

    // Calorie-auto mode: latest values from Activity.Info
    private var _latestCaloriesKcal      as Number = 0;   // cumulative kcal burned
    private var _latestEnergyExpKcalMin  as Float  = 0.0f; // current kcal/min
    private var _caloriesAvailable       as Boolean = false;
    private var _calorieDataMissingTicks as Number = 0;
    private var _calorieAutoSuspendedUntilSec as Number = 0; // Recovery: Wann erneut auf Calorie Auto prüfen
    private const CALORIE_FALLBACK_TICKS = 300; // 5 Minuten bei 1Hz
    private const CALORIE_SUSPEND_DURATION_SEC = 600; // 10 Minuten Sperre vor Recovery-Versuch
    private const RING_WARNING_MIN_SEC = 180;
    private const RING_WARNING_MAX_SEC = 600;

    // For pause detection
    private var _lastTimerTime      as Number = 0;
    private var _timerStallCount    as Number = 0;
    private var _pausedTimerOffsetS as Number = 0;
    private var _pauseStartTimerS   as Number? = null;
    private var _timerBacktrackCount as Number = 0;
    private var _usingElapsedTimeFallback as Boolean = false;
    private var _timerSourceChangedToElapsed as Boolean = false;
    private var _timerTimeAdjustmentS as Number = 0;
    private var _timerStartEventPending as Boolean = false;
    private var _hasValidTimerData as Boolean = false;

    // For undo functionality
    private var _undoAvailable      as Boolean = false;
    private var _undoGramsG10       as Number = 0;
    private var _undoTimestamp      as Number = 0;

    //! Constructor
    function initialize(storage as StorageManager, clock as FuelClock?) {
        _storage = storage;
        _clock = (clock != null) ? clock : new FuelClock();
        refreshTouchMode(true);
        loadSettings();
    }

    //! Load settings from storage
    function loadSettings() as Void {
        _carbsTargetGph   = clampSetting(
            _storage.getCarbsTargetGph(),
            _storage.MIN_CARBS_TARGET_GPH,
            _storage.MAX_CARBS_TARGET_GPH
        );
        _doseG            = clampSetting(
            _storage.getDoseG(),
            _storage.MIN_DOSE_G,
            _storage.MAX_DOSE_G
        );
        _reminderMode     = clampSetting(
            _storage.getReminderMode(),
            _storage.MIN_REMINDER_MODE,
            _storage.MAX_REMINDER_MODE
        );
        _fixedIntervalMin = clampSetting(
            _storage.getFixedIntervalMin(),
            _storage.MIN_FIXED_INTERVAL_MIN,
            _storage.MAX_FIXED_INTERVAL_MIN
        );
        _startDelayMin    = clampSetting(
            _storage.getStartDelayMin(),
            _storage.MIN_START_DELAY_MIN,
            _storage.MAX_START_DELAY_MIN
        );
        _maxSnoozeMin     = clampSetting(
            _storage.getMaxSnoozeMin(),
            _storage.MIN_MAX_SNOOZE_MIN,
            _storage.MAX_MAX_SNOOZE_MIN
        );
        _dataFieldAlertEnabled = _storage.getDataFieldAlertEnabled() != 0;
        _carbFractionPct  = clampSetting(
            _storage.getCarbFractionPct(),
            _storage.MIN_CARB_FRACTION_PCT,
            _storage.MAX_CARB_FRACTION_PCT
        );
    }

    //! Called when settings change externally (e.g., Garmin Connect phone app).
    //! Refreshes configuration immediately without resetting session state.
    function onSettingsChanged() as Void {
        refreshTouchMode(true);
        loadSettings();
        _calorieDataMissingTicks = 0;
        _calorieAutoSuspendedUntilSec = 0;
        if (_sessionActive) {
            recalculateFromCurrentState();
            _forceNextFitFieldUpdate = true;
        }
    }

    function setFitFields(fieldDeficit as FitContributor.Field?,
                          fieldConsumed as FitContributor.Field?,
                          fieldTargetSummary as FitContributor.Field?,
                          fieldActualSummary as FitContributor.Field?) as Void {
        _fitFieldDeficit = fieldDeficit;
        _fitFieldConsumed = fieldConsumed;
        _fitFieldTargetSummary = fieldTargetSummary;
        _fitFieldActualSummary = fieldActualSummary;
        _forceNextFitFieldUpdate = true;
        flushFitSessionSummary();
    }

    private function activeSnapshotNumber(snapshot as Dictionary, key as String,
                                          defaultValue as Number) as Number {
        var value = snapshot[key];
        return (value instanceof Number) ? value : defaultValue;
    }


    private function activeSnapshotBoolean(snapshot as Dictionary, key as String,
                                           defaultValue as Boolean) as Boolean {
        var value = snapshot[key];
        return (value instanceof Boolean) ? value : defaultValue;
    }


    private function activeSnapshotFloat(snapshot as Dictionary, key as String,
                                         defaultValue as Float) as Float {
        var value = snapshot[key];
        if (value instanceof Float) {
            return value;
        }
        if (value instanceof Number) {
            return value.toFloat();
        }
        return defaultValue;
    }


    //! Load session from storage
    function loadSession() as Void {
        clearRecoverySnapshotState();

        var storedActiveSession = _storage.loadActiveSessionSnapshot();
        if (storedActiveSession == null) {
            if (_storage.hasRecoverySnapshot()) {
                loadRecoverySnapshot();
                return;
            }
            if (_sessionActive || _sessionState != STATE_IDLE) {
                clearSessionState();
            }
            return;
        }

        var activeSnapshot = storedActiveSession as Dictionary;
        var sessionId = activeSnapshotNumber(
            activeSnapshot,
            _storage.ACTIVE_SESSION_KEY_SESSION_ID,
            0
        );
        var startTs = activeSnapshotNumber(
            activeSnapshot,
            _storage.ACTIVE_SESSION_KEY_START_TIMESTAMP,
            0
        );

        if (sessionId > 0 && startTs > 0) {
            var safeNow = getCurrentTimestamp();
            if (safeNow < startTs) {
                safeNow = startTs;
            }

            _sessionId           = sessionId;
            _startTimestamp      = startTs;
            _consumedTotalG      = clampNonNegativeTotalG10(activeSnapshotNumber(
                activeSnapshot,
                _storage.ACTIVE_SESSION_KEY_CONSUMED_G10,
                0
            ));

            var lastIntake = activeSnapshotNumber(
                activeSnapshot,
                _storage.ACTIVE_SESSION_KEY_LAST_INTAKE,
                0
            );
            _lastIntakeTimestamp = (lastIntake > 0) ? lastIntake : _startTimestamp;
            if (_lastIntakeTimestamp < _startTimestamp) {
                _lastIntakeTimestamp = _startTimestamp;
            } else if (_lastIntakeTimestamp > safeNow) {
                _lastIntakeTimestamp = safeNow;
            }

            _isPaused = activeSnapshotBoolean(
                activeSnapshot,
                _storage.ACTIVE_SESSION_KEY_PAUSED,
                false
            );
            _elapsedActiveSec = clampElapsedActiveSec(activeSnapshotNumber(
                activeSnapshot,
                _storage.ACTIVE_SESSION_KEY_ELAPSED_SEC,
                0
            ));
            _pausedTimerOffsetS = clampElapsedActiveSec(activeSnapshotNumber(
                activeSnapshot,
                _storage.ACTIVE_SESSION_KEY_PAUSED_OFFSET_SEC,
                0
            ));
            var pauseStartTimer = activeSnapshotNumber(
                activeSnapshot,
                _storage.ACTIVE_SESSION_KEY_PAUSE_START_TIMER,
                0
            );
            _pauseStartTimerS = (pauseStartTimer > 0) ? pauseStartTimer : null;
            var pauseStartClock = activeSnapshotNumber(
                activeSnapshot,
                _storage.ACTIVE_SESSION_KEY_PAUSE_START_CLOCK,
                0
            );
            _pauseStartClockTs = (pauseStartClock > 0) ? pauseStartClock : null;
            _isStartTimestampConfirmed = activeSnapshotBoolean(
                activeSnapshot,
                _storage.ACTIVE_SESSION_KEY_START_CONFIRMED,
                false
            );
            _intakeCount = activeSnapshotNumber(
                activeSnapshot,
                _storage.ACTIVE_SESSION_KEY_INTAKE_COUNT,
                0
            );
            _lastReminderTimestamp = activeSnapshotNumber(
                activeSnapshot,
                _storage.ACTIVE_SESSION_KEY_LAST_REMINDER,
                0
            );
            _usingElapsedTimeFallback = activeSnapshotBoolean(
                activeSnapshot,
                _storage.ACTIVE_SESSION_KEY_USING_ELAPSED,
                false
            );
            _timerSourceChangedToElapsed = false;
            _timerTimeAdjustmentS = 0;
            _latestCaloriesKcal = clampSetting(activeSnapshotNumber(
                activeSnapshot,
                _storage.ACTIVE_SESSION_KEY_LATEST_CALORIES,
                0
            ), 0, FuelModelConsts.MAX_CALORIES_KCAL);
            _latestEnergyExpKcalMin = activeSnapshotFloat(
                activeSnapshot,
                _storage.ACTIVE_SESSION_KEY_LATEST_ENERGY_RATE,
                0.0f
            );
            if (_latestEnergyExpKcalMin > FuelModelConsts.MAX_ENERGY_RATE_KCAL_MIN) {
                _latestEnergyExpKcalMin = FuelModelConsts.MAX_ENERGY_RATE_KCAL_MIN;
            }
            _caloriesAvailable = activeSnapshotBoolean(
                activeSnapshot,
                _storage.ACTIVE_SESSION_KEY_CALORIES_AVAILABLE,
                false
            );
            var storedFinalTargetG10 = activeSnapshotNumber(
                activeSnapshot,
                _storage.ACTIVE_SESSION_KEY_FINAL_TARGET_G10,
                _storage.ACTIVE_SESSION_UNKNOWN_TARGET_G10
            );
            if (_lastReminderTimestamp > safeNow) {
                _lastReminderTimestamp = safeNow;
            }
            if (_pauseStartTimerS != null && _pauseStartTimerS < 0) {
                _pauseStartTimerS = null;
            }
            if (_pauseStartClockTs != null && _pauseStartClockTs > safeNow) {
                _pauseStartClockTs = safeNow;
            }
            if (!_isPaused) {
                _pauseStartTimerS = null;
                _pauseStartClockTs = null;
            }
            if (_intakeCount == 0 && _consumedTotalG > 0) {
                _intakeCount = 1;
            }
            _sessionRecoverable = true;
            _sessionFinishHandled = false;

            var persistedSessionState = activeSnapshotNumber(
                activeSnapshot,
                _storage.ACTIVE_SESSION_KEY_STATE,
                _storage.ACTIVE_SESSION_UNKNOWN_STATE
            );

            // Recovery is written only when this exact session is finalized.
            // It therefore remains authoritative even if the preceding final
            // active write was dropped and cleanup also left an older active
            // generation behind.
            var recoverySessionId = _storage.getRecoverySessionId();
            if (recoverySessionId != null &&
                recoverySessionId == _sessionId &&
                _storage.hasRecoverySnapshot()) {
                loadRecoverySnapshot();
                _storage.clearActiveSession();
                return;
            }

            if (persistedSessionState == STATE_FINISHED) {
                if (_elapsedActiveSec <= 0) {
                    _storage.clearActiveSession();
                    clearSessionState();
                    return;
                }

                if (storedFinalTargetG10 >= 0) {
                    _targetTotalG = clampNonNegativeTotalG10(storedFinalTargetG10);
                    _deficitG = clampTotalG10(_targetTotalG - _consumedTotalG);
                } else {
                    calculateTargetAndDeficit();
                }
                var snapshotSaved = storeRecoverySnapshot(
                    _targetTotalG,
                    _consumedTotalG,
                    _elapsedActiveSec,
                    _intakeCount
                );
                if (snapshotSaved) {
                    _storage.clearActiveSession();
                }
                applyRecoverySnapshot(
                    _targetTotalG,
                    _consumedTotalG,
                    _elapsedActiveSec,
                    _intakeCount
                );
                return;
            }

            if (persistedSessionState < STATE_IDLE ||
                persistedSessionState >= STATE_FINISHED) {
                if (_isPaused) {
                    persistedSessionState = STATE_PAUSED;
                } else if (!_isStartTimestampConfirmed) {
                    persistedSessionState = STATE_PRIMING;
                } else {
                    persistedSessionState = STATE_ACTIVE;
                }
            }

            setSessionState(persistedSessionState);
            recalculateFromCurrentState();
        }
    }

    //! Save session to storage
    function saveSession() as Boolean {
        if (_sessionState == STATE_IDLE) {
            return true;
        }

        if (!_sessionRecoverable) {
            return _storage.clearActiveSession();
        }

        flushFitSessionSummary();
        return _storage.saveActiveSessionSnapshot({
            _storage.ACTIVE_SESSION_KEY_SESSION_ID => _sessionId,
            _storage.ACTIVE_SESSION_KEY_START_TIMESTAMP => _startTimestamp,
            _storage.ACTIVE_SESSION_KEY_START_CONFIRMED => _isStartTimestampConfirmed,
            _storage.ACTIVE_SESSION_KEY_CONSUMED_G10 => _consumedTotalG,
            _storage.ACTIVE_SESSION_KEY_STATE => _sessionState,
            _storage.ACTIVE_SESSION_KEY_LAST_INTAKE => _lastIntakeTimestamp,
            _storage.ACTIVE_SESSION_KEY_LAST_REMINDER => _lastReminderTimestamp,
            _storage.ACTIVE_SESSION_KEY_INTAKE_COUNT => _intakeCount,
            _storage.ACTIVE_SESSION_KEY_PAUSED => _isPaused,
            _storage.ACTIVE_SESSION_KEY_ELAPSED_SEC => _elapsedActiveSec,
            _storage.ACTIVE_SESSION_KEY_PAUSED_OFFSET_SEC => _pausedTimerOffsetS,
            _storage.ACTIVE_SESSION_KEY_PAUSE_START_TIMER =>
                (_isPaused && _pauseStartTimerS != null) ? _pauseStartTimerS : 0,
            _storage.ACTIVE_SESSION_KEY_PAUSE_START_CLOCK =>
                (_isPaused && _pauseStartClockTs != null) ? _pauseStartClockTs : 0,
            _storage.ACTIVE_SESSION_KEY_USING_ELAPSED => _usingElapsedTimeFallback,
            _storage.ACTIVE_SESSION_KEY_LATEST_CALORIES => _latestCaloriesKcal,
            _storage.ACTIVE_SESSION_KEY_LATEST_ENERGY_RATE => _latestEnergyExpKcalMin,
            _storage.ACTIVE_SESSION_KEY_CALORIES_AVAILABLE => _caloriesAvailable,
            _storage.ACTIVE_SESSION_KEY_FINAL_TARGET_G10 => _targetTotalG
        });
    }

    private function clearRecoverySnapshotState() as Void {
        _recoverySnapshotAvailable = false;
        _recoverySnapshotTargetG10 = 0;
        _recoverySnapshotConsumedG10 = 0;
        _recoverySnapshotElapsedSec = 0;
        _recoverySnapshotIntakeCount = 0;
    }

    private function storeRecoverySnapshot(targetG10 as Number,
                                           consumedG10 as Number,
                                           elapsedSec as Number,
                                           intakeCount as Number) as Boolean {
        return _storage.saveRecoverySnapshotForSession(
            _sessionId,
            targetG10,
            consumedG10,
            elapsedSec,
            intakeCount
        );
    }

    private function loadRecoverySnapshot() as Void {
        var elapsedSec = _storage.getRecoveryElapsedSec();
        if (elapsedSec <= 0) {
            clearRecoverySnapshotState();
            return;
        }

        applyRecoverySnapshot(
            _storage.getRecoveryTargetG10(),
            _storage.getRecoveryConsumedG10(),
            elapsedSec,
            _storage.getRecoveryIntakeCount()
        );
    }

    private function applyRecoverySnapshot(targetG10 as Number,
                                           consumedG10 as Number,
                                           elapsedSec as Number,
                                           intakeCount as Number) as Void {
        _recoverySnapshotAvailable = elapsedSec > 0;
        _recoverySnapshotTargetG10 = clampNonNegativeTotalG10(targetG10);
        _recoverySnapshotConsumedG10 = clampNonNegativeTotalG10(consumedG10);
        _recoverySnapshotElapsedSec = clampElapsedActiveSec(elapsedSec);
        _recoverySnapshotIntakeCount = (intakeCount > 0) ? intakeCount : 0;
        setSessionState(STATE_IDLE);
        _sessionRecoverable = false;
        _sessionFinishHandled = true;
        _startTimestamp = 0;
        _sessionId = 0;
        _lastIntakeTimestamp = 0;
        _isStartTimestampConfirmed = false;
        _lastReminderTimestamp = 0;
        _autoIntakeLocked = false;
        _autoIntakeEventPending = false;
        clearUndoState();
        _consumedTotalG = _recoverySnapshotConsumedG10;
        _intakeCount = _recoverySnapshotIntakeCount;
        _elapsedActiveSec = _recoverySnapshotElapsedSec;
        _targetTotalG = _recoverySnapshotTargetG10;
        _deficitG = _recoverySnapshotTargetG10 - _recoverySnapshotConsumedG10;
        _nextDueInSec = 0;
        _isReminderDue = false;
        _pauseStartTimerS = null;
        _pauseStartClockTs = null;
    }

    //! Start a new session
    function startNewSession(activityStartTs as Number?) as Void {
        // getTimerTime() runs before activity-boundary detection, so preserve
        // the source selected for this same sample while resetting all
        // coordinate history from the previous session.
        var currentUsesElapsedFallback = _usingElapsedTimeFallback;
        clearRecoverySnapshotState();
        var now              = (activityStartTs != null) ? activityStartTs : getCurrentTimestamp();
        _sessionId           = createSessionId(now);
        _startTimestamp      = now;
        _consumedTotalG      = 0;
        _lastIntakeTimestamp = now;
        _isPaused            = false;
        _isStartTimestampConfirmed = (activityStartTs != null);
        _lastReminderTimestamp = 0;
        _autoIntakeLocked    = false;
        _autoIntakeEventPending = false;
        clearUndoState();
        _sessionRecoverable = true;

        if (activityStartTs != null) {
            setSessionState(STATE_ACTIVE);
        } else {
            setSessionState(STATE_PRIMING);
        }
        _intakeCount         = 0;
        _lastTimerTime       = 0;
        _timerStallCount     = 0;
        _pausedTimerOffsetS  = 0;
        _pauseStartTimerS    = null;
        _pauseStartClockTs   = null;
        _usingElapsedTimeFallback = currentUsesElapsedFallback;
        _timerSourceChangedToElapsed = false;
        _timerTimeAdjustmentS = 0;
        _timerBacktrackCount = 0;
        _timerStartEventPending = false;

        _elapsedActiveSec       = 0;
        _targetTotalG           = 0;
        _deficitG               = 0;
        _nextDueInSec           = 0;
        _isReminderDue          = false;
        _latestCaloriesKcal     = 0;
        _latestEnergyExpKcalMin = 0.0f;
        _caloriesAvailable      = false;
        _lastFitFieldUpdateMs   = 0;
        _forceNextFitFieldUpdate = true;

        loadSettings();
        _storage.clearSession();
        saveSession();
    }

    private function setSessionState(state as Number) as Void {
        if (state != STATE_FINISHED) {
            _sessionFinishHandled = false;
        }
        _sessionState = state;
        _sessionActive = (
            state == STATE_PRIMING ||
            state == STATE_ACTIVE ||
            state == STATE_PAUSED
        );
        _isPaused = (state == STATE_PAUSED);
    }


    private function createSessionId(candidate as Number) as Number {
        var recoverySessionId = _storage.getRecoverySessionId();
        if (recoverySessionId != null && recoverySessionId == candidate) {
            // A failed recovery cleanup must not let a new activity started in
            // the same second inherit the previous session's committed result.
            return candidate + 1;
        }
        return candidate;
    }

    private function reconcileSessionState(activityStartTs as Number?,
                                           timerSec as Number,
                                           timerStatePaused as Boolean) as Void {
        if (_sessionState == STATE_IDLE) {
            if (!isStoppedSession()) {
                resetDisplayValues();
            } else {
                _nextDueInSec = 0;
                _isReminderDue = false;
            }
            return;
        }

        if (timerStatePaused) {
            if (_sessionState != STATE_PAUSED) {
                setSessionState(STATE_PAUSED);
                saveSession();
            }
            return;
        }
        // Fallback-started session: hold in priming briefly until the timer
        // looks stable, so we do not immediately "trust" a transient start.
        if (!_isStartTimestampConfirmed &&
            activityStartTs == null &&
            timerSec < FuelModelConsts.PRIMING_CONFIRM_SEC) {
            if (_sessionState != STATE_PRIMING) {
                setSessionState(STATE_PRIMING);
                saveSession();
            }
            return;
        }

        if (_sessionState != STATE_ACTIVE) {
            setSessionState(STATE_ACTIVE);
            saveSession();
        }
    }

    function clearSessionState() as Void {
        setSessionState(STATE_IDLE);
        _sessionRecoverable = false;
        _sessionFinishHandled = false;
        _startTimestamp = 0;
        _consumedTotalG = 0;
        _lastIntakeTimestamp = 0;
        _sessionId = 0;
        _isStartTimestampConfirmed = false;
        _intakeCount = 0;
        _autoIntakeLocked = false;
        _autoIntakeEventPending = false;
        _lastReminderTimestamp = 0;
        _latestCaloriesKcal = 0;
        _latestEnergyExpKcalMin = 0.0f;
        _caloriesAvailable = false;
        _timerStartEventPending = false;
        _hasValidTimerData = false;
        clearRecoverySnapshotState();
        resetDisplayValues();
    }

    private function markSessionFinished() as Void {
        if (_sessionState == STATE_IDLE) {
            return;
        }

        calculateTargetAndDeficit();
        _forceNextFitFieldUpdate = true;
        updateFitFields();
        flushFitSessionSummary();

        // Persist a final active-session record first. If the aggregate
        // recovery write fails, this remains the recoverable source of truth
        // and loadSession() will retry the conversion on the next launch.
        setSessionState(STATE_FINISHED);
        _sessionRecoverable = true;
        saveSession();

        var finalTargetG10 = _targetTotalG;
        var finalConsumedG10 = _consumedTotalG;
        var finalElapsedSec = _elapsedActiveSec;
        var finalIntakeCount = _intakeCount;
        if (finalElapsedSec <= 0) {
            _storage.clearActiveSession();
            clearSessionState();
            return;
        }
        var snapshotSaved = storeRecoverySnapshot(
            finalTargetG10,
            finalConsumedG10,
            finalElapsedSec,
            finalIntakeCount
        );
        if (snapshotSaved) {
            _storage.clearActiveSession();
        }

        applyRecoverySnapshot(
            finalTargetG10,
            finalConsumedG10,
            finalElapsedSec,
            finalIntakeCount
        );
        _timerStartEventPending = false;
        _hasValidTimerData = false;
    }

    //! Main compute function — call every tick (1 Hz)
    function compute(info) as Void {
        if (info == null) {
            _hasValidTimerData = false;
            return;
        }

        refreshTouchMode(false);

        var timerStateOff = isTimerStateOff(info);
        var timerStatePaused = isTimerStatePaused(info);
        if (timerStateOff) {
            _hasValidTimerData = false;
            _timerStartEventPending = false;
            if (_sessionState != STATE_IDLE && !_sessionFinishHandled) {
                markSessionFinished();
            }
            return;
        }

        var timerTime = getTimerTime(info, timerStatePaused);

        if (timerTime == null) {
            _hasValidTimerData = false;
            if (_sessionState == STATE_IDLE) {
                resetDisplayValues();
                return;
            }
            if (timerStatePaused && _sessionState != STATE_PAUSED) {
                if (_pauseStartClockTs == null) {
                    _pauseStartClockTs = getCurrentTimestamp();
                }
                setSessionState(STATE_PAUSED);
                saveSession();
            }
            _isReminderDue = false;
            _autoIntakeLocked = false;
            _autoIntakeEventPending = false;
            return;
        }
        _hasValidTimerData = true;

        var timerSec = timerTime / 1000;
        if (timerSec < 0) {
            timerSec = 0;
        }

        var activityStartTs = getActivityStartTimestamp(info);
        handleActivityStartDetection(activityStartTs, timerSec, timerStatePaused);
        handleTimerState(info, timerTime, timerSec, timerStatePaused);
        handleSessionStates(info);
    }

    //! Detect new activity or timer reset
    private function handleActivityStartDetection(activityStartTs as Number?,
                                                  timerSec as Number,
                                                  timerStatePaused as Boolean) as Void {
        if (_timerStartEventPending) {
            _timerStartEventPending = false;
            if (!_sessionActive) {
                startNewSession(activityStartTs);
                return;
            }
        }

        if (activityStartTs != null) {
            _timerBacktrackCount = 0;
            if (_sessionActive) {
                if (_startTimestamp != activityStartTs) {
                    if (_isStartTimestampConfirmed) {
                        startNewSession(activityStartTs);
                    } else {
                        _startTimestamp = activityStartTs;
                        _sessionId = createSessionId(activityStartTs);
                        _isStartTimestampConfirmed = true;
                        saveSession();
                    }
                } else if (!_isStartTimestampConfirmed) {
                    _sessionId = createSessionId(activityStartTs);
                    _isStartTimestampConfirmed = true;
                    saveSession();
                }
            } else if (isStoppedSession()) {
                if (!timerStatePaused &&
                    _startTimestamp != activityStartTs &&
                    timerSec > 0) {
                    startNewSession(activityStartTs);
                }
            } else if (timerSec > 0) {
                startNewSession(activityStartTs);
            }
        } else {
            if (_sessionActive && isLikelyTimerReset(timerSec)) {
                startNewSession(null);
            } else if (isStoppedSession()) {
                if (!timerStatePaused &&
                    timerSec > 0 &&
                    isLikelyTimerReset(timerSec)) {
                    startNewSession(null);
                }
            } else if (!_sessionActive && timerSec > 0) {
                _timerBacktrackCount = 0;
                startNewSession(null);
            }
        }
    }

    //! Handle timer state and update elapsed time
    private function handleTimerState(info as Activity.Info?, timerTime as Number,
                                      timerSec as Number,
                                      timerStatePaused as Boolean) as Void {
        var effectiveTimerSec = getEffectiveTimerSec(
            timerSec,
            timerStatePaused,
            _usingElapsedTimeFallback
        );
        if (!timerStatePaused &&
            _elapsedActiveSec > 0 &&
            effectiveTimerSec < _elapsedActiveSec) {
            // Active elapsed is monotonic within one detected activity. Raw
            // timer reset detection runs before this clamp, so a real new
            // activity can still reset the model while source lag cannot make
            // the fueling target move backwards.
            effectiveTimerSec = _elapsedActiveSec;
        }
        _elapsedActiveSec = clampElapsedActiveSec(effectiveTimerSec);

        var pauseDetected = detectPause(timerTime, timerStatePaused);
        var activityStartTs = getActivityStartTimestamp(info);
        reconcileSessionState(activityStartTs, timerSec, timerStatePaused || pauseDetected);
    }

    //! Handle session state-specific logic
    private function handleSessionStates(info as Activity.Info?) as Void {
        if (_sessionState == STATE_IDLE) {
            if (!isStoppedSession()) {
                resetDisplayValues();
            } else {
                _nextDueInSec = 0;
                _isReminderDue = false;
            }
            return;
        }

        if (_sessionState == STATE_PAUSED) {
            calculateTargetAndDeficit();
            _isReminderDue = false;
            _nextDueInSec = 0;
            _autoIntakeLocked = false;
            _autoIntakeEventPending = false;
            updateFitFields();
            return;
        }

        if (_sessionState == STATE_PRIMING) {
            _targetTotalG = 0;
            _deficitG = 0;
            _nextDueInSec = 0;
            _isReminderDue = false;
            _autoIntakeLocked = false;
            _autoIntakeEventPending = false;
            updateFitFields();
            return;
        }

        // ACTIVE only from here on
        updateCalorieData(info);
        calculateTargetAndDeficit();
        calculateNextDue();
        checkReminderDue();
        applyAutoIntakeIfDue();
        updateFitFields();
    }


    private function detectTouchScreen() as Boolean {
        try {
            var settings = System.getDeviceSettings();
            if (settings != null &&
                settings has :isTouchScreen &&
                settings.isTouchScreen instanceof Boolean) {
                return settings.isTouchScreen;
            }
        } catch (e) {
            FuelPlannerLog.logWarn("TouchDetect", "Failed to detect touch screen");
        }
        return false;
    }


    private function refreshTouchMode(force as Boolean) as Void {
        var nowMs = System.getTimer();
        var elapsedMs = nowMs - _lastTouchRefreshMs;
        if (elapsedMs < 0) {
            elapsedMs = FuelModelConsts.TOUCH_REFRESH_INTERVAL_MS;
        }
        if (!force &&
            _lastTouchRefreshMs > 0 &&
            elapsedMs < FuelModelConsts.TOUCH_REFRESH_INTERVAL_MS) {
            return;
        }
        _isTouch = detectTouchScreen();
        _lastTouchRefreshMs = nowMs;
    }

    private function clampSetting(value as Number, min as Number, max as Number) as Number {
        if (value < min) { return min; }
        if (value > max) { return max; }
        return value;
    }


    private function clampElapsedActiveSec(value as Number) as Number {
        if (value < 0) {
            return 0;
        }
        if (value > FuelModelConsts.MAX_ELAPSED_ACTIVE_SEC) {
            return FuelModelConsts.MAX_ELAPSED_ACTIVE_SEC;
        }
        return value;
    }


    private function clampTotalG10(value as Number) as Number {
        if (value > FuelModelConsts.MAX_TOTAL_G10) {
            return FuelModelConsts.MAX_TOTAL_G10;
        }
        if (value < -FuelModelConsts.MAX_TOTAL_G10) {
            return -FuelModelConsts.MAX_TOTAL_G10;
        }
        return value;
    }


    private function clampNonNegativeTotalG10(value as Number) as Number {
        if (value < 0) {
            return 0;
        }
        if (value > FuelModelConsts.MAX_TOTAL_G10) {
            return FuelModelConsts.MAX_TOTAL_G10;
        }
        return value;
    }


    private function clampNextDueSec(value as Number) as Number {
        if (value < 0) {
            return 0;
        }
        if (value > FuelModelConsts.MAX_NEXT_DUE_SEC) {
            return FuelModelConsts.MAX_NEXT_DUE_SEC;
        }
        return value;
    }


    private function shiftReminderReferenceTimestamps(pausedDurationSec as Number) as Void {
        if (pausedDurationSec <= 0) {
            return;
        }

        if (_lastIntakeTimestamp > 0) {
            _lastIntakeTimestamp += pausedDurationSec;
        }
        if (_lastReminderTimestamp > 0) {
            _lastReminderTimestamp += pausedDurationSec;
        }
    }


    private function getSnoozeRemainingSec(nowTimestamp as Number) as Number {
        if (_lastReminderTimestamp <= 0) {
            return 0;
        }

        var snoozeSec = _maxSnoozeMin * 60;
        var elapsedSinceReminder = nowTimestamp - _lastReminderTimestamp;
        if (elapsedSinceReminder < 0) {
            elapsedSinceReminder = 0;
        }
        return clampNextDueSec(snoozeSec - elapsedSinceReminder);
    }


    private function isLikelyTimerReset(rawTimerSec as Number) as Boolean {
        if (_elapsedActiveSec <= 0) {
            _timerBacktrackCount = 0;
            return false;
        }

        // A reset candidate must stay close to zero for several consecutive
        // samples. The window is deliberately wider than the confirmation
        // count so a missing zero-second sample cannot make confirmation
        // mathematically impossible.
        if (rawTimerSec > FuelModelConsts.TIMER_RESET_LOW_WINDOW_SEC) {
            _timerBacktrackCount = 0;
            return false;
        }

        var delta = _elapsedActiveSec - rawTimerSec;
        if (delta < FuelModelConsts.TIMER_BACKTRACK_RESET_DELTA_SEC) {
            _timerBacktrackCount = 0;
            return false;
        }

        _timerBacktrackCount += 1;
        if (_timerBacktrackCount < FuelModelConsts.TIMER_BACKTRACK_CONFIRM_TICKS) {
            return false;
        }

        _timerBacktrackCount = 0;
        return true;
    }


    private function applyAutoIntakeIfDue() as Void {
        if (_isTouch) {
            _autoIntakeLocked = false;
            _autoIntakeEventPending = false;
            return;
        }

        if (!_isReminderDue) {
            _autoIntakeLocked = false;
            _autoIntakeEventPending = false;
            return;
        }

        if (_autoIntakeLocked) {
            return;
        }

        var intakeCountBefore = _intakeCount;
        _autoIntakeLocked = true;
        recordDefaultIntake();
        if (_intakeCount <= intakeCountBefore) {
            // Intake was not booked (e.g. unexpected validation/storage issue) -> allow retry.
            _autoIntakeLocked = false;
            _autoIntakeEventPending = false;
            return;
        }
        _autoIntakeEventPending = true;
        recordReminderTriggered();
        _deficitG = _targetTotalG - _consumedTotalG;
        calculateNextDue();
        checkReminderDue();
    }


    private function updateFitFields() as Void {
        if (!isSessionActive()) {
            _forceNextFitFieldUpdate = true;
            return;
        }
        if (_fitFieldDeficit == null && _fitFieldConsumed == null &&
            _fitFieldTargetSummary == null && _fitFieldActualSummary == null) {
            return;
        }

        var nowMs = System.getTimer();
        var elapsedMs = nowMs - _lastFitFieldUpdateMs;
        if (!_forceNextFitFieldUpdate && elapsedMs >= 0 && elapsedMs < FuelModelConsts.FIT_UPDATE_INTERVAL_MS) {
            return;
        }
        _lastFitFieldUpdateMs = nowMs;
        _forceNextFitFieldUpdate = false;

        try {
            if (_fitFieldDeficit != null) {
                _fitFieldDeficit.setData(_deficitG.toFloat() / 10.0f);
            }
        } catch (e) {
            FuelPlannerLog.logError("FIT", "Failed to write deficit record");
        }

        try {
            if (_fitFieldConsumed != null) {
                _fitFieldConsumed.setData(_consumedTotalG.toFloat() / 10.0f);
            }
        } catch (e) {
            FuelPlannerLog.logError("FIT", "Failed to write consumed record");
        }

        writeFitSessionSummary(_fitFieldTargetSummary, _fitFieldActualSummary);
    }


    function flushFitSessionSummary() as Void {
        // Session FIT fields are summary values. Write them whenever fields exist,
        // including the final stop/recovery phase where _sessionActive is already false.
        if (_fitFieldTargetSummary == null && _fitFieldActualSummary == null) {
            return;
        }
        writeFitSessionSummary(_fitFieldTargetSummary, _fitFieldActualSummary);
    }


    private function writeFitSessionSummary(fieldTargetSummary as FitContributor.Field?,
                                            fieldActualSummary as FitContributor.Field?) as Void {
        try {
            if (fieldTargetSummary != null) {
                fieldTargetSummary.setData(_targetTotalG.toFloat() / 10.0f);
            }
        } catch (e) {
            FuelPlannerLog.logError("FIT", "Failed to write target summary");
        }

        try {
            if (fieldActualSummary != null) {
                fieldActualSummary.setData(_consumedTotalG.toFloat() / 10.0f);
            }
        } catch (e) {
            FuelPlannerLog.logError("FIT", "Failed to write actual summary");
        }
    }

    private function getElapsedTimeMillis(info) as Number? {
        try {
            if (info has :elapsedTime) {
                return getNonNegativeNumberOrNull(info.elapsedTime);
            }
        } catch (e) {}
        return null;
    }


    private function updatePausedTimerOffset(observedOffset as Number,
                                             timerStatePaused as Boolean) as Void {
        if (observedOffset <= _pausedTimerOffsetS) {
            return;
        }
        _pausedTimerOffsetS = clampElapsedActiveSec(observedOffset);
        if (timerStatePaused && _pauseStartClockTs != null) {
            // The elapsed-vs-timer delta now includes the pause up to this
            // sample. Shift reminder references for that committed portion,
            // then continue wall-clock fallback only from this point.
            var now = getCurrentTimestamp();
            shiftReminderReferenceTimestamps(now - _pauseStartClockTs);
            _pauseStartClockTs = now;
        }
    }


    private function calibrateElapsedFallbackOffset(timerTimeMs as Number,
                                                    elapsedTimeMs as Number,
                                                    timerStatePaused as Boolean) as Void {
        var timerSec = timerTimeMs / 1000;
        var elapsedSec = elapsedTimeMs / 1000;
        var observedOffset = elapsedSec - timerSec;
        if (observedOffset >= 0) {
            updatePausedTimerOffset(observedOffset, timerStatePaused);
        }
    }


    private function getTimerTime(info, timerStatePaused as Boolean) as Number? {
        var wasUsingElapsedFallback = _usingElapsedTimeFallback;
        try {
            if (info has :timerTime) {
                var timerTime = getNonNegativeNumberOrNull(info.timerTime);
                if (timerTime != null) {
                    var companionElapsedTime = getElapsedTimeMillis(info);
                    var timerSec = timerTime / 1000;
                    var needsTimerMapping = wasUsingElapsedFallback ||
                                            (_lastTimerTime == 0 &&
                                             _elapsedActiveSec > 0 &&
                                             timerSec < _elapsedActiveSec);
                    if (needsTimerMapping) {
                        var mappedTimerSec = _elapsedActiveSec;
                        if (companionElapsedTime != null) {
                            var companionActiveSec = (companionElapsedTime / 1000) -
                                                     _pausedTimerOffsetS;
                            if (companionActiveSec > mappedTimerSec) {
                                mappedTimerSec = companionActiveSec;
                            }
                            if (wasUsingElapsedFallback) {
                                var maximumMappedSec = _elapsedActiveSec +
                                                       FuelModelConsts.TIMER_SOURCE_SWITCH_GRACE_SEC;
                                if (mappedTimerSec > maximumMappedSec) {
                                    mappedTimerSec = maximumMappedSec;
                                }
                            }
                        }
                        _timerTimeAdjustmentS = mappedTimerSec - timerSec;
                    } else if (_timerTimeAdjustmentS != 0 &&
                               companionElapsedTime != null &&
                               !timerStatePaused) {
                        // If a temporarily stale timer source catches up, keep
                        // its adjusted coordinate aligned with the still-live
                        // elapsed source instead of introducing a later jump.
                        var companionActiveSec = (companionElapsedTime / 1000) -
                                                 _pausedTimerOffsetS;
                        if (companionActiveSec >= _elapsedActiveSec) {
                            _timerTimeAdjustmentS = companionActiveSec - timerSec;
                        }
                    }
                    var adjustedTimerTime = timerTime + (_timerTimeAdjustmentS * 1000);
                    if (companionElapsedTime != null &&
                        (adjustedTimerTime / 1000) >= _elapsedActiveSec) {
                        calibrateElapsedFallbackOffset(
                            adjustedTimerTime,
                            companionElapsedTime,
                            timerStatePaused
                        );
                    }
                    if (wasUsingElapsedFallback) {
                        // Raw timer sources use different coordinate systems.
                        _lastTimerTime = 0;
                    }
                    _usingElapsedTimeFallback = false;
                    _timerSourceChangedToElapsed = false;
                    return timerTime;
                }
            }
        } catch (e) {}

        // Some devices/profiles expose elapsed time instead of timerTime.
        var elapsedTime = getElapsedTimeMillis(info);
        if (elapsedTime != null) {
            _timerSourceChangedToElapsed = !wasUsingElapsedFallback &&
                                           _elapsedActiveSec > 0;
            if (_timerSourceChangedToElapsed) {
                _lastTimerTime = 0;
            }
            _usingElapsedTimeFallback = true;
            _timerTimeAdjustmentS = 0;
            return elapsedTime;
        }
        _usingElapsedTimeFallback = false;
        _timerSourceChangedToElapsed = false;
        _timerTimeAdjustmentS = 0;
        return null;
    }


    private function getActivityStartTimestamp(info) as Number? {
        try {
            if (info has :startTime && info.startTime != null) {
                return info.startTime.value();
            }
        } catch (e) {
            FuelPlannerLog.logWarn("ActivityStart", "Failed to get start timestamp");
        }
        return null;
    }


    private function isTimerStatePaused(info) as Boolean {
        try {
            if (info has :timerState &&
                Activity has :TIMER_STATE_PAUSED &&
                info.timerState == Activity.TIMER_STATE_PAUSED) {
                return true;
            }
            if (info has :timerState &&
                Activity has :TIMER_STATE_STOPPED &&
                info.timerState == Activity.TIMER_STATE_STOPPED) {
                return true;
            }
        } catch (e) {}
        return false;
    }


    private function isTimerStateOff(info) as Boolean {
        return FuelPlannerUtils.isTimerStateOff(info);
    }


    private function getEffectiveTimerSec(rawTimerSec as Number,
                                          timerStatePaused as Boolean,
                                          usingElapsedTimeFallback as Boolean) as Number {
        // Activity.Info.timerTime is already the activity timer. Only the
        // elapsedTime fallback needs an accumulated pause offset.
        if (!usingElapsedTimeFallback) {
            _pauseStartTimerS = null;
            if (timerStatePaused && _elapsedActiveSec > 0) {
                return _elapsedActiveSec;
            }
            var adjustedTimerSec = rawTimerSec + _timerTimeAdjustmentS;
            return (adjustedTimerSec < 0) ? 0 : adjustedTimerSec;
        }

        if (_timerSourceChangedToElapsed) {
            _timerSourceChangedToElapsed = false;
            var sourceSwitchCandidate = rawTimerSec - _pausedTimerOffsetS;
            var maximumExpectedSec = _elapsedActiveSec +
                                     FuelModelConsts.TIMER_SOURCE_SWITCH_GRACE_SEC;
            if (sourceSwitchCandidate > maximumExpectedSec) {
                // A fallback source normally includes prior pauses. Calibrate
                // the first sample instead of adding that paused time at once.
                updatePausedTimerOffset(
                    rawTimerSec - _elapsedActiveSec,
                    timerStatePaused
                );
            }
        }

        if (timerStatePaused) {
            if (_pauseStartTimerS == null) {
                // elapsedTime may keep advancing while the timer is stopped.
                // Anchor the pause to the last observed sample so the first
                // stopped tick cannot be counted as active time.
                var lastObservedSec = _lastTimerTime / 1000;
                if (_lastTimerTime > 0 && lastObservedSec <= rawTimerSec) {
                    _pauseStartTimerS = lastObservedSec;
                } else {
                    _pauseStartTimerS = rawTimerSec;
                }
            }

            var pauseStartForFreeze = (_pauseStartTimerS != null) ? _pauseStartTimerS : rawTimerSec;
            var frozenSec = pauseStartForFreeze - _pausedTimerOffsetS;
            if (frozenSec < 0) {
                frozenSec = 0;
            }
            return frozenSec;
        }

        if (_pauseStartTimerS != null) {
            var pauseStartForDelta = (_pauseStartTimerS != null) ? _pauseStartTimerS : rawTimerSec;
            var pauseEndSec = rawTimerSec;
            var lastObservedSec = _lastTimerTime / 1000;
            if (_lastTimerTime > 0 &&
                lastObservedSec > pauseStartForDelta &&
                lastObservedSec <= rawTimerSec) {
                pauseEndSec = lastObservedSec;
            }
            var pausedDuration = pauseEndSec - pauseStartForDelta;
            if (pausedDuration > 0) {
                _pausedTimerOffsetS += pausedDuration;
            }
            _pauseStartTimerS = null;
        }

        var effectiveSec = rawTimerSec - _pausedTimerOffsetS;
        if (effectiveSec < 0) {
            effectiveSec = 0;
        }
        return effectiveSec;
    }


    private function updateCalorieData(info) as Void {
        var hasCalorieDataThisTick = false;

        try {
            if (info has :calories) {
                var calories = getNonNegativeNumberOrNull(info.calories);
                if (calories != null) {
                    if (calories > FuelModelConsts.MAX_CALORIES_KCAL) {
                        calories = FuelModelConsts.MAX_CALORIES_KCAL;
                    }
                    if (!_caloriesAvailable || calories >= _latestCaloriesKcal) {
                        _latestCaloriesKcal = calories;
                    }
                    _caloriesAvailable = true;
                    hasCalorieDataThisTick = true;
                }
            }
        } catch (e) {}

        try {
            if (info has :energyExpenditure) {
                var energyRate = toFloatOrNull(info.energyExpenditure);
                if (energyRate != null && energyRate > 0.0f) {
                    if (energyRate > FuelModelConsts.MAX_ENERGY_RATE_KCAL_MIN) {
                        energyRate = FuelModelConsts.MAX_ENERGY_RATE_KCAL_MIN;
                    }
                    _latestEnergyExpKcalMin = energyRate;
                }
            }
        } catch (e) {}

        // Calorie Auto Fallback mit Recovery: Wechsel auf MODE_AUTO wenn Kalorien-Daten fehlen
        if (_reminderMode == MODE_CALORIE_AUTO) {
            if (hasCalorieDataThisTick) {
                _calorieDataMissingTicks = 0;
                // Sperre abgelaufen? Dann aufheben
                if (_calorieAutoSuspendedUntilSec > 0 &&
                    _elapsedActiveSec >= _calorieAutoSuspendedUntilSec) {
                    _calorieAutoSuspendedUntilSec = 0;
                }
            } else {
                _calorieDataMissingTicks += 1;
                if (_calorieDataMissingTicks >= CALORIE_FALLBACK_TICKS) {
                    _reminderMode = MODE_AUTO;
                    _calorieDataMissingTicks = 0;
                    // Sperre für 10 Minuten setzen, dann erneut auf Calorie Auto prüfen
                    _calorieAutoSuspendedUntilSec = _elapsedActiveSec + CALORIE_SUSPEND_DURATION_SEC;
                }
            }
        }

        // Recovery: Prüfe ob Kalorien wieder verfügbar sind und Sperre abgelaufen
        if (_calorieAutoSuspendedUntilSec > 0 &&
            hasCalorieDataThisTick &&
            _elapsedActiveSec >= _calorieAutoSuspendedUntilSec) {
            _reminderMode = MODE_CALORIE_AUTO;
            _calorieAutoSuspendedUntilSec = 0;
            // Erzwinge Neuberechnung nach Mode-Recovery
            calculateNextDue();
            checkReminderDue();
        }
    }



    private function toNumberOrNull(value as Lang.Object?) as Number? {
        if (value instanceof Number) {
            return value;
        }
        return null;
    }


    private function getNonNegativeNumberOrNull(value as Lang.Object?) as Number? {
        var numberValue = toNumberOrNull(value);
        if (numberValue != null && numberValue >= 0) {
            return numberValue;
        }
        return null;
    }


    private function toFloatOrNull(value as Lang.Object?) as Float? {
        if (value instanceof Float) {
            return value;
        }
        if (value instanceof Number) {
            return value.toFloat();
        }
        return null;
    }

    //! Detect pause from explicit timer state (preferred) or timer stall fallback.
    private function detectPause(timerTime as Number, timerStatePaused as Boolean) as Boolean {
        var wasPaused = (_sessionState == STATE_PAUSED);
        var pauseDetected = false;

        if (timerStatePaused) {
            pauseDetected = true;
            _timerStallCount = 0;
            _lastTimerTime = timerTime;
        } else if (wasPaused && _pauseStartClockTs != null && _lastTimerTime == 0) {
            // After a reload we do not know whether a persisted pause has already resumed.
            // Keep the paused candidate until we observe the timer move on a later tick.
            pauseDetected = true;
            _timerStallCount = 1;
            _lastTimerTime = timerTime;
        } else if (wasPaused && _pauseStartClockTs != null && timerTime == _lastTimerTime) {
            pauseDetected = true;
            _timerStallCount = 1;
            _lastTimerTime = timerTime;
        } else if (_lastTimerTime > 0) {
            if (timerTime == _lastTimerTime) {
                _timerStallCount += 1;
                if (_timerStallCount >= 2) {
                    pauseDetected = true;
                }
            } else {
                _timerStallCount = 0;
                pauseDetected = false;
            }
            _lastTimerTime = timerTime;
        } else {
            pauseDetected = false;
            _lastTimerTime = timerTime;
        }

        if (pauseDetected) {
            if (!wasPaused) {
                _pauseStartClockTs = getCurrentTimestamp();
            }
            return true;
        }

        if (wasPaused && _pauseStartClockTs != null) {
            shiftReminderReferenceTimestamps(getCurrentTimestamp() - _pauseStartClockTs);
        }
        _pauseStartClockTs = null;

        return false;
    }


    private function resetDisplayValues() as Void {
        _elapsedActiveSec   = 0;
        _targetTotalG       = 0;
        _deficitG           = 0;
        _nextDueInSec       = 0;
        _isPaused           = false;
        _isReminderDue      = false;
        _autoIntakeLocked   = false;
        _autoIntakeEventPending = false;
        _lastTimerTime      = 0;
        _timerStallCount    = 0;
        _pausedTimerOffsetS = 0;
        _pauseStartTimerS   = null;
        _pauseStartClockTs  = null;
        _usingElapsedTimeFallback = false;
        _timerSourceChangedToElapsed = false;
        _timerTimeAdjustmentS = 0;
        _timerBacktrackCount = 0;
        _lastFitFieldUpdateMs = 0;
        _forceNextFitFieldUpdate = true;
        clearUndoState();
    }

    public static function calculateTargetTotalG10(elapsedActiveSec as Number,
                                                   carbsTargetGph as Number,
                                                   reminderMode as Number,
                                                   latestCaloriesKcal as Number,
                                                   carbFractionPct as Number,
                                                   caloriesAvailable as Boolean,
                                                   minCarbsTargetGph as Number) as Number {
        var safeElapsedActiveSec = elapsedActiveSec;
        if (safeElapsedActiveSec < 0) {
            safeElapsedActiveSec = 0;
        } else if (safeElapsedActiveSec > FuelModelConsts.MAX_ELAPSED_ACTIVE_SEC) {
            safeElapsedActiveSec = FuelModelConsts.MAX_ELAPSED_ACTIVE_SEC;
        }

        if (reminderMode == FuelReminderModes.CALORIE_AUTO && caloriesAvailable) {
            // Target = burned carbs estimate in g10.
            var safeCaloriesKcal = latestCaloriesKcal;
            if (safeCaloriesKcal < 0) {
                safeCaloriesKcal = 0;
            } else if (safeCaloriesKcal > FuelModelConsts.MAX_CALORIES_KCAL) {
                safeCaloriesKcal = FuelModelConsts.MAX_CALORIES_KCAL;
            }

            var safeCarbFractionPct = carbFractionPct;
            if (safeCarbFractionPct < 0) {
                safeCarbFractionPct = 0;
            } else if (safeCarbFractionPct > 100) {
                safeCarbFractionPct = 100;
            }

            var calorieTargetG10 = ((safeCaloriesKcal * safeCarbFractionPct * 10) + 200) / 400;
            if (calorieTargetG10 > FuelModelConsts.MAX_TOTAL_G10) {
                return FuelModelConsts.MAX_TOTAL_G10;
            }
            return calorieTargetG10;
        }

        var safeCarbsRateGph10 = ((carbsTargetGph > 0) ? carbsTargetGph : minCarbsTargetGph) * 10;
        var targetG10 = (safeElapsedActiveSec * safeCarbsRateGph10) / 3600;
        if (targetG10 > FuelModelConsts.MAX_TOTAL_G10) {
            return FuelModelConsts.MAX_TOTAL_G10;
        }
        return targetG10;
    }

    public static function calculateDeficit(elapsedActiveSec as Number,
                                            consumedTotalG10 as Number,
                                            carbsTargetGph as Number,
                                            reminderMode as Number,
                                            latestCaloriesKcal as Number,
                                            carbFractionPct as Number,
                                            caloriesAvailable as Boolean,
                                            minCarbsTargetGph as Number) as Number {
        var targetG10 = FuelModel.calculateTargetTotalG10(
            elapsedActiveSec,
            carbsTargetGph,
            reminderMode,
            latestCaloriesKcal,
            carbFractionPct,
            caloriesAvailable,
            minCarbsTargetGph
        );

        var safeConsumedTotalG10 = consumedTotalG10;
        if (safeConsumedTotalG10 < 0) {
            safeConsumedTotalG10 = 0;
        } else if (safeConsumedTotalG10 > FuelModelConsts.MAX_TOTAL_G10) {
            safeConsumedTotalG10 = FuelModelConsts.MAX_TOTAL_G10;
        }

        var deficitG10 = targetG10 - safeConsumedTotalG10;
        if (deficitG10 > FuelModelConsts.MAX_TOTAL_G10) {
            return FuelModelConsts.MAX_TOTAL_G10;
        }
        if (deficitG10 < -FuelModelConsts.MAX_TOTAL_G10) {
            return -FuelModelConsts.MAX_TOTAL_G10;
        }
        return deficitG10;
    }

    private function calculateTargetAndDeficit() as Void {
        _targetTotalG = clampNonNegativeTotalG10(FuelModel.calculateTargetTotalG10(
            _elapsedActiveSec,
            _carbsTargetGph,
            _reminderMode,
            _latestCaloriesKcal,
            _carbFractionPct,
            _caloriesAvailable,
            _storage.MIN_CARBS_TARGET_GPH
        ));
        _deficitG = clampTotalG10(_targetTotalG - _consumedTotalG);
    }


    //! Recompute target/deficit/reminder timing from current state and settings.
    private function recalculateFromCurrentState() as Void {
        if (_sessionState == STATE_IDLE) {
            resetDisplayValues();
            return;
        }

        calculateTargetAndDeficit();

        if (_sessionState == STATE_PRIMING ||
            _sessionState == STATE_PAUSED) {
            _nextDueInSec = 0;
            _isReminderDue = false;
            return;
        }

        calculateNextDue();
        checkReminderDue();
    }

    (:testsupport)
    function setTouchForTest(isTouch as Boolean) as Void {
        _isTouch = isTouch;
        _lastTouchRefreshMs = System.getTimer();
    }

    //! Calculate time until next intake is due
    private function calculateNextDue() as Void {
        var safeStartDelayMin = (_startDelayMin >= 0)
            ? _startDelayMin
            : _storage.MIN_START_DELAY_MIN;
        var safeDoseG10 = (_doseG > 0)
            ? _doseG * 10
            : _storage.MIN_DOSE_G * 10;
        var safeCarbsRateGph10 = (_carbsTargetGph > 0)
            ? _carbsTargetGph * 10
            : _storage.MIN_CARBS_TARGET_GPH * 10;

        var startDelaySec = safeStartDelayMin * 60;

        if (_consumedTotalG == 0 && _elapsedActiveSec < startDelaySec) {
            _nextDueInSec = startDelaySec - _elapsedActiveSec;
            return;
        }

        if (_reminderMode == MODE_FIXED) {
            // Fixed interval from last intake; first reminder after delay + one full interval
            var safeIntervalMin = (_fixedIntervalMin > 0)
                ? _fixedIntervalMin
                : _storage.MIN_FIXED_INTERVAL_MIN;
            var intervalSec = safeIntervalMin * 60;
            if (_consumedTotalG == 0) {
                _nextDueInSec = clampNextDueSec((startDelaySec + intervalSec) - _elapsedActiveSec);
            } else {
                var now = getCurrentTimestamp();
                var safeLastIntakeTimestamp = (_lastIntakeTimestamp > 0) ? _lastIntakeTimestamp : now;
                _nextDueInSec = clampNextDueSec(intervalSec - (now - safeLastIntakeTimestamp));
            }
            return;
        }

        // MODE_AUTO and MODE_CALORIE_AUTO: deficit-based (all g10)
        if (_deficitG >= safeDoseG10) {
            _nextDueInSec = 0;
        } else {
            var deficitNeededG10 = safeDoseG10 - _deficitG;

            if (_reminderMode == MODE_CALORIE_AUTO && _latestEnergyExpKcalMin > 0.0f) {
                // sec = neededG10 / (kcalMin * carbPct / 2400)
                var rateNumerator = _latestEnergyExpKcalMin * _carbFractionPct.toFloat();
                if (rateNumerator > 0.0f) {
                    _nextDueInSec = clampNextDueSec(((deficitNeededG10.toFloat() * 2400.0f) / rateNumerator).toNumber());
                } else {
                    _nextDueInSec = FuelModelConsts.MAX_NEXT_DUE_SEC;
                }
            } else {
                // ceil(needed * 3600 / rateG10PerHour)
                _nextDueInSec = clampNextDueSec(((deficitNeededG10 * 3600) + safeCarbsRateGph10 - 1) / safeCarbsRateGph10);
            }
        }
    }


    //! Check if reminder should fire
    private function checkReminderDue() as Void {
        _isReminderDue = ReminderManager.shouldVibrate(
            _nextDueInSec,
            _isPaused,
            _consumedTotalG,
            _elapsedActiveSec,
            _startDelayMin,
            _lastReminderTimestamp,
            _maxSnoozeMin,
            getCurrentTimestamp()
        );
    }

    private function getSafeDoseG10() as Number {
        if (_doseG > 0) {
            return _doseG * 10;
        }
        return _storage.MIN_DOSE_G * 10;
    }

    function getRingTone() as Number {
        if (!_sessionActive) {
            return RING_TONE_GREEN;
        }
        if (_isPaused) {
            return RING_TONE_GREEN;
        }

        var safeDoseG10 = (_doseG > 0)
            ? _doseG * 10
            : _storage.MIN_DOSE_G * 10;
        var roundedDeficitG10 = (_deficitG > 5)
            ? ((_deficitG + 5) / 10) * 10
            : 0;
        if (_reminderMode != MODE_FIXED) {
            if (roundedDeficitG10 >= safeDoseG10) {
                return RING_TONE_RED;
            }
        }

        if (_isReminderDue || _nextDueInSec <= 0) {
            return RING_TONE_RED;
        }

        if (_reminderMode != MODE_FIXED) {
            var warningDeficitG10 = ((safeDoseG10 * 7) + 9) / 10;
            if (roundedDeficitG10 >= warningDeficitG10) {
                return RING_TONE_YELLOW;
            }
        }

        var cycleSec = 0;
        if (_reminderMode == MODE_FIXED) {
            var safeIntervalMin = (_fixedIntervalMin > 0)
                ? _fixedIntervalMin
                : _storage.MIN_FIXED_INTERVAL_MIN;
            cycleSec = safeIntervalMin * 60;
        } else if (_reminderMode == MODE_CALORIE_AUTO &&
                   _latestEnergyExpKcalMin > 0.0f) {
            var rateNumerator = _latestEnergyExpKcalMin * _carbFractionPct.toFloat();
            if (rateNumerator > 0.0f) {
                cycleSec = ((safeDoseG10.toFloat() * 2400.0f) /
                            rateNumerator).toNumber();
            }
        } else {
            var safeCarbsRateGph10 = (_carbsTargetGph > 0)
                ? _carbsTargetGph * 10
                : _storage.MIN_CARBS_TARGET_GPH * 10;
            if (safeCarbsRateGph10 > 0) {
                cycleSec = ((safeDoseG10 * 3600) + safeCarbsRateGph10 - 1) /
                           safeCarbsRateGph10;
            }
        }
        if (cycleSec < 0) { cycleSec = 0; }
        if (cycleSec > FuelModelConsts.MAX_NEXT_DUE_SEC) {
            cycleSec = FuelModelConsts.MAX_NEXT_DUE_SEC;
        }

        var warningLeadSec = cycleSec / 4;
        if (warningLeadSec < RING_WARNING_MIN_SEC) {
            warningLeadSec = RING_WARNING_MIN_SEC;
        }
        if (warningLeadSec > RING_WARNING_MAX_SEC) {
            warningLeadSec = RING_WARNING_MAX_SEC;
        }
        if (warningLeadSec >= cycleSec) {
            warningLeadSec = cycleSec / 2;
            if (warningLeadSec < 1 && cycleSec > 0) {
                warningLeadSec = 1;
            }
        }
        if (warningLeadSec > 0 && _nextDueInSec <= warningLeadSec) {
            return RING_TONE_YELLOW;
        }

        return RING_TONE_GREEN;
    }


    function recordReminderTriggered() as Void {
        _lastReminderTimestamp = getCurrentTimestamp();
        _isReminderDue = false;
        _forceNextFitFieldUpdate = true;
        saveSession();
    }


    function snoozeReminder() as Void {
        if (!_sessionActive) {
            return;
        }
        _lastReminderTimestamp = getCurrentTimestamp();
        _isReminderDue = false;
        _forceNextFitFieldUpdate = true;
        saveSession();
    }


    function recordIntake(grams as Number) as Void {
        if (!_sessionActive) { return; }
        if (grams <= 0) { return; }
        var safeGrams = grams;
        if (safeGrams > FuelModelConsts.MAX_MANUAL_INTAKE_G) {
            safeGrams = FuelModelConsts.MAX_MANUAL_INTAKE_G;
        }

        var gramsG10 = gramsToG10(safeGrams);
        if (gramsG10 <= 0) { return; }
        var now              = getCurrentTimestamp();
        _consumedTotalG      = clampNonNegativeTotalG10(_consumedTotalG + gramsG10);
        _lastIntakeTimestamp = now;
        _lastReminderTimestamp = 0;
        _isReminderDue       = false;
        _autoIntakeLocked    = false;
        _autoIntakeEventPending = false;
        _intakeCount        += 1;

        // Store undo state
        _undoAvailable = true;
        _undoGramsG10 = gramsG10;
        _undoTimestamp = now;

        recalculateFromCurrentState();
        _forceNextFitFieldUpdate = true;
        saveSession();
    }


    function undoLastIntake() as Boolean {
        if (!_sessionActive || !_undoAvailable) {
            return false;
        }

        var now = getCurrentTimestamp();
        if (now - _undoTimestamp > FuelModelConsts.UNDO_WINDOW_SEC) {
            clearUndoState();
            return false;
        }

        _consumedTotalG = clampNonNegativeTotalG10(_consumedTotalG - _undoGramsG10);
        _intakeCount -= 1;
        if (_intakeCount < 0) {
            _intakeCount = 0;
        }

        clearUndoState();
        recalculateFromCurrentState();
        _forceNextFitFieldUpdate = true;
        saveSession();
        return true;
    }


    function isUndoAvailable() as Boolean {
        if (!_sessionActive || !_undoAvailable) {
            return false;
        }
        var now = getCurrentTimestamp();
        if (now - _undoTimestamp > FuelModelConsts.UNDO_WINDOW_SEC) {
            clearUndoState();
            return false;
        }
        return true;
    }


    function getUndoRemainingSec() as Number {
        if (!isUndoAvailable()) {
            return 0;
        }
        var now = getCurrentTimestamp();
        var remaining = FuelModelConsts.UNDO_WINDOW_SEC - (now - _undoTimestamp);
        if (remaining < 0) {
            return 0;
        }
        return remaining;
    }


    private function clearUndoState() as Void {
        _undoAvailable = false;
        _undoGramsG10 = 0;
        _undoTimestamp = 0;
    }


    function recordDefaultIntake() as Void {
        recordIntake(_doseG);
    }


    private function getCurrentTimestamp() as Number {
        return _clock.now();
    }

    function onTimerLap() as Void {
        if (!_sessionActive) {
            return;
        }

        saveSession();
    }

    function onTimerStart() as Void {
        refreshTouchMode(true);
        if (_sessionState == STATE_PAUSED) {
            resumeSessionFromTimerEvent();
            return;
        }
        if (!_sessionActive) {
            _timerStartEventPending = true;
        }
    }

    function onTimerStop() as Void {
        pauseSessionFromTimerEvent();
    }

    function onTimerPause() as Void {
        pauseSessionFromTimerEvent();
    }

    function onTimerResume() as Void {
        refreshTouchMode(true);
        resumeSessionFromTimerEvent();
    }

    function onTimerReset() as Void {
        _timerStartEventPending = false;
        _hasValidTimerData = false;
        if (_sessionState != STATE_IDLE && !_sessionFinishHandled) {
            markSessionFinished();
        }
    }

    private function pauseSessionFromTimerEvent() as Void {
        if (!_sessionActive || _sessionState == STATE_PAUSED) {
            return;
        }
        if (_usingElapsedTimeFallback && _pauseStartTimerS == null) {
            _pauseStartTimerS = _elapsedActiveSec + _pausedTimerOffsetS;
        }
        if (_pauseStartClockTs == null) {
            _pauseStartClockTs = getCurrentTimestamp();
        }
        setSessionState(STATE_PAUSED);
        _isReminderDue = false;
        _autoIntakeLocked = false;
        _autoIntakeEventPending = false;
        saveSession();
    }

    private function resumeSessionFromTimerEvent() as Void {
        if (_sessionState != STATE_PAUSED) {
            return;
        }
        if (_pauseStartClockTs != null) {
            var pausedClockDuration = getCurrentTimestamp() - _pauseStartClockTs;
            shiftReminderReferenceTimestamps(pausedClockDuration);
            if (_usingElapsedTimeFallback && _pauseStartTimerS != null) {
                if (pausedClockDuration > 0) {
                    _pausedTimerOffsetS += pausedClockDuration;
                }
                _pauseStartTimerS = null;
            }
        }
        _pauseStartClockTs = null;
        if (!_usingElapsedTimeFallback) {
            _pauseStartTimerS = null;
        }
        setSessionState(STATE_ACTIVE);
        saveSession();
    }


    // grams is always an integer Number, so * 10 is exact — no Float needed
    private function gramsToG10(grams as Number) as Number {
        return grams * 10;
    }

    // ── Getters ─────────────────────────────────────────

    function isSessionActive()      as Boolean { return _sessionActive; }
    function isPaused()             as Boolean { return _isPaused; }
    function isPriming()            as Boolean { return _sessionState == STATE_PRIMING; }
    function hasValidTimerData()    as Boolean { return _hasValidTimerData; }
    function isTouchInputEnabled()  as Boolean { return _isTouch; }
    function getElapsedActiveSec()  as Number  { return _elapsedActiveSec; }
    function getElapsedActiveHours()as Float   { return _elapsedActiveSec.toFloat() / 3600.0f; }
    function getConsumedTotalG10()  as Number  { return _consumedTotalG; }
    function getTargetTotalG10()    as Number  { return _targetTotalG; }
    function getDeficitG10()        as Number  { return _deficitG; }
    function getNextDueInSec()      as Number  { return _nextDueInSec; }
    function getDisplayNextDueInSec() as Number {
        if (_isReminderDue) {
            return 0;
        }
        if (_nextDueInSec > 0) {
            return _nextDueInSec;
        }
        return getSnoozeRemainingSec(getCurrentTimestamp());
    }
    function isReminderDue()        as Boolean { return _isReminderDue; }
    function getCarbsTargetGph()    as Number  { return _carbsTargetGph; }
    function getDoseG()             as Number  { return _doseG; }
    function getDoseG10()           as Number  { return _doseG * 10; }
    function getReminderMode()      as Number  { return _reminderMode; }
    function getFixedIntervalMin()  as Number  { return _fixedIntervalMin; }
    function isStoppedSession()     as Boolean { return _recoverySnapshotAvailable; }
    function supportsNativeDataFieldAlert() as Boolean {
        return WatchUi.DataField has :showAlert;
    }
    function isDataFieldAlertEnabled() as Boolean {
        return _dataFieldAlertEnabled && supportsNativeDataFieldAlert();
    }
    function getCarbFractionPct()   as Number  { return _carbFractionPct; }
    function isCaloriesAvailable()  as Boolean { return _caloriesAvailable; }
    function isCalorieModeActive()  as Boolean { return _reminderMode == MODE_CALORIE_AUTO; }

    function consumeAutoIntakeEvent() as Boolean {
        if (!_autoIntakeEventPending) {
            return false;
        }
        _autoIntakeEventPending = false;
        return true;
    }

    function getIntakeCount() as Number {
        return _intakeCount;
    }


    function getRecoveryDeficit() as Number? {
        if (!_recoverySnapshotAvailable || _recoverySnapshotElapsedSec <= 0) {
            return null;
        }

        var recoveryDeficitG10 = _recoverySnapshotTargetG10 - _recoverySnapshotConsumedG10;
        if (recoveryDeficitG10 <= 0) {
            return null;
        }
        return (recoveryDeficitG10 + 5) / 10;
    }


}
