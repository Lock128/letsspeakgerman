#!/bin/bash

set -e

ENVIRONMENT=${1:-dev}

echo "Cleaning up User Admin Messaging Stack for environment: $ENVIRONMENT"

# Validate environment
if [[ ! "$ENVIRONMENT" =~ ^(dev|staging|prod)$ ]]; then
    echo "Error: Environment must be one of: dev, staging, prod"
    exit 1
fi

# Delete the instance
echo "Deleting $ENVIRONMENT instance..."
kubectl delete resourcegroupinstance "user-admin-messaging-$ENVIRONMENT" --ignore-not-found=true

# Wait for resources to be cleaned up
echo "Waiting for resources to be cleaned up..."
sleep 30

echo "Cleanup completed for environment: $ENVIRONMENT"
echo ""
echo "Note: The ResourceGroup definition and IAM roles are preserved."
echo "To completely remove everything, run:"
echo "  kubectl delete -f resource-group.yaml"
echo "  kubectl delete -f iam-roles.yaml"