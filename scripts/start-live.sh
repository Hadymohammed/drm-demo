#!/bin/bash

# start-live.sh
# Responsibility: Start live video capture from Mac camera
# Output: Raw video segments to RAW_DIR

set -e
source "$(dirname "$0")/config.sh"

log_info "Starting live video capture from Mac camera..."

ensure_directories

# Kill any existing ffmpeg process
pkill -f "ffmpeg.*avfoundation" 2>/dev/null || true

# FFmpeg: Capture from Mac camera and output raw video
# This will continuously generate segments as video is captured
ffmpeg -f avfoundation -framerate "$FRAMERATE" -i "0" \
  -c:v libx264 \
  -preset "$VIDEO_PRESET" \
  -tune "$TUNE" \
  -pix_fmt yuv420p \
  -g 60 -keyint_min 60 -sc_threshold 0 \
  -f segment \
  -segment_time "$SEGMENT_DURATION" \
  -segment_format mpegts \
  -reset_timestamps 1 \
  "$RAW_DIR/segment_%03d.ts" &

FFMPEG_PID=$!
log_success "FFmpeg capturing live video (PID: $FFMPEG_PID)"
log_info "Segments will be written to: $RAW_DIR"
log_info "Waiting for segments to be generated..."

# Wait a bit to ensure segments are created
sleep 3

# Check if segments were created
if [ -f "$RAW_DIR/segment_000.ts" ]; then
    log_success "First segment generated successfully"
else
    log_warning "Waiting for first segment..."
    sleep 5
fi

# Keep the process running
wait $FFMPEG_PID
