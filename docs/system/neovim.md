# Neovim IDE Architecture & Keybinding Reference (Zed-Parity Overhaul)

## Verified dashboard behavior, 2026-10-23

The managed `lua/configs/dashboard.lua` now excludes floating windows when
choosing a dashboard host. A focused floating tool previously received the
dashboard; it now stays intact while the dashboard opens in a normal window.
The two-condition change is in the chezmoi source and applied target.

Headless tests passed for startup, final normal-buffer closure with NvimTree
focused, one dashboard only, reopening NvimTree, preserving Oil, and preserving
a floating tool. `lua_ls` attached to a Lua test buffer. Neo-tree is not configured
here, and interactive keyboard/visual testing was not performed. Warm startup
samples for the active local Neovim 0.12.5 were 41.0/37.8/40.5 ms under concurrent
build activity; these are a baseline, not an optimization claim. The packaged
Neovim 0.12.6 remains installed and the existing executable selection is preserved.

Tests and exact rollback: [workstation audit](workstation-audit-2026-10-23.md).

This document specifies the architecture, keybindings, and plugin layer for the overhauled Neovim configuration in `~/.config/nvim`, designed as a full-featured, resource-light IDE mirroring Zed.

---

## 1. Architectural Highlights

* **Base Framework:** NvChad v2.5 with a decoupled, modular IDE layer (`lua/configs/ide.lua`, `lua/plugins/ide.lua`).
* **Startup Performance:** Lazy-loading via `lazy.nvim` achieves instant launch (only ~8 plugins loaded on initial load out of 65 total).
* **60% Keyboard Compliant:** Zero physical function keys (`F1`-`F12`) are bound. All debugger actions, terminal toggles, and diagnostics use mnemonic `<leader>` space-chords.
* **Terminal Key Invariant:** `Alt+o` is strictly unmapped in Neovim to prevent collisions with `foot` terminal's URL mode.
* **Autosave & Hygiene:** Native event-driven autosave (500ms debounce on `CursorHold`/`CursorHoldI`, skipping non-file buffers) and automatic trailing whitespace stripping on save without third-party plugin overhead.
* **Theme Synchronization:** Dynamic integration with system theme via `chadrc.lua` and base46.

---

## 2. Zed-Compatible Keybindings (`mappings.lua`)

### Navigation, Windows & Splits
* `<C-w>`: Standard Vim window management prefix restored (no longer hijacked for tab close).
* `<C-h>`, `<C-j>`, `<C-k>`, `<C-l>`: Instant split navigation.
* `<leader>w/` or `<leader>wv`: Vertical split.
* `<leader>w-` or `<leader>ws`: Horizontal split.
* `<leader>wd` / `<leader>wq`: Close active window.
* `<leader>wo`: Close all other windows (maximize current).

### File Explorers & Tools
* `<leader>e`: Toggle project tree (`nvim-tree`).
* `-`: Open parent directory in `Oil.nvim`.
* `<leader>-`: Open `Oil` in floating window.
* `<leader>oE`: Dedicated Oil file explorer toggle.
* `<leader>oy`: Open `Yazi` terminal file manager inside Neovim.
* `<leader>cs`: Toggle code outline (`symbols-outline`).
* `<leader>xx`: Toggle diagnostics list (`Trouble.nvim`).
* `<leader>tt`: Toggle floating terminal (`toggleterm`).
* `<leader>th`: Toggle bottom horizontal terminal.

### Search & Buffers
* `<leader>f` / `<leader>ff`: Find files (`Telescope find_files`).
* `<leader>fw` / `<leader>sp`: Live grep project search.
* `<leader>bb`: Buffer switcher.
* `<leader>x`: Close current buffer (`tabufline.close_buffer()`).
* `<S-h>` / `<S-l>`: Switch to previous / next buffer tab.
* `<leader>sr`: Search and replace (`search-replace.nvim`).
* `s` / `S`: Sneak forward / backward 2-character motion with single-letter label direct jumps.

---

## 3. LSP, Formatting & Code Intelligence

### Language Server Protocol (LSP)
* **Attached Servers:** `lua_ls`, `pyright`, `vtsls`, `html`, `cssls`, `jsonls`, `emmet_language_server`, `tailwindcss`, `rust_analyzer`, `gopls`, `clangd`, `eslint`, `bashls`, `yamlls`, `marksman`, `jdtls` (Java).
* **Keymaps on Attach:**
  * `gd`: Go to definition.
  * `gD`: Go to declaration.
  * `gr`: Find references.
  * `gi`: Go to implementation.
  * `<leader>cr` / `<leader>rn`: Rename symbol.
  * `<leader>ca`: Code actions.
  * `K`: Hover documentation.
  * `<leader>ih`: Toggle inlay hints.
  * `[d` / `]d`: Jump to previous / next diagnostic.

### Formatting & Linting
* **Format-on-Save:** Driven by `conform.nvim` with fallback to LSP formatting.
* **Formatters:** `stylua`, `ruff`, `gofumpt`, `goimports`, `prettierd`, `clang-format`, `google-java-format`, `shfmt`.
* **Manual Format:** `<leader>cf` / `<leader>fm`.

---

## 4. Debugging & AI Integration (60% Ergonomics)

### Debug Adapter Protocol (DAP)
Zero function keys. Debugging is driven via leader chords:
* `<leader>b`: Toggle breakpoint.
* `<leader>Db`: Toggle breakpoint.
* `<leader>DB`: Conditional breakpoint.
* `<leader>Dl`: Log point.
* `<leader>Dc`: Continue / Start debugger.
* `<leader>Do`: Step over.
* `<leader>Di`: Step into.
* `<leader>DI`: Step out.
* `<leader>Dp`: Pause.
* `<leader>Dr`: Restart session.
* `<leader>Dt`: Terminate session.
* `<leader>Du`: Toggle debugger UI (`dap-ui`).
* `<leader>De`: Evaluate expression.

### AI Assistant (`CodeCompanion`)
* `<leader>ia`: Inline AI code assist (Normal & Visual mode).
* `<leader>ic`: Toggle AI interactive chat buffer.
* `<leader>iA`: Open AI code actions menu.
* Adapter: Google Gemini via `GEMINI_API_KEY`.

---

## 5. Session Management & State
* `<leader>oR`: Restore session search (`auto-session`).
* `<leader>oS`: Save current session.
* `<leader>oA`: Toggle automatic session save.
