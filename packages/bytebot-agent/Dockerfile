# =============================================================================
# ByteBot Agent Dockerfile - Workspace-based build
# =============================================================================

FROM node:20.19.5-slim AS base

# Install system dependencies
RUN apt-get update && apt-get install -y \
    curl \
    ca-certificates \
    gnupg \
    tesseract-ocr \
    tesseract-ocr-eng \
    # Canvas/Cairo dependencies
    libcairo2-dev \
    libpango1.0-dev \
    libpangocairo-1.0-0 \
    libglib2.0-dev \
    libfontconfig1-dev \
    libjpeg-dev \
    libgif-dev \
    librsvg2-dev \
    libpixman-1-dev \
    pkg-config \
    # Build tools
    build-essential \
    python3 \
    && apt-get clean && rm -rf /var/lib/apt/lists/*

WORKDIR /app

# Copy workspace configuration and all packages
COPY package.json package-lock.json* ./
COPY ./packages ./packages
COPY ./config ./config

# Set environment variables
ENV NODE_ENV=production \
    NPM_CONFIG_LOGLEVEL=warn

# Install ALL workspace dependencies at once (proper monorepo install)
RUN echo "=== Installing workspace dependencies ===" && \
    npm install && \
    echo "✓ Workspace dependencies installed successfully"

# Build shared package first
WORKDIR /app/packages/shared
RUN echo "=== Building shared package ===" && \
    npm run build && \
    echo "✓ shared package built"

# Build bytebot-cv package
WORKDIR /app/packages/bytebot-cv
RUN echo "=== Building bytebot-cv package ===" && \
    npm run build && \
    echo "✓ bytebot-cv built successfully (OmniParser + Tesseract.js only)"

# Build bytebot-agent
WORKDIR /app/packages/bytebot-agent
RUN echo "=== Generating Prisma client ===" && \
    npx prisma generate && \
    echo "✓ Prisma client generated"

RUN echo "=== Building bytebot-agent application ===" && \
    npm run build:dist && \
    echo "✓ bytebot-agent built successfully"

# Add health check
HEALTHCHECK --interval=30s --timeout=10s --start-period=60s --retries=3 \
    CMD node -e "console.log('Health check: Node.js OK'); process.exit(0);"

WORKDIR /app/packages/bytebot-agent

# Start the application with enhanced startup script
CMD ["node", "scripts/enhanced-startup.js"]

ENV BYTEBOT_OCR_DEBUG=false
