# btop Resource Monitor Architecture & Custom Patching

This document outlines the btop deployment, scratchpad/floating integration, binary precedence, and source-level patching architecture on this workstation.

---

## 1. System Integration & Execution Modes

`btop` (v1.4.7+) is the primary terminal resource monitor for CPU, GPU (NVIDIA RTX 5050 + Intel UHD), memory, disks, network, and process activity.

### Launch Paths
1. **Dedicated Floating Window (`toggle-btop`):**
   * Launcher: `~/.local/bin/toggle-btop` (source: `dot_local/bin/executable_toggle-btop`).
   * Spawns a dedicated Wayland client: `footclient --app-id=btop btop`.
   * Sway window rule (`~/.config/sway/config.d/30-window-rules.conf`):
     ```sway
     for_window [app_id="(?i)^btop$"] floating enable, resize set 1820 1100, move position center
     ```
2. **Scratchpad Terminal (`Ctrl + Space` / `Alt + \``):**
   * Managed via `~/.local/bin/scratch-toggle term`.
   * Runs inside `scratch-term` with Foot override font `Iosevka Nerd Font Mono:size=16:style=Regular`.
   * Output-scale cap: scaled to 90% (`SCRATCH_SCALE_PCT=90`, `1328x830` on 1476x923 logical Wayland output). Provides full width for multi-column memory and disk meters without triggering btop's abbreviated compact labels (`U`, `A`, `C`, `F`).

---

## 2. Configuration & Binary Precedence

### Configuration Locations
* Live user config: `~/.config/btop/btop.conf`
* Chezmoi source of truth: `dot_config/btop/btop.conf`
* Autostart theme integration: generated via `theme-set` from `dot_config/theme/templates/btop.theme`.

### Binary Path Invariant
```
~/.local/bin/btop   (tailored workstation binary, highest precedence)
/usr/bin/btop       (system package managed by pacman / cachyos-extra-v3)
```
Because `~/.local/bin` precedes `/usr/bin` in the user `$PATH`:
* Routine package updates (`pacman -Syu`, `cachyos-rate-mirrors`) write to `/usr/bin/btop` and never modify `~/.local/bin/btop`.
* User-level patches, font adjustments, and source customizations persist across system updates.

---

## 3. Implemented Disk I/O & Symbol Patch (`R` / `W` Mode)

### Problem
In upstream btop (`src/btop_draw.cpp`), disk read and write throughput values are rendered using hardcoded Unicode black triangles:
* Read throughput: `"▲" + floating_humanizer(...)`
* Write throughput: `"▼" + floating_humanizer(...)`

In `Iosevka Nerd Font Mono`, characters have a standard monospace advance width of 500 units. The patched Nerd Font glyphs for `▲` (`U+25B2`) and `▼` (`U+25BC`) have a bounding box width of 780 units (`xMin=110, xMax=890`), overflowing the cell boundary by 56%. In the disk box, upstream btop formats speeds without an intervening space (`▲3.3M`), causing the oversized glyph to visually bleed into and overlap the following number. Furthermore, active throughput hides the `R` and `W` indicators, leaving the user with ambiguous arrows or combined `▼▲` strings.

### Solution
The tailored binary in `~/.local/bin/btop` replaces all hardcoded triangle glyphs with clean text identifiers, cleans interface and sort navigation symbols, restores delicate high-resolution braille telemetry, and fixes upstream graph character slicing:
* **Separate I/O mode (`io_graph_combined = false`):** Dedicated rows for Read and Write. Read displays `R <speed>` (e.g. `R 48K`) when active and `R` when idle. Write displays `W <speed>` (e.g. `W 1.4M`) when active and `W` when idle. Character clears are expanded to 8 spaces to prevent digit ghosting.
* **Combined I/O mode fallback (`io_graph_combined = true`):** Active transfers format as `R <speed> W <speed>` instead of `▼▲`. When idle, it shows `R / W`.
* **Standard space mode (`io_mode = false`):** Throughput in the disk header formats as `R:<speed> W:<speed>`.
* **CPU / GPU Midline Graph Divider:** Replaced `total ▲▼gpu-totals` with `total / gpu-totals`.
* **Network Box:** Removed `▲` and `▼` from upload, download, Top, and Total rows.
* **Network & Process Selectors:** Replaced wide Unicode arrow characters (`←` and `→`) with clean ASCII angle brackets (`<` and `>`). The network interface selector renders cleanly as `<b wlan0 n>` without glyph/ligature collisions, and process sorting displays `< memory >`.
* **Battery Box:** Replaced `▲` and `▼` with `+` (charging) and `-` (discharging).
* **Bottom Toolbar & Scrollbar Directional Symbols (`Symbols::up` & `Symbols::down`):**
  * Replaced `↑` and `↓` with clean ASCII `^` and `v`. The process selector renders as `^ select v` and the process list scrollbar uses `^` (top) and `v` (bottom) without glyph overflow.
* **Bottom Toolbar Hotkey Layout & Enter Caret Collision (`<enter> info`):**
  * In upstream btop, the info button hardcoded `"info "` followed by `Symbols::enter` (`"↵"`), immediately abutted against `title_right_down` (`└`) and `title_left_down` (`┘`) before `terminate`. In `Iosevka Nerd Font Mono`, the carriage return arrow `↵` (`U+21B5`) has an oversized bounding box that collided into the tab brackets `└┘` and the letter `t` of `terminate`.
  * Replaced `info ↵` with `<enter> info`, placing the shortcut `<enter>` in highlighted color (`hi_fg`) followed by the action `info`, matching the rest of the toolbar (`terminate`, `kill`, `signals`, `Nice`, `Follow`). The button ends cleanly with ASCII `o`, preventing any glyph collision with `└┘` and `terminate`. Updated mouse click hitbox from width 6 to width 12 (`mouse_x += 14`).
* **Process List Simplification (`proc_cpu_graphs = false`):**
  * Disabled per-process mini CPU graph bars in `proc`, allocating full terminal width to command paths and cleanly displaying actual RAM usage (`MemB`) and `Cpu%`.
* **High-Resolution Telemetry Graphs (`graph_symbol = "braille"`):**
  * Uses 8-dot Unicode Braille matrices (`⢀⣠⣤⣴⣶⣾⣿`) for CPU, GPU, Net, and Disk graphs, producing smooth waveforms and organic curves while eliminating monolithic solid block "glazing".
* **Robust UTF-8 Character Slicing in `Graph::operator()`:**
  * Fixed an upstream btop bug where single-height line graphs hardcoded `find_first_of('m') + 4` when scrolling old data points.
  * In `btop_draw.cpp`, character byte widths are now dynamically determined from the UTF-8 lead byte (1 to 4 bytes). This prevents ANSI escape codes (`\x1b[38;2;...m`) from being truncated into literal raw text (such as `2;112;132;169m` or `;2;81;160;175m`), ensuring `Cache` and `Free` memory meters and throughput values render cleanly without text artifacts.

### Configuration in `btop.conf`:
```ini
# Default symbols to use for graph creation ("braille", "block" or "tty")
graph_symbol = "braille"

# Toggles io mode for disks, showing dedicated graphs for disk read/write speeds
io_mode = true

# Shows separate read and write graphs clearly labeled R and W
io_graph_combined = false

# Disable per-process mini CPU graph bars in the process list
proc_cpu_graphs = false

# Default sort by memory
proc_sorting = "memory"
```

---

## 4. Reproducible Build & Re-Patch Procedure

To recompile or update the patched btop binary from upstream source:

```bash
TMP_DIR=$(mktemp -d /tmp/btop-build-XXXXXX)
git clone --depth=1 https://github.com/aristocratos/btop.git "$TMP_DIR"
cd "$TMP_DIR"

python3 - <<'EOF'
import re

path = "src/btop_draw.cpp"
with open(path, "r", encoding="utf-8") as f:
    code = f.read()

# 1. Replace Left and Right arrows with clean ASCII "<" and ">"
assert 'const string Symbols::left = "←";' in code
assert 'const string Symbols::right = "→";' in code
code = code.replace('const string Symbols::left = "←";', 'const string Symbols::left = "<";')
code = code.replace('const string Symbols::right = "→";', 'const string Symbols::right = ">";')

# 2. CPU Midline divider
assert 'graph_up_field + Mv::r(1) + "▲▼" + Mv::r(1) + graph_lo_field;' in code
code = code.replace(
    'graph_up_field + Mv::r(1) + "▲▼" + Mv::r(1) + graph_lo_field;',
    'graph_up_field + " / " + graph_lo_field;'
)

# 3. Battery status symbols
assert '{"charging", "▲"},' in code
assert '{"discharging", "▼"},' in code
code = code.replace('{"charging", "▲"},', '{"charging", "+"},')
code = code.replace('{"discharging", "▼"},', '{"discharging", "-"},')

# 4. Disks IO Combined mode fallback: show "R <speed> W <speed>" or "R <speed>" or "W <speed>" or "R / W", never arrows
old_comb = '''const string humanized = (disk.io_write.back() > 0 ? "▼"s : ""s) + (disk.io_read.back() > 0 ? "▲"s : ""s)
												+ (comb_val > 0 ? Mv::r(1) + floating_humanizer(comb_val, true) : "RW");'''
new_comb = '''const string humanized = (comb_val > 0 ?
							(disk.io_read.back() > 0 ? "R "s + floating_humanizer(disk.io_read.back(), true) + (disk.io_write.back() > 0 ? " "s : ""s) : ""s) +
							(disk.io_write.back() > 0 ? "W "s + floating_humanizer(disk.io_write.back(), true) : ""s) : "R / W"s);'''
assert old_comb in code
code = code.replace(old_comb, new_comb)

# 5. Disks IO Separate mode: Always show "R <speed>" and "W <speed>" when active, "R" and "W" when idle
old_sep = '''const string human_read = (disk.io_read.back() > 0 ? "▲" + floating_humanizer(disk.io_read.back(), true) : "R");
						const string human_write = (disk.io_write.back() > 0 ? "▼" + floating_humanizer(disk.io_write.back(), true) : "W");
						if (disks_io_h <= 3) out += Mv::to(y+1+cy, x+1+cx) + string(5, ' ') + Mv::to(y+cy + disks_io_h, x+1+cx) + string(5, ' ');'''
new_sep = '''const string human_read = (disk.io_read.back() > 0 ? "R " + floating_humanizer(disk.io_read.back(), true) : "R");
						const string human_write = (disk.io_write.back() > 0 ? "W " + floating_humanizer(disk.io_write.back(), true) : "W");
						if (disks_io_h <= 3) out += Mv::to(y+1+cy, x+1+cx) + string(8, ' ') + Mv::to(y+cy + disks_io_h, x+1+cx) + string(8, ' ');'''
assert old_sep in code
code = code.replace(old_sep, new_sep)

# 6. Non-IO disk list header: show "R:<speed> W:<speed>" without arrows
old_header = '''const string human_io = (comb_val > 0 ? (disk.io_write.back() > 0 and big_disk ? "▼"s : ""s) + (disk.io_read.back() > 0 and big_disk ? "▲"s : ""s)
											+ floating_humanizer(comb_val, true) : "");'''
new_header = '''const string human_io = (comb_val > 0 ?
							(disk.io_read.back() > 0 ? "R:"s + floating_humanizer(disk.io_read.back(), true) + (disk.io_write.back() > 0 ? " "s : ""s) : ""s) +
							(disk.io_write.back() > 0 ? "W:"s + floating_humanizer(disk.io_write.back(), true) : ""s) : "");'''
assert old_header in code
code = code.replace(old_header, new_header)

# 7. Network box: remove arrow prefixes
assert 'const string symbol = (dir == "upload" ? "▲" : "▼");' in code
code = code.replace(
    'const string symbol = (dir == "upload" ? "▲" : "▼");',
    'const string symbol = "";'
)

# 8. Robust UTF-8 length handling in Graph::operator() (prevents ANSI escape code corruption)
old_erase = '''		for (const int& i : iota(0, height)) {
			if (height == 1 and graphs.at(current).at(i).at(1) == '[') {
				if (graphs.at(current).at(i).at(3) == 'C') graphs.at(current).at(i).erase(0, 4);
				else graphs.at(current).at(i).erase(0, graphs.at(current).at(i).find_first_of('m') + 4);
			}
			else if (graphs.at(current).at(i).at(0) == ' ') graphs.at(current).at(i).erase(0, 1);
			else graphs.at(current).at(i).erase(0, 3);
		}'''

new_erase = '''		for (const int& i : iota(0, height)) {
			auto& line_str = graphs.at(current).at(i);
			if (height == 1 and line_str.size() > 1 and line_str.at(1) == '[') {
				if (line_str.size() > 3 and line_str.at(3) == 'C') line_str.erase(0, 4);
				else {
					auto m_pos = line_str.find_first_of('m');
					if (m_pos != string::npos) {
						size_t char_len = 1;
						if (m_pos + 1 < line_str.size()) {
							unsigned char c = static_cast<unsigned char>(line_str.at(m_pos + 1));
							if ((c & 0x80) == 0) char_len = 1;
							else if ((c & 0xE0) == 0xC0) char_len = 2;
							else if ((c & 0xF0) == 0xE0) char_len = 3;
							else if ((c & 0xF8) == 0xF0) char_len = 4;
						}
						line_str.erase(0, m_pos + 1 + char_len);
					}
					else line_str.erase(0, 1);
				}
			}
			else if (line_str.size() > 0 and line_str.at(0) == ' ') line_str.erase(0, 1);
			else if (line_str.size() >= 3) line_str.erase(0, 3);
			else line_str.clear();
		}'''
assert old_erase in code
code = code.replace(old_erase, new_erase)

# 9. Symbols::up and Symbols::down replaced with clean ASCII "^" and "v"
assert 'const string Symbols::up = "↑";' in code
assert 'const string Symbols::down = "↓";' in code
code = code.replace('const string Symbols::up = "↑";', 'const string Symbols::up = "^";')
code = code.replace('const string Symbols::down = "↓";', 'const string Symbols::down = "v";')

# 10. Replace "info ↵" in bottom proc toolbar with "<enter> info" and update mouse_x
old_info = '''			out += Mv::to(y + height - 1, x + 1) + title_left_down + Fx::b + hi_color + up_button + Theme::c("title") + " select " + down_button + Fx::ub + title_right_down
				+ title_left_down + Fx::b + t_color + "info " + hi_color + Symbols::enter + Fx::ub + title_right_down;
				if (selected > 0) Input::mouse_mappings["info_enter"] = {y + height - 1, mouse_x, 1, 6};
				mouse_x += 8;'''

new_info = '''			out += Mv::to(y + height - 1, x + 1) + title_left_down + Fx::b + hi_color + up_button + Theme::c("title") + " select " + down_button + Fx::ub + title_right_down
				+ title_left_down + Fx::b + hi_color + "<enter> " + t_color + "info" + Fx::ub + title_right_down;
				if (selected > 0) Input::mouse_mappings["info_enter"] = {y + height - 1, mouse_x, 1, 12};
				mouse_x += 14;'''
assert old_info in code
code = code.replace(old_info, new_info)

with open(path, "w", encoding="utf-8") as f:
    f.write(code)

print("Patch applied successfully and all assertions passed!")
EOF

make -j"$(nproc)"
install -m 755 bin/btop "$HOME/.local/bin/btop"
rm -rf "$TMP_DIR"
```

---

## 5. Potential Source Customizations

Beyond disk labels, the following source-level modifications are feasible when customizing btop for specific ricing, gaming, or typography requirements:

### A. Network Transfer Symbols (`src/btop_draw.cpp`)
* **Upstream:** Uses `▲` for upload and `▼` for download in `draw_net()`.
* **Patch:** Replace with standard networking notation `TX ` and `RX ` (or `UP ` and `DN `) to prevent glyph collisions in monospace fonts.

### B. Battery Status Indicators (`src/btop_draw.cpp`)
* **Upstream:**
  ```cpp
  {"charging", "▲"},
  {"discharging", "▼"},
  ```
* **Patch:** Replace with `+` (charging) and `-` (discharging) or `CHR` and `BAT` for clean ASCII rendering in the battery meter: `BAT+ 60% 0.00W`.

### C. Thermal Scale Thresholds for HX-Class Laptop CPUs (`src/btop_draw.cpp`)
* **Upstream:** Hardcodes thermal gradient transition points calibrated for desktop CPUs (turning yellow at ~70°C and red above ~80°C).
* **Workstation Context:** The Intel Core i5-13450HX operates within normal boost envelopes up to 85°C-92°C under mixed compilation or gaming loads.
* **Patch:** Shift gradient color inflection points in `Cpu::collect()` or `Theme::g("temp")` (e.g. green up to 75°C, yellow up to 88°C, red only above 92°C) so visual warnings represent actual thermal limits rather than routine turbo boost.

### D. Process Name Sanitization & Truncation (`src/btop_draw.cpp`)
* **Upstream:** Truncates process commands from the right or wraps full directory paths (e.g., `/opt/brave-origin-bin/brave ...`).
* **Patch:** Strip redundant launcher wrapper paths (`/usr/bin/`, `/opt/.../`) and display clean executable basenames with selective argument highlights.

### E. Custom Box Titles & Borders
* **Upstream:** Box titles use numbers `1cpu`, `2mem`, `3net`, `4proc`.
* **Patch:** Strip numeric hotkey badges or replace box frame corners with custom minimal glyphs (`┌`, `└` to squared or borderless styling) for minimal tiling aesthetic.
