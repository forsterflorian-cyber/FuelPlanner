# FuelPlanner - Garmin Connect IQ

Carbohydrate intake tracker for endurance activities. FuelPlanner is a data-field-only app with an on-watch settings menu.

Supported languages: English, Deutsch

---

## Features

- Real-time tracking of carbohydrate intake during activities
- Auto mode: reminder fires when your deficit reaches one gel or dose
- Fixed interval mode: reminder at fixed intervals
- Calorie Auto mode: uses watch calorie or energy data and adapts to actual effort
- Vibration and backlight alerts when it is time to fuel
- Pause-aware session logic
- Session persistence across watch restarts and app switches
- On-watch settings menu plus Garmin Connect settings sync

---

## Supported Devices

Touch and button devices running Connect IQ 3.3.0 or later.

Current manifest targets:
Forerunner 165 / 165 Music / 255 / 255 Music / 255S / 255S Music / 265 / 265S / 955 / 965,
Fenix 6X Pro / 7 / 7S / 7X / 7 Pro / 7S Pro / 7X Pro / 8 Solar 47 mm / 8 Solar 51 mm,
Epix Gen 2 / Epix Pro 42 mm / 47 mm / 51 mm,
Venu 2 / 2S / 2 Plus / 3 / 3S / Venu Sq 2 / Venu Sq 2 Music / Vivoactive 5,
D2 Air X10 / D2 Mach 1, Enduro 3, MARQ 2 / MARQ 2 Aviator.

---

## Installation

### From Connect IQ Store

Search for `FuelPlanner` in the data field category.

### Manual Build

1. Install the [Connect IQ SDK](https://developer.garmin.com/connect-iq/sdk/).
2. Clone this repository.
3. Run `.\build.ps1`.

Or build manually:

```text
monkeyc -f monkey.jungle -o FuelPlanner-DataField.iq -d fr965 -y developer_key -e
```

---

## Configuration

Settings are available from the activity data field settings menu or through Garmin Connect.

| Setting | Default | Range | Description |
|---------|---------|-------|-------------|
| Carbs Target | 60 g/h | 20-120 | Target carb rate in Auto mode |
| Gel Size | 25 g | 5-100 | Size of one gel or dose |
| Reminder Mode | Auto | Auto / Fixed / Calorie Auto | Reminder logic |
| Fixed Interval | 20 min | 5-60 | Interval for Fixed mode |
| Start Delay | 15 min | 0-60 | Delay before first reminder |
| Snooze Time | 5 min | 1-15 | Minimum gap between reminders |
| Carb % of kcal | 60 % | 40-80 | Carb fraction used in Calorie Auto mode |

Sport presets available on-watch:

| Preset | Target | Gel Size |
|--------|--------|----------|
| Running | 60 g/h | 25 g |
| Cycling | 90 g/h | 30 g |
| Hiking | 40 g/h | 20 g |

---

## Controls

Touch input:

| Tap zone | Normal state | Reminder active |
|----------|--------------|-----------------|
| Top 25% | Half dose (minimum 5 g) | Snooze |
| Middle 50% | Default dose | Default dose |
| Bottom 25% | Double dose | Double dose |

Button input:

On any device that emits key events, hold `DOWN` while the FuelPlanner data field is visible to log the default gel or dose.
This provides a fallback when touch interaction is locked during an activity.
Short `LAP` remains the normal lap action; hold `LAP` for about one second to undo the last logged intake.

---

## Reminder Modes

Auto mode calculates `elapsed_hours * target_g_per_hour`. When the deficit reaches gel size, the reminder fires.

Fixed interval mode reminds after start delay plus one interval, then repeats from the last intake.

Calorie Auto mode uses watch calorie or energy data. Target carbs = `calories_burned * carb_fraction / 4`.

---

## Troubleshooting

Settings not applying on watch:
Configure the data field on-watch through `FuelPlanner -> Settings` or through Garmin Connect, then sync.

Reminder not vibrating:
Check that vibration is enabled in the watch system settings.

Session reset unexpectedly:
The data field starts a fresh session when it detects a timer reset or backtrack.

---

## Version History

### v1.0.0

- Initial release with Auto, Fixed, and Calorie Auto reminder modes
- Session persistence and rolling intake log
- Vibration and backlight alerts with snooze
- On-watch settings menu
- Sport presets
