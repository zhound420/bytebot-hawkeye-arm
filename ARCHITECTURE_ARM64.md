# ARM64 Architecture Technical Documentation

Comprehensive technical guide to Bytebot Hawkeye's ARM64 platform support architecture.

---

## Table of Contents

1. [Overview](#overview)
2. [Platform Detection System](#platform-detection-system)
3. [GPU Backend Selection](#gpu-backend-selection)
4. [Docker Multi-Architecture Strategy](#docker-multi-architecture-strategy)
5. [Performance Optimization](#performance-optimization)
6. [Service-Specific Details](#service-specific-details)

---

## Overview

### Design Philosophy

Bytebot Hawkeye ARM64 follows these principles:

1. **Platform-Agnostic API**: Same REST API across all platforms
2. **Auto-Detection First**: Automatically detect and configure for the host platform
3. **Fallback Gracefully**: Degrade to CPU if GPU unavailable
4. **Zero-Config Goal**: Work out-of-the-box with sensible defaults

### Supported Platform Matrix

| Platform | OS | CPU | GPU | Docker GPU | Deployment |
|----------|------|-----|-----|------------|------------|
| **Apple Silicon M1-M4** | macOS | ARM64 | MPS (Metal) | ❌ No | Native OmniParser + Docker services |
| **NVIDIA DGX Spark** | Linux | ARM64 | CUDA | ✅ Yes | Full Docker stack with GPU passthrough |
| **Generic ARM64 Linux** | Linux | ARM64 | None | N/A | Docker with CPU fallback |
| **x86_64 + NVIDIA** | Linux/Win | x86_64 | CUDA | ✅ Yes | Full Docker stack (reference platform) |

---

## Platform Detection System

### Detection Flow

```
┌─────────────────────────────────────┐
│  scripts/detect-arm64-platform.sh   │
│  ↓                                   │
│  1. Check architecture (uname -m)   │
│     - arm64/aarch64 → Continue      │
│     - other → Exit (x86_64 guide)   │
│  ↓                                   │
│  2. Check OS (uname -s)             │
│     - Darwin → Apple Silicon        │
│     - Linux → Continue to step 3    │
│  ↓                                   │
│  3. Check for NVIDIA GPU            │
│     - nvidia-smi works → DGX Spark  │
│     - nvidia-smi fails → Generic    │
│  ↓                                   │
│  4. Export environment variables    │
│     BYTEBOT_ARM64_PLATFORM          │
│     BYTEBOT_GPU_TYPE                │
│     BYTEBOT_DEPLOYMENT_MODE         │
└─────────────────────────────────────┘
```

### Detection Script Output

```bash
#!/bin/bash
# scripts/detect-arm64-platform.sh

# Detect architecture
ARCH=$(uname -m)
if [[ "$ARCH" != "arm64" && "$ARCH" != "aarch64" ]]; then
    echo "ERROR: Not ARM64"
    exit 1
fi

# Detect platform
if [[ "$(uname -s)" == "Darwin" ]]; then
    # Apple Silicon
    PLATFORM="apple_silicon"
    GPU_TYPE="mps"
    DEPLOYMENT="native"
elif command -v nvidia-smi &> /dev/null; then
    # NVIDIA ARM64 (DGX Spark)
    PLATFORM="dgx_spark"
    GPU_TYPE="cuda"
    DEPLOYMENT="docker"
else
    # Generic ARM64
    PLATFORM="arm64_generic"
    GPU_TYPE="cpu"
    DEPLOYMENT="docker"
fi

# Export for other scripts
export BYTEBOT_ARM64_PLATFORM="$PLATFORM"
export BYTEBOT_GPU_TYPE="$GPU_TYPE"
export BYTEBOT_DEPLOYMENT_MODE="$DEPLOYMENT"
```

---

## GPU Backend Selection

### PyTorch Device Detection

**Location**: `packages/bytebot-omniparser/src/config.py`

```python
def get_device() -> Literal["cuda", "mps", "cpu"]:
    """
    Auto-detect best available device.

    Priority order:
    1. CUDA (NVIDIA GPU) - best performance
    2. MPS (Apple Silicon GPU) - good performance, native macOS only
    3. CPU - fallback, slower but works everywhere
    """
    import torch
    import platform

    # Check CUDA first (NVIDIA GPUs - x86_64 and ARM64)
    if torch.cuda.is_available():
        gpu_count = torch.cuda.device_count()
        gpu_name = torch.cuda.get_device_name(0) if gpu_count > 0 else "Unknown"
        print(f"✓ CUDA available: {gpu_count} GPU(s) - {gpu_name}")
        return "cuda"

    # Check MPS (Apple Silicon - only works natively, not in Docker)
    if hasattr(torch.backends, "mps") and torch.backends.mps.is_available():
        print(f"✓ MPS (Apple Silicon) available on {platform.machine()}")
        return "mps"

    # Fallback to CPU
    arch = platform.machine()
    print(f"⚠ No GPU acceleration - using CPU on {arch}")
    if arch in ["arm64", "aarch64"]:
        print("  Note: MPS not available in Docker - run natively for M4 GPU")
    return "cpu"
```

### Device Selection Matrix

| Environment | CUDA Available | MPS Available | Selected Device | Performance |
|-------------|----------------|---------------|-----------------|-------------|
| **DGX Spark Docker** | ✅ Yes | ❌ No | `cuda` | ~0.8-1.5s |
| **M4 Native** | ❌ No | ✅ Yes | `mps` | ~1-2s |
| **M4 Docker** | ❌ No | ❌ No | `cpu` | ~8-15s |
| **Generic ARM64** | ❌ No | ❌ No | `cpu` | ~8-15s |
| **x86_64 + RTX** | ✅ Yes | ❌ No | `cuda` | ~0.6s |

### Configuration Override

Users can override auto-detection:

```bash
# Environment variable
OMNIPARSER_DEVICE=cuda  # Force CUDA
OMNIPARSER_DEVICE=mps   # Force MPS
OMNIPARSER_DEVICE=cpu   # Force CPU
OMNIPARSER_DEVICE=auto  # Auto-detect (default)
```

---

## Docker Multi-Architecture Strategy

### Dockerfile Platform Detection

**Location**: `packages/bytebot-omniparser/Dockerfile`

```dockerfile
# Get build platform for architecture-specific optimizations
ARG TARGETPLATFORM
ARG BUILDPLATFORM

# Install PyTorch based on target platform
RUN if [ "$TARGETPLATFORM" = "linux/arm64" ]; then \
        echo "Building for ARM64 - installing CUDA 12.1 PyTorch for DGX Spark"; \
        pip install torch torchvision --index-url https://download.pytorch.org/whl/cu121; \
    else \
        echo "Building for AMD64 - installing CUDA 12.1 PyTorch"; \
        pip install torch torchvision --index-url https://download.pytorch.org/whl/cu121; \
    fi
```

**Key Decision**: ARM64 Docker images install **CUDA PyTorch** (not CPU-only) to support DGX Spark.

### Multi-Arch Build Commands

```bash
# Build for specific platform
docker buildx build --platform linux/arm64 -t service:arm64 .
docker buildx build --platform linux/amd64 -t service:amd64 .

# Build multi-arch manifest (single image for both)
docker buildx build --platform linux/arm64,linux/amd64 -t service:latest --push .

# Docker Compose auto-detection
docker compose -f docker-compose.proxy.yml build
# Builds for host architecture automatically
```

### Platform Override in Docker Compose

**Location**: `docker/docker-compose.arm64.yml`

```yaml
services:
  bytebot-omniparser:
    platform: linux/arm64  # Force ARM64

  bytebot-agent:
    platform: linux/arm64

  # ... other services
```

Usage:
```bash
# Use ARM64 overrides
docker compose -f docker-compose.proxy.yml -f docker-compose.arm64.yml up -d
```

---

## Performance Optimization

### Batch Size Tuning

Different platforms have different optimal batch sizes:

```python
# packages/bytebot-omniparser/src/config.py

class PerformanceProfile:
    BALANCED = {
        "batch_size_mps": 32,    # Apple Silicon MPS
        "batch_size_gpu": 128,   # NVIDIA CUDA (x86_64 + ARM64)
        "batch_size_cpu": 16,    # CPU fallback
    }

def get_batch_size(self, device: str) -> int:
    if device == "mps":
        return profile["batch_size_mps"]
    elif device == "cuda":
        return profile["batch_size_gpu"]
    else:  # cpu
        return profile["batch_size_cpu"]
```

**Rationale**:
- **MPS**: Limited by Metal API overhead, 32 works well
- **CUDA**: High-bandwidth memory, 128+ optimal
- **CPU**: Memory-constrained, 16 to avoid thrashing

### Memory Management

| Platform | Total Memory | OmniParser | Docker Services | OS Overhead | Recommended Minimum |
|----------|--------------|------------|-----------------|-------------|---------------------|
| **M4 Pro 24GB** | 24GB | 4GB | 8GB | 6GB | ✅ 18GB |
| **M4 Pro 36GB** | 36GB | 4GB | 12GB | 6GB | ✅ 22GB |
| **DGX Spark** | 128GB | 8GB | 20GB | 10GB | ✅ 38GB (plenty!) |
| **Generic 16GB** | 16GB | 4GB | 6GB | 4GB | ⚠️ 14GB (tight) |

### Model Precision

```bash
# Environment configuration
OMNIPARSER_MODEL_DTYPE=float16  # Recommended for all platforms
# OMNIPARSER_MODEL_DTYPE=float32  # Use for debugging only (2x memory)
# OMNIPARSER_MODEL_DTYPE=bfloat16  # Experimental, needs PyTorch 2.1+
```

**Trade-offs**:
- **float16**: 2x memory savings, minimal accuracy loss (~0.5%)
- **float32**: Full precision, 2x memory usage
- **bfloat16**: Dynamic range of float32, size of float16 (best of both, but new)

---

## Service-Specific Details

### OmniParser (Python + PyTorch)

**Key files**:
- `packages/bytebot-omniparser/Dockerfile` - Multi-arch PyTorch installation
- `packages/bytebot-omniparser/src/config.py` - Device detection
- `packages/bytebot-omniparser/src/server.py` - GPU diagnostics at startup

**Platform-specific behavior**:
```python
# Native macOS (M4)
device = "mps"
batch_size = 32
torch_index = "https://download.pytorch.org/whl/torch_stable.html"

# Docker on DGX Spark
device = "cuda"
batch_size = 128
torch_index = "https://download.pytorch.org/whl/cu121"

# Docker on M4 (fallback)
device = "cpu"
batch_size = 16
torch_index = "https://download.pytorch.org/whl/cpu"
```

### bytebot-agent (NestJS + TypeScript)

**ARM64 considerations**:
- Node.js 20 has native ARM64 support
- No architecture-specific code needed
- Prisma ORM supports ARM64
- Native modules (`bcrypt`, etc.) compile for ARM64 automatically

**Build process**:
```dockerfile
FROM node:20.19.5-slim AS base
# No platform-specific logic needed
# Node.js binaries are already ARM64-native
```

### bytebotd (Desktop Daemon)

**ARM64 considerations**:
- `libnut-core` - Compiled from source for ARM64 (lines 262-270 in Dockerfile)
- `uiohook-napi` - Rebuilt with `--build-from-source` flag
- `sharp` - Auto-detects ARM64 and uses native binaries

**Critical build step**:
```dockerfile
# Upgrade CMake for ARM64 compatibility
RUN ARCH=$(dpkg --print-architecture) && \
    if [ "$ARCH" = "arm64" ]; then \
        CMAKE_ARCH="aarch64"; \
    fi && \
    wget https://github.com/Kitware/CMake/releases/download/v3.29.8/cmake-3.29.8-linux-${CMAKE_ARCH}.tar.gz

# Build libnut-core for ARM64
RUN git clone https://github.com/ZachJW34/libnut-core.git && \
    cd libnut-core && \
    npm install && \
    npm run build:release
```

### PostgreSQL (pgvector)

**ARM64 support**:
```yaml
services:
  postgres:
    image: pgvector/pgvector:pg16
    platform: linux/arm64  # Official image supports ARM64
```

**Verification**:
```bash
docker run --rm --platform linux/arm64 pgvector/pgvector:pg16 postgres --version
# Should show: postgres (PostgreSQL) 16.x (Debian 16.x-arm64)
```

---

## Deployment Patterns

### Pattern 1: Apple Silicon (Hybrid)

```
┌───────────────────────────┐
│  macOS (Native)           │
│  - OmniParser (MPS GPU)   │ ← Best performance
└───────────────────────────┘
            ↕
┌───────────────────────────┐
│  Docker Desktop (ARM64)   │
│  - Agent, UI, Desktop     │
│  - PostgreSQL, LLM Proxy  │
└───────────────────────────┘
```

**Why hybrid?**
- MPS not available in Docker → must run native
- Docker Desktop manages networking via `host.docker.internal`

### Pattern 2: DGX Spark (All-Docker)

```
┌────────────────────────────────┐
│  Docker with NVIDIA Runtime    │
│  - OmniParser (CUDA GPU) ✓     │
│  - Agent, UI, Desktop          │
│  - PostgreSQL, LLM Proxy       │
└────────────────────────────────┘
```

**Why all-Docker?**
- CUDA available in containers on Linux
- Simpler deployment (single command)
- Better isolation and reproducibility

### Pattern 3: Generic ARM64 (Docker CPU)

```
┌────────────────────────────────┐
│  Docker (ARM64)                │
│  - OmniParser (CPU only) ⚠️    │
│  - Agent, UI, Desktop          │
│  - PostgreSQL, LLM Proxy       │
└────────────────────────────────┘
```

**Why CPU-only?**
- No GPU available
- Fallback for compatibility testing
- Not recommended for production (too slow)

---

## Future Enhancements

### Potential Improvements

1. **Apple Silicon Docker GPU Support**
   - When Docker Desktop adds MPS passthrough, update to all-Docker pattern
   - Monitor: https://github.com/docker/for-mac/issues/6824

2. **AWS Graviton Optimizations**
   - Test on Graviton3/4 instances
   - Optimize for AWS ARM64 specific features

3. **Hybrid MPS/CUDA Models**
   - Research using both MPS (native) and CUDA (containers) simultaneously
   - Potential for distributed inference

4. **ARM64 Model Quantization**
   - Explore INT8 quantization for faster inference
   - Trade-off: 4x speed vs ~2% accuracy loss

---

## References

- [PyTorch MPS Backend](https://pytorch.org/docs/stable/notes/mps.html)
- [Docker Multi-Platform Builds](https://docs.docker.com/build/building/multi-platform/)
- [NVIDIA Container Toolkit](https://docs.nvidia.com/datacenter/cloud-native/container-toolkit/overview.html)
- [Apple Silicon Performance Guide](https://developer.apple.com/metal/pytorch/)

---

**Last Updated**: January 2025
**Architecture Version**: 1.0.0-arm64
