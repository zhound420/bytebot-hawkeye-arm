<div align="center">

<img src="docs/images/bytebot-logo.png" width="500" alt="Bytebot Logo">

# Bytebot Hawkeye ARM64: Multi-Platform AI Desktop Agent

[![GitHub](https://img.shields.io/badge/GitHub-bytebot--hawkeye--arm-blue?logo=github)](https://github.com/zhound420/bytebot-hawkeye-arm)
[![License](https://img.shields.io/badge/License-Apache%202.0-blue.svg)](LICENSE)

**ARM64-optimized AI desktop agent for Apple Silicon (M1-M4) and NVIDIA DGX Spark**
**GPU-accelerated computer vision with 89% click accuracy on ARM64 architectures**

</div>

---

## 🎯 ARM64-Optimized Fork

This is the **ARM64-optimized variant** of Bytebot Hawkeye, specifically designed for:

- **🍎 Apple Silicon (M1-M4)** - MPS GPU acceleration via native execution (~1-2s/frame)
- **⚡ NVIDIA DGX Spark** - ARM64 + CUDA in Docker containers (~0.8-1.5s/frame)
- **🔧 Generic ARM64** - CPU fallback support for compatibility

### Why ARM64?

- **Native Performance**: Full GPU acceleration on Apple Silicon (MPS) and DGX Spark (CUDA)
- **Unified Memory**: Efficient memory sharing on both platforms (128GB on DGX Spark!)
- **Power Efficiency**: Lower power consumption vs x86_64 while maintaining performance
- **Future-Proof**: ARM64 is the future for AI workloads (Apple, NVIDIA, AWS Graviton)

### Prerequisites

#### System Requirements

- **Architecture**: ARM64 (Apple Silicon M1-M4, NVIDIA DGX Spark, or Generic ARM64)
- **RAM**: 16GB minimum, 32GB+ recommended for production
- **Storage**: 20GB free space (10GB for models + 10GB for services)

#### Required Software

**Core Dependencies:**
- **Node.js** ≥20.0.0 - [Download](https://nodejs.org/)
- **Git** - For cloning the repository
- **Docker**:
  - **macOS**: Docker Desktop 4.25+ with ARM64 support - [Download](https://www.docker.com/products/docker-desktop)
  - **Linux**: Docker + nvidia-container-toolkit (for GPU) - [Install Guide](https://docs.docker.com/engine/install/)
  - **DGX Spark**: Preinstalled (DGX OS includes Docker + NVIDIA Container Runtime)

**Optional (Platform-Specific):**
- **Python 3.12** - Only for Apple Silicon native OmniParser (MPS GPU acceleration)

#### Required API Keys

At least **one** LLM provider API key:
- **Anthropic** (Claude models) - [Get key](https://console.anthropic.com)
- **OpenAI** (GPT models) - [Get key](https://platform.openai.com)
- **Google** (Gemini models) - [Get key](https://aistudio.google.com)
- **OpenRouter** (Multi-model proxy) - [Get key](https://openrouter.ai)

#### Platform-Specific Notes

| Platform | Requirements | Notes |
|----------|-------------|-------|
| **Apple Silicon** | Docker Desktop + Python 3.12 | Native OmniParser uses MPS GPU (~1-2s/frame) |
| **DGX Spark** | Pre-configured | Everything ready out-of-box with CUDA (~0.8-1.5s/frame) |
| **Generic ARM64** | Docker only | CPU-only OmniParser (~8-15s/frame, slower) |

#### Quick Verification

```bash
# Check prerequisites
node --version        # Should be v20.x.x or higher
docker --version      # Docker installed
python3 --version     # 3.12.x (Apple Silicon only)
uname -m              # Should show: arm64 or aarch64
```

### Installation

```bash
# Clone the repository
git clone https://github.com/zhound420/bytebot-hawkeye-arm.git
cd bytebot-hawkeye-arm

# Install dependencies
npm install
```

---

## 🚀 Supported Platforms

| Platform | GPU Acceleration | Deployment | Performance | Recommended For |
|----------|-----------------|------------|-------------|-----------------|
| **Apple Silicon (M1-M4)** | ✅ MPS (Metal) | Native execution | ~1-2s/frame | Development, testing on MacBook |
| **NVIDIA DGX Spark** | ✅ CUDA on ARM64 | Docker containers | ~0.8-1.5s/frame | Production, high-performance inference |
| **Generic ARM64 Linux** | ❌ CPU only | Docker containers | ~8-15s/frame | Compatibility testing |

---

## 📦 Quick Start

### Automated Setup (Recommended)

**Option 1: Fresh Build (First-Time Setup)**

```bash
# One command does everything
./scripts/fresh-build.sh

# What it does:
# - Auto-detects: Apple Silicon, DGX Spark, or Generic ARM64
# - Builds: shared → bytebot-cv → OmniParser → Docker services
# - Prompts: Desktop platform, LMStudio/Ollama setup
# - Starts: All services with platform-specific optimizations
```

**Option 2: Quick Start (After Fresh Build)**

```bash
# Quick restart of services
./scripts/start.sh

# What it does:
# - Auto-detects ARM64 platform
# - Apple Silicon: Starts native OmniParser + Docker services
# - DGX Spark: Full Docker with ARM64 + CUDA
# - Generic ARM64: Full Docker with CPU fallback
```

### Platform Detection (Diagnostic)

```bash
# Identify your ARM64 platform
./scripts/detect-arm64-platform.sh

# Output shows:
# - Platform type (Apple Silicon / DGX Spark / Generic ARM64)
# - GPU availability (MPS / CUDA / CPU)
# - Recommended deployment mode
# - Expected performance
```

### What Happens Automatically

| Platform | Deployment | OmniParser | Docker Services |
|----------|-----------|------------|-----------------|
| **Apple Silicon** | Hybrid | Native with MPS GPU (~1-2s/frame) | ✅ All other services |
| **DGX Spark** | Full Docker | Container with CUDA (~0.8-1.5s/frame) | ✅ All services |
| **Generic ARM64** | Full Docker | Container with CPU (~8-15s/frame) | ✅ All services |

### Manual Service Control

```bash
# Stop all services
./scripts/stop-stack.sh

# Apple Silicon only: Manage native OmniParser
./scripts/start-omniparser.sh  # Start with MPS GPU
./scripts/stop-omniparser.sh   # Stop
```

### Platform-Specific Guides

For detailed setup and optimization:
- **Apple Silicon (M1-M4)**: See [DEPLOYMENT_M4.md](DEPLOYMENT_M4.md)
- **DGX Spark**: See [DEPLOYMENT_DGX_SPARK.md](DEPLOYMENT_DGX_SPARK.md)
- **Architecture Details**: See [ARCHITECTURE_ARM64.md](ARCHITECTURE_ARM64.md)

---

## 🏗️ Architecture Overview

This fork maintains the full Bytebot Hawkeye feature set while adding ARM64 platform support:

### Core Components

1. **bytebot-agent** - NestJS API server with Claude/GPT integration
2. **bytebot-ui** - Next.js frontend with real-time desktop view
3. **bytebotd** - Desktop control daemon (Linux X11/XFCE)
4. **bytebot-omniparser** - OmniParser v2.0 with ARM64 GPU support
5. **bytebot-cv** - Computer vision package (Tesseract.js OCR)
6. **bytebot-llm-proxy** - LiteLLM multi-provider routing

### ARM64 Enhancements

- **Multi-Platform GPU Detection**: Auto-detects MPS (Apple Silicon) vs CUDA (DGX Spark) vs CPU
- **Platform-Aware PyTorch**: ARM64 CUDA PyTorch for DGX Spark, standard PyTorch for Apple Silicon native
- **Docker Multi-Architecture**: Builds for both linux/arm64 and linux/amd64
- **Optimized Performance Profiles**: Device-specific batch sizes for MPS vs CUDA vs CPU

**See [ARCHITECTURE_ARM64.md](ARCHITECTURE_ARM64.md) for technical details**

---

## 🎯 Precision Features (All Preserved!)

This ARM64 fork includes **all Hawkeye precision features**:

- **Smart Focus System**: 3-stage coarse→focus→click workflow
- **OmniParser v2.0**: Semantic UI detection (YOLOv8 + Florence-2)
- **Universal Coordinates**: Cross-application element positioning
- **Progressive Zoom**: Deterministic zoom ladder with coordinate reconciliation
- **Grid Overlay Guidance**: Always-on coordinate grids with debug overlays
- **89% Click Accuracy**: Industry-leading precision on ARM64

---

## 📚 Documentation

### Platform-Specific Guides
- **[DEPLOYMENT_M4.md](DEPLOYMENT_M4.md)** - Apple Silicon M1-M4 deployment guide
- **[DEPLOYMENT_DGX_SPARK.md](DEPLOYMENT_DGX_SPARK.md)** - NVIDIA DGX Spark deployment guide
- **[ARCHITECTURE_ARM64.md](ARCHITECTURE_ARM64.md)** - ARM64 technical architecture

### General Documentation
- **[CLAUDE.md](CLAUDE.md)** - Development guidelines for Claude Code
- **[docs/](docs/)** - Additional documentation and guides

---

## 🔄 Relationship to Main Repository

This is an **ARM64-optimized fork** of [bytebot-hawkeye-op](https://github.com/zhound420/bytebot-hawkeye-op):

- **Main repo**: x86_64-focused with optional ARM64 support
- **This fork**: ARM64-first design with Apple Silicon + DGX Spark optimizations

Changes are **not intended to merge back** - this is a separate distribution for ARM64 users.

---

## ⚙️ Environment Variables

Key ARM64-specific configuration:

```bash
# Platform Detection
OMNIPARSER_DEVICE=auto              # auto, cuda, mps, cpu
BYTEBOT_ARM64_PLATFORM=apple_silicon  # apple_silicon, dgx_spark, arm64_generic

# Performance (device-specific defaults)
OMNIPARSER_BATCH_SIZE=32           # MPS: 32, CUDA: 128, CPU: 16
OMNIPARSER_MODEL_DTYPE=float16     # float16 (recommended), float32, bfloat16

# Docker Platform
DOCKER_DEFAULT_PLATFORM=linux/arm64  # Force ARM64 builds
```

---

## 🧪 Development

### Building for ARM64

```bash
# Build all services for ARM64
docker compose -f docker/docker-compose.proxy.yml -f docker/docker-compose.arm64.yml build

# Build specific service
docker buildx build --platform linux/arm64 -t bytebot-omniparser:arm64 packages/bytebot-omniparser
```

### Testing on Different Platforms

1. **M4 Pro/Max**: Use native OmniParser + Docker for services
2. **DGX Spark**: Full Docker stack with CUDA GPU passthrough
3. **AWS Graviton**: Docker with CPU fallback (test ARM64 compatibility)

---

## 🤝 Contributing

Contributions welcome! This is the ARM64-optimized repository for Bytebot Hawkeye.

**Submit issues and pull requests to:** https://github.com/zhound420/bytebot-hawkeye-arm

### Focus Areas for ARM64 Optimization

- Performance benchmarks on different ARM64 platforms
- Native binary optimization (libnut-core, uiohook-napi, sharp)
- Apple Silicon Docker improvements (when MPS support lands)
- DGX Spark-specific tuning and optimizations

For x86_64-specific contributions, see [bytebot-hawkeye-op](https://github.com/zhound420/bytebot-hawkeye-op).

---

## 📝 License

Apache 2.0 - Same as upstream Bytebot Hawkeye

---

## 🙏 Credits

- **Bytebot Hawkeye**: Original precision-enhanced AI agent
- **Microsoft OmniParser**: UI element detection models
- **NVIDIA**: DGX Spark ARM64 + CUDA platform
- **Apple**: Metal Performance Shaders (MPS) for Apple Silicon

---

<div align="center">

**Built for ARM64. Optimized for Apple Silicon & DGX Spark. Precision AI everywhere.**

[Platform Detection](scripts/detect-arm64-platform.sh) • [M4 Guide](DEPLOYMENT_M4.md) • [DGX Spark Guide](DEPLOYMENT_DGX_SPARK.md) • [Architecture](ARCHITECTURE_ARM64.md)

</div>
