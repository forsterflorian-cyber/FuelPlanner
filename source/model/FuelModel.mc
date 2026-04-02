import Toybox.Lang;
import Toybox.Time;
import Toybox.Activity;
import Toybox.FitContributor;
import Toybox.System;
import FuelPlannerLog;

// Module-level constants: stored in bytecode, not per-instance heap
module FuelModelConsts {
    const FIT_UPDATE_INTERVAL_MS          = 5000;
    const TIMER_BACKTRACK_RESET_DELTA_SEC = 30;  // Erhöht von 10: Verhindert falsche Session-Resets bei GPS-Aussetzern
    const TIMER_BACKTRACK_CONFIRM_TICKS   = 6;   // Erhöht von 4: Erfordert längeren konstanten Reset für Session-Neustart
    const MAX_ELAPSED_ACTIVE_SEC          = 604800; // 7 days
    const MAX_TOTAL_G10                   = 200000; // 20,000 g
    const MAX_NEXT_DUE_SEC                = 359999; // 99h 59m 59s
    const MAX_CALORIES_KCAL               = 20000;
    const MAX_ENERGY_RATE_KCAL_MIN        = 40.0f;
    const MAX_MANUAL_INTAKE_G             = 200;
    const PRIMING_CONFIRM_SEC = 3;
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
    public const MODE_AUTO         = 0;  // deficit-based with fixed g/h target
    public const MODE_FIXED        = 1;  // fixed interval from last intake
    public const MODE_CALORIE_AUTO = 2;  // target derived from watch calorie data
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
    private var _reminderMode      as Number = 0;
    private var _fixedIntervalMin  as Number = 20;
    private var _startDelayMin     as Number = 15;
    private var _maxSnoozeMin      as Number = 5;
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

    // For undo functionality
    (:full)
    private var _undoAvailable      as Boolean = false;
    (:full)
    private var _undoGramsG10       as Number = 0;
    (:full)
    private var _undoTimestamp      as Number = 0;

    //! Constructor
    function initialize(storage as StorageManager, clock as FuelClock?) {
        _storage = storage;
        _clock = (clock != null) ? clock : new FuelClock();
        _isTouch = detectTouchScreen();
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
        _carbFractionPct  = clampSetting(
            _storage.getCarbFractionPct(),
            _storage.MIN_CARB_FRACTION_PCT,
            _storage.MAX_CARB_FRACTION_PCT
        );
    }

    //! Called when settings change externally (e.g., Garmin Connect phone app).
    //! Refreshes configuration immediately without resetting session state.
    function onSettingsChanged() as Void {
        _isTouch = detectTouchScreen();
        loadSettings();
        _calorieDataMissingTicks = 0;
        _calorieAutoSuspendedUntilSec = 0;
        if (_sessionActive) {
            recalculateFromCurrentState();
            _forceNextFitFieldUpdate = true;
        }
    }

    (:full)
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

    //! Load session from storage
    function loadSession() as Void {
        if (!_storage.hasActiveSession()) {
            if (_sessionActive) {
                clearSessionState();
            }
            return;
        }

        var sessionId = _storage.getSessionId();
        var startTs   = _storage.getStartTimestamp();

        if (sessionId != null && startTs != null) {
            var safeNow = getCurrentTimestamp();
            if (safeNow < startTs) {
                safeNow = startTs;
            }

            _sessionId           = sessionId;
            _startTimestamp      = startTs;
            _consumedTotalG      = clampNonNegativeTotalG10(_storage.getConsumedTotalG10());

            var lastIntake       = _storage.getLastIntakeTimestamp();
            _lastIntakeTimestamp = (lastIntake != null) ? lastIntake : _startTimestamp;
            if (_lastIntakeTimestamp < _startTimestamp) {
                _lastIntakeTimestamp = _startTimestamp;
            } else if (_lastIntakeTimestamp > safeNow) {
                _lastIntakeTimestamp = safeNow;
            }

            _isPaused            = _storage.getIsPaused();
            _elapsedActiveSec    = clampElapsedActiveSec(_storage.getElapsedActiveSec());
            _pausedTimerOffsetS  = clampElapsedActiveSec(_storage.getPausedTimerOffsetSec());
            if (_pausedTimerOffsetS > _elapsedActiveSec) {
                _pausedTimerOffsetS = _elapsedActiveSec;
            }
            _pauseStartTimerS    = _storage.getPauseStartTimerSec();
            _pauseStartClockTs   = _storage.getPauseStartClockSec();
            _isStartTimestampConfirmed = _storage.getIsStartTimestampConfirmed();
            _intakeCount         = _storage.getIntakeCount();
            _lastReminderTimestamp = _storage.getLastReminderTimestamp();
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

            if (_isPaused) {
                setSessionState(STATE_PAUSED);
            } else if (!_isStartTimestampConfirmed) {
                setSessionState(STATE_PRIMING);
            } else {
                setSessionState(STATE_ACTIVE);
            }

            recalculateFromCurrentState();
        }
    }

    //! Save session to storage
    function saveSession() as Void {
        if (_sessionState == STATE_IDLE) {
            return;
        }

        if (!_sessionRecoverable || _sessionState == STATE_FINISHED) {
            _storage.clearSession();
            return;
        }

        flushFitSessionSummary();
        _storage.setSessionId(_sessionId);
        _storage.setStartTimestamp(_startTimestamp);
        _storage.setConsumedTotalG10(_consumedTotalG);
        _storage.setLastIntakeTimestamp(_lastIntakeTimestamp);
        _storage.setLastReminderTimestamp(_lastReminderTimestamp);
        _storage.setIntakeCount(_intakeCount);
        _storage.setIsPaused(_isPaused);
        _storage.setElapsedActiveSec(_elapsedActiveSec);
        _storage.setPausedTimerOffsetSec(_pausedTimerOffsetS);
        _storage.setPauseStartTimerSec(_isPaused ? _pauseStartTimerS : null);
        _storage.setPauseStartClockSec(_isPaused ? _pauseStartClockTs : null);
        _storage.setIsStartTimestampConfirmed(_isStartTimestampConfirmed);
    }

    //! Start a new session
    function startNewSession(activityStartTs as Number?) as Void {
        var now              = (activityStartTs != null) ? activityStartTs : getCurrentTimestamp();
        _sessionId           = now;
        _startTimestamp      = now;
        _consumedTotalG      = 0;
        _lastIntakeTimestamp = now;
        _isPaused            = false;
        _isStartTimestampConfirmed = (activityStartTs != null);
        _lastReminderTimestamp = 0;
        _autoIntakeLocked    = false;
        _autoIntakeEventPending = false;
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
        _timerBacktrackCount = 0;

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

    private function reconcileSessionState(activityStartTs as Number?,
                                           timerSec as Number,
                                           timerStatePaused as Boolean,
                                           timerStateStoppedOrOff as Boolean) as Void {
        if (_sessionState == STATE_IDLE) {
            resetDisplayValues();
            return;
        }

        if (timerStateStoppedOrOff) {
            if (_sessionState != STATE_FINISHED) {
                setSessionState(STATE_FINISHED);
            }
            return;
        }

        if (timerStatePaused) {
            setSessionState(STATE_PAUSED);
            return;
        }
        // Fallback-started session: hold in priming briefly until the timer
        // looks stable, so we do not immediately "trust" a transient start.
        if (!_isStartTimestampConfirmed &&
            activityStartTs == null &&
            timerSec < FuelModelConsts.PRIMING_CONFIRM_SEC) {
            setSessionState(STATE_PRIMING);
            return;
        }

        setSessionState(STATE_ACTIVE);
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
        resetDisplayValues();
    }

    (:full)
    private function markSessionFinished() as Void {
        if (_sessionState == STATE_IDLE) {
            return;
        }

        writeFitSessionSummary(_fitFieldTargetSummary, _fitFieldActualSummary);
        _sessionRecoverable = false;
        _pauseStartTimerS = null;
        _pauseStartClockTs = null;
        _lastReminderTimestamp = 0;
        _isReminderDue = false;
        _autoIntakeLocked = false;
        _autoIntakeEventPending = false;
        _storage.clearSession();
        _sessionFinishHandled = true;
    }

    (:lite)
    private function markSessionFinished() as Void {
        if (_sessionState == STATE_IDLE) {
            return;
        }

        _sessionRecoverable = false;
        _pauseStartTimerS = null;
        _pauseStartClockTs = null;
        _lastReminderTimestamp = 0;
        _isReminderDue = false;
        _autoIntakeLocked = false;
        _autoIntakeEventPending = false;
        _storage.clearSession();
        _sessionFinishHandled = true;
    }
    //! Main compute function — call every tick (1 Hz)
    function compute(info) as Void {
        if (info == null) {
            return;
        }

        var timerTime = getTimerTime(info);

        if (timerTime == null) {
            if (_sessionState == STATE_IDLE) {
                resetDisplayValues();
                return;
            }
            _isReminderDue = false;
            _autoIntakeLocked = false;
            _autoIntakeEventPending = false;
            return;
        }

        var timerSec = timerTime / 1000;
        if (timerSec < 0) {
            timerSec = 0;
        }

        var activityStartTs = getActivityStartTimestamp(info);
        handleActivityStartDetection(activityStartTs, timerSec);
        handleTimerState(info, timerTime, timerSec);
        handleSessionStates(info);
    }

    //! Detect new activity or timer reset
    private function handleActivityStartDetection(activityStartTs as Number?,
                                                  timerSec as Number) as Void {
        if (activityStartTs != null) {
            _timerBacktrackCount = 0;
            if (_sessionActive) {
                if (_startTimestamp != activityStartTs) {
                    if (_isStartTimestampConfirmed) {
                        startNewSession(activityStartTs);
                    } else {
                        _startTimestamp = activityStartTs;
                        _sessionId = activityStartTs;
                        _isStartTimestampConfirmed = true;
                        saveSession();
                    }
                } else if (!_isStartTimestampConfirmed) {
                    _sessionId = activityStartTs;
                    _isStartTimestampConfirmed = true;
                    saveSession();
                }
            } else if (timerSec > 0) {
                startNewSession(activityStartTs);
            }
        } else {
            if (_sessionActive && isLikelyTimerReset(timerSec)) {
                startNewSession(null);
            } else if (!_sessionActive && timerSec > 0) {
                _timerBacktrackCount = 0;
                startNewSession(null);
            }
        }
    }

    //! Handle timer state and update elapsed time
    private function handleTimerState(info as Activity.Info?, timerTime as Number, timerSec as Number) as Void {
        var timerStatePaused = isTimerStatePaused(info);
        var effectiveTimerSec = getEffectiveTimerSec(timerSec, timerStatePaused);
        if (!timerStatePaused &&
            _elapsedActiveSec > 0 &&
            effectiveTimerSec + FuelModelConsts.TIMER_BACKTRACK_RESET_DELTA_SEC < _elapsedActiveSec) {
            effectiveTimerSec = _elapsedActiveSec;
        }
        _elapsedActiveSec = clampElapsedActiveSec(effectiveTimerSec);

        var timerStateStoppedOrOff = isTimerStateStoppedOrOff(info);
        var pauseDetected = detectPause(timerTime, timerStatePaused);
        var activityStartTs = getActivityStartTimestamp(info);
        reconcileSessionState(activityStartTs, timerSec, timerStatePaused || pauseDetected, timerStateStoppedOrOff);
    }

    //! Handle session state-specific logic
    private function handleSessionStates(info as Activity.Info?) as Void {
        if (_sessionState == STATE_IDLE) {
            resetDisplayValues();
            return;
        }

        if (_sessionState == STATE_FINISHED) {
            if (!_sessionFinishHandled) {
                markSessionFinished();
            }
            _nextDueInSec = 0;
            updateFitFields();
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

    (:lite)
    private function detectTouchScreen() as Boolean {
        return false;
    }

    (:full)
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

    (:full)
    private function clampSetting(value as Number, min as Number, max as Number) as Number {
        if (value < min) { return min; }
        if (value > max) { return max; }
        return value;
    }

    (:lite)
    private function clampSetting(value as Number, min as Number, max as Number) as Number {
        return value;
    }

    (:full)
    private function clampElapsedActiveSec(value as Number) as Number {
        if (value < 0) {
            return 0;
        }
        if (value > FuelModelConsts.MAX_ELAPSED_ACTIVE_SEC) {
            return FuelModelConsts.MAX_ELAPSED_ACTIVE_SEC;
        }
        return value;
    }

    (:lite)
    private function clampElapsedActiveSec(value as Number) as Number {
        return value;
    }

    (:full)
    private function clampTotalG10(value as Number) as Number {
        if (value > FuelModelConsts.MAX_TOTAL_G10) {
            return FuelModelConsts.MAX_TOTAL_G10;
        }
        if (value < -FuelModelConsts.MAX_TOTAL_G10) {
            return -FuelModelConsts.MAX_TOTAL_G10;
        }
        return value;
    }

    (:lite)
    private function clampTotalG10(value as Number) as Number {
        return value;
    }

    (:full)
    private function clampNonNegativeTotalG10(value as Number) as Number {
        if (value < 0) {
            return 0;
        }
        if (value > FuelModelConsts.MAX_TOTAL_G10) {
            return FuelModelConsts.MAX_TOTAL_G10;
        }
        return value;
    }

    (:lite)
    private function clampNonNegativeTotalG10(value as Number) as Number {
        return value;
    }

    (:full)
    private function clampNextDueSec(value as Number) as Number {
        if (value < 0) {
            return 0;
        }
        if (value > FuelModelConsts.MAX_NEXT_DUE_SEC) {
            return FuelModelConsts.MAX_NEXT_DUE_SEC;
        }
        return value;
    }

    (:lite)
    private function clampNextDueSec(value as Number) as Number {
        return value;
    }

    (:full)
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

    (:lite)
    private function shiftReminderReferenceTimestamps(pausedDurationSec as Number) as Void {
    }

    (:full)
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

    (:lite)
    private function getSnoozeRemainingSec(nowTimestamp as Number) as Number {
        return 0;
    }

    (:full)
    private function isLikelyTimerReset(rawTimerSec as Number) as Boolean {
        if (_elapsedActiveSec <= 0) {
            _timerBacktrackCount = 0;
            return false;
        }

        // Nur als Reset werten, wenn Timer wirklich auf 0 oder nahe 0 ist
        // Verhindert falsche Resets bei GPS-Aussetzern oder Gerätesleep
        if (rawTimerSec > 5) {
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

    (:lite)
    private function isLikelyTimerReset(rawTimerSec as Number) as Boolean {
        if (_elapsedActiveSec <= 0) {
            return false;
        }

        if (rawTimerSec > 5) {
            return false;
        }

        var delta = _elapsedActiveSec - rawTimerSec;
        if (delta < FuelModelConsts.TIMER_BACKTRACK_RESET_DELTA_SEC) {
            return false;
        }

        return true;
    }

    (:full)
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

    (:lite)
    private function applyAutoIntakeIfDue() as Void {
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

    (:full)
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
        } catch (e) {}

        try {
            if (_fitFieldConsumed != null) {
                _fitFieldConsumed.setData(_consumedTotalG.toFloat() / 10.0f);
            }
        } catch (e) {}

        writeFitSessionSummary(_fitFieldTargetSummary, _fitFieldActualSummary);
    }

    (:lite)
    private function updateFitFields() as Void {
        _forceNextFitFieldUpdate = true;
    }

    (:full)
    function flushFitSessionSummary() as Void {
        if (!_sessionActive) {
            return;
        }
        writeFitSessionSummary(_fitFieldTargetSummary, _fitFieldActualSummary);
    }

    (:lite)
    function flushFitSessionSummary() as Void {
    }

    (:full)
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

    (:full)
    private function getTimerTime(info) as Number? {
        try {
            if (info has :timerTime) {
                var timerTime = getNonNegativeNumberOrNull(info.timerTime);
                if (timerTime != null) {
                    return timerTime;
                }
            }
        } catch (e) {}

        // Some devices/profiles expose elapsed time instead of timerTime.
        try {
            if (info has :elapsedTime) {
                var elapsedTime = getNonNegativeNumberOrNull(info.elapsedTime);
                if (elapsedTime != null) {
                    return elapsedTime;
                }
            }
        } catch (e) {}
        return null;
    }

    (:lite)
    private function getTimerTime(info) as Number? {
        try {
            if (info has :timerTime) {
                var timerTime = getNonNegativeNumberOrNull(info.timerTime);
                if (timerTime != null) {
                    return timerTime;
                }
            }
        } catch (e) {}

        try {
            if (info has :elapsedTime) {
                var elapsedTime = getNonNegativeNumberOrNull(info.elapsedTime);
                if (elapsedTime != null) {
                    return elapsedTime;
                }
            }
        } catch (e) {}
        return null;
    }

    (:full)
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

    (:lite)
    private function getActivityStartTimestamp(info) as Number? {
        try {
            if (info has :startTime && info.startTime != null) {
                return info.startTime.value();
            }
        } catch (e) {}
        return null;
    }

    (:full)
    private function isTimerStatePaused(info) as Boolean {
        try {
            if (info has :timerState &&
                Activity has :TIMER_STATE_PAUSED &&
                info.timerState == Activity.TIMER_STATE_PAUSED) {
                return true;
            }
        } catch (e) {}
        return false;
    }

    (:lite)
    private function isTimerStatePaused(info) as Boolean {
        try {
            if (info has :timerState &&
                Activity has :TIMER_STATE_PAUSED &&
                info.timerState == Activity.TIMER_STATE_PAUSED) {
                return true;
            }
        } catch (e) {}
        return false;
    }

    (:full)
    private function isTimerStateStoppedOrOff(info) as Boolean {
        return FuelPlannerUtils.isTimerStateStoppedOrOff(info);
    }

    (:lite)
    private function isTimerStateStoppedOrOff(info) as Boolean {
        return FuelPlannerUtils.isTimerStateStoppedOrOff(info);
    }

    (:full)
    private function getEffectiveTimerSec(rawTimerSec as Number,
                                          timerStatePaused as Boolean) as Number {
        if (timerStatePaused) {
            if (_pauseStartTimerS == null) {
                _pauseStartTimerS = rawTimerSec;
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
            var pausedDuration = rawTimerSec - pauseStartForDelta;
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

    (:lite)
    private function getEffectiveTimerSec(rawTimerSec as Number,
                                          timerStatePaused as Boolean) as Number {
        if (timerStatePaused) {
            if (_pauseStartTimerS == null) {
                _pauseStartTimerS = rawTimerSec;
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
            var pausedDuration = rawTimerSec - pauseStartForDelta;
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

    (:full)
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

    (:lite)
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

        if (_reminderMode == MODE_CALORIE_AUTO) {
            if (hasCalorieDataThisTick) {
                _calorieDataMissingTicks = 0;
                if (_calorieAutoSuspendedUntilSec > 0 &&
                    _elapsedActiveSec >= _calorieAutoSuspendedUntilSec) {
                    _calorieAutoSuspendedUntilSec = 0;
                }
            } else {
                _calorieDataMissingTicks += 1;
                if (_calorieDataMissingTicks >= CALORIE_FALLBACK_TICKS) {
                    _reminderMode = MODE_AUTO;
                    _calorieDataMissingTicks = 0;
                    _calorieAutoSuspendedUntilSec = _elapsedActiveSec + CALORIE_SUSPEND_DURATION_SEC;
                }
            }
        }

        if (_calorieAutoSuspendedUntilSec > 0 &&
            hasCalorieDataThisTick &&
            _elapsedActiveSec >= _calorieAutoSuspendedUntilSec) {
            _reminderMode = MODE_CALORIE_AUTO;
            _calorieAutoSuspendedUntilSec = 0;
            calculateNextDue();
            checkReminderDue();
        }
    }

    (:lite)
    private function toNumberOrNull(value as Lang.Object?) as Number? {
        if (value instanceof Number) {
            return value;
        }
        return null;
    }

    (:full)
    private function toNumberOrNull(value as Lang.Object?) as Number? {
        if (value instanceof Number) {
            return value;
        }
        return null;
    }

    (:lite)
    private function getNonNegativeNumberOrNull(value as Lang.Object?) as Number? {
        var numberValue = toNumberOrNull(value);
        if (numberValue != null && numberValue >= 0) {
            return numberValue;
        }
        return null;
    }

    (:full)
    private function getNonNegativeNumberOrNull(value as Lang.Object?) as Number? {
        var numberValue = toNumberOrNull(value);
        if (numberValue != null && numberValue >= 0) {
            return numberValue;
        }
        return null;
    }

    (:lite)
    private function toFloatOrNull(value as Lang.Object?) as Float? {
        if (value instanceof Float) {
            return value;
        }
        if (value instanceof Number) {
            return value.toFloat();
        }
        return null;
    }

    (:full)
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
    (:full)
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

    (:lite)
    private function detectPause(timerTime as Number, timerStatePaused as Boolean) as Boolean {
        var wasPaused = (_sessionState == STATE_PAUSED);
        var pauseDetected = false;

        if (timerStatePaused) {
            pauseDetected = true;
            _timerStallCount = 0;
            _lastTimerTime = timerTime;
        } else if (wasPaused && _pauseStartClockTs != null && _lastTimerTime == 0) {
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
        _timerBacktrackCount = 0;
        _lastFitFieldUpdateMs = 0;
        _forceNextFitFieldUpdate = true;
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

        // reminderMode == 2 ist MODE_CALORIE_AUTO (kann in static method nicht als Instanz-Konstante gelesen werden)
        if (reminderMode == 2 && caloriesAvailable) {
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

    (:full)
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

        _deficitG = clampTotalG10(FuelModel.calculateDeficit(
            _elapsedActiveSec,
            _consumedTotalG,
            _carbsTargetGph,
            _reminderMode,
            _latestCaloriesKcal,
            _carbFractionPct,
            _caloriesAvailable,
            _storage.MIN_CARBS_TARGET_GPH
        ));
    }

    (:lite)
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

        _deficitG = clampTotalG10(FuelModel.calculateDeficit(
            _elapsedActiveSec,
            _consumedTotalG,
            _carbsTargetGph,
            _reminderMode,
            _latestCaloriesKcal,
            _carbFractionPct,
            _caloriesAvailable,
            _storage.MIN_CARBS_TARGET_GPH
        ));
    }

    //! Recompute target/deficit/reminder timing from current state and settings.
    (:full)
    private function recalculateFromCurrentState() as Void {
        if (_sessionState == STATE_IDLE) {
            resetDisplayValues();
            return;
        }

        calculateTargetAndDeficit();

        if (_sessionState == STATE_PRIMING ||
            _sessionState == STATE_PAUSED ||
            _sessionState == STATE_FINISHED) {
            _nextDueInSec = 0;
            _isReminderDue = false;
            return;
        }

        calculateNextDue();
        checkReminderDue();
    }

    (:lite)
    private function recalculateFromCurrentState() as Void {
        if (_sessionState == STATE_IDLE) {
            resetDisplayValues();
            return;
        }

        calculateTargetAndDeficit();

        if (_sessionState == STATE_PRIMING ||
            _sessionState == STATE_PAUSED ||
            _sessionState == STATE_FINISHED) {
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
    }

    //! Calculate time until next intake is due
    (:full)
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

    (:lite)
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
                var rateNumerator = _latestEnergyExpKcalMin * _carbFractionPct.toFloat();
                if (rateNumerator > 0.0f) {
                    _nextDueInSec = clampNextDueSec(((deficitNeededG10.toFloat() * 2400.0f) / rateNumerator).toNumber());
                } else {
                    _nextDueInSec = FuelModelConsts.MAX_NEXT_DUE_SEC;
                }
            } else {
                _nextDueInSec = clampNextDueSec(((deficitNeededG10 * 3600) + safeCarbsRateGph10 - 1) / safeCarbsRateGph10);
            }
        }
    }

    //! Check if reminder should fire
    (:full)
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

    private function getSafeStartDelaySec() as Number {
        var safeStartDelayMin = (_startDelayMin >= 0)
            ? _startDelayMin
            : _storage.MIN_START_DELAY_MIN;
        return safeStartDelayMin * 60;
    }

    private function getSafeDoseG10() as Number {
        if (_doseG > 0) {
            return _doseG * 10;
        }
        return _storage.MIN_DOSE_G * 10;
    }

    private function getPlannedIntakeCycleSec() as Number {
        if (_reminderMode == MODE_FIXED) {
            var safeIntervalMin = (_fixedIntervalMin > 0)
                ? _fixedIntervalMin
                : _storage.MIN_FIXED_INTERVAL_MIN;
            return clampNextDueSec(safeIntervalMin * 60);
        }

        var safeDoseG10 = getSafeDoseG10();
        if (_reminderMode == MODE_CALORIE_AUTO && _latestEnergyExpKcalMin > 0.0f) {
            var rateNumerator = _latestEnergyExpKcalMin * _carbFractionPct.toFloat();
            if (rateNumerator > 0.0f) {
                return clampNextDueSec(((safeDoseG10.toFloat() * 2400.0f) / rateNumerator).toNumber());
            }
        }

        var safeCarbsRateGph10 = (_carbsTargetGph > 0)
            ? _carbsTargetGph * 10
            : _storage.MIN_CARBS_TARGET_GPH * 10;
        if (safeCarbsRateGph10 <= 0) {
            return 0;
        }
        return clampNextDueSec(((safeDoseG10 * 3600) + safeCarbsRateGph10 - 1) / safeCarbsRateGph10);
    }

    private function getRingWarningLeadSec(cycleSec as Number) as Number {
        if (cycleSec <= 0) {
            return 0;
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
            if (warningLeadSec < 1) {
                warningLeadSec = 1;
            }
        }
        return warningLeadSec;
    }

    function getRingAlertTone() as Number {
        if (!_sessionActive && _sessionState != STATE_FINISHED) {
            return RING_TONE_GREEN;
        }
        if (_isPaused) {
            return RING_TONE_GREEN;
        }
        if (_consumedTotalG <= 0 && _elapsedActiveSec < getSafeStartDelaySec()) {
            return RING_TONE_GREEN;
        }
        if (_isReminderDue || _nextDueInSec <= 0) {
            return RING_TONE_RED;
        }

        if (_reminderMode != MODE_FIXED && _deficitG >= getSafeDoseG10()) {
            return RING_TONE_RED;
        }

        var warningLeadSec = getRingWarningLeadSec(getPlannedIntakeCycleSec());
        if (warningLeadSec > 0 && _nextDueInSec <= warningLeadSec) {
            return RING_TONE_YELLOW;
        }

        return RING_TONE_GREEN;
    }

    (:lite)
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

    (:full)
    function recordReminderTriggered() as Void {
        _lastReminderTimestamp = getCurrentTimestamp();
        _isReminderDue = false;
        _forceNextFitFieldUpdate = true;
        saveSession();
    }

    (:lite)
    function recordReminderTriggered() as Void {
        _lastReminderTimestamp = getCurrentTimestamp();
        _isReminderDue = false;
        saveSession();
    }

    (:full)
    function snoozeReminder() as Void {
        if (!_sessionActive) {
            return;
        }
        _lastReminderTimestamp = getCurrentTimestamp();
        _isReminderDue = false;
        _forceNextFitFieldUpdate = true;
        saveSession();
    }

    (:lite)
    function snoozeReminder() as Void {
        if (!_sessionActive) {
            return;
        }
        _lastReminderTimestamp = getCurrentTimestamp();
        _isReminderDue = false;
        saveSession();
    }

    (:full)
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

    (:lite)
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
        
        recalculateFromCurrentState();
        saveSession();
    }

    (:full)
    function undoLastIntake() as Boolean {
        if (!_sessionActive || !_undoAvailable) {
            return false;
        }
        
        var now = getCurrentTimestamp();
        // Allow undo within 10 seconds
        if (now - _undoTimestamp > 10) {
            _undoAvailable = false;
            return false;
        }
        
        _consumedTotalG = clampNonNegativeTotalG10(_consumedTotalG - _undoGramsG10);
        _intakeCount -= 1;
        if (_intakeCount < 0) {
            _intakeCount = 0;
        }
        
        _undoAvailable = false;
        recalculateFromCurrentState();
        _forceNextFitFieldUpdate = true;
        saveSession();
        return true;
    }

    (:lite)
    function undoLastIntake() as Boolean {
        return false;
    }

    (:full)
    function isUndoAvailable() as Boolean {
        if (!_sessionActive || !_undoAvailable) {
            return false;
        }
        var now = getCurrentTimestamp();
        return (now - _undoTimestamp) <= 10;
    }

    (:lite)
    function isUndoAvailable() as Boolean {
        return false;
    }

    (:full)
    function getUndoRemainingSec() as Number {
        if (!_sessionActive || !_undoAvailable) {
            return 0;
        }
        var now = getCurrentTimestamp();
        var remaining = 10 - (now - _undoTimestamp);
        if (remaining < 0) {
            return 0;
        }
        return remaining;
    }

    (:lite)
    function getUndoRemainingSec() as Number {
        return 0;
    }

    (:full)
    function recordDefaultIntake() as Void {
        recordIntake(_doseG);
    }

    (:lite)
    function recordDefaultIntake() as Void {
        recordIntake(_doseG);
    }

    private function getCurrentTimestamp() as Number {
        return _clock.now();
    }

    (:full)
    function onTimerLap() as Void {
        if (!_sessionActive) {
            return;
        }

        saveSession();
    }

    (:lite)
    function onTimerLap() as Void {
        if (!_sessionActive) {
            return;
        }

        saveSession();
    }

    // grams is always an integer Number, so * 10 is exact — no Float needed
    private function gramsToG10(grams as Number) as Number {
        return grams * 10;
    }

    // ── Getters ─────────────────────────────────────────

    function isSessionActive()      as Boolean { return _sessionActive; }
    function isPaused()             as Boolean { return _isPaused; }
    function getElapsedActiveSec()  as Number  { return _elapsedActiveSec; }
    (:full)
    function getElapsedActiveHours()as Float   { return _elapsedActiveSec.toFloat() / 3600.0f; }
    (:lite)
    function getElapsedActiveHours()as Float   { return 0.0f; }
    function getConsumedTotalG10()  as Number  { return _consumedTotalG; }
    function getTargetTotalG10()    as Number  { return _targetTotalG; }
    function getDeficitG10()        as Number  { return _deficitG; }
    function getNextDueInSec()      as Number  { return _nextDueInSec; }
    function getRingTone()          as Number  { return getRingAlertTone(); }
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

    (:full)
    function getIntakeCount() as Number {
        return _intakeCount;
    }

    (:lite)
    function getIntakeCount() as Number {
        return _intakeCount;
    }

    (:full)
    function getRecoveryDeficit() as Number? {
        if ((_sessionState != STATE_FINISHED && !_sessionActive) || _elapsedActiveSec <= 0) {
            return null;
        }

        var recoveryDeficitG10 = _targetTotalG - _consumedTotalG;
        if (recoveryDeficitG10 <= 0) {
            return null;
        }
        return (recoveryDeficitG10 + 5) / 10;
    }

    (:lite)
    function getRecoveryDeficit() as Number? {
        if ((_sessionState != STATE_FINISHED && !_sessionActive) || _elapsedActiveSec <= 0) {
            return null;
        }

        var recoveryDeficitG10 = _targetTotalG - _consumedTotalG;
        if (recoveryDeficitG10 <= 0) {
            return null;
        }
        return (recoveryDeficitG10 + 5) / 10;
    }

}
