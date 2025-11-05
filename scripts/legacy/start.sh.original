#!/bin/bash

set -e

# Colors for output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
RED='\033[0;31m'
NC='\033[0m' # No Color

# Default values
DOCKER_COMPOSE_FILE="docker/docker-compose.yml"
ENV_FILE="docker/.env"
ENV_DEFAULTS="docker/.env.defaults"

echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${BLUE}  Bytebot Hawkeye - Auto-Detection Startup${NC}"
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo

# Check if BYTEBOT_FORCE_PLATFORM is set
if [ -n "$BYTEBOT_FORCE_PLATFORM" ]; then
    echo -e "${YELLOW}⚙ Manual platform override detected: ${BYTEBOT_FORCE_PLATFORM}${NC}"
    PLATFORM="$BYTEBOT_FORCE_PLATFORM"
else
    # Auto-detect host platform
    echo -e "${BLUE}🔍 Detecting host platform...${NC}"

    OS_TYPE=$(uname -s | tr '[:upper:]' '[:lower:]')
    ARCH=$(uname -m)

    case "$OS_TYPE" in
        linux*)
            echo -e "${GREEN}  → Detected: Linux${NC}"
            DETECTED_OS="linux"
            ;;
        darwin*)
            echo -e "${GREEN}  → Detected: macOS${NC}"
            DETECTED_OS="macos"
            ;;
        msys*|mingw*|cygwin*)
            echo -e "${GREEN}  → Detected: Windows (WSL/Git Bash)${NC}"
            DETECTED_OS="windows"
            ;;
        *)
            echo -e "${YELLOW}  → Unknown OS: $OS_TYPE, defaulting to Linux${NC}"
            DETECTED_OS="linux"
            ;;
    esac

    # Check for Windows desktop support requirements
    if [ "$DETECTED_OS" = "linux" ] && [ -e "/dev/kvm" ]; then
        echo -e "${BLUE}🔍 Checking for Windows desktop support...${NC}"
        echo -e "${GREEN}  → KVM detected (/dev/kvm)${NC}"
        echo -e "${BLUE}  → Windows desktop (OmniBox) is available${NC}"

        # Check if Windows ISO exists
        ISO_PATH="$HOME/.cache/bytebot/iso/tiny11.iso"
        if [ -f "$ISO_PATH" ]; then
            echo -e "${GREEN}  → Windows ISO found: $ISO_PATH${NC}"
            WINDOWS_AVAILABLE=true
        else
            echo -e "${YELLOW}  → Windows ISO not found: $ISO_PATH${NC}"
            echo -e "${YELLOW}  → To use Windows desktop, download Tiny11 ISO (~3GB)${NC}"
            WINDOWS_AVAILABLE=false
        fi
    else
        WINDOWS_AVAILABLE=false
    fi

    # Ask user for platform preference (only if Windows is available)
    if [ "$WINDOWS_AVAILABLE" = true ]; then
        echo
        echo -e "${BLUE}Select desktop platform:${NC}"
        echo -e "  ${GREEN}1${NC}) Linux desktop (default, recommended)"
        echo -e "  ${YELLOW}2${NC}) Windows 11 desktop (via OmniBox VM)"
        echo
        read -p "Choice [1]: " PLATFORM_CHOICE
        PLATFORM_CHOICE=${PLATFORM_CHOICE:-1}

        case "$PLATFORM_CHOICE" in
            2)
                echo -e "${YELLOW}  → Selected: Windows desktop${NC}"
                PLATFORM="windows"
                ;;
            *)
                echo -e "${GREEN}  → Selected: Linux desktop${NC}"
                PLATFORM="linux"
                ;;
        esac
    else
        # Default to Linux if Windows not available
        echo -e "${GREEN}  → Platform: Linux desktop${NC}"
        PLATFORM="linux"
    fi
fi

# Set Docker Compose profile based on platform
case "$PLATFORM" in
    windows)
        COMPOSE_PROFILES="omnibox"
        DESKTOP_BASE_URL="http://omnibox-adapter:5001"
        DESKTOP_LINUX_URL="http://bytebot-desktop:9990"
        DESKTOP_WINDOWS_URL="http://omnibox-adapter:5001"
        ;;
    *)
        COMPOSE_PROFILES="linux"
        DESKTOP_BASE_URL="http://bytebot-desktop:9990"
        DESKTOP_LINUX_URL="http://bytebot-desktop:9990"
        DESKTOP_WINDOWS_URL="http://omnibox-adapter:5001"
        ;;
esac

echo
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${BLUE}  Configuration${NC}"
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "  Platform:         ${GREEN}$PLATFORM${NC}"
echo -e "  Docker Profile:   ${GREEN}$COMPOSE_PROFILES${NC}"
echo -e "  Desktop URL:      ${GREEN}$DESKTOP_BASE_URL${NC}"
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo

# Update or create .env file
echo -e "${BLUE}⚙ Updating environment configuration...${NC}"

# Create or update .env file (preserves other settings)
if [ -f "$ENV_FILE" ]; then
    # Update existing .env
    if grep -q "^BYTEBOT_DESKTOP_PLATFORM=" "$ENV_FILE"; then
        sed -i "s|^BYTEBOT_DESKTOP_PLATFORM=.*|BYTEBOT_DESKTOP_PLATFORM=$PLATFORM|" "$ENV_FILE"
    else
        echo "BYTEBOT_DESKTOP_PLATFORM=$PLATFORM" >> "$ENV_FILE"
    fi

    if grep -q "^BYTEBOT_DESKTOP_BASE_URL=" "$ENV_FILE"; then
        sed -i "s|^BYTEBOT_DESKTOP_BASE_URL=.*|BYTEBOT_DESKTOP_BASE_URL=$DESKTOP_BASE_URL|" "$ENV_FILE"
    else
        echo "BYTEBOT_DESKTOP_BASE_URL=$DESKTOP_BASE_URL" >> "$ENV_FILE"
    fi
else
    # Create new .env from defaults
    cp "$ENV_DEFAULTS" "$ENV_FILE"
    echo "BYTEBOT_DESKTOP_PLATFORM=$PLATFORM" >> "$ENV_FILE"
    echo "BYTEBOT_DESKTOP_BASE_URL=$DESKTOP_BASE_URL" >> "$ENV_FILE"
fi

echo -e "${GREEN}  ✓ Configuration saved to $ENV_FILE${NC}"
echo

# Start Docker Compose with the appropriate profile
echo -e "${BLUE}🚀 Starting Bytebot Hawkeye stack...${NC}"
echo -e "   ${BLUE}Profile: $COMPOSE_PROFILES${NC}"
echo

export COMPOSE_PROFILES="$COMPOSE_PROFILES"
docker compose -f "$DOCKER_COMPOSE_FILE" up -d

echo
echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${GREEN}  ✓ Bytebot Hawkeye started successfully!${NC}"
echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo
echo -e "${BLUE}Access points:${NC}"
echo -e "  • Web UI:         ${GREEN}http://localhost:9992${NC}"
echo -e "  • Agent API:      ${GREEN}http://localhost:9991${NC}"
echo -e "  • Desktop Daemon: ${GREEN}http://localhost:9990${NC}"

if [ "$PLATFORM" = "windows" ]; then
    echo -e "  • Windows Desktop VNC: ${GREEN}http://localhost:5000${NC}"
    echo
    echo -e "${YELLOW}Note: Windows VM may take 2-10 minutes to boot${NC}"
else
    echo -e "  • Linux Desktop VNC:   ${GREEN}http://localhost:8081${NC}"
fi

echo
echo -e "${BLUE}Useful commands:${NC}"
echo -e "  • View logs:    ${GREEN}docker compose -f $DOCKER_COMPOSE_FILE logs -f${NC}"
echo -e "  • Stop stack:   ${GREEN}docker compose -f $DOCKER_COMPOSE_FILE down${NC}"
echo -e "  • Restart:      ${GREEN}$0${NC}"
echo
echo -e "${BLUE}To force a specific platform:${NC}"
echo -e "  ${GREEN}BYTEBOT_FORCE_PLATFORM=linux $0${NC}"
echo -e "  ${GREEN}BYTEBOT_FORCE_PLATFORM=windows $0${NC}"
echo
