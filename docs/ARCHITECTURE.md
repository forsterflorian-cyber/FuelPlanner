# Architecture

## App Structure

- `source/FuelPlannerApp.mc` wires app lifecycle, view creation, settings access,
  and FIT field registration.
- `source/model/FuelModel.mc` owns session detection, carb calculations,
  reminder timing, auto-intake handling, recovery state, and FIT updates.
- `source/model/ReminderManager.mc` contains reminder gating plus vibration and
  backlight delivery.
- `source/model/StorageManager.mc` separates persisted settings from live
  session state.
- `source/FuelPlannerFieldView.mc` is the default full-tier data field view.
- `source/FuelPlannerFieldViewInstinct3.mc` is the compact lite-tier view used
  for constrained devices.
- `source/FuelPlannerFieldDelegate.mc`, `source/FuelPlannerMenuView.mc`, and
  `source/FuelPlannerMenuDelegate.mc` are full-tier only.

## FuelModel Lifecycle

1. `FuelPlannerApp.onStart()` creates storage, model, and reminder instances,
   then calls `FuelModel.loadSession()`.
2. `FuelModel.compute()` starts or resumes a session when timer data becomes
   available. It prefers `info.startTime` and falls back to timer-reset
   detection when start time is missing.
3. Every tick updates pause state, calorie data, target carbs, deficit, next
   due time, reminder state, auto-intake, and FIT fields.
4. `onTimerLap()` snapshots the live session via `saveSession()`.
5. `onStop()` always saves the session; full-tier builds also flush FIT session
   summary values.
6. When the timer becomes `STOPPED` or `OFF`, the model marks the session as
   finished and clears recoverable storage so completed activities are not
   restored.

## Reminder System

- `ReminderManager.shouldVibrate()` suppresses reminders while paused, before
  the configured start delay, and during the snooze window.
- Auto and Calorie Auto are deficit-driven; Fixed Interval is driven by time
  since the last intake.
- Full-tier builds support tap-to-log plus top-band snooze when a reminder is
  due.
- Lite-tier builds keep the interaction model simpler and rely on Auto-Flow for
  button-first devices instead of adding device-specific code paths.

## Persistence Rules

- User settings are stored in `Application.Properties` and clamped on read and
  write.
- Live session state is stored in `Application.Storage`, including session id,
  start timestamp, consumed carbs, last intake/reminder timestamps, intake
  count, elapsed active seconds, and pause offsets.
- Intake booking, snooze actions, lap snapshots, and stop events persist
  through `saveSession()`.
- Reloaded sessions recompute transient display state rather than persisting it
  directly.
- Finished sessions are removed from recoverable storage and are not restored on
  the next launch.

## Device Tiering Strategy

- `fr955` remains the reference device for development and testing.
- The full tier is the default path. It includes the standard view, touch
  delegate, on-watch settings menu, and FIT contribution fields.
- The lite tier is assigned only in `monkey.jungle` through
  `excludeAnnotations`; there is no runtime device branching.
- Lite devices intentionally degrade the UI by using the compact rendering path
  and removing full-tier-only interaction surfaces:
  - `fr245`, `fr245m`
  - `fenix6`, `fenix6s`
  - `vivoactive4`, `vivoactive4s`
  - `instinct2`, `instinct2s`, `instinct2x`
  - `instinctcrossover`
  - `instinct3solar45mm`
- Family expansion should only add devices that fit one of these two existing
  tiers without further code changes.
