#!/bin/bash

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}Stopping Bytebot Hawkeye Stack...${NC}"
echo ""

cd docker

# Determine which compose file is active
if docker ps --format '{{.Names}}' | grep -q "bytebot-llm-proxy"; then
    COMPOSE_FILE="docker-compose.proxy.yml"
    echo "Detected: Proxy Stack"
else
    COMPOSE_FILE="docker-compose.yml"
    echo "Detected: Standard Stack"
fi

# Stop main Docker services
docker compose -f $COMPOSE_FILE down

echo ""
echo -e "${GREEN}✓ Main services stopped${NC}"

# Check for OmniBox containers (these use the 'omnibox' profile)
if docker ps -a --format '{{.Names}}' | grep -q "bytebot-omnibox"; then
    echo ""
    echo -e "${BLUE}Stopping OmniBox Windows desktop...${NC}"

    # Stop OmniBox containers directly (they use profiles and won't stop with normal down)
    docker stop bytebot-omnibox-adapter bytebot-omnibox 2>/dev/null || true
    docker rm bytebot-omnibox-adapter bytebot-omnibox 2>/dev/null || true

    echo -e "${GREEN}✓ OmniBox stopped and removed${NC}"
fi

# Clean up network if it exists
if docker network ls --format '{{.Name}}' | grep -q "bytebot_bytebot-network"; then
    docker network rm bytebot_bytebot-network 2>/dev/null || true
fi

# Check if native OmniParser is running
if command -v lsof >/dev/null 2>&1 && lsof -Pi :9989 -sTCP:LISTEN -t >/dev/null 2>&1; then
    echo ""
    echo -e "${YELLOW}Native OmniParser still running on port 9989${NC}"
    read -p "Stop native OmniParser too? [Y/n] " -n 1 -r
    echo ""
    if [[ ! $REPLY =~ ^[Nn]$ ]]; then
        cd ..
        ./scripts/stop-omniparser.sh
    fi
elif ss -tlnp 2>/dev/null | grep -q ":9989"; then
    echo ""
    echo -e "${YELLOW}Service detected on port 9989 (possibly native OmniParser)${NC}"
    read -p "Stop native OmniParser? [Y/n] " -n 1 -r
    echo ""
    if [[ ! $REPLY =~ ^[Nn]$ ]]; then
        cd ..
        ./scripts/stop-omniparser.sh
    fi
fi

echo ""
echo -e "${GREEN}✅ Stack stopped and cleaned up${NC}"
