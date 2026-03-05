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
    private var _confirmationPattern as Array<Attention.VibeProfile>? = null;
    private var _snoozePattern as Array<Attention.VibeProfile>? = null;
    
    //! Constructor
    function initialize() {
        buildPatterns();
        checkCapabilities();
    }

    private function buildPatterns() as Void {
        _intakeReminderPattern = [
            new Attention.VibeProfile(100, VIBE_LONG),
            new Attention.VibeProfile(0, VIBE_PAUSE),
            new Attention.VibeProfile(100, VIBE_MEDIUM),
            new Attention.VibeProfile(0, VIBE_PAUSE),
            new Attention.VibeProfile(100, VIBE_LONG)
        ] as Array<Attention.VibeProfile>;

        _confirmationPattern = [
            new Attention.VibeProfile(50, VIBE_SHORT),
            new Attention.VibeProfile(0, 50),
            new Attention.VibeProfile(50, VIBE_SHORT)
        ] as Array<Attention.VibeProfile>;

        _snoozePattern = [
            new Attention.VibeProfile(25, VIBE_MEDIUM)
        ] as Array<Attention.VibeProfile>;
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
    
    //! Trigger reminder vibration pattern
    function triggerReminder() as Boolean {
        // Rate limiting
        var now = System.getTimer();
        if (now - _lastVibeTime < _minVibInterval) {
            return false;
        }
        
        var success = false;
        
        // Try vibration
        if (_hasVibration && _intakeReminderPattern != null) {
            success = vibratePattern(_intakeReminderPattern as Array<Attention.VibeProfile>);
        }
        
        // Also flash backlight if available
        if (_hasBacklight) {
            flashBacklight();
        }
        
        if (success) {
            _lastVibeTime = now;
        }
        
        return success;
    }
    
    //! Trigger confirmation vibration (after intake recorded)
    function triggerConfirmation() as Boolean {
        if (!_hasVibration || _confirmationPattern == null) {
            return false;
        }
        
        return vibratePattern(_confirmationPattern as Array<Attention.VibeProfile>);
    }
    
    //! Trigger snooze confirmation
    function triggerSnooze() as Boolean {
        if (!_hasVibration || _snoozePattern == null) {
            return false;
        }
        
        return vibratePattern(_snoozePattern as Array<Attention.VibeProfile>);
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
            System.println("Vibration failed: " + e.getErrorMessage());
        } catch (e) {
        }
        return false;
    }
    
    //! Flash backlight
    private function flashBacklight() as Void {
        try {
            if (Attention has :backlight) {
                Attention.backlight(true);
            }
        } catch (e instanceof Lang.Exception) {
            // Backlight failed, continue silently
        } catch (e) {
        }
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
