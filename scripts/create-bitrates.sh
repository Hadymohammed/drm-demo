#!/bin/bash

# create-bitrates.sh
# Responsibility: Create multiple bitrate versions from raw video
# This script transcodes raw segments into different bitrates

set -e
source "$(dirname "$0")/config.sh"

log_info "Creating multiple bitrate versions..."

ensure_directories

# Create directory for different bitrates
BITRATE_DIR="$OUTPUT_DIR/bitrates"
mkdir -p "$BITRATE_DIR/144p" "$BITRATE_DIR/240p" "$BITRATE_DIR/360p"

# Bitrate definitions
declare -A BITRATES=(
    ["144p"]="256:144:300k"
    ["240p"]="320:240:800k"
    ["360p"]="480:360:1500k"
)

# Get first raw segment
RAW_SEGMENT="$RAW_DIR/segment_000.ts"

if [ ! -f "$RAW_SEGMENT" ]; then
    log_error "No raw segment found at $RAW_SEGMENT"
    log_info "Please ensure start-live.sh is running first"
    exit 1
fi

log_info "Processing: $RAW_SEGMENT"

# Create transcode for each bitrate
for quality in 144p 240p 360p; do
    IFS=':' read -r width height bitrate <<< "${BITRATES[$quality]}"
    output_file="$BITRATE_DIR/$quality/segment_%03d.ts"
    
    log_info "Creating $quality version (${width}x${height}, $bitrate)..."
    
    mkdir -p "$BITRATE_DIR/$quality"
    
    ffmpeg -i "$RAW_SEGMENT" \
      -vf "scale=${width}:${height}" \
      -c:v libx264 \
      -b:v "$bitrate" \
      -preset "$VIDEO_PRESET" \
      -tune "$TUNE" \
      -pix_fmt yuv420p \
      -g 60 -keyint_min 60 -sc_threshold 0 \
      -f segment \
      -segment_time "$SEGMENT_DURATION" \
      -segment_format mpegts \
      "$output_file" \
      2>&1 | grep -E "frame=|muxing|error" || true
    
    log_success "$quality version created"
done

log_success "All bitrate versions created in: $BITRATE_DIR"
