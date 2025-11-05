FROM python:3.12-slim

# Get build platform for architecture-specific optimizations
ARG TARGETPLATFORM
ARG BUILDPLATFORM

# Install system dependencies
RUN apt-get update && apt-get install -y \
    git \
    wget \
    curl \
    libgl1 \
    libglib2.0-0 \
    && rm -rf /var/lib/apt/lists/*

# Set working directory
WORKDIR /app

# Copy requirements first for better caching
COPY requirements.txt .

# Install PyTorch based on target platform
# ARM64 Multi-Platform Support:
#   - NVIDIA DGX Spark: CUDA 12.1 support on ARM64 (full GPU acceleration in Docker)
#   - Apple Silicon (M1-M4): MPS support via native execution (not in Docker)
#   - Fallback: CPU-only for compatibility
# AMD64: Full CUDA 12.1 support (backward compatible with 11.8+)
RUN if [ "$TARGETPLATFORM" = "linux/arm64" ]; then \
        echo "Building for ARM64 - installing CUDA 12.1 PyTorch for DGX Spark"; \
        echo "Note: For M4 Pro/Apple Silicon, run natively (not Docker) for MPS GPU"; \
        pip install --no-cache-dir torch torchvision --index-url https://download.pytorch.org/whl/cu121; \
    else \
        echo "Building for AMD64 - installing CUDA 12.1 PyTorch"; \
        pip install --no-cache-dir torch torchvision --index-url https://download.pytorch.org/whl/cu121; \
    fi

# Install remaining requirements
RUN pip install --no-cache-dir -r requirements.txt

# Copy application code
COPY src/ ./src/
COPY scripts/ ./scripts/
COPY pyproject.toml .

# Clone OmniParser repository
RUN git clone https://github.com/microsoft/OmniParser.git

# Apply PaddleOCR 3.x compatibility patch
RUN chmod +x scripts/patch-paddleocr.sh && \
    bash scripts/patch-paddleocr.sh

# Create weights directory
RUN mkdir -p weights

# Download models (this will be done at build time)
# In production, you might want to mount these or download at runtime
RUN chmod +x scripts/download_models.sh && \
    bash scripts/download_models.sh || echo "Model download skipped - will download at runtime"

# Expose port
EXPOSE 9989

# Health check
HEALTHCHECK --interval=30s --timeout=10s --start-period=60s --retries=3 \
    CMD curl -f http://localhost:9989/health || exit 1

# Create startup script with GPU diagnostics (ARM64 + x86_64)
RUN echo '#!/bin/bash\n\
echo "========================================"\n\
echo "OmniParser ARM64-Optimized GPU Diagnostics"\n\
echo "========================================"\n\
\n\
# Detect architecture\n\
ARCH=$(uname -m)\n\
echo "Architecture: $ARCH"\n\
\n\
# Check for NVIDIA runtime (DGX Spark / x86_64 CUDA)\n\
if [ -d "/proc/driver/nvidia" ]; then\n\
    echo "✓ NVIDIA driver detected in container"\n\
    ls -la /proc/driver/nvidia/ | head -5\n\
else\n\
    echo "⚠ No NVIDIA driver in /proc/driver/nvidia"\n\
fi\n\
\n\
# Check for NVIDIA devices\n\
if [ -e "/dev/nvidia0" ]; then\n\
    echo "✓ GPU device /dev/nvidia0 available"\n\
    ls -la /dev/nvidia* | head -5\n\
else\n\
    echo "⚠ No GPU devices found in /dev/"\n\
fi\n\
\n\
# Check CUDA libraries\n\
if ldconfig -p | grep -q libcuda.so; then\n\
    echo "✓ CUDA libraries found"\n\
    ldconfig -p | grep libcuda | head -3\n\
else\n\
    echo "⚠ No CUDA libraries in ldconfig"\n\
fi\n\
\n\
# Run PyTorch GPU check (CUDA + MPS)\n\
echo ""\n\
echo "PyTorch Device Detection:"\n\
python3 -c "\n\
import torch\n\
print(f\"  PyTorch Version: {torch.__version__}\")\n\
print(f\"  CUDA Available: {torch.cuda.is_available()}\")\n\
if torch.cuda.is_available():\n\
    print(f\"  CUDA Version: {torch.version.cuda}\")\n\
    print(f\"  GPU Count: {torch.cuda.device_count()}\")\n\
    for i in range(torch.cuda.device_count()):\n\
        print(f\"  GPU {i}: {torch.cuda.get_device_name(i)}\")\n\
# Check MPS (Apple Silicon - only works natively, not in Docker)\n\
try:\n\
    if torch.backends.mps.is_available():\n\
        print(f\"  MPS (Apple Silicon) Available: True\")\n\
    else:\n\
        print(f\"  MPS (Apple Silicon) Available: False (expected in Docker)\")\n\
except AttributeError:\n\
    print(f\"  MPS Not Supported (PyTorch < 1.12 or non-macOS)\")\n\
"\n\
\n\
echo "========================================"\n\
echo "Starting OmniParser Service..."\n\
echo "========================================"\n\
\n\
# Start the actual service\n\
exec python -m src.server\n\
' > /app/entrypoint.sh && chmod +x /app/entrypoint.sh

# Run the server with diagnostics
CMD ["/app/entrypoint.sh"]
