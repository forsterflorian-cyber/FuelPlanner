# FuelPlanner - Garmin Connect IQ Data Field

FuelPlanner is a carbohydrate intake tracker for endurance activities.
It is a data-field-only app with an on-watch settings menu and Garmin Connect settings sync.

Current release: **v0.1.0 (Initial Beta)**

Supported languages: English, Deutsch

---

## Features

- Real-time carb deficit tracking during activities
- Reminder modes:
  - Auto (deficit-based)
  - Fixed interval
  - Calorie Auto (watch calorie/energy based)
- Auto-Flow on non-touch devices:
  - if reminder is due, the default dose is booked automatically
- Smart-Pause compensation:
  - paused/stalled timer time is excluded from active fueling math
- FIT recording:
  - custom FIT fields for deficit and consumed carbs
  - visible in Garmin Connect activity summary/charts
- Session persistence across activity/data field restarts
- Integer tenths-of-grams math + throttled FIT updates for efficiency

---

## Supported Devices

- App type: `datafield`
- Minimum API level: `3.0.0`
- Permission: `FitContributor`
- Product targets: see `manifest.xml` (currently 67 device profiles)

---

## Installation

### From Connect IQ Store

Search for `FuelPlanner` in the Data Field category.

### Manual Build

1. Install the [Connect IQ SDK](https://developer.garmin.com/connect-iq/sdk/).
2. Clone this repository.
3. Run `.\build.ps1`.

Manual compile example:

```text
monkeyc -f monkey.jungle -o FuelPlanner-DataField.iq -d fr965 -y developer_key -e
```

---

## Configuration

Settings are available from the activity data field settings menu or Garmin Connect.

| Setting | Default | Range | Description |
|---------|---------|-------|-------------|
| Carbs Target | 60 g/h | 20-120 | Target carb rate in Auto mode |
| Gel Size | 25 g | 5-100 | Size of one gel/dose |
| Reminder Mode | Auto | Auto / Fixed / Calorie Auto | Reminder logic |
| Fixed Interval | 20 min | 5-60 | Interval for Fixed mode |
| Start Delay | 15 min | 0-60 | Delay before first reminder |
| Snooze Time | 5 min | 1-15 | Minimum gap between reminders |
| Carb % of kcal | 60 % | 40-80 | Used in Calorie Auto mode |

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

Non-touch devices:

- No manual key-binding intake action is currently implemented in the field delegate.
- Auto-Flow handles intake booking automatically when reminder is due.

---

## Reminder Logic

- Auto mode: target carbs = `elapsed_active_time * carbs_target_rate`; reminder when deficit reaches one dose.
- Fixed mode: reminder on interval timing from last intake (with start delay handling).
- Calorie Auto: target carbs = `calories_burned * carb_fraction / 4`.
- Smart-Pause: paused/stalled timer phases are excluded from active elapsed calculation.

---

## Version History

### v0.1.0 - Initial Beta

- Auto / Fixed / Calorie Auto reminder modes
- Auto-Flow for non-touch devices
- FIT deficit/consumed recording for Garmin Connect analysis
- Smart-Pause compensation and timer resilience
- On-watch settings menu with Garmin Connect property sync
