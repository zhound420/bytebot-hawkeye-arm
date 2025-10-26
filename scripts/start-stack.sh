#!/bin/bash
set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Load environment defaults for Docker Compose variable substitution
# This exports variables so ${VAR} syntax in docker-compose.yml works
if [ -f "docker/.env.defaults" ]; then
    set -a  # Auto-export all variables
    source docker/.env.defaults
    set +a  # Stop auto-exporting
fi

ARCH=$(uname -m)
OS=$(uname -s)

echo -e "${BLUE}================================================${NC}"
echo -e "${BLUE}   Starting Bytebot Hawkeye Stack${NC}"
echo -e "${BLUE}================================================${NC}"
echo ""

# Interactive Platform Selection
echo -e "${BLUE}Desktop Platform Selection:${NC}"
echo "  1) Linux Desktop (default - via bytebotd)"
echo "  2) Windows 11 Desktop (via OmniBox)"
echo ""
read -p "Select desktop platform [1]: " platform_choice

case "${platform_choice:-1}" in
    1)
        DESKTOP_PLATFORM="linux"
        echo -e "${GREEN}✓ Using Linux Desktop${NC}"
        ;;
    2)
        DESKTOP_PLATFORM="windows"
        echo -e "${GREEN}✓ Using Windows 11 Desktop${NC}"
        ;;
    *)
        DESKTOP_PLATFORM="linux"
        echo -e "${GREEN}✓ Using Linux Desktop (default)${NC}"
        ;;
esac

echo ""

# Change to docker directory
cd docker

# Update .env.defaults with selected platform and corresponding URLs
if [ -f ".env.defaults" ]; then
    # Update platform setting
    if grep -q "^BYTEBOT_DESKTOP_PLATFORM=" .env.defaults; then
        # Update existing entry
        sed -i.bak "s/^BYTEBOT_DESKTOP_PLATFORM=.*/BYTEBOT_DESKTOP_PLATFORM=$DESKTOP_PLATFORM/" .env.defaults
        rm -f .env.defaults.bak
    else
        # Add new entry
        echo "" >> .env.defaults
        echo "# Desktop Platform (set by start-stack.sh)" >> .env.defaults
        echo "BYTEBOT_DESKTOP_PLATFORM=$DESKTOP_PLATFORM" >> .env.defaults
    fi

    # Update desktop URLs based on platform selection
    if [ "$DESKTOP_PLATFORM" = "linux" ]; then
        # Set Linux desktop URLs
        sed -i.bak "s|^BYTEBOT_DESKTOP_VNC_URL=.*|BYTEBOT_DESKTOP_VNC_URL=http://bytebot-desktop:9990/websockify|" .env.defaults
        sed -i.bak "s|^BYTEBOT_DESKTOP_BASE_URL=.*|BYTEBOT_DESKTOP_BASE_URL=http://bytebot-desktop:9990|" .env.defaults
        rm -f .env.defaults.bak
        echo -e "${GREEN}✓ Configured for Linux Desktop (bytebot-desktop:9990)${NC}"
    else
        # Set Windows/OmniBox URLs
        sed -i.bak "s|^BYTEBOT_DESKTOP_VNC_URL=.*|BYTEBOT_DESKTOP_VNC_URL=http://omnibox:8006/websockify|" .env.defaults
        sed -i.bak "s|^BYTEBOT_DESKTOP_BASE_URL=.*|BYTEBOT_DESKTOP_BASE_URL=http://omnibox-adapter:5001|" .env.defaults
        rm -f .env.defaults.bak
        echo -e "${GREEN}✓ Configured for Windows Desktop (omnibox-adapter:5001)${NC}"
    fi
fi

cd ..

# Determine which compose file to use
if [[ -f "docker/.env" ]]; then
    # Check if using proxy or standard stack
    if [[ -f "docker/docker-compose.proxy.yml" ]]; then
        COMPOSE_FILE="docker-compose.proxy.yml"
        echo -e "${BLUE}Using: Proxy Stack (with LiteLLM)${NC}"
    else
        COMPOSE_FILE="docker-compose.yml"
        echo -e "${BLUE}Using: Standard Stack${NC}"
    fi
else
    echo -e "${RED}✗ docker/.env not found${NC}"
    echo ""
    echo "Copy and configure the environment file:"
    echo -e "  ${BLUE}cp docker/.env.example docker/.env${NC}"
    exit 1
fi

# Check for Windows ISO (if using Windows desktop platform)
if [ "$DESKTOP_PLATFORM" = "windows" ]; then
    echo ""
    echo -e "${BLUE}Checking for Windows ISO...${NC}"

    CACHE_DIR="$HOME/.cache/bytebot/iso"
    VARIANT_FILE="$CACHE_DIR/.variant"
    SYMLINK_PATH="$CACHE_DIR/windows.iso"

    # Check if symlink exists
    if [ -L "$SYMLINK_PATH" ] && [ -e "$SYMLINK_PATH" ]; then
        # Get variant from metadata
        if [ -f "$VARIANT_FILE" ]; then
            VARIANT=$(cat "$VARIANT_FILE")
            case "$VARIANT" in
                standard)
                    VARIANT_NAME="Tiny11 2311 (Standard)"
                    ;;
                core)
                    VARIANT_NAME="Tiny11 Core x64"
                    ;;
                *)
                    VARIANT_NAME="Unknown"
                    ;;
            esac
        else
            VARIANT_NAME="Unknown variant"
        fi

        ISO_SIZE_MB=$(du -m "$SYMLINK_PATH" 2>/dev/null | cut -f1)
        echo -e "${GREEN}✓ Using cached Windows ISO: ${VARIANT_NAME} (${ISO_SIZE_MB}MB)${NC}"
        echo -e "${BLUE}  Location: $SYMLINK_PATH${NC}"
    else
        echo -e "${YELLOW}⚠️  No Windows ISO found in cache${NC}"
        echo -e "${YELLOW}  Expected location: $SYMLINK_PATH${NC}"
        echo ""
        echo "Windows desktop requires a Tiny11 ISO (~3GB)."
        echo ""
        read -p "Download Windows ISO now? [Y/n]: " -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Nn]$ ]]; then
            echo -e "${BLUE}Running download script...${NC}"
            echo ""
            ./scripts/download-windows-iso.sh
            if [ $? -ne 0 ]; then
                echo ""
                echo -e "${RED}✗ ISO download failed${NC}"
                echo "You can manually download later with: ./scripts/download-windows-iso.sh"
                echo ""
                read -p "Continue without Windows desktop? [y/N]: " -n 1 -r
                echo
                if [[ ! $REPLY =~ ^[Yy]$ ]]; then
                    echo -e "${YELLOW}Exiting. Run this script again after downloading the ISO.${NC}"
                    exit 1
                fi
                echo -e "${YELLOW}Continuing without Windows desktop...${NC}"
                DESKTOP_PLATFORM="linux"
            else
                echo ""
                echo -e "${GREEN}✓ ISO download complete${NC}"
            fi
        else
            echo -e "${YELLOW}Skipping ISO download.${NC}"
            echo ""
            read -p "Continue without Windows desktop? [y/N]: " -n 1 -r
            echo
            if [[ ! $REPLY =~ ^[Yy]$ ]]; then
                echo -e "${YELLOW}Exiting. Run this script again after downloading the ISO.${NC}"
                exit 1
            fi
            echo -e "${YELLOW}Switching to Linux desktop...${NC}"
            DESKTOP_PLATFORM="linux"
        fi
    fi
fi

echo ""

# Platform-specific configuration
if [[ "$ARCH" == "arm64" ]] && [[ "$OS" == "Darwin" ]]; then
    echo -e "${BLUE}Platform: Apple Silicon${NC}"
    echo ""

    # Check if native OmniParser is running
    if lsof -Pi :9989 -sTCP:LISTEN -t >/dev/null 2>&1; then
        echo -e "${GREEN}✓ Native OmniParser detected on port 9989${NC}"

        # Update .env.defaults (system defaults) to use native OmniParser
        if grep -q "OMNIPARSER_URL=http://bytebot-omniparser:9989" docker/.env.defaults 2>/dev/null; then
            echo -e "${BLUE}Updating system configuration to use native OmniParser...${NC}"
            sed -i.bak 's|OMNIPARSER_URL=http://bytebot-omniparser:9989|OMNIPARSER_URL=http://host.docker.internal:9989|' docker/.env.defaults
            rm docker/.env.defaults.bak
        fi

        # LMStudio Configuration (optional)
        echo ""
        echo -e "${BLUE}LMStudio Configuration:${NC}"
        echo "Configure local VLM models from LMStudio?"
        read -p "[y/N]: " setup_lmstudio

        if [[ $setup_lmstudio =~ ^[Yy]$ ]]; then
            ./scripts/setup-lmstudio.sh
        fi

        cd docker

        echo ""
        echo -e "${BLUE}Starting Docker stack (without OmniParser container)...${NC}"

        # Determine profile based on platform selection
        if [ "$DESKTOP_PLATFORM" = "windows" ]; then
            PROFILE_ARG="--profile omnibox"
            echo -e "${BLUE}Including Windows desktop (OmniBox) services...${NC}"
        else
            PROFILE_ARG="--profile linux"
            echo -e "${BLUE}Including Linux desktop (bytebotd) services...${NC}"
        fi

        # Start all services except OmniParser container
        # --no-deps prevents starting dependent services (bytebot-omniparser)
        # Add --build flag to rebuild if code changed
        docker compose $PROFILE_ARG -f $COMPOSE_FILE -f docker-compose.override.yml up -d --build --no-deps \
            $([ "$DESKTOP_PLATFORM" = "windows" ] && echo "omnibox omnibox-adapter" || echo "bytebot-desktop") \
            bytebot-agent \
            bytebot-ui \
            postgres \
            $([ "$COMPOSE_FILE" = "docker-compose.proxy.yml" ] && echo "bytebot-llm-proxy" || echo "")

    else
        echo -e "${YELLOW}⚠ Native OmniParser not running${NC}"
        echo ""

        # Check if it's been set up
        if [[ ! -d "packages/bytebot-omniparser/venv" ]] && [[ ! -d "packages/bytebot-omniparser/weights/icon_detect" ]]; then
            echo -e "${BLUE}→ Setting up native OmniParser automatically (recommended for M4 GPU)...${NC}"
            echo ""
            ./scripts/setup-omniparser.sh
            echo ""
            echo -e "${BLUE}→ Starting native OmniParser...${NC}"
            ./scripts/start-omniparser.sh
            echo ""
            echo "Waiting for OmniParser to be ready..."
            sleep 3
        else
            echo -e "${BLUE}→ Starting native OmniParser automatically...${NC}"
            ./scripts/start-omniparser.sh
            echo ""
            echo "Waiting for OmniParser to be ready..."
            sleep 3
        fi

        # Update .env.defaults (system defaults) to use native OmniParser
        if grep -q "OMNIPARSER_URL=http://bytebot-omniparser:9989" docker/.env.defaults 2>/dev/null; then
            sed -i.bak 's|OMNIPARSER_URL=http://bytebot-omniparser:9989|OMNIPARSER_URL=http://host.docker.internal:9989|' docker/.env.defaults
            rm docker/.env.defaults.bak
        fi

        # LMStudio Configuration (optional)
        echo ""
        echo -e "${BLUE}LMStudio Configuration:${NC}"
        echo "Configure local VLM models from LMStudio?"
        read -p "[y/N]: " setup_lmstudio

        if [[ $setup_lmstudio =~ ^[Yy]$ ]]; then
            ./scripts/setup-lmstudio.sh
        fi

        cd docker

        # Start stack without container
        echo ""
        echo -e "${BLUE}Starting Docker stack (without OmniParser container)...${NC}"

        # Determine profile based on platform selection
        if [ "$DESKTOP_PLATFORM" = "windows" ]; then
            PROFILE_ARG="--profile omnibox"
            echo -e "${BLUE}Including Windows desktop (OmniBox) services...${NC}"
        else
            PROFILE_ARG="--profile linux"
            echo -e "${BLUE}Including Linux desktop (bytebotd) services...${NC}"
        fi

        # --no-deps prevents starting dependent services (bytebot-omniparser)
        # Add --build flag to rebuild if code changed

        # For Windows: start in background and monitor
        if [ "$DESKTOP_PLATFORM" = "windows" ]; then
            docker compose $PROFILE_ARG -f $COMPOSE_FILE -f docker-compose.override.yml up -d --build --no-deps \
                omnibox omnibox-adapter \
                bytebot-agent \
                bytebot-ui \
                postgres \
                $([ "$COMPOSE_FILE" = "docker-compose.proxy.yml" ] && echo "bytebot-llm-proxy" || echo "") &
            COMPOSE_PID=$!

            echo ""
            echo -e "${YELLOW}═══════════════════════════════════════════════════════${NC}"
            echo -e "${YELLOW}   Windows Desktop Starting Up${NC}"
            echo -e "${YELLOW}═══════════════════════════════════════════════════════${NC}"
            echo ""
            echo -e "${CYAN}Starting real-time progress monitor...${NC}"
            echo ""

            # Monitor in foreground
            ./scripts/monitor-omnibox.sh || true

            # Wait for docker compose to finish if still running
            wait $COMPOSE_PID 2>/dev/null || true

            echo ""
            echo -e "${CYAN}To resume monitoring at any time:${NC}"
            echo -e "  ${BLUE}./scripts/monitor-omnibox.sh${NC}"
            echo ""
        else
            docker compose $PROFILE_ARG -f $COMPOSE_FILE -f docker-compose.override.yml up -d --build --no-deps \
                bytebot-desktop \
                bytebot-agent \
                bytebot-ui \
                postgres \
                $([ "$COMPOSE_FILE" = "docker-compose.proxy.yml" ] && echo "bytebot-llm-proxy" || echo "")
        fi

        # Check service status
        echo ""
        echo -e "${BLUE}Service Status:${NC}"
        services=("bytebot-ui:9992" "bytebot-agent:9991" "bytebot-desktop:9990" "OmniParser:9989")
        for service_port in "${services[@]}"; do
            IFS=: read -r service port <<< "$service_port"
            if nc -z localhost $port 2>/dev/null; then
                echo -e "  ${GREEN}✓${NC} $service (port $port)"
            else
                echo -e "  ${YELLOW}...${NC} $service (port $port) - starting..."
            fi
        done
        echo ""
        echo -e "${GREEN}Stack ready with native OmniParser (MPS GPU)!${NC}"
        echo ""
        echo "Services:"
        echo "  • UI:       http://localhost:9992"
        echo "  • Agent:    http://localhost:9991"
        echo "  • Desktop:  http://localhost:9990"
        echo "  • OmniParser: http://localhost:9989 (native MPS)"
        echo ""
        exit 0
    fi

elif [[ "$ARCH" == "x86_64" ]] || [[ "$ARCH" == "amd64" ]]; then
    echo -e "${BLUE}Platform: x86_64${NC}"

    # Check for NVIDIA GPU
    if command -v nvidia-smi &> /dev/null; then
        echo -e "${GREEN}✓ NVIDIA GPU detected${NC}"
        nvidia-smi --query-gpu=name --format=csv,noheader | head -1
    fi

    # LMStudio Configuration (optional)
    echo ""
    echo -e "${BLUE}LMStudio Configuration:${NC}"
    echo "Configure local VLM models from LMStudio?"
    read -p "[y/N]: " setup_lmstudio

    if [[ $setup_lmstudio =~ ^[Yy]$ ]]; then
        ./scripts/setup-lmstudio.sh
    fi

    cd docker

    echo ""
    echo -e "${BLUE}Starting full Docker stack (includes OmniParser container)...${NC}"

    # Determine profile based on platform selection
    if [ "$DESKTOP_PLATFORM" = "windows" ]; then
        PROFILE_ARG="--profile omnibox"
        echo -e "${BLUE}Including Windows desktop (OmniBox) services...${NC}"
    else
        PROFILE_ARG="--profile linux"
        echo -e "${BLUE}Including Linux desktop (bytebotd) services...${NC}"
    fi

    # For Windows: start docker compose in background, then monitor
    if [ "$DESKTOP_PLATFORM" = "windows" ]; then
        # Start docker compose in background (will wait for health checks)
        docker compose $PROFILE_ARG -f $COMPOSE_FILE -f docker-compose.override.yml up -d --build &
        COMPOSE_PID=$!

        cd ..

        echo ""
        echo -e "${YELLOW}═══════════════════════════════════════════════════════${NC}"
        echo -e "${YELLOW}   Windows Desktop Starting Up${NC}"
        echo -e "${YELLOW}═══════════════════════════════════════════════════════${NC}"
        echo ""
        echo -e "${CYAN}Starting real-time progress monitor...${NC}"
        echo ""

        # Monitor in foreground while docker compose waits for health checks
        ./scripts/monitor-omnibox.sh || true

        # Wait for docker compose to finish if still running
        wait $COMPOSE_PID 2>/dev/null || true

        echo ""
        echo -e "${CYAN}To resume monitoring at any time:${NC}"
        echo -e "  ${BLUE}./scripts/monitor-omnibox.sh${NC}"
        echo ""
    else
        # Linux: run docker compose normally (foreground)
        docker compose $PROFILE_ARG -f $COMPOSE_FILE -f docker-compose.override.yml up -d --build
        cd ..
    fi
fi

# Wait for services to be ready
echo ""
echo -e "${BLUE}Waiting for services to start...${NC}"
sleep 5

# Check service health
echo ""
echo -e "${BLUE}Service Status:${NC}"

# Check each service
services=("bytebot-ui:9992" "bytebot-agent:9991" "bytebot-desktop:9990")
if lsof -Pi :9989 -sTCP:LISTEN -t >/dev/null 2>&1; then
    services+=("OmniParser:9989")
fi

all_healthy=true
for service_port in "${services[@]}"; do
    IFS=: read -r service port <<< "$service_port"
    if nc -z localhost $port 2>/dev/null; then
        echo -e "  ${GREEN}✓${NC} $service (port $port)"
    else
        echo -e "  ${RED}✗${NC} $service (port $port) - starting..."
        all_healthy=false
    fi
done

echo ""
if $all_healthy; then
    echo -e "${GREEN}================================================${NC}"
    echo -e "${GREEN}   Stack Ready!${NC}"
    echo -e "${GREEN}================================================${NC}"
else
    echo -e "${YELLOW}================================================${NC}"
    echo -e "${YELLOW}   Stack Starting (check logs if issues)${NC}"
    echo -e "${YELLOW}================================================${NC}"
fi

echo ""
echo "Services:"
echo "  • UI:       http://localhost:9992"
echo "  • Agent:    http://localhost:9991"
echo "  • Desktop:  http://localhost:9990"
echo "  • OmniParser: http://localhost:9989"
echo ""
echo "View logs:"
echo -e "  ${BLUE}docker compose -f docker/$COMPOSE_FILE logs -f${NC}"
echo ""
echo "Stop stack:"
echo -e "  ${BLUE}./scripts/stop-stack.sh${NC}"
echo ""
