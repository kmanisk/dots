# Proton Prefix Dependency Management Guide (.NET, VC++, & Runtimes)

**Target Environment:** CachyOS · Proton / Wine prefixes (`compatdata/<AppID>`)  
**Core Tool:** Protontricks (`/usr/bin/protontricks` v1.14.1) & Winetricks (`/usr/bin/winetricks`)  
**Relevance:** Mod Managers (Mod Organizer 2, Vortex), Game Mod Loaders (ME2, EldenModLoader), External Modding Tools & Randomizers (.NET 6.0 / 8.0, .NET Framework 4.8).

---

## 1. Overview: The Proton Virtual Windows Container

Valve Proton isolates each game into its own dedicated Windows virtual environment called a **compatdata prefix** (located under `~/.local/share/Steam/steamapps/compatdata/<AppID>/pfx`).

Because these prefixes are sandboxed:
- Standard system packages (like Linux `.NET` or `mono`) are **not** visible to Windows binaries running inside Proton.
- Tools like randomizers, mod launchers, and configuration GUIs that require Microsoft .NET Framework (4.x) or modern .NET Core / .NET Runtimes (6.0, 8.0) must have their Windows dependencies installed directly inside that game's prefix.

---

## 2. Primary Management Utilities

### A. Protontricks (CLI & GUI — Recommended for Steam Games)
Protontricks acts as a bridge between Steam and Winetricks, automatically locating the game's prefix by AppID or game title.

#### Command-Line Interface (CLI)
```bash
# General syntax:
protontricks <AppID> <verb>

# Install .NET Framework 4.8 (common for older mod managers & tools):
protontricks <AppID> dotnet48

# Install modern .NET Runtimes:
protontricks <AppID> dotnet6
protontricks <AppID> dotnet8

# Install Visual C++ Redistributables (common for DLL mods & hooks):
protontricks <AppID> vcrun2022

# Install DirectX runtime helpers:
protontricks <AppID> d3dcompiler_47
```

#### Graphical User Interface (GUI)
```bash
protontricks --gui
```
1. Select the target game from the list.
2. Choose **"Select the default wineprefix"**.
3. Select **"Install a Windows DLL or component"**.
4. Check the box for the needed runtime (e.g. `dotnet48`, `dotnet6`, `vcrun2022`) and click OK.

---

### B. Direct Proton Headless Execution (Fastest for Standalone Installers)
When an exact official installer executable is downloaded (e.g., Microsoft's official `windowsdesktop-runtime-8.0-win-x64.exe`):

```bash
STEAM_COMPAT_CLIENT_INSTALL_PATH="$HOME/.local/share/Steam" \
STEAM_COMPAT_DATA_PATH="$HOME/.local/share/Steam/steamapps/compatdata/<AppID>" \
"$HOME/.local/share/Steam/steamapps/common/Proton - Experimental/proton" run \
    /path/to/windowsdesktop-runtime-8.0-win-x64.exe /install /quiet /norestart
```

#### Verification inside the Prefix
```bash
WINEPREFIX="$HOME/.local/share/Steam/steamapps/compatdata/<AppID>/pfx" \
wine "C:\\Program Files\\dotnet\\dotnet.exe" --info
```

---

### C. Bottles & Non-Steam Prefix Managers
For standalone, GOG, or Epic Games titles running outside Steam:
- **Bottles:** Navigate to the bottle > **Dependencies** tab > click to install .NET Framework 4.0–4.8 or .NET Runtime 6, 7, 8, 9 with automatic registry adjustments.
- **Lutris & Heroic:** Use the embedded **Winetricks / Protontricks** button in the game context menu to execute verbs directly against the game container.

---

## 3. Critical Wine DLL Overrides for .NET

When installing official Windows Microsoft .NET runtimes into a prefix, Wine's internal fallback (Wine Mono) might try to intercept calls. To guarantee the Windows runtime is used:

```bash
# Add to launch command or launcher wrapper:
export WINEDLLOVERRIDES="mscoree=native"

# Or in Steam Launch Options:
WINEDLLOVERRIDES="mscoree=native" %command%
```

---

## 4. Quick Reference: Common Game Modding Requirements

| Tool / Mod | Requirement | Method |
|---|---|---|
| **Elden Ring Randomizer v0.12+** | .NET 8.0 Desktop Runtime (x64) | Direct installer / `protontricks <AppID> dotnet8` |
| **Dark Souls 3 Static Randomizer** | .NET Framework 4.6.1+ | Direct installer / `protontricks 374320 dotnet48` |
| **Mod Organizer 2 (MO2)** | VC++ 2019/2022 + .NET 8.0 | `protontricks <AppID> vcrun2022 dotnet8` |
| **Vortex Mod Manager** | .NET 6.0/8.0 Desktop Runtime | `protontricks <AppID> dotnet8` |
| **ReShade Installer** | .NET 6.0 Desktop Runtime | `protontricks <AppID> dotnet6` |
