#!/bin/bash

# Certificate Lifecycle Scripts - Directory Explorer
# Shows the organized structure and provides quick navigation

echo "🔐 Certificate Lifecycle Deployment Scripts - Directory Structure"
echo "================================================================="
echo ""

echo "📊 MONITORING (Certificate lifecycle analysis & monitoring)"
echo "   ./monitoring/"
ls -la monitoring/ | grep -E '\.(sh|ps1)$' | awk '{print "   ├── " $9}'
echo ""

echo "🚀 DEPLOYMENT (Deployment scripts & templates)"
echo "   ./deployment/"  
ls -la deployment/ | grep -E '\.(sh|json)$' | awk '{print "   ├── " $9}'
echo ""

echo "🔍 DIAGNOSTICS (Troubleshooting & diagnostic tools)"
echo "   ./diagnostics/"
ls -la diagnostics/ | grep -E '\.(sh|ps1)$' | awk '{print "   ├── " $9}'
echo ""

echo "🧪 TESTING (Certificate testing & development tools)"
echo "   ./testing/"
ls -la testing/ | grep -E '\.(ps1|sh)$' | awk '{print "   ├── " $9}'
echo ""

echo "📚 DOCS (Comprehensive documentation)"
echo "   ./docs/"
ls -la docs/ | grep -E '\.md$' | awk '{print "   ├── " $9}'
echo ""

echo "⚡ CONVENIENCE SCRIPTS (Quick access)"
echo "   ├── quick-status.sh         # Fast 30-second status check"
echo "   └── run-full-analysis.sh    # Comprehensive analysis"
echo ""

echo "🎯 QUICK START:"
echo "   ./quick-status.sh                    # Fast overview"
echo "   ./run-full-analysis.sh               # Full analysis"  
echo "   ./monitoring/cert-lifecycle-status.sh # Direct tool access"
echo ""

echo "📖 DOCUMENTATION:"
echo "   cat ./docs/CERTIFICATE_MONITORING_GUIDE.md"
echo "   cat ./README.md"
echo ""

echo "Total files organized: $(find . -type f \( -name '*.sh' -o -name '*.ps1' -o -name '*.json' -o -name '*.md' \) | wc -l)"