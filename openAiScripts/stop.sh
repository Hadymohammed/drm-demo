#!/bin/bash

source "$(dirname "$0")/common.sh"

kill_if_running "$ENCODER_PID" "ffmpeg"
kill_if_running "$DASH_PID" "packager"
kill_if_running "$HLS_PID" "packager"

rm -f "$PIPE_144" "$PIPE_240"

echo "🛑 All stopped"