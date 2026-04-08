#!/bin/bash

# DRM Setup with Clear Key for both HLS and DASH
# Uses ffmpeg for transcoding + shaka-packager for DRM packaging

# Colors for output
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo -e "${BLUE}Starting DRM Transcode & Package Pipeline...${NC}"

# Directories
OUTPUT_DIR="cdn/storage/live"
RAW_DIR="$OUTPUT_DIR/raw"
DASH_DIR="$OUTPUT_DIR/dash"
HLS_DIR="$OUTPUT_DIR/hls"

# Create directories
mkdir -p "$RAW_DIR" "$DASH_DIR" "$HLS_DIR"

# Clear Key values (must match drm-keys.json)
KID="0x0123456789abcdef0123456789abcdef"
KEY="0xabcdefabcdefabcdefabcdefabcdefab"

# Check if shaka-packager exists
if ! command -v packager &> /dev/null; then
    echo -e "${YELLOW}⚠️  shaka-packager not found. Installing...${NC}"
    # Try to find it locally
    if [ -f "./packager-osx" ]; then
        PACKAGER="./packager-osx"
        chmod +x "$PACKAGER"
    elif [ -f "./packager-linux" ]; then
        PACKAGER="./packager-linux"
        chmod +x "$PACKAGER"
    else
        echo -e "${YELLOW}Downloading shaka-packager...${NC}"
        curl -L https://github.com/shaka-project/shaka-packager/releases/download/v3.0.0/packager-osx -o packager-osx 2>/dev/null || \
        curl -L https://github.com/shaka-project/shaka-packager/releases/download/v3.0.0/packager-linux -o packager-linux 2>/dev/null
        chmod +x packager-*
        PACKAGER="./packager-osx"
    fi
else
    PACKAGER="packager"
fi

echo -e "${GREEN}✓ Using packager: $PACKAGER${NC}"

# ===== STEP 1: FFmpeg Transcoding =====
echo -e "${BLUE}Step 1: Starting FFmpeg transcoding...${NC}"

# Kill any existing ffmpeg process
pkill -f "ffmpeg.*avfoundation" 2>/dev/null || true

# FFmpeg: Transcode from camera to multiple bitrates (raw segments)
ffmpeg -f avfoundation -framerate 30 -i "0" \
  -filter_complex "\
    [0:v]split=2[src1][src2]; \
    [src1]scale=256:144,split=2[v1dash][v1hls]; \
    [src2]scale=320:240,split=2[v2dash][v2hls]" \
  \
  -map "[v1dash]" -c:v:0 libx264 -b:v:0 300k \
  -map "[v2dash]" -c:v:1 libx264 -b:v:1 800k \
  \
  -preset veryfast -tune zerolatency \
  -pix_fmt yuv420p \
  -g 60 -keyint_min 60 -sc_threshold 0 \
  \
  -f segment \
  -segment_time 2 \
  -segment_format mpegts \
  -reset_timestamps 1 \
  "$RAW_DIR/segment_%03d.ts" &

FFMPEG_PID=$!
echo -e "${GREEN}✓ FFmpeg running (PID: $FFMPEG_PID)${NC}"
echo -e "${YELLOW}Waiting 5 seconds for ffmpeg to generate initial segments...${NC}"
sleep 5

# ===== STEP 2: Shaka Packager - DASH =====
echo -e "${BLUE}Step 2: Packaging DASH with Clear Key DRM...${NC}"

# Get first two segments
SEGMENT_1="$RAW_DIR/segment_000.ts"
SEGMENT_2="$RAW_DIR/segment_001.ts"

if [ -f "$SEGMENT_1" ] && [ -f "$SEGMENT_2" ]; then
    $PACKAGER \
      "in=$SEGMENT_1,stream=0,output=$DASH_DIR/stream_144p.m4s" \
      "in=$SEGMENT_2,stream=0,output=$DASH_DIR/stream_240p.m4s" \
      \
      --enable_clear_key \
      --keys "key_id=$KID:key=$KEY" \
      \
      --mpd_output "$DASH_DIR/manifest.mpd" \
      --segment_duration 2 \
      --fragment_duration 2
    
    echo -e "${GREEN}✓ DASH packaging complete${NC}"
else
    echo -e "${YELLOW}⚠️  Segments not yet generated, waiting...${NC}"
    sleep 5
fi

# ===== STEP 3: Shaka Packager - HLS =====
echo -e "${BLUE}Step 3: Packaging HLS with Clear Key DRM...${NC}"

if [ -f "$SEGMENT_1" ] && [ -f "$SEGMENT_2" ]; then
    $PACKAGER \
      "in=$SEGMENT_1,stream=0,output=$HLS_DIR/stream_144p.m4s" \
      "in=$SEGMENT_2,stream=0,output=$HLS_DIR/stream_240p.m4s" \
      \
      --enable_clear_key \
      --keys "key_id=$KID:key=$KEY" \
      \
      --hls_master_playlist_output "$HLS_DIR/master.m3u8" \
      --hls_playlist_output "$HLS_DIR/stream.m3u8" \
      --segment_duration 2 \
      --fragment_duration 2
    
    echo -e "${GREEN}✓ HLS packaging complete${NC}"
else
    echo -e "${YELLOW}⚠️  Segments not yet generated${NC}"
fi

echo -e "${GREEN}✓ DRM Transcoding & Packaging Pipeline Running${NC}"
echo -e "${BLUE}Output locations:${NC}"
echo -e "  DASH: ${DASH_DIR}/manifest.mpd"
echo -e "  HLS:  ${HLS_DIR}/master.m3u8"
echo -e "${BLUE}DRM Keys:${NC}"
echo -e "  KID: $KID"
echo -e "  KEY: $KEY"

# Wait for ffmpeg to continue running
wait $FFMPEG_PID
