#!/bin/bash

# Kubernetes Cleanup Script
# This script removes Kubernetes deployments and resources

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Default values
NAMESPACE=""
CLEANUP_TYPE="deployment"
FORCE=false
DRY_RUN=false
CONFIRM=true

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
    echo "Usage: $0 [OPTIONS] [CLEANUP_TYPE]"
    echo ""
    echo "Clean up Kubernetes resources"
    echo ""
    echo "Cleanup Types:"
    echo "  deployment                  Remove application deployment (default)"
    echo "  namespace                   Remove entire namespace and all resources"
    echo "  config                      Remove only ConfigMaps and Secrets"
    echo "  images                      Remove unused Docker images from cluster"
    echo "  all                         Remove everything including namespace"
    echo ""
    echo "Options:"
    echo "  -n, --namespace NAMESPACE   Kubernetes namespace (required for most operations)"
    echo "  -f, --force                 Force cleanup without confirmation"
    echo "  -d, --dry-run               Show what would be deleted without actually deleting"
    echo "  --no-confirm                Skip confirmation prompts"
    echo "  -h, --help                  Show this help message"
    echo ""
    echo "Examples:"
    echo "  $0 -n dev                   # Clean up deployment in dev namespace"
    echo "  $0 -n staging namespace -f  # Force remove staging namespace"
    echo "  $0 config -n prod           # Remove only config in prod namespace"
    echo "  $0 images                   # Clean up unused Docker images"
    echo "  $0 all -n test --no-confirm # Remove everything in test namespace"
    exit 1
}

# Parse command line arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        -n|--namespace)
            NAMESPACE="$2"
            shift 2
            ;;
        -f|--force)
            FORCE=true
            shift
            ;;
        -d|--dry-run)
            DRY_RUN=true
            shift
            ;;
        --no-confirm)
            CONFIRM=false
            shift
            ;;
        -h|--help)
            usage
            ;;
        deployment|namespace|config|images|all)
            CLEANUP_TYPE="$1"
            shift
            ;;
        *)
            print_error "Unknown option: $1"
            usage
            ;;
    esac
done

# Validate namespace requirement
if [[ "$CLEANUP_TYPE" != "images" ]] && [ -z "$NAMESPACE" ]; then
    print_error "Namespace is required for cleanup type: $CLEANUP_TYPE"
    usage
fi

# Check prerequisites
check_prerequisites() {
    print_status "Checking prerequisites..."
    
    # Check if kubectl is available
    if ! command -v kubectl &> /dev/null; then
        print_error "kubectl is not installed or not in PATH"
        exit 1
    fi
    
    # Check kubectl connection
    if ! kubectl cluster-info &> /dev/null; then
        print_error "Cannot connect to Kubernetes cluster"
        exit 1
    fi
    
    # Check if namespace exists (if required)
    if [ -n "$NAMESPACE" ] && ! kubectl get namespace "$NAMESPACE" &> /dev/null; then
        print_error "Namespace '$NAMESPACE' does not exist"
        exit 1
    fi
    
    print_success "Prerequisites check passed"
}

# Confirm cleanup action
confirm_cleanup() {
    if [ "$FORCE" = true ] || [ "$CONFIRM" = false ]; then
        return 0
    fi
    
    echo ""
    print_warning "You are about to perform cleanup operation:"
    print_warning "  Type: $CLEANUP_TYPE"
    if [ -n "$NAMESPACE" ]; then
        print_warning "  Namespace: $NAMESPACE"
    fi
    print_warning "  Dry Run: $DRY_RUN"
    
    if [ "$CLEANUP_TYPE" = "namespace" ] || [ "$CLEANUP_TYPE" = "all" ]; then
        print_error "This will DELETE the entire namespace and ALL resources in it!"
        print_error "This action CANNOT be undone!"
    fi
    
    echo ""
    read -p "Are you sure you want to continue? (type 'yes' to confirm): " confirm
    
    if [ "$confirm" != "yes" ]; then
        print_status "Cleanup cancelled by user"
        exit 0
    fi
}

# Show resources to be deleted
show_resources() {
    local kubectl_opts=""
    if [ -n "$NAMESPACE" ]; then
        kubectl_opts="--namespace=$NAMESPACE"
    fi
    
    print_status "Resources that will be affected:"
    
    case $CLEANUP_TYPE in
        deployment)
            echo ""
            print_debug "Deployments:"
            kubectl get deployments $kubectl_opts 2>/dev/null || echo "  No deployments found"
            
            echo ""
            print_debug "Services:"
            kubectl get services $kubectl_opts 2>/dev/null || echo "  No services found"
            
            echo ""
            print_debug "Ingress:"
            kubectl get ingress $kubectl_opts 2>/dev/null || echo "  No ingress found"
            
            echo ""
            print_debug "HPA:"
            kubectl get hpa $kubectl_opts 2>/dev/null || echo "  No HPA found"
            ;;
        config)
            echo ""
            print_debug "ConfigMaps:"
            kubectl get configmaps $kubectl_opts 2>/dev/null || echo "  No ConfigMaps found"
            
            echo ""
            print_debug "Secrets:"
            kubectl get secrets $kubectl_opts 2>/dev/null || echo "  No Secrets found"
            ;;
        namespace|all)
            echo ""
            print_debug "All resources in namespace $NAMESPACE:"
            kubectl get all $kubectl_opts 2>/dev/null || echo "  No resources found"
            
            echo ""
            print_debug "ConfigMaps and Secrets:"
            kubectl get configmaps,secrets $kubectl_opts 2>/dev/null || echo "  No config resources found"
            ;;
        images)
            echo ""
            print_debug "Docker images in cluster (this may take a moment)..."
            # This is cluster-specific and may not work on all cluster types
            ;;
    esac
}

# Clean up deployment resources
cleanup_deployment() {
    print_status "Cleaning up application deployment..."
    
    local kubectl_opts="--namespace=$NAMESPACE"
    if [ "$DRY_RUN" = true ]; then
        kubectl_opts="$kubectl_opts --dry-run=client"
        print_warning "DRY RUN MODE - No actual changes will be made"
    fi
    
    # Delete resources in reverse order of creation
    print_status "Removing HorizontalPodAutoscalers..."
    kubectl delete hpa --all $kubectl_opts --ignore-not-found=true
    
    print_status "Removing Ingress resources..."
    kubectl delete ingress --all $kubectl_opts --ignore-not-found=true
    
    print_status "Removing Deployments..."
    kubectl delete deployment --all $kubectl_opts --ignore-not-found=true
    
    print_status "Removing Services..."
    # Keep default kubernetes service
    kubectl get services $kubectl_opts -o name | grep -v "service/kubernetes" | xargs -r kubectl delete $kubectl_opts --ignore-not-found=true
    
    if [ "$DRY_RUN" = false ]; then
        print_status "Waiting for pods to terminate..."
        kubectl wait --for=delete pods --all $kubectl_opts --timeout=120s || true
    fi
    
    print_success "Deployment cleanup completed"
}

# Clean up configuration resources
cleanup_config() {
    print_status "Cleaning up configuration resources..."
    
    local kubectl_opts="--namespace=$NAMESPACE"
    if [ "$DRY_RUN" = true ]; then
        kubectl_opts="$kubectl_opts --dry-run=client"
        print_warning "DRY RUN MODE - No actual changes will be made"
    fi
    
    print_status "Removing ConfigMaps..."
    kubectl delete configmap app-config $kubectl_opts --ignore-not-found=true
    
    print_status "Removing Secrets..."
    kubectl delete secret app-secrets $kubectl_opts --ignore-not-found=true
    
    print_success "Configuration cleanup completed"
}

# Clean up entire namespace
cleanup_namespace() {
    print_status "Cleaning up entire namespace: $NAMESPACE"
    
    if [ "$DRY_RUN" = true ]; then
        print_warning "DRY RUN MODE - Namespace would be deleted: $NAMESPACE"
        return
    fi
    
    # Delete the namespace (this will delete all resources in it)
    kubectl delete namespace "$NAMESPACE" --ignore-not-found=true
    
    print_status "Waiting for namespace to be fully deleted..."
    while kubectl get namespace "$NAMESPACE" &> /dev/null; do
        print_debug "Waiting for namespace deletion..."
        sleep 5
    done
    
    print_success "Namespace cleanup completed"
}

# Clean up Docker images
cleanup_images() {
    print_status "Cleaning up unused Docker images..."
    
    # Detect cluster type
    local current_context=$(kubectl config current-context)
    
    if [[ "$current_context" == kind-* ]]; then
        print_status "Detected kind cluster, cleaning up Docker images..."
        
        if [ "$DRY_RUN" = true ]; then
            print_warning "DRY RUN MODE - Would clean up Docker images"
            docker images "user-admin-messaging/*" --format "table {{.Repository}}\t{{.Tag}}\t{{.Size}}"
            return
        fi
        
        # Remove user-admin-messaging images
        local images=$(docker images "user-admin-messaging/*" -q)
        if [ -n "$images" ]; then
            print_status "Removing user-admin-messaging Docker images..."
            docker rmi $images -f || true
        fi
        
        # Clean up dangling images
        print_status "Removing dangling images..."
        docker image prune -f || true
        
    elif [[ "$current_context" == *minikube* ]]; then
        print_status "Detected minikube cluster, cleaning up images in minikube..."
        
        if [ "$DRY_RUN" = true ]; then
            print_warning "DRY RUN MODE - Would clean up minikube images"
            return
        fi
        
        # Set minikube docker environment
        eval $(minikube docker-env 2>/dev/null) || true
        
        # Remove user-admin-messaging images
        local images=$(docker images "user-admin-messaging/*" -q 2>/dev/null)
        if [ -n "$images" ]; then
            print_status "Removing user-admin-messaging images from minikube..."
            docker rmi $images -f || true
        fi
        
        # Clean up dangling images
        docker image prune -f || true
        
    else
        print_warning "Unknown cluster type, skipping image cleanup"
        print_status "For manual cleanup, remove images with tag 'user-admin-messaging/*'"
    fi
    
    print_success "Image cleanup completed"
}

# Clean up everything
cleanup_all() {
    print_status "Performing complete cleanup..."
    
    # Clean up deployment first
    cleanup_deployment
    
    # Clean up configuration
    cleanup_config
    
    # Clean up namespace
    cleanup_namespace
    
    # Clean up images
    cleanup_images
    
    print_success "Complete cleanup finished"
}

# Show cleanup summary
show_summary() {
    echo ""
    print_status "Cleanup Summary"
    echo "==============="
    echo "  Type: $CLEANUP_TYPE"
    if [ -n "$NAMESPACE" ]; then
        echo "  Namespace: $NAMESPACE"
    fi
    echo "  Dry Run: $DRY_RUN"
    echo "  Force: $FORCE"
    
    if [ "$DRY_RUN" = false ]; then
        echo ""
        print_success "Cleanup completed successfully!"
        
        if [ "$CLEANUP_TYPE" != "namespace" ] && [ "$CLEANUP_TYPE" != "all" ] && [ -n "$NAMESPACE" ]; then
            echo ""
            print_status "Remaining resources in namespace $NAMESPACE:"
            kubectl get all --namespace="$NAMESPACE" 2>/dev/null || echo "  No resources found"
        fi
    else
        echo ""
        print_status "Dry run completed - no actual changes were made"
    fi
}

# Main execution
main() {
    print_status "Starting Kubernetes cleanup..."
    print_status "Configuration:"
    print_status "  Cleanup Type: $CLEANUP_TYPE"
    if [ -n "$NAMESPACE" ]; then
        print_status "  Namespace: $NAMESPACE"
    fi
    print_status "  Force: $FORCE"
    print_status "  Dry Run: $DRY_RUN"
    print_status "  Confirm: $CONFIRM"
    
    check_prerequisites
    show_resources
    confirm_cleanup
    
    case $CLEANUP_TYPE in
        deployment)
            cleanup_deployment
            ;;
        config)
            cleanup_config
            ;;
        namespace)
            cleanup_namespace
            ;;
        images)
            cleanup_images
            ;;
        all)
            cleanup_all
            ;;
        *)
            print_error "Unknown cleanup type: $CLEANUP_TYPE"
            usage
            ;;
    esac
    
    show_summary
}

# Run main function
main "$@"