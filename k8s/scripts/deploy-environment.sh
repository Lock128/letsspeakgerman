#!/bin/bash

# Environment-Specific Kubernetes Deployment Script
# This script handles deployment with proper namespace and environment configuration

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Default values
ENVIRONMENT=""
NAMESPACE=""
CONFIG_ONLY=false
DRY_RUN=false
FORCE=false

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

print_debug() {
    echo -e "${BLUE}[DEBUG]${NC} $1"
}

# Function to show usage
usage() {
    echo "Usage: $0 [OPTIONS] ENVIRONMENT"
    echo ""
    echo "Deploy to specific environment with proper configuration"
    echo ""
    echo "Arguments:"
    echo "  ENVIRONMENT                  Environment to deploy (development|staging|production)"
    echo ""
    echo "Options:"
    echo "  -n, --namespace NAMESPACE    Override default namespace for environment"
    echo "  -c, --config-only           Only deploy configuration (ConfigMaps/Secrets)"
    echo "  -d, --dry-run               Perform a dry run without applying changes"
    echo "  -f, --force                 Force deployment even if environment is production"
    echo "  -h, --help                  Show this help message"
    echo ""
    echo "Environment Defaults:"
    echo "  development -> dev namespace"
    echo "  staging     -> staging namespace"
    echo "  production  -> production namespace"
    echo ""
    echo "Examples:"
    echo "  $0 development                      # Deploy to development environment"
    echo "  $0 staging -n my-staging           # Deploy to staging with custom namespace"
    echo "  $0 production -f                   # Force production deployment"
    echo "  $0 development -c                  # Only update configuration"
    exit 1
}

# Parse command line arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        -n|--namespace)
            NAMESPACE="$2"
            shift 2
            ;;
        -c|--config-only)
            CONFIG_ONLY=true
            shift
            ;;
        -d|--dry-run)
            DRY_RUN=true
            shift
            ;;
        -f|--force)
            FORCE=true
            shift
            ;;
        -h|--help)
            usage
            ;;
        development|staging|production)
            if [ -z "$ENVIRONMENT" ]; then
                ENVIRONMENT="$1"
            else
                print_error "Multiple environments specified"
                usage
            fi
            shift
            ;;
        *)
            print_error "Unknown option: $1"
            usage
            ;;
    esac
done

# Validate environment
if [ -z "$ENVIRONMENT" ]; then
    print_error "Environment is required"
    usage
fi

if [[ ! "$ENVIRONMENT" =~ ^(development|staging|production)$ ]]; then
    print_error "Invalid environment: $ENVIRONMENT. Must be development, staging, or production."
    exit 1
fi

# Set default namespace if not provided
if [ -z "$NAMESPACE" ]; then
    case $ENVIRONMENT in
        development)
            NAMESPACE="dev"
            ;;
        staging)
            NAMESPACE="staging"
            ;;
        production)
            NAMESPACE="production"
            ;;
    esac
fi

# Production safety check
if [ "$ENVIRONMENT" = "production" ] && [ "$FORCE" = false ]; then
    echo ""
    print_warning "You are about to deploy to PRODUCTION environment!"
    print_warning "Namespace: $NAMESPACE"
    print_warning "This action cannot be undone."
    echo ""
    read -p "Are you sure you want to continue? (type 'yes' to confirm): " confirm
    
    if [ "$confirm" != "yes" ]; then
        print_status "Deployment cancelled by user"
        exit 0
    fi
fi

# Environment configuration
get_environment_config() {
    local env="$1"
    
    case $env in
        development)
            echo "Development environment configuration:"
            echo "  - Namespace: $NAMESPACE"
            echo "  - Replicas: 1 (minimal resources)"
            echo "  - Resource limits: Low"
            echo "  - Debug logging: Enabled"
            echo "  - Auto-scaling: Disabled"
            ;;
        staging)
            echo "Staging environment configuration:"
            echo "  - Namespace: $NAMESPACE"
            echo "  - Replicas: 2 (moderate resources)"
            echo "  - Resource limits: Medium"
            echo "  - Debug logging: Enabled"
            echo "  - Auto-scaling: Enabled"
            ;;
        production)
            echo "Production environment configuration:"
            echo "  - Namespace: $NAMESPACE"
            echo "  - Replicas: 3+ (high availability)"
            echo "  - Resource limits: High"
            echo "  - Debug logging: Disabled"
            echo "  - Auto-scaling: Enabled"
            echo "  - Monitoring: Full"
            ;;
    esac
}

# Create environment-specific configuration
create_environment_config() {
    local env="$1"
    local namespace="$2"
    local config_file="$K8S_DIR/config/environments/${env}.yaml"
    
    print_status "Creating environment-specific configuration for $env..."
    
    # Create environments directory if it doesn't exist
    mkdir -p "$K8S_DIR/config/environments"
    
    # Generate environment-specific ConfigMap and Secret
    cat > "$config_file" << EOF
---
apiVersion: v1
kind: ConfigMap
metadata:
  name: app-config
  namespace: $namespace
data:
  DEPLOYMENT_MODE: "kubernetes"
  ENVIRONMENT: "$env"
  LOG_LEVEL: "$([ "$env" = "production" ] && echo "info" || echo "debug")"
  REDIS_URL: "redis://redis-service:6379"
  WEBSOCKET_PORT: "8080"
  HEALTH_PORT: "8081"
  # Environment-specific settings
$(case $env in
    development)
        cat << DEV_EOF
  DEBUG: "true"
  CORS_ORIGIN: "*"
  RATE_LIMIT_ENABLED: "false"
DEV_EOF
        ;;
    staging)
        cat << STAGING_EOF
  DEBUG: "true"
  CORS_ORIGIN: "https://staging.example.com"
  RATE_LIMIT_ENABLED: "true"
  RATE_LIMIT_MAX: "1000"
STAGING_EOF
        ;;
    production)
        cat << PROD_EOF
  DEBUG: "false"
  CORS_ORIGIN: "https://messaging.example.com"
  RATE_LIMIT_ENABLED: "true"
  RATE_LIMIT_MAX: "500"
  MONITORING_ENABLED: "true"
PROD_EOF
        ;;
esac)

---
apiVersion: v1
kind: Secret
metadata:
  name: app-secrets
  namespace: $namespace
type: Opaque
data:
  # Base64 encoded secrets
  REDIS_PASSWORD: $(echo -n "redis-password-${env}" | base64)
  JWT_SECRET: $(echo -n "jwt-secret-${env}-$(date +%s)" | base64)
  SESSION_SECRET: $(echo -n "session-secret-${env}-$(date +%s)" | base64)
EOF

    print_status "Environment configuration created: $config_file"
}

# Update deployment manifests for environment
update_deployment_manifests() {
    local env="$1"
    local namespace="$2"
    
    print_status "Updating deployment manifests for $env environment..."
    
    local temp_dir=$(mktemp -d)
    
    # Copy manifests to temp directory
    cp -r "$K8S_DIR"/* "$temp_dir/"
    
    # Update namespace in all manifests
    find "$temp_dir" -name "*.yaml" -type f | while read -r file; do
        if grep -q "namespace:" "$file"; then
            sed -i.bak "s/namespace: .*/namespace: $namespace/g" "$file"
        else
            # Add namespace to metadata if not present
            sed -i.bak '/^metadata:/a\
  namespace: '"$namespace" "$file"
        fi
        rm -f "${file}.bak"
    done
    
    # Environment-specific resource adjustments
    case $env in
        development)
            # Reduce replicas and resources for development
            find "$temp_dir/deployments" -name "*.yaml" -type f | while read -r file; do
                sed -i.bak 's/replicas: [0-9]*/replicas: 1/g' "$file"
                sed -i.bak 's/cpu: [0-9]*m/cpu: 100m/g' "$file"
                sed -i.bak 's/memory: [0-9]*Mi/memory: 128Mi/g' "$file"
                rm -f "${file}.bak"
            done
            
            # Disable HPA for development
            rm -f "$temp_dir/autoscaling"/*.yaml
            ;;
        staging)
            # Moderate resources for staging
            find "$temp_dir/deployments" -name "*.yaml" -type f | while read -r file; do
                sed -i.bak 's/replicas: 1$/replicas: 2/g' "$file"
                rm -f "${file}.bak"
            done
            ;;
        production)
            # Ensure high availability for production
            find "$temp_dir/deployments" -name "*.yaml" -type f | while read -r file; do
                sed -i.bak 's/replicas: [12]$/replicas: 3/g' "$file"
                rm -f "${file}.bak"
            done
            ;;
    esac
    
    echo "$temp_dir"
}

# Deploy configuration only
deploy_config_only() {
    local env="$1"
    local namespace="$2"
    
    print_status "Deploying configuration for $env environment..."
    
    local kubectl_opts="--namespace=$namespace"
    if [ "$DRY_RUN" = true ]; then
        kubectl_opts="$kubectl_opts --dry-run=client"
        print_warning "Running in dry-run mode - no changes will be applied"
    fi
    
    # Create namespace if it doesn't exist
    if [ "$DRY_RUN" = false ]; then
        kubectl create namespace "$namespace" --dry-run=client -o yaml | kubectl apply -f -
        print_status "Namespace $namespace created or already exists"
    fi
    
    # Create environment-specific configuration
    create_environment_config "$env" "$namespace"
    
    # Apply configuration
    local config_file="$K8S_DIR/config/environments/${env}.yaml"
    kubectl apply $kubectl_opts -f "$config_file"
    
    print_status "Configuration deployment completed"
}

# Full deployment
deploy_full() {
    local env="$1"
    local namespace="$2"
    
    print_status "Starting full deployment for $env environment..."
    
    # Update manifests for environment
    local manifest_dir=$(update_deployment_manifests "$env" "$namespace")
    
    local kubectl_opts="--namespace=$namespace"
    if [ "$DRY_RUN" = true ]; then
        kubectl_opts="$kubectl_opts --dry-run=client"
        print_warning "Running in dry-run mode - no changes will be applied"
    fi
    
    # Create namespace if it doesn't exist
    if [ "$DRY_RUN" = false ]; then
        kubectl create namespace "$namespace" --dry-run=client -o yaml | kubectl apply -f -
        print_status "Namespace $namespace created or already exists"
    fi
    
    # Create and apply environment-specific configuration
    create_environment_config "$env" "$namespace"
    local config_file="$K8S_DIR/config/environments/${env}.yaml"
    kubectl apply $kubectl_opts -f "$config_file"
    
    # Deploy in correct order
    print_status "Deploying Services..."
    kubectl apply $kubectl_opts -f "$manifest_dir/services/"
    
    print_status "Deploying Deployments..."
    kubectl apply $kubectl_opts -f "$manifest_dir/deployments/"
    
    print_status "Deploying Ingress..."
    kubectl apply $kubectl_opts -f "$manifest_dir/ingress/"
    
    # Deploy HPA only for staging and production
    if [ "$env" != "development" ] && [ -d "$manifest_dir/autoscaling" ]; then
        print_status "Deploying HorizontalPodAutoscalers..."
        kubectl apply $kubectl_opts -f "$manifest_dir/autoscaling/"
    fi
    
    # Clean up temp directory
    rm -rf "$manifest_dir"
    
    if [ "$DRY_RUN" = false ]; then
        print_status "Waiting for deployments to be ready..."
        
        # Wait for deployments with environment-appropriate timeout
        local timeout=300
        case $env in
            development) timeout=180 ;;
            staging) timeout=300 ;;
            production) timeout=600 ;;
        esac
        
        local deployments=("websocket-service" "user-frontend-service" "admin-frontend-service")
        
        for deployment in "${deployments[@]}"; do
            if kubectl get deployment "$deployment" $kubectl_opts &> /dev/null; then
                kubectl wait --for=condition=available --timeout="${timeout}s" "deployment/$deployment" $kubectl_opts
            fi
        done
        
        print_status "Deployment completed successfully!"
        
        # Show deployment status
        echo ""
        print_status "Deployment Status:"
        kubectl get pods,services,ingress $kubectl_opts
        
        if [ "$env" != "development" ]; then
            kubectl get hpa $kubectl_opts 2>/dev/null || true
        fi
        
    else
        print_status "Dry run completed successfully!"
    fi
}

# Main execution
main() {
    print_status "Environment-specific deployment starting..."
    print_status "Environment: $ENVIRONMENT"
    print_status "Namespace: $NAMESPACE"
    print_status "Config Only: $CONFIG_ONLY"
    print_status "Dry Run: $DRY_RUN"
    
    echo ""
    get_environment_config "$ENVIRONMENT"
    echo ""
    
    # Check prerequisites
    if ! command -v kubectl &> /dev/null; then
        print_error "kubectl is not installed or not in PATH"
        exit 1
    fi
    
    if ! kubectl cluster-info &> /dev/null; then
        print_error "Cannot connect to Kubernetes cluster"
        exit 1
    fi
    
    # Deploy based on mode
    if [ "$CONFIG_ONLY" = true ]; then
        deploy_config_only "$ENVIRONMENT" "$NAMESPACE"
    else
        deploy_full "$ENVIRONMENT" "$NAMESPACE"
    fi
    
    print_status "Environment-specific deployment completed!"
    
    # Show next steps
    echo ""
    print_status "Next Steps:"
    echo "  1. Validate deployment: $SCRIPT_DIR/validate-deployment.sh -n $NAMESPACE"
    echo "  2. Check logs: kubectl logs -f deployment/websocket-service -n $NAMESPACE"
    echo "  3. Port forward for testing: kubectl port-forward service/websocket-service 8080:8080 -n $NAMESPACE"
    
    if [ "$ENVIRONMENT" = "production" ]; then
        echo ""
        print_warning "Production Deployment Notes:"
        echo "  - Monitor application metrics and logs"
        echo "  - Verify external access through ingress"
        echo "  - Check auto-scaling behavior under load"
        echo "  - Ensure backup and disaster recovery procedures are in place"
    fi
}

# Run main function
main "$@"