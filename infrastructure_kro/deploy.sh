#!/bin/bash

set -e

ENVIRONMENT=${1:-dev}
ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)

echo "Deploying User Admin Messaging Stack for environment: $ENVIRONMENT"
echo "AWS Account ID: $ACCOUNT_ID"

# Validate environment
if [[ ! "$ENVIRONMENT" =~ ^(dev|staging|prod)$ ]]; then
    echo "Error: Environment must be one of: dev, staging, prod"
    exit 1
fi

# Check if required tools are installed
command -v kubectl >/dev/null 2>&1 || { echo "kubectl is required but not installed. Aborting." >&2; exit 1; }
command -v aws >/dev/null 2>&1 || { echo "AWS CLI is required but not installed. Aborting." >&2; exit 1; }

# Check if Kro is installed
if ! kubectl get crd resourcegroups.kro.run >/dev/null 2>&1; then
    echo "Installing Kro..."
    kubectl apply -f https://github.com/kubernetes-sigs/kro/releases/latest/download/kro.yaml
    echo "Waiting for Kro to be ready..."
    kubectl wait --for=condition=Available deployment/kro-controller-manager -n kro-system --timeout=300s
fi

# Check if ACK controllers are installed (basic check)
echo "Checking ACK controllers..."
if ! kubectl get crd tables.dynamodb.services.k8s.aws >/dev/null 2>&1; then
    echo "Warning: DynamoDB ACK controller not found. Please install it first."
fi

# Deploy IAM roles first
echo "Deploying IAM roles..."
kubectl apply -f iam-roles.yaml

# Deploy the ResourceGroup definition
echo "Deploying ResourceGroup definition..."
kubectl apply -f resource-group.yaml

# Wait for ResourceGroup to be ready
echo "Waiting for ResourceGroup to be ready..."
kubectl wait --for=condition=Ready resourcegroup/user-admin-messaging-stack --timeout=60s

# Update instance file with actual account ID
INSTANCE_FILE="instances/${ENVIRONMENT}-instance.yaml"
if [[ ! -f "$INSTANCE_FILE" ]]; then
    echo "Error: Instance file $INSTANCE_FILE not found"
    exit 1
fi

# Create a temporary file with substituted values
TEMP_INSTANCE_FILE=$(mktemp)
sed "s/ACCOUNT_ID/$ACCOUNT_ID/g" "$INSTANCE_FILE" > "$TEMP_INSTANCE_FILE"

# Deploy the instance
echo "Deploying $ENVIRONMENT instance..."
kubectl apply -f "$TEMP_INSTANCE_FILE"

# Clean up temporary file
rm "$TEMP_INSTANCE_FILE"

echo "Waiting for resources to be created..."
sleep 10

# Check status
echo "Checking deployment status..."
kubectl get resourcegroupinstance "user-admin-messaging-$ENVIRONMENT" -o yaml

echo "Deployment completed for environment: $ENVIRONMENT"
echo ""
echo "To check the status of your resources:"
echo "  kubectl get resourcegroupinstance user-admin-messaging-$ENVIRONMENT"
echo ""
echo "To get resource details:"
echo "  kubectl describe resourcegroupinstance user-admin-messaging-$ENVIRONMENT"