<div align="center">

<img src="docs/images/bytebot-logo.png" width="500" alt="Bytebot Logo">

# Bytebot Hawkeye ARM64: Multi-Platform AI Desktop Agent

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

---

## 🚀 Supported Platforms

| Platform | GPU Acceleration | Deployment | Performance | Recommended For |
|----------|-----------------|------------|-------------|-----------------|
| **Apple Silicon (M1-M4)** | ✅ MPS (Metal) | Native execution | ~1-2s/frame | Development, testing on MacBook |
| **NVIDIA DGX Spark** | ✅ CUDA on ARM64 | Docker containers | ~0.8-1.5s/frame | Production, high-performance inference |
| **Generic ARM64 Linux** | ❌ CPU only | Docker containers | ~8-15s/frame | Compatibility testing |

---

## 📦 Quick Start

### Platform Detection

First, detect your ARM64 platform and get deployment recommendations:

```bash
./scripts/detect-arm64-platform.sh
```

This will identify your system (Apple Silicon / DGX Spark / Generic ARM64) and provide tailored setup instructions.

### Apple Silicon (M1-M4) Setup

For **best performance** on Apple Silicon, run OmniParser **natively** (Docker can't access MPS GPU):

```bash
# 1. Install dependencies
npm install

# 2. Setup native OmniParser with MPS GPU
cd packages/bytebot-omniparser
bash scripts/setup.sh  # Auto-detects Apple Silicon, installs with MPS support
python src/server.py   # Starts on http://localhost:9989

# 3. In another terminal, start other services in Docker
cd ../../
docker compose -f docker/docker-compose.proxy.yml up -d
```

**See [DEPLOYMENT_M4.md](DEPLOYMENT_M4.md) for detailed M4 Pro/Max/Ultra guide**

### NVIDIA DGX Spark Setup

DGX Spark supports **full GPU acceleration in Docker** (ARM64 + CUDA):

```bash
# Everything runs in Docker with GPU passthrough
docker compose -f docker/docker-compose.proxy.yml up -d

# Or use ARM64-specific overrides
docker compose -f docker/docker-compose.proxy.yml -f docker/docker-compose.arm64.yml up -d
```

**See [DEPLOYMENT_DGX_SPARK.md](DEPLOYMENT_DGX_SPARK.md) for DGX Spark optimization guide**

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

This is an **ARM64-optimized fork** of [bytebot-hawkeye-op](https://github.com/your-org/bytebot-hawkeye-op):

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

Contributions welcome! Focus areas for ARM64 optimization:

- Performance benchmarks on different ARM64 platforms
- Native binary optimization (libnut-core, uiohook-napi, sharp)
- Apple Silicon Docker improvements (when MPS support lands)
- DGX Spark-specific tuning and optimizations

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
