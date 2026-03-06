# Garmin Connect IQ Store - Copy and Descriptions

Field limit: 4000 characters per description field.
Character counts are noted for each block.

---

## DATA FIELD - English

### Short Description (max 255 chars)
```text
Real-time carbohydrate intake tracker for endurance athletes. Reminds you when to fuel, logs your gels, and shows your deficit vs. target directly on your watch during any activity.
```

### Full Description (~2300 chars)
```text
FuelPlanner - Carbohydrate Intake Tracker

Never bonk again. FuelPlanner is a data field that tracks your carbohydrate intake during running, cycling, or hiking and vibrates when it is time to eat.

Version 0.1 is the Initial Beta release focused on robust race-day fueling logic and FIT-based post-activity analysis.

HOW IT WORKS
FuelPlanner watches your active elapsed time and calculates how many grams of carbs you should have consumed based on your target rate. When the deficit reaches your gel size, it reminds you to fuel. Paused time is automatically excluded.

THREE REMINDER MODES
- Auto (default): Triggers when your carb deficit reaches your configured gel size. Adapts dynamically if you eat more or less than planned.
- Fixed Interval: Reminds you every N minutes from the last intake. Simple and predictable.
- Calorie Auto: Uses the watch's calorie or energy data. Target carbs = calories burned x your carb fraction. No fixed g/h needed and it adapts to your actual effort.

LOGGING INTAKE
- Tap center: Log your default gel or dose
- Tap top 25%: Snooze reminder, or log a half dose
- Tap bottom 25%: Log a double dose
- On non-touch devices, Auto-Flow handles intake booking automatically when a reminder is due.

WHAT YOU SEE
- Countdown to next recommended intake (color-coded: green/yellow/red)
- Consumed vs. target carbs in grams
- Deficit or surplus indicator
- Active elapsed time and intake count
- Edge deficit gauge (green/red) for quick status at a glance

SMART FEATURES
- Smart-Pause: Paused activity time is excluded from deficit math, so coffee stops and traffic lights do not corrupt your fueling model.
- Session persistence: Survives watch restart mid-activity
- Vibration + backlight flash alert
- Snooze to delay a reminder
- Settings hot-reload: updates apply during activity without restarting
- Auto-Flow for non-touch devices (e.g. fenix 6/7, Forerunner 255/955): when a reminder is due, the default dose can be booked automatically to maintain fueling rhythm under load.
- Real-Time FIT Analysis: custom FIT fields for deficit and consumed carbs are recorded and can be reviewed directly in Garmin Connect after the workout.

SETTINGS (on watch or in Garmin Connect)
- Carbs Target: 20-120 g/h (default 60)
- Gel Size: 5-100 g (default 25)
- Reminder Mode: Auto / Fixed Interval / Calorie Auto
- Fixed Interval: 5-60 min (default 20)
- Start Delay: 0-60 min (default 15)
- Snooze Time: 1-15 min (default 5)
- Carb % of kcal: 40-80 % (default 60, used in Calorie Auto mode)

Requires Connect IQ 3.0.0+.
```

### Changelog
```text
v0.1.0 - Initial Beta
- Auto-Flow for non-touch devices
- Real-Time FIT deficit/consumed recording for Garmin Connect analysis
- Smart-Pause compensation for stable deficit calculations
- Input validation and hardened session/timer resilience
- Integer carb math and throttled FIT updates for battery efficiency
```

---

## DATA FIELD - Deutsch

### Kurzbeschreibung (max 255 Zeichen)
```text
Echtzeit-Kohlenhydrat-Tracker fuer Ausdauersport. Erinnert dich ans Essen, protokolliert Gels und zeigt dein Defizit vs. Ziel direkt auf der Uhr waehrend jeder Aktivitaet.
```

### Vollstandige Beschreibung (~2400 Zeichen)
```text
FuelPlanner - Kohlenhydrat-Tracking fuer Ausdauersportler

Nie wieder "Hungerast". FuelPlanner ist ein Datenfeld, das deine Kohlenhydratzufuhr waehrend Laufen, Radfahren oder Wandern verfolgt und vibriert, wenn es Zeit zum Essen ist.

Version 0.1 ist der Initial-Beta-Release mit Fokus auf robuster Race-Day-Logik und FIT-basierter Nachanalyse.

WIE ES FUNKTIONIERT
FuelPlanner berechnet anhand deiner aktiven Zeit, wie viele Gramm Kohlenhydrate du bis jetzt haettest zufuehren sollen. Wenn das Defizit deine Gel-Groesse erreicht, wirst du erinnert. Pausenzeiten werden automatisch herausgerechnet.

DREI ERINNERUNGS-MODI
- Auto (Standard): Erinnert, wenn das KH-Defizit deine Gel-Groesse erreicht. Passt sich dynamisch an, egal ob du mehr oder weniger gegessen hast.
- Festes Intervall: Erinnert alle N Minuten seit der letzten Zufuhr. Einfach und vorhersehbar.
- Kalorien-Auto: Nutzt Kalorien- oder Energie-Daten der Uhr. Ziel-KH = Kalorien x KH-Anteil. Kein festes g/h-Ziel noetig und passt sich deiner tatsaechlichen Belastung an.

ZUFUHR ERFASSEN
- Mitte antippen: Standard-Gel oder Portion erfassen
- Oben (25%): Erinnerung schlummern oder halbe Portion erfassen
- Unten (25%): Doppelte Portion erfassen
- Auf Nicht-Touch-Geraeten uebernimmt Auto-Flow die Buchung automatisch, sobald eine Erinnerung faellig ist.

WAS DU SIEHST
- Countdown bis zur naechsten empfohlenen Zufuhr (farbig: gruen/gelb/rot)
- Konsumierte vs. Ziel-Kohlenhydrate in Gramm
- Defizit- oder Ueberschuss-Anzeige
- Aktive Zeit und Anzahl der Einnahmen
- Edge-Defizit-Anzeige (gruen/rot) fuer schnellen Status auf einen Blick

FUNKTIONEN
- Smart-Pause: Pausenzeiten werden sauber aus der Defizit-Berechnung ausgeschlossen, damit Kaffee-Stopps oder Ampeln die Fueling-Logik nicht verfaelschen.
- Sitzungs-Persistenz: Ueberlebt Neustart der Uhr mitten in der Aktivitaet
- Vibrations- und Hintergrundlicht-Alarm
- Schlummer-Funktion fuer Erinnerungen
- Settings-Hot-Reload: Aenderungen greifen waehrend der Aktivitaet ohne Neustart
- Auto-Flow fuer Nicht-Touch-Geraete (z.B. fenix 6/7, Forerunner 255/955): Wenn eine Erinnerung faellig ist, kann die Standard-Portion automatisch gebucht werden, damit der Fueling-Rhythmus unter Belastung stabil bleibt.
- Echtzeit-FIT-Analyse: Eigene FIT-Felder fuer Defizit und konsumierte KH werden aufgezeichnet und sind direkt in Garmin Connect auswertbar.

EINSTELLUNGEN (auf der Uhr oder in Garmin Connect)
- KH-Ziel: 20-120 g/h (Standard 60)
- Gel-Groesse: 5-100 g (Standard 25)
- Erinnerungs-Modus: Auto / Festes Intervall / Kalorien-Auto
- Festes Intervall: 5-60 min (Standard 20)
- Startverzoegerung: 0-60 min (Standard 15)
- Schlummer-Zeit: 1-15 min (Standard 5)
- KH-Anteil: 40-80 % (Standard 60, fuer Kalorien-Auto-Modus)

Erfordert Connect IQ 3.0.0+.
```

### Aenderungsprotokoll
```text
v0.1.0 - Initial Beta
- Auto-Flow fuer Nicht-Touch-Geraete
- Echtzeit-FIT-Aufzeichnung fuer Defizit/Konsum und Analyse in Garmin Connect
- Smart-Pause Kompensation fuer stabile Defizit-Berechnung
- Eingabevalidierung und robustere Session-/Timer-Resilienz
- Ganzzahl-KH-Mathematik und FIT-Throttling fuer Akkueffizienz
```

---
