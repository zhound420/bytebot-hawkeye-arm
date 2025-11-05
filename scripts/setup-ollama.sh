#!/bin/bash
# Ollama VLM Auto-Discovery and Configuration
# Automatically detects Vision Language Models from Ollama and configures litellm proxy

set -e

# Colors for output
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

echo ""
echo "======================================"
echo "  Ollama VLM Auto-Discovery"
echo "======================================"
echo ""

# Get script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

# Step 1: Ask for Ollama URL
echo "Ollama allows running local Vision Language Models (VLMs) on your machine."
echo "Typical setup: Ollama running locally or on a separate machine with GPU."
echo ""
read -p "Enter Ollama URL [http://localhost:11434]: " OLLAMA_INPUT
OLLAMA_INPUT=${OLLAMA_INPUT:-http://localhost:11434}

# Normalize URL - strip trailing slash if present
OLLAMA_URL=$(echo "$OLLAMA_INPUT" | sed 's:/*$::')

echo ""

# Step 2: Test connectivity
log_info "Testing connection to ${OLLAMA_URL}..."
if ! curl -s -f -m 5 "${OLLAMA_URL}/api/tags" > /dev/null 2>&1; then
    log_error "Cannot connect to Ollama at ${OLLAMA_URL}"
    log_error "Please ensure:"
    log_error "  1. Ollama is running (check with: ollama list)"
    log_error "  2. Ollama server is accessible at ${OLLAMA_URL}"
    log_error "  3. Port 11434 is accessible from this machine"
    log_error "  4. If using remote Ollama, set OLLAMA_HOST environment variable"
    echo ""
    exit 1
fi

log_success "Connected to Ollama"
echo ""

# Step 3: Fetch available models
log_info "Fetching available models from Ollama..."
MODELS_JSON=$(curl -s "${OLLAMA_URL}/api/tags")

if [ -z "$MODELS_JSON" ] || [ "$MODELS_JSON" = "null" ]; then
    log_error "No response from Ollama /api/tags endpoint"
    exit 1
fi

# Step 4: Parse and filter VLMs
log_info "Filtering Vision Language Models (VLMs)..."

# VLM detection pattern - matches known vision model families
# Pattern includes: llava, qwen-vl, minicpm-v, bakllava, glm-4, llama3.2, internlm-vl, cogvlm, yi-vl, deepseek-vl
VLM_PATTERN="llava|qwen.*vl|qwen.*vision|minicpm-v|bakllava|glm-4|llama3\\.2|internlm.*vl|cogvlm|yi-vl|deepseek-vl|vision|vl|visual"

# Check for manual override file
OVERRIDE_FILE="$SCRIPT_DIR/ollama-vision-models.txt"
OVERRIDE_PATTERNS=""
if [ -f "$OVERRIDE_FILE" ]; then
    log_info "Loading manual vision model overrides from ollama-vision-models.txt..."
    # Read non-empty, non-comment lines and join with |
    OVERRIDE_PATTERNS=$(grep -v '^\s*#' "$OVERRIDE_FILE" | grep -v '^\s*$' | tr '\n' '|' | sed 's/|$//')
    if [ -n "$OVERRIDE_PATTERNS" ]; then
        VLM_PATTERN="${VLM_PATTERN}|${OVERRIDE_PATTERNS}"
        log_info "Added $(echo "$OVERRIDE_PATTERNS" | tr '|' '\n' | wc -l) manual override(s)"
    fi
fi

# Check if jq is available
if command -v jq &> /dev/null; then
    # Use jq for JSON parsing (more reliable)
    # Ollama returns models in .models[] array with .name field
    VLM_MODELS=$(echo "$MODELS_JSON" | jq -r '.models[]? | select(.name | test("'"${VLM_PATTERN}"'"; "i")) | .name' 2>/dev/null)
else
    # Fallback to grep (less reliable but works without jq)
    log_warn "jq not found, using grep (install jq for better reliability)"
    VLM_MODELS=$(echo "$MODELS_JSON" | grep -oP '"name":\s*"\K[^"]*' | grep -iE "${VLM_PATTERN}")
fi

if [ -z "$VLM_MODELS" ]; then
    log_warn "No VLM models found on Ollama"
    log_warn ""
    log_warn "Auto-detected VLM model families:"
    log_warn "  • llava (all variants)"
    log_warn "  • qwen-vl, qwen*vision (Qwen vision models)"
    log_warn "  • minicpm-v (MiniCPM vision)"
    log_warn "  • bakllava (BakLLaVa)"
    log_warn "  • glm-4 (GLM-4V vision models)"
    log_warn "  • llama3.2 (Llama 3.2-Vision)"
    log_warn "  • internlm-vl (InternLM vision)"
    log_warn "  • cogvlm (CogVLM series)"
    log_warn "  • yi-vl (Yi vision models)"
    log_warn "  • deepseek-vl (DeepSeek vision)"
    log_warn "  • vision, vl, visual (generic patterns)"
    echo ""
    log_warn "For models not auto-detected, create:"
    log_warn "  scripts/ollama-vision-models.txt"
    log_warn "  (one model name pattern per line)"
    echo ""
    log_info "Available models on Ollama:"
    if command -v jq &> /dev/null; then
        echo "$MODELS_JSON" | jq -r '.models[]? | .name' | while read -r model; do
            echo "  • $model"
        done
    else
        echo "$MODELS_JSON" | grep -oP '"name":\s*"\K[^"]*' | while read -r model; do
            echo "  • $model"
        done
    fi
    echo ""
    log_info "To download VLM models, try:"
    log_info "  ollama pull llava:latest"
    log_info "  ollama pull llava:13b"
    log_info "  ollama pull qwen2-vl:7b"
    log_info "  ollama pull minicpm-v:latest"
    log_info "  ollama pull glm4:latest"
    echo ""
    exit 0
fi

# Count VLMs
VLM_COUNT=$(echo "$VLM_MODELS" | wc -l | tr -d ' ')

log_success "Found ${VLM_COUNT} VLM model(s):"
echo "$VLM_MODELS" | while read -r model; do
    echo "  • $model"
done
echo ""

# Step 5: Generate litellm-config.yaml entries
CONFIG_FILE="$PROJECT_ROOT/packages/bytebot-llm-proxy/litellm-config.yaml"

if [ ! -f "$CONFIG_FILE" ]; then
    log_error "litellm-config.yaml not found at $CONFIG_FILE"
    exit 1
fi

# Create backup
BACKUP_FILE="${CONFIG_FILE}.backup.$(date +%s)"
log_info "Backing up existing config to ${BACKUP_FILE}..."
cp "$CONFIG_FILE" "$BACKUP_FILE"

# Create temp file with new models
TEMP_MODELS=$(mktemp)

echo "$VLM_MODELS" | while read -r model; do
    # Generate sanitized model name for litellm
    # Replace : with - (ollama uses : for tags like llava:13b)
    SAFE_NAME=$(echo "$model" | tr ':' '-' | tr '/' '-' | tr ' ' '-' | tr '[:upper:]' '[:lower:]')

    cat >> "$TEMP_MODELS" << EOF
  - model_name: local-ollama-${SAFE_NAME}
    litellm_params:
      model: ollama_chat/${model}
      api_base: ${OLLAMA_URL}
      supports_function_calling: true
    model_info:
      supports_vision: true
EOF
done

# Step 6: Update litellm-config.yaml
log_info "Updating litellm-config.yaml..."

# Remove old Ollama auto-generated entries (between markers)
# Strategy: Delete from first Ollama marker to litellm_settings (keep litellm_settings line)
sed -i.tmp '/# Ollama VLM models/,/^litellm_settings:/{/^litellm_settings:/!d;}' "$CONFIG_FILE"

# Also remove any stray auto-discovered entries from previous runs
sed -i.tmp '/# Add local models via Ollama/,/^litellm_settings:/{/^litellm_settings:/!d;}' "$CONFIG_FILE"

# Insert new models before litellm_settings
TIMESTAMP=$(date +"%Y-%m-%d %H:%M:%S")
# Using perl for macOS/Linux compatibility (BSD sed vs GNU sed syntax)
perl -i.tmp -pe 'print "  # Ollama VLM models (auto-discovered on '"${TIMESTAMP}"')\n" if /^litellm_settings:/' "$CONFIG_FILE"
sed -i.tmp "/# Ollama VLM models (auto-discovered on ${TIMESTAMP})/r $TEMP_MODELS" "$CONFIG_FILE"

rm -f "${CONFIG_FILE}.tmp" "$TEMP_MODELS"

log_success "Added ${VLM_COUNT} VLM model(s) to litellm-config.yaml"
echo ""

# Step 7: Update .env.defaults with Ollama URL
ENV_DEFAULTS_FILE="$PROJECT_ROOT/docker/.env.defaults"
ENV_FILE="$PROJECT_ROOT/docker/.env"

if [ -f "$ENV_DEFAULTS_FILE" ]; then
    if grep -q "^OLLAMA_URL=" "$ENV_DEFAULTS_FILE"; then
        # Update existing entry
        sed -i.tmp "s|^OLLAMA_URL=.*|OLLAMA_URL=${OLLAMA_URL}|" "$ENV_DEFAULTS_FILE"
        rm -f "${ENV_DEFAULTS_FILE}.tmp"
        log_info "Updated OLLAMA_URL in .env.defaults"
    else
        # Add new entry
        echo "" >> "$ENV_DEFAULTS_FILE"
        echo "# Ollama Configuration (added by setup-ollama.sh)" >> "$ENV_DEFAULTS_FILE"
        echo "OLLAMA_URL=${OLLAMA_URL}" >> "$ENV_DEFAULTS_FILE"
        log_success "Added OLLAMA_URL to .env.defaults"
    fi
else
    log_warn ".env.defaults file not found, skipping OLLAMA_URL configuration"
fi

# Sync OLLAMA_URL from .env.defaults to .env (Docker Compose reads .env)
if [ -f "$ENV_FILE" ] && [ -f "$ENV_DEFAULTS_FILE" ]; then
    if grep -q "^OLLAMA_URL=" "$ENV_DEFAULTS_FILE"; then
        OLLAMA_VALUE=$(grep "^OLLAMA_URL=" "$ENV_DEFAULTS_FILE" | cut -d= -f2-)
        if grep -q "^OLLAMA_URL=" "$ENV_FILE"; then
            sed -i.tmp "s|^OLLAMA_URL=.*|OLLAMA_URL=$OLLAMA_VALUE|" "$ENV_FILE"
            rm -f "${ENV_FILE}.tmp"
        else
            echo "OLLAMA_URL=$OLLAMA_VALUE" >> "$ENV_FILE"
        fi
        log_info "Synced OLLAMA_URL to .env"
    fi
fi

echo ""
log_success "========================================="
log_success "  Ollama Configuration Complete!"
log_success "========================================="
echo ""
log_info "Configured Models:"
echo "$VLM_MODELS" | while read -r model; do
    SAFE_NAME=$(echo "$model" | tr ':' '-' | tr '/' '-' | tr ' ' '-' | tr '[:upper:]' '[:lower:]')
    echo "  • local-ollama-${SAFE_NAME}"
done
echo ""
log_info "Next Steps:"
echo "  1. Restart the stack to load new models:"
echo "     ${BLUE}./scripts/stop-stack.sh && ./scripts/start-stack.sh${NC}"
echo ""
echo "  2. Models will appear in UI at: ${BLUE}http://localhost:9992${NC}"
echo ""
log_info "Backup saved: ${BACKUP_FILE}"
echo ""
