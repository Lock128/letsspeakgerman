#!/bin/bash

# Local Kubernetes Cluster Setup Script
# This script sets up a local Kubernetes cluster using kind or minikube

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Default values
CLUSTER_TYPE="kind"
CLUSTER_NAME="user-admin-messaging"
KUBERNETES_VERSION="v1.28.0"
NODES=3
INGRESS_ENABLED=true
METRICS_ENABLED=true
FORCE_RECREATE=false

# Get script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
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
    echo "Set up local Kubernetes cluster for development"
    echo ""
    echo "Options:"
    echo "  -t, --type TYPE             Cluster type (kind|minikube, default: kind)"
    echo "  -n, --name NAME             Cluster name (default: user-admin-messaging)"
    echo "  -k, --kubernetes VERSION    Kubernetes version (default: v1.28.0)"
    echo "  --nodes COUNT               Number of nodes for kind cluster (default: 3)"
    echo "  --no-ingress               Disable ingress controller setup"
    echo "  --no-metrics               Disable metrics server setup"
    echo "  -f, --force                Force recreate cluster if it exists"
    echo "  -h, --help                 Show this help message"
    echo ""
    echo "Examples:"
    echo "  $0                         # Create kind cluster with defaults"
    echo "  $0 -t minikube             # Create minikube cluster"
    echo "  $0 --nodes 1 --no-ingress # Single node kind cluster without ingress"
    echo "  $0 -f                      # Force recreate existing cluster"
    exit 1
}

# Parse command line arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        -t|--type)
            CLUSTER_TYPE="$2"
            shift 2
            ;;
        -n|--name)
            CLUSTER_NAME="$2"
            shift 2
            ;;
        -k|--kubernetes)
            KUBERNETES_VERSION="$2"
            shift 2
            ;;
        --nodes)
            NODES="$2"
            shift 2
            ;;
        --no-ingress)
            INGRESS_ENABLED=false
            shift
            ;;
        --no-metrics)
            METRICS_ENABLED=false
            shift
            ;;
        -f|--force)
            FORCE_RECREATE=true
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

# Validate cluster type
if [[ ! "$CLUSTER_TYPE" =~ ^(kind|minikube)$ ]]; then
    print_error "Invalid cluster type: $CLUSTER_TYPE. Must be 'kind' or 'minikube'."
    exit 1
fi

# Check prerequisites
check_prerequisites() {
    print_status "Checking prerequisites..."
    
    # Check Docker
    if ! command -v docker &> /dev/null; then
        print_error "Docker is not installed or not in PATH"
        exit 1
    fi
    
    if ! docker info &> /dev/null; then
        print_error "Docker daemon is not running"
        exit 1
    fi
    
    # Check kubectl
    if ! command -v kubectl &> /dev/null; then
        print_error "kubectl is not installed or not in PATH"
        print_status "Install kubectl: https://kubernetes.io/docs/tasks/tools/"
        exit 1
    fi
    
    # Check cluster-specific tools
    case $CLUSTER_TYPE in
        kind)
            if ! command -v kind &> /dev/null; then
                print_error "kind is not installed or not in PATH"
                print_status "Install kind: https://kind.sigs.k8s.io/docs/user/quick-start/#installation"
                exit 1
            fi
            ;;
        minikube)
            if ! command -v minikube &> /dev/null; then
                print_error "minikube is not installed or not in PATH"
                print_status "Install minikube: https://minikube.sigs.k8s.io/docs/start/"
                exit 1
            fi
            ;;
    esac
    
    print_success "Prerequisites check passed"
}

# Create kind cluster
create_kind_cluster() {
    print_status "Creating kind cluster: $CLUSTER_NAME"
    
    # Check if cluster already exists
    if kind get clusters | grep -q "^${CLUSTER_NAME}$"; then
        if [ "$FORCE_RECREATE" = true ]; then
            print_warning "Cluster $CLUSTER_NAME already exists, deleting..."
            kind delete cluster --name "$CLUSTER_NAME"
        else
            print_error "Cluster $CLUSTER_NAME already exists. Use -f to force recreate."
            exit 1
        fi
    fi
    
    # Create kind configuration
    local config_file=$(mktemp)
    
    cat > "$config_file" << EOF
kind: Cluster
apiVersion: kind.x-k8s.io/v1alpha4
name: $CLUSTER_NAME
nodes:
EOF
    
    # Add control plane node
    cat >> "$config_file" << EOF
- role: control-plane
  image: kindest/node:$KUBERNETES_VERSION
EOF
    
    # Add ingress port mapping if enabled
    if [ "$INGRESS_ENABLED" = true ]; then
        cat >> "$config_file" << EOF
  kubeadmConfigPatches:
  - |
    kind: InitConfiguration
    nodeRegistration:
      kubeletExtraArgs:
        node-labels: "ingress-ready=true"
  extraPortMappings:
  - containerPort: 80
    hostPort: 80
    protocol: TCP
  - containerPort: 443
    hostPort: 443
    protocol: TCP
EOF
    fi
    
    # Add worker nodes
    for ((i=1; i<NODES; i++)); do
        cat >> "$config_file" << EOF
- role: worker
  image: kindest/node:$KUBERNETES_VERSION
EOF
    done
    
    print_debug "Kind configuration:"
    cat "$config_file"
    
    # Create cluster
    kind create cluster --config "$config_file"
    
    # Clean up config file
    rm -f "$config_file"
    
    # Set kubectl context
    kubectl cluster-info --context "kind-${CLUSTER_NAME}"
    
    print_success "Kind cluster created successfully"
}

# Create minikube cluster
create_minikube_cluster() {
    print_status "Creating minikube cluster: $CLUSTER_NAME"
    
    # Check if cluster already exists
    if minikube profile list -o json 2>/dev/null | grep -q "\"Name\":\"${CLUSTER_NAME}\""; then
        if [ "$FORCE_RECREATE" = true ]; then
            print_warning "Cluster $CLUSTER_NAME already exists, deleting..."
            minikube delete --profile "$CLUSTER_NAME"
        else
            print_error "Cluster $CLUSTER_NAME already exists. Use -f to force recreate."
            exit 1
        fi
    fi
    
    # Start minikube with configuration
    local minikube_args=(
        "--profile=$CLUSTER_NAME"
        "--kubernetes-version=$KUBERNETES_VERSION"
        "--driver=docker"
        "--cpus=2"
        "--memory=4096"
        "--disk-size=20g"
    )
    
    if [ "$NODES" -gt 1 ]; then
        minikube_args+=("--nodes=$NODES")
    fi
    
    minikube start "${minikube_args[@]}"
    
    # Set kubectl context
    kubectl config use-context "$CLUSTER_NAME"
    kubectl cluster-info
    
    print_success "Minikube cluster created successfully"
}

# Setup ingress controller
setup_ingress() {
    if [ "$INGRESS_ENABLED" = false ]; then
        print_status "Skipping ingress controller setup"
        return
    fi
    
    print_status "Setting up ingress controller..."
    
    case $CLUSTER_TYPE in
        kind)
            # Install NGINX Ingress Controller for kind
            kubectl apply -f https://raw.githubusercontent.com/kubernetes/ingress-nginx/main/deploy/static/provider/kind/deploy.yaml
            
            # Wait for ingress controller to be ready
            print_status "Waiting for ingress controller to be ready..."
            kubectl wait --namespace ingress-nginx \
                --for=condition=ready pod \
                --selector=app.kubernetes.io/component=controller \
                --timeout=90s
            ;;
        minikube)
            # Enable ingress addon for minikube
            minikube addons enable ingress --profile "$CLUSTER_NAME"
            
            # Wait for ingress controller to be ready
            print_status "Waiting for ingress controller to be ready..."
            kubectl wait --namespace ingress-nginx \
                --for=condition=ready pod \
                --selector=app.kubernetes.io/name=ingress-nginx \
                --timeout=90s
            ;;
    esac
    
    print_success "Ingress controller setup completed"
}

# Setup metrics server
setup_metrics() {
    if [ "$METRICS_ENABLED" = false ]; then
        print_status "Skipping metrics server setup"
        return
    fi
    
    print_status "Setting up metrics server..."
    
    case $CLUSTER_TYPE in
        kind)
            # Install metrics server for kind
            kubectl apply -f https://github.com/kubernetes-sigs/metrics-server/releases/latest/download/components.yaml
            
            # Patch metrics server for kind (insecure TLS)
            kubectl patch deployment metrics-server -n kube-system --type='json' \
                -p='[{"op": "add", "path": "/spec/template/spec/containers/0/args/-", "value": "--kubelet-insecure-tls"}]'
            ;;
        minikube)
            # Enable metrics server addon for minikube
            minikube addons enable metrics-server --profile "$CLUSTER_NAME"
            ;;
    esac
    
    # Wait for metrics server to be ready
    print_status "Waiting for metrics server to be ready..."
    kubectl wait --namespace kube-system \
        --for=condition=ready pod \
        --selector=k8s-app=metrics-server \
        --timeout=90s
    
    print_success "Metrics server setup completed"
}

# Setup development namespace
setup_dev_namespace() {
    print_status "Setting up development namespace..."
    
    # Create dev namespace
    kubectl create namespace dev --dry-run=client -o yaml | kubectl apply -f -
    
    # Set dev namespace as default
    kubectl config set-context --current --namespace=dev
    
    print_success "Development namespace setup completed"
}

# Install additional tools
install_tools() {
    print_status "Installing additional development tools..."
    
    # Install Redis for development
    print_status "Installing Redis..."
    kubectl apply -f - << EOF
apiVersion: apps/v1
kind: Deployment
metadata:
  name: redis
  namespace: dev
spec:
  replicas: 1
  selector:
    matchLabels:
      app: redis
  template:
    metadata:
      labels:
        app: redis
    spec:
      containers:
      - name: redis
        image: redis:7-alpine
        ports:
        - containerPort: 6379
        resources:
          requests:
            cpu: 100m
            memory: 128Mi
          limits:
            cpu: 200m
            memory: 256Mi
---
apiVersion: v1
kind: Service
metadata:
  name: redis-service
  namespace: dev
spec:
  selector:
    app: redis
  ports:
  - port: 6379
    targetPort: 6379
  type: ClusterIP
EOF
    
    # Wait for Redis to be ready
    kubectl wait --namespace dev \
        --for=condition=ready pod \
        --selector=app=redis \
        --timeout=60s
    
    print_success "Additional tools installed"
}

# Show cluster information
show_cluster_info() {
    echo ""
    print_success "Local Kubernetes cluster setup completed!"
    echo ""
    
    print_status "Cluster Information:"
    echo "  Type: $CLUSTER_TYPE"
    echo "  Name: $CLUSTER_NAME"
    echo "  Kubernetes Version: $KUBERNETES_VERSION"
    echo "  Nodes: $NODES"
    echo "  Ingress Enabled: $INGRESS_ENABLED"
    echo "  Metrics Enabled: $METRICS_ENABLED"
    echo ""
    
    print_status "Cluster Status:"
    kubectl get nodes
    echo ""
    
    print_status "System Pods:"
    kubectl get pods -A | grep -E "(ingress|metrics|kube-system)"
    echo ""
    
    print_status "Development Namespace:"
    kubectl get all -n dev
    echo ""
    
    print_status "Useful Commands:"
    echo "  Switch to cluster context:"
    case $CLUSTER_TYPE in
        kind)
            echo "    kubectl config use-context kind-${CLUSTER_NAME}"
            ;;
        minikube)
            echo "    kubectl config use-context ${CLUSTER_NAME}"
            ;;
    esac
    echo ""
    echo "  Deploy application:"
    echo "    $SCRIPT_DIR/deploy-environment.sh development"
    echo ""
    echo "  Access services locally:"
    if [ "$INGRESS_ENABLED" = true ]; then
        echo "    Add to /etc/hosts: 127.0.0.1 messaging.local"
        echo "    Access via: http://messaging.local/user"
    else
        echo "    kubectl port-forward service/websocket-service 8080:8080 -n dev"
    fi
    echo ""
    echo "  Delete cluster:"
    case $CLUSTER_TYPE in
        kind)
            echo "    kind delete cluster --name ${CLUSTER_NAME}"
            ;;
        minikube)
            echo "    minikube delete --profile ${CLUSTER_NAME}"
            ;;
    esac
}

# Main execution
main() {
    print_status "Setting up local Kubernetes cluster..."
    print_status "Configuration:"
    print_status "  Type: $CLUSTER_TYPE"
    print_status "  Name: $CLUSTER_NAME"
    print_status "  Kubernetes Version: $KUBERNETES_VERSION"
    print_status "  Nodes: $NODES"
    print_status "  Ingress Enabled: $INGRESS_ENABLED"
    print_status "  Metrics Enabled: $METRICS_ENABLED"
    print_status "  Force Recreate: $FORCE_RECREATE"
    
    check_prerequisites
    
    # Create cluster based on type
    case $CLUSTER_TYPE in
        kind)
            create_kind_cluster
            ;;
        minikube)
            create_minikube_cluster
            ;;
    esac
    
    setup_ingress
    setup_metrics
    setup_dev_namespace
    install_tools
    
    show_cluster_info
}

# Run main function
main "$@"