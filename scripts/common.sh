#!/bin/bash

BASE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "$BASE_DIR/.." && pwd)"

# Pipes
RAW_DIR="$ROOT_DIR/cdn/storage/live/raw"
PIPE_144="$RAW_DIR/live_144p.ts"
PIPE_240="$RAW_DIR/live_240p.ts"

# Outputs
DASH_DIR="$ROOT_DIR/cdn/storage/live/dash"
HLS_DIR="$ROOT_DIR/cdn/storage/live/hls"

# DRM
KEY_ID="0123456789abcdef0123456789abcdef"
KEY="abcdefabcdefabcdefabcdefabcdefab"

# Video
SEGMENT_DURATION=2
BUFFER_DEPTH=60

# Docker
DOCKER_IMAGE="google/shaka-packager"
DOCKER_MOUNT="$ROOT_DIR:/data"

# PIDs
PID_DIR="$ROOT_DIR/pids"
mkdir -p "$PID_DIR"

ENCODER_PID="$PID_DIR/encoder.pid"
DASH_PID="$PID_DIR/dash.pid"
HLS_PID="$PID_DIR/hls.pid"

# ======================
# HELPERS
# ======================

kill_if_running() {
  local PID_FILE=$1
  local NAME=$2

  if [ -f "$PID_FILE" ]; then
    PID=$(cat "$PID_FILE")
    if ps -p $PID > /dev/null 2>&1; then
      echo "🛑 Killing $NAME ($PID)"
      kill -9 $PID || true
    fi
    rm -f "$PID_FILE"
  fi

  # fallback
  pkill -f "$NAME" 2>/dev/null || true
}