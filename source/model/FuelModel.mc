import Toybox.Lang;
import Toybox.Time;
import Toybox.Activity;
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
    private var _consumedTotalG       as Number  = 0;
    private var _lastIntakeTimestamp  as Number  = 0;
    private var _isPaused             as Boolean = false;
    private var _sessionId            as Number  = 0;
    private var _isStartTimestampConfirmed as Boolean = false;

    // Cached settings
    private var _carbsTargetGph    as Number = 60;
    private var _doseG             as Number = 25;
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
    private var _targetTotalG        as Float   = 0.0f;
    private var _deficitG            as Float   = 0.0f;
    private var _nextDueInSec        as Number  = 0;
    private var _isReminderDue       as Boolean = false;

    // Calorie-auto mode: latest values from Activity.Info
    private var _latestCaloriesKcal      as Number = 0;   // cumulative kcal burned
    private var _latestEnergyExpKcalMin  as Float  = 0.0f; // current kcal/min
    private var _caloriesAvailable       as Boolean = false;
    private var _startTimeUnavailableLogged as Boolean = false;

    // For pause detection
    private var _lastTimerTime   as Number = 0;
    private var _timerStallCount as Number = 0;

    //! Constructor
    function initialize(storage as StorageManager) {
        _storage = storage;
        loadSettings();
    }

    //! Load settings from storage
    function loadSettings() as Void {
        _carbsTargetGph   = _storage.getCarbsTargetGph();
        _doseG            = _storage.getDoseG();
        _reminderMode     = _storage.getReminderMode();
        _fixedIntervalMin = _storage.getFixedIntervalMin();
        _startDelayMin    = _storage.getStartDelayMin();
        _maxSnoozeMin     = _storage.getMaxSnoozeMin();
        _carbFractionPct  = _storage.getCarbFractionPct();
    }

    //! Load session from storage
    function loadSession() as Void {
        if (_storage.hasActiveSession()) {
            var sessionId = _storage.getSessionId();
            var startTs   = _storage.getStartTimestamp();

            if (sessionId != null && startTs != null) {
                _sessionId           = sessionId;
                _startTimestamp      = startTs;
                _consumedTotalG      = _storage.getConsumedTotal();

                var lastIntake       = _storage.getLastIntakeTimestamp();
                _lastIntakeTimestamp = (lastIntake != null) ? lastIntake : _startTimestamp;

                _isPaused            = _storage.getIsPaused();
                _elapsedActiveSec    = _storage.getElapsedActiveSec();
                _isStartTimestampConfirmed = _storage.getIsStartTimestampConfirmed();
                _sessionActive = true;
            }
        }
    }

    //! Save session to storage
    function saveSession() as Void {
        if (_sessionActive) {
            _storage.setSessionId(_sessionId);
            _storage.setStartTimestamp(_startTimestamp);
            _storage.setConsumedTotal(_consumedTotalG);
            _storage.setLastIntakeTimestamp(_lastIntakeTimestamp);
            _storage.setIsPaused(_isPaused);
            _storage.setElapsedActiveSec(_elapsedActiveSec);
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
        _sessionActive       = true;
        _lastTimerTime       = 0;
        _timerStallCount     = 0;

        _elapsedActiveHours     = 0.0f;
        _elapsedActiveSec       = 0;
        _targetTotalG           = 0.0f;
        _deficitG               = 0.0f;
        _nextDueInSec           = 0;
        _isReminderDue          = false;
        _latestCaloriesKcal     = 0;
        _latestEnergyExpKcalMin = 0.0f;
        _caloriesAvailable      = false;

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

        var activityStartTs = getActivityStartTimestamp(info);

        // Detect a new activity.
        if (activityStartTs != null) {
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
            // Data Fields may not run while their screen is hidden, so we might
            // first see the new activity after timerSec already advanced.
            if (_sessionActive && timerSec + 2 < _elapsedActiveSec) {
                startNewSession(null);
            } else if (!_sessionActive && timerSec > 0) {
                startNewSession(null);
            }
        }

        if (!_sessionActive) {
            resetDisplayValues();
            return;
        }

        _elapsedActiveSec   = timerSec;
        _elapsedActiveHours = _elapsedActiveSec.toFloat() / 3600.0f;

        detectPause(timerTime);

        updateCalorieData(info);

        // --- Calculate target ---
        if (_reminderMode == MODE_CALORIE_AUTO && _caloriesAvailable) {
            // Target = carbs the body has actually burned (estimated from watch calories)
            // Formula: kcal × carbFraction / 4 kcal-per-gram
            var frac = _carbFractionPct.toFloat() / 100.0f;
            _targetTotalG = _latestCaloriesKcal.toFloat() * frac / 4.0f;
        } else {
            // Fixed rate target
            _targetTotalG = _elapsedActiveHours * _carbsTargetGph.toFloat();
        }

        _deficitG = _targetTotalG - _consumedTotalG.toFloat();

        calculateNextDue();
        checkReminderDue();
    }

    private function getTimerTime(info as Activity.Info) as Number? {
        try {
            if (info has :timerTime && info.timerTime instanceof Number) {
                return info.timerTime;
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
            if (!_startTimeUnavailableLogged) {
                System.println("FuelPlanner startTime unavailable: " + e.getErrorMessage());
                _startTimeUnavailableLogged = true;
            }
        } catch (e) {}
        return null;
    }

    private function updateCalorieData(info as Activity.Info) as Void {
        _caloriesAvailable = false;
        _latestEnergyExpKcalMin = 0.0f;

        try {
            if (info has :calories) {
                var calories = toNumberOrNull(info.calories);
                if (calories != null) {
                    _latestCaloriesKcal = calories;
                    _caloriesAvailable = true;
                }
            }
        } catch (e) {}

        try {
            if (info has :energyExpenditure) {
                var energyRate = toFloatOrNull(info.energyExpenditure);
                if (energyRate != null) {
                    _latestEnergyExpKcalMin = energyRate;
                }
            }
        } catch (e) {}
    }

    private function toNumberOrNull(value) as Number? {
        if (value instanceof Number) {
            return value;
        }
        return null;
    }

    private function toFloatOrNull(value) as Float? {
        if (value instanceof Float) {
            return value;
        }
        if (value instanceof Number) {
            return value.toFloat();
        }
        return null;
    }

    //! Detect pause from timer stall
    private function detectPause(timerTime as Number) as Void {
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
        _targetTotalG       = 0.0f;
        _deficitG           = 0.0f;
        _nextDueInSec       = 0;
        _isReminderDue      = false;
    }

    function setPaused(paused as Boolean) as Void {
        _isPaused = paused;
    }

    //! Calculate time until next intake is due
    private function calculateNextDue() as Void {
        var startDelaySec = _startDelayMin * 60;

        if (_consumedTotalG == 0 && _elapsedActiveSec < startDelaySec) {
            _nextDueInSec = startDelaySec - _elapsedActiveSec;
            return;
        }

        if (_reminderMode == MODE_FIXED) {
            // Fixed interval from last intake; first reminder after delay + one full interval
            var intervalSec = _fixedIntervalMin * 60;
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

        // MODE_AUTO and MODE_CALORIE_AUTO: deficit-based
        if (_deficitG >= _doseG.toFloat()) {
            _nextDueInSec = 0;
        } else {
            var deficitNeeded   = _doseG.toFloat() - _deficitG;
            var ratePerSecond;

            if (_reminderMode == MODE_CALORIE_AUTO && _latestEnergyExpKcalMin > 0.0f) {
                // Use live energy expenditure rate for more accurate prediction
                var frac    = _carbFractionPct.toFloat() / 100.0f;
                ratePerSecond = _latestEnergyExpKcalMin * frac / 4.0f / 60.0f;
            } else {
                ratePerSecond = _carbsTargetGph.toFloat() / 3600.0f;
            }

            if (ratePerSecond > 0.0f) {
                _nextDueInSec = (deficitNeeded / ratePerSecond).toNumber();
            } else {
                _nextDueInSec = 9999;
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
        var now              = getCurrentTimestamp();
        _consumedTotalG     += grams;
        _lastIntakeTimestamp = now;
        _lastReminderTimestamp = 0;
        _isReminderDue       = false;
        _storage.addIntakeEntry(now, grams, "manual");
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
        _deficitG = _targetTotalG - _consumedTotalG.toFloat();
        calculateNextDue();
        checkReminderDue();
        saveSession();
        return true;
    }

    private function rebuildIntakeStateFromLog() as Void {
        var log = _storage.getIntakeLog();
        var totalG = 0;
        var lastTs = _startTimestamp;

        for (var i = 0; i < log.size(); i += 1) {
            var entry = log[i];
            if (entry instanceof Dictionary) {
                var grams = toNumberOrNull(entry["g"]);
                if (grams != null) {
                    totalG += grams;
                }

                var ts = toNumberOrNull(entry["t"]);
                if (ts != null) {
                    lastTs = ts;
                }
            }
        }

        _consumedTotalG = totalG;
        _lastIntakeTimestamp = lastTs;
    }

    private function getCurrentTimestamp() as Number {
        return Time.now().value();
    }

    // ── Getters ─────────────────────────────────────────

    function isSessionActive()      as Boolean { return _sessionActive; }
    function isPaused()             as Boolean { return _isPaused; }
    function getElapsedActiveSec()  as Number  { return _elapsedActiveSec; }
    function getElapsedActiveHours()as Float   { return _elapsedActiveHours; }
    function getConsumedTotalG()    as Number  { return _consumedTotalG; }
    function getTargetTotalG()      as Float   { return _targetTotalG; }
    function getDeficitG()          as Float   { return _deficitG; }
    function getNextDueInSec()      as Number  { return _nextDueInSec; }
    function isReminderDue()        as Boolean { return _isReminderDue; }
    function getCarbsTargetGph()    as Number  { return _carbsTargetGph; }
    function getDoseG()             as Number  { return _doseG; }
    function getReminderMode()      as Number  { return _reminderMode; }
    function getCarbFractionPct()   as Number  { return _carbFractionPct; }
    function isCaloriesAvailable()  as Boolean { return _caloriesAvailable; }
    function isCalorieModeActive()  as Boolean { return _reminderMode == MODE_CALORIE_AUTO; }

    function getAverageGph() as Float {
        if (_elapsedActiveHours < 0.01f) { return 0.0f; }
        return _consumedTotalG.toFloat() / _elapsedActiveHours;
    }

    function getIntakeCount() as Number {
        return _storage.getIntakeLog().size();
    }
}
