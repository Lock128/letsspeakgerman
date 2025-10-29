#!/bin/bash

# Complete deployment script for User Admin Messaging application
# Usage: ./scripts/deploy-complete.sh [environment] [options]

set -e

# Default values
ENVIRONMENT="dev"
SKIP_INFRASTRUCTURE=false
SKIP_FRONTEND=false
SKIP_BUILD=false

# Parse command line arguments
while [[ $# -gt 0 ]]; do
  case $1 in
    -e|--environment)
      ENVIRONMENT="$2"
      shift 2
      ;;
    --skip-infrastructure)
      SKIP_INFRASTRUCTURE=true
      shift
      ;;
    --skip-frontend)
      SKIP_FRONTEND=true
      shift
      ;;
    --skip-build)
      SKIP_BUILD=true
      shift
      ;;
    -h|--help)
      echo "Usage: $0 [options]"
      echo "Options:"
      echo "  -e, --environment ENV     Target environment (dev, staging, prod) [default: dev]"
      echo "  --skip-infrastructure    Skip infrastructure deployment"
      echo "  --skip-frontend          Skip frontend deployment"
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

echo "🚀 Complete deployment of User Admin Messaging application"
echo "📋 Configuration:"
echo "   Environment: $ENVIRONMENT"
echo "   Skip infrastructure: $SKIP_INFRASTRUCTURE"
echo "   Skip frontend: $SKIP_FRONTEND"
echo "   Skip build: $SKIP_BUILD"
echo ""

# Step 1: Build Lambda functions
if [[ "$SKIP_BUILD" == false ]]; then
  echo "🔨 Step 1: Building Lambda functions..."
  npm run build:lambda
  echo "✅ Lambda functions built successfully"
  echo ""
fi

# Step 2: Deploy infrastructure
if [[ "$SKIP_INFRASTRUCTURE" == false ]]; then
  echo "🏗️  Step 2: Deploying infrastructure..."
  npm run deploy:$ENVIRONMENT
  echo "✅ Infrastructure deployed successfully"
  echo ""
fi

# Step 3: Configure frontend endpoints
echo "🔧 Step 3: Configuring frontend endpoints..."
npm run configure:endpoints:$ENVIRONMENT
echo "✅ Frontend endpoints configured"
echo ""

# Step 4: Build and deploy frontend
if [[ "$SKIP_FRONTEND" == false ]]; then
  echo "📦 Step 4: Building and deploying frontend..."
  npm run deploy:frontend:simple:$ENVIRONMENT
  echo "✅ Frontend deployed successfully"
  echo ""
fi

# Step 5: Validate deployment
echo "🧪 Step 5: Validating deployment..."
./scripts/validate-deployment.sh $ENVIRONMENT
echo ""

# Step 6: Display final information
echo "🎉 Complete deployment finished successfully!"
echo ""

# Read and display important URLs
OUTPUTS_FILE="infrastructure/outputs-$ENVIRONMENT.json"
if [[ -f "$OUTPUTS_FILE" ]]; then
  echo "🔗 Application URLs:"
  
  if command -v jq &> /dev/null; then
    STACK_NAME="UserAdminMessaging-$ENVIRONMENT"
    USER_URL=$(jq -r ".[\"$STACK_NAME\"].UserInterfaceUrl // empty" "$OUTPUTS_FILE")
    ADMIN_URL=$(jq -r ".[\"$STACK_NAME\"].AdminInterfaceUrl // empty" "$OUTPUTS_FILE")
    WEBSOCKET_URL=$(jq -r ".[\"$STACK_NAME\"].WebSocketUrl // empty" "$OUTPUTS_FILE")
    
    if [[ -n "$USER_URL" ]]; then
      echo "   👤 User Interface: $USER_URL"
    fi
    if [[ -n "$ADMIN_URL" ]]; then
      echo "   👨‍💼 Admin Interface: $ADMIN_URL"
    fi
    if [[ -n "$WEBSOCKET_URL" ]]; then
      echo "   🔌 WebSocket API: $WEBSOCKET_URL"
    fi
  else
    echo "   📄 Check $OUTPUTS_FILE for URLs (install 'jq' for formatted display)"
  fi
fi

echo ""
echo "📝 Testing checklist:"
echo "   ✓ Infrastructure deployed"
echo "   ✓ Frontend applications built and deployed"
echo "   ✓ WebSocket endpoints configured"
echo ""
echo "🧪 Manual testing steps:"
echo "   1. Open the User Interface URL"
echo "   2. Open the Admin Interface URL in another tab"
echo "   3. Click the button in the User Interface"
echo "   4. Verify the message appears in the Admin Interface"
echo ""
echo "🔧 Troubleshooting:"
echo "   - Check CloudWatch logs for Lambda function errors"
echo "   - Verify WebSocket connections in browser developer tools"
echo "   - CloudFront may take a few minutes to serve updated content"