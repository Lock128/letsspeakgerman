#!/bin/bash

# Destruction script for User Admin Messaging application
# Usage: ./scripts/destroy.sh [environment] [options]

set -e

# Default values
ENVIRONMENT="dev"
FORCE=false

# Parse command line arguments
while [[ $# -gt 0 ]]; do
  case $1 in
    -e|--environment)
      ENVIRONMENT="$2"
      shift 2
      ;;
    -f|--force)
      FORCE=true
      shift
      ;;
    -h|--help)
      echo "Usage: $0 [options]"
      echo "Options:"
      echo "  -e, --environment ENV     Target environment (dev, staging, prod) [default: dev]"
      echo "  -f, --force              Skip confirmation prompt"
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

echo "🗑️  Destroying User Admin Messaging application in $ENVIRONMENT environment"
echo ""

# Confirmation prompt (unless forced)
if [[ "$FORCE" == false ]]; then
  echo "⚠️  WARNING: This will permanently delete all resources in the $ENVIRONMENT environment!"
  echo "   This includes:"
  echo "   - DynamoDB table and all data"
  echo "   - S3 buckets and all files"
  echo "   - Lambda functions"
  echo "   - API Gateway"
  echo "   - CloudFront distribution"
  echo ""
  read -p "Are you sure you want to continue? (type 'yes' to confirm): " confirmation
  
  if [[ "$confirmation" != "yes" ]]; then
    echo "❌ Destruction cancelled"
    exit 0
  fi
fi

echo "🗑️  Destroying CDK stack..."

# Destroy the stack
if [[ "$FORCE" == true ]]; then
  cdk destroy --context environment="$ENVIRONMENT" --force
else
  cdk destroy --context environment="$ENVIRONMENT"
fi

# Clean up output files
if [[ -f "outputs-$ENVIRONMENT.json" ]]; then
  rm "outputs-$ENVIRONMENT.json"
  echo "🧹 Cleaned up outputs-$ENVIRONMENT.json"
fi

echo ""
echo "✅ Destruction completed successfully!"
echo "🧹 All resources for $ENVIRONMENT environment have been removed."