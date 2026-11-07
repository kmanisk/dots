# Call of Duty: Modern Warfare (r4v3n / Randgrid.sys) - Proton Incompatibility

This document records the architectural reason why Call of Duty: Modern Warfare (r4v3n offline singleplayer release, `sp26`) cannot run under Linux Wine or Proton, and documents how to run it via the dual-boot Windows installation.

---

## 1. Overview and Target Details

- **Title**: Call of Duty: Modern Warfare (Steam App ID `1938090`, codename `sp26`)
- **Release Source**: SteamRIP / r4v3n offline SP v2
- **Install Path**: `/mnt/Games/NonSteamGames/Call of Duty - Modern Warfare 4 (2026)` (accessible from Windows as `D:\NonSteamGames\...`)
- **Status on Linux (Proton/Wine)**: **Incompatible** (Definitive architectural block)
- **Status on Windows (Dual-Boot)**: **Fully Working** via `!start_sp26.bat`

---

## 2. Technical Root Cause: Kernel-Mode Driver Requirement

The game relies on an offline bypass wrapper that interfaces directly with Activision's **Ricochet kernel anti-cheat driver** (`Randgrid.sys`).

Inspecting `!start_sp26.bat`:
```cmd
set DRIVERFILE=Randgrid.sys
set DRIVERNAME=atvi-randgrid_sr_offline
set EXENAME=sp26-cod.exe

sc.exe create %DRIVERNAME% type= kernel binPath="%CD%\%DRIVERFILE%"
sc.exe start "%DRIVERNAME%"
start /wait .\sp26\%EXENAME% hdeyguxs3zaumvlgvybm2vyc
sc.exe stop "%DRIVERNAME%"
sc.exe delete %DRIVERNAME%
```

### Why Wine and Proton Cannot Run This:
1. **No NT Kernel Support**: Wine and Proton translate user-mode Windows Win32 API calls to POSIX/Linux system calls. Wine cannot load or execute Windows NT kernel-mode drivers (`.sys` files) into the Linux kernel.
2. **Service Failure**: Calling `sc.exe create ... type= kernel` and `sc.exe start` inside a Proton prefix returns Windows error code 90 (`ERROR_NOT_SUPPORTED`). Wine's faux Service Control Manager (`services.exe`) explicitly rejects kernel-mode service starts.
3. **Attestation Crash**: When `sp26/sp26-cod.exe` executes without an active `\\.\atvi-randgrid_sr_offline` kernel handle, its security and TPM attestation modules (`tbs.dll`, `azure-attest-manager.dll`, `AzureAttestNormal.dll`) fail to communicate with the driver. This triggers an unhandled `0xc0000005` (Access Violation) loop in `ntdll.dll`, exhausting the stack and exiting with code 1.

---

## 3. How to Play on Windows (Dual-Boot)

The game files are located on the shared high-speed NTFS SSD partition (`/mnt/Games`), which is visible directly to the Windows installation:

1. Reboot your PC and select **Windows** from the bootloader / rEFInd menu.
2. In Windows File Explorer, navigate to your Games drive:
   `...\NonSteamGames\Call of Duty - Modern Warfare 4 (2026)`
3. Right-click **`!start_sp26.bat`** and select **Run as Administrator**.
4. The script will register `Randgrid.sys` in the Windows Service Manager, start the kernel driver, launch `sp26-cod.exe` with the decryption key (`hdeyguxs3zaumvlgvybm2vyc`), and automatically unregister the driver when you close the game.

---

## 4. Workstation State

- All Wine/Proton prefixes, runner wrappers, and test logs for this title have been removed from the Linux system (`~/.local/share/Steam/steamapps/compatdata/cod-mw4` deleted).
- No dead entries exist in `rofi-games` (`Alt + G`).
- The game directory on `/mnt/Games` remains fully intact and ready for Windows dual-boot play.
