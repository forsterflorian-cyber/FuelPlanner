# FuelPlanner

FuelPlanner is a Garmin Connect IQ data field for on-device carbohydrate
guidance during endurance activities. The current codebase stays centered on
the existing architecture, with `fr955` as the reference device for ongoing
development and verification.

## Main Features
- Auto, Fixed Interval, and Calorie Auto reminder modes.
- Real-time carbohydrate target and deficit tracking from active elapsed time.
- Simple intake logging from the field, with Auto-Flow on lite/button-focused
  devices.
- Session persistence, pause handling, and recovery after reloads.
- FIT contribution fields on full-tier builds.

## Supported Device Families

| Family | Reference | Supported devices | Tier notes |
| --- | --- | --- | --- |
| Forerunner | `fr955` | `fr245`, `fr245m`, `fr255`, `fr255m`, `fr255s`, `fr255sm`, `fr265`, `fr265s`, `fr745`, `fr945`, `fr945lte`, `fr955`, `fr965` | `fr245` and `fr245m` use the lite tier |
| Fenix / Epix | `fenix7` | `epix2`, `epix2pro42mm`, `epix2pro47mm`, `epix2pro51mm`, `fenix6`, `fenix6pro`, `fenix6s`, `fenix6spro`, `fenix6xpro`, `fenix7`, `fenix7pro`, `fenix7pronowifi`, `fenix7s`, `fenix7spro`, `fenix7x`, `fenix7xpro`, `fenix7xpronowifi` | `fenix6` and `fenix6s` use the lite tier |
| Lifestyle | `venu3` | `venu3`, `venu3s`, `vivoactive4`, `vivoactive4s` | `vivoactive4` and `vivoactive4s` use the lite tier |
| Outdoor | `instinct2` | `instinct2`, `instinct2s`, `instinct2x`, `instinctcrossover`, `instinct3solar45mm`, `instinct3amoled45mm`, `instinct3amoled50mm` | `instinct2*`, `instinctcrossover`, and `instinct3solar45mm` use the lite tier |

`enduro2` is intentionally not listed yet because the local Connect IQ SDK
exposes `enduro` and `enduro3`, but not an `enduro2` product target.

## Build

Use the project script:

```powershell
.\build.ps1
```

Manual reference build for `fr955`:

```powershell
monkeyc -f monkey.jungle -o bin\FuelPlanner-fr955.prg -y developer_key -d fr955 -w
```

Store package build:

```powershell
monkeyc -f monkey.jungle -o bin\FuelPlanner-DataField.iq -e -y developer_key -w
```
