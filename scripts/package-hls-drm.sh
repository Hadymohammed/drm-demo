#!/bin/bash

# package-hls-drm.sh
# Responsibility: Package HLS with Clear Key DRM using shaka-packager
# Output: Encrypted HLS master playlist, variant playlists, and segments
# Supports: Docker or binary execution

set -e
source "$(dirname "$0")/config.sh"

log_info "Starting HLS packaging with Clear Key DRM..."

ensure_directories

# Get packager command
PACKAGER=$(get_packager)

if [ -z "$PACKAGER" ]; then
    log_error "shaka-packager not found"
    exit 1
    # log_info "Attempting to download..."
    # curl -L https://github.com/shaka-project/shaka-packager/releases/download/v3.0.0/packager-osx \
    #   -o packager-osx 2>/dev/null && chmod +x packager-osx && PACKAGER="./packager-osx" || \
    # curl -L https://github.com/shaka-project/shaka-packager/releases/download/v3.0.0/packager-linux \
    #   -o packager-linux 2>/dev/null && chmod +x packager-linux && PACKAGER="./packager-linux" || \
    # (log_error "Failed to download packager"; exit 1)
fi

log_success "Using packager: $PACKAGER (method: $PACKAGER_METHOD)"

# Get segments
SEGMENT_1="$RAW_DIR/segment_000.ts"
SEGMENT_2="$RAW_DIR/segment_001.ts"

# Wait for segments to exist
if [ ! -f "$SEGMENT_1" ]; then
    log_warning "Waiting for first segment to be generated..."
    for i in {1..30}; do
        if [ -f "$SEGMENT_1" ]; then
            break
        fi
        sleep 1
    done
fi

if [ ! -f "$SEGMENT_1" ]; then
    log_error "First segment not found at: $SEGMENT_1"
    log_info "Make sure start-live.sh is running"
    exit 1
fi

log_info "Found segment: $SEGMENT_1"

# Wait for second segment if available
if [ ! -f "$SEGMENT_2" ]; then
    log_warning "Second segment not ready, waiting..."
    sleep 3
fi

log_info "Running shaka-packager for HLS..."

if [ "$PACKAGER_METHOD" = "docker" ]; then
    # Docker execution with Clear Key DRM
    log_info "Using Docker execution with Clear Key DRM..."
    docker run --rm \
      -v "$(pwd):/data" \
      google/shaka-packager packager \
        "input=/data/$SEGMENT_1,stream=video,output=/data/$HLS_DIR/stream_144p.m4s" \
        "input=/data/$SEGMENT_2,stream=video,output=/data/$HLS_DIR/stream_240p.m4s" \
        \
        --enable_raw_key_encryption \
        --keys "label=:key_id=$KID:key=$KEY" \
        --protection_scheme cbcs \
        --clear_lead 0 \
        \
        --segment_duration "$SEGMENT_DURATION" \
        --hls_master_playlist_output "/data/$HLS_DIR/master.m3u8" \
        --hls_playlist_output "/data/$HLS_DIR/stream.m3u8"
else
    # Binary execution
    # log_info "Using binary execution..."
    # $PACKAGER \
    #   "in=$SEGMENT_1,stream=0,output=$HLS_DIR/stream_144p.m4s" \
    #   "in=$SEGMENT_2,stream=0,output=$HLS_DIR/stream_240p.m4s" \
    #   \
    #   --enable_clear_key \
    #   --keys "key_id=$KID:key=$KEY" \
    #   \
    #   --hls_master_playlist_output "$HLS_DIR/master.m3u8" \
    #   --hls_playlist_output "$HLS_DIR/stream.m3u8" \
    #   --segment_duration "$SEGMENT_DURATION" \
    #   --fragment_duration "$SEGMENT_DURATION"
    log_error "Binary execution not implemented yet"
    exit 1
fi

if [ $? -eq 0 ]; then
    log_success "HLS packaging complete"
    log_info "Master playlist: $HLS_DIR/master.m3u8"
    log_info "Variant playlist: $HLS_DIR/stream.m3u8"
    log_info "Segments: $HLS_DIR/stream_*.m4s"
else
    log_error "HLS packaging failed"
    exit 1
fi
