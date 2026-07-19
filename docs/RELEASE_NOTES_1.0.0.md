# FuelPlanner 1.0.0 Release Notes

Release date: 2026-07-19

## Deutsch

- Garmin `STOPPED` pausiert FuelPlanner und kann fortgesetzt werden. Erst Timer-`RESET` oder der terminale `OFF`-Zustand schliesst die Session ab.
- Wechsel zwischen verfuegbaren Timer-Quellen, Pausen und Reloads behalten die aktive Zeit konsistent.
- Versionierte Aggregate sichern aktive Sessions und das eingefrorene Recovery-Ergebnis gegen Teil-Schreibvorgaenge und unterbrochenes Aufraeumen ab.
- Touch-Aktionen richten sich nach der Touch-Faehigkeit des Geraets. Edge 820 und Edge Explore behalten die manuelle Bedienung; nur der native Vollbild-Alarm benoetigt Connect IQ 3.2+.
- Kompakte und vollflaechige Layouts unterstuetzen die deklarierte Uhren- und Edge-Produktmatrix.

## English

- Garmin `STOPPED` pauses FuelPlanner and remains resumable. Only timer `RESET` or terminal `OFF` finalizes the session.
- Changes between available timer sources, pauses, and reloads keep active elapsed time consistent.
- Versioned aggregates protect active sessions and the frozen recovery result from partial writes and interrupted cleanup.
- Touch actions follow the device's touch capability. Edge 820 and Edge Explore retain manual interaction; only the native full-screen alert requires Connect IQ 3.2+.
- Compact and full layouts support the declared watch and Edge product matrix.

## Validation Scope

Compile, simulator, and physical-device results must be reported separately in the release handoff. These release notes describe shipped behavior and do not by themselves claim validation on physical hardware.

Version `1.0.0` currently has no physical-device validation claim recorded in this repository. Touch delivery, haptics, native alerts, FIT output, physical heap behavior, and real activity lifecycle ordering still require explicitly documented hardware checks.
