#!/bin/bash

# Quick Certificate Lifecycle Status Check
# Convenience script that runs the monitoring tools from the reorganized structure

set -euo pipefail

echo "🔐 Certificate Lifecycle - Quick Status Check"
echo "============================================="

# Check if we're in the right directory
if [ ! -d "monitoring" ]; then
    echo "❌ Error: This script must be run from the certlc-deployment-scripts directory"
    exit 1
fi

# Run the quick status check
echo "⚡ Running quick status analysis..."
./monitoring/cert-quick-status.sh

echo ""
echo "🎯 Available Actions:"
echo "  📊 Full analysis:        ./run-full-analysis.sh"
echo "  🔍 PowerShell analysis:  pwsh ./monitoring/cert-lifecycle-events.ps1"
echo "  🚀 Deployment check:     ./diagnostics/check-deployment-status.sh"
echo "  📋 View documentation:   ./docs/"