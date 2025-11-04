#!/bin/bash
# LMStudio VLM Auto-Discovery and Configuration
# Automatically detects Vision Language Models from LMStudio and configures litellm proxy

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
echo "  LMStudio VLM Auto-Discovery"
echo "======================================"
echo ""

# Get script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

# Step 1: Ask for LMStudio IP
echo "LMStudio allows running local Vision Language Models (VLMs) on your network."
echo "Typical setup: LMStudio running on a separate machine with GPU."
echo ""
read -p "Enter LMStudio IP address [192.168.4.250]: " LMSTUDIO_IP
LMSTUDIO_IP=${LMSTUDIO_IP:-192.168.4.250}
LMSTUDIO_URL="http://${LMSTUDIO_IP}:1234"

echo ""

# Step 2: Test connectivity
log_info "Testing connection to ${LMSTUDIO_URL}..."
if ! curl -s -f -m 5 "${LMSTUDIO_URL}/v1/models" > /dev/null 2>&1; then
    log_error "Cannot connect to LMStudio at ${LMSTUDIO_URL}"
    log_error "Please ensure:"
    log_error "  1. LMStudio is running on ${LMSTUDIO_IP}"
    log_error "  2. Local server is enabled in LMStudio settings"
    log_error "  3. Port 1234 is accessible from this machine"
    log_error "  4. Firewall allows connections"
    echo ""
    exit 1
fi

log_success "Connected to LMStudio"
echo ""

# Step 3: Fetch available models
log_info "Fetching available models from LMStudio..."
MODELS_JSON=$(curl -s "${LMSTUDIO_URL}/v1/models")

if [ -z "$MODELS_JSON" ] || [ "$MODELS_JSON" = "null" ]; then
    log_error "No response from LMStudio /v1/models endpoint"
    exit 1
fi

# Step 4: Parse and filter VLMs
log_info "Filtering Vision Language Models (VLMs)..."

# Check if jq is available
if command -v jq &> /dev/null; then
    # Use jq for JSON parsing (more reliable)
    VLM_MODELS=$(echo "$MODELS_JSON" | jq -r '.data[]? | select(.id | test("vl|vision|visual|multimodal|llava|cogvlm|internvl|qwen.*vl|ui-tars"; "i")) | .id' 2>/dev/null)
else
    # Fallback to grep (less reliable but works without jq)
    log_warn "jq not found, using grep (install jq for better reliability)"
    VLM_MODELS=$(echo "$MODELS_JSON" | grep -oP '"id":\s*"\K[^"]*' | grep -iE 'vl|vision|visual|llava|cogvlm|internvl|qwen.*vl|ui-tars')
fi

if [ -z "$VLM_MODELS" ]; then
    log_warn "No VLM models found on LMStudio"
    log_warn ""
    log_warn "VLM models must have one of these in the name:"
    log_warn "  • vl (vision-language)"
    log_warn "  • vision"
    log_warn "  • visual"
    log_warn "  • multimodal"
    log_warn "  • llava, cogvlm, internvl (known VLM families)"
    log_warn "  • ui-tars (UI-specific models)"
    echo ""
    log_info "Available models on LMStudio:"
    if command -v jq &> /dev/null; then
        echo "$MODELS_JSON" | jq -r '.data[]? | .id' | while read -r model; do
            echo "  • $model"
        done
    else
        echo "$MODELS_JSON" | grep -oP '"id":\s*"\K[^"]*' | while read -r model; do
            echo "  • $model"
        done
    fi
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
    SAFE_NAME=$(echo "$model" | tr '/' '-' | tr ' ' '-' | tr '[:upper:]' '[:lower:]')

    cat >> "$TEMP_MODELS" << EOF
  - model_name: local-lmstudio-${SAFE_NAME}
    litellm_params:
      model: openai/${model}
      api_base: ${LMSTUDIO_URL}/v1
      api_key: lm-studio
      supports_function_calling: true
    model_info:
      supports_vision: true
EOF
done

# Step 6: Update litellm-config.yaml
log_info "Updating litellm-config.yaml..."

# Remove old LMStudio auto-generated entries (between markers)
# Strategy: Delete from first LMStudio marker to next section (Ollama) or litellm_settings
if grep -q "# Ollama VLM models" "$CONFIG_FILE"; then
    # Ollama section exists, delete from LMStudio to Ollama (keep Ollama line)
    sed -i.tmp '/# LMStudio VLM models/,/# Ollama VLM models/{/# Ollama VLM models/!d;}' "$CONFIG_FILE"
else
    # No Ollama section, delete from LMStudio to litellm_settings (keep litellm_settings line)
    sed -i.tmp '/# LMStudio VLM models/,/^litellm_settings:/{/^litellm_settings:/!d;}' "$CONFIG_FILE"
fi

# Also remove old manual LMStudio entries if they exist
sed -i.tmp '/# Add local models via LMStudio/,/^litellm_settings:/{/^litellm_settings:/!d;}' "$CONFIG_FILE"

# Insert new models before Ollama section (if exists) or litellm_settings
TIMESTAMP=$(date +"%Y-%m-%d %H:%M:%S")
if grep -q "# Ollama VLM models" "$CONFIG_FILE"; then
    # Insert before Ollama section
    sed -i.tmp '/# Ollama VLM models/i\  # LMStudio VLM models (auto-discovered on '"${TIMESTAMP}"')' "$CONFIG_FILE"
    sed -i.tmp "/# LMStudio VLM models (auto-discovered on ${TIMESTAMP})/r $TEMP_MODELS" "$CONFIG_FILE"
else
    # Insert before litellm_settings
    sed -i.tmp '/^litellm_settings:/i\  # LMStudio VLM models (auto-discovered on '"${TIMESTAMP}"')' "$CONFIG_FILE"
    sed -i.tmp "/# LMStudio VLM models (auto-discovered on ${TIMESTAMP})/r $TEMP_MODELS" "$CONFIG_FILE"
fi

rm -f "${CONFIG_FILE}.tmp" "$TEMP_MODELS"

log_success "Added ${VLM_COUNT} VLM model(s) to litellm-config.yaml"
echo ""

# Step 7: Update .env.defaults with LMStudio URL
ENV_DEFAULTS_FILE="$PROJECT_ROOT/docker/.env.defaults"
ENV_FILE="$PROJECT_ROOT/docker/.env"

if [ -f "$ENV_DEFAULTS_FILE" ]; then
    if grep -q "^LMSTUDIO_URL=" "$ENV_DEFAULTS_FILE"; then
        # Update existing entry
        sed -i.tmp "s|^LMSTUDIO_URL=.*|LMSTUDIO_URL=${LMSTUDIO_URL}|" "$ENV_DEFAULTS_FILE"
        rm -f "${ENV_DEFAULTS_FILE}.tmp"
        log_info "Updated LMSTUDIO_URL in .env.defaults"
    else
        # Add new entry
        echo "" >> "$ENV_DEFAULTS_FILE"
        echo "# LMStudio Configuration (added by setup-lmstudio.sh)" >> "$ENV_DEFAULTS_FILE"
        echo "LMSTUDIO_URL=${LMSTUDIO_URL}" >> "$ENV_DEFAULTS_FILE"
        log_success "Added LMSTUDIO_URL to .env.defaults"
    fi
else
    log_warn ".env.defaults file not found, skipping LMSTUDIO_URL configuration"
fi

# Sync LMSTUDIO_URL from .env.defaults to .env (Docker Compose reads .env)
if [ -f "$ENV_FILE" ] && [ -f "$ENV_DEFAULTS_FILE" ]; then
    if grep -q "^LMSTUDIO_URL=" "$ENV_DEFAULTS_FILE"; then
        LMSTUDIO_VALUE=$(grep "^LMSTUDIO_URL=" "$ENV_DEFAULTS_FILE" | cut -d= -f2-)
        if grep -q "^LMSTUDIO_URL=" "$ENV_FILE"; then
            sed -i.tmp "s|^LMSTUDIO_URL=.*|LMSTUDIO_URL=$LMSTUDIO_VALUE|" "$ENV_FILE"
            rm -f "${ENV_FILE}.tmp"
        else
            echo "LMSTUDIO_URL=$LMSTUDIO_VALUE" >> "$ENV_FILE"
        fi
        log_info "Synced LMSTUDIO_URL to .env"
    fi
fi

echo ""
log_success "========================================="
log_success "  LMStudio Configuration Complete!"
log_success "========================================="
echo ""
log_info "Configured Models:"
echo "$VLM_MODELS" | while read -r model; do
    SAFE_NAME=$(echo "$model" | tr '/' '-' | tr ' ' '-' | tr '[:upper:]' '[:lower:]')
    echo "  • local-lmstudio-${SAFE_NAME}"
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
