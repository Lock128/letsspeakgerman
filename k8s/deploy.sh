#!/bin/bash

# Kubernetes Deployment Script for User-Admin-Messaging Application
# This script deploys all Kubernetes manifests in the correct order

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Default values
NAMESPACE="default"
ENVIRONMENT="production"
DRY_RUN=false

# Function to print colored output
print_status() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Function to show usage
usage() {
    echo "Usage: $0 [OPTIONS]"
    echo "Options:"
    echo "  -n, --namespace NAMESPACE    Kubernetes namespace (default: default)"
    echo "  -e, --environment ENV        Environment (development|staging|production, default: production)"
    echo "  -d, --dry-run               Perform a dry run without applying changes"
    echo "  -h, --help                  Show this help message"
    exit 1
}

# Parse command line arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        -n|--namespace)
            NAMESPACE="$2"
            shift 2
            ;;
        -e|--environment)
            ENVIRONMENT="$2"
            shift 2
            ;;
        -d|--dry-run)
            DRY_RUN=true
            shift
            ;;
        -h|--help)
            usage
            ;;
        *)
            echo "Unknown option: $1"
            usage
            ;;
    esac
done

# Validate environment
if [[ ! "$ENVIRONMENT" =~ ^(development|staging|production)$ ]]; then
    print_error "Invalid environment: $ENVIRONMENT. Must be development, staging, or production."
    exit 1
fi

print_status "Starting deployment to namespace: $NAMESPACE, environment: $ENVIRONMENT"

# Set kubectl options
KUBECTL_OPTS="--namespace=$NAMESPACE"
if [ "$DRY_RUN" = true ]; then
    KUBECTL_OPTS="$KUBECTL_OPTS --dry-run=client"
    print_warning "Running in dry-run mode - no changes will be applied"
fi

# Create namespace if it doesn't exist
if [ "$DRY_RUN" = false ]; then
    kubectl create namespace "$NAMESPACE" --dry-run=client -o yaml | kubectl apply -f -
    print_status "Namespace $NAMESPACE created or already exists"
fi

# Deploy in correct order
print_status "Deploying ConfigMaps and Secrets..."

# Deploy environment-specific configuration
if [ -f "config/environments/${ENVIRONMENT}.yaml" ]; then
    kubectl apply $KUBECTL_OPTS -f "config/environments/${ENVIRONMENT}.yaml"
    print_status "Applied environment-specific configuration for $ENVIRONMENT"
else
    # Fallback to default configuration
    kubectl apply $KUBECTL_OPTS -f config/app-config.yaml
    kubectl apply $KUBECTL_OPTS -f config/app-secrets.yaml
    print_warning "Environment-specific config not found, using default configuration"
fi

print_status "Deploying Services..."
kubectl apply $KUBECTL_OPTS -f services/

print_status "Deploying Deployments..."
kubectl apply $KUBECTL_OPTS -f deployments/

print_status "Deploying Ingress..."
kubectl apply $KUBECTL_OPTS -f ingress/

print_status "Deploying HorizontalPodAutoscalers..."
kubectl apply $KUBECTL_OPTS -f autoscaling/

if [ "$DRY_RUN" = false ]; then
    print_status "Waiting for deployments to be ready..."
    
    # Wait for deployments to be ready
    kubectl wait --for=condition=available --timeout=300s deployment/websocket-service $KUBECTL_OPTS
    kubectl wait --for=condition=available --timeout=300s deployment/user-frontend-service $KUBECTL_OPTS
    kubectl wait --for=condition=available --timeout=300s deployment/admin-frontend-service $KUBECTL_OPTS
    kubectl wait --for=condition=available --timeout=300s deployment/redis-service $KUBECTL_OPTS
    
    print_status "All deployments are ready!"
    
    # Show deployment status
    echo ""
    print_status "Deployment Status:"
    kubectl get pods,services,ingress,hpa $KUBECTL_OPTS
    
    echo ""
    print_status "To check logs, use:"
    echo "  kubectl logs -f deployment/websocket-service $KUBECTL_OPTS"
    echo "  kubectl logs -f deployment/user-frontend-service $KUBECTL_OPTS"
    echo "  kubectl logs -f deployment/admin-frontend-service $KUBECTL_OPTS"
    
    echo ""
    print_status "To access the application:"
    echo "  User Interface: https://clc.lockhead.cloud/user"
    echo "  Admin Interface: https://clc.lockhead.cloud/admin"
    echo "  WebSocket Endpoint: wss://clc.lockhead.cloud/ws"
    echo "  Health Check: https://clc.lockhead.cloud/health"
else
    print_status "Dry run completed successfully!"
fi

print_status "Deployment script completed!"