#!/bin/bash

set -e

ENVIRONMENT=${1:-dev}
NAMESPACE=${2:-default}

echo "Deploying User-Admin Messaging infrastructure for environment: $ENVIRONMENT"

# Check if kubectl is available
if ! command -v kubectl &> /dev/null; then
    echo "kubectl is required but not installed. Please install kubectl."
    exit 1
fi

# Check if Crossplane is installed
if ! kubectl get crd compositeresourcedefinitions.apiextensions.crossplane.io &> /dev/null; then
    echo "Crossplane is not installed. Please install Crossplane first."
    echo "Run: helm install crossplane crossplane-stable/crossplane --namespace crossplane-system --create-namespace"
    exit 1
fi

# Apply provider configuration
echo "Applying AWS provider configuration..."
kubectl apply -f provider-config.yaml

# Wait for provider to be ready
echo "Waiting for AWS provider to be ready..."
kubectl wait --for=condition=Healthy provider/provider-aws --timeout=300s

# Apply composite resource definition
echo "Applying composite resource definition..."
kubectl apply -f composite-resource-definition.yaml

# Apply composition
echo "Applying composition..."
kubectl apply -f composition.yaml

# Apply environment-specific claim
echo "Applying claim for environment: $ENVIRONMENT"
if [[ -f "claim-${ENVIRONMENT}.yaml" ]]; then
    kubectl apply -f "claim-${ENVIRONMENT}.yaml" -n "$NAMESPACE"
else
    echo "Claim file for environment $ENVIRONMENT not found. Available environments: dev, staging, prod"
    exit 1
fi

echo "Deployment initiated successfully!"
echo "Monitor the deployment with:"
echo "  kubectl get useradminmessaging -n $NAMESPACE"
echo "  kubectl describe useradminmessaging user-admin-messaging-$ENVIRONMENT -n $NAMESPACE"