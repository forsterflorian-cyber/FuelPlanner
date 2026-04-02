FuelPlanner
FuelPlanner is a Garmin Connect IQ data field for carbohydrate fueling during endurance activities.
It helps you keep track of intake targets during a session, shows the current intake gap, and reminds you when the next intake is due.
What it does
tracks carbohydrate intake during an activity
supports reminder-based fueling on the watch
shows target intake and current deficit
supports touch and button-based device flows
writes fueling-related FIT data for later review
Reminder Modes
Auto  
Uses a configured carb target and the current session state to determine when intake is due.
Fixed  
Uses a fixed interval from the last logged intake.
Calorie Auto  
Derives the intake target from watch calorie data and a configurable carb fraction.
Core Features
carbohydrate target in g/h
configurable dose size
configurable start delay
configurable snooze
pause/resume aware session handling
session recovery after interruption
support for standard presets such as Run, Bike, and Hike
Supported Devices
FuelPlanner currently targets these Garmin device families:
Forerunner  
255, 255 Music, 255S, 255S Music, 265, 265S, 745, 945, 945 LTE, 955, 965
Fenix  
6 Pro, 6S, 6S Pro, 6X Pro, 7, 7 Pro, 7S, 7S Pro, 7X, 7X Pro
The Fenix 6 family is shipped through the separate memory-optimized store package.
Epix  
2, 2 Pro (42mm, 47mm, 51mm)
Instinct  
Instinct 3 AMOLED (45mm, 50mm), Instinct 3 Solar (45mm)
Venu  
3, 3S
Installation
Requirements
Garmin Connect IQ SDK
Monkey C extension for Visual Studio Code
Garmin simulator or supported device
developer key for local builds
Build
```bash
monkeyc -f monkey.jungle -o FuelPlanner.prg -y <developer_key>
```
Run in simulator
```bash
monkeydo FuelPlanner.prg <device>
```
Build with PowerShell script
```powershell
.\build.ps1
```
Usage
Add as a data field
Open the activity settings on your Garmin device
Select a supported activity such as Run or Bike
Add a new data screen or field
Choose the Connect IQ data field
Select FuelPlanner
Main settings
Carbs Target: target carbohydrate intake rate in g/h
Dose Size: logged amount per intake
Reminder Mode: Auto, Fixed, or Calorie Auto
Carb Fraction: carb share used in Calorie Auto mode
Fixed Interval: reminder interval in Fixed mode
Start Delay: delay before reminders begin
Snooze Time: reminder snooze duration
Presets
Run
Bike
Hike
Project Structure
```text
FuelPlanner/
├── source/
│   ├── FuelPlannerApp.mc
│   ├── FuelPlannerFieldView.mc
│   ├── FuelPlannerFieldViewInstinct3.mc
│   ├── FuelPlannerFieldDelegate.mc
│   ├── FuelPlannerMenuView.mc
│   ├── FuelPlannerMenuDelegate.mc
│   └── model/
│       ├── FuelModel.mc
│       ├── StorageManager.mc
│       └── ReminderManager.mc
├── tests/
├── resources/
├── manifest.xml
├── monkey.jungle
└── build.ps1
```
Development
Common commands
```powershell
.\build.ps1
.\build.ps1 -Test -Device fr955
.\build.ps1 -Clean
```
Release packages
```text
FuelPlanner-DataField.iq        -> standard package for non-Fenix 6 targets
FuelPlanner-DataField-Fenix6.iq -> memory-optimized package for the Fenix 6 family
```
Test build
```bash
monkeyc -f monkey.tests.jungle -o FuelPlannerTests-fr955.prg -d fr955 -t -y <developer_key>
```
Status
FuelPlanner is in active development and focused on robustness, session handling, and practical usability during real training.
License
MIT License. See `LICENSE`.
