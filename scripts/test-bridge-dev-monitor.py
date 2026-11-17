#!/usr/bin/env python3
"""Pure, offline regression for the operator-only BridgeDev TUI."""
import importlib.util
import json
from pathlib import Path
from unittest.mock import patch

source = Path("dot_local/bin/executable_bridge-dev-monitor")
spec = importlib.util.spec_from_file_location("bridge_dev_monitor", source)
# extensionless executable has no default Python loader
from importlib.machinery import SourceFileLoader
spec = importlib.util.spec_from_loader("bridge_dev_monitor", SourceFileLoader("bridge_dev_monitor", str(source)))
mod = importlib.util.module_from_spec(spec)
spec.loader.exec_module(mod)

class Response:
    def __enter__(self): return self
    def __exit__(self, *_): pass
    def read(self): return json.dumps({"ok": True, "entries": [], "active": [
        {"request_id": "fixture-1", "tool": "read_text_file", "started_at": "2026-11-17T12:00:00Z"}]}).encode()

state = mod.MonitorState({"ADMIN_PORT": "3001", "ADMIN_TOKEN": "test-only"})
with patch.object(mod.urllib.request, "urlopen", return_value=Response()):
    state.fetch_recent_activities()
assert len(state.active_requests) == 1
assert state.active_requests[0]["tool"] == "read_text_file"

class Screen:
    def __init__(self): self.output = []
    def getmaxyx(self): return (30, 110)
    def erase(self): self.output.clear()
    def addstr(self, y, x, text, attrs=0): self.output.append((y, str(text)))
    def refresh(self): pass

screen = Screen()
state.health = {"status": "ok", "pid": 1200, "policy_mode": "standard", "active_sessions": 1}
state.streaming = True
app = mod.TuiApp(screen, state)
with patch.object(mod.curses, "color_pair", return_value=0):
    app.render()
assert any(y == 2 and "MCP RUNNING: 1" in text for y, text in screen.output)
assert not any("test-only" in text for _, text in screen.output)

with state.lock:
    state.active_requests = []
with patch.object(mod.curses, "color_pair", return_value=0):
    app.render()
assert any(y == 2 and "NO ACTIVE MCP CALL" in text for y, text in screen.output)
assert any("ChatGPT response state unavailable" in text for _, text in screen.output)
print("BridgeDev TUI active-call banner and idle distinction: PASS")
