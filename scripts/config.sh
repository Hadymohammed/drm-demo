#!/bin/bash

# Configuration file - shared by all scripts
# Set your directories and DRM keys here

# Directories
export OUTPUT_DIR="cdn/storage/live"
export RAW_DIR="$OUTPUT_DIR/raw"
export DASH_DIR="$OUTPUT_DIR/dash"
export HLS_DIR="$OUTPUT_DIR/hls"

# Clear Key DRM values (must match drm-keys.json)
# Note: Without 0x prefix for packager
export KID="0123456789abcdef0123456789abcdef"
export KEY="abcdefabcdefabcdefabcdefabcdefab"
# With 0x prefix (for reference)
export KID_HEX="0x0123456789abcdef0123456789abcdef"
export KEY_HEX="0xabcdefabcdefabcdefabcdefabcdefab"

# Transcoding settings
export FRAMERATE="30"
export SEGMENT_DURATION="2"
export VIDEO_PRESET="veryfast"
export TUNE="zerolatency"

# Colors for output
export GREEN='\033[0;32m'
export BLUE='\033[0;34m'
export YELLOW='\033[1;33m'
export RED='\033[0;31m'
export NC='\033[0m' # No Color

# Packager execution method: 'docker' or 'binary'
export PACKAGER_METHOD="${PACKAGER_METHOD:-docker}"

# Helper function: Get packager command
get_packager() {
    if [ "$PACKAGER_METHOD" = "docker" ]; then
        # Check if Docker is available
        if command -v docker &> /dev/null; then
            echo "docker"
        else
            log_warning "Docker not available, falling back to binary"
            PACKAGER_METHOD="binary"
            get_packager_binary
        fi
    else
        get_packager_binary
    fi
}

# Helper function: Find or download shaka-packager binary
get_packager_binary() {
    if command -v packager &> /dev/null; then
        echo "packager"
    elif [ -f "./packager-osx" ]; then
        echo "./packager-osx"
    elif [ -f "./packager-linux" ]; then
        echo "./packager-linux"
    else
        echo ""
    fi
}

# Helper function: Ensure directories exist
ensure_directories() {
    mkdir -p "$RAW_DIR" "$DASH_DIR" "$HLS_DIR"
}

# Helper function: Log message
log_info() {
    echo -e "${BLUE}ℹ️  $1${NC}"
}

log_success() {
    echo -e "${GREEN}✓ $1${NC}"
}

log_warning() {
    echo -e "${YELLOW}⚠️  $1${NC}"
}

log_error() {
    echo -e "${RED}✗ $1${NC}"
}
