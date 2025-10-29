# Kubernetes Deployment Manifests

This directory contains all the Kubernetes manifests needed to deploy the user-admin-messaging application on a Kubernetes cluster.

## Directory Structure

```
k8s/
├── deployments/           # Deployment manifests for all services
│   ├── websocket-deployment.yaml
│   ├── user-frontend-deployment.yaml
│   └── admin-frontend-deployment.yaml
├── services/              # Service manifests for internal communication
│   ├── websocket-service.yaml
│   ├── user-frontend-service.yaml
│   ├── admin-frontend-service.yaml
│   └── redis-service.yaml
├── ingress/               # Ingress configuration for external access
│   ├── user-admin-messaging-ingress.yaml
│   └── tls-certificate.yaml
├── config/                # ConfigMaps and Secrets
│   ├── app-config.yaml
│   ├── app-secrets.yaml
│   └── environments/      # Environment-specific configurations
│       ├── development.yaml
│       ├── staging.yaml
│       └── production.yaml
├── autoscaling/           # HorizontalPodAutoscaler configurations
│   ├── websocket-hpa.yaml
│   └── frontend-hpa.yaml
├── deploy.sh              # Deployment script
└── README.md              # This file
```

## Prerequisites

1. **Kubernetes Cluster**: A running Kubernetes cluster (v1.19+)
2. **kubectl**: Configured to connect to your cluster
3. **Ingress Controller**: NGINX Ingress Controller installed
4. **Metrics Server**: For HPA functionality
5. **Docker Images**: Built and pushed to a registry accessible by your cluster

## Quick Start

### 1. Build and Push Docker Images

First, ensure all Docker images are built and available in your container registry:

```bash
# Build all images (from project root)
./scripts/docker-build.sh

# Tag and push to your registry
docker tag user-admin-messaging/websocket:latest your-registry/websocket:latest
docker tag user-admin-messaging/user-frontend:latest your-registry/user-frontend:latest
docker tag user-admin-messaging/admin-frontend:latest your-registry/admin-frontend:latest

docker push your-registry/websocket:latest
docker push your-registry/user-frontend:latest
docker push your-registry/admin-frontend:latest
```

### 2. Update Image References

Update the image references in the deployment manifests to point to your registry:

```bash
# Update websocket deployment
sed -i 's|user-admin-messaging/websocket:latest|your-registry/websocket:latest|' deployments/websocket-deployment.yaml

# Update frontend deployments
sed -i 's|user-admin-messaging/user-frontend:latest|your-registry/user-frontend:latest|' deployments/user-frontend-deployment.yaml
sed -i 's|user-admin-messaging/admin-frontend:latest|your-registry/admin-frontend:latest|' deployments/admin-frontend-deployment.yaml
```

### 3. Configure Environment

Update the configuration files for your environment:

```bash
# For production, update the domain name
sed -i 's|clc.lockhead.cloud|your-domain.com|g' ingress/user-admin-messaging-ingress.yaml
sed -i 's|clc.lockhead.cloud|your-domain.com|g' config/app-config.yaml

# Update secrets with actual values
# Edit config/app-secrets.yaml and replace base64 encoded values
```

### 4. Deploy to Kubernetes

Use the deployment script for easy deployment:

```bash
# Deploy to default namespace with production configuration
./deploy.sh

# Deploy to specific namespace and environment
./deploy.sh --namespace my-app --environment staging

# Dry run to validate manifests
./deploy.sh --dry-run
```

Or deploy manually:

```bash
# Create namespace
kubectl create namespace user-admin-messaging

# Deploy in order
kubectl apply -f config/ -n user-admin-messaging
kubectl apply -f services/ -n user-admin-messaging
kubectl apply -f deployments/ -n user-admin-messaging
kubectl apply -f ingress/ -n user-admin-messaging
kubectl apply -f autoscaling/ -n user-admin-messaging
```

## Configuration

### Environment Variables

The application supports the following environment variables:

| Variable | Description | Default |
|----------|-------------|---------|
| `DEPLOYMENT_MODE` | Deployment mode (kubernetes/aws) | kubernetes |
| `REDIS_URL` | Redis connection URL | redis://redis-service:6379 |
| `PORT` | WebSocket server port | 8080 |
| `HEALTH_PORT` | Health check port | 8081 |

### ConfigMaps

- **app-config**: Non-sensitive application configuration
- **app-config-{env}**: Environment-specific configuration

### Secrets

- **app-secrets**: Sensitive configuration (Redis password, JWT secret)
- **app-secrets-{env}**: Environment-specific secrets
- **messaging-tls-secret**: TLS certificate for HTTPS

## Monitoring and Health Checks

### Health Endpoints

- **Liveness Probe**: `GET /health` on port 8081
- **Readiness Probe**: `GET /ready` on port 8081

### Monitoring

The WebSocket service exposes metrics for monitoring:

- Connection count
- Message throughput
- Error rates

### Autoscaling

HorizontalPodAutoscaler is configured for:

- **WebSocket Service**: 2-10 replicas based on CPU (70%) and memory (80%)
- **Frontend Services**: 2-5 replicas based on CPU (80%) and memory (85%)

## Troubleshooting

### Common Issues

1. **Pods not starting**: Check image pull secrets and registry access
2. **Ingress not working**: Verify NGINX Ingress Controller is installed
3. **WebSocket connections failing**: Check ingress annotations for WebSocket support
4. **Redis connection errors**: Verify Redis service is running and accessible

### Debugging Commands

```bash
# Check pod status
kubectl get pods -n user-admin-messaging

# Check logs
kubectl logs -f deployment/websocket-service -n user-admin-messaging

# Check service endpoints
kubectl get endpoints -n user-admin-messaging

# Check ingress status
kubectl describe ingress user-admin-messaging-ingress -n user-admin-messaging

# Check HPA status
kubectl get hpa -n user-admin-messaging
```

### Port Forwarding for Local Testing

```bash
# Forward WebSocket service
kubectl port-forward service/websocket-service 8080:8080 -n user-admin-messaging

# Forward user frontend
kubectl port-forward service/user-frontend-service 3000:80 -n user-admin-messaging

# Forward admin frontend
kubectl port-forward service/admin-frontend-service 3001:80 -n user-admin-messaging
```

## Security Considerations

1. **TLS**: Configure proper TLS certificates for production
2. **Secrets**: Use proper secret management (e.g., Sealed Secrets, External Secrets)
3. **Network Policies**: Implement network policies to restrict pod communication
4. **RBAC**: Configure appropriate RBAC permissions
5. **Pod Security**: Enable Pod Security Standards

## Scaling

### Manual Scaling

```bash
# Scale WebSocket service
kubectl scale deployment websocket-service --replicas=5 -n user-admin-messaging

# Scale frontend services
kubectl scale deployment user-frontend-service --replicas=3 -n user-admin-messaging
```

### Automatic Scaling

HPA is configured to automatically scale based on:
- CPU utilization
- Memory utilization
- Custom metrics (if configured)

## Cleanup

To remove the entire deployment:

```bash
# Delete all resources
kubectl delete namespace user-admin-messaging

# Or delete individual components
kubectl delete -f autoscaling/ -n user-admin-messaging
kubectl delete -f ingress/ -n user-admin-messaging
kubectl delete -f deployments/ -n user-admin-messaging
kubectl delete -f services/ -n user-admin-messaging
kubectl delete -f config/ -n user-admin-messaging
```

## Environment-Specific Deployments

### Development

```bash
./deploy.sh --environment development --namespace dev
```

### Staging

```bash
./deploy.sh --environment staging --namespace staging
```

### Production

```bash
./deploy.sh --environment production --namespace production
```

## Support

For issues and questions:
1. Check the troubleshooting section above
2. Review Kubernetes logs and events
3. Verify configuration and secrets
4. Check network connectivity and DNS resolution