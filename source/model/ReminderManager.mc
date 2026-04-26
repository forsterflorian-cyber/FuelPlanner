import Toybox.Lang;
import Toybox.Attention;
import Toybox.System;

//! Manages vibration reminders with defensive capability checks
class ReminderManager {
    
    // Vibration patterns
    private const VIBE_SHORT = 100;
    private const VIBE_MEDIUM = 200;
    private const VIBE_LONG = 400;
    private const VIBE_PAUSE = 100;
    
    private var _hasVibration as Boolean = false;
    private var _hasBacklight as Boolean = false;
    private var _lastVibeTime as Number = 0;
    private var _minVibInterval as Number = 2000; // Minimum 2 seconds between vibes
    private var _intakeReminderPattern as Array<Attention.VibeProfile>? = null;
    private var _autoIntakePattern as Array<Attention.VibeProfile>? = null;
    private var _confirmationPattern as Array<Attention.VibeProfile>? = null;
    private var _snoozePattern as Array<Attention.VibeProfile>? = null;
    private var _undoPattern as Array<Attention.VibeProfile>? = null;
    
    //! Constructor
    function initialize() {
        checkCapabilities();
    }

    private function getIntakeReminderPattern() as Array<Attention.VibeProfile> {
        if (_intakeReminderPattern == null) {
            _intakeReminderPattern = [
                new Attention.VibeProfile(100, VIBE_LONG),
                new Attention.VibeProfile(0, VIBE_PAUSE),
                new Attention.VibeProfile(100, VIBE_MEDIUM),
                new Attention.VibeProfile(0, VIBE_PAUSE),
                new Attention.VibeProfile(100, VIBE_LONG)
            ] as Array<Attention.VibeProfile>;
        }
        return _intakeReminderPattern as Array<Attention.VibeProfile>;
    }

    private function getAutoIntakePattern() as Array<Attention.VibeProfile> {
        if (_autoIntakePattern == null) {
            _autoIntakePattern = [
                new Attention.VibeProfile(45, VIBE_SHORT),
                new Attention.VibeProfile(0, 60),
                new Attention.VibeProfile(45, VIBE_SHORT)
            ] as Array<Attention.VibeProfile>;
        }
        return _autoIntakePattern as Array<Attention.VibeProfile>;
    }

    private function getConfirmationPattern() as Array<Attention.VibeProfile> {
        if (_confirmationPattern == null) {
            _confirmationPattern = [
                new Attention.VibeProfile(50, VIBE_SHORT),
                new Attention.VibeProfile(0, 50),
                new Attention.VibeProfile(50, VIBE_SHORT)
            ] as Array<Attention.VibeProfile>;
        }
        return _confirmationPattern as Array<Attention.VibeProfile>;
    }

    private function getSnoozePattern() as Array<Attention.VibeProfile> {
        if (_snoozePattern == null) {
            _snoozePattern = [
                new Attention.VibeProfile(25, VIBE_MEDIUM)
            ] as Array<Attention.VibeProfile>;
        }
        return _snoozePattern as Array<Attention.VibeProfile>;
    }

    private function getUndoPattern() as Array<Attention.VibeProfile> {
        if (_undoPattern == null) {
            // Triple pulse: deutlich anders als Confirmation (double pulse)
            // Signalisiert "Rückgängig gemacht"
            _undoPattern = [
                new Attention.VibeProfile(30, VIBE_SHORT),
                new Attention.VibeProfile(0, 80),
                new Attention.VibeProfile(30, VIBE_SHORT),
                new Attention.VibeProfile(0, 80),
                new Attention.VibeProfile(30, VIBE_SHORT)
            ] as Array<Attention.VibeProfile>;
        }
        return _undoPattern as Array<Attention.VibeProfile>;
    }
    
    //! Check device capabilities
    private function checkCapabilities() as Void {
        _hasVibration = false;

        // Check for vibration support
        if (Attention has :vibrate) {
            try {
                var deviceSettings = System.getDeviceSettings();
                if (deviceSettings != null &&
                    deviceSettings has :vibrateOn &&
                    deviceSettings.vibrateOn instanceof Boolean) {
                    _hasVibration = deviceSettings.vibrateOn;
                } else {
                    _hasVibration = true; // Assume available if we cannot query the setting
                }
            } catch (e) {
                _hasVibration = true;
            }
        } else {
            _hasVibration = false;
        }
        
        // Check for backlight support
        if (Attention has :backlight) {
            _hasBacklight = true;
        } else {
            _hasBacklight = false;
        }
    }

    public static function shouldVibrate(nextDueInSec as Number,
                                         isPaused as Boolean,
                                         consumedTotalG10 as Number,
                                         elapsedActiveSec as Number,
                                         startDelayMin as Number,
                                         lastReminderTimestamp as Number,
                                         maxSnoozeMin as Number,
                                         nowTimestamp as Number) as Boolean {
        var safeNextDueInSec = (nextDueInSec < 0) ? 0 : nextDueInSec;
        var safeElapsedActiveSec = (elapsedActiveSec < 0) ? 0 : elapsedActiveSec;
        var safeStartDelayMin = (startDelayMin < 0) ? 0 : startDelayMin;
        var safeMaxSnoozeMin = (maxSnoozeMin < 0) ? 0 : maxSnoozeMin;
        var safeNowTimestamp = (nowTimestamp < 0) ? 0 : nowTimestamp;

        if (isPaused) {
            return false;
        }

        if (consumedTotalG10 <= 0 && safeElapsedActiveSec < safeStartDelayMin * 60) {
            return false;
        }

        if (safeNextDueInSec > 0) {
            return false;
        }

        if (lastReminderTimestamp == 0) {
            return true;
        }

        return (safeNowTimestamp - lastReminderTimestamp) >= (safeMaxSnoozeMin * 60);
    }
    
    //! Trigger reminder vibration pattern
    function triggerReminder() as Boolean {
        // Rate limiting
        var now = System.getTimer();
        if (now - _lastVibeTime < _minVibInterval) {
            return false;
        }
        
        var delivered = false;
        
        // Try vibration
        if (_hasVibration) {
            delivered = vibratePattern(getIntakeReminderPattern());
        }
        
        // Also flash backlight if available
        if (_hasBacklight) {
            delivered = flashBacklight() || delivered;
        }
        
        if (delivered) {
            _lastVibeTime = now;
        }
        
        return delivered;
    }
    
    //! Trigger confirmation vibration (after intake recorded)
    function triggerConfirmation() as Boolean {
        if (!_hasVibration) {
            return false;
        }
        
        return vibratePattern(getConfirmationPattern());
    }

    //! Trigger Auto-Flow intake confirmation (short double pulse)
    function triggerAutoIntake() as Boolean {
        if (!_hasVibration) {
            return false;
        }

        var now = System.getTimer();
        if (now - _lastVibeTime < _minVibInterval) {
            return false;
        }

        var success = vibratePattern(getAutoIntakePattern());
        if (success) {
            _lastVibeTime = now;
        }
        return success;
    }

    //! Trigger snooze confirmation
    function triggerSnooze() as Boolean {
        if (!_hasVibration) {
            return false;
        }
        
        return vibratePattern(getSnoozePattern());
    }

    //! Trigger undo confirmation (triple pulse - distinct from intake confirmation)
    function triggerUndo() as Boolean {
        if (!_hasVibration) {
            return false;
        }
        
        return vibratePattern(getUndoPattern());
    }
    
    //! Execute vibration pattern
    private function vibratePattern(pattern as Array<Attention.VibeProfile>) as Boolean {
        try {
            if (Attention has :vibrate) {
                Attention.vibrate(pattern);
                return true;
            }
        } catch (e instanceof Lang.Exception) {
            // Vibration failed, continue silently
        } catch (e) {
        }
        return false;
    }
    
    //! Flash backlight
    private function flashBacklight() as Boolean {
        try {
            if (Attention has :backlight) {
                Attention.backlight(true);
                return true;
            }
        } catch (e instanceof Lang.Exception) {
            // Backlight failed, continue silently
        } catch (e) {
        }
        return false;
    }
    
    //! Check if vibration is available
    function hasVibration() as Boolean {
        return _hasVibration;
    }
    
    //! Check if backlight control is available
    function hasBacklight() as Boolean {
        return _hasBacklight;
    }
    
    //! Refresh capability check (call if settings might have changed)
    function refreshCapabilities() as Void {
        checkCapabilities();
    }
}
