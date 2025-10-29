#!/bin/bash

# Deploy script for all frontend applications
# Usage: ./scripts/deploy-all.sh [environment] [options]

set -e

# Default values
ENVIRONMENT="dev"
SKIP_BUILD=false

# Parse command line arguments
while [[ $# -gt 0 ]]; do
  case $1 in
    -e|--environment)
      ENVIRONMENT="$2"
      shift 2
      ;;
    --skip-build)
      SKIP_BUILD=true
      shift
      ;;
    -h|--help)
      echo "Usage: $0 [options]"
      echo "Options:"
      echo "  -e, --environment ENV     Target environment (dev, staging, prod) [default: dev]"
      echo "  --skip-build             Skip building before deployment"
      echo "  -h, --help               Show this help message"
      exit 0
      ;;
    *)
      echo "Unknown option: $1"
      exit 1
      ;;
  esac
done

# Validate environment
if [[ ! "$ENVIRONMENT" =~ ^(dev|staging|prod)$ ]]; then
  echo "Error: Environment must be one of: dev, staging, prod"
  exit 1
fi

echo "🚀 Deploying all frontend applications to $ENVIRONMENT environment"
echo ""

# Build if not skipped
if [[ "$SKIP_BUILD" == false ]]; then
  echo "🔨 Building frontend applications..."
  # Get the directory where this script is located
  SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
  "$SCRIPT_DIR/build-all.sh"
  echo ""
fi

# Deploy user interface
echo "📦 Deploying user interface..."
cd user && npm run deploy:$ENVIRONMENT && cd ..
echo "✅ User interface deployed successfully"
echo ""

# Deploy admin interface
echo "📦 Deploying admin interface..."
cd admin && npm run deploy:$ENVIRONMENT && cd ..
echo "✅ Admin interface deployed successfully"

echo ""
echo "🎉 All frontend applications deployed successfully to $ENVIRONMENT!"
echo ""
echo "📝 Next steps:"
echo "   1. Update frontend configurations with WebSocket URL from infrastructure outputs"
echo "   2. Test the application end-to-end"
echo "   3. Consider invalidating CloudFront cache if needed"