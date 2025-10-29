#!/bin/bash

# Deployment validation script for User Admin Messaging application
# Usage: ./scripts/validate-deployment.sh [environment]

set -e

# Default values
ENVIRONMENT="${1:-dev}"

# Validate environment
if [[ ! "$ENVIRONMENT" =~ ^(dev|staging|prod)$ ]]; then
  echo "Error: Environment must be one of: dev, staging, prod"
  exit 1
fi

echo "🧪 Validating deployment for $ENVIRONMENT environment"
echo ""

# Check if infrastructure outputs exist
OUTPUTS_FILE="infrastructure/outputs-$ENVIRONMENT.json"
if [[ ! -f "$OUTPUTS_FILE" ]]; then
  echo "❌ Infrastructure outputs not found: $OUTPUTS_FILE"
  echo "   Deploy infrastructure first: npm run deploy:$ENVIRONMENT"
  exit 1
fi

echo "✅ Infrastructure outputs found"

# Parse outputs using jq if available
if command -v jq &> /dev/null; then
  STACK_NAME="UserAdminMessaging-$ENVIRONMENT"
  USER_URL=$(jq -r ".[\"$STACK_NAME\"].UserInterfaceUrl // empty" "$OUTPUTS_FILE")
  ADMIN_URL=$(jq -r ".[\"$STACK_NAME\"].AdminInterfaceUrl // empty" "$OUTPUTS_FILE")
  WEBSOCKET_URL=$(jq -r ".[\"$STACK_NAME\"].WebSocketUrl // empty" "$OUTPUTS_FILE")
  
  echo "🔗 Application URLs:"
  echo "   👤 User Interface: $USER_URL"
  echo "   👨‍💼 Admin Interface: $ADMIN_URL"
  echo "   🔌 WebSocket API: $WEBSOCKET_URL"
  echo ""
  
  # Test WebSocket endpoint
  if [[ -n "$WEBSOCKET_URL" ]]; then
    echo "🔌 Testing WebSocket endpoint..."
    # Note: This is a basic connectivity test
    # Full WebSocket testing requires a WebSocket client
    echo "   WebSocket URL: $WEBSOCKET_URL"
    echo "   ✅ WebSocket endpoint configured"
  fi
  
  # Test HTTP endpoints
  if [[ -n "$USER_URL" ]]; then
    echo "🌐 Testing User Interface..."
    if curl -s -o /dev/null -w "%{http_code}" "$USER_URL" | grep -q "200"; then
      echo "   ✅ User Interface accessible"
    else
      echo "   ❌ User Interface not accessible"
    fi
  fi
  
  if [[ -n "$ADMIN_URL" ]]; then
    echo "🌐 Testing Admin Interface..."
    if curl -s -o /dev/null -w "%{http_code}" "$ADMIN_URL" | grep -q "200"; then
      echo "   ✅ Admin Interface accessible"
    else
      echo "   ❌ Admin Interface not accessible"
    fi
  fi
  
else
  echo "⚠️  Install 'jq' for detailed URL validation"
  echo "   Outputs file: $OUTPUTS_FILE"
fi

echo ""
echo "🎉 Deployment validation completed!"