#!/usr/bin/env bash
set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo -e "${BLUE}================================================${NC}"
echo -e "${BLUE}   Bytebot Hawkeye ARM64 - Fresh Build${NC}"
echo -e "${BLUE}================================================${NC}"
echo ""

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"

# Load environment defaults for Docker Compose variable substitution
# This exports variables so ${VAR} syntax in docker-compose.yml works
if [ -f "docker/.env.defaults" ]; then
    set -a  # Auto-export all variables
    source docker/.env.defaults
    set +a  # Stop auto-exporting
fi

#  ═══════════════════════════════════════════════════════
#   Environment Setup
#  ═══════════════════════════════════════════════════════

echo -e "${BLUE}Step 1: Environment configuration...${NC}"

# Create docker/.env if it doesn't exist
if [ ! -f "docker/.env" ]; then
    if [ -f "docker/.env.example" ]; then
        cp docker/.env.example docker/.env
        echo -e "${GREEN}✓ Created docker/.env from template${NC}"
        echo -e "${YELLOW}  You can configure API keys via CLI (prompted later) or UI Settings${NC}"
    else
        echo -e "${YELLOW}⚠ docker/.env.example not found, creating empty docker/.env${NC}"
        touch docker/.env
    fi
else
    echo -e "${GREEN}✓ docker/.env already exists${NC}"
fi

# Generate SETTINGS_ENCRYPTION_KEY if not present in .env.defaults
if ! grep -q "SETTINGS_ENCRYPTION_KEY=" docker/.env.defaults 2>/dev/null; then
    echo -e "${BLUE}Generating encryption key for API key storage...${NC}"

    # Generate secure random 32-character hex key
    if command -v openssl &> /dev/null; then
        ENCRYPTION_KEY=$(openssl rand -hex 16)
    else
        # Fallback: use /dev/urandom
        ENCRYPTION_KEY=$(cat /dev/urandom | tr -dc 'a-f0-9' | fold -w 32 | head -n 1)
    fi

    # Append to .env.defaults
    echo "" >> docker/.env.defaults
    echo "# API Key Encryption (auto-generated)" >> docker/.env.defaults
    echo "SETTINGS_ENCRYPTION_KEY=${ENCRYPTION_KEY}" >> docker/.env.defaults

    echo -e "${GREEN}✓ Generated SETTINGS_ENCRYPTION_KEY${NC}"
    echo -e "${YELLOW}  This key encrypts API keys stored via the UI Settings dialog${NC}"
else
    echo -e "${GREEN}✓ SETTINGS_ENCRYPTION_KEY already configured${NC}"
fi

echo ""

#  ═══════════════════════════════════════════════════════
#   ARM64 Platform Detection
#  ═══════════════════════════════════════════════════════

echo -e "${BLUE}Detecting ARM64 platform...${NC}"

# Call detect-arm64-platform.sh for unified detection
if [ -f "$SCRIPT_DIR/detect-arm64-platform.sh" ]; then
    source "$SCRIPT_DIR/detect-arm64-platform.sh" --silent || true
fi

# Fallback detection if script didn't set variables
if [ -z "$BYTEBOT_ARM64_PLATFORM" ]; then
    ARCH=$(uname -m)
    OS=$(uname -s)

    if [[ "$ARCH" == "arm64" ]] && [[ "$OS" == "Darwin" ]]; then
        BYTEBOT_ARM64_PLATFORM="apple_silicon"
        BYTEBOT_GPU_TYPE="mps"
        BYTEBOT_DEPLOYMENT_MODE="hybrid"
    elif [[ "$ARCH" == "aarch64" ]] || [[ "$ARCH" == "arm64" ]]; then
        # Check for NVIDIA GPU
        if command -v nvidia-smi &> /dev/null && nvidia-smi &> /dev/null; then
            BYTEBOT_ARM64_PLATFORM="dgx_spark"
            BYTEBOT_GPU_TYPE="cuda"
            BYTEBOT_DEPLOYMENT_MODE="docker"
        else
            BYTEBOT_ARM64_PLATFORM="arm64_generic"
            BYTEBOT_GPU_TYPE="cpu"
            BYTEBOT_DEPLOYMENT_MODE="docker"
        fi
    else
        BYTEBOT_ARM64_PLATFORM="x86_64"
        BYTEBOT_GPU_TYPE="cpu"
        BYTEBOT_DEPLOYMENT_MODE="docker"
    fi
fi

case "$BYTEBOT_ARM64_PLATFORM" in
    apple_silicon)
        echo -e "${GREEN}✓ Platform: Apple Silicon (${BYTEBOT_GPU_TYPE})${NC}"
        echo -e "  Deployment: Hybrid (Native OmniParser + Docker)"
        ;;
    dgx_spark)
        echo -e "${GREEN}✓ Platform: NVIDIA DGX Spark (ARM64 + CUDA)${NC}"
        echo -e "  Deployment: Full Docker with GPU"
        ;;
    arm64_generic)
        echo -e "${GREEN}✓ Platform: Generic ARM64 (CPU only)${NC}"
        echo -e "  Deployment: Full Docker"
        ;;
    *)
        echo -e "${YELLOW}✓ Platform: x86_64${NC}"
        echo -e "  Note: This is the ARM64-optimized repository"
        ;;
esac
echo ""

# Interactive Platform Selection
echo -e "${BLUE}Step 2: Desktop Platform Selection${NC}"
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
echo -e "${BLUE}Step 3: Stopping existing services...${NC}"
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

# Update .env.defaults with selected platform and corresponding URLs
if [ -f "docker/.env.defaults" ]; then
    # Update platform setting
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

    # Update desktop URLs based on platform selection
    if [ "$DESKTOP_PLATFORM" = "linux" ]; then
        # Set Linux desktop URLs
        sed -i.bak "s|^BYTEBOT_DESKTOP_VNC_URL=.*|BYTEBOT_DESKTOP_VNC_URL=http://bytebot-desktop:9990/websockify|" docker/.env.defaults
        sed -i.bak "s|^BYTEBOT_DESKTOP_BASE_URL=.*|BYTEBOT_DESKTOP_BASE_URL=http://bytebot-desktop:9990|" docker/.env.defaults
        rm -f docker/.env.defaults.bak
        echo -e "${GREEN}✓ Configured for Linux Desktop (bytebot-desktop:9990)${NC}"
    else
        # Set Windows/OmniBox URLs
        sed -i.bak "s|^BYTEBOT_DESKTOP_VNC_URL=.*|BYTEBOT_DESKTOP_VNC_URL=http://omnibox:8006/websockify|" docker/.env.defaults
        sed -i.bak "s|^BYTEBOT_DESKTOP_BASE_URL=.*|BYTEBOT_DESKTOP_BASE_URL=http://omnibox-adapter:5001|" docker/.env.defaults
        rm -f docker/.env.defaults.bak
        echo -e "${GREEN}✓ Configured for Windows Desktop (omnibox-adapter:5001)${NC}"
    fi
fi
echo ""

# Clean problematic node_modules (OpenCV build artifacts)
echo -e "${BLUE}Step 4: Cleaning node_modules...${NC}"
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

    # Check if OmniBox VM already exists (persistent volume)
    if docker volume ls --format '{{.Name}}' | grep -q "^bytebot_omnibox_data$"; then
        VOLUME_SIZE=$(docker volume inspect bytebot_omnibox_data --format '{{.Mountpoint}}' 2>/dev/null | xargs -I{} du -sh {} 2>/dev/null | cut -f1 || echo "unknown")
        echo -e "${BLUE}Step 3c: OmniBox VM Status${NC}"
        echo -e "${GREEN}✓ Existing Windows installation detected${NC}"
        echo -e "${BLUE}  Volume: bytebot_omnibox_data (${VOLUME_SIZE})${NC}"
        echo -e "${BLUE}  Startup: ~30 seconds (reusing existing VM)${NC}"
        echo ""
        echo -e "${YELLOW}⚠ Reinstall Windows from scratch?${NC}"
        echo "  This will DELETE the existing VM and reinstall Windows (20-90 minutes)"
        echo "  Use this if:"
        echo "    - VM is corrupted or unstable"
        echo "    - Testing fresh Windows installation"
        echo "    - Want to reclaim disk space"
        echo ""
        read -p "Reinstall Windows from scratch? [y/N] " -n 1 -r
        echo
        if [[ $REPLY =~ ^[Yy]$ ]]; then
            echo ""
            echo -e "${RED}⚠⚠⚠ WARNING ⚠⚠⚠${NC}"
            echo -e "${RED}This will PERMANENTLY DELETE all data in the Windows VM!${NC}"
            echo ""
            read -p "Type 'DELETE' to confirm: " confirm
            if [ "$confirm" = "DELETE" ]; then
                echo ""
                echo -e "${BLUE}Removing OmniBox volume...${NC}"
                docker volume rm bytebot_omnibox_data || {
                    echo -e "${YELLOW}Volume might be in use, stopping containers first...${NC}"
                    docker stop bytebot-omnibox bytebot-omnibox-adapter 2>/dev/null || true
                    docker rm bytebot-omnibox bytebot-omnibox-adapter 2>/dev/null || true
                    docker volume rm bytebot_omnibox_data
                }
                echo -e "${GREEN}✓ OmniBox volume deleted${NC}"
                echo -e "${YELLOW}Windows will be installed from scratch (this will take 20-90 minutes)${NC}"
            else
                echo -e "${YELLOW}Cancelled - keeping existing VM${NC}"
            fi
        else
            echo -e "${GREEN}Keeping existing VM (fast startup)${NC}"
        fi
        echo ""
    else
        echo -e "${BLUE}Step 3c: OmniBox VM Status${NC}"
        echo -e "${YELLOW}No existing Windows installation found${NC}"
        echo -e "${BLUE}Windows will be installed from scratch (20-90 minutes on first boot)${NC}"
        echo ""
    fi
fi

# Build shared package first (required dependency)
echo -e "${BLUE}Step 5: Building shared package...${NC}"
cd packages/shared
npm install
npm run build
echo -e "${GREEN}✓ Shared package built${NC}"
cd ../..
echo ""

# Build bytebot-cv package (depends on shared)
echo -e "${BLUE}Step 6: Building bytebot-cv package...${NC}"
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
echo -e "${BLUE}Step 7: Setting up OmniParser...${NC}"
if [ -f "scripts/setup-omniparser.sh" ]; then
    ./scripts/setup-omniparser.sh
else
    echo -e "${YELLOW}⚠ OmniParser setup script not found, skipping${NC}"
fi
echo ""

# LMStudio Configuration (optional)
echo -e "${BLUE}Step 7.5: LMStudio Model Discovery (optional)${NC}"
echo "LMStudio allows running local VLM models on your network."
read -p "Configure LMStudio models? [y/N]: " setup_lmstudio

if [[ $setup_lmstudio =~ ^[Yy]$ ]]; then
    ./scripts/setup-lmstudio.sh || true
fi
echo ""

# Ollama Configuration (optional)
echo -e "${BLUE}Step 7.6: Ollama Model Discovery (optional)${NC}"
echo "Ollama allows running local VLM models on your machine."
read -p "Configure Ollama models? [y/N]: " setup_ollama

if [[ $setup_ollama =~ ^[Yy]$ ]]; then
    ./scripts/setup-ollama.sh || true
fi
echo ""

# Start OmniParser for Apple Silicon (native with MPS GPU)
NATIVE_OMNIPARSER=false

if [ "$BYTEBOT_ARM64_PLATFORM" = "apple_silicon" ]; then
    echo -e "${BLUE}Step 8: Starting native OmniParser (Apple Silicon with MPS GPU)...${NC}"
    if [ -f "scripts/start-omniparser.sh" ]; then
        ./scripts/start-omniparser.sh
        echo ""
        echo "Waiting for OmniParser to be ready..."
        sleep 3

        # Verify OmniParser is running
        if curl -s http://localhost:9989/health > /dev/null 2>&1; then
            echo -e "${GREEN}✓ OmniParser running natively on port 9989${NC}"
            NATIVE_OMNIPARSER=true
        else
            echo -e "${YELLOW}⚠ OmniParser may not be ready yet${NC}"
        fi
    else
        echo -e "${YELLOW}⚠ OmniParser start script not found${NC}"
    fi
    echo ""
elif [ "$BYTEBOT_ARM64_PLATFORM" = "dgx_spark" ]; then
    echo -e "${BLUE}Step 8: OmniParser will run in Docker with CUDA (ARM64)${NC}"
    echo -e "${GREEN}  → DGX Spark detected: ARM64 + NVIDIA GPU${NC}"
    echo ""
else
    echo -e "${BLUE}Step 8: OmniParser will run in Docker container${NC}"
    if [ "$BYTEBOT_GPU_TYPE" = "cuda" ]; then
        echo -e "${GREEN}  → NVIDIA GPU acceleration enabled${NC}"
    elif [ "$BYTEBOT_GPU_TYPE" = "cpu" ]; then
        echo -e "${YELLOW}  → CPU-only mode (slower)${NC}"
    fi
    echo ""
fi

# Build and start Docker stack with fresh build
echo -e "${BLUE}Step 10: Building Docker containers (this may take several minutes)...${NC}"
echo ""

cd docker

# Determine compose files
COMPOSE_FILES="-f docker-compose.yml"

if [[ -f "docker-compose.proxy.yml" ]]; then
    COMPOSE_FILES="$COMPOSE_FILES -f docker-compose.proxy.yml"
    echo -e "${BLUE}Using: Proxy Stack (with LiteLLM)${NC}"
    USING_PROXY=true
else
    echo -e "${BLUE}Using: Standard Stack${NC}"
    USING_PROXY=false
fi

# Add ARM64-specific compose file for DGX Spark and ARM64 generic
if [ "$BYTEBOT_ARM64_PLATFORM" = "dgx_spark" ] || [ "$BYTEBOT_ARM64_PLATFORM" = "arm64_generic" ]; then
    if [ -f "docker-compose.arm64.yml" ]; then
        COMPOSE_FILES="$COMPOSE_FILES -f docker-compose.arm64.yml"
        echo -e "${GREEN}✓ Using ARM64 platform overrides${NC}"
    fi
fi

# Determine profile based on platform selection
if [ "$DESKTOP_PLATFORM" = "windows" ]; then
    PROFILE_ARG="--profile omnibox"
    echo -e "${BLUE}Including Windows desktop (OmniBox) services...${NC}"
else
    PROFILE_ARG="--profile linux"
    echo -e "${BLUE}Including Linux desktop (bytebotd) services...${NC}"
fi

echo ""

if [ "$BYTEBOT_ARM64_PLATFORM" = "apple_silicon" ] && [ "$NATIVE_OMNIPARSER" = true ]; then
    echo -e "${BLUE}Building without OmniParser container (using native with MPS)...${NC}"
    # Build without OmniParser container (running natively with MPS)
    docker compose $PROFILE_ARG $COMPOSE_FILES build \
        $([ "$DESKTOP_PLATFORM" = "windows" ] && echo "omnibox omnibox-adapter" || echo "bytebot-desktop") \
        bytebot-agent \
        bytebot-ui \
        $([ "$USING_PROXY" = true ] && echo "bytebot-llm-proxy" || echo "")

    echo ""
    echo -e "${BLUE}Starting services...${NC}"

    # For Windows: start in background and monitor
    if [ "$DESKTOP_PLATFORM" = "windows" ]; then
        docker compose $PROFILE_ARG $COMPOSE_FILES up -d --no-deps \
            omnibox omnibox-adapter \
            bytebot-agent \
            bytebot-ui \
            postgres \
            $([ "$USING_PROXY" = true ] && echo "bytebot-llm-proxy" || echo "") &
        COMPOSE_PID=$!

        cd ..

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
        docker compose $PROFILE_ARG $COMPOSE_FILES up -d --no-deps \
            bytebot-desktop \
            bytebot-agent \
            bytebot-ui \
            postgres \
            $([ "$USING_PROXY" = true ] && echo "bytebot-llm-proxy" || echo "")
        cd ..
    fi
else
    # DGX Spark, ARM64 generic, x86_64 - build everything including OmniParser
    echo -e "${BLUE}Building all services including OmniParser...${NC}"
    if [ "$BYTEBOT_ARM64_PLATFORM" = "dgx_spark" ]; then
        echo -e "${GREEN}  → Using ARM64 + CUDA optimizations${NC}"
    fi

    # For Windows: start docker compose in background, then monitor progress
    if [ "$DESKTOP_PLATFORM" = "windows" ]; then
        # Start docker compose in background (will wait for health checks)
        docker compose $PROFILE_ARG $COMPOSE_FILES up -d --build &
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
        # Linux/ARM64: run docker compose normally (foreground)
        docker compose $PROFILE_ARG $COMPOSE_FILES up -d --build
        cd ..
    fi
fi

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

#  ═══════════════════════════════════════════════════════
#   API Key Configuration (Hybrid CLI/GUI)
#  ═══════════════════════════════════════════════════════

echo ""
echo -e "${BLUE}================================================${NC}"
echo -e "${BLUE}   API Key Configuration${NC}"
echo -e "${BLUE}================================================${NC}"
echo ""
echo "Bytebot requires at least one LLM API key to function."
echo ""
echo "You have two options:"
echo "  1) Configure now via CLI (quick setup)"
echo "  2) Configure later via UI Settings dialog (recommended)"
echo ""

read -p "Would you like to configure API keys now via CLI? [y/N]: " configure_keys

KEYS_CONFIGURED=false

if [[ $configure_keys =~ ^[Yy]$ ]]; then
    echo ""
    echo -e "${YELLOW}Enter your API keys below (press Enter to skip any key):${NC}"
    echo ""

    # Prompt for each API key
    read -p "ANTHROPIC_API_KEY (Claude): " anthropic_key
    read -p "OPENAI_API_KEY (GPT-4): " openai_key
    read -p "GEMINI_API_KEY (Gemini): " gemini_key
    read -p "OPENROUTER_API_KEY (Multi-model): " openrouter_key

    # Write keys to docker/.env (only non-empty values)
    KEYS_ADDED=0

    if [ -n "$anthropic_key" ]; then
        # Check if key already exists in .env
        if grep -q "^ANTHROPIC_API_KEY=" docker/.env 2>/dev/null; then
            sed -i.bak "s|^ANTHROPIC_API_KEY=.*|ANTHROPIC_API_KEY=$anthropic_key|" docker/.env
        else
            echo "ANTHROPIC_API_KEY=$anthropic_key" >> docker/.env
        fi
        KEYS_ADDED=$((KEYS_ADDED + 1))
        echo -e "${GREEN}✓ Anthropic API key saved${NC}"
    fi

    if [ -n "$openai_key" ]; then
        if grep -q "^OPENAI_API_KEY=" docker/.env 2>/dev/null; then
            sed -i.bak "s|^OPENAI_API_KEY=.*|OPENAI_API_KEY=$openai_key|" docker/.env
        else
            echo "OPENAI_API_KEY=$openai_key" >> docker/.env
        fi
        KEYS_ADDED=$((KEYS_ADDED + 1))
        echo -e "${GREEN}✓ OpenAI API key saved${NC}"
    fi

    if [ -n "$gemini_key" ]; then
        if grep -q "^GEMINI_API_KEY=" docker/.env 2>/dev/null; then
            sed -i.bak "s|^GEMINI_API_KEY=.*|GEMINI_API_KEY=$gemini_key|" docker/.env
        else
            echo "GEMINI_API_KEY=$gemini_key" >> docker/.env
        fi
        KEYS_ADDED=$((KEYS_ADDED + 1))
        echo -e "${GREEN}✓ Gemini API key saved${NC}"
    fi

    if [ -n "$openrouter_key" ]; then
        if grep -q "^OPENROUTER_API_KEY=" docker/.env 2>/dev/null; then
            sed -i.bak "s|^OPENROUTER_API_KEY=.*|OPENROUTER_API_KEY=$openrouter_key|" docker/.env
        else
            echo "OPENROUTER_API_KEY=$openrouter_key" >> docker/.env
        fi
        KEYS_ADDED=$((KEYS_ADDED + 1))
        echo -e "${GREEN}✓ OpenRouter API key saved${NC}"
    fi

    # Clean up backup files
    rm -f docker/.env.bak

    if [ $KEYS_ADDED -gt 0 ]; then
        KEYS_CONFIGURED=true
        echo ""
        echo -e "${GREEN}✓ $KEYS_ADDED API key(s) configured${NC}"
        echo -e "${BLUE}Restarting bytebot-agent to load new keys...${NC}"

        cd docker
        docker compose $PROFILE_ARG $COMPOSE_FILES restart bytebot-agent
        cd ..

        echo -e "${GREEN}✓ Agent restarted${NC}"
    else
        echo ""
        echo -e "${YELLOW}No API keys were entered${NC}"
    fi
else
    echo ""
    echo -e "${YELLOW}Skipping CLI configuration${NC}"
fi

echo ""
if [ "$KEYS_CONFIGURED" = false ]; then
    echo -e "${YELLOW}⚠️  No API keys configured yet${NC}"
    echo ""
    echo "To configure API keys:"
    echo "  1. Open: http://localhost:9992"
    echo "  2. Click the Settings icon (⚙️) in the header"
    echo "  3. Enter your API keys and click 'Save'"
    echo ""
fi

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
