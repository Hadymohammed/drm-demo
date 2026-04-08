#!/bin/bash

# package-dash-continuous.sh
# Continuously packages DASH segments with Clear Key DRM
# Watches for new segments and re-packages them
# This enables live streaming with growing duration

set -e
source "$(dirname "$0")/config.sh"

log_info "Starting continuous DASH packaging with Clear Key DRM..."

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

# Function to create live DASH manifest wrapper
create_live_manifest() {
    local manifest_file="$1"
    local segment_count="$2"
    
    # Get current time in ISO 8601 format
    local current_time=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
    
    # Create live manifest with dynamic type
    cat > "$manifest_file" << 'EOF'
<?xml version="1.0" encoding="UTF-8"?>
<MPD xmlns="urn:mpeg:dash:schema:mpd:2011"
     xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance"
     xsi:schemaLocation="urn:mpeg:dash:schema:mpd:2011 DASH-MPD.xsd"
     type="dynamic"
     mediaPresentationDuration="PT0S"
     minBufferTime="PT2S"
     publishTime="PUBLISH_TIME_PLACEHOLDER">
  <Period id="0" start="PT0S">
    <AdaptationSet id="0" contentType="video" segmentAlignment="true" bitstreamSwitching="true">
      <ContentProtection schemeIdUri="urn:uuid:e2719d58-a985-b3c9-781a-b30760f1d58d" cenc:default_KID="KIDS_HEX">
        <cenc:pssh>PSSH_PLACEHOLDER</cenc:pssh>
      </ContentProtection>
      <Representation id="0" bandwidth="1000000" codecs="avc1.4d401e" width="640" height="480" frameRate="30">
        <BaseURL>./</BaseURL>
        <SegmentList>
SEGMENT_LIST_PLACEHOLDER
        </SegmentList>
      </Representation>
    </AdaptationSet>
  </Period>
</MPD>
EOF
}

# Function to update live manifest with new segments
update_live_manifest() {
    local manifest_file="$1"
    local segment_count="$2"
    
    local current_time=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
    
    # Generate segment list
    local segment_list=""
    for i in $(seq 0 $((segment_count - 1))); do
        local duration=$((SEGMENT_DURATION * 1000))  # Convert to milliseconds
        segment_list="$segment_list        <SegmentURL media=\"segment_$(printf "%03d" $i).m4s\" duration=\"$duration\"/>\n"
    done
    
    # Update manifest with dynamic type and live attributes
    local temp_manifest=$(mktemp)
    
    cat > "$temp_manifest" << EOF
<?xml version="1.0" encoding="UTF-8"?>
<MPD xmlns="urn:mpeg:dash:schema:mpd:2011"
     xmlns:cenc="urn:mpeg:cenc:2013"
     xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance"
     type="dynamic"
     mediaPresentationDuration="PT0S"
     minBufferTime="PT2S"
     timeShiftBufferDepth="PT60S"
     publishTime="$current_time">
  <Period id="0" start="PT0S">
    <AdaptationSet id="0" contentType="video" segmentAlignment="true">
      <ContentProtection schemeIdUri="urn:uuid:e2719d58-a985-b3c9-781a-b30760f1d58d">
      </ContentProtection>
      <Representation id="0" bandwidth="800000" codecs="avc1.42401e" width="320" height="180" frameRate="30">
        <BaseURL>./</BaseURL>
        <SegmentList timescale="1000">
$(echo -e "$segment_list")
        </SegmentList>
      </Representation>
    </AdaptationSet>
  </Period>
</MPD>
EOF

    mv "$temp_manifest" "$manifest_file"
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
    
    log_info "Packaging ${#segments[@]} segments (${SEGMENT_DURATION}s each = $((${#segments[@]} * SEGMENT_DURATION))s total)..."
    
    # Create temp file for concatenated segments
    local temp_input="$DASH_DIR/.temp_input.ts"
    cat "${segments[@]}" > "$temp_input"
    
    # Pipe concatenated segments directly to packager
    if [ "$PACKAGER_METHOD" = "docker" ]; then
        # Docker execution - package temp file
        docker run --rm \
          -v "$(pwd):/work" \
          -w /work \
          google/shaka-packager packager \
            "input=/work/$temp_input,stream=video,output=/work/$DASH_DIR/stream.m4s" \
            \
            --enable_raw_key_encryption \
            --keys "label=:key_id=$KID:key=$KEY" \
            --protection_scheme cbcs \
            --clear_lead 0 \
            \
            --segment_duration "$SEGMENT_DURATION" \
            --mpd_output "/work/$DASH_DIR/manifest.mpd"
        
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
log_success "Continuous packaging started. Monitoring for new segments..."

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
