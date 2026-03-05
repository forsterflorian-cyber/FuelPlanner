# FuelPlanner - Garmin Connect IQ Data Field

A fuel/carbohydrate intake tracker for endurance activities on Garmin watches.

## Features

- **Real-time tracking** of carbohydrate intake during activities
- **Auto mode**: Reminders based on deficit reaching your gel/dose size
- **Fixed interval mode**: Reminders at set intervals (e.g., every 20 min)
- **Calorie Auto mode**: Uses watch calorie/energy data — no fixed g/h rate needed
- **Vibration alerts** when it's time to fuel
- **Pause-aware**: Paused time doesn't count toward targets
- **Session persistence**: Data survives watch restarts

## Supported Devices

- Forerunner 955 / 955 Solar
- Forerunner 965
- Fenix 7 / 7S / 7X
- Epix (Gen 2)

Requires Connect IQ 5.2.0 or higher.

## Installation

### From Connect IQ Store
1. Search for "FuelPlanner" in the Connect IQ Store
2. Install to your device

### Manual Build
1. Install [Connect IQ SDK](https://developer.garmin.com/connect-iq/sdk/)
2. Clone this repository
3. Build **Data Field**:
   ```bash
   monkeyc -f monkey.jungle -o FuelPlanner.prg -d fr955 -y developer_key.der
   ```
4. Build **Widget (Settings app)**:
   ```bash
   monkeyc -f monkey-widget.jungle -o FuelPlanner-Widget.prg -d fr955 -y developer_key.der
   ```

**VS Code:** To run the widget, set `monkeyC.jungleFiles` to `monkey-widget.jungle` in project settings, then use "Run Widget (Settings)" launch config.

   Configuration
Settings (via Garmin Connect Mobile or Express)
| Setting | Default | Range | Description |
|---------|---------|-------|-------------|
| Carbs Target | 60 g/h | 20–120 | Target carbohydrate intake rate (Auto mode) |
| Gel Size | 25 g | 5–100 | Size of one gel/dose for quick logging |
| Reminder Mode | Auto | Auto / Fixed / Calorie Auto | How reminders are triggered |
| Fixed Interval | 20 min | 5–60 | Interval for Fixed mode |
| Start Delay | 15 min | 0–30 | Delay before first reminder |
| Snooze Time | 5 min | 1–10 | Time between repeated reminders |
| Carb % of kcal | 60 % | 40–80 | Carb fraction used in Calorie Auto mode |
Sport Presets
Run: 60 g/h, 25g gel
Bike: 90 g/h, 30g gel
Hike: 40 g/h, 20g gel
Usage During Activity
Adding as Data Field
On your watch, go to activity settings
Select "Data Screens"
Add a custom data screen
Select "FuelPlanner" as the data field
Display Layout
text
┌─────────────────────┐
│     Next 07:30      │  ← Time until next intake
│                     │
│       Carbs         │
│     35 / 60g        │  ← Consumed / Target
│   target 60 g/h     │
│                     │
│    Deficit 12g      │  ← Or "Ahead Xg"
│                     │
│  45m | 2 intakes    │  ← Status bar
└─────────────────────┘
Button Controls
Button	Action
START/LAP	Record gel intake (default dose)
UP	Snooze current reminder
DOWN	Toggle manual pause
Touch Controls (touchscreen devices)
Area	Action
Top third	Snooze
Middle	Record intake
Swipe Up	Record 40g
Swipe Down	Record 10g
Long press	Intake options (future)
Indicators
"FUEL NOW" (flashing): Time to eat!
"PAUSED": Activity paused, timer stopped
"DUE": Intake is overdue
Red deficit: You're behind target
Green "Ahead": You're ahead of target
How It Works
### Auto Mode (Default)
Calculates your target based on elapsed active time × target rate. When the deficit reaches your gel size, it reminds you. Example: at 60 g/h with 25 g gels, first reminder ~25 min in.

### Fixed Mode
Triggers reminder at fixed intervals from activity start. First reminder after start delay; subsequent reminders every N minutes from last intake.

### Calorie Auto Mode
Uses the watch's own calorie/energy expenditure data (HR-based). Target carbs = `calories_burned × carb_fraction / 4`. No fixed g/h rate needed — adapts to your actual effort level.
Test Plan
Basic Functionality
Start an activity (Run/Bike)
Verify data field shows "Waiting..." then activates
After start_delay minutes, verify reminder triggers
Press START to log intake
Verify consumed increases, deficit decreases
Verify next due time recalculates
Pause Handling
During activity, pause (STOP button)
Verify "PAUSED" displays
Wait 2 minutes
Resume activity
Verify elapsed time doesn't include pause
Edge Cases
Start activity, immediately pause
Very long activity (3+ hours)
Multiple quick intakes
Device restart during activity
Technical Notes
Data Persistence
Session data stored in Application.Storage
Intake log limited to 50 entries (rolling)
Settings persist across app restarts
Battery Considerations
Compute runs at 1 Hz (standard for data fields)
Minimal UI redraws
No background processing
Known Limitations
Pause detection is heuristic (timer-based)
Limited button access in data field mode
Cannot show custom picker dialogs during activity
Troubleshooting
Reminder not vibrating?

Check watch vibration settings (not on silent)
Verify activity is not paused
Data not persisting?

Ensure activity ends normally (Save, not Discard)
Check storage isn't full
Wrong target showing?

Settings sync may take a moment
Force sync via Garmin Connect app
Version History
### v1.0.0 (MVP)
- Initial release
- Auto, Fixed, and Calorie Auto reminder modes
- Basic session tracking
- Vibration alerts
- On-watch settings widget
License