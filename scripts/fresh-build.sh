#!/usr/bin/env bash
set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo -e "${BLUE}================================================${NC}"
echo -e "${BLUE}   Bytebot Hawkeye - Fresh Build${NC}"
echo -e "${BLUE}================================================${NC}"
echo ""

# Detect platform with enhanced Windows/WSL support
ARCH=$(uname -m)
OS=$(uname -s)

# Detect if running on Windows WSL
IS_WSL=false
if grep -qEi "(Microsoft|WSL)" /proc/version 2>/dev/null; then
    IS_WSL=true
    OS="WSL"
fi

# Normalize OS name
case "$OS" in
    Linux*)
        if [ "$IS_WSL" = true ]; then
            PLATFORM="Windows (WSL)"
        else
            PLATFORM="Linux"
        fi
        ;;
    Darwin*)
        PLATFORM="macOS"
        ;;
    CYGWIN*|MINGW*|MSYS*)
        PLATFORM="Windows (Git Bash)"
        ;;
    *)
        PLATFORM="$OS"
        ;;
esac

echo -e "${BLUE}Platform: $PLATFORM ($ARCH)${NC}"
echo ""

# Interactive Platform Selection
echo -e "${BLUE}Step 1: Desktop Platform Selection${NC}"
echo "Which desktop environment would you like to use?"
echo "  1) Linux Desktop (default - faster, lighter)"
echo "  2) Windows 11 Desktop (via OmniBox - requires KVM)"
echo ""
read -p "Select [1]: " platform_choice

case "${platform_choice:-1}" in
    1)
        DESKTOP_PLATFORM="linux"
        echo -e "${GREEN}✓ Using Linux Desktop${NC}"
        ;;
    2)
        DESKTOP_PLATFORM="windows"
        echo -e "${GREEN}✓ Using Windows 11 Desktop${NC}"
        # Check if OmniBox needs setup
        if [ ! -f "packages/omnibox/.setup_complete" ]; then
            echo -e "${BLUE}Setting up OmniBox for first time...${NC}"
            ./scripts/setup-omnibox.sh
            touch packages/omnibox/.setup_complete
        fi
        ;;
    *)
        DESKTOP_PLATFORM="linux"
        echo -e "${GREEN}✓ Using Linux Desktop (default)${NC}"
        ;;
esac
echo ""

# Stop any running services
echo -e "${BLUE}Step 2: Stopping existing services...${NC}"
if [ -f "scripts/stop-stack.sh" ]; then
    ./scripts/stop-stack.sh || true
fi
echo ""

# Clean Docker build cache (optional - ask user)
read -p "Clear Docker build cache? (Slower but ensures fresh build) [y/N] " -n 1 -r
echo ""
if [[ $REPLY =~ ^[Yy]$ ]]; then
    echo -e "${BLUE}Pruning Docker build cache...${NC}"
    docker builder prune -f
    echo -e "${GREEN}✓ Build cache cleared${NC}"
fi
echo ""

# Update .env.defaults with selected platform
if [ -f "docker/.env.defaults" ]; then
    if grep -q "^BYTEBOT_DESKTOP_PLATFORM=" docker/.env.defaults; then
        # Update existing entry
        sed -i.bak "s/^BYTEBOT_DESKTOP_PLATFORM=.*/BYTEBOT_DESKTOP_PLATFORM=$DESKTOP_PLATFORM/" docker/.env.defaults
        rm -f docker/.env.defaults.bak
    else
        # Add new entry
        echo "" >> docker/.env.defaults
        echo "# Desktop Platform (set by fresh-build.sh)" >> docker/.env.defaults
        echo "BYTEBOT_DESKTOP_PLATFORM=$DESKTOP_PLATFORM" >> docker/.env.defaults
    fi
    echo -e "${GREEN}✓ Platform configuration saved to .env.defaults${NC}"
fi
echo ""

# Clean problematic node_modules (OpenCV build artifacts)
echo -e "${BLUE}Step 3: Cleaning node_modules...${NC}"
if [ -d "node_modules/@u4/opencv-build" ]; then
    echo "Removing OpenCV build artifacts..."
    rm -rf node_modules/@u4/opencv-build
    rm -rf node_modules/@u4/.opencv-build-*
fi
if [ -d "packages/bytebot-cv/node_modules/@u4/opencv-build" ]; then
    echo "Removing CV OpenCV build artifacts..."
    rm -rf packages/bytebot-cv/node_modules/@u4/opencv-build
    rm -rf packages/bytebot-cv/node_modules/@u4/.opencv-build-*
fi
echo -e "${GREEN}✓ Cleaned node_modules${NC}"
echo ""

# Check for Windows ISO (if using Windows desktop platform)
if [ "$DESKTOP_PLATFORM" = "windows" ] || grep -q "BYTEBOT_DESKTOP_PLATFORM=windows" docker/.env 2>/dev/null; then
    CACHE_DIR="$HOME/.cache/bytebot/iso"
    VARIANT_FILE="$CACHE_DIR/.variant"
    SYMLINK_PATH="$CACHE_DIR/windows.iso"

    echo -e "${BLUE}Step 3b: Checking for cached Windows ISO...${NC}"

    # Check if symlink exists and points to valid file
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
                    VARIANT_NAME="Unknown variant"
                    ;;
            esac
        else
            VARIANT_NAME="Unknown variant"
        fi

        ISO_SIZE_MB=$(du -m "$SYMLINK_PATH" 2>/dev/null | cut -f1)
        echo -e "${GREEN}✓ Using cached Windows ISO: ${VARIANT_NAME} (${ISO_SIZE_MB}MB)${NC}"
        echo -e "${BLUE}  Location: $SYMLINK_PATH${NC}"
    else
        echo -e "${YELLOW}⚠ Windows ISO not found in cache${NC}"
        echo -e "${YELLOW}  Expected location: $SYMLINK_PATH${NC}"
        echo ""
        read -p "Download Windows ISO now? (~3GB, takes 5-15 min) [Y/n] " -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Nn]$ ]]; then
            echo -e "${BLUE}Running download script...${NC}"
            echo ""
            ./scripts/download-windows-iso.sh
            if [ $? -eq 0 ]; then
                echo ""
                echo -e "${GREEN}✓ ISO download complete${NC}"
            else
                echo ""
                echo -e "${RED}✗ ISO download failed${NC}"
                echo "You can manually download later with: ./scripts/download-windows-iso.sh"
                echo "Continuing without Windows desktop..."
            fi
        else
            echo -e "${YELLOW}Skipping ISO download. Windows desktop will not be available.${NC}"
            echo "Run later with: ./scripts/download-windows-iso.sh"
        fi
    fi
    echo ""
fi

# Build shared package first (required dependency)
echo -e "${BLUE}Step 4: Building shared package...${NC}"
cd packages/shared
npm install
npm run build
echo -e "${GREEN}✓ Shared package built${NC}"
cd ../..
echo ""

# Build bytebot-cv package (depends on shared)
echo -e "${BLUE}Step 5: Building bytebot-cv package...${NC}"
cd packages/bytebot-cv
# Clean local node_modules if npm install fails
if [ -d "node_modules" ]; then
    echo "Cleaning bytebot-cv node_modules for fresh install..."
    rm -rf node_modules
fi
npm install --no-save
npm run build
echo -e "${GREEN}✓ CV package built${NC}"
cd ../..
echo ""

# Setup OmniParser if needed
echo -e "${BLUE}Step 6: Setting up OmniParser...${NC}"
if [ -f "scripts/setup-omniparser.sh" ]; then
    ./scripts/setup-omniparser.sh
else
    echo -e "${YELLOW}⚠ OmniParser setup script not found, skipping${NC}"
fi
echo ""

# LMStudio Configuration (optional)
echo -e "${BLUE}Step 6.5: LMStudio Model Discovery (optional)${NC}"
echo "LMStudio allows running local VLM models on your network."
read -p "Configure LMStudio models? [y/N]: " setup_lmstudio

if [[ $setup_lmstudio =~ ^[Yy]$ ]]; then
    ./scripts/setup-lmstudio.sh
fi
echo ""

# Start OmniParser for Apple Silicon (native with MPS GPU)
if [[ "$ARCH" == "arm64" ]] && [[ "$PLATFORM" == "macOS" ]]; then
    echo -e "${BLUE}Step 7: Starting native OmniParser (Apple Silicon with MPS GPU)...${NC}"
    if [ -f "scripts/start-omniparser.sh" ]; then
        ./scripts/start-omniparser.sh
        echo ""
        echo "Waiting for OmniParser to be ready..."
        sleep 3

        # Verify OmniParser is running
        if curl -s http://localhost:9989/health > /dev/null 2>&1; then
            echo -e "${GREEN}✓ OmniParser running natively on port 9989${NC}"
        else
            echo -e "${YELLOW}⚠ OmniParser may not be ready yet${NC}"
        fi
    else
        echo -e "${YELLOW}⚠ OmniParser start script not found${NC}"
    fi
    echo ""
else
    echo -e "${BLUE}Step 7: OmniParser will run in Docker container${NC}"
    if [[ "$PLATFORM" == "Windows (WSL)" ]] || [[ "$PLATFORM" == "Linux" ]]; then
        echo -e "${BLUE}(CUDA GPU acceleration if available)${NC}"
    fi
    echo ""
fi

# Build and start Docker stack with fresh build
echo -e "${BLUE}Step 8: Building Docker containers (this may take several minutes)...${NC}"
echo ""

cd docker

# Determine compose file
if [[ -f "docker-compose.proxy.yml" ]]; then
    COMPOSE_FILE="docker-compose.proxy.yml"
    echo -e "${BLUE}Using: Proxy Stack (with LiteLLM)${NC}"
else
    COMPOSE_FILE="docker-compose.yml"
    echo -e "${BLUE}Using: Standard Stack${NC}"
fi

# Build services - now unified across all platforms with x86_64 architecture
echo -e "${BLUE}Building services (forced x86_64 architecture for consistency)...${NC}"

# Determine profile based on platform selection
if [ "$DESKTOP_PLATFORM" = "windows" ]; then
    PROFILE_ARG="--profile omnibox"
    echo -e "${BLUE}Including Windows desktop (OmniBox) services...${NC}"
else
    PROFILE_ARG="--profile linux"
    echo -e "${BLUE}Including Linux desktop (bytebotd) services...${NC}"
fi

if [[ "$ARCH" == "arm64" ]] && [[ "$PLATFORM" == "macOS" ]]; then
    echo -e "${YELLOW}Note: Running via Rosetta 2 on Apple Silicon${NC}"
    echo -e "${BLUE}Building without OmniParser container (using native)...${NC}"
    # Build without OmniParser container (running natively with MPS)
    docker compose $PROFILE_ARG -f $COMPOSE_FILE -f docker-compose.override.yml build \
        $([ "$DESKTOP_PLATFORM" = "windows" ] && echo "omnibox omnibox-adapter" || echo "bytebot-desktop") \
        bytebot-agent \
        bytebot-ui \
        $([ "$COMPOSE_FILE" = "docker-compose.proxy.yml" ] && echo "bytebot-llm-proxy" || echo "")

    echo ""
    echo -e "${BLUE}Starting services...${NC}"
    docker compose $PROFILE_ARG -f $COMPOSE_FILE -f docker-compose.override.yml up -d --no-deps \
        $([ "$DESKTOP_PLATFORM" = "windows" ] && echo "omnibox omnibox-adapter" || echo "bytebot-desktop") \
        bytebot-agent \
        bytebot-ui \
        postgres \
        $([ "$COMPOSE_FILE" = "docker-compose.proxy.yml" ] && echo "bytebot-llm-proxy" || echo "")
else
    # Linux and Windows (WSL) - build everything including OmniParser
    echo -e "${BLUE}Building all services including OmniParser...${NC}"
    docker compose $PROFILE_ARG -f $COMPOSE_FILE -f docker-compose.override.yml up -d --build
fi

cd ..

# Wait for services
echo ""
echo -e "${BLUE}Waiting for services to start...${NC}"
sleep 8

# Check service health
echo ""
echo -e "${BLUE}Service Health Check:${NC}"

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
        echo -e "  ${RED}✗${NC} $service (port $port) - check logs"
        all_healthy=false
    fi
done

echo ""
if $all_healthy; then
    echo -e "${GREEN}================================================${NC}"
    echo -e "${GREEN}   Fresh Build Complete! 🚀${NC}"
    echo -e "${GREEN}================================================${NC}"
else
    echo -e "${YELLOW}================================================${NC}"
    echo -e "${YELLOW}   Build Complete (some services may need time)${NC}"
    echo -e "${YELLOW}================================================${NC}"
fi

echo ""
echo "Services:"
echo "  • UI:        http://localhost:9992"
echo "  • Agent:     http://localhost:9991"
echo "  • Desktop:   http://localhost:9990"
if [[ "$ARCH" == "arm64" ]] && [[ "$PLATFORM" == "macOS" ]]; then
    echo "  • OmniParser: http://localhost:9989 (native with MPS GPU)"
else
    echo "  • OmniParser: http://localhost:9989 (Docker, CUDA if available)"
fi

echo ""
echo -e "${BLUE}Platform Info:${NC}"
echo "  • Detected: $PLATFORM ($ARCH)"
echo "  • Docker:   x86_64 (linux/amd64) via docker-compose.override.yml"

echo ""
echo "View logs:"
echo -e "  ${BLUE}docker compose -f docker/$COMPOSE_FILE logs -f${NC}"
echo ""
echo "Test OmniParser:"
echo -e "  ${BLUE}curl http://localhost:9989/health${NC}"
echo ""
echo "Stop stack:"
echo -e "  ${BLUE}./scripts/stop-stack.sh${NC}"
echo ""
