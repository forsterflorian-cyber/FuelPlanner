==============================================================================
PROJECT CONTEXT & HANDOVER - FuelPlanner
==============================================================================
Current Status: Initial Beta (v0.1.0)
Principle: Relative Design (All UI scales via screen height/width factors)

### KEY IMPLEMENTATIONS
- Logic: FuelModel calculates deficit based on (ElapsedMinutes * Gph/60).
- Modes: 
  * Auto: Triggers when deficit reaches gel size.
  * Fixed: Simple timer-based intervals.
  * Calorie Auto: Carbs = burned calories * carb_fraction.
- UI: FuelPlannerFieldView uses 3-zone touch interaction.
  * Top 25%: Snooze / Half Dose.
  * Center: Default Dose / Menu.
  * Bottom 25%: Double Dose.
- Hardware: Auto-Flow logic for button-only devices (Fenix/Forerunner).

### DATA INTEGRITY
- Persistence: Session survives watch restarts mid-activity.
- FIT Fields: Records mDeficitField and mTotalCarbsField for summary.

### BACKLOG
- [ ] Refine Calorie Auto metabolic efficiency factors.
- [ ] Implement "Undo" logic for accidental bookings.
- [ ] Add visual "Flash" feedback on successful logging.
==============================================================================