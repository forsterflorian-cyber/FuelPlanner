# Technical Specification

## Calculation Logic
- ElapsedTime: Only includes active timer time (Smart-Pause).
- Deficit: (ActiveMinutes * (TargetGph / 60)) - ConsumedGrams.
- Calorie Mode: TargetCarbs = kcal * (CarbPercent / 100).

## UI Layout (Relative Design)
- Gauges: Scaled using screen width factors (dc.getWidth() * 0.05).
- Zones: Touch detection split at 25% (Top), 50% (Center), 75% (Bottom).
- Colors: 
  * Green/White: On track.
  * Yellow/Orange: Approaching threshold or ahead of plan.
  * Red: Deficit reached gel size.

## FitContributor Fields
- Field 1: Total Consumed Carbs (Uint16).
- Field 2: Current Deficit (Float).