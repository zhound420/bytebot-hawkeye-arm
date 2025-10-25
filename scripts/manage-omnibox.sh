#!/bin/bash
# OmniBox VM Management Script
# Manage Windows 11 VM for AI agent testing

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Print colored message
log_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Determine which compose file to use
get_compose_file() {
    if [ -f "$PROJECT_ROOT/docker/docker-compose.proxy.yml" ]; then
        echo "$PROJECT_ROOT/docker/docker-compose.proxy.yml"
    else
        echo "$PROJECT_ROOT/docker/docker-compose.yml"
    fi
}

COMPOSE_FILE=$(get_compose_file)

# Check prerequisites
check_prerequisites() {
    log_info "Checking prerequisites..."

    # Check Docker
    if ! command -v docker &> /dev/null; then
        log_error "Docker is not installed. Please install Docker Desktop."
        exit 1
    fi

    # Check Docker Compose
    if ! command -v docker compose &> /dev/null; then
        log_error "Docker Compose is not installed."
        exit 1
    fi

    # Check KVM (Linux only)
    if [[ "$OSTYPE" == "linux-gnu"* ]]; then
        if ! lsmod | grep -q kvm; then
            log_warn "KVM module not loaded. OmniBox requires KVM for virtualization."
            log_warn "Try: sudo modprobe kvm && sudo modprobe kvm_intel  # or kvm_amd"
        fi
    fi

    log_info "Prerequisites check passed"
}

# Wait for API to be ready
wait_for_api() {
    log_info "Waiting for Computer Use API to be ready..."

    local max_retries=60  # 5 minutes (5 seconds * 60)
    local retry_count=0

    while [ $retry_count -lt $max_retries ]; do
        if curl -sf http://localhost:5000/probe > /dev/null 2>&1; then
            log_info "✓ Computer Use API is ready!"
            return 0
        fi

        retry_count=$((retry_count + 1))
        echo -n "."
        sleep 5
    done

    log_error "API did not become ready within timeout"
    return 1
}

# Create and start VM
create_vm() {
    check_prerequisites

    log_info "Creating OmniBox Windows 11 VM..."

    # Check if Windows ISO exists
    ISO_PATH="$HOME/.cache/bytebot/iso/windows.iso"
    if [ ! -L "$ISO_PATH" ] || [ ! -e "$ISO_PATH" ]; then
        log_warn "Windows ISO not found at $ISO_PATH"
        log_warn "Please run: ./scripts/download-windows-iso.sh"
        log_info "Continuing anyway (Docker will try to download)..."
    fi

    # Start containers with omnibox profile
    log_info "Starting OmniBox container..."
    cd "$PROJECT_ROOT/docker"
    docker compose --profile omnibox -f "$(basename $COMPOSE_FILE)" up -d

    # Wait for API
    wait_for_api

    log_info "✓ OmniBox VM created successfully!"
    log_info "  Web Viewer: http://localhost:8006"
    log_info "  VNC: localhost:5900"
    log_info "  RDP: localhost:3389"
    log_info "  API: http://localhost:5000"
}

# Start existing VM
start_vm() {
    check_prerequisites

    log_info "Starting OmniBox VM..."
    docker start bytebot-omnibox bytebot-omnibox-adapter 2>/dev/null || {
        log_warn "Containers not found, trying docker compose start..."
        cd "$PROJECT_ROOT/docker"
        docker compose --profile omnibox -f "$(basename $COMPOSE_FILE)" start
    }

    wait_for_api

    log_info "✓ OmniBox VM started successfully!"
}

# Stop VM
stop_vm() {
    log_info "Stopping OmniBox VM..."
    docker stop bytebot-omnibox-adapter bytebot-omnibox 2>/dev/null || true
    log_info "✓ OmniBox VM stopped"
}

# Delete VM (WARNING: destroys all data)
delete_vm() {
    log_warn "This will DELETE all VM data (Windows installation, files, etc.)"
    log_warn "The VM will need to be reinstalled from scratch (20-90 minutes)"
    echo ""
    read -p "Type 'DELETE' to confirm: " response
    if [ "$response" != "DELETE" ]; then
        log_info "Cancelled"
        exit 0
    fi

    log_info "Stopping containers..."
    docker stop bytebot-omnibox-adapter bytebot-omnibox 2>/dev/null || true
    docker rm bytebot-omnibox-adapter bytebot-omnibox 2>/dev/null || true

    log_info "Deleting OmniBox volume..."
    docker volume rm bytebot_omnibox_data 2>/dev/null || {
        log_warn "Volume not found (may already be deleted)"
    }

    log_info "✓ OmniBox VM deleted"
    log_info "Run './scripts/manage-omnibox.sh create' to reinstall"
}

# Show VM status
status_vm() {
    log_info "OmniBox VM Status:"
    echo ""

    # Check containers
    if docker ps --format '{{.Names}}' | grep -q "bytebot-omnibox"; then
        docker ps --filter "name=bytebot-omnibox" --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}"
    else
        log_warn "OmniBox containers not running"
    fi

    echo ""

    # Check volume
    if docker volume ls --format '{{.Name}}' | grep -q "^bytebot_omnibox_data$"; then
        VOLUME_SIZE=$(docker volume inspect bytebot_omnibox_data --format '{{.Mountpoint}}' 2>/dev/null | xargs -I{} du -sh {} 2>/dev/null | cut -f1 || echo "unknown")
        log_info "Volume: bytebot_omnibox_data ($VOLUME_SIZE)"
    else
        log_warn "Volume: bytebot_omnibox_data (not found)"
    fi

    echo ""
    log_info "Testing API connection..."
    if curl -sf http://localhost:5000/probe > /dev/null 2>&1; then
        log_info "✓ API is responding"
    else
        log_warn "✗ API is not responding"
    fi
}

# Show logs
logs_vm() {
    docker logs bytebot-omnibox -f --tail 100
}

# Restart VM
restart_vm() {
    log_info "Restarting OmniBox VM..."
    stop_vm
    sleep 2
    start_vm
}

# Main
case "${1:-}" in
    create)
        create_vm
        ;;
    start)
        start_vm
        ;;
    stop)
        stop_vm
        ;;
    restart)
        restart_vm
        ;;
    delete)
        delete_vm
        ;;
    status)
        status_vm
        ;;
    logs)
        logs_vm
        ;;
    *)
        echo "OmniBox VM Management"
        echo ""
        echo "Usage: $0 {create|start|stop|restart|delete|status|logs}"
        echo ""
        echo "Commands:"
        echo "  create   - Create and start the OmniBox VM (first-time setup)"
        echo "  start    - Start existing OmniBox VM"
        echo "  stop     - Stop running OmniBox VM"
        echo "  restart  - Restart OmniBox VM"
        echo "  delete   - Delete OmniBox VM (WARNING: destroys all data)"
        echo "  status   - Show VM status and health"
        echo "  logs     - Show VM logs (follow mode)"
        echo ""
        echo "Examples:"
        echo "  $0 create    # First-time setup (20-90 minutes)"
        echo "  $0 start     # Quick start of existing VM (~30 seconds)"
        echo "  $0 delete    # Clean slate (for corrupted VM)"
        exit 1
        ;;
esac
