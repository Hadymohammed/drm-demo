#!/bin/bash
set -e

source "$(dirname "$0")/common.sh"

kill_if_running "$DASH_PID" "packager"

mkdir -p "$DASH_DIR"

echo "🚀 Starting DASH packager..."

  # add to enable DRM encryption (ClearKey in this case)
  # --enable_raw_key_encryption \
  # --keys label=:key_id=$KEY_ID:key=$KEY \
  # --protection_scheme cenc \

  # support different qualities
docker run --rm \
  -p 1234:1234/udp \
  -v "$DOCKER_MOUNT" \
  $DOCKER_IMAGE packager \
  "input=udp://0.0.0.0:1234,stream=video,init_segment=/data/cdn/storage/live/dash/init.mp4,segment_template=/data/cdn/storage/live/dash/chunk_144_\$Number\$.m4s" \
  --clear_lead 0 \
  --segment_duration $SEGMENT_DURATION \
  --time_shift_buffer_depth $BUFFER_DEPTH \
  --mpd_output /data/cdn/storage/live/dash/manifest.mpd &

echo $! > "$DASH_PID"
echo "✅ DASH 144 packager started (PID: $(cat $DASH_PID))"