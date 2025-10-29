#!/bin/bash

# Docker build script for user-admin-messaging application
# This script builds all Docker images with proper tagging

set -e

# Configuration
REGISTRY=${DOCKER_REGISTRY:-"user-admin-messaging"}
TAG=${DOCKER_TAG:-"latest"}
BUILD_DATE=$(date -u +'%Y-%m-%dT%H:%M:%SZ')
GIT_COMMIT=${GIT_COMMIT:-$(git rev-parse --short HEAD 2>/dev/null || echo "unknown")}

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

# Function to build Docker image
build_image() {
    local service_name=$1
    local dockerfile_path=$2
    local context_path=$3
    local image_name="${REGISTRY}/${service_name}:${TAG}"
    
    log_info "Building ${service_name} image..."
    log_info "Image name: ${image_name}"
    log_info "Dockerfile: ${dockerfile_path}"
    log_info "Context: ${context_path}"
    
    docker build \
        --file "${dockerfile_path}" \
        --tag "${image_name}" \
        --tag "${REGISTRY}/${service_name}:${GIT_COMMIT}" \
        --label "org.opencontainers.image.created=${BUILD_DATE}" \
        --label "org.opencontainers.image.revision=${GIT_COMMIT}" \
        --label "org.opencontainers.image.version=${TAG}" \
        --label "org.opencontainers.image.source=https://github.com/user/user-admin-messaging" \
        --label "org.opencontainers.image.title=${service_name}" \
        --label "org.opencontainers.image.description=User Admin Messaging ${service_name} service" \
        "${context_path}"
    
    if [ $? -eq 0 ]; then
        log_success "Successfully built ${service_name} image"
    else
        log_error "Failed to build ${service_name} image"
        exit 1
    fi
}

# Function to show usage
show_usage() {
    echo "Usage: $0 [OPTIONS] [SERVICES...]"
    echo ""
    echo "Build Docker images for user-admin-messaging application"
    echo ""
    echo "Options:"
    echo "  -h, --help          Show this help message"
    echo "  -t, --tag TAG       Docker image tag (default: latest)"
    echo "  -r, --registry REG  Docker registry prefix (default: user-admin-messaging)"
    echo "  --no-cache          Build without using cache"
    echo "  --push              Push images to registry after building"
    echo ""
    echo "Services:"
    echo "  websocket           Build WebSocket server image"
    echo "  user-frontend       Build user frontend image"
    echo "  admin-frontend      Build admin frontend image"
    echo "  all                 Build all images (default)"
    echo ""
    echo "Examples:"
    echo "  $0                                    # Build all images"
    echo "  $0 websocket                          # Build only WebSocket image"
    echo "  $0 -t v1.0.0 --push all             # Build all with tag v1.0.0 and push"
    echo "  $0 -r myregistry.com/myapp websocket # Build with custom registry"
}

# Parse command line arguments
SERVICES=()
NO_CACHE=""
PUSH_IMAGES=false

while [[ $# -gt 0 ]]; do
    case $1 in
        -h|--help)
            show_usage
            exit 0
            ;;
        -t|--tag)
            TAG="$2"
            shift 2
            ;;
        -r|--registry)
            REGISTRY="$2"
            shift 2
            ;;
        --no-cache)
            NO_CACHE="--no-cache"
            shift
            ;;
        --push)
            PUSH_IMAGES=true
            shift
            ;;
        websocket|user-frontend|admin-frontend|all)
            SERVICES+=("$1")
            shift
            ;;
        *)
            log_error "Unknown option: $1"
            show_usage
            exit 1
            ;;
    esac
done

# Default to building all services if none specified
if [ ${#SERVICES[@]} -eq 0 ]; then
    SERVICES=("all")
fi

# Check if Docker is available
if ! command -v docker &> /dev/null; then
    log_error "Docker is not installed or not in PATH"
    exit 1
fi

# Check if we're in the project root
if [ ! -f "package.json" ] || [ ! -d "websocket-server" ] || [ ! -d "frontend" ]; then
    log_error "This script must be run from the project root directory"
    exit 1
fi

log_info "Starting Docker build process..."
log_info "Registry: ${REGISTRY}"
log_info "Tag: ${TAG}"
log_info "Git Commit: ${GIT_COMMIT}"
log_info "Build Date: ${BUILD_DATE}"

# Build images based on selected services
for service in "${SERVICES[@]}"; do
    case $service in
        websocket|all)
            if [ "$service" = "websocket" ] || [ "$service" = "all" ]; then
                build_image "websocket" "websocket-server/Dockerfile" "websocket-server"
            fi
            ;;
        user-frontend|all)
            if [ "$service" = "user-frontend" ] || [ "$service" = "all" ]; then
                build_image "user-frontend" "frontend/user/Dockerfile" "."
            fi
            ;;
        admin-frontend|all)
            if [ "$service" = "admin-frontend" ] || [ "$service" = "all" ]; then
                build_image "admin-frontend" "frontend/admin/Dockerfile" "."
            fi
            ;;
    esac
done

# Push images if requested
if [ "$PUSH_IMAGES" = true ]; then
    log_info "Pushing images to registry..."
    
    for service in "${SERVICES[@]}"; do
        case $service in
            websocket|all)
                if [ "$service" = "websocket" ] || [ "$service" = "all" ]; then
                    log_info "Pushing websocket image..."
                    docker push "${REGISTRY}/websocket:${TAG}"
                    docker push "${REGISTRY}/websocket:${GIT_COMMIT}"
                fi
                ;;
            user-frontend|all)
                if [ "$service" = "user-frontend" ] || [ "$service" = "all" ]; then
                    log_info "Pushing user-frontend image..."
                    docker push "${REGISTRY}/user-frontend:${TAG}"
                    docker push "${REGISTRY}/user-frontend:${GIT_COMMIT}"
                fi
                ;;
            admin-frontend|all)
                if [ "$service" = "admin-frontend" ] || [ "$service" = "all" ]; then
                    log_info "Pushing admin-frontend image..."
                    docker push "${REGISTRY}/admin-frontend:${TAG}"
                    docker push "${REGISTRY}/admin-frontend:${GIT_COMMIT}"
                fi
                ;;
        esac
    done
    
    log_success "All images pushed successfully"
fi

log_success "Docker build process completed successfully!"

# Show built images
log_info "Built images:"
docker images "${REGISTRY}/*:${TAG}" --format "table {{.Repository}}\t{{.Tag}}\t{{.Size}}\t{{.CreatedAt}}"