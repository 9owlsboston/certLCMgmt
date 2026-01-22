#!/bin/bash

# Configuration System Demo
# This script demonstrates the new centralized configuration system

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
NC='\033[0m' # No Color

echo -e "${BLUE}Certificate Lifecycle Management - Configuration System Demo${NC}"
echo "============================================================"
echo ""

echo -e "${GREEN}✨ NEW: Centralized Configuration System ✨${NC}"
echo ""
echo "This demo shows how the new configuration system eliminates hard-coded variables"
echo "and provides auto-discovery from your existing ARM template deployment."
echo ""

echo -e "${YELLOW}📋 Available Commands:${NC}"
echo ""
echo "  ./config.sh init                                    # Create .env from template"
echo "  ./config.sh auto-populate --resource-group <name>  # Auto-detect from deployment"
echo "  ./config.sh validate                               # Validate configuration"
echo "  ./config.sh show                                   # Show current configuration"
echo "  ./config.sh reset                                  # Reset to template"
echo ""

echo -e "${PURPLE}🔍 Example: Auto-populate from LAB deployment${NC}"
echo ""
echo "If you have a LAB environment with resource group 'rg-certlc-lab-12345':"
echo ""
echo -e "${BLUE}  ./config.sh auto-populate --resource-group rg-certlc-lab-12345${NC}"
echo ""
echo "This will:"
echo "  ✅ Detect your subscription ID and region"
echo "  ✅ Extract the unique string from resource names"
echo "  ✅ Discover all deployed resource names"
echo "  ✅ Generate a complete .env configuration file"
echo ""

echo -e "${PURPLE}🎯 Example: Manual setup${NC}"
echo ""
echo -e "${BLUE}  ./config.sh init${NC}"
echo -e "${BLUE}  nano .env${NC}              # Edit with your values"
echo -e "${BLUE}  ./config.sh validate${NC}"  
echo ""

echo -e "${GREEN}✅ Benefits:${NC}"
echo "  • No more editing variables in multiple scripts"
echo "  • Auto-discovery from existing deployments"
echo "  • Validation ensures complete configuration"
echo "  • All scripts use the same configuration"
echo "  • Easy maintenance and updates"
echo ""

echo -e "${YELLOW}📖 For complete documentation, see:${NC}"
echo "  - CONFIGURATION_GUIDE.md (detailed setup guide)"
echo "  - README.md (updated with configuration info)"
echo ""

# Check if .env exists and show status
if [ -f ".env" ]; then
    echo -e "${GREEN}✅ Configuration file (.env) already exists${NC}"
    echo "Run './config.sh show' to view current configuration"
    echo "Run './config.sh validate' to check if it's complete"
else
    echo -e "${YELLOW}⚠️  No configuration file found${NC}"
    echo "Run './config.sh init' or './config.sh auto-populate --resource-group <name>' to get started"
fi

echo ""
echo -e "${BLUE}Ready to eliminate hard-coded variables! 🚀${NC}"