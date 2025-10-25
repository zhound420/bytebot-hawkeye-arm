#!/bin/bash

# Setup script for Trajectory Distillation & Few-Shot Learning
# Enables pgvector extension and runs database migrations

set -e

echo "🚀 Setting up Trajectory Learning System..."

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
echo -e "${GREEN}Trajectory Learning System Setup Complete!${NC}"
echo -e "${GREEN}================================================${NC}"
echo -e ""
echo -e "${YELLOW}Configuration:${NC}"
echo -e "  • Trajectory recording: BYTEBOT_RECORD_TRAJECTORIES=true"
echo -e "  • Few-shot learning: BYTEBOT_USE_FEW_SHOT=true"
echo -e "  • Source models: BYTEBOT_RECORD_MODEL_PROVIDERS=anthropic"
echo -e ""
echo -e "${YELLOW}Next steps:${NC}"
echo -e "  1. Ensure OpenAI API key is set (for embeddings): OPENAI_API_KEY or BYTEBOT_EMBEDDING_API_KEY"
echo -e "  2. Run tasks with Claude models to build trajectory dataset"
echo -e "  3. Test with other models (GPT, Gemini) to see improvement"
echo -e "  4. Export training data: cd packages/bytebot-agent && npm run export:trajectories"
echo -e ""
echo -e "${GREEN}System is ready to learn from successful task completions!${NC}"
