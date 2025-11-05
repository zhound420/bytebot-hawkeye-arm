#!/bin/bash
# Platform detection script for ARM64 systems
# Detects: Apple Silicon (M1-M4) vs NVIDIA DGX Spark vs Generic ARM64

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo "========================================="
echo " Bytebot Hawkeye ARM64 Platform Detection"
echo "========================================="
echo ""

# Check architecture
ARCH=$(uname -m)
echo -e "${BLUE}Architecture:${NC} $ARCH"

if [[ "$ARCH" != "arm64" && "$ARCH" != "aarch64" ]]; then
    echo -e "${RED}ERROR: Not an ARM64 system${NC}"
    echo "This script is for ARM64 platforms only (Apple Silicon, DGX Spark)"
    exit 1
fi

# Detect platform
PLATFORM="unknown"
GPU_TYPE="none"
RECOMMENDED_DEPLOYMENT="unknown"

# Check for Apple Silicon
if [[ "$(uname -s)" == "Darwin" ]]; then
    PLATFORM="apple_silicon"

    # Detect specific M-series chip
    CHIP=$(sysctl -n machdep.cpu.brand_string 2>/dev/null || echo "Unknown")
    echo -e "${GREEN}Platform:${NC} Apple Silicon (macOS)"
    echo -e "${GREEN}Chip:${NC} $CHIP"

    # Check for MPS support in Python
    if command -v python3 &> /dev/null; then
        MPS_AVAILABLE=$(python3 -c "import torch; print(torch.backends.mps.is_available())" 2>/dev/null || echo "false")
        if [[ "$MPS_AVAILABLE" == "True" ]]; then
            GPU_TYPE="mps"
            echo -e "${GREEN}GPU Acceleration:${NC} MPS (Metal Performance Shaders) ✓"
        else
            GPU_TYPE="cpu"
            echo -e "${YELLOW}GPU Acceleration:${NC} MPS not available (install PyTorch)"
        fi
    fi

    RECOMMENDED_DEPLOYMENT="native"
    echo ""
    echo -e "${BLUE}Recommended Deployment:${NC} Native execution (Docker can't access MPS)"
    echo -e "${BLUE}Expected OmniParser Performance:${NC} ~1-2s/frame with MPS GPU"

# Check for NVIDIA DGX Spark
elif [[ -f /proc/cpuinfo ]] && grep -q "ARM Cortex" /proc/cpuinfo; then
    # Check if NVIDIA GPU present
    if command -v nvidia-smi &> /dev/null; then
        GPU_INFO=$(nvidia-smi --query-gpu=name --format=csv,noheader 2>/dev/null || echo "Unknown NVIDIA GPU")
        PLATFORM="dgx_spark"
        GPU_TYPE="cuda"
        echo -e "${GREEN}Platform:${NC} NVIDIA DGX Spark (ARM64 + CUDA)"
        echo -e "${GREEN}GPU:${NC} $GPU_INFO"
        echo -e "${GREEN}GPU Acceleration:${NC} CUDA ✓"

        # Check CUDA version
        CUDA_VERSION=$(nvidia-smi | grep "CUDA Version" | awk '{print $9}' || echo "Unknown")
        echo -e "${GREEN}CUDA Version:${NC} $CUDA_VERSION"

        RECOMMENDED_DEPLOYMENT="docker"
        echo ""
        echo -e "${BLUE}Recommended Deployment:${NC} Docker with NVIDIA Container Runtime"
        echo -e "${BLUE}Expected OmniParser Performance:${NC} ~0.8-1.5s/frame with CUDA GPU"
    else
        PLATFORM="arm64_generic"
        GPU_TYPE="cpu"
        echo -e "${YELLOW}Platform:${NC} Generic ARM64 Linux (no NVIDIA GPU detected)"
        echo -e "${YELLOW}GPU Acceleration:${NC} None - CPU only"

        RECOMMENDED_DEPLOYMENT="docker"
        echo ""
        echo -e "${BLUE}Recommended Deployment:${NC} Docker (CPU fallback)"
        echo -e "${YELLOW}Expected OmniParser Performance:${NC} ~8-15s/frame (CPU, slow)"
    fi

# Generic ARM64 Linux
else
    PLATFORM="arm64_generic"
    GPU_TYPE="cpu"
    echo -e "${YELLOW}Platform:${NC} Generic ARM64 system"
    echo -e "${YELLOW}GPU Acceleration:${NC} Unknown - likely CPU only"

    RECOMMENDED_DEPLOYMENT="docker"
    echo ""
    echo -e "${BLUE}Recommended Deployment:${NC} Docker"
fi

echo ""
echo "========================================="
echo " Platform Summary"
echo "========================================="
echo -e "Platform Type:      ${GREEN}$PLATFORM${NC}"
echo -e "GPU Acceleration:   ${GREEN}$GPU_TYPE${NC}"
echo -e "Deployment Mode:    ${GREEN}$RECOMMENDED_DEPLOYMENT${NC}"
echo ""

# Export environment variables for other scripts
# Actually export for scripts that source this file
export BYTEBOT_ARM64_PLATFORM="$PLATFORM"
export BYTEBOT_GPU_TYPE="$GPU_TYPE"
export BYTEBOT_DEPLOYMENT_MODE="$RECOMMENDED_DEPLOYMENT"

# Also print for manual evaluation if needed
echo "# Platform detection results (source this file)"
echo "export BYTEBOT_ARM64_PLATFORM=\"$PLATFORM\""
echo "export BYTEBOT_GPU_TYPE=\"$GPU_TYPE\""
echo "export BYTEBOT_DEPLOYMENT_MODE=\"$RECOMMENDED_DEPLOYMENT\""
echo ""

# Platform-specific instructions
echo "========================================="
echo " Next Steps"
echo "========================================="

case "$PLATFORM" in
    apple_silicon)
        echo "1. For best performance, run OmniParser NATIVELY (not in Docker):"
        echo "   cd packages/bytebot-omniparser"
        echo "   bash scripts/setup.sh"
        echo "   python src/server.py"
        echo ""
        echo "2. Run other services in Docker:"
        echo "   docker compose -f docker/docker-compose.yml --profile linux up -d"
        echo ""
        echo "3. See DEPLOYMENT_M4.md for detailed instructions"
        ;;
    dgx_spark)
        echo "1. Your DGX Spark supports CUDA in Docker containers!"
        echo "   ./scripts/start.sh"
        echo ""
        echo "2. GPU passthrough is pre-configured via NVIDIA Container Runtime"
        echo ""
        echo "3. See DEPLOYMENT_DGX_SPARK.md for optimization tips"
        ;;
    arm64_generic)
        echo "1. CPU-only mode will be slow (~8-15s per frame)"
        echo "   ./scripts/start.sh"
        echo ""
        echo "2. Consider running on a GPU-enabled system for production use"
        ;;
    *)
        echo "Unknown platform configuration"
        echo "Please review documentation for manual setup"
        ;;
esac

echo ""
echo "========================================="
