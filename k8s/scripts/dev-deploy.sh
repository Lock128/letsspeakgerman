#!/bin/bash

# Local Development Deployment Script
# This script deploys the application to a local Kubernetes cluster for development

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Default values
CLUSTER_NAME="user-admin-messaging"
NAMESPACE="dev"
BUILD_IMAGES=true
LOAD_IMAGES=true
WATCH_LOGS=false
PORT_FORWARD=false
CLEANUP_FIRST=false

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

print_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

print_debug() {
    echo -e "${BLUE}[DEBUG]${NC} $1"
}

# Function to show usage
usage() {
    echo "Usage: $0 [OPTIONS]"
    echo ""
    echo "Deploy application to local Kubernetes cluster for development"
    echo ""
    echo "Options:"
    echo "  -c, --cluster NAME          Cluster name (default: user-admin-messaging)"
    echo "  -n, --namespace NAMESPACE   Kubernetes namespace (default: dev)"
    echo "  --no-build                  Skip building Docker images"
    echo "  --no-load                   Skip loading images to cluster"
    echo "  -w, --watch                 Watch logs after deployment"
    echo "  -p, --port-forward          Set up port forwarding after deployment"
    echo "  --cleanup                   Clean up existing deployment first"
    echo "  -h, --help                  Show this help message"
    echo ""
    echo "Examples:"
    echo "  $0                          # Deploy with defaults"
    echo "  $0 --no-build -w           # Deploy without building, watch logs"
    echo "  $0 --cleanup -p             # Clean up, deploy, and port forward"
    echo "  $0 -c my-cluster -n test    # Deploy to custom cluster and namespace"
    exit 1
}

# Parse command line arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        -c|--cluster)
            CLUSTER_NAME="$2"
            shift 2
            ;;
        -n|--namespace)
            NAMESPACE="$2"
            shift 2
            ;;
        --no-build)
            BUILD_IMAGES=false
            shift
            ;;
        --no-load)
            LOAD_IMAGES=false
            shift
            ;;
        -w|--watch)
            WATCH_LOGS=true
            shift
            ;;
        -p|--port-forward)
            PORT_FORWARD=true
            shift
            ;;
        --cleanup)
            CLEANUP_FIRST=true
            shift
            ;;
        -h|--help)
            usage
            ;;
        *)
            print_error "Unknown option: $1"
            usage
            ;;
    esac
done

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
    
    # Check kubectl connection
    if ! kubectl cluster-info &> /dev/null; then
        print_error "Cannot connect to Kubernetes cluster"
        print_status "Make sure your local cluster is running:"
        print_status "  kind: kind get clusters"
        print_status "  minikube: minikube status"
        exit 1
    fi
    
    # Check if we're in the project root
    if [ ! -f "$PROJECT_ROOT/package.json" ] || [ ! -d "$PROJECT_ROOT/websocket-server" ] || [ ! -d "$PROJECT_ROOT/frontend" ]; then
        print_error "Project structure not found. Make sure you're running from the correct directory."
        exit 1
    fi
    
    # Detect cluster type
    local current_context=$(kubectl config current-context)
    if [[ "$current_context" == kind-* ]]; then
        CLUSTER_TYPE="kind"
        print_debug "Detected kind cluster: $current_context"
    elif [[ "$current_context" == *minikube* ]]; then
        CLUSTER_TYPE="minikube"
        print_debug "Detected minikube cluster: $current_context"
    else
        print_warning "Unknown cluster type, assuming generic Kubernetes"
        CLUSTER_TYPE="generic"
    fi
    
    print_success "Prerequisites check passed"
}

# Clean up existing deployment
cleanup_deployment() {
    if [ "$CLEANUP_FIRST" = false ]; then
        return
    fi
    
    print_status "Cleaning up existing deployment..."
    
    local kubectl_opts="--namespace=$NAMESPACE"
    
    # Delete resources in reverse order
    kubectl delete hpa --all $kubectl_opts --ignore-not-found=true
    kubectl delete ingress --all $kubectl_opts --ignore-not-found=true
    kubectl delete deployment --all $kubectl_opts --ignore-not-found=true
    kubectl delete service --all $kubectl_opts --ignore-not-found=true
    kubectl delete configmap app-config $kubectl_opts --ignore-not-found=true
    kubectl delete secret app-secrets $kubectl_opts --ignore-not-found=true
    
    # Wait for pods to terminate
    print_status "Waiting for pods to terminate..."
    kubectl wait --for=delete pods --all $kubectl_opts --timeout=60s || true
    
    print_success "Cleanup completed"
}

# Build Docker images
build_images() {
    if [ "$BUILD_IMAGES" = false ]; then
        print_status "Skipping image build as requested"
        return
    fi
    
    print_status "Building Docker images for local development..."
    
    cd "$PROJECT_ROOT"
    
    # Build with development tag
    ./scripts/docker-build.sh -t dev all
    
    print_success "Docker images built successfully"
}

# Load images to cluster
load_images() {
    if [ "$LOAD_IMAGES" = false ]; then
        print_status "Skipping image loading as requested"
        return
    fi
    
    print_status "Loading images to local cluster..."
    
    local images=(
        "user-admin-messaging/websocket:dev"
        "user-admin-messaging/user-frontend:dev"
        "user-admin-messaging/admin-frontend:dev"
    )
    
    case $CLUSTER_TYPE in
        kind)
            for image in "${images[@]}"; do
                print_debug "Loading $image to kind cluster..."
                kind load docker-image "$image" --name "$CLUSTER_NAME"
            done
            ;;
        minikube)
            # Set Docker environment to minikube
            eval $(minikube docker-env --profile "$CLUSTER_NAME")
            
            # Images should already be available in minikube's Docker daemon
            # If not, we need to rebuild them in minikube's context
            for image in "${images[@]}"; do
                if ! docker images --format "{{.Repository}}:{{.Tag}}" | grep -q "$image"; then
                    print_warning "$image not found in minikube Docker daemon, rebuilding..."
                    cd "$PROJECT_ROOT"
                    ./scripts/docker-build.sh -t dev all
                    break
                fi
            done
            ;;
        generic)
            print_warning "Generic cluster detected, assuming images are available in cluster registry"
            ;;
    esac
    
    print_success "Images loaded to cluster"
}

# Create development configuration
create_dev_config() {
    print_status "Creating development configuration..."
    
    local kubectl_opts="--namespace=$NAMESPACE"
    
    # Create namespace if it doesn't exist
    kubectl create namespace "$NAMESPACE" --dry-run=client -o yaml | kubectl apply -f -
    
    # Create development ConfigMap
    kubectl apply $kubectl_opts -f - << EOF
apiVersion: v1
kind: ConfigMap
metadata:
  name: app-config
  namespace: $NAMESPACE
data:
  DEPLOYMENT_MODE: "kubernetes"
  ENVIRONMENT: "development"
  LOG_LEVEL: "debug"
  DEBUG: "true"
  REDIS_URL: "redis://redis-service:6379"
  WEBSOCKET_PORT: "8080"
  HEALTH_PORT: "8081"
  CORS_ORIGIN: "*"
  RATE_LIMIT_ENABLED: "false"
EOF
    
    # Create development Secret
    kubectl apply $kubectl_opts -f - << EOF
apiVersion: v1
kind: Secret
metadata:
  name: app-secrets
  namespace: $NAMESPACE
type: Opaque
data:
  REDIS_PASSWORD: $(echo -n "dev-redis-password" | base64)
  JWT_SECRET: $(echo -n "dev-jwt-secret" | base64)
  SESSION_SECRET: $(echo -n "dev-session-secret" | base64)
EOF
    
    print_success "Development configuration created"
}

# Deploy application
deploy_application() {
    print_status "Deploying application to development environment..."
    
    local kubectl_opts="--namespace=$NAMESPACE"
    local temp_dir=$(mktemp -d)
    
    # Copy manifests to temp directory
    cp -r "$K8S_DIR"/* "$temp_dir/"
    
    # Update image tags to use dev tag
    find "$temp_dir/deployments" -name "*.yaml" -type f | while read -r file; do
        sed -i.bak "s|image: user-admin-messaging/\([^:]*\):.*|image: user-admin-messaging/\1:dev|g" "$file"
        sed -i.bak "s|namespace: .*|namespace: $NAMESPACE|g" "$file"
        # Reduce replicas for development
        sed -i.bak 's/replicas: [0-9]*/replicas: 1/g' "$file"
        # Reduce resource requests for development
        sed -i.bak 's/cpu: [0-9]*m/cpu: 100m/g' "$file"
        sed -i.bak 's/memory: [0-9]*Mi/memory: 128Mi/g' "$file"
        rm -f "${file}.bak"
    done
    
    # Update other manifests
    find "$temp_dir" -name "*.yaml" -type f -not -path "*/deployments/*" | while read -r file; do
        if grep -q "namespace:" "$file"; then
            sed -i.bak "s|namespace: .*|namespace: $NAMESPACE|g" "$file"
        else
            # Add namespace to metadata if not present
            sed -i.bak '/^metadata:/a\
  namespace: '"$NAMESPACE" "$file"
        fi
        rm -f "${file}.bak"
    done
    
    # Deploy services first
    print_status "Deploying services..."
    kubectl apply $kubectl_opts -f "$temp_dir/services/"
    
    # Deploy deployments
    print_status "Deploying applications..."
    kubectl apply $kubectl_opts -f "$temp_dir/deployments/"
    
    # Deploy ingress for local access
    print_status "Deploying ingress..."
    
    # Create development ingress with local domain
    kubectl apply $kubectl_opts -f - << EOF
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: user-admin-messaging-ingress
  namespace: $NAMESPACE
  annotations:
    nginx.ingress.kubernetes.io/websocket-services: "websocket-service"
    nginx.ingress.kubernetes.io/proxy-read-timeout: "3600"
    nginx.ingress.kubernetes.io/proxy-send-timeout: "3600"
spec:
  rules:
  - host: messaging.local
    http:
      paths:
      - path: /user
        pathType: Prefix
        backend:
          service:
            name: user-frontend-service
            port:
              number: 80
      - path: /admin
        pathType: Prefix
        backend:
          service:
            name: admin-frontend-service
            port:
              number: 80
      - path: /ws
        pathType: Prefix
        backend:
          service:
            name: websocket-service
            port:
              number: 8080
      - path: /health
        pathType: Prefix
        backend:
          service:
            name: websocket-service
            port:
              number: 8081
EOF
    
    # Clean up temp directory
    rm -rf "$temp_dir"
    
    # Wait for deployments to be ready
    print_status "Waiting for deployments to be ready..."
    
    local deployments=("websocket-service" "user-frontend-service" "admin-frontend-service")
    
    for deployment in "${deployments[@]}"; do
        if kubectl get deployment "$deployment" $kubectl_opts &> /dev/null; then
            kubectl wait --for=condition=available --timeout=180s "deployment/$deployment" $kubectl_opts
        fi
    done
    
    print_success "Application deployed successfully"
}

# Show deployment status
show_status() {
    local kubectl_opts="--namespace=$NAMESPACE"
    
    echo ""
    print_status "Deployment Status:"
    kubectl get pods,services,ingress $kubectl_opts
    
    echo ""
    print_status "Application URLs:"
    echo "  Add to /etc/hosts: 127.0.0.1 messaging.local"
    echo "  User Interface: http://messaging.local/user"
    echo "  Admin Interface: http://messaging.local/admin"
    echo "  WebSocket Endpoint: ws://messaging.local/ws"
    echo "  Health Check: http://messaging.local/health"
    
    echo ""
    print_status "Port Forward Commands (alternative to ingress):"
    echo "  WebSocket: kubectl port-forward service/websocket-service 8080:8080 $kubectl_opts"
    echo "  User Frontend: kubectl port-forward service/user-frontend-service 3000:80 $kubectl_opts"
    echo "  Admin Frontend: kubectl port-forward service/admin-frontend-service 3001:80 $kubectl_opts"
    echo "  Redis: kubectl port-forward service/redis-service 6379:6379 $kubectl_opts"
    
    echo ""
    print_status "Useful Commands:"
    echo "  Watch logs: kubectl logs -f deployment/websocket-service $kubectl_opts"
    echo "  Shell into pod: kubectl exec -it deployment/websocket-service $kubectl_opts -- /bin/sh"
    echo "  Scale deployment: kubectl scale deployment websocket-service --replicas=2 $kubectl_opts"
    echo "  Delete deployment: kubectl delete all --all $kubectl_opts"
}

# Setup port forwarding
setup_port_forward() {
    if [ "$PORT_FORWARD" = false ]; then
        return
    fi
    
    print_status "Setting up port forwarding..."
    
    local kubectl_opts="--namespace=$NAMESPACE"
    
    # Kill existing port forwards
    pkill -f "kubectl.*port-forward" || true
    
    # Start port forwards in background
    kubectl port-forward service/websocket-service 8080:8080 $kubectl_opts &
    kubectl port-forward service/user-frontend-service 3000:80 $kubectl_opts &
    kubectl port-forward service/admin-frontend-service 3001:80 $kubectl_opts &
    
    sleep 2
    
    print_success "Port forwarding setup completed"
    echo "  WebSocket: http://localhost:8080"
    echo "  User Frontend: http://localhost:3000"
    echo "  Admin Frontend: http://localhost:3001"
    echo ""
    echo "  To stop port forwarding: pkill -f 'kubectl.*port-forward'"
}

# Watch logs
watch_logs() {
    if [ "$WATCH_LOGS" = false ]; then
        return
    fi
    
    print_status "Watching application logs..."
    print_status "Press Ctrl+C to stop watching logs"
    
    local kubectl_opts="--namespace=$NAMESPACE"
    
    # Watch logs from all deployments
    kubectl logs -f deployment/websocket-service $kubectl_opts &
    kubectl logs -f deployment/user-frontend-service $kubectl_opts &
    kubectl logs -f deployment/admin-frontend-service $kubectl_opts &
    
    # Wait for user to stop
    wait
}

# Main execution
main() {
    print_status "Starting local development deployment..."
    print_status "Configuration:"
    print_status "  Cluster: $CLUSTER_NAME"
    print_status "  Namespace: $NAMESPACE"
    print_status "  Build Images: $BUILD_IMAGES"
    print_status "  Load Images: $LOAD_IMAGES"
    print_status "  Watch Logs: $WATCH_LOGS"
    print_status "  Port Forward: $PORT_FORWARD"
    print_status "  Cleanup First: $CLEANUP_FIRST"
    
    check_prerequisites
    cleanup_deployment
    build_images
    load_images
    create_dev_config
    deploy_application
    show_status
    setup_port_forward
    watch_logs
    
    print_success "Local development deployment completed!"
}

# Run main function
main "$@"