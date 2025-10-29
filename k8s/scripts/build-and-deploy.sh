#!/bin/bash

# Kubernetes Build and Deploy Script for User-Admin-Messaging Application
# This script builds Docker images and deploys all components to Kubernetes

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Default values
NAMESPACE="default"
ENVIRONMENT="production"
DRY_RUN=false
BUILD_IMAGES=true
PUSH_IMAGES=false
REGISTRY="user-admin-messaging"
TAG="latest"
SKIP_VALIDATION=false
TIMEOUT=300

# Get script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
K8S_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"

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

print_debug() {
    echo -e "${BLUE}[DEBUG]${NC} $1"
}

# Function to show usage
usage() {
    echo "Usage: $0 [OPTIONS]"
    echo ""
    echo "Build Docker images and deploy to Kubernetes cluster"
    echo ""
    echo "Options:"
    echo "  -n, --namespace NAMESPACE    Kubernetes namespace (default: default)"
    echo "  -e, --environment ENV        Environment (development|staging|production, default: production)"
    echo "  -r, --registry REGISTRY      Docker registry prefix (default: user-admin-messaging)"
    echo "  -t, --tag TAG               Docker image tag (default: latest)"
    echo "  -d, --dry-run               Perform a dry run without applying changes"
    echo "  --no-build                  Skip building Docker images"
    echo "  --push                      Push images to registry after building"
    echo "  --skip-validation           Skip deployment validation"
    echo "  --timeout SECONDS           Deployment timeout in seconds (default: 300)"
    echo "  -h, --help                  Show this help message"
    echo ""
    echo "Examples:"
    echo "  $0                                           # Build and deploy to default namespace"
    echo "  $0 -n dev-env -e development                # Deploy to dev-env namespace with development config"
    echo "  $0 -t v1.0.0 --push                        # Build with tag v1.0.0 and push to registry"
    echo "  $0 --no-build -n staging                    # Deploy without building (use existing images)"
    echo "  $0 -d --skip-validation                     # Dry run without validation"
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
        -r|--registry)
            REGISTRY="$2"
            shift 2
            ;;
        -t|--tag)
            TAG="$2"
            shift 2
            ;;
        -d|--dry-run)
            DRY_RUN=true
            shift
            ;;
        --no-build)
            BUILD_IMAGES=false
            shift
            ;;
        --push)
            PUSH_IMAGES=true
            shift
            ;;
        --skip-validation)
            SKIP_VALIDATION=true
            shift
            ;;
        --timeout)
            TIMEOUT="$2"
            shift 2
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

# Validate timeout
if ! [[ "$TIMEOUT" =~ ^[0-9]+$ ]]; then
    print_error "Invalid timeout: $TIMEOUT. Must be a positive integer."
    exit 1
fi

# Check prerequisites
check_prerequisites() {
    print_status "Checking prerequisites..."
    
    # Check if kubectl is available
    if ! command -v kubectl &> /dev/null; then
        print_error "kubectl is not installed or not in PATH"
        exit 1
    fi
    
    # Check if Docker is available (only if building)
    if [ "$BUILD_IMAGES" = true ] && ! command -v docker &> /dev/null; then
        print_error "Docker is not installed or not in PATH"
        exit 1
    fi
    
    # Check if we're in the project root
    if [ ! -f "$PROJECT_ROOT/package.json" ] || [ ! -d "$PROJECT_ROOT/websocket-server" ] || [ ! -d "$PROJECT_ROOT/frontend" ]; then
        print_error "Project structure not found. Make sure you're running from the correct directory."
        exit 1
    fi
    
    # Check kubectl connection
    if ! kubectl cluster-info &> /dev/null; then
        print_error "Cannot connect to Kubernetes cluster. Check your kubectl configuration."
        exit 1
    fi
    
    print_status "Prerequisites check passed"
}

# Build Docker images
build_images() {
    if [ "$BUILD_IMAGES" = false ]; then
        print_status "Skipping image build as requested"
        return 0
    fi
    
    print_status "Building Docker images..."
    
    cd "$PROJECT_ROOT"
    
    # Build arguments
    BUILD_ARGS=("-t" "$TAG" "-r" "$REGISTRY")
    if [ "$PUSH_IMAGES" = true ]; then
        BUILD_ARGS+=("--push")
    fi
    
    # Run build script
    if ! ./scripts/docker-build.sh "${BUILD_ARGS[@]}" all; then
        print_error "Failed to build Docker images"
        exit 1
    fi
    
    print_status "Docker images built successfully"
}

# Update image tags in Kubernetes manifests
update_image_tags() {
    print_status "Updating image tags in Kubernetes manifests..."
    
    local temp_dir=$(mktemp -d)
    
    # Copy manifests to temp directory
    cp -r "$K8S_DIR"/* "$temp_dir/"
    
    # Update image tags in deployment manifests
    find "$temp_dir/deployments" -name "*.yaml" -type f | while read -r file; do
        sed -i.bak "s|image: ${REGISTRY}/\([^:]*\):.*|image: ${REGISTRY}/\1:${TAG}|g" "$file"
        rm -f "${file}.bak"
    done
    
    echo "$temp_dir"
}

# Deploy to Kubernetes
deploy_to_kubernetes() {
    print_status "Starting deployment to namespace: $NAMESPACE, environment: $ENVIRONMENT"
    
    # Update image tags
    local manifest_dir=$(update_image_tags)
    
    # Set kubectl options
    local kubectl_opts="--namespace=$NAMESPACE"
    if [ "$DRY_RUN" = true ]; then
        kubectl_opts="$kubectl_opts --dry-run=client"
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
    if [ -f "$manifest_dir/config/environments/${ENVIRONMENT}.yaml" ]; then
        kubectl apply $kubectl_opts -f "$manifest_dir/config/environments/${ENVIRONMENT}.yaml"
        print_status "Applied environment-specific configuration for $ENVIRONMENT"
    else
        # Fallback to default configuration
        kubectl apply $kubectl_opts -f "$manifest_dir/config/app-config.yaml"
        kubectl apply $kubectl_opts -f "$manifest_dir/config/app-secrets.yaml"
        print_warning "Environment-specific config not found, using default configuration"
    fi
    
    print_status "Deploying Services..."
    kubectl apply $kubectl_opts -f "$manifest_dir/services/"
    
    print_status "Deploying Deployments..."
    kubectl apply $kubectl_opts -f "$manifest_dir/deployments/"
    
    print_status "Deploying Ingress..."
    kubectl apply $kubectl_opts -f "$manifest_dir/ingress/"
    
    print_status "Deploying HorizontalPodAutoscalers..."
    kubectl apply $kubectl_opts -f "$manifest_dir/autoscaling/"
    
    # Clean up temp directory
    rm -rf "$manifest_dir"
    
    if [ "$DRY_RUN" = false ] && [ "$SKIP_VALIDATION" = false ]; then
        validate_deployment
    elif [ "$DRY_RUN" = true ]; then
        print_status "Dry run completed successfully!"
    else
        print_status "Deployment completed (validation skipped)"
    fi
}

# Validate deployment
validate_deployment() {
    print_status "Validating deployment..."
    
    local kubectl_opts="--namespace=$NAMESPACE"
    
    print_status "Waiting for deployments to be ready (timeout: ${TIMEOUT}s)..."
    
    # Wait for deployments to be ready
    local deployments=("websocket-service" "user-frontend-service" "admin-frontend-service")
    
    for deployment in "${deployments[@]}"; do
        print_status "Waiting for deployment/$deployment to be ready..."
        if ! kubectl wait --for=condition=available --timeout="${TIMEOUT}s" "deployment/$deployment" $kubectl_opts; then
            print_error "Deployment $deployment failed to become ready within ${TIMEOUT} seconds"
            show_troubleshooting_info
            exit 1
        fi
    done
    
    # Check Redis deployment if it exists
    if kubectl get deployment redis-service $kubectl_opts &> /dev/null; then
        print_status "Waiting for deployment/redis-service to be ready..."
        if ! kubectl wait --for=condition=available --timeout="${TIMEOUT}s" deployment/redis-service $kubectl_opts; then
            print_warning "Redis deployment failed to become ready, but continuing..."
        fi
    fi
    
    print_status "All deployments are ready!"
    
    # Show deployment status
    show_deployment_status
    
    # Run health checks
    run_health_checks
}

# Show deployment status
show_deployment_status() {
    local kubectl_opts="--namespace=$NAMESPACE"
    
    echo ""
    print_status "Deployment Status:"
    kubectl get pods,services,ingress,hpa $kubectl_opts
    
    echo ""
    print_status "Resource Usage:"
    kubectl top pods $kubectl_opts 2>/dev/null || print_warning "Metrics server not available for resource usage"
    
    echo ""
    print_status "Useful Commands:"
    echo "  Check logs:"
    echo "    kubectl logs -f deployment/websocket-service $kubectl_opts"
    echo "    kubectl logs -f deployment/user-frontend-service $kubectl_opts"
    echo "    kubectl logs -f deployment/admin-frontend-service $kubectl_opts"
    echo ""
    echo "  Port forward for local access:"
    echo "    kubectl port-forward service/websocket-service 8080:8080 $kubectl_opts"
    echo "    kubectl port-forward service/user-frontend-service 3000:80 $kubectl_opts"
    echo "    kubectl port-forward service/admin-frontend-service 3001:80 $kubectl_opts"
    echo ""
    echo "  Scale deployments:"
    echo "    kubectl scale deployment websocket-service --replicas=3 $kubectl_opts"
}

# Run health checks
run_health_checks() {
    print_status "Running health checks..."
    
    local kubectl_opts="--namespace=$NAMESPACE"
    
    # Check if WebSocket service is responding
    print_status "Checking WebSocket service health..."
    
    # Get WebSocket service pod
    local ws_pod=$(kubectl get pods -l app=websocket-service $kubectl_opts -o jsonpath='{.items[0].metadata.name}' 2>/dev/null)
    
    if [ -n "$ws_pod" ]; then
        # Check health endpoint
        if kubectl exec "$ws_pod" $kubectl_opts -- curl -f http://localhost:8081/health &> /dev/null; then
            print_status "WebSocket service health check passed"
        else
            print_warning "WebSocket service health check failed"
        fi
        
        # Check readiness endpoint
        if kubectl exec "$ws_pod" $kubectl_opts -- curl -f http://localhost:8081/ready &> /dev/null; then
            print_status "WebSocket service readiness check passed"
        else
            print_warning "WebSocket service readiness check failed"
        fi
    else
        print_warning "No WebSocket service pods found for health check"
    fi
    
    print_status "Health checks completed"
}

# Show troubleshooting information
show_troubleshooting_info() {
    local kubectl_opts="--namespace=$NAMESPACE"
    
    echo ""
    print_error "Deployment failed. Troubleshooting information:"
    echo ""
    
    print_status "Pod Status:"
    kubectl get pods $kubectl_opts
    
    echo ""
    print_status "Recent Events:"
    kubectl get events --sort-by='.lastTimestamp' $kubectl_opts | tail -10
    
    echo ""
    print_status "Failed Pod Logs (if any):"
    kubectl get pods $kubectl_opts -o jsonpath='{.items[*].metadata.name}' | tr ' ' '\n' | while read -r pod; do
        if [ -n "$pod" ]; then
            local status=$(kubectl get pod "$pod" $kubectl_opts -o jsonpath='{.status.phase}')
            if [ "$status" != "Running" ]; then
                echo "--- Logs for $pod (status: $status) ---"
                kubectl logs "$pod" $kubectl_opts --tail=20 || echo "No logs available"
                echo ""
            fi
        fi
    done
}

# Main execution
main() {
    print_status "Starting Kubernetes build and deploy process..."
    print_status "Configuration:"
    print_status "  Namespace: $NAMESPACE"
    print_status "  Environment: $ENVIRONMENT"
    print_status "  Registry: $REGISTRY"
    print_status "  Tag: $TAG"
    print_status "  Build Images: $BUILD_IMAGES"
    print_status "  Push Images: $PUSH_IMAGES"
    print_status "  Dry Run: $DRY_RUN"
    print_status "  Skip Validation: $SKIP_VALIDATION"
    print_status "  Timeout: ${TIMEOUT}s"
    
    check_prerequisites
    build_images
    deploy_to_kubernetes
    
    print_status "Build and deploy process completed successfully!"
}

# Run main function
main "$@"