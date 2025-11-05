#!/bin/bash

# ═══════════════════════════════════════════════════════════════
#  DEPRECATED: start-stack.sh
# ═══════════════════════════════════════════════════════════════
#
#  This script has been superseded by the unified start.sh
#
#  Please use: ./scripts/start.sh
#
#  Rationale:
#  - start.sh now includes all ARM64-specific logic
#  - Unified platform detection via detect-arm64-platform.sh
#  - Better support for DGX Spark and generic ARM64
#  - Simpler maintenance with single entry point
#
#  The original version has been preserved at:
#    scripts/legacy/start-stack.sh.legacy
#
# ═══════════════════════════════════════════════════════════════

echo "⚠️  DEPRECATED: start-stack.sh has been replaced by start.sh"
echo ""
echo "Please use the new unified startup script:"
echo "  ./scripts/start.sh"
echo ""
echo "The enhanced start.sh provides:"
echo "  • Unified ARM64 platform detection"
echo "  • Apple Silicon native OmniParser support"
echo "  • DGX Spark ARM64 + CUDA support"
echo "  • Automatic docker-compose.arm64.yml overlay"
echo "  • Platform-specific documentation links"
echo ""
echo "Forwarding to start.sh in 3 seconds..."
sleep 3

exec "$(dirname "$0")/start.sh" "$@"
