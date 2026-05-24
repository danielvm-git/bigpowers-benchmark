#!/usr/bin/env bash
set -euo pipefail

echo "BigPowers Benchmark setup"

if ! command -v swift >/dev/null 2>&1; then
  echo "ERROR: swift not found. Install Xcode or Swift toolchain."
  exit 1
fi

if command -v xcodebuild >/dev/null 2>&1; then
  echo "[OK] xcodebuild found"
else
  echo "[WARN] xcodebuild not found — Xcode may be missing"
fi

if command -v opencode >/dev/null 2>&1; then
  echo "[OK] opencode $(opencode --version 2>/dev/null || echo 'installed')"
else
  echo "[WARN] opencode not found — benchmark runs will fail until installed"
fi

if command -v daytona >/dev/null 2>&1; then
  echo "[OK] daytona installed"
else
  echo "[WARN] daytona not found — sandbox features unavailable until installed"
fi

mkdir -p "$HOME/runs/data"
mkdir -p "$HOME/runs/logs"
mkdir -p "$HOME/Library/Logs/BigPowersBenchmark"
touch "$HOME/runs/data/.gitkeep"
touch "$HOME/runs/logs/.gitkeep"

if [[ ! -d "$HOME/runs/data/.git" ]]; then
  git -C "$HOME/runs/data" init -q
  echo "Initialized git repo at ~/runs/data"
else
  echo "Git repo at ~/runs/data already exists, skipping"
fi

echo "Building project..."
swift build -q

echo ""
echo "Setup complete."
echo "Configure Daytona API key in app Settings → Keychain."
echo "Debug logs: ~/Library/Logs/BigPowersBenchmark/debug.ndjson"
