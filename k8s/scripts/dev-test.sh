#!/bin/bash

# Local Development Testing and Debugging Script
# This script provides testing and debugging utilities for local Kubernetes deployment

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Default values
NAMESPACE="dev"
TEST_TYPE="all"
VERBOSE=false
INTERACTIVE=false

# Get script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

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
    echo "Usage: $0 [OPTIONS] [TEST_TYPE]"
    echo ""
    echo "Test and debug local Kubernetes deployment"
    echo ""
    echo "Test Types:"
    echo "  all                         Run all tests (default)"
    echo "  connectivity                Test service connectivity"
    echo "  health                      Test health endpoints"
    echo "  websocket                   Test WebSocket functionality"
    echo "  frontend                    Test frontend services"
    echo "  redis                       Test Redis connectivity"
    echo "  logs                        Show and analyze logs"
    echo "  debug                       Interactive debugging session"
    echo ""
    echo "Options:"
    echo "  -n, --namespace NAMESPACE   Kubernetes namespace (default: dev)"
    echo "  -v, --verbose              Enable verbose output"
    echo "  -i, --interactive          Interactive mode for debugging"
    echo "  -h, --help                 Show this help message"
    echo ""
    echo "Examples:"
    echo "  $0                         # Run all tests"
    echo "  $0 websocket -v            # Test WebSocket with verbose output"
    echo "  $0 debug -i                # Interactive debugging session"
    echo "  $0 logs -n staging         # Analyze logs in staging namespace"
    exit 1
}

# Parse command line arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        -n|--namespace)
            NAMESPACE="$2"
            shift 2
            ;;
        -v|--verbose)
            VERBOSE=true
            shift
            ;;
        -i|--interactive)
            INTERACTIVE=true
            shift
            ;;
        -h|--help)
            usage
            ;;
        all|connectivity|health|websocket|frontend|redis|logs|debug)
            TEST_TYPE="$1"
            shift
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

# Test service connectivity
test_connectivity() {
    print_status "Testing service connectivity..."
    
    local kubectl_opts="--namespace=$NAMESPACE"
    local test_results=()
    
    # Get a WebSocket pod for testing
    local ws_pod=$(kubectl get pods -l app=websocket-service $kubectl_opts -o jsonpath='{.items[0].metadata.name}' 2>/dev/null)
    
    if [ -z "$ws_pod" ]; then
        print_error "No WebSocket service pods found"
        return 1
    fi
    
    print_debug "Using pod $ws_pod for connectivity tests"
    
    # Test Redis connectivity
    print_status "Testing Redis connectivity..."
    if kubectl exec "$ws_pod" $kubectl_opts -- nc -z redis-service 6379 &> /dev/null; then
        print_success "✓ Redis connectivity: OK"
        test_results+=("PASS: Redis connectivity")
    else
        print_error "✗ Redis connectivity: FAILED"
        test_results+=("FAIL: Redis connectivity")
    fi
    
    # Test service discovery
    print_status "Testing service discovery..."
    local services=("user-frontend-service" "admin-frontend-service" "redis-service")
    
    for service in "${services[@]}"; do
        if kubectl exec "$ws_pod" $kubectl_opts -- nslookup "$service" &> /dev/null; then
            print_success "✓ Service discovery ($service): OK"
            test_results+=("PASS: Service discovery ($service)")
        else
            print_error "✗ Service discovery ($service): FAILED"
            test_results+=("FAIL: Service discovery ($service)")
        fi
    done
    
    # Test internal HTTP connectivity
    print_status "Testing internal HTTP connectivity..."
    if kubectl exec "$ws_pod" $kubectl_opts -- curl -f -s http://user-frontend-service &> /dev/null; then
        print_success "✓ User frontend HTTP: OK"
        test_results+=("PASS: User frontend HTTP")
    else
        print_error "✗ User frontend HTTP: FAILED"
        test_results+=("FAIL: User frontend HTTP")
    fi
    
    if kubectl exec "$ws_pod" $kubectl_opts -- curl -f -s http://admin-frontend-service &> /dev/null; then
        print_success "✓ Admin frontend HTTP: OK"
        test_results+=("PASS: Admin frontend HTTP")
    else
        print_error "✗ Admin frontend HTTP: FAILED"
        test_results+=("FAIL: Admin frontend HTTP")
    fi
    
    # Show summary
    echo ""
    print_status "Connectivity Test Summary:"
    for result in "${test_results[@]}"; do
        echo "  $result"
    done
}

# Test health endpoints
test_health() {
    print_status "Testing health endpoints..."
    
    local kubectl_opts="--namespace=$NAMESPACE"
    local test_results=()
    
    # Get WebSocket pods
    local ws_pods=$(kubectl get pods -l app=websocket-service $kubectl_opts -o jsonpath='{.items[*].metadata.name}' 2>/dev/null)
    
    if [ -z "$ws_pods" ]; then
        print_error "No WebSocket service pods found"
        return 1
    fi
    
    for pod in $ws_pods; do
        print_debug "Testing health endpoints for pod: $pod"
        
        # Test health endpoint
        if kubectl exec "$pod" $kubectl_opts -- curl -f -s http://localhost:8081/health &> /dev/null; then
            local health_response=$(kubectl exec "$pod" $kubectl_opts -- curl -s http://localhost:8081/health 2>/dev/null)
            print_success "✓ Health endpoint ($pod): OK"
            print_debug "Health response: $health_response"
            test_results+=("PASS: Health endpoint ($pod)")
        else
            print_error "✗ Health endpoint ($pod): FAILED"
            test_results+=("FAIL: Health endpoint ($pod)")
        fi
        
        # Test readiness endpoint
        if kubectl exec "$pod" $kubectl_opts -- curl -f -s http://localhost:8081/ready &> /dev/null; then
            local ready_response=$(kubectl exec "$pod" $kubectl_opts -- curl -s http://localhost:8081/ready 2>/dev/null)
            print_success "✓ Readiness endpoint ($pod): OK"
            print_debug "Readiness response: $ready_response"
            test_results+=("PASS: Readiness endpoint ($pod)")
        else
            print_error "✗ Readiness endpoint ($pod): FAILED"
            test_results+=("FAIL: Readiness endpoint ($pod)")
        fi
    done
    
    # Show summary
    echo ""
    print_status "Health Test Summary:"
    for result in "${test_results[@]}"; do
        echo "  $result"
    done
}

# Test WebSocket functionality
test_websocket() {
    print_status "Testing WebSocket functionality..."
    
    local kubectl_opts="--namespace=$NAMESPACE"
    
    # Create a simple WebSocket test script
    local test_script=$(mktemp)
    cat > "$test_script" << 'EOF'
const WebSocket = require('ws');

const ws = new WebSocket('ws://localhost:8080');

ws.on('open', function open() {
    console.log('WebSocket connection opened');
    
    // Send a test message
    ws.send(JSON.stringify({
        type: 'test',
        message: 'Hello from test client'
    }));
    
    setTimeout(() => {
        ws.close();
        console.log('WebSocket test completed successfully');
        process.exit(0);
    }, 2000);
});

ws.on('message', function message(data) {
    console.log('Received:', data.toString());
});

ws.on('error', function error(err) {
    console.error('WebSocket error:', err.message);
    process.exit(1);
});

ws.on('close', function close() {
    console.log('WebSocket connection closed');
});

// Timeout after 10 seconds
setTimeout(() => {
    console.error('WebSocket test timeout');
    process.exit(1);
}, 10000);
EOF
    
    # Port forward WebSocket service
    print_status "Setting up port forward for WebSocket testing..."
    kubectl port-forward service/websocket-service 8080:8080 $kubectl_opts &
    local pf_pid=$!
    
    # Wait for port forward to be ready
    sleep 3
    
    # Run WebSocket test
    print_status "Running WebSocket test..."
    if cd "$PROJECT_ROOT" && node "$test_script" 2>&1; then
        print_success "✓ WebSocket functionality: OK"
    else
        print_error "✗ WebSocket functionality: FAILED"
    fi
    
    # Clean up
    kill $pf_pid 2>/dev/null || true
    rm -f "$test_script"
}

# Test frontend services
test_frontend() {
    print_status "Testing frontend services..."
    
    local kubectl_opts="--namespace=$NAMESPACE"
    local test_results=()
    
    # Test user frontend
    print_status "Testing user frontend service..."
    kubectl port-forward service/user-frontend-service 3000:80 $kubectl_opts &
    local user_pf_pid=$!
    sleep 2
    
    if curl -f -s http://localhost:3000 &> /dev/null; then
        print_success "✓ User frontend service: OK"
        test_results+=("PASS: User frontend service")
    else
        print_error "✗ User frontend service: FAILED"
        test_results+=("FAIL: User frontend service")
    fi
    
    kill $user_pf_pid 2>/dev/null || true
    
    # Test admin frontend
    print_status "Testing admin frontend service..."
    kubectl port-forward service/admin-frontend-service 3001:80 $kubectl_opts &
    local admin_pf_pid=$!
    sleep 2
    
    if curl -f -s http://localhost:3001 &> /dev/null; then
        print_success "✓ Admin frontend service: OK"
        test_results+=("PASS: Admin frontend service")
    else
        print_error "✗ Admin frontend service: FAILED"
        test_results+=("FAIL: Admin frontend service")
    fi
    
    kill $admin_pf_pid 2>/dev/null || true
    
    # Show summary
    echo ""
    print_status "Frontend Test Summary:"
    for result in "${test_results[@]}"; do
        echo "  $result"
    done
}

# Test Redis functionality
test_redis() {
    print_status "Testing Redis functionality..."
    
    local kubectl_opts="--namespace=$NAMESPACE"
    local test_results=()
    
    # Get Redis pod
    local redis_pod=$(kubectl get pods -l app=redis $kubectl_opts -o jsonpath='{.items[0].metadata.name}' 2>/dev/null)
    
    if [ -z "$redis_pod" ]; then
        print_error "No Redis pods found"
        return 1
    fi
    
    print_debug "Using Redis pod: $redis_pod"
    
    # Test Redis ping
    if kubectl exec "$redis_pod" $kubectl_opts -- redis-cli ping | grep -q "PONG"; then
        print_success "✓ Redis ping: OK"
        test_results+=("PASS: Redis ping")
    else
        print_error "✗ Redis ping: FAILED"
        test_results+=("FAIL: Redis ping")
    fi
    
    # Test Redis set/get
    local test_key="test:$(date +%s)"
    local test_value="test-value-$(date +%s)"
    
    if kubectl exec "$redis_pod" $kubectl_opts -- redis-cli set "$test_key" "$test_value" | grep -q "OK"; then
        print_success "✓ Redis SET: OK"
        test_results+=("PASS: Redis SET")
        
        local retrieved_value=$(kubectl exec "$redis_pod" $kubectl_opts -- redis-cli get "$test_key" 2>/dev/null)
        if [ "$retrieved_value" = "$test_value" ]; then
            print_success "✓ Redis GET: OK"
            test_results+=("PASS: Redis GET")
        else
            print_error "✗ Redis GET: FAILED (expected: $test_value, got: $retrieved_value)"
            test_results+=("FAIL: Redis GET")
        fi
        
        # Clean up test key
        kubectl exec "$redis_pod" $kubectl_opts -- redis-cli del "$test_key" &> /dev/null
    else
        print_error "✗ Redis SET: FAILED"
        test_results+=("FAIL: Redis SET")
    fi
    
    # Show Redis info
    if [ "$VERBOSE" = true ]; then
        print_debug "Redis info:"
        kubectl exec "$redis_pod" $kubectl_opts -- redis-cli info server | head -10
    fi
    
    # Show summary
    echo ""
    print_status "Redis Test Summary:"
    for result in "${test_results[@]}"; do
        echo "  $result"
    done
}

# Analyze logs
analyze_logs() {
    print_status "Analyzing application logs..."
    
    local kubectl_opts="--namespace=$NAMESPACE"
    
    # Get all pods
    local pods=$(kubectl get pods $kubectl_opts -o jsonpath='{.items[*].metadata.name}' 2>/dev/null)
    
    if [ -z "$pods" ]; then
        print_error "No pods found in namespace $NAMESPACE"
        return 1
    fi
    
    for pod in $pods; do
        echo ""
        print_status "Logs for pod: $pod"
        echo "================================"
        
        # Get recent logs
        local logs=$(kubectl logs "$pod" $kubectl_opts --tail=50 2>/dev/null || echo "No logs available")
        
        if [ "$logs" = "No logs available" ]; then
            print_warning "No logs available for $pod"
            continue
        fi
        
        # Analyze logs for errors
        local error_count=$(echo "$logs" | grep -i "error" | wc -l)
        local warning_count=$(echo "$logs" | grep -i "warning\|warn" | wc -l)
        
        print_status "Log analysis for $pod:"
        echo "  Total lines: $(echo "$logs" | wc -l)"
        echo "  Errors: $error_count"
        echo "  Warnings: $warning_count"
        
        if [ "$error_count" -gt 0 ]; then
            print_error "Recent errors in $pod:"
            echo "$logs" | grep -i "error" | tail -5
        fi
        
        if [ "$warning_count" -gt 0 ] && [ "$VERBOSE" = true ]; then
            print_warning "Recent warnings in $pod:"
            echo "$logs" | grep -i "warning\|warn" | tail -3
        fi
        
        if [ "$VERBOSE" = true ]; then
            echo ""
            print_debug "Recent logs from $pod:"
            echo "$logs" | tail -10
        fi
    done
}

# Interactive debugging session
interactive_debug() {
    print_status "Starting interactive debugging session..."
    
    local kubectl_opts="--namespace=$NAMESPACE"
    
    if [ "$INTERACTIVE" = false ]; then
        print_warning "Interactive mode not enabled. Use -i flag for full interactive experience."
    fi
    
    while true; do
        echo ""
        print_status "Debug Menu:"
        echo "  1. Show pod status"
        echo "  2. Show service status"
        echo "  3. Show recent logs"
        echo "  4. Shell into WebSocket pod"
        echo "  5. Shell into Redis pod"
        echo "  6. Port forward services"
        echo "  7. Run connectivity tests"
        echo "  8. Show resource usage"
        echo "  9. Describe problematic pods"
        echo "  0. Exit"
        echo ""
        
        if [ "$INTERACTIVE" = true ]; then
            read -p "Select option (0-9): " choice
        else
            # Non-interactive mode - show all info and exit
            choice="all"
        fi
        
        case $choice in
            1|all)
                print_status "Pod Status:"
                kubectl get pods $kubectl_opts -o wide
                if [ "$choice" != "all" ]; then continue; fi
                ;;
            2|all)
                print_status "Service Status:"
                kubectl get services $kubectl_opts
                kubectl get endpoints $kubectl_opts
                if [ "$choice" != "all" ]; then continue; fi
                ;;
            3|all)
                analyze_logs
                if [ "$choice" != "all" ]; then continue; fi
                ;;
            4)
                local ws_pod=$(kubectl get pods -l app=websocket-service $kubectl_opts -o jsonpath='{.items[0].metadata.name}' 2>/dev/null)
                if [ -n "$ws_pod" ]; then
                    print_status "Opening shell in WebSocket pod: $ws_pod"
                    kubectl exec -it "$ws_pod" $kubectl_opts -- /bin/sh
                else
                    print_error "No WebSocket pods found"
                fi
                ;;
            5)
                local redis_pod=$(kubectl get pods -l app=redis $kubectl_opts -o jsonpath='{.items[0].metadata.name}' 2>/dev/null)
                if [ -n "$redis_pod" ]; then
                    print_status "Opening shell in Redis pod: $redis_pod"
                    kubectl exec -it "$redis_pod" $kubectl_opts -- /bin/sh
                else
                    print_error "No Redis pods found"
                fi
                ;;
            6)
                print_status "Setting up port forwarding..."
                kubectl port-forward service/websocket-service 8080:8080 $kubectl_opts &
                kubectl port-forward service/user-frontend-service 3000:80 $kubectl_opts &
                kubectl port-forward service/admin-frontend-service 3001:80 $kubectl_opts &
                print_success "Port forwarding active. Press Ctrl+C to stop."
                wait
                ;;
            7|all)
                test_connectivity
                if [ "$choice" != "all" ]; then continue; fi
                ;;
            8|all)
                print_status "Resource Usage:"
                kubectl top pods $kubectl_opts 2>/dev/null || print_warning "Metrics server not available"
                if [ "$choice" != "all" ]; then continue; fi
                ;;
            9|all)
                print_status "Problematic Pods:"
                local problem_pods=$(kubectl get pods $kubectl_opts --no-headers | grep -v "Running\|Completed" | awk '{print $1}')
                if [ -n "$problem_pods" ]; then
                    for pod in $problem_pods; do
                        echo ""
                        print_warning "Describing pod: $pod"
                        kubectl describe pod "$pod" $kubectl_opts
                    done
                else
                    print_success "No problematic pods found"
                fi
                if [ "$choice" != "all" ]; then continue; fi
                ;;
            0)
                print_status "Exiting debug session"
                break
                ;;
            all)
                print_status "Debug information collected"
                break
                ;;
            *)
                print_error "Invalid option: $choice"
                ;;
        esac
    done
}

# Main execution
main() {
    print_status "Starting local development testing..."
    print_status "Configuration:"
    print_status "  Namespace: $NAMESPACE"
    print_status "  Test Type: $TEST_TYPE"
    print_status "  Verbose: $VERBOSE"
    print_status "  Interactive: $INTERACTIVE"
    
    check_prerequisites
    
    case $TEST_TYPE in
        all)
            test_connectivity
            test_health
            test_websocket
            test_frontend
            test_redis
            analyze_logs
            ;;
        connectivity)
            test_connectivity
            ;;
        health)
            test_health
            ;;
        websocket)
            test_websocket
            ;;
        frontend)
            test_frontend
            ;;
        redis)
            test_redis
            ;;
        logs)
            analyze_logs
            ;;
        debug)
            interactive_debug
            ;;
        *)
            print_error "Unknown test type: $TEST_TYPE"
            usage
            ;;
    esac
    
    print_success "Testing completed!"
}

# Run main function
main "$@"