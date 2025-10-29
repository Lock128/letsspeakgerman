#!/bin/bash

# Bootstrap script for CDK deployment
# Usage: ./scripts/bootstrap.sh [environment] [options]

set -e

# Default values
ENVIRONMENT="dev"
REGION=""
ACCOUNT=""

# Parse command line arguments
while [[ $# -gt 0 ]]; do
  case $1 in
    -e|--environment)
      ENVIRONMENT="$2"
      shift 2
      ;;
    -r|--region)
      REGION="$2"
      shift 2
      ;;
    -a|--account)
      ACCOUNT="$2"
      shift 2
      ;;
    -h|--help)
      echo "Usage: $0 [options]"
      echo "Options:"
      echo "  -e, --environment ENV     Target environment (dev, staging, prod) [default: dev]"
      echo "  -r, --region REGION       AWS region [default: from AWS CLI/env]"
      echo "  -a, --account ACCOUNT     AWS account ID [default: from AWS CLI/env]"
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

echo "🚀 Bootstrapping CDK for $ENVIRONMENT environment"
echo ""

# Get AWS account and region if not provided
if [[ -z "$ACCOUNT" ]]; then
  ACCOUNT=$(aws sts get-caller-identity --query Account --output text 2>/dev/null || echo "")
fi

if [[ -z "$REGION" ]]; then
  REGION=$(aws configure get region 2>/dev/null || echo "eu-central-1")
fi

if [[ -z "$ACCOUNT" ]]; then
  echo "❌ Error: Could not determine AWS account ID"
  echo "   Please ensure AWS CLI is configured or provide --account parameter"
  exit 1
fi

echo "📋 Configuration:"
echo "   Environment: $ENVIRONMENT"
echo "   AWS Account: $ACCOUNT"
echo "   AWS Region: $REGION"
echo ""

# Bootstrap CDK
echo "🔧 Bootstrapping CDK..."
cdk bootstrap \
  --context environment="$ENVIRONMENT" \
  "aws://$ACCOUNT/$REGION"

echo ""
echo "✅ CDK bootstrap completed successfully!"
echo "🎉 You can now deploy the application using: npm run deploy:$ENVIRONMENT"