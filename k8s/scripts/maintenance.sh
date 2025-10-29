#!/bin/bash

# Kubernetes Maintenance Script
# This script handles updating configurations and rolling deployments

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Default values
NAMESPACE=""
OPERATION=""
DEPLOYMENT=""
IMAGE_TAG=""
CONFIG_FILE=""
WAIT_TIMEOUT=300
DRY_RUN=false

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
    echo "Usage: $0 [OPTIONS] OPERATION"
    echo ""
    echo "Perform maintenance operations on Kubernetes deployment"
    echo ""
    echo "Operations:"
    echo "  update-config               Update ConfigMaps and Secrets"
    echo "  rolling-update              Perform rolling update of deployments"
    echo "  scale                       Scale deployments up or down"
    echo "  restart                     Restart deployments"
    echo "  update-image                Update deployment image"
    echo "  status                      Show deployment status"
    echo "  health-check                Perform health check on all services"
    echo ""
    echo "Options:"
    echo "  -n, --namespace NAMESPACE   Kubernetes namespace (required)"
    echo "  -d, --deployment NAME       Specific deployment name (for targeted operations)"
    echo "  -t, --tag TAG              Image tag for update-image operation"
    echo "  -c, --config FILE          Configuration file for update-config operation"
    echo "  -r, --replicas COUNT       Number of replicas for scale operation"
    echo "  --timeout SECONDS          Wait timeout in seconds (default: 300)"
    echo "  --dry-run                  Show what would be done without executing"
    echo "  -h, --help                 Show this help message"
    echo ""
    echo "Examples:"
    echo "  $0 -n prod update-config                    # Update all config in prod"
    echo "  $0 -n staging rolling-update                # Rolling update all deployments"
    echo "  $0 -n dev scale -d websocket-service -r 3   # Scale websocket to 3 replicas"
    echo "  $0 -n prod update-image -t v1.2.0           # Update all images to v1.2.0"
    echo "  $0 -n dev restart -d user-frontend-service  # Restart specific deployment"
    exit 1
}

# Parse command line arguments
REPLICAS=""
while [[ $# -gt 0 ]]; do
    case $1 in
        -n|--namespace)
            NAMESPACE="$2"
            shift 2
            ;;
        -d|--deployment)
            DEPLOYMENT="$2"
            shift 2
            ;;
        -t|--tag)
            IMAGE_TAG="$2"
            shift 2
            ;;
        -c|--config)
            CONFIG_FILE="$2"
            shift 2
            ;;
        -r|--replicas)
            REPLICAS="$2"
            shift 2
            ;;
        --timeout)
            WAIT_TIMEOUT="$2"
            shift 2
            ;;
        --dry-run)
            DRY_RUN=true
            shift
            ;;
        -h|--help)
            usage
            ;;
        update-config|rolling-update|scale|restart|update-image|status|health-check)
            OPERATION="$1"
            shift
            ;;
        *)
            print_error "Unknown option: $1"
            usage
            ;;
    esac
done

# Validate required parameters
if [ -z "$OPERATION" ]; then
    print_error "Operation is required"
    usage
fi

if [ -z "$NAMESPACE" ]; then
    print_error "Namespace is required"
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
    
    # Check if namespace exists
    if ! kubectl get namespace "$NAMESPACE" &> /dev/null; then
        print_error "Namespace '$NAMESPACE' does not exist"
        exit 1
    fi
    
    print_success "Prerequisites check passed"
}

# Get deployments list
get_deployments() {
    local kubectl_opts="--namespace=$NAMESPACE"
    
    if [ -n "$DEPLOYMENT" ]; then
        # Check if specific deployment exists
        if kubectl get deployment "$DEPLOYMENT" $kubectl_opts &> /dev/null; then
            echo "$DEPLOYMENT"
        else
            print_error "Deployment '$DEPLOYMENT' not found in namespace '$NAMESPACE'"
            exit 1
        fi
    else
        # Get all deployments
        kubectl get deployments $kubectl_opts -o jsonpath='{.items[*].metadata.name}' 2>/dev/null || echo ""
    fi
}

# Update configuration
update_config() {
    print_status "Updating configuration..."
    
    local kubectl_opts="--namespace=$NAMESPACE"
    if [ "$DRY_RUN" = true ]; then
        kubectl_opts="$kubectl_opts --dry-run=client"
        print_warning "DRY RUN MODE - No actual changes will be made"
    fi
    
    if [ -n "$CONFIG_FILE" ] && [ -f "$CONFIG_FILE" ]; then
        print_status "Applying configuration from file: $CONFIG_FILE"
        kubectl apply $kubectl_opts -f "$CONFIG_FILE"
    else
        # Update default configuration
        print_status "Updating default configuration..."
        
        # Check if environment-specific config exists
        local env_config="$K8S_DIR/config/environments/production.yaml"
        if [ -f "$env_config" ]; then
            kubectl apply $kubectl_opts -f "$env_config"
        else
            # Apply default config
            kubectl apply $kubectl_opts -f "$K8S_DIR/config/app-config.yaml"
            kubectl apply $kubectl_opts -f "$K8S_DIR/config/app-secrets.yaml"
        fi
    fi
    
    if [ "$DRY_RUN" = false ]; then
        # Restart deployments to pick up new config
        print_status "Restarting deployments to pick up new configuration..."
        local deployments=$(get_deployments)
        
        for deployment in $deployments; do
            if [ -n "$deployment" ]; then
                kubectl rollout restart deployment/"$deployment" $kubectl_opts
            fi
        done
        
        # Wait for rollouts to complete
        for deployment in $deployments; do
            if [ -n "$deployment" ]; then
                print_status "Waiting for $deployment rollout to complete..."
                kubectl rollout status deployment/"$deployment" $kubectl_opts --timeout="${WAIT_TIMEOUT}s"
            fi
        done
    fi
    
    print_success "Configuration update completed"
}

# Perform rolling update
rolling_update() {
    print_status "Performing rolling update..."
    
    local kubectl_opts="--namespace=$NAMESPACE"
    local deployments=$(get_deployments)
    
    if [ -z "$deployments" ]; then
        print_warning "No deployments found to update"
        return
    fi
    
    for deployment in $deployments; do
        print_status "Rolling update for deployment: $deployment"
        
        if [ "$DRY_RUN" = true ]; then
            print_warning "DRY RUN: Would restart deployment $deployment"
            continue
        fi
        
        # Trigger rolling update by restarting
        kubectl rollout restart deployment/"$deployment" $kubectl_opts
        
        # Wait for rollout to complete
        print_status "Waiting for $deployment rollout to complete..."
        kubectl rollout status deployment/"$deployment" $kubectl_opts --timeout="${WAIT_TIMEOUT}s"
        
        # Verify deployment health
        print_status "Verifying $deployment health..."
        kubectl wait --for=condition=available deployment/"$deployment" $kubectl_opts --timeout=60s
    done
    
    print_success "Rolling update completed"
}

# Scale deployments
scale_deployments() {
    if [ -z "$REPLICAS" ]; then
        print_error "Replicas count is required for scale operation. Use -r flag."
        exit 1
    fi
    
    print_status "Scaling deployments to $REPLICAS replicas..."
    
    local kubectl_opts="--namespace=$NAMESPACE"
    local deployments=$(get_deployments)
    
    if [ -z "$deployments" ]; then
        print_warning "No deployments found to scale"
        return
    fi
    
    for deployment in $deployments; do
        print_status "Scaling deployment: $deployment to $REPLICAS replicas"
        
        if [ "$DRY_RUN" = true ]; then
            print_warning "DRY RUN: Would scale deployment $deployment to $REPLICAS replicas"
            continue
        fi
        
        kubectl scale deployment/"$deployment" --replicas="$REPLICAS" $kubectl_opts
        
        # Wait for scaling to complete
        print_status "Waiting for $deployment scaling to complete..."
        kubectl wait --for=condition=available deployment/"$deployment" $kubectl_opts --timeout="${WAIT_TIMEOUT}s"
    done
    
    print_success "Scaling completed"
}

# Restart deployments
restart_deployments() {
    print_status "Restarting deployments..."
    
    local kubectl_opts="--namespace=$NAMESPACE"
    local deployments=$(get_deployments)
    
    if [ -z "$deployments" ]; then
        print_warning "No deployments found to restart"
        return
    fi
    
    for deployment in $deployments; do
        print_status "Restarting deployment: $deployment"
        
        if [ "$DRY_RUN" = true ]; then
            print_warning "DRY RUN: Would restart deployment $deployment"
            continue
        fi
        
        kubectl rollout restart deployment/"$deployment" $kubectl_opts
        
        # Wait for restart to complete
        print_status "Waiting for $deployment restart to complete..."
        kubectl rollout status deployment/"$deployment" $kubectl_opts --timeout="${WAIT_TIMEOUT}s"
    done
    
    print_success "Restart completed"
}

# Update deployment images
update_images() {
    if [ -z "$IMAGE_TAG" ]; then
        print_error "Image tag is required for update-image operation. Use -t flag."
        exit 1
    fi
    
    print_status "Updating deployment images to tag: $IMAGE_TAG"
    
    local kubectl_opts="--namespace=$NAMESPACE"
    local deployments=$(get_deployments)
    
    if [ -z "$deployments" ]; then
        print_warning "No deployments found to update"
        return
    fi
    
    for deployment in $deployments; do
        print_status "Updating image for deployment: $deployment"
        
        # Get current image name (without tag)
        local current_image=$(kubectl get deployment "$deployment" $kubectl_opts -o jsonpath='{.spec.template.spec.containers[0].image}' | cut -d':' -f1)
        local new_image="${current_image}:${IMAGE_TAG}"
        
        print_debug "Updating $deployment image from $(kubectl get deployment "$deployment" $kubectl_opts -o jsonpath='{.spec.template.spec.containers[0].image}') to $new_image"
        
        if [ "$DRY_RUN" = true ]; then
            print_warning "DRY RUN: Would update deployment $deployment image to $new_image"
            continue
        fi
        
        kubectl set image deployment/"$deployment" "${deployment}=${new_image}" $kubectl_opts
        
        # Wait for rollout to complete
        print_status "Waiting for $deployment image update to complete..."
        kubectl rollout status deployment/"$deployment" $kubectl_opts --timeout="${WAIT_TIMEOUT}s"
    done
    
    print_success "Image update completed"
}

# Show deployment status
show_status() {
    print_status "Deployment Status for namespace: $NAMESPACE"
    
    local kubectl_opts="--namespace=$NAMESPACE"
    
    echo ""
    print_status "Deployments:"
    kubectl get deployments $kubectl_opts -o wide
    
    echo ""
    print_status "Pods:"
    kubectl get pods $kubectl_opts -o wide
    
    echo ""
    print_status "Services:"
    kubectl get services $kubectl_opts
    
    echo ""
    print_status "Ingress:"
    kubectl get ingress $kubectl_opts 2>/dev/null || echo "No ingress resources found"
    
    echo ""
    print_status "HorizontalPodAutoscalers:"
    kubectl get hpa $kubectl_opts 2>/dev/null || echo "No HPA resources found"
    
    echo ""
    print_status "ConfigMaps:"
    kubectl get configmaps $kubectl_opts
    
    echo ""
    print_status "Secrets:"
    kubectl get secrets $kubectl_opts
    
    # Show resource usage if metrics server is available
    echo ""
    print_status "Resource Usage:"
    kubectl top pods $kubectl_opts 2>/dev/null || print_warning "Metrics server not available"
    
    # Show recent events
    echo ""
    print_status "Recent Events:"
    kubectl get events $kubectl_opts --sort-by='.lastTimestamp' | tail -10
}

# Perform health check
health_check() {
    print_status "Performing health check..."
    
    local kubectl_opts="--namespace=$NAMESPACE"
    local health_results=()
    local failed_checks=0
    
    # Check deployment status
    print_status "Checking deployment status..."
    local deployments=$(get_deployments)
    
    for deployment in $deployments; do
        if [ -n "$deployment" ]; then
            local ready_replicas=$(kubectl get deployment "$deployment" $kubectl_opts -o jsonpath='{.status.readyReplicas}' 2>/dev/null || echo "0")
            local desired_replicas=$(kubectl get deployment "$deployment" $kubectl_opts -o jsonpath='{.spec.replicas}' 2>/dev/null || echo "0")
            
            if [ "$ready_replicas" = "$desired_replicas" ] && [ "$ready_replicas" != "0" ]; then
                print_success "✓ Deployment $deployment: $ready_replicas/$desired_replicas replicas ready"
                health_results+=("PASS: Deployment $deployment")
            else
                print_error "✗ Deployment $deployment: $ready_replicas/$desired_replicas replicas ready"
                health_results+=("FAIL: Deployment $deployment")
                failed_checks=$((failed_checks + 1))
            fi
        fi
    done
    
    # Check service endpoints
    print_status "Checking service endpoints..."
    local services=$(kubectl get services $kubectl_opts -o jsonpath='{.items[*].metadata.name}' 2>/dev/null)
    
    for service in $services; do
        if [[ "$service" != "kubernetes" ]]; then
            local endpoints=$(kubectl get endpoints "$service" $kubectl_opts -o jsonpath='{.subsets[*].addresses[*].ip}' 2>/dev/null | wc -w)
            
            if [ "$endpoints" -gt 0 ]; then
                print_success "✓ Service $service: $endpoints endpoint(s) available"
                health_results+=("PASS: Service $service")
            else
                print_error "✗ Service $service: No endpoints available"
                health_results+=("FAIL: Service $service")
                failed_checks=$((failed_checks + 1))
            fi
        fi
    done
    
    # Check WebSocket health endpoints
    print_status "Checking WebSocket health endpoints..."
    local ws_pods=$(kubectl get pods -l app=websocket-service $kubectl_opts -o jsonpath='{.items[*].metadata.name}' 2>/dev/null)
    
    for pod in $ws_pods; do
        if [ -n "$pod" ]; then
            if kubectl exec "$pod" $kubectl_opts -- curl -f -s http://localhost:8081/health &> /dev/null; then
                print_success "✓ Health endpoint ($pod): OK"
                health_results+=("PASS: Health endpoint ($pod)")
            else
                print_error "✗ Health endpoint ($pod): FAILED"
                health_results+=("FAIL: Health endpoint ($pod)")
                failed_checks=$((failed_checks + 1))
            fi
        fi
    done
    
    # Show health check summary
    echo ""
    print_status "Health Check Summary:"
    for result in "${health_results[@]}"; do
        echo "  $result"
    done
    
    echo ""
    if [ "$failed_checks" -eq 0 ]; then
        print_success "All health checks passed!"
        return 0
    else
        print_error "$failed_checks health check(s) failed"
        return 1
    fi
}

# Main execution
main() {
    print_status "Starting maintenance operation: $OPERATION"
    print_status "Configuration:"
    print_status "  Namespace: $NAMESPACE"
    if [ -n "$DEPLOYMENT" ]; then
        print_status "  Deployment: $DEPLOYMENT"
    fi
    if [ -n "$IMAGE_TAG" ]; then
        print_status "  Image Tag: $IMAGE_TAG"
    fi
    if [ -n "$REPLICAS" ]; then
        print_status "  Replicas: $REPLICAS"
    fi
    if [ -n "$CONFIG_FILE" ]; then
        print_status "  Config File: $CONFIG_FILE"
    fi
    print_status "  Timeout: ${WAIT_TIMEOUT}s"
    print_status "  Dry Run: $DRY_RUN"
    
    check_prerequisites
    
    case $OPERATION in
        update-config)
            update_config
            ;;
        rolling-update)
            rolling_update
            ;;
        scale)
            scale_deployments
            ;;
        restart)
            restart_deployments
            ;;
        update-image)
            update_images
            ;;
        status)
            show_status
            ;;
        health-check)
            health_check
            ;;
        *)
            print_error "Unknown operation: $OPERATION"
            usage
            ;;
    esac
    
    print_success "Maintenance operation completed!"
}

# Run main function
main "$@"