# FuelPlanner

FuelPlanner is a Garmin Connect IQ Data Field for real-time carbohydrate 
intake tracking and race-day fueling.

## Core Features
- 3 Reminder Modes: Auto (Deficit), Fixed Interval, and Calorie Auto.
- Smart-Pause: Excludes paused time from fueling math.
- Auto-Flow: Automatic intake booking for non-touch devices.
- FIT-Analysis: Records deficit and consumption data for Garmin Connect.
- Relative Design: Dynamic scaling for all Garmin display types.

## Support
https://buymeacoffee.com/forsterf

## Build & Installation
Run the build script:
.\build.ps1

Manual build:
monkeyc -f monkey.jungle -o bin/FuelPlanner.prg -y dev_key.der -d fr955 -w