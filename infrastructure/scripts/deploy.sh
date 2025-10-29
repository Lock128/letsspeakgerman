#!/bin/bash

# Deployment script for User Admin Messaging application
# Usage: ./scripts/deploy.sh [environment] [options]

set -e

# Default values
ENVIRONMENT="dev"
SKIP_BUILD=false
SKIP_LAMBDA_BUILD=false
REQUIRE_APPROVAL="never"

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
    --skip-lambda-build)
      SKIP_LAMBDA_BUILD=true
      shift
      ;;
    --require-approval)
      REQUIRE_APPROVAL="$2"
      shift 2
      ;;
    -h|--help)
      echo "Usage: $0 [options]"
      echo "Options:"
      echo "  -e, --environment ENV     Target environment (dev, staging, prod) [default: dev]"
      echo "  --skip-build             Skip TypeScript compilation"
      echo "  --skip-lambda-build      Skip Lambda function build"
      echo "  --require-approval MODE  CDK approval mode (never, any-change, broadening) [default: never for dev, broadening for others]"
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

# Set approval mode based on environment if not specified
if [[ "$REQUIRE_APPROVAL" == "never" && "$ENVIRONMENT" != "dev" ]]; then
  REQUIRE_APPROVAL="broadening"
fi

echo "🚀 Deploying User Admin Messaging application to $ENVIRONMENT environment"
echo "📋 Configuration:"
echo "   Environment: $ENVIRONMENT"
echo "   Skip build: $SKIP_BUILD"
echo "   Skip Lambda build: $SKIP_LAMBDA_BUILD"
echo "   Require approval: $REQUIRE_APPROVAL"
echo ""

# Build Lambda functions if not skipped
if [[ "$SKIP_LAMBDA_BUILD" == false ]]; then
  echo "🔨 Building Lambda functions..."
  cd ../lambda
  npm run build
  cd ../infrastructure
  echo "✅ Lambda functions built successfully"
fi

# Build infrastructure if not skipped
if [[ "$SKIP_BUILD" == false ]]; then
  echo "🔨 Building CDK infrastructure..."
  npm run build
  echo "✅ Infrastructure built successfully"
fi

# Deploy the stack
echo "🚀 Deploying CDK stack..."
cdk deploy \
  --context environment="$ENVIRONMENT" \
  --require-approval "$REQUIRE_APPROVAL" \
  --progress events \
  --outputs-file "outputs-$ENVIRONMENT.json"

echo ""
echo "✅ Deployment completed successfully!"
echo "📄 Stack outputs saved to: outputs-$ENVIRONMENT.json"

# Display important outputs
if [[ -f "outputs-$ENVIRONMENT.json" ]]; then
  echo ""
  echo "🔗 Important URLs:"
  
  # Extract URLs from outputs (requires jq)
  if command -v jq &> /dev/null; then
    STACK_NAME="UserAdminMessaging-$ENVIRONMENT"
    WEBSOCKET_URL=$(jq -r ".[\"$STACK_NAME\"].WebSocketUrl // empty" "outputs-$ENVIRONMENT.json")
    USER_URL=$(jq -r ".[\"$STACK_NAME\"].UserInterfaceUrl // empty" "outputs-$ENVIRONMENT.json")
    ADMIN_URL=$(jq -r ".[\"$STACK_NAME\"].AdminInterfaceUrl // empty" "outputs-$ENVIRONMENT.json")
    
    if [[ -n "$WEBSOCKET_URL" ]]; then
      echo "   WebSocket API: $WEBSOCKET_URL"
    fi
    if [[ -n "$USER_URL" ]]; then
      echo "   User Interface: $USER_URL"
    fi
    if [[ -n "$ADMIN_URL" ]]; then
      echo "   Admin Interface: $ADMIN_URL"
    fi
  else
    echo "   Install 'jq' to see formatted URLs, or check outputs-$ENVIRONMENT.json"
  fi
fi

echo ""
echo "🎉 Deployment complete! Don't forget to update frontend configurations with the WebSocket URL."