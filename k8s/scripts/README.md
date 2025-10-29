# Kubernetes Deployment and Management Scripts

This directory contains comprehensive scripts for deploying, managing, and maintaining the user-admin-messaging application on Kubernetes clusters.

## Script Overview

### Deployment Scripts

#### `build-and-deploy.sh`
Complete build and deployment script that handles Docker image building and Kubernetes deployment.

**Usage:**
```bash
./build-and-deploy.sh [OPTIONS]
```

**Key Features:**
- Builds Docker images with proper tagging
- Updates Kubernetes manifests with correct image tags
- Deploys to specified namespace and environment
- Validates deployment health
- Supports dry-run mode

**Examples:**
```bash
# Build and deploy to default namespace
./build-and-deploy.sh

# Deploy to staging with custom tag
./build-and-deploy.sh -n staging -e staging -t v1.2.0

# Dry run without building images
./build-and-deploy.sh --no-build -d
```

#### `deploy-environment.sh`
Environment-specific deployment script with proper configuration management.

**Usage:**
```bash
./deploy-environment.sh [OPTIONS] ENVIRONMENT
```

**Environments:** development, staging, production

**Key Features:**
- Environment-specific resource allocation
- Automatic namespace management
- Configuration generation per environment
- Production safety checks

**Examples:**
```bash
# Deploy to development
./deploy-environment.sh development

# Deploy to production with confirmation
./deploy-environment.sh production -f

# Update only configuration
./deploy-environment.sh staging -c
```

#### `validate-deployment.sh`
Comprehensive deployment validation and health checking.

**Usage:**
```bash
./validate-deployment.sh [OPTIONS]
```

**Key Features:**
- Validates all Kubernetes resources
- Tests service connectivity
- Checks health endpoints
- Performance validation
- Detailed reporting

**Examples:**
```bash
# Validate deployment in dev namespace
./validate-deployment.sh -n dev

# Full validation with performance tests
./validate-deployment.sh --performance -v
```

### Local Development Scripts

#### `setup-local-cluster.sh`
Sets up local Kubernetes clusters using kind or minikube.

**Usage:**
```bash
./setup-local-cluster.sh [OPTIONS]
```

**Key Features:**
- Supports kind and minikube
- Configurable cluster size
- Automatic ingress controller setup
- Metrics server installation
- Development namespace creation

**Examples:**
```bash
# Create kind cluster with defaults
./setup-local-cluster.sh

# Create minikube cluster
./setup-local-cluster.sh -t minikube

# Single node cluster without ingress
./setup-local-cluster.sh --nodes 1 --no-ingress
```

#### `dev-deploy.sh`
Deploys application to local Kubernetes cluster for development.

**Usage:**
```bash
./dev-deploy.sh [OPTIONS]
```

**Key Features:**
- Builds and loads images to local cluster
- Creates development configuration
- Sets up port forwarding
- Watches logs
- Minimal resource allocation

**Examples:**
```bash
# Deploy with defaults
./dev-deploy.sh

# Deploy without building, watch logs
./dev-deploy.sh --no-build -w

# Clean deploy with port forwarding
./dev-deploy.sh --cleanup -p
```

#### `dev-test.sh`
Testing and debugging utilities for local development.

**Usage:**
```bash
./dev-test.sh [OPTIONS] [TEST_TYPE]
```

**Test Types:** all, connectivity, health, websocket, frontend, redis, logs, debug

**Key Features:**
- Comprehensive connectivity testing
- Health endpoint validation
- WebSocket functionality testing
- Interactive debugging mode
- Log analysis

**Examples:**
```bash
# Run all tests
./dev-test.sh

# Test WebSocket functionality
./dev-test.sh websocket -v

# Interactive debugging session
./dev-test.sh debug -i
```

### Maintenance Scripts

#### `maintenance.sh`
Handles configuration updates and rolling deployments.

**Usage:**
```bash
./maintenance.sh [OPTIONS] OPERATION
```

**Operations:** update-config, rolling-update, scale, restart, update-image, status, health-check

**Key Features:**
- Configuration management
- Rolling updates
- Deployment scaling
- Image updates
- Health monitoring

**Examples:**
```bash
# Update configuration
./maintenance.sh -n prod update-config

# Scale WebSocket service
./maintenance.sh -n staging scale -d websocket-service -r 3

# Rolling update all deployments
./maintenance.sh -n prod rolling-update
```

#### `cleanup.sh`
Removes Kubernetes deployments and resources.

**Usage:**
```bash
./cleanup.sh [OPTIONS] [CLEANUP_TYPE]
```

**Cleanup Types:** deployment, namespace, config, images, all

**Key Features:**
- Selective resource cleanup
- Safety confirmations
- Dry-run support
- Image cleanup for local clusters

**Examples:**
```bash
# Clean up deployment in dev namespace
./cleanup.sh -n dev

# Force remove staging namespace
./cleanup.sh -n staging namespace -f

# Clean up Docker images
./cleanup.sh images
```

#### `backup-restore.sh`
Backup and restore operations for Redis data.

**Usage:**
```bash
./backup-restore.sh [OPTIONS] OPERATION
```

**Operations:** backup, restore, list, cleanup, status

**Key Features:**
- Automated Redis backups
- Compressed backup files
- Metadata tracking
- Restore verification
- Backup rotation

**Examples:**
```bash
# Create backup
./backup-restore.sh backup

# Restore from backup
./backup-restore.sh restore -f backup_20231201.rdb.gz

# List available backups
./backup-restore.sh list
```

## Quick Start Guide

### 1. Set Up Local Development Environment

```bash
# Create local Kubernetes cluster
./setup-local-cluster.sh

# Deploy application for development
./dev-deploy.sh

# Test the deployment
./dev-test.sh
```

### 2. Deploy to Staging Environment

```bash
# Build and deploy to staging
./build-and-deploy.sh -n staging -e staging

# Validate deployment
./validate-deployment.sh -n staging

# Check status
./maintenance.sh -n staging status
```

### 3. Deploy to Production

```bash
# Deploy to production (with confirmation)
./deploy-environment.sh production

# Validate deployment
./validate-deployment.sh -n production --performance

# Create backup
./backup-restore.sh backup -n production
```

## Script Dependencies

All scripts require:
- `kubectl` - Kubernetes command-line tool
- `docker` - Docker for image building (where applicable)
- Standard Unix tools: `curl`, `nc`, `gzip`, etc.

For local development:
- `kind` or `minikube` for local clusters
- `node` and `npm` for WebSocket testing

## Configuration

Scripts use the following configuration sources:
1. Command-line arguments (highest priority)
2. Environment variables
3. Default values (lowest priority)

### Environment Variables

- `DOCKER_REGISTRY` - Docker registry prefix
- `DOCKER_TAG` - Default image tag
- `KUBECTL_CONTEXT` - Kubernetes context to use

## Troubleshooting

### Common Issues

1. **kubectl not connected**
   ```bash
   kubectl cluster-info
   kubectl config get-contexts
   ```

2. **Images not found in cluster**
   ```bash
   # For kind clusters
   kind load docker-image user-admin-messaging/websocket:latest

   # For minikube clusters
   eval $(minikube docker-env)
   ```

3. **Pods not starting**
   ```bash
   kubectl describe pods -n <namespace>
   kubectl logs <pod-name> -n <namespace>
   ```

4. **Service connectivity issues**
   ```bash
   ./dev-test.sh connectivity -v
   kubectl get endpoints -n <namespace>
   ```

### Debug Mode

Most scripts support verbose output with `-v` or `--verbose` flags:
```bash
./script-name.sh -v
```

For interactive debugging:
```bash
./dev-test.sh debug -i
```

## Security Considerations

- Production deployments require explicit confirmation
- Secrets are base64 encoded in Kubernetes
- Non-root containers are used for security
- Resource limits prevent resource exhaustion
- Network policies can be applied for additional security

## Best Practices

1. **Always validate deployments** after changes
2. **Create backups** before major updates
3. **Use dry-run mode** to preview changes
4. **Monitor resource usage** in production
5. **Keep scripts executable**: `chmod +x k8s/scripts/*.sh`
6. **Test in development** before deploying to production

## Support

For issues or questions:
1. Check script help: `./script-name.sh --help`
2. Review logs with verbose output
3. Use the debug and testing utilities
4. Validate prerequisites and dependencies