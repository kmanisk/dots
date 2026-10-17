---
name: emacs-ide-performance
description: High-performance, modular, keyboard-first IDE architecture rules and patterns for Emacs on Linux.
---

# Emacs High-Performance IDE Architecture & Principles

## Core Architectural Invariants

1. **Emacs performance is always the first priority.**
   - Priority order: Typing responsiveness > Low completion latency > Low input latency > Reliable LSP > Fast navigation/search > Low idle CPU > Fast startup > Low memory overhead > Feature richness > Visual polish.
   - Never sacrifice editor responsiveness merely to imitate VS Code visually.

2. **Prefer fast, responsive editing over visual complexity.**
   - Avoid bloat, redundant packages, and duplicate functionality.
   - Avoid unnecessary background processes, polling timers, and synchronous I/O on the UI thread.
   - Say tearing/immediate window rules *reduce* input latency; never claim they bring it to zero.

3. **Feature-rich does NOT mean package-heavy.**
   - Build around native Emacs primitives whenever sufficient (`completion-at-point`, `xref`, `project.el`, `Flymake`, `treesit`, standard file and subprocess APIs).
   - Use third-party packages only where they provide clear, high-value improvements.

4. **Modular and Maintainable Architecture:**
   - Keep modules focused with single responsibilities (`mod-lsp.el`, `mod-completion.el`, `mod-project.el`, `mod-window.el`, etc.).
   - Use `autoloads`, `with-eval-after-load`, deferred initialization, and mode-specific hooks.
   - Configuration must remain human-readable and editable without unnecessary macro cleverness.

5. **Single Coherent LSP Architecture:**
   - Do not run competing global LSP systems (e.g. do not run Eglot and `lsp-mode` simultaneously).
   - Use `lsp-mode` with deferred startup (`lsp-deferred`) on programming hooks.
   - Optimize `lsp-mode`: disable file watchers, reduce idle delay, disable expensive breadcrumb/symbol-highlighting/lens rendering during fast typing.
   - Keep LSP diagnostics asynchronous via Flymake.

6. **Language-Appropriate LSP Integrations:**
   - **Java:** `lsp-java` + Eclipse JDT Language Server (JDTLS) + `lsp-mode`.
     - Use isolated per-project JDTLS workspace directories (`~/.cache/jdtls-workspaces/<project>`).
     - Detect supported JDK dynamically (prefer modern JDK like JDK 17+ / JDK 26).
     - Respect project-local build files (`pom.xml`, `build.gradle`, `settings.gradle`).
   - **Python:** Detect available server in priority order: `basedpyright` -> `pyright` -> `pylsp`. Detect project venvs (`.venv`, `venv`, `uv`, Poetry).
   - **C / C++:** `clangd` with `--background-index`, `--clang-tidy`, respecting `compile_commands.json` / `compile_flags.txt`.
   - **Rust:** `rust-analyzer` respecting `Cargo.toml`.
   - **Go:** `gopls`.
   - **JS / TS:** `typescript-language-server`.
   - Only activate servers whose executables exist in `PATH`.

7. **Fast Completion Architecture:**
   - **Corfu + Cape + Orderless + Yasnippet** over `completion-at-point-functions` (CAPF).
   - Fast popup without freezing typing (`corfu-auto t`, small delay `0.05s - 0.1s`).
   - Cape backends: `cape-file`, `cape-elisp-symbol`, `cape-keyword`, `cape-dabbrev`.
   - Yasnippet integrated cleanly for instant template expansions (e.g., Java `sout` -> `System.out.println($1);`).

8. **Tree-sitter:**
   - Built-in `treesit` loaded lazily; remap modes only when tree-sitter grammars are compiled and available.

9. **Theme & UI Performance:**
   - Themes are performance-sensitive infrastructure, not decoration.
   - Avoid animated themes, continuously evaluated visual effects, or heavy background redraws.
   - Use face-based themes (e.g., `doom-themes`, `vscode-dark-plus`, `green-phosphor`) with reliable built-in fallback.
   - Keep tab bar font compact (`:height 0.85`) and sidebar clean without distracting mode-lines.

10. **Error Handling & Validation:**
    - Never blanket-wrap code in `(ignore-errors ...)`.
    - Isolate optional features so they fail independently without breaking Emacs startup.
    - Always validate configuration by running tests/batch evaluations before completing changes.
