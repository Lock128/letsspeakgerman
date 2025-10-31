# Taskfile Setup for Local Kubernetes Development

This repository uses [Taskfile](https://taskfile.dev/) to manage local Kubernetes environments with Kind, Crossplane v2, and KRO/ACK controllers.

## Prerequisites

Install the required tools:

```bash
# Install Task
brew install go-task/tap/go-task  # macOS
# or
sh -c "$(curl --location https://taskfile.dev/install.sh)" -- -d  # Linux/macOS

# Install Kind
brew install kind  # macOS
# or
go install sigs.k8s.io/kind@latest  # Go

# Install kubectl
brew install kubectl  # macOS

# Install Helm
brew install helm  # macOS

# Install AWS CLI
brew install awscli  # macOS
```

Verify installation:
```bash
task check:prereqs
```

## Quick Start

### 1. Crossplane Environment

Set up a local Kind cluster with Crossplane v2:

```bash
# Create cluster and install Crossplane
task crossplane:setup

# Set up AWS credentials (required)
export AWS_ACCESS_KEY_ID="your-access-key"
export AWS_SECRET_ACCESS_KEY="your-secret-key"
task -d infrastructure_crossplane setup:credentials

# Deploy infrastructure for development
task crossplane:deploy ENVIRONMENT=dev

# Check status
task -d infrastructure_crossplane status ENVIRONMENT=dev
```

### 2. KRO/ACK Environment

Set up a local Kind cluster with KRO and ACK controllers:

```bash
# Create cluster and install KRO + ACK
task kro:setup

# Set up AWS credentials and service accounts
task -d infrastructure_kro setup:credentials

# Deploy infrastructure for development
task kro:deploy ENVIRONMENT=dev

# Check status
task -d infrastructure_kro status ENVIRONMENT=dev
```

## Available Tasks

### Root Level Tasks

```bash
# Show all available tasks
task

# Cluster management
task kind:create          # Create Kind cluster
task kind:delete          # Delete Kind cluster
task kind:status          # Check cluster status

# Environment setup
task crossplane:setup     # Setup Crossplane environment
task kro:setup           # Setup KRO/ACK environment

# Deployment
task crossplane:deploy ENVIRONMENT=dev    # Deploy with Crossplane
task kro:deploy ENVIRONMENT=dev          # Deploy with KRO/ACK

# Development helpers
task dev:status          # Show status of all components
task dev:logs           # Show logs from infrastructure components

# Cleanup
task cleanup:all        # Clean up everything
```

### Crossplane Tasks

```bash
cd infrastructure_crossplane

# Setup and installation
task setup                    # Install Crossplane and AWS provider
task setup:credentials        # Set up AWS credentials

# Deployment
task deploy ENVIRONMENT=dev   # Deploy infrastructure
task status ENVIRONMENT=dev   # Check deployment status

# Maintenance
task logs                     # Show Crossplane logs
task cleanup ENVIRONMENT=dev  # Clean up specific environment
task cleanup:all             # Clean up everything
```

### KRO/ACK Tasks

```bash
cd infrastructure_kro

# Setup and installation
task setup                    # Install KRO and ACK controllers
task setup:credentials        # Set up AWS credentials and service accounts

# Deployment
task deploy ENVIRONMENT=dev   # Deploy infrastructure
task status ENVIRONMENT=dev   # Check deployment status

# Maintenance
task logs                     # Show KRO and ACK logs
task cleanup ENVIRONMENT=dev  # Clean up specific environment
task cleanup:all             # Clean up everything
```

## Environment Variables

### Required for AWS Operations

```bash
export AWS_ACCESS_KEY_ID="your-access-key-id"
export AWS_SECRET_ACCESS_KEY="your-secret-access-key"
export AWS_DEFAULT_REGION="us-east-1"  # Optional, defaults to us-east-1
```

### Optional Configuration

```bash
export KIND_CLUSTER_NAME="custom-cluster-name"  # Default: user-admin-messaging
export KUBERNETES_VERSION="v1.34.0"             # Default: v1.34.0
```

## Supported Environments

- `dev` - Development environment (default)
- `staging` - Staging environment
- `prod` - Production environment

## Troubleshooting

### Check Prerequisites
```bash
task check:prereqs
```

### Check Cluster Status
```bash
task kind:status
task dev:status
```

### View Logs
```bash
task dev:logs
task -d infrastructure_crossplane logs
task -d infrastructure_kro logs
```

### Clean Start
```bash
task cleanup:all
task kind:create
# Then setup your preferred environment
```

### Common Issues

1. **Cluster not found**: Run `task kind:create` first
2. **Port conflicts**: If you get "port already allocated" errors:
   - Check what's using the ports: `task check:ports`
   - The cluster uses ports 9080 and 9443 for ingress
   - Use `task kind:recreate` to delete and recreate the cluster
3. **AWS credentials**: Ensure AWS credentials are set and valid
4. **Helm repositories**: If Helm charts fail, try `helm repo update`
5. **Resource conflicts**: Use `task cleanup:all` for a clean start

## Architecture Overview

### Crossplane Setup
- **Kind cluster** with Crossplane v2 installed
- **AWS Provider** for managing AWS resources
- **Composite Resource Definitions** for infrastructure templates
- **Claims** for environment-specific deployments

### KRO/ACK Setup
- **Kind cluster** with KRO (Kube Resource Orchestrator)
- **ACK Controllers** for AWS services (DynamoDB, Lambda, S3, etc.)
- **ResourceGroups** for orchestrating complex deployments
- **Instances** for environment-specific configurations

## File Structure

```
├── Taskfile.yml                           # Root task definitions
├── kind-config.yaml                       # Kind cluster configuration
├── infrastructure_crossplane/
│   ├── Taskfile.yml                      # Crossplane-specific tasks
│   ├── composite-resource-definition.yaml
│   ├── composition.yaml
│   ├── provider-config.yaml
│   └── claims/
│       ├── claim-dev.yaml
│       ├── claim-staging.yaml
│       └── claim-prod.yaml
└── infrastructure_kro/
    ├── Taskfile.yml                      # KRO/ACK-specific tasks
    ├── resource-group.yaml
    ├── iam-roles.yaml
    ├── ack-controllers-setup.yaml
    └── instances/
        ├── dev-instance.yaml
        ├── staging-instance.yaml
        └── prod-instance.yaml
```

## Next Steps

1. Choose your preferred infrastructure approach (Crossplane or KRO/ACK)
2. Set up the environment using the appropriate tasks
3. Deploy your infrastructure for development
4. Use the status and logs tasks to monitor your deployment
5. Iterate on your infrastructure definitions as needed

For more information about the underlying technologies:
- [Taskfile Documentation](https://taskfile.dev/)
- [Kind Documentation](https://kind.sigs.k8s.io/)
- [Crossplane Documentation](https://crossplane.io/docs/)
- [KRO Documentation](https://github.com/kubernetes-sigs/kro)
- [ACK Documentation](https://aws-controllers-k8s.github.io/community/)