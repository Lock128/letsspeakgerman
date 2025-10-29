#!/bin/bash

set -e

echo "Installing prerequisites for Kro and ACK infrastructure..."

# Check if kubectl is available
command -v kubectl >/dev/null 2>&1 || { echo "kubectl is required but not installed. Aborting." >&2; exit 1; }
command -v helm >/dev/null 2>&1 || { echo "helm is required but not installed. Aborting." >&2; exit 1; }

ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
echo "AWS Account ID: $ACCOUNT_ID"

# Install Kro
echo "Installing Kro..."
kubectl apply -f https://github.com/kubernetes-sigs/kro/releases/latest/download/kro.yaml

echo "Waiting for Kro to be ready..."
kubectl wait --for=condition=Available deployment/kro-controller-manager -n kro-system --timeout=300s

# Create ACK system namespace
echo "Creating ACK system namespace..."
kubectl create namespace ack-system --dry-run=client -o yaml | kubectl apply -f -

# Install ACK Controllers
echo "Installing ACK Controllers..."

# DynamoDB Controller
echo "Installing DynamoDB Controller..."
helm install ack-dynamodb-controller oci://public.ecr.aws/aws-controllers-k8s/dynamodb-chart \
  --version=v1.2.10 \
  --namespace ack-system \
  --create-namespace \
  --wait || echo "DynamoDB controller installation failed or already exists"

# Lambda Controller
echo "Installing Lambda Controller..."
helm install ack-lambda-controller oci://public.ecr.aws/aws-controllers-k8s/lambda-chart \
  --version=v1.4.2 \
  --namespace ack-system \
  --wait || echo "Lambda controller installation failed or already exists"

# API Gateway V2 Controller
echo "Installing API Gateway V2 Controller..."
helm install ack-apigatewayv2-controller oci://public.ecr.aws/aws-controllers-k8s/apigatewayv2-chart \
  --version=v1.0.14 \
  --namespace ack-system \
  --wait || echo "API Gateway V2 controller installation failed or already exists"

# S3 Controller
echo "Installing S3 Controller..."
helm install ack-s3-controller oci://public.ecr.aws/aws-controllers-k8s/s3-chart \
  --version=v1.0.13 \
  --namespace ack-system \
  --wait || echo "S3 controller installation failed or already exists"

# CloudFront Controller
echo "Installing CloudFront Controller..."
helm install ack-cloudfront-controller oci://public.ecr.aws/aws-controllers-k8s/cloudfront-chart \
  --version=v1.2.11 \
  --namespace ack-system \
  --wait || echo "CloudFront controller installation failed or already exists"

# IAM Controller
echo "Installing IAM Controller..."
helm install ack-iam-controller oci://public.ecr.aws/aws-controllers-k8s/iam-chart \
  --version=v1.3.8 \
  --namespace ack-system \
  --wait || echo "IAM controller installation failed or already exists"

# Apply service account and RBAC
echo "Setting up service accounts and RBAC..."
sed "s/ACCOUNT_ID/$ACCOUNT_ID/g" ack-controllers-setup.yaml | kubectl apply -f -

echo "Prerequisites installation completed!"
echo ""
echo "Installed components:"
echo "- Kro (Kube Resource Orchestrator)"
echo "- ACK Controllers (DynamoDB, Lambda, API Gateway V2, S3, CloudFront, IAM)"
echo ""
echo "You can now deploy the infrastructure using:"
echo "  ./deploy.sh dev"