# Standby Guide: Solitude 3 Nighttime Brightness & Gamma Calibration

**Target Game:** Grand Theft Auto IV: Complete Edition (1.2.0.59)  
**Status:** Standby Configuration (Reverted from active cfg; preserved on-demand)  
**Related Snapshots:** Baseline #34, Revert #35

---

## 1. Overview
In Solitude 3 v1.1.5, nighttime ambient coefficients (`amb_r`, `amb_g`, `amb_b`) from 00:00 to 05:00 are authored specifically around the Xbox 360 sRGB gamma curve (`ConsoleGamma = 1`).
When running under standard PC linear gamma (`ConsoleGamma = 0`), deep shadow recesses, asphalt, and vehicle paint fall below 0 IRE (crushed blacks).

---

## 2. On-Demand Activation Options (Lossless & Zero Performance Overhead)

### Option A: In-Game Display Sliders (Zero file changes)
* In **Pause Menu → Display**:
  * **Brightness:** Increase by **+2 to +4 ticks**.
  * **Contrast:** Decrease by **-1 or -2 ticks**.
* *Effect:* Instantly lifts the dark shadow floor without blowing out neon or streetlights.

### Option B: Enable FusionFix Console Gamma
* In **Pause Menu → Display → Console Gamma: Set to `ON`**
* Or in [`plugins/GTAIV.EFLC.FusionFix.cfg`](file:///home/onyx/.local/share/Steam/steamapps/common/Grand%20Theft%20Auto%20IV/GTAIV/plugins/GTAIV.EFLC.FusionFix.cfg):
  ```ini
  ConsoleGamma = 1
  ```
* *Effect:* Activates the console-style non-linear sRGB gamma curve, elevating road and shadow details naturally with 0 FPS impact.

### Option C: Timecycle Swap (DayL's Natural Timecycle)
* Pre-staged in [`standby_mods/dayl_natural/`](file:///home/onyx/.local/share/Steam/steamapps/common/Grand%20Theft%20Auto%20IV/GTAIV/standby_mods/dayl_natural/).
* *Effect:* Provides a brighter, softer urban nighttime sky with naturally higher ambient bounce.
