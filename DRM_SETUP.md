# Shaka Packager DRM Setup Guide

## Overview
To enable DRM with shaka-packager, you'll need:

1. **DRM Provider Keys** (choose one or more)
   - **Widevine** (Google) - Most common, requires Widevine license server
   - **PlayReady** (Microsoft) - Windows/Azure ecosystem
   - **FairPlay** (Apple) - HLS/iOS
   - **Clear Key** - Development/testing only

2. **Key Information Required**
   - Content Encryption Key (CEK)
   - Key ID (KID)
   - License server URLs (for DASH/HLS players)

## Step 1: Generate Encryption Keys

```bash
# Generate a 128-bit content encryption key (hex format, 32 chars)
# For testing, you can use:
# CEK: 0x0123456789abcdef0123456789abcdef
# KID: 0x00000000000000000000000000000001

# Or generate random keys:
openssl rand -hex 16  # For CEK
openssl rand -hex 16  # For KID
```

## Step 2: Install Shaka Packager

```bash
# Download pre-built binary for macOS
curl -O https://github.com/shaka-project/shaka-packager/releases/download/v3.0.0/packager-osx

# Or install via homebrew (if available)
brew install shaka-packager

chmod +x packager-osx
```

## Step 3: Transcode with FFmpeg First (Required)

ffmpeg must produce the video segments first:

```bash
ffmpeg -f avfoundation -framerate 30 -i "0" \
  -c:v libx264 \
  -preset veryfast \
  -tune zerolatency \
  -keyint_min 60 -g 60 -sc_threshold 0 \
  -pix_fmt yuv420p \
  -f segment \
  -segment_time 2 \
  -segment_format mpegts \
  cdn/storage/live/raw/segment_%03d.ts
```

## Step 4: Package with DRM Using Shaka Packager

### Basic DASH + Widevine Example:

```bash
./packager-osx \
  in=cdn/storage/live/raw/segment_000.ts,stream=0,output=cdn/storage/live/dash/stream.m4s \
  in=cdn/storage/live/raw/segment_000.ts,stream=0,output=cdn/storage/live/dash/stream.m4s \
  \
  --enable_widevine_encryption \
  --key_server_url https://license.uat.widevine.com/cenc/cbcs \
  --content_id test_content_id \
  --signer /path/to/signer.pfx \
  --signer_password signer_password \
  --ca_file /path/to/ca.crt \
  \
  --mpd_output=cdn/storage/live/dash/manifest.mpd
```

### Basic HLS + FairPlay Example:

```bash
./packager-osx \
  in=cdn/storage/live/raw/segment_000.ts,stream=0,output=cdn/storage/live/hls/stream.m4s \
  \
  --enable_fairplay_encryption \
  --fairplay_key 0x0123456789abcdef0123456789abcdef \
  --fairplay_key_id 0x00000000000000000000000000000001 \
  \
  --hls_master_playlist_output=cdn/storage/live/hls/master.m3u8 \
  --hls_playlist_output=cdn/storage/live/hls/stream.m3u8
```

### Using Clear Key (Development):

```bash
./packager-osx \
  in=cdn/storage/live/raw/segment_000.ts,stream=0,output=cdn/storage/live/dash/stream.m4s \
  \
  --clear_key \
  --keys key_id=0x00000000000000000000000000000001:key=0x0123456789abcdef0123456789abcdef \
  \
  --mpd_output=cdn/storage/live/dash/manifest.mpd
```

## Step 5: Update Your License Server

Your License Server (`license/license.js`) needs to:

1. **For Widevine**: 
   - Validate client requests
   - Request license from Widevine DRM server
   - Return encrypted license to client

2. **For FairPlay**:
   - Provide the key derivation function (KDF)
   - Return asymmetric-wrapped keys

3. **For Clear Key**:
   - Return key-value pairs (for development only)

Example endpoint:
```javascript
app.post('/license/:drm', async (req, res) => {
  const drmType = req.params.drm; // 'widevine', 'fairplay', 'clearkey'
  
  // Validate request
  // Fetch/store license from DRM provider
  // Return license to client
});
```

## Step 6: Update Your Player (Client Server)

Your player (`index.html`) needs to:

1. Detect DRM requirements from manifest
2. Add `keySystemConfig` for your DRM system
3. Point to your License Server endpoint

Example (DASH.js):
```javascript
const player = dashjs.MediaPlayer().create();
player.updateSettings({
  streaming: {
    bufferTimeDefault: 2,
    bufferTimeMax: 4
  }
});

// Add key system config
const protectionData = {
  'org.w3c.clearkey': {
    licenseUrl: 'https://your-license-server/license/clearkey'
  },
  'com.widevine.alpha': {
    licenseUrl: 'https://your-license-server/license/widevine'
  }
};

player.attachProtectionData(protectionData);
player.attachView(document.getElementById('videoContainer'));
player.attachSource(url);
player.play();
```

## Recommended Approach for Your Setup

1. **Start with Clear Key** (development/testing)
   - No external dependencies
   - Fast setup
   - Good for testing the pipeline

2. **Then add Widevine** (production)
   - Most widely supported
   - Requires license server setup
   - Google account and certificate

3. **Optional: Add FairPlay** (for iOS/macOS)
   - Requires Apple developer account
   - More complex setup
   - Good for Apple ecosystem

## Key Configuration Files Needed

```
license/
├── license.js           # License server (needs DRM endpoints)
├── keys.json           # Store your CEK/KID (for Clear Key)
└── certificates/       # DRM certificates
    ├── widevine/
    ├── fairplay/
    └── clearkey/

cdn/
├── cdn.js              # CDN server (unchanged)
└── storage/
    └── live/
        ├── raw/        # Raw ffmpeg output
        ├── dash/       # Encrypted DASH output
        └── hls/        # Encrypted HLS output
```

## Next Steps

1. Choose your DRM approach (Clear Key for testing → Widevine for production)
2. Install shaka-packager
3. Create DRM key management
4. Update License Server with DRM endpoints
5. Configure player with key system configs
6. Test end-to-end flow

Would you like me to help implement any of these steps?
