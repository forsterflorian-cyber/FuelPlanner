# FuelPlanner Architecture

## Overview

FuelPlanner is a Garmin Connect IQ Data Field that provides intelligent carbohydrate fueling reminders during endurance activities. The architecture follows a clean separation of concerns with a Model-View-Delegate pattern adapted for the Connect IQ platform.

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
    │ PRIMING  │
    └────┬─────┘
         │ timer confirmed
         ▼
    ┌──────────┐  pause()/STOPPED  ┌──────────┐
    │  ACTIVE  │──────────────────►│  PAUSED  │
    └────┬─────┘◄──────────────────└────┬─────┘
         │          start()/resume()     │
         │                               │
         └───────────┬───────────────────┘
                     │ reset()/terminal OFF
                     ▼
               ┌──────────┐
               │ FINISHED │  transient persisted handoff state
               └────┬─────┘
                    │ verified recovery snapshot
                    ▼
               ┌──────────┐
               │  IDLE +  │
               │ RECOVERY │
               └──────────┘
```

Garmin `TIMER_STATE_STOPPED` is intentionally treated like `PAUSED`: it is resumable and does not create a final recovery result. Only timer reset or terminal `OFF` finalizes a session. `FINISHED` is a persistence handoff marker rather than a long-lived interactive state. The recovery view is `IDLE` plus a frozen snapshot, not another active-session state.

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
│  │  - versioned aggregate active-session snapshot │ │
│  │  - versioned aggregate recovery snapshot       │ │
│  │  - legacy scalar keys for migration/cleanup    │ │
│  └────────────────────────────────────────────────┘ │
└─────────────────────────────────────────────────────┘
```

The aggregate snapshots keep related values in one storage generation. Recovery handoff first attempts and verifies the final active state, then writes and verifies the recovery aggregate, and only then clears the active state. If cleanup is interrupted and both records remain, the matching confirmed recovery record takes precedence. If recovery fails after the `FINISHED` active aggregate commits, that aggregate remains so handoff can be retried after reload. If the final active write also fails, storage still retains the latest previously verified coherent active generation, which may predate finalization and reload as active.

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

**Normal Tap Routing** (no reminder or overlay):
```
┌─────────────────────────────────────────────┐
│            Inactive upper margin             │
│    ┌───────────────────────────────────┐    │
│    │                                   │    │
│    │     Intake (center rectangle)     │    │
│    │                                   │    │
│    └───────────────────────────────────┘    │
├─────────────────────────────────────────────┤
│       Undo lower band (when available)       │
└─────────────────────────────────────────────┘
```

The normal intake rectangle uses one-sixth insets from each edge. The lower sixth performs an undo only when the model exposes an undoable intake; other margin taps are ignored.

**Reminder/Overlay Tap Routing**:
```
┌─────────────────────────────────────────────┐
│       Snooze (visible dynamic top band)      │
├─────────────────────────────────────────────┤
│                                             │
│        Record intake (all remaining area)    │
│                                             │
└─────────────────────────────────────────────┘
```

Reminder routing is modal: the top band snoozes and every valid tap below it records the planned intake, including taps in the normal undo area. The view and delegate share the same boundary. Full layouts use approximately the top fifth; compact layouts use a larger bounded band so the visible target remains usable. Undo routing returns after the reminder or overlay is dismissed.

FuelPlanner enables these tap routes when the device reports that touch is available. Edge 820 and Edge Explore therefore use the same manual touch flow as newer touch products. Connect IQ 3.2 is the threshold for native `DataFieldAlert`, not for `InputDelegate.onTap`; devices without the native alert continue to use FuelPlanner's in-field reminder overlay.

## Data Flow

### Session Lifecycle

```
1. Application starts
   └─► FuelPlannerApp.onStart()
       ├─► Create StorageManager, FuelModel, and ReminderManager
       └─► FuelModel.loadSession()
           └─► StorageManager.loadActiveSessionSnapshot()
               ├─► Active aggregate: restore session state
               ├─► No active aggregate + recovery: load frozen recovery
               └─► Neither: wait for activity

2. Timer starts
   └─► FuelPlannerFieldView.compute(info)
       └─► FuelModel.compute(info)
           └─► FuelModel.startNewSession(activityStartTs)
               └─► FuelModel.saveSession()
                   └─► StorageManager.saveActiveSessionSnapshot()

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
       └─► FuelModel.saveSession()
           └─► StorageManager.saveActiveSessionSnapshot()

5. User records intake
   └─► FuelPlannerFieldDelegate.onTap()
       └─► FuelModel.recordIntake(grams)
           └─► FuelModel.saveSession()
               └─► StorageManager.saveActiveSessionSnapshot()

6. Timer is reset or reaches terminal OFF
   └─► FuelModel.markSessionFinished()
       ├─► Attempt and verify final versioned active-session record
       ├─► Write and read back versioned recovery snapshot
       ├─► Clear active state only after recovery is confirmed
       └─► Display the frozen recovery result

7. Timer is paused or STOPPED
   └─► FuelModel pauses and persists the active session
       └─► A later start/resume continues the same session
```

## Compile-Time Optimization

The project uses Connect IQ compile-time attributes for test-only and feature-gated code:

```monkeyc
standard shipped product path
(:test)    // Test-only code
(:testsupport) // Test helpers
```

## Memory Management

Connect IQ devices have limited heap. FuelPlanner minimizes memory usage:

1. **Module-level constants**: Stored in bytecode, not heap
2. **Lazy initialization**: Vibe profiles created on first use
3. **Integer arithmetic**: g10 (tenths of grams) avoids Float where possible
4. **Bounded hot-path string work**: Shared string loading and short formatted labels
5. **Minimal object allocation**: Reuse existing objects

Simulator memory checks are useful for regressions, but they are not a measurement of the physical FR955 data-field heap. Release reporting therefore keeps simulator memory results separate from physical-device profiling.

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

Validation results are always reported separately:

1. **Compile**: compiler and package results for named products or the full manifest matrix
2. **Simulator**: automated tests plus named layout and interaction checks
3. **Physical device**: named hardware, firmware, lifecycle, touch, haptic, FIT, and memory observations

Compile and simulator success do not imply physical-device validation. Version 1.0.0 currently carries no physical-device validation claim in this repository.

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

**Document Version**: 1.1
**Last Updated**: 2026-07-19
