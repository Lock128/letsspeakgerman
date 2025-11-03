# Crossplane V2 Infrastructure for User-Admin Messaging

This directory contains the Crossplane V2 infrastructure definitions (scope: Cluster) converted from the original AWS CDK stack.

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

```bash
task setup
```

## Deployment

1. Setup XRD, Composition and XR
```bash
task deploy
```

### Verification

```bash
crossplane beta trace XUserAdminMessaging user-admin-messaging-crossplane-dev -o wide
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