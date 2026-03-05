# FuelPlanner — Garmin Connect IQ

Carbohydrate intake tracker for endurance activities. Available as a **Data Field** and a companion **Settings Widget**.

Supported languages: English, Deutsch

---

## Features

- **Real-time tracking** of carbohydrate intake during activities
- **Auto mode**: reminder fires when your deficit reaches one gel/dose size
- **Fixed interval mode**: reminder at fixed intervals (e.g. every 20 min)
- **Calorie Auto mode**: uses watch calorie/energy data — target adapts to actual effort
- **Vibration + backlight alerts** when it's time to fuel
- **Pause-aware**: timer-stall detection, paused time excluded from targets
- **Session persistence**: survives watch restarts and app switches
- **On-watch settings widget**: change all settings without touching your phone

---

## Supported Devices

All touchscreen devices running Connect IQ 4.2+:

Forerunner 165 / 255 / 265 / 955 / 965 · Fenix 7 / 7S / 7X / 7 Pro / 8 Solar · Epix Gen 2 (42/47/51mm) · Venu 2 / 2S / 2 Plus / 3 / 3S · Vivoactive 5 · Venue Sq2 · D2 Air X10 / Mach1 · Enduro 3 · MARQ2 · FR255S/SM

---

## Installation

### From Connect IQ Store
Search for **FuelPlanner** (Data Field) and **FuelPlanner Settings** (Widget).

### Manual Build
1. Install the [Connect IQ SDK](https://developer.garmin.com/connect-iq/sdk/)
2. Clone this repository
3. Run `build.ps1` — builds both `.iq` files automatically

Or build individually:
```
monkeyc -f monkey.jungle        -o FuelPlanner-DataField.iq -d fr965 -y developer_key.der -e
monkeyc -f monkey-widget.jungle -o FuelPlanner-Widget.iq    -d fr965 -y developer_key.der -e
```

---

## Configuration

Settings are accessible via the **Settings Widget** on the watch or via **Garmin Connect** (synced to the watch).

| Setting | Default | Range | Description |
|---------|---------|-------|-------------|
| Carbs Target | 60 g/h | 20–120 | Target carb rate (Auto mode) |
| Gel Size | 25 g | 5–60 | Size of one gel/dose |
| Reminder Mode | Auto | Auto / Fixed / Calorie Auto | How reminders trigger |
| Fixed Interval | 20 min | 5–60 | Interval for Fixed mode |
| Start Delay | 15 min | 0–30 | Delay before first reminder |
| Snooze Time | 5 min | 1–10 | Minimum gap between repeated reminders |
| Carb % of kcal | 60 % | 40–80 | Carb fraction used in Calorie Auto mode |

**Sport Presets** (apply via widget menu):

| Preset | Target | Gel Size |
|--------|--------|----------|
| Running | 60 g/h | 25 g |
| Cycling | 90 g/h | 30 g |
| Hiking | 40 g/h | 20 g |

---

## Data Field Layout

```
┌─────────────────────────┐
│     Nächste 07:30       │  ← Status: time until next intake
│                         │
│       35 / 60g          │  ← Consumed / Target (large number font)
│                         │
│     Ziel 60 g/h         │  ← Rate label (dim)
│      Hinter 12g         │  ← Deficit or "Ahead Xg" / "Im Ziel"
│                         │
│      45m | 2x           │  ← Elapsed time | intake count
│   12g / 25g / 50g       │  ← Tap zone hint
└─────────────────────────┘
```

Status row colors: green = on track · yellow = due soon (< 3 min) · red = due now · yellow = paused

---

## Touch Controls

| Tap zone | Normal state | Reminder active |
|----------|-------------|-----------------|
| Top 25% | Half dose (≥5g) | Snooze |
| Middle 50% | Default dose | Default dose |
| Bottom 25% | Double dose | Double dose |

---

## Reminder Modes

**Auto (deficit-based)** — calculates `elapsed_hours × target_g/h`. When the deficit ≥ gel size, the reminder fires. After eating, the clock resets.

**Fixed interval** — first reminder after start delay + one full interval; subsequent reminders every N minutes from last intake.

**Calorie Auto** — uses the watch's calorie burn data. Target carbs = `calories_burned × carb_fraction% / 4 kcal/g`. Adapts in real time to your actual effort.

---

## Troubleshooting

**Settings not applying on watch?**
Open the Settings Widget, change a value and change it back — this forces a write to the shared property store. Both apps use the same app ID and share storage.

**Reminder not vibrating?**
Check that vibration is enabled in the watch system settings (not on silent).

**Session reset unexpectedly?**
The data field auto-detects a new activity when the timer resets to 0. Starting a new activity always begins a fresh session.

---

## Version History

### v1.0.0
- Initial release: Auto, Fixed, and Calorie Auto reminder modes
- Session persistence, intake log (rolling 50 entries)
- Vibration + backlight alerts with snooze
- On-watch settings widget (EN + DE)
- Sport presets
