# Kro and ACK Infrastructure

This directory contains the Kubernetes-native infrastructure definitions using:
- **Kro (Kube Resource Orchestrator)** for resource composition and orchestration
- **ACK (AWS Controllers for Kubernetes)** for AWS service management

## Architecture

The infrastructure includes:
- DynamoDB table for WebSocket connections (ACK)
- Lambda functions for connection and message handling (ACK)
- API Gateway WebSocket API (ACK)
- S3 buckets for frontend hosting (ACK)
- CloudFront distribution (ACK)
- Kro ResourceGroup for orchestrating the complete stack

## Prerequisites

1. Install ACK controllers:
   ```bash
   # DynamoDB Controller
   kubectl apply -f https://raw.githubusercontent.com/aws-controllers-k8s/dynamodb-controller/main/config/crd/bases/dynamodb.services.k8s.aws_tables.yaml
   
   # Lambda Controller
   kubectl apply -f https://raw.githubusercontent.com/aws-controllers-k8s/lambda-controller/main/config/crd/bases/lambda.services.k8s.aws_functions.yaml
   
   # API Gateway V2 Controller
   kubectl apply -f https://raw.githubusercontent.com/aws-controllers-k8s/apigatewayv2-controller/main/config/crd/bases/apigatewayv2.services.k8s.aws_apis.yaml
   
   # S3 Controller
   kubectl apply -f https://raw.githubusercontent.com/aws-controllers-k8s/s3-controller/main/config/crd/bases/s3.services.k8s.aws_buckets.yaml
   
   # CloudFront Controller
   kubectl apply -f https://raw.githubusercontent.com/aws-controllers-k8s/cloudfront-controller/main/config/crd/bases/cloudfront.services.k8s.aws_distributions.yaml
   ```

2. Install Kro:
   ```bash
   kubectl apply -f https://github.com/kubernetes-sigs/kro/releases/latest/download/kro.yaml
   ```

## Deployment

```bash
# Deploy the ResourceGroup definition
kubectl apply -f resource-group.yaml

# Create an instance for development environment
kubectl apply -f instances/dev-instance.yaml
```

## Environment Management

Create instances for different environments:
- `instances/dev-instance.yaml` - Development
- `instances/staging-instance.yaml` - Staging  
- `instances/prod-instance.yaml` - Production