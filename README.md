# FuelPlanner

FuelPlanner is a Garmin Connect IQ data field for carbohydrate fueling during endurance activities.
It tracks intake against a target, shows the current deficit, and reminds the athlete when the next intake is due.

## Features

- Carbohydrate target in `g/h`
- Configurable dose size
- Configurable start delay and snooze
- Reminder modes: `Auto`, `Fixed`, `Calorie Auto`
- Pause-aware session handling, including Garmin `STOPPED` as a resumable pause
- Frozen post-activity recovery snapshot after timer reset or terminal `OFF`
- Touch logging and undo on touch-capable devices
- Automatic estimate flow on non-touch devices
- FIT record and session fields written to the FIT file for compatible analysis tools

## Reminder Modes

- `Auto`: uses the configured carb target and live session state
- `Fixed`: uses a fixed interval from the last logged intake
- `Calorie Auto`: derives the target from device calorie data and a configurable carb fraction

## Supported Devices

FuelPlanner currently ships as a single package for these devices:

- Forerunner: `fr255`, `fr255m`, `fr255s`, `fr255sm`, `fr265`, `fr265s`, `fr57042mm`, `fr57047mm`, `fr745`, `fr945`, `fr945lte`, `fr955`, `fr965`, `fr970`
- Fenix / Epix: `epix2`, `epix2pro42mm`, `epix2pro47mm`, `epix2pro51mm`, `fenix7`, `fenix7pro`, `fenix7pronowifi`, `fenix7s`, `fenix7spro`, `fenix7x`, `fenix7xpro`, `fenix7xpronowifi`, `fenix843mm`, `fenix847mm`, `fenix8pro47mm`, `fenix8solar47mm`, `fenix8solar51mm`
- Edge: `edge1030`, `edge1030bontrager`, `edge1030plus`, `edge1040`, `edge1050`, `edge520plus`, `edge530`, `edge540`, `edge550`, `edge820`, `edge830`, `edge840`, `edge850`, `edgeexplore`, `edgeexplore2`, `edgemtb`
- Instinct: `instinct3amoled45mm`, `instinct3amoled50mm`
- Venu: `venu3`, `venu3s`

Edge 1000 and Edge 520 are below the app's Connect IQ 3.0 minimum. Edge 130 and Edge 130 Plus are not listed because the current data field package exceeds their 32 KB data field memory limit.

Edge 820 and Edge Explore are touch-capable and use the same manual intake, snooze, and undo flow as other touch products. Connect IQ 3.2 is required only for Garmin's native full-screen `DataFieldAlert`; FuelPlanner's in-field reminder overlay remains available when that native control is unavailable.

## Installation

1. Add FuelPlanner as a Connect IQ data field to a supported activity.
2. Start an activity such as Run, Bike, or Hike.
3. On touch-capable devices, use the center zone to log intake and the lower band to undo when no reminder is active.
4. On non-touch devices, FuelPlanner applies the configured dose automatically when a reminder becomes due.
5. During an active reminder or alert overlay, touch routing is modal: the visible top snooze band snoozes, and any valid tap below it records the intake. Undo becomes available again after the reminder is dismissed.

## Lifecycle and Recovery

- `PAUSED` and Garmin `STOPPED` timer states pause the FuelPlanner session. The session remains persisted and resumes with the activity timer.
- Timer `RESET` and terminal `OFF` end the FuelPlanner session. A normal stop does not finalize it.
- Finalization attempts a verified final active aggregate, then persists a verified recovery snapshot before active-session cleanup. A confirmed recovery snapshot takes precedence if interrupted cleanup leaves both records behind.
- If recovery persistence fails after the final active aggregate commits, that `FINISHED` aggregate remains for retry on the next load. If the final active write also fails, storage retains the latest previously verified coherent active aggregate, which may predate finalization.

## Settings

- `Carbs Target`: target carbohydrate intake rate in `g/h`
- `Dose Size`: logged grams per intake
- `Reminder Mode`: `Auto`, `Fixed`, or `Calorie Auto`
- `Carb Fraction`: carbohydrate share used in `Calorie Auto`
- `Fixed Interval`: reminder interval used in `Fixed`
- `Start Delay`: delay before reminders begin
- `Snooze Time`: reminder snooze duration
- `Native Full-Screen Alerts`: available only on Connect IQ 3.2+ devices that support Garmin `DataFieldAlert`

## FIT Data

FuelPlanner writes live record fields and final session fields to the FIT file. Garmin Connect may show the live record fields as charts, but Connect does not consistently surface custom session fields in the activity summary on all devices/accounts. The session fields are still written to the FIT file and can be read by compatible FIT tools.

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

- Current version: `1.0.0`
- Store package: `artifacts/FuelPlanner-DataField.iq`
- Test bundle example: `artifacts/FuelPlannerTests-fr955.prg`
- Accepted waiver: launcher icon scaling warnings on `35px`, `36px`, `54px`, `56px`, `60px`, `65px`, `68px`, and `70px` targets

Release validation is reported in three separate categories:

- **Compile**: compiler/package results for the declared product matrix
- **Simulator**: automated tests and interactive layout/behavior checks, with the simulated products named
- **Physical device**: explicitly named hardware checks; compile or simulator success is never presented as on-device validation

The repository does not currently claim physical-device validation for version `1.0.0`. See `docs/CHANGELOG.md`, `docs/RELEASE_NOTES_1.0.0.md`, and `docs/RELEASE_TEMPLATE.md` for release details and the validation checklist.

## License

MIT License. See `LICENSE`.
