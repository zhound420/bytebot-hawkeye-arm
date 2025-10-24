#!/bin/bash
# =============================================================================
# Download Tiny11 ISO for OmniBox Windows Environment
# =============================================================================
# Downloads and caches Tiny11 ISO variants to avoid repeated downloads
# during fresh builds. ISOs are stored in user's cache directory.
#
# Usage: ./scripts/download-windows-iso.sh [variant]
#   variant: standard|core (optional, prompts if not provided)

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Configuration
CACHE_DIR="$HOME/.cache/bytebot/iso"
VARIANT_FILE="$CACHE_DIR/.variant"
SYMLINK_PATH="$CACHE_DIR/windows.iso"

# Variant configurations
declare -A VARIANTS=(
    [standard]="Tiny11 2311 (Standard)"
    [core]="Tiny11 Core x64"
)

declare -A ISO_NAMES=(
    [standard]="tiny11-2311.iso"
    [core]="tiny11-core-x64.iso"
)

declare -A DOWNLOAD_URLS=(
    [standard]="https://archive.org/download/tiny11-2311/tiny11%202311%20x64.iso"
    [core]="https://archive.org/download/tiny-11-core-x-64-beta-1/tiny11%20core%20x64%20beta%201.iso"
)

declare -A EXPECTED_SIZES=(
    [standard]=3000  # ~3.6GB
    [core]=2500      # ~2.7GB
)

declare -A INSTALLED_SIZES=(
    [standard]="~20GB"
    [core]="~11GB"
)

echo -e "${BLUE}╔═══════════════════════════════════════════════════════╗${NC}"
echo -e "${BLUE}║   ${CYAN}Bytebot Hawkeye - Windows ISO Download${BLUE}        ║${NC}"
echo -e "${BLUE}╚═══════════════════════════════════════════════════════╝${NC}"
echo ""

# Create cache directory if it doesn't exist
if [ ! -d "$CACHE_DIR" ]; then
    echo -e "${YELLOW}Creating cache directory: $CACHE_DIR${NC}"
    mkdir -p "$CACHE_DIR"
fi

# Check for cached ISOs
check_cached_isos() {
    local has_iso=false
    echo -e "${BLUE}Checking for cached ISOs...${NC}"
    echo ""

    for variant in "${!VARIANTS[@]}"; do
        local iso_path="$CACHE_DIR/${ISO_NAMES[$variant]}"
        if [ -f "$iso_path" ]; then
            local file_size_mb=$(du -m "$iso_path" | cut -f1)
            echo -e "${GREEN}  ✓ ${VARIANTS[$variant]}: ${file_size_mb}MB${NC}"
            has_iso=true
        fi
    done

    if [ "$has_iso" = false ]; then
        echo -e "${YELLOW}  No cached ISOs found${NC}"
    fi

    echo ""
}

# Select variant
select_variant() {
    local preset="$1"

    if [ -n "$preset" ]; then
        if [ "$preset" = "standard" ] || [ "$preset" = "core" ]; then
            echo "$preset"
            return
        else
            echo -e "${RED}Invalid variant: $preset${NC}" >&2
            echo -e "${YELLOW}Valid options: standard, core${NC}" >&2
            exit 1
        fi
    fi

    echo -e "${CYAN}Select Tiny11 variant:${NC}"
    echo ""
    echo -e "  ${GREEN}1)${NC} Tiny11 2311 ${CYAN}(Standard)${NC} - ${YELLOW}Recommended${NC}"
    echo -e "     • Size: ~3.6GB download, ${INSTALLED_SIZES[standard]} installed"
    echo -e "     • Fully serviceable (receives Windows updates)"
    echo -e "     • Best for: Regular use, development"
    echo ""
    echo -e "  ${GREEN}2)${NC} Tiny11 Core x64 ${CYAN}(Minimal)${NC}"
    echo -e "     • Size: ~2.7GB download, ${INSTALLED_SIZES[core]} installed"
    echo -e "     • ${RED}NOT serviceable${NC} (no updates/languages)"
    echo -e "     • Best for: Testing, disposable VMs"
    echo -e "     ${YELLOW}⚠️  WARNING: Not suitable for production use${NC}"
    echo ""

    read -p "Enter choice [1]: " choice
    choice=${choice:-1}

    case "$choice" in
        1|standard)
            echo "standard"
            ;;
        2|core)
            echo "core"
            ;;
        *)
            echo -e "${RED}Invalid choice. Using Standard.${NC}" >&2
            echo "standard"
            ;;
    esac
}

# Download ISO
download_iso() {
    local variant="$1"
    local iso_name="${ISO_NAMES[$variant]}"
    local iso_path="$CACHE_DIR/$iso_name"
    local download_url="${DOWNLOAD_URLS[$variant]}"
    local expected_size="${EXPECTED_SIZES[$variant]}"

    # Check if already exists
    if [ -f "$iso_path" ]; then
        local file_size_mb=$(du -m "$iso_path" | cut -f1)

        if [ "$file_size_mb" -lt "$expected_size" ]; then
            echo -e "${YELLOW}⚠️  Existing ISO is incomplete (${file_size_mb}MB < ${expected_size}MB)${NC}"
            read -p "Re-download? [Y/n]: " -n 1 -r
            echo
            if [[ ! $REPLY =~ ^[Nn]$ ]]; then
                rm "$iso_path"
            else
                echo -e "${YELLOW}Keeping incomplete ISO. Build may fail.${NC}"
                return 1
            fi
        else
            echo -e "${GREEN}✓ ${VARIANTS[$variant]} already cached${NC}"
            echo -e "${BLUE}  Location: $iso_path${NC}"
            echo -e "${BLUE}  Size: ${file_size_mb}MB${NC}"
            return 0
        fi
    fi

    # Download
    echo ""
    echo -e "${BLUE}Downloading ${VARIANTS[$variant]}...${NC}"
    echo -e "${CYAN}  Source: $download_url${NC}"
    echo -e "${CYAN}  Target: $iso_path${NC}"
    echo ""
    echo -e "${YELLOW}This will download ~${expected_size}MB and may take 5-15 minutes.${NC}"
    echo ""

    # Use curl with progress bar
    if command -v curl &> /dev/null; then
        curl -L -o "$iso_path" --progress-bar "$download_url"
    elif command -v wget &> /dev/null; then
        wget -O "$iso_path" --show-progress "$download_url"
    else
        echo -e "${RED}Error: Neither curl nor wget found. Please install one of them.${NC}"
        exit 1
    fi

    # Verify download
    if [ ! -f "$iso_path" ]; then
        echo -e "${RED}✗ Download failed - ISO file not found${NC}"
        exit 1
    fi

    local file_size_mb=$(du -m "$iso_path" | cut -f1)
    echo ""
    echo -e "${GREEN}✓ Download complete!${NC}"
    echo -e "${BLUE}  File: $iso_path${NC}"
    echo -e "${BLUE}  Size: ${file_size_mb}MB${NC}"

    if [ "$file_size_mb" -lt "$expected_size" ]; then
        echo -e "${RED}⚠️  Warning: File size (${file_size_mb}MB) is smaller than expected (${expected_size}MB)${NC}"
        echo -e "${YELLOW}  The download may have failed. Try running this script again.${NC}"
        exit 1
    fi

    return 0
}

# Create symlink and save variant
setup_active_variant() {
    local variant="$1"
    local iso_name="${ISO_NAMES[$variant]}"
    local iso_path="$CACHE_DIR/$iso_name"

    # Save variant to metadata file
    echo "$variant" > "$VARIANT_FILE"

    # Create or update symlink
    if [ -L "$SYMLINK_PATH" ]; then
        rm "$SYMLINK_PATH"
    fi
    ln -s "$iso_name" "$SYMLINK_PATH"

    echo -e "${GREEN}✓ Active variant set to: ${VARIANTS[$variant]}${NC}"
}

# Main execution
main() {
    local preset_variant="$1"

    # Show cached ISOs
    check_cached_isos

    # Select variant
    echo -e "${CYAN}═══════════════════════════════════════════════════════${NC}"
    local variant=$(select_variant "$preset_variant")
    echo ""

    # Show warning for Core
    if [ "$variant" = "core" ]; then
        echo -e "${YELLOW}╔═══════════════════════════════════════════════════════╗${NC}"
        echo -e "${YELLOW}║  ${RED}⚠️  WARNING: Tiny11 Core Selected${YELLOW}                  ║${NC}"
        echo -e "${YELLOW}╠═══════════════════════════════════════════════════════╣${NC}"
        echo -e "${YELLOW}║  This variant is NOT serviceable:                    ║${NC}"
        echo -e "${YELLOW}║  • Cannot receive Windows updates                    ║${NC}"
        echo -e "${YELLOW}║  • Cannot add languages or features                  ║${NC}"
        echo -e "${YELLOW}║  • Use for testing/development only                  ║${NC}"
        echo -e "${YELLOW}╚═══════════════════════════════════════════════════════╝${NC}"
        echo ""
        read -p "Continue with Tiny11 Core? [y/N]: " -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            echo -e "${BLUE}Switching to Standard variant...${NC}"
            variant="standard"
            echo ""
        fi
    fi

    # Download ISO
    download_iso "$variant"

    # Setup as active variant
    setup_active_variant "$variant"

    echo ""
    echo -e "${GREEN}╔═══════════════════════════════════════════════════════╗${NC}"
    echo -e "${GREEN}║  ${CYAN}Setup Complete!${GREEN}                                    ║${NC}"
    echo -e "${GREEN}╚═══════════════════════════════════════════════════════╝${NC}"
    echo ""
    echo -e "Variant: ${CYAN}${VARIANTS[$variant]}${NC}"
    echo -e "Location: ${BLUE}$CACHE_DIR/${ISO_NAMES[$variant]}${NC}"
    echo -e "Symlink: ${BLUE}$SYMLINK_PATH${NC}"
    echo ""
    echo "The ISO is now cached and will be used for all OmniBox builds."
    echo "This ISO will persist even if you delete Docker volumes."
    echo ""
    echo -e "${CYAN}Next steps:${NC}"
    echo "  1. Fresh build: ${BLUE}./scripts/fresh-build.sh${NC}"
    echo "  2. Start stack: ${BLUE}./scripts/start-stack.sh${NC}"
    echo "  3. Or manually: ${BLUE}docker compose -f docker/docker-compose.proxy.yml --profile omnibox up -d${NC}"
    echo ""
    echo -e "${YELLOW}To switch variants, run this script again and choose a different option.${NC}"
    echo ""
}

# Run main with command-line argument (if provided)
main "$1"
