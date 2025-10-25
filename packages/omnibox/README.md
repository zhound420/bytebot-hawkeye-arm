# OmniBox - Tiny11 Desktop Agent Environment

OmniBox is a lightweight Tiny11 (Windows 11 minimal) VM in Docker from Microsoft's OmniParser project, designed for AI agent testing and automation.

## Features

- **70% smaller** than traditional Windows VMs (20GB vs 60GB+)
- **Computer Use API** on port 5000 for programmatic desktop control
- **VNC Access** on port 5900 for visual debugging
- **PyAutoGUI integration** for mouse/keyboard automation
- **Pre-configured** Tiny11 environment (Windows 11 with bloat removed)
- **Cached ISO** - Download once, reuse forever

## Prerequisites

- Docker Desktop with KVM support (Linux/WSL2)
- ~20GB free disk space
- Tiny11 2311 ISO (automatically downloaded)

## Setup

### 1. Download Tiny11 ISO

Run the automated download script (downloads ~3GB):
```bash
./scripts/download-windows-iso.sh
```

This downloads Tiny11 2311 from Internet Archive and caches it in `~/.cache/bytebot/iso/`. The ISO persists across Docker volume deletions, so you only download once.

**Manual download** (if script fails):
```bash
mkdir -p ~/.cache/bytebot/iso
# Download from: https://archive.org/download/tiny11-2311/tiny11%202311%20x64.iso
# Save as: ~/.cache/bytebot/iso/tiny11-2311.iso
```

### 2. Start OmniBox

```bash
# Using docker-compose (from project root)
docker compose -f docker/docker-compose.proxy.yml --profile omnibox up -d omnibox

# OR using fresh build script
./scripts/fresh-build.sh
```

The container will boot from the cached Tiny11 ISO. First boot takes 20-30 minutes for automated setup (Python, PyAutoGUI, Computer Use server).

### 3. Access Windows Desktop

**VNC Viewer:** Connect to `localhost:5900`

**Web Viewer:** Open `http://localhost:8006`

## Computer Use API

OmniBox exposes HTTP endpoints for programmatic control:

### POST /execute
Execute Python commands via PyAutoGUI:

```bash
curl -X POST http://localhost:5000/execute \
  -H "Content-Type: application/json" \
  -d '{"command": ["python", "-c", "import pyautogui; pyautogui.click(640, 360)"]}'
```

### GET /screenshot
Capture current screen state:

```bash
curl http://localhost:5000/screenshot > screenshot.png
```

## Integration with Bytebot

OmniBox integrates with Bytebot through the **omnibox-adapter** service, which provides a bytebotd-compatible API:

```
bytebot-agent
    ↓
omnibox-adapter (port 5001)
    ↓
OmniBox HTTP API (port 5000)
    ↓
Windows 11 Desktop
```

See `packages/omnibox-adapter/README.md` for details.

## Management Commands

Use the management script for manual VM control:

```bash
# From project root
./scripts/manage-omnibox.sh status   # Check VM status
./scripts/manage-omnibox.sh start    # Start existing VM (~30s)
./scripts/manage-omnibox.sh stop     # Stop VM
./scripts/manage-omnibox.sh restart  # Restart VM
./scripts/manage-omnibox.sh logs     # View VM logs
./scripts/manage-omnibox.sh delete   # Delete VM (WARNING: destroys all data)
```

**Note:** For a complete fresh build with platform selection, use `./scripts/fresh-build.sh` instead.

## Architecture

```
┌─────────────────────────────────────┐
│  OmniBox Docker Container           │
│  ┌───────────────────────────────┐  │
│  │  Windows 11 Enterprise VM     │  │
│  │  - QEMU/KVM virtualization    │  │
│  │  - PyAutoGUI server           │  │
│  │  - HTTP API (:5000)           │  │
│  │  - VNC server (:5900)         │  │
│  │  - Web viewer (:8006)         │  │
│  └───────────────────────────────┘  │
└─────────────────────────────────────┘
```

## Supported Actions

- **Mouse:** left_click, right_click, double_click, mouse_move, drag, hover
- **Keyboard:** type, hotkey (Ctrl+C, Win+R, etc.)
- **Screen:** screenshot, cursor_position
- **Navigation:** scroll_up, scroll_down, wait

## Troubleshooting

**VM won't start:**
- Ensure KVM is enabled: `lsmod | grep kvm`
- Check Docker has privileges: `docker run --privileged`

**Container health check failing:**
- The health check uses the Windows VM's bridge IP (typically `172.30.0.4`)
- Check container logs: `docker logs bytebot-omnibox`
- Verify VM is assigned the expected IP:
  ```bash
  docker exec bytebot-omnibox ip addr show eth0
  ```
- Test connectivity from within container:
  ```bash
  docker exec bytebot-omnibox curl http://172.30.0.4:5000/probe
  docker exec bytebot-omnibox curl http://172.30.0.3:5000/probe
  ```
- If the IP is different, update the health check in `docker/docker-compose.yml` or `docker/docker-compose.proxy.yml`

**Slow performance:**
- Increase allocated RAM: Set `OMNIBOX_RAM_SIZE=16G` in docker/.env
- Allocate more CPU cores: Set `OMNIBOX_CPU_CORES=8`
- Ensure SSD storage for VM disk

**API not responding:**
- Check container logs: `docker logs bytebot-omnibox`
- Verify port 5000 is accessible: `curl http://localhost:5000/probe`
- Wait for VM boot (can take 2-3 minutes)
- Check Python server is running inside VM (via VNC at `http://localhost:8006`)

## Resources

- [Microsoft OmniParser OmniBox](https://github.com/microsoft/OmniParser/tree/master/omnitool/omnibox)
- [Windows Container Documentation](https://github.com/dockur/windows)
- [PyAutoGUI Documentation](https://pyautogui.readthedocs.io/)

## License

OmniBox is based on Microsoft's OmniParser project. See upstream license for details.
