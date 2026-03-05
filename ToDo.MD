# FuelPlanner ToDo / Review Log

## Release Scope (as configured)
- Target app type: Data Field (`manifest.xml`)
- Target devices configured: 38
- Manifest product IDs:
  - `d2airx10`, `d2mach1`, `enduro3`, `epix2`, `epix2pro42mm`, `epix2pro47mm`, `epix2pro51mm`, `fenix6xpro`, `fenix7`, `fenix7pro`, `fenix7pronowifi`, `fenix7s`, `fenix7spro`, `fenix7x`, `fenix7xpro`, `fenix7xpronowifi`, `fenix8solar47mm`, `fenix8solar51mm`, `fr165`, `fr165m`, `fr255`, `fr255m`, `fr255s`, `fr255sm`, `fr265`, `fr265s`, `fr955`, `fr965`, `marq2`, `marq2aviator`, `venu2`, `venu2plus`, `venu2s`, `venu3`, `venu3s`, `venusq2`, `venusq2m`, `vivoactive5`

## Device Compatibility Check (local SDK metadata)
- [x] All 38 product IDs exist in local `ConnectIQ/Devices`.
- [x] All 38 advertise `datafield` support in `compiler.json`.
- [x] All 38 are compatible with `minApiLevel="3.3.0"` (lowest observed: API 3.4 on `fenix6xpro`).

## Build/Ship Status (2026-03-05)
- [ ] Store package build verified end-to-end in current environment.
- Blocker:
  - `build.ps1` currently fails with PATH Java 8:
    - `Java 11+ is required. Current java reports: java version "1.8.0_481"`
  - Alternate local Java 17 runtime tested is reduced/jlink and missing `java.desktop`.
- Effect:
  - Device targeting is configured and valid, but final `.iq` export cannot be produced on this machine until Java runtime is fixed.

## Full Review Findings + Fixes Applied
- [x] Fixed long-DOWN intake handling reliability for button devices.
  - Updated `FuelPlannerFieldDelegate` so hold detection works correctly across `onKeyPressed`, `onKey`, and `onKeyReleased` event ordering.
  - Confirmed intake action path includes `_model.recordDefaultIntake();` for confirmed long hold.
- [x] Fixed touch-lock fallback gap on touch-capable devices with buttons.
  - Removed `isTouchScreen` gating from DOWN-key handlers so long DOWN intake works whenever key events are available.
- [x] Reduced model log spam risk.
  - Updated `FuelModel.getActivityStartTimestamp()` to log missing `startTime` only once per run instead of potentially every tick.
- [x] Naming cleanup in model.
  - Renamed `_maxSnoozMin` to `_maxSnoozeMin` for clarity and consistency.
- [x] Hardened late `startTime` session reconciliation.
  - Added persisted start timestamp confirmation (`start_ts_ok`) to distinguish fallback-started sessions.
  - Fallback-started sessions now adopt late `startTime` without clearing intake data.
  - Confirmed sessions still roll over to a new session when a different `startTime` appears.
- [x] Reminder capability checks hardened.
  - `ReminderManager` now handles missing/partial device settings more defensively and avoids crashes from non-standard capability access failures.
- [x] Build script hardened.
  - `build.ps1` now validates Java version and required `java.desktop` module and surfaces actionable failure messages.

## Completed Earlier Project Tasks
- [x] On-watch Data Field settings
  - Configure via activity Data Field settings menu (`FuelPlannerApp.getSettingsView()`) or Garmin Connect.
  - Settings stored in `Application.Properties`.
- [x] Touch-disabled activity support
  - Data Field remains usable via hold DOWN in button mode.
- [x] Remove Settings Widget
  - Widget app removed; Data Field only.

## Next Actions
- [ ] Install/configure a full Java 17+ runtime (with `java.desktop`) and point `build.ps1` to it (`-JavaPath` or PATH/JAVA_HOME).
- [ ] Re-run build and generate `bin/FuelPlanner-DataField.iq`.
- [ ] Perform final smoke test on at least:
  - one touch device (`venu3`/`epix2`)
  - one button-only workflow device (`fenix6xpro`/`fr255`)
- [x] Optional UX feature: "Undo last intake" via long LAP hold (short LAP remains normal lap action).
  - Undo now recomputes deficit/reminder timing immediately.
  - Long LAP with no intake left to undo gives haptic feedback.
  - Button-mode hint uses a shorter LAP label on smaller layouts.
