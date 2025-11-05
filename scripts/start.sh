#!/bin/bash

set -e

# Colors for output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
RED='\033[0;31m'
NC='\033[0m' # No Color

# Default values
DOCKER_COMPOSE_FILE="docker/docker-compose.yml"
DOCKER_COMPOSE_PROXY="docker/docker-compose.proxy.yml"
DOCKER_COMPOSE_ARM64="docker/docker-compose.arm64.yml"
ENV_FILE="docker/.env"
ENV_DEFAULTS="docker/.env.defaults"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"

echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${BLUE}  Bytebot Hawkeye ARM64 - Unified Startup${NC}"
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo

# Load environment defaults for Docker Compose variable substitution
if [ -f "$ENV_DEFAULTS" ]; then
    set -a  # Auto-export all variables
    source "$ENV_DEFAULTS"
    set +a  # Stop auto-exporting
fi

#  ═══════════════════════════════════════════════════════
#   ARM64 Platform Detection
#  ═══════════════════════════════════════════════════════

echo -e "${BLUE}🔍 Detecting ARM64 platform...${NC}"

# Call detect-arm64-platform.sh for unified detection
if [ -f "$SCRIPT_DIR/detect-arm64-platform.sh" ]; then
    # Source the detection script to get environment variables
    source "$SCRIPT_DIR/detect-arm64-platform.sh" --silent || true

    if [ -n "$BYTEBOT_ARM64_PLATFORM" ]; then
        case "$BYTEBOT_ARM64_PLATFORM" in
            apple_silicon)
                echo -e "${GREEN}  → Platform: Apple Silicon (${BYTEBOT_GPU_TYPE})${NC}"
                echo -e "${CYAN}  → Deployment: Hybrid (Native OmniParser + Docker)${NC}"
                ARM64_PLATFORM="apple_silicon"
                ;;
            dgx_spark)
                echo -e "${GREEN}  → Platform: NVIDIA DGX Spark (ARM64 + CUDA)${NC}"
                echo -e "${CYAN}  → Deployment: Full Docker with GPU${NC}"
                ARM64_PLATFORM="dgx_spark"
                ;;
            arm64_generic)
                echo -e "${GREEN}  → Platform: Generic ARM64 (CPU only)${NC}"
                echo -e "${CYAN}  → Deployment: Full Docker${NC}"
                ARM64_PLATFORM="arm64_generic"
                ;;
            *)
                echo -e "${YELLOW}  → Platform: ${BYTEBOT_ARM64_PLATFORM} (unrecognized)${NC}"
                ARM64_PLATFORM="unknown"
                ;;
        esac
    else
        # Fallback to manual detection if script didn't set variable
        ARCH=$(uname -m)
        OS=$(uname -s)

        if [[ "$ARCH" == "arm64" ]] && [[ "$OS" == "Darwin" ]]; then
            echo -e "${GREEN}  → Platform: Apple Silicon (detected)${NC}"
            ARM64_PLATFORM="apple_silicon"
            BYTEBOT_ARM64_PLATFORM="apple_silicon"
            BYTEBOT_GPU_TYPE="mps"
        elif [[ "$ARCH" == "aarch64" ]] || [[ "$ARCH" == "arm64" ]]; then
            # Check for NVIDIA GPU on ARM64
            if command -v nvidia-smi &> /dev/null && nvidia-smi &> /dev/null; then
                echo -e "${GREEN}  → Platform: ARM64 with NVIDIA GPU (DGX Spark?)${NC}"
                ARM64_PLATFORM="dgx_spark"
                BYTEBOT_ARM64_PLATFORM="dgx_spark"
                BYTEBOT_GPU_TYPE="cuda"
            else
                echo -e "${GREEN}  → Platform: Generic ARM64${NC}"
                ARM64_PLATFORM="arm64_generic"
                BYTEBOT_ARM64_PLATFORM="arm64_generic"
                BYTEBOT_GPU_TYPE="cpu"
            fi
        else
            echo -e "${YELLOW}  → Platform: x86_64 (not ARM64)${NC}"
            echo -e "${CYAN}  → Note: This is the ARM64-optimized repository${NC}"
            ARM64_PLATFORM="x86_64"
        fi
    fi
else
    echo -e "${YELLOW}  → detect-arm64-platform.sh not found, using fallback detection${NC}"
    ARCH=$(uname -m)
    OS=$(uname -s)

    if [[ "$ARCH" == "arm64" ]] && [[ "$OS" == "Darwin" ]]; then
        ARM64_PLATFORM="apple_silicon"
    elif [[ "$ARCH" == "aarch64" ]] || [[ "$ARCH" == "arm64" ]]; then
        ARM64_PLATFORM="arm64_generic"
    else
        ARM64_PLATFORM="x86_64"
    fi
fi

echo

#  ═══════════════════════════════════════════════════════
#   Desktop Platform Selection
#  ═══════════════════════════════════════════════════════

# Check if BYTEBOT_FORCE_DESKTOP is set
if [ -n "$BYTEBOT_FORCE_DESKTOP" ]; then
    echo -e "${YELLOW}⚙ Manual desktop override: ${BYTEBOT_FORCE_DESKTOP}${NC}"
    DESKTOP_PLATFORM="$BYTEBOT_FORCE_DESKTOP"
else
    # Check for Windows desktop support (KVM + ISO)
    WINDOWS_AVAILABLE=false
    if [ -e "/dev/kvm" ]; then
        echo -e "${BLUE}🔍 Checking Windows desktop support...${NC}"
        echo -e "${GREEN}  → KVM detected (/dev/kvm)${NC}"

        # Check for Windows ISO
        ISO_PATH="$HOME/.cache/bytebot/iso/tiny11.iso"
        SYMLINK_PATH="$HOME/.cache/bytebot/iso/windows.iso"

        if [ -f "$ISO_PATH" ] || [ -L "$SYMLINK_PATH" ]; then
            if [ -L "$SYMLINK_PATH" ] && [ -e "$SYMLINK_PATH" ]; then
                echo -e "${GREEN}  → Windows ISO found (symlink): $SYMLINK_PATH${NC}"
            else
                echo -e "${GREEN}  → Windows ISO found: $ISO_PATH${NC}"
            fi
            WINDOWS_AVAILABLE=true
        else
            echo -e "${YELLOW}  → Windows ISO not found${NC}"
            echo -e "${CYAN}  → Run ./scripts/download-windows-iso.sh to enable Windows desktop${NC}"
        fi
    fi

    # Interactive platform selection
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
                DESKTOP_PLATFORM="windows"
                ;;
            *)
                echo -e "${GREEN}  → Selected: Linux desktop${NC}"
                DESKTOP_PLATFORM="linux"
                ;;
        esac
    else
        echo -e "${GREEN}  → Desktop: Linux (default)${NC}"
        DESKTOP_PLATFORM="linux"
    fi
fi

echo

#  ═══════════════════════════════════════════════════════
#   Apple Silicon: Native OmniParser Setup
#  ═══════════════════════════════════════════════════════

NATIVE_OMNIPARSER=false

if [ "$ARM64_PLATFORM" = "apple_silicon" ]; then
    echo -e "${BLUE}🍎 Apple Silicon Configuration${NC}"
    echo

    # Check if native OmniParser is running
    if lsof -Pi :9989 -sTCP:LISTEN -t >/dev/null 2>&1; then
        echo -e "${GREEN}✓ Native OmniParser detected on port 9989${NC}"
        NATIVE_OMNIPARSER=true

        # Update environment to use native OmniParser
        if grep -q "OMNIPARSER_URL=http://bytebot-omniparser:9989" "$ENV_DEFAULTS" 2>/dev/null; then
            sed -i.bak 's|OMNIPARSER_URL=http://bytebot-omniparser:9989|OMNIPARSER_URL=http://host.docker.internal:9989|' "$ENV_DEFAULTS"
            rm -f "$ENV_DEFAULTS.bak"
            echo -e "${CYAN}  → Docker services will use native OmniParser${NC}"
        fi
    else
        echo -e "${YELLOW}⚠ Native OmniParser not running${NC}"
        echo

        # Check if OmniParser has been set up
        if [[ ! -d "$PROJECT_ROOT/packages/bytebot-omniparser/venv" ]] && \
           [[ ! -d "$PROJECT_ROOT/packages/bytebot-omniparser/weights/icon_detect" ]]; then
            echo -e "${BLUE}→ Setting up native OmniParser (recommended for MPS GPU)...${NC}"
            echo
            "$SCRIPT_DIR/setup-omniparser.sh" || true
        fi

        echo
        echo -e "${BLUE}→ Starting native OmniParser...${NC}"
        "$SCRIPT_DIR/start-omniparser.sh" || true

        echo
        echo "Waiting for OmniParser to be ready..."
        sleep 3

        # Verify it started
        if lsof -Pi :9989 -sTCP:LISTEN -t >/dev/null 2>&1; then
            echo -e "${GREEN}✓ Native OmniParser started successfully${NC}"
            NATIVE_OMNIPARSER=true

            # Update environment
            if grep -q "OMNIPARSER_URL=http://bytebot-omniparser:9989" "$ENV_DEFAULTS" 2>/dev/null; then
                sed -i.bak 's|OMNIPARSER_URL=http://bytebot-omniparser:9989|OMNIPARSER_URL=http://host.docker.internal:9989|' "$ENV_DEFAULTS"
                rm -f "$ENV_DEFAULTS.bak"
            fi
        else
            echo -e "${RED}✗ Failed to start native OmniParser${NC}"
            echo -e "${YELLOW}  → Will attempt to use Docker OmniParser instead${NC}"
            NATIVE_OMNIPARSER=false
        fi
    fi

    # Optional: LMStudio and Ollama configuration
    echo
    echo -e "${BLUE}Optional: Local VLM Configuration${NC}"
    echo
    read -p "Configure LMStudio models? [y/N]: " setup_lmstudio
    if [[ $setup_lmstudio =~ ^[Yy]$ ]]; then
        "$SCRIPT_DIR/setup-lmstudio.sh" || true
    fi

    read -p "Configure Ollama models? [y/N]: " setup_ollama
    if [[ $setup_ollama =~ ^[Yy]$ ]]; then
        "$SCRIPT_DIR/setup-ollama.sh" || true
    fi

    echo
fi

#  ═══════════════════════════════════════════════════════
#   Configuration Summary
#  ═══════════════════════════════════════════════════════

# Set Docker Compose profile and URLs based on desktop platform
case "$DESKTOP_PLATFORM" in
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

# Determine which compose files to use
COMPOSE_FILES="-f $DOCKER_COMPOSE_FILE"

# Use proxy stack if available
if [ -f "$DOCKER_COMPOSE_PROXY" ]; then
    COMPOSE_FILES="$COMPOSE_FILES -f $DOCKER_COMPOSE_PROXY"
    USING_PROXY=true
else
    USING_PROXY=false
fi

# Add ARM64-specific overrides if applicable
if [ "$ARM64_PLATFORM" = "dgx_spark" ] || [ "$ARM64_PLATFORM" = "arm64_generic" ]; then
    if [ -f "$DOCKER_COMPOSE_ARM64" ]; then
        COMPOSE_FILES="$COMPOSE_FILES -f $DOCKER_COMPOSE_ARM64"
    fi
fi

echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${BLUE}  Configuration Summary${NC}"
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "  ARM64 Platform:   ${GREEN}$ARM64_PLATFORM${NC}"
if [ -n "$BYTEBOT_GPU_TYPE" ]; then
    echo -e "  GPU Type:         ${GREEN}$BYTEBOT_GPU_TYPE${NC}"
fi
echo -e "  Desktop:          ${GREEN}$DESKTOP_PLATFORM${NC}"
echo -e "  Docker Profile:   ${GREEN}$COMPOSE_PROFILES${NC}"
if [ "$NATIVE_OMNIPARSER" = true ]; then
    echo -e "  OmniParser:       ${GREEN}Native (MPS GPU)${NC}"
else
    echo -e "  OmniParser:       ${CYAN}Docker container${NC}"
fi
if [ "$USING_PROXY" = true ]; then
    echo -e "  LLM Proxy:        ${GREEN}Enabled (LiteLLM)${NC}"
fi
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo

#  ═══════════════════════════════════════════════════════
#   Update Environment Configuration
#  ═══════════════════════════════════════════════════════

echo -e "${BLUE}⚙ Updating environment configuration...${NC}"

# Create or update .env file (preserves other settings)
if [ -f "$ENV_FILE" ]; then
    # Update existing .env
    for var in "BYTEBOT_DESKTOP_PLATFORM" "BYTEBOT_DESKTOP_BASE_URL" "BYTEBOT_ARM64_PLATFORM" "BYTEBOT_GPU_TYPE"; do
        value="${!var}"
        if [ -n "$value" ]; then
            if grep -q "^${var}=" "$ENV_FILE"; then
                sed -i.bak "s|^${var}=.*|${var}=$value|" "$ENV_FILE"
                rm -f "$ENV_FILE.bak"
            else
                echo "${var}=$value" >> "$ENV_FILE"
            fi
        fi
    done
else
    # Create new .env from defaults
    cp "$ENV_DEFAULTS" "$ENV_FILE"
    echo "BYTEBOT_DESKTOP_PLATFORM=$DESKTOP_PLATFORM" >> "$ENV_FILE"
    echo "BYTEBOT_DESKTOP_BASE_URL=$DESKTOP_BASE_URL" >> "$ENV_FILE"
    echo "BYTEBOT_ARM64_PLATFORM=$ARM64_PLATFORM" >> "$ENV_FILE"
    if [ -n "$BYTEBOT_GPU_TYPE" ]; then
        echo "BYTEBOT_GPU_TYPE=$BYTEBOT_GPU_TYPE" >> "$ENV_FILE"
    fi
fi

echo -e "${GREEN}  ✓ Configuration saved to $ENV_FILE${NC}"
echo

#  ═══════════════════════════════════════════════════════
#   Start Docker Services
#  ═══════════════════════════════════════════════════════

echo -e "${BLUE}🚀 Starting Bytebot Hawkeye stack...${NC}"
echo -e "   ${BLUE}Profile: $COMPOSE_PROFILES${NC}"
echo

cd "$PROJECT_ROOT"

# Export profile for docker compose
export COMPOSE_PROFILES="$COMPOSE_PROFILES"

# For Apple Silicon with native OmniParser, exclude the container
if [ "$NATIVE_OMNIPARSER" = true ]; then
    echo -e "${CYAN}Starting Docker services (excluding OmniParser container)...${NC}"

    if [ "$DESKTOP_PLATFORM" = "windows" ]; then
        # Windows desktop services
        docker compose $COMPOSE_FILES up -d --build --no-deps \
            omnibox omnibox-adapter \
            bytebot-agent \
            bytebot-ui \
            postgres \
            $([ "$USING_PROXY" = true ] && echo "bytebot-llm-proxy" || echo "")
    else
        # Linux desktop services
        docker compose $COMPOSE_FILES up -d --build --no-deps \
            bytebot-desktop \
            bytebot-agent \
            bytebot-ui \
            postgres \
            $([ "$USING_PROXY" = true ] && echo "bytebot-llm-proxy" || echo "")
    fi
else
    # Start all services including OmniParser container
    docker compose $COMPOSE_FILES up -d --build
fi

echo
echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${GREEN}  ✓ Bytebot Hawkeye started successfully!${NC}"
echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo
echo -e "${BLUE}Access Points:${NC}"
echo -e "  • Web UI:           ${GREEN}http://localhost:9992${NC}"
echo -e "  • Agent API:        ${GREEN}http://localhost:9991${NC}"
echo -e "  • Desktop Daemon:   ${GREEN}http://localhost:9990${NC}"

if [ "$NATIVE_OMNIPARSER" = true ]; then
    echo -e "  • OmniParser:       ${GREEN}http://localhost:9989${NC} ${CYAN}(native, MPS GPU)${NC}"
else
    echo -e "  • OmniParser:       ${GREEN}http://localhost:9989${NC} ${CYAN}(Docker)${NC}"
fi

if [ "$USING_PROXY" = true ]; then
    echo -e "  • LLM Proxy:        ${GREEN}http://localhost:8000${NC}"
fi

if [ "$DESKTOP_PLATFORM" = "windows" ]; then
    echo -e "  • Windows VNC:      ${GREEN}http://localhost:5000${NC}"
    echo
    echo -e "${YELLOW}Note: Windows VM may take 2-10 minutes to boot${NC}"
    echo -e "${CYAN}Monitor startup: ./scripts/monitor-omnibox.sh${NC}"
else
    echo -e "  • Linux VNC:        ${GREEN}http://localhost:8081${NC}"
fi

echo
echo -e "${BLUE}Platform Info:${NC}"
echo -e "  • ARM64 Platform:   ${GREEN}$ARM64_PLATFORM${NC}"
if [ -n "$BYTEBOT_GPU_TYPE" ]; then
    echo -e "  • GPU:              ${GREEN}$BYTEBOT_GPU_TYPE${NC}"
fi
echo -e "  • Deployment:       ${CYAN}$([ "$NATIVE_OMNIPARSER" = true ] && echo "Hybrid (Native + Docker)" || echo "Full Docker")${NC}"

echo
echo -e "${BLUE}Useful Commands:${NC}"
echo -e "  • View logs:      ${GREEN}docker compose $COMPOSE_FILES logs -f${NC}"
echo -e "  • Stop stack:     ${GREEN}./scripts/stop-stack.sh${NC}"
echo -e "  • Restart:        ${GREEN}$0${NC}"

echo
echo -e "${BLUE}Force Options:${NC}"
echo -e "  • Force Linux:    ${GREEN}BYTEBOT_FORCE_DESKTOP=linux $0${NC}"
echo -e "  • Force Windows:  ${GREEN}BYTEBOT_FORCE_DESKTOP=windows $0${NC}"

echo
echo -e "${CYAN}For platform-specific documentation:${NC}"
case "$ARM64_PLATFORM" in
    apple_silicon)
        echo -e "  → See ${GREEN}DEPLOYMENT_M4.md${NC}"
        ;;
    dgx_spark)
        echo -e "  → See ${GREEN}DEPLOYMENT_DGX_SPARK.md${NC}"
        ;;
    arm64_generic)
        echo -e "  → See ${GREEN}ARCHITECTURE_ARM64.md${NC}"
        ;;
esac

echo
