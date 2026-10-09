#!/usr/bin/env bash
# ==============================================================================
# rollback.sh — Rollback native microphone filter chains to original state
# ==============================================================================
set -euo pipefail

echo ":: Stopping voice FX engine..."
~/.local/bin/mic voice off 2>/dev/null || true
pkill -x dusky-fx 2>/dev/null || true

echo ":: Removing native mic filter chains..."
rm -f ~/.config/pipewire/pipewire.conf.d/40-mic.conf
rm -f ~/.config/pipewire/pipewire.conf.d/41-mic-fx.conf

echo ":: Restarting PipeWire stack..."
systemctl --user restart pipewire pipewire-pulse wireplumber
sleep 1

echo ":: Restoring dusky-audio-dsp service..."
systemctl --user enable --now dusky-audio-dsp.service 2>/dev/null || true

echo ":: Rollback complete. Original stack restored."
