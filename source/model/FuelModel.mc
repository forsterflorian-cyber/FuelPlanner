import Toybox.Lang;
import Toybox.Time;
import Toybox.Activity;
import Toybox.FitContributor;
import Toybox.System;

//! Core calculation model for fuel planning
class FuelModel {
    // Reminder modes
    public const MODE_AUTO         = 0;  // deficit-based with fixed g/h target
    public const MODE_FIXED        = 1;  // fixed interval from last intake
    public const MODE_CALORIE_AUTO = 2;  // target derived from watch calorie data

    // State
    private var _storage              as StorageManager;
    private var _sessionActive        as Boolean = false;
    private var _startTimestamp       as Number  = 0;
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
    private var _lastFitFieldUpdateMs as Number = 0;
    private var _forceNextFitFieldUpdate as Boolean = true;
    private const FIT_UPDATE_INTERVAL_MS = 5000;

    // Cached settings
    private var _carbsTargetGph    as Number = 60;
    private var _carbsTargetGph10  as Number = 600;
    private var _doseG             as Number = 25;
    private var _doseG10           as Number = 250;
    private var _reminderMode      as Number = 0;
    private var _fixedIntervalMin  as Number = 20;
    private var _startDelayMin     as Number = 15;
    private var _maxSnoozeMin      as Number = 5;
    private var _carbFractionPct   as Number = 60;  // % of kcal from carbs (40-80)

    // Last reminder timestamp (for snooze)
    private var _lastReminderTimestamp as Number = 0;

    // Computed values (updated each tick)
    private var _elapsedActiveHours  as Float   = 0.0f;
    private var _elapsedActiveSec    as Number  = 0;
    private var _targetTotalG        as Number  = 0; // g10
    private var _deficitG            as Number  = 0; // g10
    private var _nextDueInSec        as Number  = 0;
    private var _isReminderDue       as Boolean = false;

    // Calorie-auto mode: latest values from Activity.Info
    private var _latestCaloriesKcal      as Number = 0;   // cumulative kcal burned
    private var _latestEnergyExpKcalMin  as Float  = 0.0f; // current kcal/min
    private var _caloriesAvailable       as Boolean = false;

    // For pause detection
    private var _lastTimerTime      as Number = 0;
    private var _timerStallCount    as Number = 0;
    private var _pausedTimerOffsetS as Number = 0;
    private var _pauseStartTimerS   as Number? = null;
    private var _timerBacktrackCount as Number = 0;
    private const TIMER_BACKTRACK_RESET_DELTA_SEC = 10;
    private const TIMER_BACKTRACK_CONFIRM_TICKS = 4;

    //! Constructor
    function initialize(storage as StorageManager) {
        _storage = storage;
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
        _carbsTargetGph10 = _carbsTargetGph * 10;
        _doseG            = clampSetting(
            _storage.getDoseG(),
            _storage.MIN_DOSE_G,
            _storage.MAX_DOSE_G
        );
        _doseG10          = _doseG * 10;
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
        loadSettings();
        if (_sessionActive && !_isPaused) {
            recalculateFromCurrentState();
            _forceNextFitFieldUpdate = true;
        }
    }

    function setFitFields(fieldDeficit as FitContributor.Field?,
                          fieldConsumed as FitContributor.Field?) as Void {
        _fitFieldDeficit = fieldDeficit;
        _fitFieldConsumed = fieldConsumed;
        _forceNextFitFieldUpdate = true;
    }

    //! Load session from storage
    function loadSession() as Void {
        if (_storage.hasActiveSession()) {
            var sessionId = _storage.getSessionId();
            var startTs   = _storage.getStartTimestamp();

            if (sessionId != null && startTs != null) {
                _sessionId           = sessionId;
                _startTimestamp      = startTs;
                _consumedTotalG      = _storage.getConsumedTotalG10();

                var lastIntake       = _storage.getLastIntakeTimestamp();
                _lastIntakeTimestamp = (lastIntake != null) ? lastIntake : _startTimestamp;

                _isPaused            = _storage.getIsPaused();
                _elapsedActiveSec    = _storage.getElapsedActiveSec();
                _pausedTimerOffsetS  = _storage.getPausedTimerOffsetSec();
                _pauseStartTimerS    = _storage.getPauseStartTimerSec();
                _isStartTimestampConfirmed = _storage.getIsStartTimestampConfirmed();
                _intakeCount         = _storage.getIntakeCount();
                if (_pausedTimerOffsetS < 0) {
                    _pausedTimerOffsetS = 0;
                }
                if (_pauseStartTimerS != null && _pauseStartTimerS < 0) {
                    _pauseStartTimerS = null;
                }
                if (!_isPaused) {
                    _pauseStartTimerS = null;
                }
                if (_intakeCount <= 0 && _consumedTotalG > 0) {
                    // Backward compatibility for sessions saved before intake count was persisted.
                    _intakeCount = _storage.getIntakeLog().size();
                }
                _sessionActive = true;
            }
        }
    }

    //! Save session to storage
    function saveSession() as Void {
        if (_sessionActive) {
            _storage.setSessionId(_sessionId);
            _storage.setStartTimestamp(_startTimestamp);
            _storage.setConsumedTotalG10(_consumedTotalG);
            _storage.setLastIntakeTimestamp(_lastIntakeTimestamp);
            _storage.setIsPaused(_isPaused);
            _storage.setElapsedActiveSec(_elapsedActiveSec);
            _storage.setPausedTimerOffsetSec(_pausedTimerOffsetS);
            _storage.setPauseStartTimerSec(_isPaused ? _pauseStartTimerS : null);
            _storage.setIsStartTimestampConfirmed(_isStartTimestampConfirmed);
        }
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
        _sessionActive       = true;
        _intakeCount         = 0;
        _lastTimerTime       = 0;
        _timerStallCount     = 0;
        _pausedTimerOffsetS  = 0;
        _pauseStartTimerS    = null;
        _timerBacktrackCount = 0;

        _elapsedActiveHours     = 0.0f;
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
        _storage.clearIntakeLog();
        saveSession();
    }

    //! Main compute function — call every tick (1 Hz)
    function compute(info as Activity.Info?) as Void {
        // Reload settings every tick so changes made via the on-watch settings
        // menu or Garmin Connect are picked up immediately without an app restart.
        loadSettings();

        if (info == null) {
            return;
        }

        var timerTime = getTimerTime(info);

        if (timerTime == null) {
            if (_sessionActive) { _sessionActive = false; }
            resetDisplayValues();
            return;
        }

        var timerSec = timerTime / 1000;
        if (timerSec < 0) {
            timerSec = 0;
        }

        var activityStartTs = getActivityStartTimestamp(info);

        // Detect a new activity.
        if (activityStartTs != null) {
            _timerBacktrackCount = 0;
            if (_sessionActive) {
                if (_startTimestamp != activityStartTs) {
                    if (_isStartTimestampConfirmed) {
                        startNewSession(activityStartTs);
                    } else {
                        // We started from a fallback timestamp before startTime became available.
                        // Adopt the real activity start and keep current intake/session data.
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
            // Fallback: detect new activity when the timer resets/backtracks.
            // A short timer glitch must not reset the whole session.
            if (_sessionActive && isLikelyTimerReset(timerSec)) {
                startNewSession(null);
            } else if (!_sessionActive && timerSec > 0) {
                _timerBacktrackCount = 0;
                startNewSession(null);
            }
        }

        if (!_sessionActive) {
            resetDisplayValues();
            return;
        }

        var timerStatePaused = isTimerStatePaused(info);
        var effectiveTimerSec = getEffectiveTimerSec(timerSec, timerStatePaused);
        if (!timerStatePaused &&
            _elapsedActiveSec > 0 &&
            effectiveTimerSec + TIMER_BACKTRACK_RESET_DELTA_SEC < _elapsedActiveSec) {
            // Ignore transient timer backtracks until fallback reset detection confirms a real new session.
            effectiveTimerSec = _elapsedActiveSec;
        }
        _elapsedActiveSec = effectiveTimerSec;
        _elapsedActiveHours = _elapsedActiveSec.toFloat() / 3600.0f;

        detectPause(timerTime, timerStatePaused);
        if (_isPaused) {
            _isReminderDue = false;
            _autoIntakeLocked = false;
            updateFitFields(_fitFieldDeficit, _fitFieldConsumed);
            return;
        }

        updateCalorieData(info);

        // --- Calculate target in g10 (tenths of grams) ---
        if (_reminderMode == MODE_CALORIE_AUTO && _caloriesAvailable) {
            // Target = carbs the body has actually burned (estimated from watch calories)
            // Formula: kcal × carbFraction / 4 kcal-per-gram
            _targetTotalG = ((_latestCaloriesKcal * _carbFractionPct * 10) + 200) / 400;
        } else {
            var safeCarbsRateGph10 = (_carbsTargetGph10 > 0)
                ? _carbsTargetGph10
                : _storage.MIN_CARBS_TARGET_GPH * 10;
            _targetTotalG = (_elapsedActiveSec * safeCarbsRateGph10) / 3600;
        }

        _deficitG = _targetTotalG - _consumedTotalG;

        calculateNextDue();
        checkReminderDue();
        applyAutoIntakeIfDue();
        updateFitFields(_fitFieldDeficit, _fitFieldConsumed);
    }

    private function detectTouchScreen() as Boolean {
        try {
            var settings = System.getDeviceSettings();
            if (settings != null &&
                settings has :isTouchScreen &&
                settings.isTouchScreen instanceof Boolean) {
                return settings.isTouchScreen;
            }
        } catch (e) {}
        return false;
    }

    private function clampSetting(value as Number, min as Number, max as Number) as Number {
        if (value < min) { return min; }
        if (value > max) { return max; }
        return value;
    }

    private function isLikelyTimerReset(rawTimerSec as Number) as Boolean {
        if (_elapsedActiveSec <= 0) {
            _timerBacktrackCount = 0;
            return false;
        }

        var delta = _elapsedActiveSec - rawTimerSec;
        if (delta < TIMER_BACKTRACK_RESET_DELTA_SEC) {
            _timerBacktrackCount = 0;
            return false;
        }

        _timerBacktrackCount += 1;
        if (_timerBacktrackCount < TIMER_BACKTRACK_CONFIRM_TICKS) {
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

    function updateFitFields(fieldDeficit as FitContributor.Field?,
                             fieldConsumed as FitContributor.Field?) as Void {
        if (!isSessionActive()) {
            _forceNextFitFieldUpdate = true;
            return;
        }
        if (fieldDeficit == null && fieldConsumed == null) {
            return;
        }

        var nowMs = System.getTimer();
        var elapsedMs = nowMs - _lastFitFieldUpdateMs;
        if (!_forceNextFitFieldUpdate && elapsedMs >= 0 && elapsedMs < FIT_UPDATE_INTERVAL_MS) {
            return;
        }
        _lastFitFieldUpdateMs = nowMs;
        _forceNextFitFieldUpdate = false;

        try {
            if (fieldDeficit != null) {
                fieldDeficit.setData(_deficitG.toFloat() / 10.0f);
            }
        } catch (e) {}

        try {
            if (fieldConsumed != null) {
                fieldConsumed.setData(_consumedTotalG.toFloat() / 10.0f);
            }
        } catch (e) {}
    }

    private function getTimerTime(info as Activity.Info) as Number? {
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

    private function getActivityStartTimestamp(info as Activity.Info) as Number? {
        try {
            if (info has :startTime && info.startTime != null) {
                return info.startTime.value();
            }
        } catch (e instanceof Lang.Exception) {
        } catch (e) {
        }
        return null;
    }

    private function isTimerStatePaused(info as Activity.Info) as Boolean {
        try {
            if (info has :timerState &&
                Activity has :TIMER_STATE_PAUSED &&
                info.timerState == Activity.TIMER_STATE_PAUSED) {
                return true;
            }
        } catch (e) {}
        return false;
    }

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

    private function updateCalorieData(info as Activity.Info) as Void {
        _caloriesAvailable = false;
        _latestCaloriesKcal = 0;
        _latestEnergyExpKcalMin = 0.0f;

        try {
            if (info has :calories) {
                var calories = getNonNegativeNumberOrNull(info.calories);
                if (calories != null) {
                    _latestCaloriesKcal = calories;
                    _caloriesAvailable = true;
                }
            }
        } catch (e) {}

        try {
            if (info has :energyExpenditure) {
                var energyRate = toFloatOrNull(info.energyExpenditure);
                if (energyRate != null && energyRate > 0.0f) {
                    _latestEnergyExpKcalMin = energyRate;
                }
            }
        } catch (e) {}
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
    private function detectPause(timerTime as Number, timerStatePaused as Boolean) as Void {
        if (timerStatePaused) {
            _isPaused = true;
            _timerStallCount = 0;
            _lastTimerTime = timerTime;
            return;
        }

        if (_lastTimerTime > 0) {
            if (timerTime == _lastTimerTime) {
                _timerStallCount++;
                if (_timerStallCount >= 2) { _isPaused = true; }
            } else {
                _timerStallCount = 0;
                _isPaused = false;
            }
        }
        _lastTimerTime = timerTime;
    }

    private function resetDisplayValues() as Void {
        _elapsedActiveHours = 0.0f;
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
        _timerBacktrackCount = 0;
        _lastFitFieldUpdateMs = 0;
        _forceNextFitFieldUpdate = true;
    }

    //! Recompute target/deficit/reminder timing from current state and settings.
    private function recalculateFromCurrentState() as Void {
        if (_isPaused) {
            _isReminderDue = false;
            return;
        }

        if (_reminderMode == MODE_CALORIE_AUTO && _caloriesAvailable) {
            _targetTotalG = ((_latestCaloriesKcal * _carbFractionPct * 10) + 200) / 400;
        } else {
            var safeCarbsRateGph10 = (_carbsTargetGph10 > 0)
                ? _carbsTargetGph10
                : _storage.MIN_CARBS_TARGET_GPH * 10;
            _targetTotalG = (_elapsedActiveSec * safeCarbsRateGph10) / 3600;
        }

        _deficitG = _targetTotalG - _consumedTotalG;
        calculateNextDue();
        checkReminderDue();
    }

    function setPaused(paused as Boolean) as Void {
        _isPaused = paused;
        _forceNextFitFieldUpdate = true;
    }

    //! Calculate time until next intake is due
    private function calculateNextDue() as Void {
        var safeStartDelayMin = (_startDelayMin >= 0)
            ? _startDelayMin
            : _storage.MIN_START_DELAY_MIN;
        var safeDoseG10 = (_doseG10 > 0)
            ? _doseG10
            : _storage.MIN_DOSE_G * 10;
        var safeCarbsRateGph10 = (_carbsTargetGph10 > 0)
            ? _carbsTargetGph10
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
                _nextDueInSec = (startDelaySec + intervalSec) - _elapsedActiveSec;
                if (_nextDueInSec < 0) { _nextDueInSec = 0; }
            } else {
                var now = getCurrentTimestamp();
                _nextDueInSec = intervalSec - (now - _lastIntakeTimestamp);
                if (_nextDueInSec < 0) { _nextDueInSec = 0; }
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
                    _nextDueInSec = ((deficitNeededG10.toFloat() * 2400.0f) / rateNumerator).toNumber();
                } else {
                    _nextDueInSec = 9999;
                }
            } else {
                // ceil(needed * 3600 / rateG10PerHour)
                _nextDueInSec = ((deficitNeededG10 * 3600) + safeCarbsRateGph10 - 1) / safeCarbsRateGph10;
            }
        }
    }

    //! Check if reminder should fire
    private function checkReminderDue() as Void {
        if (_isPaused) { _isReminderDue = false; return; }

        // Never fire during the start delay (before any intake)
        if (_consumedTotalG == 0 && _elapsedActiveSec < _startDelayMin * 60) {
            _isReminderDue = false;
            return;
        }

        if (_nextDueInSec <= 0) {
            var snoozeSec             = _maxSnoozeMin * 60;
            var now                   = getCurrentTimestamp();
            var timeSinceLastReminder = now - _lastReminderTimestamp;

            _isReminderDue = (_lastReminderTimestamp == 0 ||
                              timeSinceLastReminder >= snoozeSec);
        } else {
            _isReminderDue = false;
        }
    }

    function recordReminderTriggered() as Void {
        _lastReminderTimestamp = getCurrentTimestamp();
    }

    function snoozeReminder() as Void {
        _lastReminderTimestamp = getCurrentTimestamp();
        _isReminderDue = false;
    }

    function recordIntake(grams as Number) as Void {
        if (!_sessionActive) { return; }
        var gramsG10 = gramsToG10(grams);
        if (gramsG10 <= 0) { return; }
        var now              = getCurrentTimestamp();
        _consumedTotalG     += gramsG10;
        _lastIntakeTimestamp = now;
        _lastReminderTimestamp = 0;
        _isReminderDue       = false;
        _storage.addIntakeEntry(now, grams, "manual");
        _intakeCount += 1;
        _forceNextFitFieldUpdate = true;
        saveSession();
    }

    function recordDefaultIntake() as Void {
        recordIntake(_doseG);
    }

    function undoLastIntake() as Boolean {
        if (!_sessionActive) {
            return false;
        }

        if (!_storage.removeLastIntakeEntry()) {
            return false;
        }

        rebuildIntakeStateFromLog();
        _lastReminderTimestamp = 0;
        _deficitG = _targetTotalG - _consumedTotalG;
        calculateNextDue();
        checkReminderDue();
        _forceNextFitFieldUpdate = true;
        saveSession();
        return true;
    }

    private function rebuildIntakeStateFromLog() as Void {
        var log = _storage.getIntakeLog();
        var totalG10 = 0;
        var lastTs = _startTimestamp;
        var intakeCount = 0;

        for (var i = 0; i < log.size(); i += 1) {
            var entry = log[i];
            if (entry instanceof Dictionary) {
                intakeCount += 1;
                var grams = toNumberOrNull(entry["g"]);
                if (grams != null) {
                    totalG10 += gramsToG10(grams);
                }

                var ts = toNumberOrNull(entry["t"]);
                if (ts != null) {
                    lastTs = ts;
                }
            }
        }

        _consumedTotalG = totalG10;
        _lastIntakeTimestamp = lastTs;
        _intakeCount = intakeCount;
    }

    private function getCurrentTimestamp() as Number {
        return Time.now().value();
    }

    private function gramsToG10(grams as Number) as Number {
        var g10 = (grams.toFloat() * 10.0f);
        if (g10 >= 0.0f) {
            return (g10 + 0.5f).toNumber();
        }
        return (g10 - 0.5f).toNumber();
    }

    // ── Getters ─────────────────────────────────────────

    function isSessionActive()      as Boolean { return _sessionActive; }
    function isPaused()             as Boolean { return _isPaused; }
    function getElapsedActiveSec()  as Number  { return _elapsedActiveSec; }
    function getElapsedActiveHours()as Float   { return _elapsedActiveHours; }
    function getConsumedTotalG()    as Number  { return (_consumedTotalG + 5) / 10; }
    function getTargetTotalG()      as Float   { return _targetTotalG.toFloat() / 10.0f; }
    function getDeficitG()          as Float   { return _deficitG.toFloat() / 10.0f; }
    function getConsumedTotalG10()  as Number  { return _consumedTotalG; }
    function getTargetTotalG10()    as Number  { return _targetTotalG; }
    function getDeficitG10()        as Number  { return _deficitG; }
    function getNextDueInSec()      as Number  { return _nextDueInSec; }
    function isReminderDue()        as Boolean { return _isReminderDue; }
    function getCarbsTargetGph()    as Number  { return _carbsTargetGph; }
    function getDoseG()             as Number  { return _doseG; }
    function getDoseG10()           as Number  { return _doseG10; }
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

    function getAverageGph() as Float {
        if (_elapsedActiveHours < 0.01f) { return 0.0f; }
        return (_consumedTotalG.toFloat() / 10.0f) / _elapsedActiveHours;
    }

    function getIntakeCount() as Number {
        return _intakeCount;
    }
}
