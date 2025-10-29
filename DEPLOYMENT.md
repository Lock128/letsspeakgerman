# User Admin Messaging - Deployment Guide

This guide covers deployment for both AWS and Kubernetes environments with dual deployment mode support.

## Prerequisites

### Core Requirements (All Deployments)
- **Node.js** 18+ installed
  ```bash
  node --version  # Should be 18.0.0 or higher
  npm --version   # Should be 8.0.0 or higher
  ```
- **Git** installed and configured
- **Docker** installed and running
  ```bash
  docker --version     # Should be 20.0.0 or higher
  docker-compose --version  # Should be 2.0.0 or higher
  ```

### Docker Installation

#### macOS
```bash
# Option 1: Docker Desktop (Recommended - includes Docker Compose)
# Download from: https://docs.docker.com/desktop/mac/install/
# Or install via Homebrew:
brew install --cask docker

# Option 2: Homebrew (Docker CLI only)
brew install docker docker-compose

# Start Docker Desktop from Applications or:
open /Applications/Docker.app
```

#### Windows
```bash
# Option 1: Docker Desktop (Recommended - includes Docker Compose)
# Download from: https://docs.docker.com/desktop/windows/install/

# Option 2: Windows Subsystem for Linux (WSL2)
# Install WSL2 first, then install Docker in WSL2:
wsl --install
# Then follow Linux instructions inside WSL2
```

#### Linux (Ubuntu/Debian)
```bash
# Update package index
sudo apt-get update

# Install prerequisites
sudo apt-get install ca-certificates curl gnupg lsb-release

# Add Docker's official GPG key
sudo mkdir -p /etc/apt/keyrings
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg

# Set up repository
echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null

# Install Docker Engine
sudo apt-get update
sudo apt-get install docker-ce docker-ce-cli containerd.io docker-compose-plugin

# Add user to docker group (to run without sudo)
sudo usermod -aG docker $USER
newgrp docker

# Install Docker Compose (if not included)
sudo curl -L "https://github.com/docker/compose/releases/latest/download/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
sudo chmod +x /usr/local/bin/docker-compose
```

#### Linux (CentOS/RHEL/Fedora)
```bash
# CentOS/RHEL
sudo yum install -y yum-utils
sudo yum-config-manager --add-repo https://download.docker.com/linux/centos/docker-ce.repo
sudo yum install docker-ce docker-ce-cli containerd.io docker-compose-plugin

# Fedora
sudo dnf -y install dnf-plugins-core
sudo dnf config-manager --add-repo https://download.docker.com/linux/fedora/docker-ce.repo
sudo dnf install docker-ce docker-ce-cli containerd.io docker-compose-plugin

# Start and enable Docker
sudo systemctl start docker
sudo systemctl enable docker

# Add user to docker group
sudo usermod -aG docker $USER
newgrp docker

# Install Docker Compose (if needed)
sudo curl -L "https://github.com/docker/compose/releases/latest/download/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
sudo chmod +x /usr/local/bin/docker-compose
```

#### Verify Installation
```bash
# Check Docker
docker --version
docker run --rm hello-world

# Check Docker Compose
docker-compose --version
# OR (newer Docker installations)
docker compose version

# Test Docker daemon
docker ps
# Should show empty list without errors
```

#### Docker Installation Troubleshooting

**Common Issues:**

1. **"Cannot connect to the Docker daemon" error:**
   ```bash
   # Linux: Start Docker service
   sudo systemctl start docker
   sudo systemctl status docker
   
   # macOS/Windows: Start Docker Desktop
   # Check if Docker Desktop is running in system tray/menu bar
   ```

2. **"Permission denied" when running docker commands:**
   ```bash
   # Linux: Add user to docker group
   sudo usermod -aG docker $USER
   # Log out and log back in, or run:
   newgrp docker
   ```

3. **Docker Compose not found:**
   ```bash
   # Check if it's installed as a plugin (newer versions)
   docker compose version
   
   # If not, install manually:
   sudo curl -L "https://github.com/docker/compose/releases/latest/download/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
   sudo chmod +x /usr/local/bin/docker-compose
   ```

4. **WSL2 issues on Windows:**
   ```bash
   # Update WSL2
   wsl --update
   
   # Set WSL2 as default
   wsl --set-default-version 2
   
   # Restart Docker Desktop
   ```

5. **macOS Apple Silicon (M1/M2) issues:**
   ```bash
   # Make sure you downloaded the Apple Silicon version
   # Enable "Use Rosetta for x86/amd64 emulation" in Docker Desktop settings if needed
   ```

## macOS Local Development Setup Guide

### Step 1: Install Prerequisites

#### Install Homebrew (if not already installed)
```bash
# Install Homebrew
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"

# Verify installation
brew --version
```

#### Install Node.js
```bash
# Install Node.js (version 18 or higher)
brew install node@18

# Or install the latest LTS version
brew install node

# Verify installation
node --version  # Should be 18.0.0 or higher
npm --version   # Should be 8.0.0 or higher
```

#### Install Docker Desktop
```bash
# Option 1: Download from Docker website (Recommended)
# Go to: https://docs.docker.com/desktop/mac/install/
# Download Docker Desktop for Mac (choose Intel or Apple Silicon)

# Option 2: Install via Homebrew
brew install --cask docker

# Start Docker Desktop
open /Applications/Docker.app

# Wait for Docker to start (you'll see the whale icon in menu bar)
```

#### Verify Docker Installation
```bash
# Check Docker
docker --version

# Check Docker Compose (newer Docker Desktop versions)
docker compose version
# OR (older versions)
docker-compose --version

# If docker-compose command not found, use 'docker compose' instead
# Modern Docker Desktop includes Compose as a plugin
```

#### Install Git (if not already installed)
```bash
# Install Git
brew install git

# Verify installation
git --version
```

### Step 2: Clone and Setup Project

```bash
# Clone the repository
git clone <your-repository-url>
cd user-admin-messaging

# Install all project dependencies
npm run install-all
```

### Step 3: Start Local Development

#### Option 1: Docker Compose (Recommended)
```bash
# Start all services (use the command that works for your Docker version)
npm run dev:docker

# If you get "docker-compose command not found", the project uses the newer format
# Check which command works:
docker compose version  # Newer Docker Desktop
docker-compose --version  # Older versions

# Start services manually if needed:
docker compose up --build  # Newer Docker Desktop
# OR
docker-compose up --build  # Older versions

# Access the application:
# User Interface: http://localhost/user/
# Admin Interface: http://localhost/admin/
# WebSocket Health: http://localhost:8081/health
```

#### Option 2: Using Make
```bash
# Alternative using Makefile
make dev

# View logs
make dev-logs

# Stop services
make dev-down
```

### Step 4: Verify Everything is Working

```bash
# Check if all containers are running
docker compose ps
# OR
docker-compose ps

# Should show:
# - user-admin-messaging-redis (Up)
# - user-admin-messaging-websocket (Up)
# - user-admin-messaging-user-frontend (Up)
# - user-admin-messaging-admin-frontend (Up)
# - user-admin-messaging-nginx (Up)

# Test health endpoints
curl http://localhost:8081/health      # WebSocket health
curl http://localhost/health           # Nginx health

# Test the application
# 1. Open http://localhost/user/ in browser
# 2. Open http://localhost/admin/ in another tab
# 3. Click the button in user interface
# 4. Verify message appears in admin interface
```

### Step 5: Development Workflow

```bash
# View logs for specific services
docker compose logs -f websocket      # WebSocket server logs
docker compose logs -f user-frontend  # User frontend logs
docker compose logs -f admin-frontend # Admin frontend logs

# Restart a specific service
docker compose restart websocket

# Rebuild and restart all services
docker compose up --build

# Stop all services
docker compose down

# Stop and remove all data (clean slate)
docker compose down -v
```

### Step 6: macOS Troubleshooting

#### Docker Compose Command Issues
```bash
# If you get "docker-compose: command not found":

# 1. Check if Docker Compose is available as a plugin (newer Docker Desktop)
docker compose version

# 2. If the above works, use 'docker compose' instead of 'docker-compose'
# Replace all 'docker-compose' commands with 'docker compose'

# 3. If you need the standalone docker-compose command (RECOMMENDED):
brew install docker-compose

# 4. Verify installation:
docker-compose --version

# 5. Or create an alias in your shell profile (~/.zshrc or ~/.bash_profile):
echo 'alias docker-compose="docker compose"' >> ~/.zshrc
source ~/.zshrc
```

#### Docker Build Issues
```bash
# If you get "COPY failed" or path not found errors:

# 1. Make sure you're in the project root directory:
pwd  # Should end with your project name
ls   # Should show: frontend/, websocket-server/, docker-compose.yml

# 2. Clean Docker cache and rebuild:
docker system prune -f
docker compose build --no-cache

# 3. If still failing, try building individual services:
docker compose build websocket
docker compose build user-frontend
docker compose build admin-frontend

# 4. Check if all required files exist:
ls frontend/user/src/
ls frontend/admin/src/
ls frontend/shared/
```

#### User/Group Creation Issues
```bash
# If you get "group 'nginx' in use" error:
# This happens because the nginx:alpine base image already has an nginx group

# The fix is already applied in the Dockerfiles, but if you see this error:
# 1. Clean Docker cache:
docker system prune -f

# 2. Rebuild without cache:
docker-compose build --no-cache

# 3. If still failing, try removing all images and rebuilding:
docker rmi $(docker images -q user-admin-messaging*)
docker-compose up --build
```

#### NPM Workspace Issues
```bash
# If you get "Unsupported URL Type 'workspace:'" error:
# This happens when Docker build doesn't understand npm workspaces

# 1. Make sure you're building from project root:
pwd  # Should end with your project name
ls   # Should show package.json with workspaces configuration

# 2. Clean npm cache and Docker cache:
npm cache clean --force
docker system prune -f

# 3. Rebuild with no cache:
docker-compose build --no-cache

# 4. If still failing, check workspace setup:
npm ls  # Should show workspace packages
cat package.json | grep -A 10 workspaces
```

#### Docker Desktop Issues
```bash
# If Docker Desktop won't start:
# 1. Quit Docker Desktop completely
# 2. Restart it from Applications folder
# 3. Wait for the whale icon to appear in menu bar

# Check Docker Desktop status
docker system info

# Reset Docker Desktop if needed:
# Docker Desktop > Troubleshoot > Reset to factory defaults
```

#### Port Conflicts
```bash
# Check if ports are in use
lsof -i :80    # Nginx
lsof -i :8080  # WebSocket
lsof -i :6379  # Redis

# If ports are occupied, stop the conflicting services:
sudo lsof -ti:80 | xargs kill -9    # Kill processes on port 80
sudo lsof -ti:8080 | xargs kill -9  # Kill processes on port 8080
```

#### Apple Silicon (M1/M2) Specific
```bash
# If you have build issues on Apple Silicon:
# 1. Make sure you downloaded Docker Desktop for Apple Silicon
# 2. In Docker Desktop settings, enable:
#    "Use Rosetta for x86/amd64 emulation on Apple Silicon"

# Force rebuild for your architecture
docker compose build --no-cache
```

#### Node.js Version Management
```bash
# If you need to manage multiple Node.js versions:
brew install nvm

# Add to your ~/.zshrc:
echo 'export NVM_DIR="$HOME/.nvm"' >> ~/.zshrc
echo '[ -s "/opt/homebrew/share/nvm/nvm.sh" ] && \. "/opt/homebrew/share/nvm/nvm.sh"' >> ~/.zshrc

# Restart terminal and install Node.js 18
nvm install 18
nvm use 18
nvm alias default 18
```

### Step 7: Alternative Manual Setup (Without Docker)

If you prefer not to use Docker:

```bash
# Install Redis locally
brew install redis

# Start Redis
brew services start redis
# OR run in foreground: redis-server

# Install project dependencies
npm run install-all

# Start WebSocket server (Terminal 1)
cd websocket-server
REDIS_URL=redis://localhost:6379 npm run dev

# Build frontends
npm run build:frontend

# Serve user frontend (Terminal 2)
cd frontend/user/dist
python3 -m http.server 8082

# Serve admin frontend (Terminal 3)
cd frontend/admin/dist
python3 -m http.server 8083

# Access:
# User: http://localhost:8082
# Admin: http://localhost:8083
# WebSocket: ws://localhost:8080
```

### AWS Deployment Prerequisites
- **AWS CLI** v2 installed and configured
  ```bash
  aws --version       # Should be aws-cli/2.0.0 or higher
  aws sts get-caller-identity  # Verify credentials
  ```
- **AWS CDK** CLI installed globally
  ```bash
  npm install -g aws-cdk
  cdk --version       # Should be 2.0.0 or higher
  ```
- **AWS Account** with appropriate permissions:
  - CloudFormation (full access)
  - Lambda (full access)
  - API Gateway (full access)
  - DynamoDB (full access)
  - S3 (full access)
  - CloudFront (full access)
  - IAM (role creation)

### Kubernetes Deployment Prerequisites
- **kubectl** installed and configured
  ```bash
  kubectl version --client  # Should be 1.24.0 or higher
  kubectl cluster-info      # Verify cluster connection
  ```
- **Kubernetes Cluster** (one of):
  - Local: Docker Desktop, minikube, kind, k3s
  - Cloud: EKS, GKE, AKS
  - On-premise: kubeadm, etc.
- **Cluster Requirements**:
  - Kubernetes 1.24+
  - Ingress controller (nginx, traefik, etc.)
  - Persistent volume support (for Redis)
  - LoadBalancer support (for services)

### Local Development Prerequisites
- **Redis** (for local development)
  ```bash
  # Option 1: Docker (recommended)
  docker run -d -p 6379:6379 redis:alpine
  
  # Option 2: Local installation
  redis-server --version  # Should be 6.0.0 or higher
  ```

### Optional Tools
- **jq** for JSON processing
  ```bash
  jq --version  # For formatted output display
  ```
- **curl** for health checks and testing
- **make** for using Makefile commands (alternative to npm scripts)

## Prerequisites Verification

Before starting any deployment, run these verification steps:

### 1. Verify Core Tools
```bash
# Check Node.js and npm
node --version    # Should be >= 18.0.0
npm --version     # Should be >= 8.0.0

# Check Docker
docker --version           # Should be >= 20.0.0
docker-compose --version   # Should be >= 2.0.0
docker ps                  # Should connect without errors

# Check Git
git --version     # Any recent version
```

### 2. AWS Prerequisites (if deploying to AWS)
```bash
# Check AWS CLI
aws --version     # Should be aws-cli/2.x.x

# Verify AWS credentials
aws sts get-caller-identity
# Should return your account ID and user/role

# Check CDK
cdk --version     # Should be >= 2.0.0

# Test CDK bootstrap (optional - will be done during deployment)
# cdk bootstrap --show-template
```

### 3. Kubernetes Prerequisites (if deploying to K8s)
```bash
# Check kubectl
kubectl version --client   # Should be >= 1.24.0

# Verify cluster connection
kubectl cluster-info
kubectl get nodes
# Should show your cluster info and nodes

# Check cluster capabilities
kubectl get storageclass   # Should show available storage
kubectl get ingressclass   # Should show ingress controller

# Verify namespace permissions
kubectl auth can-i create namespace
kubectl auth can-i create deployment
kubectl auth can-i create service
# All should return "yes"
```

### 4. Local Development Prerequisites
```bash
# Check available ports for local development
lsof -i :80    # Nginx reverse proxy
lsof -i :8080  # WebSocket server port
lsof -i :8081  # Health check port
lsof -i :8082  # User frontend port  
lsof -i :8083  # Admin frontend port
lsof -i :6379  # Redis port
# Should show "No output" or empty results

# Test Docker functionality with project containers
cd user-admin-messaging

# Build and start the application containers
docker-compose build
docker-compose up -d

# Verify containers are running
docker-compose ps
# Should show all services as "Up"

# Test application endpoints
curl http://localhost/health           # Nginx health
curl http://localhost:8081/health      # WebSocket health
curl http://localhost:8080/health      # WebSocket direct
# Should return health status responses

# Stop containers after testing
docker-compose down
```

### 5. Project Setup
```bash
# Clone and setup project
git clone <repository-url>
cd user-admin-messaging

# Install dependencies
npm run install-all
# Should complete without errors

# Verify project structure
ls -la
# Should show: frontend/, websocket-server/, lambda/, k8s/, infrastructure/
```

## Quick Start

### AWS Deployment (Complete)
```bash
# Prerequisites check
aws sts get-caller-identity
cdk --version

# Install dependencies and deploy everything
npm run install-all
npm run deploy:complete:dev
```

### Kubernetes Deployment (Complete)
```bash
# Prerequisites check
kubectl cluster-info
docker --version

# Build and deploy to Kubernetes
npm run k8s:build-deploy:dev
```

### Local Development
```bash
# Prerequisites check
docker --version
node --version

# Start local development environment
npm run dev:docker
# OR using make
make dev
```

## Deployment Options

### 1. AWS Cloud Deployment

#### Quick AWS Deployment
```bash
npm run deploy:complete:dev     # Development
npm run deploy:complete:staging # Staging  
npm run deploy:complete:prod    # Production
```

#### Step-by-Step AWS Deployment
```bash
# 1. Bootstrap CDK (first time only)
npm run bootstrap:dev

# 2. Deploy infrastructure
npm run deploy:dev

# 3. Configure frontend endpoints
npm run configure:endpoints:dev

# 4. Build and deploy frontend
npm run build:frontend
npm run deploy:frontend:dev

# 5. Validate deployment
./scripts/validate-deployment.sh dev
```

### 2. Kubernetes Deployment

#### Prerequisites Check
```bash
# Verify Kubernetes connection
kubectl cluster-info
kubectl get nodes

# Verify Docker is running
docker ps

# Check if ingress controller is installed
kubectl get pods -n ingress-nginx
# OR for other ingress controllers
kubectl get ingressclass
```

#### Quick Kubernetes Deployment
```bash
# Development environment
npm run k8s:build-deploy:dev

# Staging environment  
npm run k8s:build-deploy:staging

# Production environment
npm run k8s:build-deploy:prod
```

#### Step-by-Step Kubernetes Deployment
```bash
# 1. Build Docker images
npm run k8s:build
# OR
make build-all

# 2. Deploy to specific environment
npm run k8s:deploy:dev        # Development
npm run k8s:deploy:staging    # Staging
npm run k8s:deploy:prod       # Production

# 3. Validate deployment
npm run k8s:validate:dev      # Development
npm run k8s:validate:staging  # Staging
npm run k8s:validate:prod     # Production

# 4. Check status and get URLs
npm run k8s:status:dev
kubectl get ingress -n dev
```

### 3. Local Development

#### Prerequisites Check
```bash
# Check Docker
docker --version
docker-compose --version

# Check Node.js
node --version
npm --version

# Check if ports are available
lsof -i :8080  # WebSocket server
lsof -i :3000  # User frontend
lsof -i :3001  # Admin frontend
lsof -i :6379  # Redis
```

#### Docker Compose (Recommended for Development)
```bash
# Start all services with npm
npm run dev:docker

# OR using make
make dev

# OR manually
docker-compose up --build

# Access the application:
# - User Interface: http://localhost/user/
# - Admin Interface: http://localhost/admin/
# - WebSocket Direct: ws://localhost:8080
# - Health Checks: http://localhost:8081/health

# View logs
docker-compose logs -f websocket      # WebSocket server logs
docker-compose logs -f user-frontend  # User frontend logs
docker-compose logs -f admin-frontend # Admin frontend logs
docker-compose logs -f redis          # Redis logs

# Stop services
docker-compose down

# Stop and remove volumes (clean slate)
docker-compose down -v
```

#### Manual Local Setup (Alternative to Docker Compose)
```bash
# Prerequisites: Install dependencies
npm run install-all

# 1. Start Redis
docker run -d -p 6379:6379 --name user-admin-messaging-redis redis:7-alpine

# 2. Start WebSocket server (Terminal 1)
cd websocket-server
npm install
REDIS_URL=redis://localhost:6379 npm run dev
# Server will start on http://localhost:8080

# 3. Build and serve frontend applications

# Build frontends first
npm run build:frontend

# Serve user frontend (Terminal 2)
cd frontend/user/dist
python3 -m http.server 8082
# OR use any static file server
# User interface: http://localhost:8082

# Serve admin frontend (Terminal 3)  
cd frontend/admin/dist
python3 -m http.server 8083
# Admin interface: http://localhost:8083

# Note: Manual setup requires configuring WebSocket URLs in frontend
# Docker Compose is recommended as it handles all configuration automatically
```

#### Local Kubernetes Development
```bash
# Prerequisites: Local Kubernetes cluster
npm run dev:k8s

# This will:
# 1. Setup local cluster (if needed)
# 2. Build images
# 3. Deploy to dev namespace
```

## Environment Configuration

The application supports multiple deployment modes with automatic detection:

### AWS Environment
- **Infrastructure**: API Gateway WebSocket + Lambda + DynamoDB
- **Frontend**: S3 + CloudFront
- **Detection**: Automatic via URL patterns and configuration

### Kubernetes Environment  
- **Infrastructure**: WebSocket server + Redis
- **Frontend**: Nginx ingress
- **Detection**: Automatic via hostname and path patterns

### Development Environment
- **Infrastructure**: Local WebSocket server + Redis
- **Frontend**: Development servers
- **Detection**: localhost/127.0.0.1 detection

## Available Commands

### AWS Commands
```bash
# Infrastructure
npm run deploy:dev|staging|prod
npm run destroy:dev|staging|prod
npm run bootstrap:dev|staging|prod

# Frontend
npm run build:frontend
npm run deploy:frontend:dev|staging|prod
npm run configure:endpoints:dev|staging|prod

# Testing
npm run test:websocket:dev
./scripts/validate-deployment.sh dev
```

### Kubernetes Commands
```bash
# Build and deployment
npm run k8s:build                    # Build all Docker images
npm run k8s:build-deploy:dev         # Build and deploy to development
npm run k8s:build-deploy:staging     # Build and deploy to staging
npm run k8s:build-deploy:prod        # Build and deploy to production

# Environment-specific deployment
npm run k8s:deploy:dev               # Deploy to development
npm run k8s:deploy:staging           # Deploy to staging
npm run k8s:deploy:prod              # Deploy to production

# Validation and monitoring
npm run k8s:validate:dev             # Validate development deployment
npm run k8s:validate:staging         # Validate staging deployment
npm run k8s:validate:prod            # Validate production deployment

# Status and logs
npm run k8s:status:dev               # Check development status
npm run k8s:logs:dev                 # View development logs
npm run k8s:status:staging           # Check staging status
npm run k8s:logs:staging             # View staging logs

# Cleanup
npm run k8s:undeploy:dev             # Remove development deployment
npm run k8s:undeploy:staging         # Remove staging deployment
npm run k8s:undeploy:prod            # Remove production deployment

# Alternative: Make commands (if preferred)
make build-all              # Build all Docker images
make dev                   # Start local development
make clean                # Clean build artifacts
```

### Docker Commands
```bash
# Development
docker-compose up --build  # Start all services
docker-compose down        # Stop all services

# Individual services
docker-compose up websocket-server
docker-compose up redis
```

## Architecture Overview

### AWS Architecture
- **API Gateway WebSocket API**: Real-time connections
- **Lambda Functions**: Connection and message handling
- **DynamoDB**: WebSocket connection storage
- **S3 + CloudFront**: Static frontend hosting

### Kubernetes Architecture
- **WebSocket Server**: Node.js server in pods
- **Redis**: Connection state storage
- **Ingress**: Load balancing and routing
- **ConfigMaps/Secrets**: Configuration management

### Dual Deployment Features
- **Automatic Environment Detection**: Frontend adapts to deployment environment
- **Dynamic Configuration**: WebSocket URLs configured at runtime
- **Backward Compatibility**: Maintains AWS deployment compatibility
- **Environment-Specific Reconnection**: Optimized retry logic per environment

## Testing and Validation

### Manual Testing Checklist
After deployment, verify:
- [ ] User Interface loads correctly
- [ ] Admin Interface loads correctly
- [ ] WebSocket connections establish
- [ ] Button click sends message
- [ ] Message appears in admin interface in real-time
- [ ] Connection status indicators work
- [ ] Reconnection logic functions properly

### Automated Testing
```bash
# AWS environment
npm run test:websocket:dev

# Kubernetes environment
k8s/scripts/validate-deployment.sh

# Local development
npm run test:local
```

## Troubleshooting

### Common Issues

#### AWS Deployment
1. **AWS CLI not configured**
   ```bash
   aws configure
   aws sts get-caller-identity
   ```

2. **CDK not bootstrapped**
   ```bash
   npm run bootstrap:dev
   ```

3. **CloudFront cache issues**
   ```bash
   aws cloudfront create-invalidation --distribution-id <ID> --paths "/*"
   ```

#### Kubernetes Deployment
1. **kubectl not configured**
   ```bash
   kubectl cluster-info
   kubectl get nodes
   ```

2. **Docker images not built**
   ```bash
   make build-all
   docker images | grep user-admin-messaging
   ```

3. **Services not accessible**
   ```bash
   kubectl get pods,services,ingress
   kubectl logs -l app=websocket-server
   ```

#### Local Development
1. **Port conflicts**
   ```bash
   lsof -i :8080  # Check if port is in use
   docker-compose down  # Stop existing containers
   ```

2. **Redis connection issues**
   ```bash
   docker ps | grep redis
   redis-cli ping  # Test Redis connectivity
   ```

### Logs and Monitoring

#### AWS
- **Lambda Logs**: CloudWatch Logs
- **API Gateway**: Enable logging in console
- **Frontend**: Browser developer tools

#### Kubernetes
```bash
kubectl logs -l app=websocket-server
kubectl logs -l app=redis
kubectl describe pod <pod-name>
```

#### Local Development
```bash
docker-compose logs websocket-server
docker-compose logs redis
```

## Security Considerations

### Production Deployments
- Review changes before production deployment
- Use approval requirements for production
- Monitor logs after deployment
- Test in staging environment first

### Access Control
- AWS: Use IAM roles with minimal permissions
- Kubernetes: Configure RBAC appropriately
- Regularly rotate access credentials

## Cleanup

### AWS
```bash
npm run destroy:dev  # Remove all AWS resources
```

### Kubernetes
```bash
make undeploy-k8s   # Remove from Kubernetes
kubectl delete namespace user-admin-messaging
```

### Local Development
```bash
docker-compose down -v  # Stop and remove volumes
make clean             # Clean build artifacts
```

## CI/CD Integration

### GitHub Actions Example
```yaml
name: Deploy
on:
  push:
    branches: [main, develop]

jobs:
  deploy-aws:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v3
      - name: Deploy to AWS
        run: npm run deploy:complete:${{ github.ref == 'refs/heads/main' && 'prod' || 'staging' }}
        
  deploy-k8s:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v3
      - name: Deploy to Kubernetes
        run: make deploy-k8s
```

## Cost Optimization

### AWS
- Use pay-per-request billing for development
- Destroy dev environments when not in use
- Monitor costs through AWS Cost Explorer

### Kubernetes
- Use resource limits and requests
- Consider cluster autoscaling
- Monitor resource usage with metrics

---

## Quick Reference

### Prerequisites Checklist

| Environment | Prerequisites | Verification Commands |
|-------------|---------------|----------------------|
| **AWS** | AWS CLI, CDK, Node.js | `aws sts get-caller-identity && cdk --version` |
| **Kubernetes** | kubectl, Docker, K8s cluster | `kubectl cluster-info && docker --version` |
| **Local** | Docker, Node.js, Redis | `docker --version && node --version` |

### Command Reference

| Task | AWS Command | Kubernetes Command | Local Command |
|------|-------------|-------------------|---------------|
| **Quick Deploy** | `npm run deploy:complete:dev` | `npm run k8s:build-deploy:dev` | `npm run dev:docker` |
| **Build Only** | `npm run build:frontend` | `npm run k8s:build` | `npm run build` |
| **Deploy Only** | `npm run deploy:dev` | `npm run k8s:deploy:dev` | `docker-compose up -d` |
| **Validate** | `npm run test:websocket:dev` | `npm run k8s:validate:dev` | `curl http://localhost:8081/health` |
| **Status** | CloudWatch Console | `npm run k8s:status:dev` | `docker-compose ps` |
| **Logs** | CloudWatch Logs | `npm run k8s:logs:dev` | `docker-compose logs -f websocket` |
| **Cleanup** | `npm run destroy:dev` | `npm run k8s:undeploy:dev` | `docker-compose down -v` |

### Environment-Specific Commands

| Environment | Build & Deploy | Validate | Cleanup |
|-------------|----------------|----------|---------|
| **Development** | `npm run k8s:build-deploy:dev` | `npm run k8s:validate:dev` | `npm run k8s:undeploy:dev` |
| **Staging** | `npm run k8s:build-deploy:staging` | `npm run k8s:validate:staging` | `npm run k8s:undeploy:staging` |
| **Production** | `npm run k8s:build-deploy:prod` | `npm run k8s:validate:prod` | `npm run k8s:undeploy:prod` |

The system automatically detects the deployment environment and adapts its configuration accordingly, providing seamless operation across AWS, Kubernetes, and local development environments.