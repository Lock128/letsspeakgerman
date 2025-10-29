# Let's Speak German - User Admin Messaging System

A real-time messaging application demonstrating modern cloud-native deployment patterns across AWS and Kubernetes environments. This project showcases dual deployment architecture with automatic environment detection and adaptive configuration.

## 🎤 Conference Presentation

This project was featured as a demo at the **CLC Conference 2025** in the talk:

**"Why do we need observability for CI/CD pipelines?"**

📅 **Event Details:**
- **Conference:** CLC Conference 2025
- **Talk Page:** [https://clc-conference.eu/veranstaltung-83927-31-why-do-we-need-observability-for-ci-cd-pipelines.html](https://clc-conference.eu/veranstaltung-83927-31-why-do-we-need-observability-for-ci-cd-pipelines.html)
- **Focus:** Demonstrating observability patterns in modern CI/CD pipelines using this multi-environment deployment example

## 🚀 Project Overview

This application demonstrates a complete real-time messaging system with:

- **User Interface**: Simple button-click messaging interface
- **Admin Interface**: Real-time message monitoring dashboard
- **WebSocket Communication**: Instant bidirectional messaging
- **Multi-Environment Support**: AWS, Kubernetes, and local development
- **Infrastructure as Code**: CDK, Kubernetes manifests, and KRO resource definitions

## 🏗️ Architecture

### Deployment Options

1. **AWS Cloud Native**
   - API Gateway WebSocket API
   - Lambda functions for message handling
   - DynamoDB for connection storage
   - S3 + CloudFront for frontend hosting

2. **Kubernetes**
   - WebSocket server pods
   - Redis for state management
   - Ingress controllers for routing
   - ConfigMaps for configuration

3. **Crossplane V2**
   - Custom resource definitions
   - Crossplane V2
   - Declarative AWS resource management

4. **KRO (Kubernetes Resource Operator)**
   - Custom resource definitions
   - AWS Controller for Kubernetes (ACK)
   - Declarative AWS resource management

5. **Local Development**
   - Docker Compose orchestration
   - Local Redis instance
   - Development servers

## 🛠️ Technology Stack

- **Frontend**: TypeScript, HTML5, CSS3
- **Backend**: Node.js, WebSocket, Redis
- **Infrastructure**: AWS CDK, Kubernetes, Docker
- **Cloud Services**: AWS Lambda, API Gateway, DynamoDB, S3, CloudFront
- **Container Orchestration**: Kubernetes, Docker Compose
- **CI/CD**: GitHub Actions, automated deployments

## 📁 Project Structure

```
letsspeakgerman/
├── frontend/                    # Frontend applications
│   ├── user/                   # User interface
│   ├── admin/                  # Admin dashboard
│   └── shared/                 # Shared components
├── websocket-server/           # WebSocket server implementation
├── lambda/                     # AWS Lambda functions
├── infrastructure/             # AWS CDK infrastructure
├── infrastructure_crossplane/  # Crossplane configurations
├── infrastructure_kro/         # KRO resource definitions
├── k8s/                       # Kubernetes manifests
├── docker/                    # Docker configurations
└── scripts/                   # Deployment and utility scripts
```

## 🚀 Quick Start

### Prerequisites
- Node.js 18+
- Docker and Docker Compose
- AWS CLI (for AWS deployment)
- kubectl (for Kubernetes deployment)

### Local Development
```bash
# Clone and setup
git clone <repository-url>
cd letsspeakgerman
npm run install-all

# Start with Docker Compose
npm run dev:docker

# Access the application
# User Interface: http://localhost/user/
# Admin Interface: http://localhost/admin/
```

### AWS Deployment
```bash
# Deploy complete stack to development
npm run deploy:complete:dev

# Deploy to staging/production
npm run deploy:complete:staging
npm run deploy:complete:prod
```

### Kubernetes Deployment
```bash
# Build and deploy to development
npm run k8s:build-deploy:dev

# Deploy to other environments
npm run k8s:build-deploy:staging
npm run k8s:build-deploy:prod
```

### KRO Deployment
```bash
# Deploy using Kubernetes Resource Operator
cd infrastructure_kro
./deploy.sh dev

# Deploy to other environments
./deploy.sh staging
./deploy.sh prod
```

## 🔧 Key Features

### Dual Deployment Architecture
- **Environment Auto-Detection**: Automatically adapts to AWS or Kubernetes environments
- **Dynamic Configuration**: WebSocket URLs and endpoints configured at runtime
- **Unified Codebase**: Single codebase supports multiple deployment targets

### Real-Time Communication
- **WebSocket Connections**: Persistent bidirectional communication
- **Connection Management**: Automatic reconnection with exponential backoff
- **State Synchronization**: Real-time message delivery between interfaces

### Infrastructure as Code
- **AWS CDK**: TypeScript-based infrastructure definitions
- **Kubernetes Manifests**: Declarative resource configurations
- **KRO Integration**: Custom resource operators for AWS services

### Development Experience
- **Hot Reload**: Development servers with automatic refresh
- **Docker Compose**: Complete local environment in containers
- **Multi-Environment**: Consistent experience across dev/staging/prod

## 📊 Observability & Monitoring

As demonstrated in the CLC Conference 2025 presentation, this project includes:

- **Health Checks**: Endpoint monitoring for all services
- **Logging**: Structured logging across all components
- **Metrics**: Performance and usage metrics collection
- **Tracing**: Request tracing through the system
- **Alerting**: Automated alerts for system issues

## 🧪 Testing

```bash
# Run all tests
npm test

# Test WebSocket functionality
npm run test:websocket:dev

# Validate deployments
./scripts/validate-deployment.sh dev
npm run k8s:validate:dev
```

## 📚 Documentation

- [Deployment Guide](DEPLOYMENT.md) - Comprehensive deployment instructions
- [Project Structure](PROJECT_STRUCTURE.md) - Detailed project organization
- [Infrastructure Documentation](infrastructure/README.md) - AWS CDK details
- [Kubernetes Documentation](k8s/README.md) - K8s deployment guide
- [KRO Documentation](infrastructure_kro/README.md) - KRO resource definitions

## 🤝 Contributing

This project serves as a demonstration of modern cloud-native patterns. Contributions are welcome for:

- Additional deployment targets
- Enhanced observability features
- Performance optimizations
- Documentation improvements

## 📄 License

This project is provided as-is for educational and demonstration purposes.

---

**Presented at CLC Conference 2025** - Demonstrating observability in CI/CD pipelines through practical multi-environment deployment patterns.
