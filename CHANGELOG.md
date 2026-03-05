# Changelog

All notable changes to FuelPlanner will be documented in this file.

## [Unreleased] - 2026-03-05

### Added
- Started changelog tracking.

### Changed
- Hardened `build.ps1` Java validation:
  - requires Java 11+
  - checks for `java.desktop` module
  - supports explicit `-JavaPath`
- Improved button-mode long-press handling in `FuelPlannerFieldDelegate` to handle different key event orders.
- Updated `FuelModel` naming (`_maxSnoozMin` -> `_maxSnoozeMin`) and reduced repetitive `startTime` warning logging.
- Strengthened `ReminderManager` device capability checks and fallback handling.
- Updated input behavior so long `DOWN` logging works regardless of touch hardware capability checks.
- Reworked late-`startTime` reconciliation to adopt a real `startTime` for fallback-started sessions without wiping intake data.
- Added persisted `start_ts_ok` session metadata to distinguish fallback vs confirmed session starts.
- Added long-LAP undo behavior:
  - short `LAP` remains the native lap action
  - long `LAP` (~1s) undoes the last intake entry
  - intake totals and last-intake timestamp are rebuilt from the persisted intake log after undo
  - undo now recalculates deficit/reminder timing immediately instead of waiting for the next compute tick
  - long-LAP with no available undo emits snooze-style haptic feedback
  - small-layout button hint now uses a shorter LAP undo label to reduce text clipping risk
- Refined field layout to reduce bottom-row clipping:
  - extracted row Y positions and bottom safety area to named constants
  - hint row now uses safe-bottom clamping based on display height and text height
  - bottom hint inset now adapts by input mode (touch vs button) and square/round-like display geometry
  - switched to top-to-bottom flow layout with explicit line offsets and overflow-based row fallback
  - added round-screen hint-width safety calculation so bottom hint text is kept away from circle-edge clipping
  - tightened overflow fallback to reduce row clipping by shrinking gaps before removing hint text
  - adjusted number-unit rendering with relative spacing and vertical nudge so the `g` aligns better with the number row
  - expanded compact button-hint threshold (`<=300px`) to prefer shorter LAP hint text on 260/280-class screens

### Fixed
- Long DOWN hold can now reliably record default intake in more simulator/device key-event sequences.
- Avoided repeated per-tick logging when `Activity.Info.startTime` is unavailable.
- Fixed risk of unintended session reset when `Activity.Info.startTime` becomes available after a fallback session start.

### Known Issues
- Build/export remains blocked on environments with Java 8 only or reduced Java runtimes missing `java.desktop`.
