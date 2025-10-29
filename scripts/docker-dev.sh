#!/bin/bash

# Docker development helper script
# Provides convenient commands for local development with Docker

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Logging functions
log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Function to show usage
show_usage() {
    echo "Usage: $0 COMMAND [OPTIONS]"
    echo ""
    echo "Docker development helper for user-admin-messaging application"
    echo ""
    echo "Commands:"
    echo "  up              Start all services"
    echo "  down            Stop all services"
    echo "  restart         Restart all services"
    echo "  build           Build all images"
    echo "  logs [SERVICE]  Show logs for all services or specific service"
    echo "  shell SERVICE   Open shell in running service container"
    echo "  clean           Remove all containers, images, and volumes"
    echo "  status          Show status of all services"
    echo "  test            Run tests in containers"
    echo ""
    echo "Services:"
    echo "  websocket, user-frontend, admin-frontend, redis, nginx"
    echo ""
    echo "Examples:"
    echo "  $0 up                    # Start all services"
    echo "  $0 logs websocket        # Show WebSocket service logs"
    echo "  $0 shell websocket       # Open shell in WebSocket container"
    echo "  $0 build                 # Build all images"
}

# Check if Docker and docker-compose are available
check_dependencies() {
    if ! command -v docker &> /dev/null; then
        log_error "Docker is not installed or not in PATH"
        exit 1
    fi

    if ! command -v docker-compose &> /dev/null; then
        log_error "docker-compose is not installed or not in PATH"
        exit 1
    fi
}

# Check if we're in the project root
check_project_root() {
    if [ ! -f "docker-compose.yml" ]; then
        log_error "This script must be run from the project root directory"
        exit 1
    fi
}

# Start services
cmd_up() {
    log_info "Starting all services..."
    docker-compose up -d
    log_success "All services started"
    
    log_info "Waiting for services to be healthy..."
    sleep 10
    
    log_info "Service status:"
    docker-compose ps
    
    log_info "Application URLs:"
    echo "  User Interface:  http://localhost/user/"
    echo "  Admin Interface: http://localhost/admin/"
    echo "  WebSocket:       ws://localhost/ws"
    echo "  Health Check:    http://localhost/health"
}

# Stop services
cmd_down() {
    log_info "Stopping all services..."
    docker-compose down
    log_success "All services stopped"
}

# Restart services
cmd_restart() {
    log_info "Restarting all services..."
    docker-compose restart
    log_success "All services restarted"
}

# Build images
cmd_build() {
    log_info "Building all images..."
    docker-compose build --no-cache
    log_success "All images built"
}

# Show logs
cmd_logs() {
    local service=$1
    if [ -n "$service" ]; then
        log_info "Showing logs for $service..."
        docker-compose logs -f "$service"
    else
        log_info "Showing logs for all services..."
        docker-compose logs -f
    fi
}

# Open shell in container
cmd_shell() {
    local service=$1
    if [ -z "$service" ]; then
        log_error "Service name is required for shell command"
        echo "Available services: websocket, user-frontend, admin-frontend, redis, nginx"
        exit 1
    fi
    
    log_info "Opening shell in $service container..."
    docker-compose exec "$service" /bin/sh
}

# Clean up everything
cmd_clean() {
    log_warning "This will remove all containers, images, and volumes. Are you sure? (y/N)"
    read -r response
    if [[ "$response" =~ ^[Yy]$ ]]; then
        log_info "Stopping and removing all containers..."
        docker-compose down -v --remove-orphans
        
        log_info "Removing images..."
        docker images "user-admin-messaging/*" -q | xargs -r docker rmi -f
        
        log_info "Removing unused volumes..."
        docker volume prune -f
        
        log_success "Cleanup completed"
    else
        log_info "Cleanup cancelled"
    fi
}

# Show service status
cmd_status() {
    log_info "Service status:"
    docker-compose ps
    
    echo ""
    log_info "Container resource usage:"
    docker stats --no-stream --format "table {{.Container}}\t{{.CPUPerc}}\t{{.MemUsage}}\t{{.NetIO}}"
}

# Run tests
cmd_test() {
    log_info "Running tests in containers..."
    
    # Test WebSocket service
    log_info "Testing WebSocket service..."
    docker-compose exec -T websocket npm test
    
    # Test frontend services (if they have tests)
    log_info "Testing user frontend..."
    docker-compose exec -T user-frontend npm test || log_warning "User frontend tests not available"
    
    log_info "Testing admin frontend..."
    docker-compose exec -T admin-frontend npm test || log_warning "Admin frontend tests not available"
    
    log_success "Tests completed"
}

# Main script logic
main() {
    check_dependencies
    check_project_root
    
    local command=$1
    shift
    
    case $command in
        up)
            cmd_up "$@"
            ;;
        down)
            cmd_down "$@"
            ;;
        restart)
            cmd_restart "$@"
            ;;
        build)
            cmd_build "$@"
            ;;
        logs)
            cmd_logs "$@"
            ;;
        shell)
            cmd_shell "$@"
            ;;
        clean)
            cmd_clean "$@"
            ;;
        status)
            cmd_status "$@"
            ;;
        test)
            cmd_test "$@"
            ;;
        -h|--help|help)
            show_usage
            ;;
        *)
            log_error "Unknown command: $command"
            show_usage
            exit 1
            ;;
    esac
}

# Run main function with all arguments
main "$@"