# Changelog - FuelPlanner


## [0.5.0-alpha] - 2026-03-09

[DEUTSCH]
- Vollstaendige Annotation-Symmetrie (:full / :lite) implementiert.
- Trennung von High-Memory (Touch) und Low-Memory (Button) Pfaden.
- Fehlerhafte Symbol-Referenzen im Lite-Tier (Delegate/Menu) behoben.
- Release-Build fuer Instinct 3 unter 24KB stabilisiert.
- 14/14 Unit- und Stress-Tests erfolgreich abgeschlossen.

[ENGLISH]
- Implemented full annotation symmetry (:full / :lite).
- Decoupled High-Memory (Touch) and Low-Memory (Button) code paths.
- Resolved symbol leaks in Lite-Tier (Delegate/Menu references).
- Stabilized Instinct 3 Release-Build under 24KB.
- Successfully completed 14/14 Unit and Stress tests.

## [0.4.0-alpha] - 2026-03-09

[ENGLISH]
- Completed Memory Test Suite (Zero-leak verification for menu/intake).
- Optimized legacy hardware support (32KB peak-load check).
- Finalized 14/14 Unit-Test suite (Logic, Chaos, Memory).

[DEUTSCH]
- Memory-Test-Suite erfolgreich (Verifikation von Null-Leaks).
- Optimierung fuer Legacy-Hardware (32KB Peak-Load Check).
- Abschluss der 14/14 Unit-Test-Suite (Logik, Chaos, Memory).


## [0.3.0-alpha] - 2026-03-09

[DEUTSCH]
- Chaos-Stress-Tests erfolgreich abgeschlossen (11/11 Tests PASS).
- Absicherung gegen Surplus-Buchungen und fliegenden Modus-Wechsel.
- Verifikation der Crash-Recovery (Session-Wiederherstellung).
- UI-Logik (Gauge-Alerts) fuer Tests entkoppelt.

[ENGLISH]
- Completed Chaos Stress Tests (11/11 tests passed).
- Validated surplus handling and mid-activity mode switching.
- Verified crash recovery and session restoration logic.
- Decoupled UI logic (gauge alerts) for automated testing.