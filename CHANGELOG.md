# Changelog

All notable changes to FuelPlanner are documented in this file.

## [0.1.0] - 2026-03-06

### Added
- Initial public beta release (`manifest.xml` version `0.1.0`).
- Auto / Fixed / Calorie Auto reminder modes.
- Auto-Flow for non-touch devices (automatic default-dose booking when reminder is due).
- FIT contribution fields for carb deficit and consumed carbs (`resources/fitfields.xml`).
- On-watch settings menu with sport presets and Garmin Connect settings sync.

### Changed
- Fuel calculations run in integer tenths-of-grams for deterministic low-overhead math.
- FIT `setData()` updates are throttled to reduce CPU and battery load.
- Session/timer handling hardened with pause compensation and timer-backtrack resilience.

### Fixed
- Defensive type/null checks across storage and activity data access paths.
- Resource string loading hardened with fallbacks to avoid null text rendering issues.
