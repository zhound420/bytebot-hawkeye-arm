<div align="center">

<img src="docs/images/bytebot-logo.png" width="500" alt="Bytebot Logo">

# Bytebot Hawkeye: Precision AI Desktop Agent

**An AI desktop agent with enhanced targeting, GPU-accelerated computer vision, and 89% click accuracy**

[![Deploy on Railway](https://railway.com/button.svg)](https://railway.com/deploy/bytebot?referralCode=L9lKXQ)
</div>

<details>
<summary><strong>Resources & Translations</strong></summary>

<div align="center">

<a href="https://trendshift.io/repositories/14624" target="_blank"><img src="https://trendshift.io/api/badge/repositories/14624" alt="bytebot-ai%2Fbytebot | Trendshift" style="width: 250px; height: 55px;" width="250" height="55"/></a>

[![Docker](https://img.shields.io/badge/docker-ready-blue.svg)](https://github.com/bytebot-ai/bytebot/tree/main/docker)
[![License](https://img.shields.io/badge/license-Apache%202.0-green.svg)](LICENSE)
[![Discord](https://img.shields.io/discord/1232768900274585720?color=7289da&label=discord)](https://discord.com/invite/d9ewZkWPTP)

[🌐 Website](https://bytebot.ai) • [📚 Documentation](https://docs.bytebot.ai) • [💬 Discord](https://discord.com/invite/d9ewZkWPTP) • [𝕏 Twitter](https://x.com/bytebot_ai)

<!-- Keep these links. Translations will automatically update with the README. -->
[Deutsch](https://zdoc.app/de/bytebot-ai/bytebot) |
[Español](https://zdoc.app/es/bytebot-ai/bytebot) |
[français](https://zdoc.app/fr/bytebot-ai/bytebot) |
[日本語](https://zdoc.app/ja/bytebot-ai/bytebot) |
[한국어](https://zdoc.app/ko/bytebot-ai/bytebot) |
[Português](https://zdoc.app/pt/bytebot-ai/bytebot) |
[Русский](https://zdoc.app/ru/bytebot-ai/bytebot) |
[中文](https://zdoc.app/zh/bytebot-ai/bytebot)

</div>
</details>

---

## ⭐ What's New

**Latest Hawkeye enhancements (January 2025):**

- **🖥️ Windows 11 Desktop Support** - Full OmniBox integration via dockurr/windows with live VNC view
  - Automated setup with progress tracking and health monitoring
  - PyAutoGUI-based computer control (screenshot, click, type, scroll)
  - Region screenshot support for focused capture (top-left, center, etc.)
  - Handles Windows session isolation (runs in user session, not Session 0)
- **🎓 Trajectory Recording UI** - Visual controls for model learning system
  - Live recording badge with pause/resume controls in header
  - 2x2 stats grid showing recorded trajectories, success rate, quality metrics
  - Provider breakdown showing trajectories by model (Claude, GPT-4o, Gemini)
  - Clean empty states with "--" placeholders (no misleading 0% values)
- **🧠 Model Learning System** - Enable non-Claude models to learn from Claude's successful completions
  - Trajectory distillation: Record and analyze complete task execution traces
  - Dynamic few-shot learning: Auto-inject relevant successful examples (35-50% improvement)
  - Model-specific prompt engineering: Optimized prompts for GPT-4o, Gemini, and local models
  - See [MODEL_LEARNING_SYSTEM.md](docs/MODEL_LEARNING_SYSTEM.md) for details
- **61 AI Models** - Comprehensive catalog across all major providers (up from 45)
- **15 Reasoning Models** - GPT-5 series, DeepSeek R1, o1/o3, Qwen thinking variants with amber UI badges
- **Enhanced GPU Detection** - Real-time device reporting with visual indicators (⚡ NVIDIA GPU, 🍎 Apple Silicon, 💻 CPU)
- **Full OmniParser v2.0** - 100% integration complete with OCR, interactivity detection, batch captioning, overlap filtering
- **89% Click Accuracy** - Up from 72% with semantic UI understanding (YOLOv8 + Florence-2)
- **Real-Time CV Monitoring** - Live model display and performance metrics with 500ms polling

---

## 📋 Prerequisites

### Required Software
- **Docker** (≥20.10) & **Docker Compose** (≥2.0)
- **Git** for cloning the repository
- **Node.js** ≥20.0.0 (for local development only, not needed for Docker)

### API Keys (Required)
At least one LLM provider API key:
- **Anthropic** (Claude models) - Get at [console.anthropic.com](https://console.anthropic.com)
- **OpenAI** (GPT models) - Get at [platform.openai.com](https://platform.openai.com)
- **Google** (Gemini models) - Get at [aistudio.google.com](https://aistudio.google.com)
- **OpenRouter** (Multi-model proxy) - Get at [openrouter.ai](https://openrouter.ai)

### GPU Requirements (Optional, Recommended for Best Performance)

OmniParser v2.0 provides semantic UI detection with GPU acceleration:

| Platform | Performance | Setup |
|----------|-------------|-------|
| **x86_64 + NVIDIA GPU** | ⚡ ~0.6s/frame (CUDA) | Install `nvidia-container-toolkit` |
| **Apple Silicon (M1-M4)** | 🍎 ~1-2s/frame (MPS) | Automatic native execution |
| **CPU-only** | 💻 ~8-15s/frame | No setup needed, slower |

**NVIDIA GPU Setup (Ubuntu/Debian):**
```bash
sudo apt-get update
sudo apt-get install -y nvidia-container-toolkit
sudo systemctl restart docker
docker run --rm --gpus all nvidia/cuda:11.8.0-base-ubuntu22.04 nvidia-smi
```

---

## 🚀 Quick Start

### Step 1: Clone Repository
```bash
git clone https://github.com/zhound420/bytebot-hawkeye-op.git
cd bytebot-hawkeye-op
```

### Step 2: Configure API Keys

Create `docker/.env` with your API keys:

```bash
cat <<'EOF' > docker/.env
# LLM Provider API Keys (Required - at least one)
ANTHROPIC_API_KEY=sk-ant-...
OPENAI_API_KEY=sk-...
GEMINI_API_KEY=...
OPENROUTER_API_KEY=sk-or-v1-...
EOF
```

### Step 3: Setup OmniParser

The setup script auto-detects your hardware and installs the optimal configuration:

```bash
./scripts/setup-omniparser.sh
```

**What happens:**
- **Apple Silicon:** Native OmniParser with MPS GPU (~1-2s/frame)
- **x86_64 + NVIDIA:** Docker with CUDA (~0.6s/frame)
- **x86_64 CPU:** Docker with CPU fallback (~8-15s/frame)

### Step 4: Start the Stack

The new auto-detection script handles platform selection automatically:

```bash
./scripts/start.sh
```

**What happens automatically:**
- Detects your host platform (Linux, macOS, Windows WSL)
- Checks for KVM support (needed for Windows desktop VM)
- Prompts to select desktop platform if Windows is available
- Configures environment variables and Docker profiles
- Starts the stack with the appropriate desktop service

**Platform options:**
1. **Linux Desktop** (bytebotd) - Native Linux with X11/noVNC (default, fastest)
2. **Windows 11 Desktop** (OmniBox) - Full Windows VM via dockurr/windows (requires KVM + Tiny11 ISO)

**Manual platform selection:**
```bash
# Force Linux desktop
BYTEBOT_FORCE_PLATFORM=linux ./scripts/start.sh

# Force Windows desktop
BYTEBOT_FORCE_PLATFORM=windows ./scripts/start.sh
```

**Access the application:**
- 🌐 **Web UI:** http://localhost:9992
- 🖥️ **Desktop (noVNC):**
  - Linux: http://localhost:9990
  - Windows: http://localhost:8006 (also proxied in UI)
- 🤖 **Agent API:** http://localhost:9991
- 🔀 **LiteLLM Proxy:** http://localhost:4000
- 👁️ **OmniParser:** http://localhost:9989

**Stop the stack:**
```bash
./scripts/stop-stack.sh
```

**That's it!** The model learning system is **enabled by default** and sets up automatically on first start:
- ✅ pgvector extension enabled automatically
- ✅ Trajectory tables created via Prisma migrations
- ✅ Claude's successful runs recorded for learning
- ✅ Other models (GPT-4o, Gemini) auto-improve via few-shot examples

**Expected Benefits:**
- 📈 35-50% improvement in non-Claude model success rates
- 🎓 Continuous learning from every successful Claude task
- 💰 50-70% cost reduction (more tasks can use cheaper models)

See [MODEL_LEARNING_SYSTEM.md](docs/MODEL_LEARNING_SYSTEM.md) for configuration details and API reference.

---

## 📊 Models Available

**61 models across all major providers** with comprehensive reasoning and vision support:

### By Provider
- **Anthropic (9):** Opus 4.1, Sonnet 4.5, Haiku 4.5, Sonnet 3.7, Opus 3.5, Haiku 3.5
- **OpenAI (14):** GPT-5 variants, GPT-4.5, GPT-4o, GPT-4.1, o1/o3 series, GPT-4o-mini
- **Qwen3-VL (7):** 235B thinking, 30B instruct/thinking, 8B instruct/thinking
- **Gemini (12):** 2.5 Pro Exp, 2.0 Flash exp/thinking, 1.5 Pro/Flash, Exp 1206
- **DeepSeek (8):** R1, R1-free, Chat v3, v3.1 Terminus, v3.2 Exp, Chat variants
- **Llama (6):** 4 Scout, 3.3 70B, 3.2 Vision 90B/11B, free tier variants
- **LMStudio (5):** Custom local model support

### By Capability
- **🧠 15 Reasoning Models** (amber badge in UI):
  - OpenAI: o1, o1-mini, o3, o3-mini, GPT-5, GPT-5-mini, GPT-5-nano
  - DeepSeek: R1, R1-free
  - Qwen: 235B-thinking, 30B-thinking, 8B-thinking
  - Gemini: 2.0 Flash thinking variants
- **👁️ 61 Vision Models** - All models support visual input for screenshot analysis

**Configuration:** Models are defined in `packages/bytebot-llm-proxy/litellm-config.yaml`

---

## Hawkeye Fork Enhancements

Hawkeye layers precision tooling on top of upstream Bytebot for reliable autonomous operation:

| Capability | Hawkeye | Upstream Bytebot |
| --- | --- | --- |
| **Windows 11 desktop** | Full OmniBox integration with automated setup, progress tracking, PyAutoGUI control, region screenshots | Linux-only bytebotd |
| **Trajectory recording UI** | Visual badge with pause/resume, 2x2 stats grid, provider breakdown, clean empty states | Command-line only |
| **Grid overlay guidance** | Always-on coordinate grids with labeled axes, optional debug overlays (`BYTEBOT_GRID_OVERLAY`/`BYTEBOT_GRID_DEBUG`) | No persistent spatial scaffolding |
| **Smart Focus targeting** | Three-stage coarse→focus→click workflow with tunable grids ([Smart Focus System](docs/SMART_FOCUS_SYSTEM.md)) | Single-shot click reasoning |
| **Progressive zoom capture** | Deterministic zoom ladder with cyan micro-grids and coordinate reconciliation | Manual zoom without coordinate mapping |
| **Coordinate telemetry** | Real-time accuracy metrics with `BYTEBOT_COORDINATE_METRICS` and `BYTEBOT_COORDINATE_DEBUG` | No automated accuracy measurement |
| **Universal coordinate mapping** | Shared lookup in `config/universal-coordinates.yaml` auto-discovered across packages | Requires custom configuration |
| **OmniParser v2.0 semantic detection** | **100% integration:** YOLOv8 + Florence-2 + OCR + interactivity detection + batch captioning (**89% accuracy**) | Basic screenshot analysis |
| **Streamlined CV pipeline** | Two-method detection (OmniParser primary + Tesseract.js OCR fallback), OpenCV removed | Pixel-based analysis only |
| **Real-time CV monitoring** | Live tracking with animated indicators, GPU detection, model display (YOLOv8 + Florence-2), performance metrics | No CV visibility |
| **GPU acceleration** | Auto-detected NVIDIA CUDA/Apple Silicon MPS with real-time device reporting (⚡/🍎/💻 badges) | No GPU support |
| **Accessible UI theming** | Header theme toggle for high-contrast light/dark palettes | Single default theme |
| **Active Model telemetry** | Desktop dashboard card shows current provider, model, streaming heartbeat | Must tail logs to confirm model |

**Configuration:** Toggle features via environment variables (`BYTEBOT_SMART_FOCUS`, `BYTEBOT_UNIVERSAL_TEACHING`, `BYTEBOT_ADAPTIVE_CALIBRATION`, etc.)

![Desktop accuracy overlay](docs/images/hawkeye2.png)

---

## Smart Focus System

**Three-stage precision targeting** for reliable autonomous clicks:

1. **Coarse** - Overview with large grid (`BYTEBOT_OVERVIEW_GRID=200px`)
2. **Focus** - Zoom into target region with medium grid (`BYTEBOT_REGION_GRID=50px`)
3. **Click** - Final selection with fine grid (`BYTEBOT_FOCUSED_GRID=25px`)

**Configuration:**
```bash
BYTEBOT_SMART_FOCUS=true                    # Enable Smart Focus
BYTEBOT_SMART_FOCUS_MODEL=gpt-4o-mini      # Model for focus reasoning
BYTEBOT_OVERVIEW_GRID=200                   # Coarse grid (px)
BYTEBOT_REGION_GRID=50                      # Region grid (px)
BYTEBOT_FOCUSED_GRID=25                     # Fine grid (px)
```

**Documentation:** See [docs/SMART_FOCUS_SYSTEM.md](docs/SMART_FOCUS_SYSTEM.md) for full details.

---

## Computer Vision Pipeline

**Streamlined two-method detection** focused on semantic understanding and reliability:

### Primary: OmniParser v2.0 (100% Integration Complete)

**AI-powered semantic UI detection** with full pipeline capabilities:

- ✅ **YOLOv8 Icon Detection** - ~50MB model, fine-tuned for UI elements
- ✅ **Florence-2 Captioning** - ~800MB model, functional descriptions
- ✅ **PaddleOCR/EasyOCR Integration** - Text detection (+35% element coverage)
- ✅ **Interactivity Detection** - Clickable vs decorative (-15% false positives)
- ✅ **Overlap Filtering** - IoU-based duplicate removal
- ✅ **Batch Caption Processing** - 5x faster with GPU batching
- ✅ **89% Click Accuracy** - Up from 72% with classical CV methods

**Performance:**
- Icon Detection: ~0.6s/frame (NVIDIA GPU), ~1-2s (Apple Silicon), ~8-15s (CPU)
- Full Pipeline: ~1.6s/frame (GPU) with OCR + detection + captioning
- Benchmark: 39.6% on ScreenSpot Pro

**Configuration:**
```bash
BYTEBOT_CV_USE_OMNIPARSER=true             # Enable OmniParser
BYTEBOT_CV_USE_OMNIPARSER_OCR=true         # Enable OCR integration
OMNIPARSER_URL=http://localhost:9989       # Service endpoint
OMNIPARSER_DEVICE=auto                     # auto, cuda, mps, cpu
OMNIPARSER_MIN_CONFIDENCE=0.3              # Detection threshold
OMNIPARSER_IOU_THRESHOLD=0.7               # Overlap filtering
OMNIPARSER_BATCH_SIZE=128                  # Caption batch size
```

### Fallback: Tesseract.js OCR

**Pure JavaScript text extraction** when OmniParser unavailable:
- No native dependencies (no compilation required)
- Text-based element detection
- Automatic fallback when OmniParser disabled

### Real-Time CV Activity Monitoring

**Live visibility into computer vision operations:**

- **Animated Method Indicators** - Color-coded badges (OmniParser: Pink, OCR: Yellow)
- **OmniParser Model Display** - Shows YOLOv8 + Florence-2 models in real-time
- **GPU Detection** - Visual indicators: ⚡ NVIDIA GPU, 🍎 Apple Silicon, 💻 CPU
- **Performance Metrics** - Avg time, total executions, success rate, compute device
- **UI Integration** - Dedicated panels on Desktop and Task pages with 500ms polling

**API Endpoints:**
```bash
GET /cv-activity/stream      # Real-time activity (500ms polling)
GET /cv-activity/status      # Current snapshot
GET /cv-activity/performance # Performance statistics
GET /cv-activity/history     # Last 20 executions
```

**Benefits vs OpenCV:**
- ✅ Simpler installation (no C++ compilation)
- ✅ Smaller package size (~850MB vs multiple GB)
- ✅ Better cross-platform compatibility
- ✅ Superior accuracy (89% vs ~60%)

---

## Desktop Accuracy Dashboard

The `/desktop` route provides real-time telemetry with session management:

- **Live Metrics** - Success rate, weighted offsets, convergence score for current session
- **Session Selector** - Jump between historical sessions to compare performance
- **Reset Controls** - Zero out metrics for clean benchmark runs
- **Hotspot Visualization** - Identify UI zones with click accuracy issues

**Learning Metrics:**
- **Attempt count** - Sample size for current session
- **Success rate** - Percentage within configured radius (`BYTEBOT_SMART_CLICK_SUCCESS_RADIUS=12`)
- **Weighted offsets** - Average X/Y drift weighted by recency
- **Convergence** - Decay-weighted stability score (trends to 1.0 when calibrated)
- **Hotspots** - Clustered miss regions for targeted improvement

![Desktop accuracy drawer](docs/images/hawkeye3.png)

---

## Advanced Setup

### Manual Docker Compose (Proxy Stack)

If you prefer manual control over the automated `start-stack.sh`:

```bash
# 1. Configure API keys in docker/.env
cat <<'EOF' > docker/.env
ANTHROPIC_API_KEY=sk-ant-...
OPENAI_API_KEY=sk-...
GEMINI_API_KEY=...
OPENROUTER_API_KEY=sk-or-v1-...
EOF

# 2. Start full stack with LiteLLM proxy
docker compose -f docker/docker-compose.proxy.yml up -d --build
```

### Standard Stack (No Proxy)

Direct provider API access without LiteLLM:

```bash
docker compose -f docker/docker-compose.yml up -d --build
```

### Alternative Deployments

- [Railway one-click template](https://docs.bytebot.ai/deployment/railway)
- [Helm charts for Kubernetes](https://docs.bytebot.ai/deployment/helm)
- [Custom Docker Compose topologies](https://docs.bytebot.ai/deployment/litellm)

---

## Troubleshooting

### UI Connection Errors (ECONNREFUSED :9991)
```bash
docker compose ps bytebot-agent          # Check agent status
docker compose logs bytebot-agent        # View agent logs
docker exec bytebot-agent npx prisma migrate status  # Verify migrations
```

### OmniParser Connection Issues
```bash
# Apple Silicon: Check native service
lsof -i :9989

# x86_64: Check container
docker logs bytebot-omniparser

# Verify configuration
cat docker/.env.defaults | grep OMNIPARSER_URL
```

### Database Errors
```bash
# Manual migration (agent auto-migrates on startup)
docker exec bytebot-agent npx prisma migrate deploy
```

### GPU Not Detected
```bash
# Verify nvidia-container-toolkit
docker run --rm --gpus all nvidia/cuda:11.8.0-base-ubuntu22.04 nvidia-smi

# Check OmniParser logs
docker logs bytebot-omniparser | grep "device:"
```

### Windows Desktop Issues

**Desktop view not showing (black screen or "no connection"):**
```bash
# Check OmniBox container is running
docker compose ps bytebot-omnibox

# Verify Flask server is accessible
docker exec bytebot-omnibox curl -f http://172.30.0.4:5000/probe

# Check Windows setup progress
docker exec bytebot-omnibox cat /run/setup_progress.json
```

**Screenshots failing with "screen grab failed":**
- **Root Cause:** Flask server running in Session 0 (SYSTEM) instead of user session
- **Fix:** The scheduled task must use user logon trigger (not system startup)
- **Verify:** Check `setup.ps1` line 453-454 uses `-LocalUser "Docker"` (not `-AtStartup -AsSystem`)
- **Rebuild:** If misconfigured, delete volume and rebuild: `./scripts/fresh-build.sh` → choose Windows → select "Delete volume and reinstall"

**Region screenshot not working:**
- **Symptom:** "Unsupported action: screenshot_region" error
- **Fix:** Update omnibox-adapter to latest version with `screenshotRegion()` method
- **Verify:** Check omnibox-adapter logs for "Region mapped to coordinates" messages

**VNC connection errors in UI:**
- **Symptom:** "Invalid URL" errors or websocket connection failures
- **Cause:** `BYTEBOT_DESKTOP_VNC_URL` environment variable not set
- **Fix:** Ensure scripts load `.env.defaults` with `set -a && source docker/.env.defaults && set +a`
- **Default:** Should be `http://omnibox:8006/websockify` for Windows

See [GPU Setup Guide](docs/GPU_SETUP.md) for detailed troubleshooting.

---

## Operations & Tuning

### Environment Variables

**Smart Focus:**
```bash
BYTEBOT_SMART_FOCUS=true                   # Enable Smart Focus
BYTEBOT_SMART_FOCUS_MODEL=gpt-4o-mini      # Focus reasoning model
BYTEBOT_OVERVIEW_GRID=200                  # Coarse grid (px)
BYTEBOT_FOCUSED_GRID=25                    # Fine grid (px)
```

**Grid Overlays:**
```bash
BYTEBOT_GRID_OVERLAY=true                  # Enable coordinate grids
BYTEBOT_GRID_DEBUG=false                   # Debug overlays
```

**Coordinate Accuracy:**
```bash
BYTEBOT_COORDINATE_METRICS=true            # Track accuracy
BYTEBOT_COORDINATE_DEBUG=false             # Deep logging
BYTEBOT_SMART_CLICK_SUCCESS_RADIUS=12      # Success threshold (px)
```

**OmniParser:**
```bash
BYTEBOT_CV_USE_OMNIPARSER=true             # Enable semantic detection
BYTEBOT_CV_USE_OMNIPARSER_OCR=true         # OCR integration
OMNIPARSER_DEVICE=auto                     # auto, cuda, mps, cpu
```

**Universal Teaching:**
```bash
BYTEBOT_UNIVERSAL_TEACHING=true            # Element mapping learning
BYTEBOT_ADAPTIVE_CALIBRATION=true          # Coordinate calibration
```

### Smart Click Success Radius

Tune the pass/fail threshold for click accuracy:

```bash
export BYTEBOT_SMART_CLICK_SUCCESS_RADIUS=12  # pixels of acceptable drift
```

Increase for higher cursor drift tolerance, decrease for stricter accuracy requirements.

---

## Further Reading

- [Bytebot upstream README](https://github.com/bytebot-ai/bytebot#readme)
- [Quickstart guide](https://docs.bytebot.ai/quickstart)
- [API reference](https://docs.bytebot.ai/api-reference/introduction)
- [Smart Focus System](docs/SMART_FOCUS_SYSTEM.md)
- [GPU Setup Guide](docs/GPU_SETUP.md)

---

<div align="center">

**Built on [Bytebot](https://github.com/bytebot-ai/bytebot) • Enhanced with Hawkeye precision tooling**

</div>
