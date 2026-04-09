#!/bin/bash
set -e

source "$(dirname "$0")/common.sh"

kill_if_running "$ENCODER_PID" "ffmpeg"

echo "🎥 Starting encoder via UDP..."

ffmpeg -f avfoundation -framerate 30 -i "0" \
  -filter_complex "\
    [0:v]split=2[src1][src2]; \
    [src1]scale=256:144[v1out]; \
    [src2]scale=320:240[v2out]" \
  \
  -map "[v1out]" -vcodec libx264 -b:v 300k \
  -preset ultrafast -tune zerolatency \
  -g 30 -keyint_min 30 -sc_threshold 0 \
  -f mpegts "udp://127.0.0.1:1234?pkt_size=1316" \
  \
  -map "[v2out]" -vcodec libx264 -b:v 800k \
  -preset ultrafast -tune zerolatency \
  -g 30 -keyint_min 30 -sc_threshold 0 \
  -f mpegts "udp://127.0.0.1:1235?pkt_size=1316" \

echo $! > "$ENCODER_PID"
echo "✅ Encoder started (PID: $(cat $ENCODER_PID))"
echo "📡 Streaming 144p to udp://127.0.0.1:1234"
echo "📡 Streaming 240p to udp://127.0.0.1:1235"