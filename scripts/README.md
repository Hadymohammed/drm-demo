# DRM Pipeline Scripts

Modular bash scripts for DRM transcoding and packaging with Clear Key encryption.

## Architecture

```
start-pipeline.sh (Main Entry Point)
    ↓
    ├─→ start-live.sh (Live capture from camera)
    │       └─→ FFmpeg output: raw segments
    │
    ├─→ package-dash-drm.sh (DASH packaging with DRM)
    │       └─→ Shaka Packager: encrypted DASH manifest
    │
    └─→ package-hls-drm.sh (HLS packaging with DRM)
            └─→ Shaka Packager: encrypted HLS playlist
```

## Scripts

### 1. **config.sh** (Shared Configuration)
Contains all configuration variables and helper functions used by other scripts.

**Responsibilities:**
- Define output directories
- Store DRM keys (KID, KEY)
- Set transcoding parameters
- Provide logging functions
- Utility functions for finding packager

**Variables:**
```bash
OUTPUT_DIR="cdn/storage/live"
RAW_DIR="$OUTPUT_DIR/raw"
DASH_DIR="$OUTPUT_DIR/dash"
HLS_DIR="$OUTPUT_DIR/hls"
KID="0x0123456789abcdef0123456789abcdef"
KEY="0xabcdefabcdefabcdefabcdefabcdefab"
```

**Usage:**
```bash
source config.sh
log_info "Your message"
log_success "Success message"
log_warning "Warning message"
log_error "Error message"
```

### 2. **start-live.sh** (Live Video Capture)
Captures live video from Mac camera and outputs raw segments.

**Responsibility:**
- Start FFmpeg video capture
- Generate raw video segments (.ts files)
- Output to `RAW_DIR`

**Process:**
1. Kill any existing FFmpeg process
2. Start FFmpeg capturing from Mac camera (`avfoundation`)
3. Output raw MPEG-TS segments
4. Run continuously in background

**Usage:**
```bash
./start-live.sh
```

**Output:**
- `cdn/storage/live/raw/segment_000.ts`
- `cdn/storage/live/raw/segment_001.ts`
- ... (continuous)

### 3. **create-bitrates.sh** (Multi-bitrate Transcoding)
Creates multiple bitrate versions from raw segments.

**Responsibility:**
- Transcode raw segments to different resolutions
- Generate separate directories for each quality level
- Support 144p, 240p, 360p variants

**Bitrates:**
```
144p: 256x144 @ 300k
240p: 320x240 @ 800k
360p: 480x360 @ 1500k
```

**Usage:**
```bash
./create-bitrates.sh
```

**Output:**
```
cdn/storage/live/bitrates/
├── 144p/segment_000.ts
├── 240p/segment_000.ts
└── 360p/segment_000.ts
```

**Note:** Currently creates from first segment only. Can be enhanced for continuous processing.

### 4. **package-dash-drm.sh** (DASH with DRM)
Packages segments into DASH format with Clear Key DRM encryption.

**Responsibility:**
- Run Shaka Packager for DASH output
- Apply Clear Key encryption
- Generate MPEG-DASH manifest (MPD)
- Create encrypted video segments

**Process:**
1. Locate shaka-packager executable
2. Wait for raw segments to exist
3. Run packager with DRM settings:
   - `--enable_clear_key` - Enable Clear Key DRM
   - `--keys "key_id=KID:key=KEY"` - Set encryption keys
   - `--mpd_output` - Output manifest location
4. Generate encrypted segments

**Usage:**
```bash
./package-dash-drm.sh
```

**Output:**
- `cdn/storage/live/dash/manifest.mpd` - DASH manifest
- `cdn/storage/live/dash/stream_144p.m4s` - Encrypted video
- `cdn/storage/live/dash/stream_240p.m4s` - Encrypted video
- `cdn/storage/live/dash/init.mp4` - Initialization segment

**DRM Details:**
```
Encryption: AES-128-CTR (Clear Key standard)
Key ID:     0x0123456789abcdef0123456789abcdef
Key:        0xabcdefabcdefabcdefabcdefabcdefab
License URL: http://localhost:3000/license/clearkey
```

### 5. **package-hls-drm.sh** (HLS with DRM)
Packages segments into HLS format with Clear Key DRM encryption.

**Responsibility:**
- Run Shaka Packager for HLS output
- Apply Clear Key encryption
- Generate HLS master and variant playlists
- Create encrypted video segments

**Process:**
1. Locate shaka-packager executable
2. Wait for raw segments to exist
3. Run packager with DRM settings:
   - `--enable_clear_key` - Enable Clear Key DRM
   - `--keys "key_id=KID:key=KEY"` - Set encryption keys
   - `--hls_master_playlist_output` - Master playlist location
   - `--hls_playlist_output` - Variant playlist location
4. Generate encrypted segments

**Usage:**
```bash
./package-hls-drm.sh
```

**Output:**
- `cdn/storage/live/hls/master.m3u8` - HLS master playlist
- `cdn/storage/live/hls/stream.m3u8` - HLS variant playlist
- `cdn/storage/live/hls/stream_144p.m4s` - Encrypted video
- `cdn/storage/live/hls/stream_240p.m4s` - Encrypted video

**HLS Details:**
```
Format: HTTP Live Streaming
Encryption: AES-128 (via IETF JSON keys)
Segment Duration: 2 seconds
Master playlist includes variant options
```

### 6. **start-pipeline.sh** (Main Entry Point)
Orchestrates all scripts and runs the complete pipeline.

**Responsibility:**
- Coordinate all pipeline steps
- Run scripts in correct order
- Manage background processes
- Display progress and summary

**Process:**
1. Display configuration
2. Start live video capture (`start-live.sh`)
3. Wait for initial segments
4. Package DASH (`package-dash-drm.sh`)
5. Package HLS (`package-hls-drm.sh`)
6. Display summary
7. Keep live capture running

**Usage:**
```bash
./start-pipeline.sh
```

**Example Output:**
```
======================================
DRM Transcode & Package Pipeline
======================================

Configuration:
  Output Dir:      cdn/storage/live
  Raw Segments:    cdn/storage/live/raw
  DASH Output:     cdn/storage/live/dash
  HLS Output:      cdn/storage/live/hls
  DRM Key ID:      0x0123456789abcdef0123456789abcdef
  Framerate:       30
  Segment Time:    2s

Step 1: Starting live video capture...
========================================
✓ Live capture started (PID: 12345)
Waiting for segments to be generated...

Step 2: Packaging DASH with Clear Key DRM...
=============================================
✓ DASH packaging complete

Step 3: Packaging HLS with Clear Key DRM...
===========================================
✓ HLS packaging complete

======================================
✓ Pipeline Complete!
======================================

📊 Stream Outputs:
  DASH Manifest: http://localhost:4000/live/manifest.mpd
  HLS Master:    http://localhost:4000/live/master.m3u8

🔐 DRM Configuration:
  License Server: http://localhost:3000/license/clearkey
  Key ID:         0x0123456789abcdef0123456789abcdef

📺 Open player at: http://localhost:8000/index-drm.html

⏹️  Live capture is running in background (PID: 12345)
To stop: kill 12345
```

## Setup & Usage

### 1. Make scripts executable
```bash
chmod +x scripts/*.sh
```

### 2. Configure (optional)
Edit `scripts/config.sh` to customize:
- Directories
- DRM keys
- Transcoding parameters
- Framerate and segment duration

### 3. Run the pipeline
```bash
./scripts/start-pipeline.sh
```

### 4. In separate terminals, start other services:

**Terminal 1 (License Server):**
```bash
cd license
node license-drm.js
```

**Terminal 2 (CDN Server):**
```bash
cd cdn
node cdn.js
```

**Terminal 3 (Player/Client):**
```bash
# Open browser to http://localhost:8000/index-drm.html
```

## Individual Script Usage

If you want to run scripts separately:

```bash
# Just start live capture
./scripts/start-live.sh

# In another terminal, just package DASH
./scripts/package-dash-drm.sh

# In another terminal, just package HLS
./scripts/package-hls-drm.sh

# Create multiple bitrate versions
./scripts/create-bitrates.sh
```

## Troubleshooting

### "No such file or directory: start-live.sh"
```bash
# Run from project root
cd /Users/Abdelhady/Desktop/Projects/drm-demo
./scripts/start-pipeline.sh
```

### "shaka-packager not found"
- Script will attempt automatic download
- Or manually download from: https://github.com/shaka-project/shaka-packager/releases
- Place `packager-osx` or `packager-linux` in project root

### "FFmpeg not found"
```bash
# Install FFmpeg
brew install ffmpeg
```

### "Segments not generating"
1. Check camera permissions (Mac may need access granted)
2. Verify FFmpeg is running: `ps aux | grep ffmpeg`
3. Check RAW_DIR exists and is writable
4. Try specifying camera device: `-f avfoundation -i "0:none"`

### "License request failed in player"
1. Verify license server is running: `curl http://localhost:3000/health`
2. Check DRM keys in `drm-keys.json` match `config.sh`
3. Check browser console for detailed error

## File Dependencies

```
start-pipeline.sh
├─ config.sh (sourced)
├─ start-live.sh (executed)
│  └─ config.sh (sourced)
├─ package-dash-drm.sh (executed)
│  └─ config.sh (sourced)
└─ package-hls-drm.sh (executed)
   └─ config.sh (sourced)

create-bitrates.sh
└─ config.sh (sourced)
```

## Environment Variables

All configuration is in `config.sh`. No environment variables required.

To override: Edit `config.sh` before running, or:
```bash
export OUTPUT_DIR="/custom/path"
./scripts/start-pipeline.sh
```

## Adding New Scripts

Template for new scripts:

```bash
#!/bin/bash
# script-name.sh
# Responsibility: [What this script does]
# Dependencies: [Other scripts/files needed]

set -e
source "$(dirname "$0")/config.sh"

log_info "Starting..."
# Your code here
log_success "Complete"
```

## Performance Considerations

- **Segment Duration**: 2s (change in `config.sh` for latency/buffering tradeoff)
- **Preset**: `veryfast` (faster encoding, lower quality)
- **Framerate**: 30fps (Mac camera default)
- **Bitrates**: 300k/800k (adjust for your network/quality needs)

## Security Notes ⚠️

**Clear Key is for development only!**

- Keys are visible in config and on-the-wire
- For production: Use Widevine, FairPlay, or PlayReady
- Always use HTTPS in production
- Rotate keys regularly
- Store keys securely (not in git)
