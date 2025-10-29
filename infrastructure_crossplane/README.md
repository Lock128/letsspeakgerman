# Crossplane V2 Infrastructure for User-Admin Messaging

This directory contains the Crossplane V2 infrastructure definitions converted from the original AWS CDK stack.

## Architecture

The infrastructure includes:

- **DynamoDB Table**: WebSocket connections storage with TTL and GSI
- **Lambda Functions**: Connection manager and message handler
- **API Gateway**: WebSocket API for real-time messaging
- **S3 Buckets**: Static website hosting for user and admin interfaces
- **CloudFront**: CDN distribution with multiple origins
- **IAM**: Roles and policies for Lambda execution

## Files

- `composite-resource-definition.yaml`: Defines the XUserAdminMessaging API
- `composition.yaml`: Main composition defining all AWS resources
- `provider-config.yaml`: AWS provider configuration
- `claim-dev.yaml`: Development environment claim
- `claim-staging.yaml`: Staging environment claim
- `claim-prod.yaml`: Production environment claim

## Prerequisites

1. Install Crossplane in your Kubernetes cluster:
```bash
helm repo add crossplane-stable https://charts.crossplane.io/stable
helm repo update
helm install crossplane crossplane-stable/crossplane --namespace crossplane-system --create-namespace
```

2. Install the AWS provider:
```bash
kubectl apply -f provider-config.yaml
```

3. Create AWS credentials secret:
```bash
kubectl create secret generic aws-secret -n crossplane-system --from-file=creds=./aws-credentials.txt
```

Where `aws-credentials.txt` contains:
```
[default]
aws_access_key_id = YOUR_ACCESS_KEY
aws_secret_access_key = YOUR_SECRET_KEY
```

## Deployment

1. Apply the composite resource definition:
```bash
kubectl apply -f composite-resource-definition.yaml
```

2. Apply the composition:
```bash
kubectl apply -f composition.yaml
```

3. Deploy an environment (e.g., dev):
```bash
kubectl apply -f claim-dev.yaml
```

## Monitoring

Check the status of your deployment:
```bash
kubectl get useradminmessaging
kubectl describe useradminmessaging user-admin-messaging-dev
```

## Key Differences from CDK

- **Declarative**: Infrastructure is defined declaratively vs imperative CDK code
- **Kubernetes Native**: Managed through Kubernetes APIs
- **Composition**: Reusable compositions for multiple environments
- **GitOps Ready**: YAML files can be managed in Git for GitOps workflows
- **Multi-Cloud**: Can be extended to support multiple cloud providers

## Environment Configuration

Each environment (dev/staging/prod) has different configurations:
- **Dev**: Resources can be deleted, optimized for development
- **Staging/Prod**: Resources retained, optimized for stability