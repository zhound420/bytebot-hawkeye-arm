#!/bin/bash
# =============================================================================
# Download Tiny11 ISO for OmniBox Windows Environment
# =============================================================================
# Downloads and caches Tiny11 2311 ISO (~3GB) to avoid repeated downloads
# during fresh builds. ISO is stored in user's cache directory.
#
# Usage: ./scripts/download-windows-iso.sh

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
CACHE_DIR="$HOME/.cache/bytebot/iso"
ISO_NAME="tiny11-2311.iso"
ISO_PATH="$CACHE_DIR/$ISO_NAME"
DOWNLOAD_URL="https://archive.org/download/tiny11-2311/tiny11%202311%20x64.iso"
EXPECTED_SIZE_MB=3000  # Approximately 3GB

echo -e "${BLUE}=== Bytebot Hawkeye - Windows ISO Download ===${NC}"
echo ""

# Create cache directory if it doesn't exist
if [ ! -d "$CACHE_DIR" ]; then
    echo -e "${YELLOW}Creating cache directory: $CACHE_DIR${NC}"
    mkdir -p "$CACHE_DIR"
fi

# Check if ISO already exists
if [ -f "$ISO_PATH" ]; then
    echo -e "${GREEN}✓ Tiny11 ISO already cached at: $ISO_PATH${NC}"

    # Check file size
    FILE_SIZE_MB=$(du -m "$ISO_PATH" | cut -f1)
    echo -e "${BLUE}  File size: ${FILE_SIZE_MB}MB${NC}"

    if [ "$FILE_SIZE_MB" -lt "$EXPECTED_SIZE_MB" ]; then
        echo -e "${RED}⚠ Warning: File size is smaller than expected (${EXPECTED_SIZE_MB}MB)${NC}"
        echo -e "${YELLOW}  The ISO may be corrupted or incomplete.${NC}"
        read -p "Re-download? (y/N): " -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            echo -e "${YELLOW}Using existing ISO. If you encounter issues, delete it and re-run this script.${NC}"
            exit 0
        fi
        rm "$ISO_PATH"
    else
        echo -e "${GREEN}✓ ISO appears valid (size check passed)${NC}"
        echo ""
        echo "To force re-download, delete the cached ISO:"
        echo "  rm $ISO_PATH"
        exit 0
    fi
fi

# Download ISO
echo -e "${BLUE}Downloading Tiny11 2311 from Internet Archive...${NC}"
echo -e "${YELLOW}Source: $DOWNLOAD_URL${NC}"
echo -e "${YELLOW}Target: $ISO_PATH${NC}"
echo ""
echo -e "${YELLOW}This will download ~3GB and may take 5-15 minutes depending on your connection.${NC}"
echo ""

# Use curl with progress bar
if command -v curl &> /dev/null; then
    curl -L -o "$ISO_PATH" --progress-bar "$DOWNLOAD_URL"
elif command -v wget &> /dev/null; then
    wget -O "$ISO_PATH" --show-progress "$DOWNLOAD_URL"
else
    echo -e "${RED}Error: Neither curl nor wget found. Please install one of them.${NC}"
    exit 1
fi

# Verify download
if [ ! -f "$ISO_PATH" ]; then
    echo -e "${RED}✗ Download failed - ISO file not found${NC}"
    exit 1
fi

FILE_SIZE_MB=$(du -m "$ISO_PATH" | cut -f1)
echo ""
echo -e "${GREEN}✓ Download complete!${NC}"
echo -e "${BLUE}  File: $ISO_PATH${NC}"
echo -e "${BLUE}  Size: ${FILE_SIZE_MB}MB${NC}"

if [ "$FILE_SIZE_MB" -lt "$EXPECTED_SIZE_MB" ]; then
    echo -e "${RED}⚠ Warning: File size (${FILE_SIZE_MB}MB) is smaller than expected (${EXPECTED_SIZE_MB}MB)${NC}"
    echo -e "${YELLOW}  The download may have failed. Try running this script again.${NC}"
    exit 1
fi

echo ""
echo -e "${GREEN}=== Setup Complete ===${NC}"
echo ""
echo "The Tiny11 ISO is now cached and will be used for all OmniBox builds."
echo "This ISO will persist even if you delete Docker volumes."
echo ""
echo -e "${BLUE}Next steps:${NC}"
echo "  1. Build OmniBox: ./scripts/fresh-build.sh"
echo "  2. Or start manually: docker compose -f docker/docker-compose.proxy.yml --profile omnibox up -d"
echo ""
