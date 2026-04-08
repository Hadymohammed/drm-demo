# Packager Methods: Docker vs Binary

## Overview

The scripts support two methods for running shaka-packager:

1. **Docker** (Recommended) - Uses `google/shaka-packager` container
2. **Binary** - Uses local packager executable

## Docker Method

### Setup

```bash
# Just need Docker installed
docker --version

# Pull the image (optional - auto-pulled on first run)
docker pull google/shaka-packager
```

### Usage

```bash
# Use Docker method
export PACKAGER_METHOD=docker
./scripts/start-pipeline.sh
```

### Advantages
✅ No installation needed (Docker handles everything)
✅ Consistent behavior across platforms
✅ Isolated environment
✅ Easy version management
✅ Official Google image

### Disadvantages
❌ Requires Docker to be installed and running
❌ Slightly slower (container startup overhead)
❌ More verbose output

### Example Output
```
Configuration:
  Packager Method: docker

Step 2: Packaging DASH with Clear Key DRM...
✓ Using packager: docker (method: docker)
Using Docker execution...
```

## Binary Method

### Setup

**Option A: Download Binary**
```bash
# Download (auto-downloads if not found)
curl -O https://github.com/shaka-project/shaka-packager/releases/download/v3.0.0/packager-osx
chmod +x packager-osx
```

**Option B: Install via Package Manager**
```bash
# macOS
brew install shaka-packager

# Linux (Ubuntu/Debian)
sudo apt-get install shaka-packager
```

**Option C: Build from Source**
```bash
git clone https://github.com/shaka-project/shaka-packager.git
cd shaka-packager
./configure
make
```

### Usage

```bash
# Use binary method (default if Docker unavailable)
export PACKAGER_METHOD=binary
./scripts/start-pipeline.sh

# Or rely on auto-detection
./scripts/start-pipeline.sh
```

### Advantages
✅ Faster execution (no container overhead)
✅ Direct OS integration
✅ Lower resource usage
✅ Familiar command-line interface

### Disadvantages
❌ Need to install/manage binary
❌ Platform-specific
❌ Version management complexity

### Example Output
```
Configuration:
  Packager Method: binary

Step 2: Packaging DASH with Clear Key DRM...
✓ Using packager: ./packager-osx (method: binary)
Using binary execution...
```

## Comparison

| Aspect | Docker | Binary |
|--------|--------|--------|
| Setup | One-time: install Docker | Download/install packager |
| Speed | Slower (container overhead) | Faster |
| Complexity | Simple | More complex |
| Platform | Works everywhere | Platform-specific |
| Resource Use | More (container) | Less |
| Isolation | Yes | No |
| Version Mgmt | Easy | Manual |

## Configuration

### Default Method
Currently defaults to `docker` if available, falls back to `binary`.

### Override in config.sh
```bash
# Force Docker
export PACKAGER_METHOD=docker

# Force Binary
export PACKAGER_METHOD=binary
```

### Override at Runtime
```bash
# Use Docker
PACKAGER_METHOD=docker ./scripts/start-pipeline.sh

# Use Binary
PACKAGER_METHOD=binary ./scripts/start-pipeline.sh
```

## DRM Parameters Differences

### Docker Command (using raw key encryption)
```bash
docker run --rm -v $(pwd):/data google/shaka-packager packager \
  input=/data/segment.ts,stream=video,output=/data/segment.m4s \
  --enable_raw_key_encryption \
  --keys "label=:key_id=<KID>:key=<KEY>" \
  --protection_scheme cenc \
  --clear_lead 0 \
  --segment_duration 2 \
  --mpd_output /data/manifest.mpd
```

### Binary Command (using clear key encryption)
```bash
./packager-osx \
  "in=segment.ts,stream=0,output=segment.m4s" \
  --enable_clear_key \
  --keys "key_id=<KID>:key=<KEY>" \
  --mpd_output manifest.mpd \
  --segment_duration 2
```

**Key Differences:**
- Docker: `--enable_raw_key_encryption` + `--protection_scheme cenc`
- Binary: `--enable_clear_key`
- Docker: `input=` and `stream=video`
- Binary: `in=` and `stream=0`
- Docker: requires `/data` volume mount
- Binary: direct file paths

The scripts handle these differences automatically!

## Troubleshooting

### "Docker: command not found"
```bash
# Install Docker Desktop
# macOS: https://docs.docker.com/desktop/install/mac-install/
# Linux: https://docs.docker.com/engine/install/

# Or use binary method
export PACKAGER_METHOD=binary
```

### "Docker daemon not running"
```bash
# Start Docker daemon
# macOS: Open Docker Desktop application
# Linux: sudo systemctl start docker
```

### "Cannot connect to Docker daemon"
```bash
# Check permissions (Linux)
sudo usermod -aG docker $USER
newgrp docker

# Or run with sudo
sudo PACKAGER_METHOD=docker ./scripts/start-pipeline.sh
```

### "packager-osx: command not found"
```bash
# Make sure binary is executable
chmod +x ./packager-osx

# Or download it
curl -O https://github.com/shaka-project/shaka-packager/releases/download/v3.0.0/packager-osx
chmod +x packager-osx
```

### "image google/shaka-packager:latest not found"
```bash
# Pull the image
docker pull google/shaka-packager

# Or let Docker pull automatically on first use
```

## Performance Comparison

Typical execution times (for one segment pair):

| Task | Docker | Binary |
|------|--------|--------|
| DASH Packaging | ~5-8s | ~2-3s |
| HLS Packaging | ~5-8s | ~2-3s |
| Container startup | ~1-2s | N/A |

## Recommendation

- **Development**: Use **Docker** for consistency and ease
- **Production**: Use **Binary** for performance
- **CI/CD**: Use **Docker** for portability

## Advanced: Custom Docker Image

If you want to build a custom image with additional tools:

```dockerfile
FROM google/shaka-packager:latest

RUN apt-get update && apt-get install -y \
    ffmpeg \
    curl \
    && rm -rf /var/lib/apt/lists/*

ENTRYPOINT ["packager"]
```

Build and use:
```bash
docker build -t my-shaka-packager .
# Update scripts to use: my-shaka-packager instead of google/shaka-packager
```
