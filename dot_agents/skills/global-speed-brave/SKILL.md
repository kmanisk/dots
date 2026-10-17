---
name: global-speed-brave
description: Global Speed extension (Brave Origin) semantics and configuration - pinned vs global tab contexts, why new tabs reset playback speed, URL rules, shortcut blocklist, page vs browser shortcut scopes. Use when configuring or debugging Global Speed on this machine.
version: 1.0.0
---

# Global Speed on Brave Origin

Verified 2026-10-18 against a live install.

- Browser: Brave Origin (`/opt/brave-origin-bin`), profile `~/.config/BraveSoftware/Brave-Origin/Default`.
- Extension ID: `jpbjcnkcffbooppibceonlgknpkniiff` (Global Speed 3.4.124, Chrome Web Store build).
- Source reference: `polywock/globalSpeed` (`src/utils/state.ts`, `src/background/index.ts`, `src/background/rules.ts`, `src/defaults/`).

## Storage model

`chrome.storage.local` keys:

- `g:<key>` - global state (`g:speed`, `g:enabled`, `g:rules`, `g:pageKeybinds`, `g:browserKeybinds`, `g:pinByDefault`, ...).
- `t:<tabId>:<key>` - per-tab context that only exists while the tab is pinned (`isPinned`, `speed`, `enabled`, `elementFx`, `audioFx`, ...).
- `r:<tabId>:<key>` - URL rule override for that tab (an `OFF` rule writes `r:<tab>:enabled=false`).
- `s:*` - session-only keys.

Resolution order for a visible value: rule override > pinned tab context > global context.

Session keys (`s:`, `r:`, `t:`) are cleared on browser startup and on install/update. Pins do not survive a browser restart.

## Pin model (root cause of "speed resets on new tabs")

- "Pin new tabs" (`g:pinByDefault`, Options section -> "Pin new tabs") = every new tab is opened as an independently pinned tab: "Pinned tabs keep their own settings instead of sharing the global context".
- Seed context for a pinned tab comes from Initial context: PREVIOUS=1 copies the opener tab; a plain new tab (Ctrl+T / + button) has no opener and falls back to the global context; GLOBAL=2 copies global; NEW=3 fresh defaults; CUSTOM=4 a saved snapshot.
- With pinning ON, speed / on-off changes made in a tab are stored on that tab only and never become the default for new tabs. New tabs seed at `g:speed` (usually 1x), so speed appears to "turn off" on every new tab.
- With pinning OFF, changes write to `g:` and apply to all unpinned tabs and new tabs immediately. Per-tab pinning stays available manually (popup pin button, "pin" shortcut).
- Badge behavior: speed number when enabled; "OFF" text when the tab is disabled by a rule; pinned tabs use a blue badge background, global red.

## URL rules vs shortcut website policy (different mechanisms)

- URL Rules (`g:rules`, section "URL Rules"): types `SPEED | ON | OFF | FX | JS`. `OFF` disables the extension on matching URLs per tab.
- Shortcut website policy (`g:keybindsUrlCondition`, button "URL conditions" in the shortcut editor): `block:false` + allowParts = allowlist (shortcuts only on listed sites); `block:true` + blockParts = blocklist (shortcuts on all sites except listed).

## Shortcut scopes

- Page shortcuts (unmodified keys) fire only while the page has focus. `greedy: true` stops propagation so the site does not also receive the key.
- Browser shortcuts map manifest commands `commandA`..`commandS` (3.4.124 declares 19, no suggested keys) to keybind actions; actual keys are assigned in `brave://extensions/shortcuts`.
- Chromium constraint: extension command shortcuts must include Ctrl or Alt (Shift optional; Ctrl+Alt forbidden). Plain J/K/L cannot be browser shortcuts.
- "Global" scope ("Set in system settings") cannot be assigned on sway: no `GlobalShortcuts` xdg-desktop-portal interface on this box (only gnome-keyring/gtk/wlr portals). In-Brave scope works whenever Brave has focus. True OS-wide keys = xremap.

## Inspect live state

- Newest writes: `strings -a "$PROFILE/Local Extension Settings/jpbjcnkcffbooppibceonlgknpkniiff/000027.log"` (key on one line, value on the next; use `-n 1` so 1-char values like `1` appear). Watch for `t:<tab>:isPinned => true` spam (pin-per-tab) and `t:<tab>:speed => 1` seeds.
- Older compacted values (`g:*`) may only exist in `*.ldb` (snappy-compressed).
- Assigned command keys: `Preferences` -> `extensions.settings.<id>.commands` and `extensions.commands`.

## Verified fix pattern: one global speed, disabled sites stay off

1. Options -> "Pin new tabs" OFF.
2. Restart Brave (clears all `t:` pins) or unpin tabs individually from the popup.
3. Set the speed once; it becomes `g:speed` for all tabs and new tabs.
4. Keep the `OFF` type URL rule for sites that should stay disabled.
5. Note: while pinning is on, the "state" browser shortcut toggles only the current tab; with pinning off it toggles globally (all tabs), so avoid it if the extension should stay permanently on.
