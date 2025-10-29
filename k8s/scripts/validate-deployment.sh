#!/bin/bash

# Kubernetes Deployment Validation Script
# This script validates the health and functionality of the deployed application

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Default values
NAMESPACE="default"
TIMEOUT=300
VERBOSE=false
CHECK_CONNECTIVITY=true
CHECK_PERFORMANCE=false

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
    if [ "$VERBOSE" = true ]; then
        echo -e "${BLUE}[DEBUG]${NC} $1"
    fi
}

# Function to show usage
usage() {
    echo "Usage: $0 [OPTIONS]"
    echo ""
    echo "Validate Kubernetes deployment health and functionality"
    echo ""
    echo "Options:"
    echo "  -n, --namespace NAMESPACE    Kubernetes namespace (default: default)"
    echo "  -t, --timeout SECONDS        Validation timeout in seconds (default: 300)"
    echo "  -v, --verbose               Enable verbose output"
    echo "  --no-connectivity           Skip connectivity tests"
    echo "  --performance               Include performance tests"
    echo "  -h, --help                  Show this help message"
    echo ""
    echo "Examples:"
    echo "  $0                          # Validate deployment in default namespace"
    echo "  $0 -n staging -v            # Validate staging deployment with verbose output"
    echo "  $0 --performance            # Include performance validation"
    exit 1
}

# Parse command line arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        -n|--namespace)
            NAMESPACE="$2"
            shift 2
            ;;
        -t|--timeout)
            TIMEOUT="$2"
            shift 2
            ;;
        -v|--verbose)
            VERBOSE=true
            shift
            ;;
        --no-connectivity)
            CHECK_CONNECTIVITY=false
            shift
            ;;
        --performance)
            CHECK_PERFORMANCE=true
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

# Validation results
VALIDATION_RESULTS=()
FAILED_CHECKS=0
TOTAL_CHECKS=0

# Function to record validation result
record_result() {
    local check_name="$1"
    local status="$2"
    local message="$3"
    
    TOTAL_CHECKS=$((TOTAL_CHECKS + 1))
    
    if [ "$status" = "PASS" ]; then
        print_success "$check_name: $message"
        VALIDATION_RESULTS+=("✓ $check_name: $message")
    elif [ "$status" = "FAIL" ]; then
        print_error "$check_name: $message"
        VALIDATION_RESULTS+=("✗ $check_name: $message")
        FAILED_CHECKS=$((FAILED_CHECKS + 1))
    else
        print_warning "$check_name: $message"
        VALIDATION_RESULTS+=("⚠ $check_name: $message")
    fi
}

# Check prerequisites
check_prerequisites() {
    print_status "Checking prerequisites..."
    
    # Check if kubectl is available
    if ! command -v kubectl &> /dev/null; then
        record_result "Prerequisites" "FAIL" "kubectl is not installed or not in PATH"
        return 1
    fi
    
    # Check kubectl connection
    if ! kubectl cluster-info &> /dev/null; then
        record_result "Prerequisites" "FAIL" "Cannot connect to Kubernetes cluster"
        return 1
    fi
    
    # Check if namespace exists
    if ! kubectl get namespace "$NAMESPACE" &> /dev/null; then
        record_result "Prerequisites" "FAIL" "Namespace '$NAMESPACE' does not exist"
        return 1
    fi
    
    record_result "Prerequisites" "PASS" "All prerequisites met"
    return 0
}

# Validate deployments
validate_deployments() {
    print_status "Validating deployments..."
    
    local kubectl_opts="--namespace=$NAMESPACE"
    local deployments=("websocket-service" "user-frontend-service" "admin-frontend-service")
    
    for deployment in "${deployments[@]}"; do
        print_debug "Checking deployment: $deployment"
        
        # Check if deployment exists
        if ! kubectl get deployment "$deployment" $kubectl_opts &> /dev/null; then
            record_result "Deployment $deployment" "FAIL" "Deployment does not exist"
            continue
        fi
        
        # Check deployment status
        local ready_replicas=$(kubectl get deployment "$deployment" $kubectl_opts -o jsonpath='{.status.readyReplicas}' 2>/dev/null || echo "0")
        local desired_replicas=$(kubectl get deployment "$deployment" $kubectl_opts -o jsonpath='{.spec.replicas}' 2>/dev/null || echo "0")
        
        if [ "$ready_replicas" = "$desired_replicas" ] && [ "$ready_replicas" != "0" ]; then
            record_result "Deployment $deployment" "PASS" "$ready_replicas/$desired_replicas replicas ready"
        else
            record_result "Deployment $deployment" "FAIL" "$ready_replicas/$desired_replicas replicas ready"
        fi
    done
    
    # Check Redis deployment if it exists
    if kubectl get deployment redis-service $kubectl_opts &> /dev/null; then
        local ready_replicas=$(kubectl get deployment redis-service $kubectl_opts -o jsonpath='{.status.readyReplicas}' 2>/dev/null || echo "0")
        local desired_replicas=$(kubectl get deployment redis-service $kubectl_opts -o jsonpath='{.spec.replicas}' 2>/dev/null || echo "0")
        
        if [ "$ready_replicas" = "$desired_replicas" ] && [ "$ready_replicas" != "0" ]; then
            record_result "Deployment redis-service" "PASS" "$ready_replicas/$desired_replicas replicas ready"
        else
            record_result "Deployment redis-service" "WARN" "$ready_replicas/$desired_replicas replicas ready (optional service)"
        fi
    fi
}

# Validate services
validate_services() {
    print_status "Validating services..."
    
    local kubectl_opts="--namespace=$NAMESPACE"
    local services=("websocket-service" "user-frontend-service" "admin-frontend-service")
    
    for service in "${services[@]}"; do
        print_debug "Checking service: $service"
        
        # Check if service exists
        if ! kubectl get service "$service" $kubectl_opts &> /dev/null; then
            record_result "Service $service" "FAIL" "Service does not exist"
            continue
        fi
        
        # Check service endpoints
        local endpoints=$(kubectl get endpoints "$service" $kubectl_opts -o jsonpath='{.subsets[*].addresses[*].ip}' 2>/dev/null | wc -w)
        
        if [ "$endpoints" -gt 0 ]; then
            record_result "Service $service" "PASS" "$endpoints endpoint(s) available"
        else
            record_result "Service $service" "FAIL" "No endpoints available"
        fi
    done
    
    # Check Redis service if it exists
    if kubectl get service redis-service $kubectl_opts &> /dev/null; then
        local endpoints=$(kubectl get endpoints redis-service $kubectl_opts -o jsonpath='{.subsets[*].addresses[*].ip}' 2>/dev/null | wc -w)
        
        if [ "$endpoints" -gt 0 ]; then
            record_result "Service redis-service" "PASS" "$endpoints endpoint(s) available"
        else
            record_result "Service redis-service" "WARN" "No endpoints available (optional service)"
        fi
    fi
}

# Validate pods
validate_pods() {
    print_status "Validating pods..."
    
    local kubectl_opts="--namespace=$NAMESPACE"
    
    # Get all pods
    local pods=$(kubectl get pods $kubectl_opts -o jsonpath='{.items[*].metadata.name}' 2>/dev/null)
    
    if [ -z "$pods" ]; then
        record_result "Pods" "FAIL" "No pods found in namespace"
        return
    fi
    
    local total_pods=0
    local running_pods=0
    local ready_pods=0
    
    for pod in $pods; do
        total_pods=$((total_pods + 1))
        
        local phase=$(kubectl get pod "$pod" $kubectl_opts -o jsonpath='{.status.phase}' 2>/dev/null)
        local ready=$(kubectl get pod "$pod" $kubectl_opts -o jsonpath='{.status.conditions[?(@.type=="Ready")].status}' 2>/dev/null)
        
        print_debug "Pod $pod: phase=$phase, ready=$ready"
        
        if [ "$phase" = "Running" ]; then
            running_pods=$((running_pods + 1))
        fi
        
        if [ "$ready" = "True" ]; then
            ready_pods=$((ready_pods + 1))
        fi
        
        # Check for pod issues
        if [ "$phase" != "Running" ] || [ "$ready" != "True" ]; then
            local reason=$(kubectl get pod "$pod" $kubectl_opts -o jsonpath='{.status.conditions[?(@.type=="Ready")].reason}' 2>/dev/null)
            record_result "Pod $pod" "FAIL" "Phase: $phase, Ready: $ready, Reason: $reason"
        fi
    done
    
    if [ "$running_pods" = "$total_pods" ] && [ "$ready_pods" = "$total_pods" ]; then
        record_result "Pods" "PASS" "$ready_pods/$total_pods pods running and ready"
    else
        record_result "Pods" "FAIL" "$running_pods/$total_pods running, $ready_pods/$total_pods ready"
    fi
}

# Validate ingress
validate_ingress() {
    print_status "Validating ingress..."
    
    local kubectl_opts="--namespace=$NAMESPACE"
    
    # Check if ingress exists
    if ! kubectl get ingress $kubectl_opts &> /dev/null; then
        record_result "Ingress" "WARN" "No ingress resources found"
        return
    fi
    
    local ingresses=$(kubectl get ingress $kubectl_opts -o jsonpath='{.items[*].metadata.name}' 2>/dev/null)
    
    for ingress in $ingresses; do
        print_debug "Checking ingress: $ingress"
        
        # Check ingress status
        local hosts=$(kubectl get ingress "$ingress" $kubectl_opts -o jsonpath='{.spec.rules[*].host}' 2>/dev/null)
        local addresses=$(kubectl get ingress "$ingress" $kubectl_opts -o jsonpath='{.status.loadBalancer.ingress[*].ip}' 2>/dev/null)
        
        if [ -n "$addresses" ]; then
            record_result "Ingress $ingress" "PASS" "Load balancer assigned: $addresses"
        elif [ -n "$hosts" ]; then
            record_result "Ingress $ingress" "WARN" "Configured for hosts: $hosts (no load balancer IP yet)"
        else
            record_result "Ingress $ingress" "FAIL" "No hosts or addresses configured"
        fi
    done
}

# Validate HPA
validate_hpa() {
    print_status "Validating HorizontalPodAutoscalers..."
    
    local kubectl_opts="--namespace=$NAMESPACE"
    
    # Check if HPA exists
    if ! kubectl get hpa $kubectl_opts &> /dev/null; then
        record_result "HPA" "WARN" "No HPA resources found"
        return
    fi
    
    local hpas=$(kubectl get hpa $kubectl_opts -o jsonpath='{.items[*].metadata.name}' 2>/dev/null)
    
    for hpa in $hpas; do
        print_debug "Checking HPA: $hpa"
        
        # Check HPA status
        local current_replicas=$(kubectl get hpa "$hpa" $kubectl_opts -o jsonpath='{.status.currentReplicas}' 2>/dev/null)
        local desired_replicas=$(kubectl get hpa "$hpa" $kubectl_opts -o jsonpath='{.status.desiredReplicas}' 2>/dev/null)
        local target_ref=$(kubectl get hpa "$hpa" $kubectl_opts -o jsonpath='{.spec.scaleTargetRef.name}' 2>/dev/null)
        
        if [ -n "$current_replicas" ] && [ -n "$desired_replicas" ]; then
            record_result "HPA $hpa" "PASS" "Scaling $target_ref: $current_replicas/$desired_replicas replicas"
        else
            record_result "HPA $hpa" "WARN" "HPA metrics not available yet"
        fi
    done
}

# Health check validation
validate_health_checks() {
    print_status "Validating health checks..."
    
    local kubectl_opts="--namespace=$NAMESPACE"
    
    # Get WebSocket service pod for health checks
    local ws_pods=$(kubectl get pods -l app=websocket-service $kubectl_opts -o jsonpath='{.items[*].metadata.name}' 2>/dev/null)
    
    if [ -z "$ws_pods" ]; then
        record_result "Health Checks" "FAIL" "No WebSocket service pods found"
        return
    fi
    
    for pod in $ws_pods; do
        print_debug "Checking health endpoints for pod: $pod"
        
        # Check health endpoint
        if kubectl exec "$pod" $kubectl_opts -- curl -f -s http://localhost:8081/health &> /dev/null; then
            record_result "Health Check $pod" "PASS" "Health endpoint responding"
        else
            record_result "Health Check $pod" "FAIL" "Health endpoint not responding"
        fi
        
        # Check readiness endpoint
        if kubectl exec "$pod" $kubectl_opts -- curl -f -s http://localhost:8081/ready &> /dev/null; then
            record_result "Readiness Check $pod" "PASS" "Readiness endpoint responding"
        else
            record_result "Readiness Check $pod" "FAIL" "Readiness endpoint not responding"
        fi
    done
}

# Connectivity validation
validate_connectivity() {
    if [ "$CHECK_CONNECTIVITY" = false ]; then
        print_status "Skipping connectivity tests as requested"
        return
    fi
    
    print_status "Validating connectivity..."
    
    local kubectl_opts="--namespace=$NAMESPACE"
    
    # Test internal service connectivity
    local ws_pods=$(kubectl get pods -l app=websocket-service $kubectl_opts -o jsonpath='{.items[0].metadata.name}' 2>/dev/null)
    
    if [ -n "$ws_pods" ]; then
        # Test Redis connectivity (if Redis is deployed)
        if kubectl get service redis-service $kubectl_opts &> /dev/null; then
            local redis_host="redis-service.${NAMESPACE}.svc.cluster.local"
            if kubectl exec "$ws_pods" $kubectl_opts -- nc -z "$redis_host" 6379 &> /dev/null; then
                record_result "Redis Connectivity" "PASS" "WebSocket can connect to Redis"
            else
                record_result "Redis Connectivity" "FAIL" "WebSocket cannot connect to Redis"
            fi
        fi
        
        # Test service discovery
        if kubectl exec "$ws_pods" $kubectl_opts -- nslookup "user-frontend-service.${NAMESPACE}.svc.cluster.local" &> /dev/null; then
            record_result "Service Discovery" "PASS" "DNS resolution working"
        else
            record_result "Service Discovery" "FAIL" "DNS resolution not working"
        fi
    fi
}

# Performance validation
validate_performance() {
    if [ "$CHECK_PERFORMANCE" = false ]; then
        print_status "Skipping performance tests as requested"
        return
    fi
    
    print_status "Validating performance..."
    
    local kubectl_opts="--namespace=$NAMESPACE"
    
    # Check resource usage
    if command -v kubectl &> /dev/null && kubectl top pods $kubectl_opts &> /dev/null; then
        local high_cpu_pods=$(kubectl top pods $kubectl_opts --no-headers | awk '$2 ~ /[0-9]+m/ && $2+0 > 500 {print $1}')
        local high_mem_pods=$(kubectl top pods $kubectl_opts --no-headers | awk '$3 ~ /[0-9]+Mi/ && $3+0 > 512 {print $1}')
        
        if [ -z "$high_cpu_pods" ] && [ -z "$high_mem_pods" ]; then
            record_result "Resource Usage" "PASS" "All pods within resource limits"
        else
            record_result "Resource Usage" "WARN" "Some pods using high resources: CPU($high_cpu_pods) MEM($high_mem_pods)"
        fi
    else
        record_result "Resource Usage" "WARN" "Metrics server not available"
    fi
    
    # Check response times (basic test)
    local ws_pods=$(kubectl get pods -l app=websocket-service $kubectl_opts -o jsonpath='{.items[0].metadata.name}' 2>/dev/null)
    
    if [ -n "$ws_pods" ]; then
        local response_time=$(kubectl exec "$ws_pods" $kubectl_opts -- time curl -f -s http://localhost:8081/health 2>&1 | grep real | awk '{print $2}' || echo "unknown")
        if [[ "$response_time" =~ ^0m0\.[0-9]+s$ ]]; then
            record_result "Response Time" "PASS" "Health endpoint responds in $response_time"
        else
            record_result "Response Time" "WARN" "Health endpoint response time: $response_time"
        fi
    fi
}

# Show validation summary
show_summary() {
    echo ""
    print_status "Validation Summary"
    echo "=================="
    
    for result in "${VALIDATION_RESULTS[@]}"; do
        echo "$result"
    done
    
    echo ""
    echo "Total Checks: $TOTAL_CHECKS"
    echo "Failed Checks: $FAILED_CHECKS"
    echo "Success Rate: $(( (TOTAL_CHECKS - FAILED_CHECKS) * 100 / TOTAL_CHECKS ))%"
    
    if [ "$FAILED_CHECKS" -eq 0 ]; then
        print_success "All validation checks passed!"
        return 0
    else
        print_error "$FAILED_CHECKS validation check(s) failed"
        return 1
    fi
}

# Main execution
main() {
    print_status "Starting Kubernetes deployment validation..."
    print_status "Namespace: $NAMESPACE"
    print_status "Timeout: ${TIMEOUT}s"
    print_status "Verbose: $VERBOSE"
    print_status "Check Connectivity: $CHECK_CONNECTIVITY"
    print_status "Check Performance: $CHECK_PERFORMANCE"
    
    echo ""
    
    # Run validation checks
    check_prerequisites || exit 1
    validate_deployments
    validate_services
    validate_pods
    validate_ingress
    validate_hpa
    validate_health_checks
    validate_connectivity
    validate_performance
    
    # Show summary and exit with appropriate code
    show_summary
}

# Run main function
main "$@"