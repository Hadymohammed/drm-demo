# Clear Key DRM Setup Guide

## Overview
This setup uses **Clear Key**, a simple DRM system suitable for development and testing. It provides:
- Content encryption with 128-bit AES keys
- License distribution through HTTP
- Support for both DASH and HLS
- No external DRM server dependencies

## Architecture

```
Mac Camera
    ↓
FFmpeg (Transcode)
    ↓
Raw Segments (.ts files)
    ↓
Shaka Packager (with Clear Key DRM)
    ↓
Encrypted Media
    ├── DASH (manifest.mpd)
    └── HLS (master.m3u8)
    ↓
CDN Server (port 4000)
    ↓
Player (index-drm.html)
    ├─→ License Server (port 3000)
    └─→ Gets decryption keys
```

## Files Created

### 1. **drm-keys.json** - Key Management
Contains your Clear Key encryption keys:
```json
{
  "defaultKey": {
    "kid": "0123456789abcdef0123456789abcdef",
    "key": "abcdefabcdefabcdefabcdefabcdefab"
  }
}
```
- `kid`: Key ID (32 hex characters = 128 bits)
- `key`: Encryption key (32 hex characters = 128 bits)

### 2. **startTranscodePackageDRM.sh** - Pipeline Script
Automated pipeline that:
1. Captures video from Mac camera with ffmpeg
2. Transcodes to multiple bitrates (144p, 240p)
3. Packages with shaka-packager using Clear Key DRM
4. Outputs encrypted DASH and HLS streams

Run it with:
```bash
chmod +x startTranscodePackageDRM.sh
./startTranscodePackageDRM.sh
```

### 3. **license/license-drm.js** - License Server
HTTP server that:
- Listens on port 3000
- Handles license requests at `/license/clearkey`
- Returns decryption keys in IETF JSON format
- Provides DRM configuration endpoint

Start it with:
```bash
cd license
node license-drm.js
```

### 4. **index-drm.html** - DRM-Enabled Player
Web player with:
- Shaka Player (DASH/HLS support)
- Clear Key DRM integration
- Stream quality selector
- Real-time stats (bitrate, resolution)
- Go Live functionality

## Setup Steps

### Step 1: Install Shaka Packager

```bash
# Option A: Download (recommended)
curl -O https://github.com/shaka-project/shaka-packager/releases/download/v3.0.0/packager-osx
chmod +x packager-osx

# Option B: Homebrew (if available)
brew install shaka-packager
```

### Step 2: Start the License Server

```bash
cd license
npm install express  # If not already installed
node license-drm.js
```

Expected output:
```
==================================================
🔐 DRM License Server running on port 3000
==================================================

📋 Endpoints:
  POST /license/clearkey  - Clear Key license endpoint
  POST /license/widevine  - Widevine license endpoint
  POST /license/fairplay  - FairPlay license endpoint
  GET  /drm/config        - DRM configuration
  GET  /health            - Health check

🔑 Current configuration:
  Default KID: 0x0123456789abcdef0123456789abcdef
  Default KEY: 0xabcdefabcdefabcdefabcdefabcdefab
==================================================
```

### Step 3: Start the Transcoding Pipeline

```bash
chmod +x startTranscodePackageDRM.sh
./startTranscodePackageDRM.sh
```

Expected output:
```
Starting DRM Transcode & Package Pipeline...
✓ Using packager: ./packager-osx
Step 1: Starting FFmpeg transcoding...
✓ FFmpeg running (PID: 12345)
Step 2: Packaging DASH with Clear Key DRM...
✓ DASH packaging complete
Step 3: Packaging HLS with Clear Key DRM...
✓ HLS packaging complete
```

### Step 4: Start the CDN Server

```bash
# In another terminal
cd cdn
npm install express cors  # If not already installed
node cdn.js
```

### Step 5: Open the Player

Open your browser to: `http://localhost:8000/index-drm.html`

Or use the client server if it's running:
```bash
npm install express
node -e "
const express = require('express');
const app = express();
app.use(express.static('.'));
app.listen(8000, () => console.log('📺 Player available at http://localhost:8000'));
"
```

## How Clear Key Works

### 1. **Encryption (During Packaging)**
```
Original Video
    ↓
Shaka Packager applies AES-128 encryption
    ↓
Encrypted Video Segments + Encrypted Init Segment
```

### 2. **License Request (In Player)**
```
Browser loads manifest → finds Clear Key DRM info
    ↓
Player extracts KID from manifest
    ↓
Player creates license request with KID
    ↓
License request sent to server
```

### 3. **License Response (From Server)**
```
Server receives request with KID
    ↓
Server looks up encryption key for this KID
    ↓
Server returns JSON with decryption key:
{
  "keys": [{
    "kty": "oct",
    "kid": "base64url_encoded_kid",
    "k": "base64url_encoded_key"
  }]
}
```

### 4. **Playback (In Browser)**
```
Player receives license with key
    ↓
Player extracts decryption key
    ↓
Player decrypts each media segment on-the-fly
    ↓
Decrypted video displayed in <video> element
```

## Key Files Generated

```
cdn/storage/live/
├── raw/                    # Raw ffmpeg output
│   ├── segment_000.ts
│   ├── segment_001.ts
│   └── ...
├── dash/
│   ├── manifest.mpd        # DASH manifest (encrypted)
│   ├── stream_144p.m4s     # Video segment (encrypted)
│   ├── stream_240p.m4s     # Video segment (encrypted)
│   └── init.mp4            # Initialization segment
└── hls/
    ├── master.m3u8         # HLS master playlist
    ├── stream.m3u8         # HLS variant playlist
    ├── stream_144p.m4s     # Video segment (encrypted)
    └── stream_240p.m4s     # Video segment (encrypted)
```

## Testing

### 1. Check License Server Health
```bash
curl http://localhost:3000/health
```

Expected response:
```json
{
  "status": "ok",
  "drmKeysLoaded": true,
  "supportedDRMs": ["clearkey", "widevine", "fairplay"]
}
```

### 2. Test License Request
```bash
curl -X POST http://localhost:3000/license/clearkey \
  -H "Content-Type: application/json" \
  -d '{"kids": ["0123456789abcdef0123456789abcdef"]}'
```

Expected response includes keys in IETF format.

### 3. Check Stream URLs
- DASH: `http://localhost:4000/live/manifest.mpd`
- HLS: `http://localhost:4000/live/master.m3u8`

### 4. Test in Player
1. Open `http://localhost:8000/index-drm.html`
2. Click "Load Stream"
3. Select DASH or HLS from dropdown
4. Player should load and play with DRM protection

## Troubleshooting

### "Clear Key not supported" in browser
- Clear Key DRM support varies by browser
- Chrome, Edge, Firefox: Full support
- Safari: HLS with FairPlay only

### "License request failed"
- Check license server is running: `curl http://localhost:3000/health`
- Check KID matches in drm-keys.json
- Check CORS headers are enabled

### "Missing init segment"
- Shaka packager must generate init.mp4
- Check in `dash/` and `hls/` directories
- Re-run packaging script

### "Playback stalls"
- Check CDN server is running on port 4000
- Check segments exist in storage directory
- Check bandwidth availability

## Security Notes ⚠️

**Clear Key is for development only.** For production:

1. **Rotate Keys**: Change keys in drm-keys.json regularly
2. **Use Widevine**: For commercial content, use Google's Widevine DRM
3. **HTTPS Only**: Always use HTTPS in production
4. **License Validation**: Implement proper license validation in server
5. **Key Storage**: Store keys securely (not in git, use env vars)
6. **Rate Limiting**: Add rate limiting to license endpoint

## Next Steps

After verifying Clear Key works:

1. **Scale to Production**
   - Use Widevine for commercial content
   - Implement proper key management
   - Add rate limiting and analytics

2. **Multi-Protocol**
   - Add FairPlay for iOS/macOS
   - Add PlayReady for Windows

3. **Advanced Features**
   - Implement ABR (Adaptive Bitrate) optimization
   - Add offline playback
   - Track licensing metrics

## Resources

- [Shaka Packager Docs](https://shaka-project.github.io/shaka-packager/)
- [IETF Clear Key Spec](https://w3c.github.io/encrypted-media/#clear-key)
- [Shaka Player DRM Guide](https://shaka-project.github.io/shaka-player/tutorial/drm.html)
- [DASH Specification](https://dashif.org/technical/specifications/)
- [HLS Specification](https://datatracker.ietf.org/doc/html/draft-pantos-hls-rfc8216)
