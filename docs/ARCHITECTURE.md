# FuelPlaner Architecture

## Overview

FuelPlaner is a Garmin Connect IQ Data Field that provides intelligent carbohydrate fueling reminders during endurance activities. The architecture follows a clean separation of concerns with a Model-View-Delegate pattern adapted for the Connect IQ platform.

## System Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                    Garmin Connect IQ Runtime                 │
├─────────────────────────────────────────────────────────────┤
│                                                              │
│  ┌─────────────────┐    ┌──────────────────────────────────┐ │
│  │  FuelPlannerApp │    │  Activity.Info (Garmin API)      │ │
│  │  (Entry Point)  │◄───│  - timerTime                     │ │
│  │                 │    │  - elapsedTime                   │ │
│  └────────┬────────┘    │  - timerState                    │ │
│           │             │  - startTime                     │ │
│           │             │  - calories                      │ │
│           │             │  - energyExpenditure             │ │
│           │             └──────────────────────────────────┘ │
│           │                                                  │
│           ▼                                                  │
│  ┌─────────────────┐                                         │
│  │   FuelModel     │◄────────────────────────────────────┐  │
│  │  (Core Logic)   │                                     │  │
│  │                 │  ┌─────────────────────────────────┐ │  │
│  │  - calculate    │  │  StorageManager                 │ │  │
│  │  - track state  │  │  (Persistence)                  │ │  │
│  │  - manage       │  │                                 │ │  │
│  │    sessions     │  │  Properties ←→ Garmin Connect   │ │  │
│  └────────┬────────┘  │  Storage   ←→ Local Device      │ │  │
│           │           └─────────────────────────────────┘ │  │
│           │                                                │  │
│           ▼                                                │  │
│  ┌─────────────────┐    ┌─────────────────────────────────┐│  │
│  │  FieldView      │    │  ReminderManager                ││  │
│  │  (UI Display)   │◄───│  (Haptic Feedback)              ││  │
│  │                 │    │                                 ││  │
│  │  - render data  │    │  - vibration patterns           ││  │
│  │  - draw gauges  │    │  - backlight control            ││  │
│  │  - handle       │    │  - capability detection         ││  │
│  │    overlays     │    └─────────────────────────────────┘│  │
│  └────────┬────────┘                                       │  │
│           │                                                │  │
│           ▼                                                │  │
│  ┌─────────────────┐                                       │  │
│  │  FieldDelegate  │                                       │  │
│  │  (Input)        │───────────────────────────────────────┘  │
│  │                 │                                          │
│  │  - tap handling │                                          │
│  │  - zone mapping │                                          │
│  └─────────────────┘                                          │
│                                                               │
└───────────────────────────────────────────────────────────────┘
```

## Core Components

### 1. FuelPlannerApp (Entry Point)

**File**: `source/FuelPlannerApp.mc`

**Responsibilities**:
- Application lifecycle management
- Dependency initialization
- View/Delegate creation
- FIT field registration

**Key Methods**:
```monkeyc
function initialize()           // Constructor
function onStart(state)         // App start
function onStop(state)          // App stop
function getInitialView()       // Create main view
function getSettingsView()      // Create settings menu
function onSettingsChanged()    // Handle external settings changes
```

### 2. FuelModel (Core Logic)

**File**: `source/model/FuelModel.mc`

**Responsibilities**:
- Carbohydrate target calculation
- Deficit tracking
- Session state management
- Reminder timing
- Auto-intake logic

**State Machine**:
```
    ┌──────────┐
    │   IDLE   │
    └────┬─────┘
         │ startNewSession()
         ▼
    ┌──────────┐
    │ PRIMING  │◄─────────────────────┐
    └────┬─────┘                      │
         │ timer confirmed            │
         ▼                            │
    ┌──────────┐    pause()    ┌──────┴─────┐
    │  ACTIVE  │──────────────►│   PAUSED   │
    └────┬─────┘               └──────┬─────┘
         │                            │ resume()
         │ stop()                     │
         ▼                            │
    ┌──────────┐                      │
    │ FINISHED │◄─────────────────────┘
    └──────────┘
```

**Reminder Modes**:
1. **MODE_AUTO (0)**: Deficit-based with fixed g/h target
2. **MODE_FIXED (1)**: Fixed interval from last intake
3. **MODE_CALORIE_AUTO (2)**: Target derived from device calorie data

**Key Calculations**:
```monkeyc
// Target calculation (g10 = tenths of grams)
targetG10 = (elapsedSec * carbsTargetGph * 10) / 3600

// Calorie auto mode
targetG10 = (caloriesKcal * carbFractionPct * 10) / 400

// Deficit
deficitG10 = targetG10 - consumedG10

// Next due (seconds)
nextDueSec = ceil((doseG10 - deficitG10) * 3600 / carbsRateGph10)
```

### 3. StorageManager (Persistence)

**File**: `source/model/StorageManager.mc`

**Responsibilities**:
- Settings persistence (via Properties API, synced to Garmin Connect)
- Session data persistence (via Storage API, local only)
- Backward compatibility with legacy keys
- Error tracking

**Storage Architecture**:
```
┌─────────────────────────────────────────────────────┐
│                  Garmin Connect                      │
│  ┌────────────────────────────────────────────────┐ │
│  │  Properties (synced across devices)            │ │
│  │  - carbsTargetGph                              │ │
│  │  - doseG                                       │ │
│  │  - reminderMode                                │ │
│  │  - fixedIntervalMin                            │ │
│  │  - startDelayMin                               │ │
│  │  - maxSnoozeMin                                │ │
│  │  - carbFractionPct                             │ │
│  └────────────────────────────────────────────────┘ │
└─────────────────────────────────────────────────────┘
                       │ sync
                       ▼
┌─────────────────────────────────────────────────────┐
│                  Local Device                        │
│  ┌────────────────────────────────────────────────┐ │
│  │  Storage (device-specific, not synced)         │ │
│  │  - sess_id, start_ts, consum10, last_int       │ │
│  │  - is_paused, elapsed_s, pause_off_s           │ │
│  │  - start_ts_ok, int_cnt, last_rem              │ │
│  └────────────────────────────────────────────────┘ │
└─────────────────────────────────────────────────────┘
```

### 4. ReminderManager (Haptic Feedback)

**File**: `source/model/ReminderManager.mc`

**Responsibilities**:
- Vibration pattern management
- Backlight control
- Device capability detection
- Rate limiting (min 2s between vibes)

**Vibration Patterns**:
```monkeyc
// Intake reminder: Long-Medium-Long
[100 @ 400ms, 0 @ 100ms, 100 @ 200ms, 0 @ 100ms, 100 @ 400ms]

// Auto-intake: Short-Short
[45 @ 100ms, 0 @ 60ms, 45 @ 100ms]

// Confirmation: Short-Short
[50 @ 100ms, 0 @ 50ms, 50 @ 100ms]

// Snooze: Single medium
[25 @ 200ms]
```

### 5. FieldView (UI Display)

**File**:
- `source/FuelPlannerFieldView.mc`

**Display Layout**:
```
┌─────────────────────────────────────────────┐
│         Outer reminder ring                 │
│                                             │
│           Next 2:30                         │
│                                             │
│          150/300 g                          │
│                                             │
│         Behind 25 g                         │
│                                             │
│        1h23m | 6x                           │
│                                             │
│        Plan 60 g/h                          │
└─────────────────────────────────────────────┘

States:
- No session: "FuelPlanner" + "Waiting for activity..."
- Active: Status + consumed/target + deficit + meta + optional rate label
- Paused: "PAUSED" (yellow)
- Reminder due: "FUEL NOW" (blinking red)
- Recovery: "Fueling OK" (green) or "Recovery +XXg" (orange)
- Overlay: Full red screen with "FUEL NOW" + dose
```

### 6. FieldDelegate (Input Handling)

**File**: `source/FuelPlannerFieldDelegate.mc`

**Tap Zones**:
```
┌─────────────────────────────────────────────┐
│           Snooze Zone (top 20%)             │
├─────────────────────────────────────────────┤
│                                             │
│                                             │
│           Intake Zone (center 60%)          │
│                                             │
│                                             │
├─────────────────────────────────────────────┤
│          Undo Zone (bottom 20%)             │
└─────────────────────────────────────────────┘
```

The top zone snoozes only while a reminder is due. The bottom zone performs an undo only when the model exposes an undoable intake; otherwise edge taps are ignored.

## Data Flow

### Session Lifecycle

```
1. User starts activity
   └─► FuelPlannerApp.getInitialView()
       └─► FuelModel.loadSession()
           └─► StorageManager.hasActiveSession()
               ├─► Yes: Restore state
               └─► No: Wait for activity

2. Timer starts
   └─► FuelPlannerFieldView.compute(info)
       └─► FuelModel.compute(info)
           └─► FuelModel.startNewSession(activityStartTs)
               └─► StorageManager.saveSession()

3. Each tick (1 Hz)
   └─► FuelModel.compute(info)
       ├─► updateCalorieData(info)
       ├─► calculateTargetAndDeficit()
       ├─► calculateNextDue()
       ├─► checkReminderDue()
       ├─► applyAutoIntakeIfDue()
       └─► updateFitFields()

4. Reminder fires
   └─► FuelPlannerFieldView.compute()
       └─► ReminderManager.triggerReminder()
       └─► FuelModel.recordReminderTriggered()
       └─► StorageManager.saveSession()

5. User records intake
   └─► FuelPlannerFieldDelegate.onTap()
       └─► FuelModel.recordIntake(grams)
           └─► StorageManager.saveSession()

6. Activity ends
   └─► FuelModel.compute(info)
       └─► FuelModel.markSessionFinished()
           ├─► StorageManager.clearActiveSession()
           └─► StorageManager.setRecovery... snapshot values
```

## Compile-Time Optimization

The project uses Connect IQ compile-time attributes for test-only and feature-gated code:

```monkeyc
standard shipped product path
(:test)    // Test-only code
(:testsupport) // Test helpers
```

## Memory Management

Connect IQ devices have limited heap (typically 32-128 KB). FuelPlaner minimizes memory usage:

1. **Module-level constants**: Stored in bytecode, not heap
2. **Lazy initialization**: Vibe profiles created on first use
3. **Integer arithmetic**: g10 (tenths of grams) avoids Float where possible
4. **Bounded hot-path string work**: Shared string loading and short formatted labels
5. **Minimal object allocation**: Reuse existing objects

**Memory Budget** (estimated):
```
FuelModel:           ~2 KB
StorageManager:      ~0.5 KB
ReminderManager:     ~0.3 KB
FieldView:           ~1.5 KB
FieldDelegate:       ~0.2 KB
Strings/Resources:   ~2 KB
─────────────────────────
Total:               ~6.5 KB
```

## Error Handling Strategy

```
┌─────────────────────────────────────────────┐
│              Error Occurs                   │
└──────────────────┬──────────────────────────┘
                   │
                   ▼
┌─────────────────────────────────────────────┐
│         Is it recoverable?                  │
├─────────────┬───────────────────────────────┤
│    Yes      │           No                  │
│     │       │            │                  │
│     ▼       │            ▼                  │
│ ┌─────────┐ │    ┌───────────────────┐     │
│ │ Log &   │ │    │ Graceful fallback │     │
│ │ Track   │ │    │ + User warning    │     │
│ └─────────┘ │    └───────────────────┘     │
│             │                               │
└─────────────┴───────────────────────────────┘

Examples:
- Storage write failure → Track count, continue
- Missing calorie data → Fallback to MODE_AUTO
- Vibration unavailable → Use backlight
- Timer null → Suppress reminders, keep session
```

## Testing Strategy

```
┌─────────────────────────────────────────────┐
│              Unit Tests                     │
│  - FuelModel calculations                   │
│  - StorageManager operations                │
│  - ReminderManager logic                    │
└──────────────────┬──────────────────────────┘
                   │
                   ▼
┌─────────────────────────────────────────────┐
│           Integration Tests                 │
│  - Session lifecycle                        │
│  - Settings sync                            │
│  - Pause/resume                             │
└──────────────────┬──────────────────────────┘
                   │
                   ▼
┌─────────────────────────────────────────────┐
│           Device Tests                      │
│  - Real device behavior                     │
│  - Performance profiling                    │
│  - Memory stress testing                    │
└─────────────────────────────────────────────┘
```

## Future Architecture Considerations

### Planned Improvements

1. **Dependency Injection**
   ```
   IFuelStorage ← StorageManager
   IReminderManager ← ReminderManager
   IClock ← FuelClock
   ```

2. **Event Bus**
   ```
   Model → EventBus → Views
   View → EventBus → Model
   ```

3. **Component-Based Views**
   ```
   FieldView
   ├── StatusComponent
   ├── NumberComponent
   ├── RingComponent
   └── MetaComponent
   ```

### Scalability

The architecture supports:
- New reminder modes (add to FuelModel.calculateTargetTotalG10)
- New devices (add product ID to manifest.xml)
- New languages (add resource strings)
- New features (add to settings menu)

---

**Document Version**: 1.0
**Last Updated**: 2026-03-21
