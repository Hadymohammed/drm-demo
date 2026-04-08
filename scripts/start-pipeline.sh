#!/bin/bash

# start-pipeline.sh
# Responsibility: Main entry point - orchestrates all DRM transcoding and packaging
# Calls: start-live.sh, package-dash-drm.sh, package-hls-drm.sh

set -e
source "$(dirname "$0")/config.sh"

# Get the script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

log_info "======================================"
log_info "DRM Transcode & Package Pipeline"
log_info "======================================"
log_info ""

# Ensure all scripts are executable
chmod +x "$SCRIPT_DIR"/*.sh 2>/dev/null || true

# Step 1: Display configuration
log_info "Configuration:"
log_info "  Output Dir:      $OUTPUT_DIR"
log_info "  Raw Segments:    $RAW_DIR"
log_info "  DASH Output:     $DASH_DIR"
log_info "  HLS Output:      $HLS_DIR"
log_info "  DRM Method:      Raw Key Encryption (CENC)"
log_info "  Key ID:          $KID"
log_info "  Packager Method: $PACKAGER_METHOD"
log_info "  Framerate:       $FRAMERATE"
log_info "  Segment Time:    ${SEGMENT_DURATION}s"
log_info ""

# Step 2: Start live video capture
log_info "Step 1: Starting live video capture..."
log_info "========================================"

# Run in background so we can continue with packaging
"$SCRIPT_DIR/start-live.sh" &
LIVE_PID=$!

log_success "Live capture started (PID: $LIVE_PID)"
log_info "Waiting for segments to be generated..."
sleep 5

log_info ""

# Step 3: Start continuous DASH packaging
log_info "Step 2: Starting continuous DASH packaging..."
log_info "=============================================="

"$SCRIPT_DIR/package-dash-continuous.sh" &
DASH_PID=$!

log_success "Continuous DASH packaging started (PID: $DASH_PID)"
log_info ""

# # Step 4: Start continuous HLS packaging
# log_info "Step 3: Starting continuous HLS packaging..."
# log_info "=============================================="

# "$SCRIPT_DIR/package-hls-continuous.sh" &
# HLS_PID=$!

# log_success "Continuous HLS packaging started (PID: $HLS_PID)"
# log_info ""

# Summary
log_success "======================================"
log_success "Pipeline Started!"
log_success "======================================"
log_info ""
log_info "📊 Stream Outputs:"
log_info "  DASH Manifest: http://localhost:4000/live/dash/manifest.mpd"
log_info "  HLS Master:    http://localhost:4000/live/hls/master.m3u8"
log_info ""
log_info "🔐 DRM Configuration:"
log_info "  License Server: http://localhost:3000/license?type=clearkey"
log_info "  Key ID:         $KID"
log_info ""
log_info "📺 Open player at: http://localhost:8000"
log_info ""
log_info "🔄 Continuous Process Overview:"
log_info "  Live Capture:     PID $LIVE_PID  - Capturing video from camera"
log_info "  DASH Packaging:   PID $DASH_PID  - Re-packaging segments as they arrive"
log_info "  HLS Packaging:    PID $HLS_PID  - Re-packaging segments as they arrive"
log_info ""
log_info "To stop all processes:"
log_info "  kill $LIVE_PID $DASH_PID $HLS_PID"
log_info ""

# Trap to cleanup on exit
cleanup() {
    log_info "Shutting down pipeline..."
    kill $LIVE_PID 2>/dev/null || true
    kill $DASH_PID 2>/dev/null || true
    kill $HLS_PID 2>/dev/null || true
    log_success "All processes stopped"
}

trap cleanup EXIT INT TERM

# Keep the main script alive - all processes continue in background
log_info "Press Ctrl+C to stop the pipeline"
while true; do
    sleep 60
done
