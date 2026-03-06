# FuelPlanner Notes

This file tracks current project status and next tasks.

## Current Baseline (v0.1.0)
- App type: Data Field
- Min API: 3.0.0
- Permission: `FitContributor`
- Language support: English and German
- Device targets: 97 profiles listed in `manifest.xml`

## Current Runtime Behavior
- Touch devices:
  - Top tap zone: half dose or snooze (if reminder due)
  - Middle tap zone: default dose
  - Bottom tap zone: double dose
- Non-touch devices:
  - Auto-Flow books default dose automatically when reminder is due
  - No explicit key-based intake/undo handler in `FuelPlannerFieldDelegate`
- FIT contribution fields:
  - Deficit and consumed carbs are recorded and visible in Garmin Connect
  - FIT updates are throttled in `FuelModel.updateFitFields()`

## Completed for Beta 0.1
- Auto / Fixed / Calorie Auto reminder logic
- Smart-Pause and timer-backtrack resilience
- Session persistence and intake log storage
- Store-ready docs (`garmin.md`) in EN/DE

## Next Ideas
- Optional explicit button bindings for manual intake/undo on non-touch devices
- Additional smoke tests on low-memory devices before wider rollout
