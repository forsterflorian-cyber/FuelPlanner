# Changelog

All notable public-facing changes to FuelPlanner are recorded here.

## [1.0.0] - 2026-07-19

[DE]
- Unterstuetzung fuer kompatible Edge Radcomputer ergaenzt.
- Kompakte Anzeige fuer kleine rechteckige Datenfeld-Slots hinzugefuegt.
- STOPPED wird als fortsetzbare Pause behandelt; nur RESET oder der terminale OFF-Zustand beendet die Session.
- Timing der Erinnerungen rund um Startverzoegerung, Snooze und Pausen korrigiert.
- Pause/Fortsetzen bei Timer-Quellenwechseln, Timer-Stalls und Reloads robuster gemacht.
- Aktive Sessions und Recovery-Daten als versionierte Aggregate gespeichert, damit Teil-Schreibvorgaenge keine gemischten Sessions erzeugen.
- Recovery-Uebergabe gegen unterbrochenes Aufraeumen abgesichert; bestaetigte Recovery-Daten haben Vorrang vor uebrig gebliebenen Abschlussdaten.
- Touch-Erkennung waehrend aktiver Sessions aktualisiert; Edge 820 und Edge Explore behalten die manuelle Touch-Bedienung, waehrend native Vollbild-Alarme nur auf kompatiblen Connect IQ 3.2+ Geraeten erscheinen.

[EN]
- Added support for compatible Edge cycling computers.
- Added a compact view for small rectangular data field slots.
- Treats STOPPED as a resumable pause; only RESET or terminal OFF ends a session.
- Fixed reminder timing around start delay, snooze, and pause handling.
- Improved pause/resume robustness across timer-source changes, timer stalls, and reloads.
- Stores active sessions and recovery data as versioned aggregates so partial writes cannot create mixed session generations.
- Makes recovery handoff resilient to interrupted cleanup; confirmed recovery data takes precedence over a lingering finished record.
- Refreshes touch detection during active sessions; Edge 820 and Edge Explore retain manual touch input, while native full-screen alerts appear only on compatible Connect IQ 3.2+ devices.

## [0.1.0] - 2026-03-06

[DE]
- Erste oeffentliche Beta von FuelPlanner als Connect IQ data field.
- Auto, Fixed Interval und Calorie Auto fuer Fuelettermin-Erinnerungen hinzugefuegt.
- Einfache Intake-Logs, Auto-Flow fuer Button-Geraete und FIT-Felder fuer Defizit und Verbrauch bereitgestellt.
- Einstellungen ueber das On-Watch-Menue und Garmin Connect Properties angebunden.

[EN]
- Initial public beta release of FuelPlanner as a Connect IQ data field.
- Added Auto, Fixed Interval, and Calorie Auto fueling reminders.
- Shipped simple intake logging, Auto-Flow for button devices, and FIT fields for deficit and intake data.
- Connected on-watch settings with Garmin Connect properties.
