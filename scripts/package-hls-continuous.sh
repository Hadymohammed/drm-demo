#!/bin/bash

# package-hls-continuous.sh
# Continuously packages HLS segments with Clear Key DRM
# Watches for new segments and re-packages them
# This enables live streaming with growing duration

set -e
source "$(dirname "$0")/config.sh"

log_info "Starting continuous HLS packaging with Clear Key DRM..."

ensure_directories

# Get packager command
PACKAGER=$(get_packager)

if [ -z "$PACKAGER" ]; then
    log_error "shaka-packager not found"
    exit 1
fi

log_success "Using packager: $PACKAGER (method: $PACKAGER_METHOD)"

# Track the last packaged segment number
LAST_PACKAGED=0
PACKAGE_COUNT=0

# Function to update live HLS playlists
update_live_playlists() {
    local segment_count="$1"
    
    local current_time=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
    
    # Generate segment list
    local segment_list=""
    for i in $(seq 0 $((segment_count - 1))); do
        segment_list="${segment_list}#EXTINF:${SEGMENT_DURATION}.0,\nsegment_$(printf "%03d" $i).m4s\n"
    done
    
    # Create master playlist (live version)
    cat > "$HLS_DIR/master.m3u8" << EOF
#EXTM3U
#EXT-X-VERSION:3
#EXT-X-TARGETDURATION:$SEGMENT_DURATION
#EXT-X-MEDIA-SEQUENCE:0
#EXT-X-PLAYLIST-TYPE:EVENT
#EXTINF:${SEGMENT_DURATION}.0,
stream.m3u8
EOF

    # Create stream playlist (live version with all segments)
    cat > "$HLS_DIR/stream.m3u8" << EOF
#EXTM3U
#EXT-X-VERSION:3
#EXT-X-TARGETDURATION:$SEGMENT_DURATION
#EXT-X-MEDIA-SEQUENCE:0
$(echo -e "$segment_list")#EXT-X-ENDLIST
EOF
}

# Function to package segments by piping to packager
package_segments() {
    segment_count=$1
    
    if [ "$segment_count" -lt 2 ]; then
        return
    fi
    
    # Get segment files in order
    segments=()
    for i in $(seq 0 $((segment_count - 1))); do
        seg=$(printf "%s/segment_%03d.ts" "$RAW_DIR" "$i")
        if [ -f "$seg" ]; then
            segments+=("$seg")
        fi
    done
    
    if [ ${#segments[@]} -lt 2 ]; then
        return
    fi
    
    log_info "Packaging ${#segments[@]} segments for HLS (${SEGMENT_DURATION}s each = $((${#segments[@]} * SEGMENT_DURATION))s total)..."
    
    # Create temp file for concatenated segments
    local temp_input="$HLS_DIR/.temp_input.ts"
    cat "${segments[@]}" > "$temp_input"
    
    # Pipe concatenated segments directly to packager
    if [ "$PACKAGER_METHOD" = "docker" ]; then
        # Docker execution - package temp file
        docker run --rm \
          -v "$(pwd):/work" \
          -w /work \
          google/shaka-packager packager \
            "input=/work/$temp_input,stream=video,output=/work/$HLS_DIR/stream.m4s" \
            \
            --enable_raw_key_encryption \
            --keys "label=:key_id=$KID:key=$KEY" \
            --protection_scheme cbcs \
            --clear_lead 0 \
            \
            --hls_master_playlist_output "/work/$HLS_DIR/master.m3u8" \
            --hls_playlist_output "/work/$HLS_DIR/stream.m3u8"
        
        rm -f "$temp_input"
    else
        log_error "Binary execution not implemented"
        return 1
    fi
    
    LAST_PACKAGED=$segment_count
    ((PACKAGE_COUNT++))
}

# Function to get all available segments
get_available_segments() {
    ls "$RAW_DIR"/segment_*.ts 2>/dev/null | wc -l
}

# Wait for initial segments
log_info "Waiting for initial segments..."
for i in {1..60}; do
    count=$(get_available_segments)
    if [ "$count" -ge 2 ]; then
        log_success "Found $count segments"
        break
    fi
    sleep 1
done

# Initial packaging
log_info "Performing initial packaging..."
package_segments $(get_available_segments)

# Continuous monitoring loop
log_success "Continuous HLS packaging started. Monitoring for new segments..."

ITERATIONS=0
UNCHANGED_COUNT=0

while true; do
    sleep 2  # Check every 2 seconds
    
    current_count=$(get_available_segments)
    
    if [ "$current_count" -gt "$LAST_PACKAGED" ]; then
        log_info "New segments detected: $LAST_PACKAGED → $current_count"
        package_segments "$current_count"
        UNCHANGED_COUNT=0
    else
        ((UNCHANGED_COUNT++))
        if [ $((UNCHANGED_COUNT % 15)) -eq 0 ]; then
            log_info "Watching... $current_count segments, $(($current_count * SEGMENT_DURATION))s total duration"
        fi
    fi
    
    ((ITERATIONS++))
    if [ $((ITERATIONS % 30)) -eq 0 ]; then
        log_info "Status: $current_count segments packaged ($PACKAGE_COUNT times), $(($current_count * SEGMENT_DURATION))s total"
    fi
done
