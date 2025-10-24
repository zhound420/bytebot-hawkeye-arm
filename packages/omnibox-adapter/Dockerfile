# =============================================================================
# OmniBox Adapter Dockerfile - Workspace-based build
# Windows Desktop Control Service
# =============================================================================

FROM node:20.19.5-slim AS base

# Install system dependencies
RUN apt-get update && apt-get install -y \
    curl \
    ca-certificates \
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
    echo "✓ bytebot-cv built successfully"

# Build omnibox-adapter
WORKDIR /app/packages/omnibox-adapter
RUN echo "=== Building omnibox-adapter application ===" && \
    npx @nestjs/cli build && \
    echo "✓ omnibox-adapter built successfully"

# Expose port
EXPOSE 5001

# Set runtime environment variables
ENV PORT=5001 \
    OMNIBOX_URL=http://omnibox:5000 \
    OMNIPARSER_URL=http://bytebot-omniparser:9989

# Health check
HEALTHCHECK --interval=30s --timeout=10s --start-period=10s --retries=3 \
  CMD node -e "require('http').get('http://localhost:5001/health', (r) => process.exit(r.statusCode === 200 ? 0 : 1))"

WORKDIR /app/packages/omnibox-adapter

# Start application
CMD ["npm", "run", "start:prod"]
