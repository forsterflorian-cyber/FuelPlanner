# FuelPlanner

FuelPlanner is a Garmin Connect IQ data field for carbohydrate fueling during endurance activities.
It tracks intake against a target, shows the current deficit, and reminds the athlete when the next intake is due.

## Features

- Carbohydrate target in `g/h`
- Configurable dose size
- Configurable start delay and snooze
- Reminder modes: `Auto`, `Fixed`, `Calorie Auto`
- Pause-aware session handling
- Frozen post-activity recovery snapshot after stop/restart
- Touch and button support on the remaining supported devices
- FIT summary fields for later review

## Reminder Modes

- `Auto`: uses the configured carb target and live session state
- `Fixed`: uses a fixed interval from the last logged intake
- `Calorie Auto`: derives the target from watch calorie data and a configurable carb fraction

## Supported Devices

FuelPlanner currently ships as a single package for these devices:

- Forerunner: `fr255`, `fr255m`, `fr255s`, `fr255sm`, `fr265`, `fr265s`, `fr57042mm`, `fr57047mm`, `fr745`, `fr945`, `fr945lte`, `fr955`, `fr965`, `fr970`
- Fenix / Epix: `epix2`, `epix2pro42mm`, `epix2pro47mm`, `epix2pro51mm`, `fenix7`, `fenix7pro`, `fenix7pronowifi`, `fenix7s`, `fenix7spro`, `fenix7x`, `fenix7xpro`, `fenix7xpronowifi`, `fenix843mm`, `fenix847mm`, `fenix8pro47mm`, `fenix8solar47mm`, `fenix8solar51mm`
- Instinct: `instinct3amoled45mm`, `instinct3amoled50mm`
- Venu: `venu3`, `venu3s`

## Installation

1. Add FuelPlanner as a Connect IQ data field to a supported activity.
2. Start an activity such as Run, Bike, or Hike.
3. Use the center touch zone or button flow to log intake.
4. Use the top zone or menu action to snooze reminders when needed.

## Settings

- `Carbs Target`: target carbohydrate intake rate in `g/h`
- `Dose Size`: logged grams per intake
- `Reminder Mode`: `Auto`, `Fixed`, or `Calorie Auto`
- `Carb Fraction`: carbohydrate share used in `Calorie Auto`
- `Fixed Interval`: reminder interval used in `Fixed`
- `Start Delay`: delay before reminders begin
- `Snooze Time`: reminder snooze duration
- `Native Full-Screen Alerts`: available only on devices that support Garmin `DataFieldAlert`

## Build

### PowerShell build

```powershell
.\build.ps1
.\build.ps1 -Test -Device fr955
.\build.ps1 -Clean
```

Build outputs are written to `artifacts/` by default.

### Direct Monkey C build

```bash
monkeyc -f monkey.jungle -o artifacts/FuelPlanner.prg -y <developer_key>
```

### Simulator

```bash
monkeydo artifacts/FuelPlanner.prg fr955
```

## Project Structure

```text
FuelPlanner/
├── source/
│   ├── FuelPlannerApp.mc
│   ├── FuelPlannerFieldView.mc
│   ├── FuelPlannerFieldDelegate.mc
│   ├── FuelPlannerMenuView.mc
│   ├── FuelPlannerMenuDelegate.mc
│   └── model/
│       ├── FuelModel.mc
│       ├── StorageManager.mc
│       └── ReminderManager.mc
├── tests/
├── docs/
├── resources/
├── manifest.xml
├── monkey.jungle
└── build.ps1
```

## Release

- Store package: `artifacts/FuelPlanner-DataField.iq`
- Test bundle example: `artifacts/FuelPlannerTests-fr955.prg`
- Accepted waiver: launcher icon scaling warnings on `60px`, `65px`, and `70px` targets

## License

MIT License. See `LICENSE`.
