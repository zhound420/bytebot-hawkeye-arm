#!/bin/bash

# Manual Setup/Troubleshooting Script for Trajectory Learning System
#
# NOTE: This script is NOT required for normal operation!
# The model learning system sets up automatically on first stack start.
#
# Use this script only for:
# - Troubleshooting existing database issues
# - Manually enabling pgvector on existing databases
# - Verifying trajectory table creation
#
# For normal setup, just run: ./scripts/start-stack.sh

set -e

echo "🔧 Manual Trajectory Learning System Setup/Troubleshooting..."

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

# Get database URL from environment or use default
DATABASE_URL="${DATABASE_URL:-postgresql://postgres:postgres@localhost:5432/bytebotdb}"

echo -e "${YELLOW}Database URL: ${DATABASE_URL}${NC}"

# Step 1: Enable pgvector extension
echo -e "\n${GREEN}Step 1: Enabling pgvector extension...${NC}"
if command -v psql &> /dev/null; then
  psql "$DATABASE_URL" -c "CREATE EXTENSION IF NOT EXISTS vector;" || {
    echo -e "${RED}Failed to enable pgvector. Trying with docker...${NC}"
    docker compose -f docker/docker-compose.yml exec -T bytebot-postgres psql -U postgres -d bytebotdb -c "CREATE EXTENSION IF NOT EXISTS vector;" || {
      echo -e "${RED}Failed to enable pgvector via docker. Make sure PostgreSQL is running.${NC}"
      exit 1
    }
  }
  echo -e "${GREEN}✓ pgvector extension enabled${NC}"
else
  echo -e "${YELLOW}psql not found, trying docker...${NC}"
  docker compose -f docker/docker-compose.yml exec -T bytebot-postgres psql -U postgres -d bytebotdb -c "CREATE EXTENSION IF NOT EXISTS vector;" || {
    echo -e "${RED}Failed to enable pgvector. Make sure PostgreSQL is running.${NC}"
    exit 1
  }
  echo -e "${GREEN}✓ pgvector extension enabled${NC}"
fi

# Step 2: Run Prisma migrations
echo -e "\n${GREEN}Step 2: Running Prisma migrations...${NC}"
cd packages/bytebot-agent || {
  echo -e "${RED}Failed to change to bytebot-agent directory${NC}"
  exit 1
}

npm run prisma:dev || {
  echo -e "${RED}Failed to run Prisma migrations${NC}"
  exit 1
}

echo -e "${GREEN}✓ Prisma migrations completed${NC}"

# Step 3: Verify tables
echo -e "\n${GREEN}Step 3: Verifying trajectory tables...${NC}"
cd ../..
if command -v psql &> /dev/null; then
  psql "$DATABASE_URL" -c "\dt" | grep -E "TaskTrajectory|TrajectoryStep|TrajectoryEmbedding|FewShotExample" && {
    echo -e "${GREEN}✓ All trajectory tables created successfully${NC}"
  } || {
    echo -e "${YELLOW}Warning: Some trajectory tables may not have been created${NC}"
  }
else
  echo -e "${YELLOW}Skipping table verification (psql not available)${NC}"
fi

# Summary
echo -e "\n${GREEN}================================================${NC}"
echo -e "${GREEN}Manual Setup/Troubleshooting Complete!${NC}"
echo -e "${GREEN}================================================${NC}"
echo -e ""
echo -e "${YELLOW}Note:${NC} This script is for troubleshooting only."
echo -e "The model learning system sets up ${GREEN}automatically${NC} on first stack start."
echo -e ""
echo -e "${YELLOW}System Configuration (enabled by default):${NC}"
echo -e "  • Trajectory recording: BYTEBOT_RECORD_TRAJECTORIES=true"
echo -e "  • Few-shot learning: BYTEBOT_USE_FEW_SHOT=true"
echo -e "  • Source models: BYTEBOT_RECORD_MODEL_PROVIDERS=anthropic"
echo -e ""
echo -e "${YELLOW}What happens automatically:${NC}"
echo -e "  1. pgvector extension enabled via migration"
echo -e "  2. Trajectory tables created via Prisma"
echo -e "  3. Claude's successful runs recorded for learning"
echo -e "  4. Other models auto-improve via few-shot examples"
echo -e ""
echo -e "${GREEN}System ready! Just run: ./scripts/start-stack.sh${NC}"
