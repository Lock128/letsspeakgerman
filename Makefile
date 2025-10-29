# Makefile for user-admin-messaging Docker operations

# Configuration
DOCKER_REGISTRY ?= user-admin-messaging
TAG ?= latest
GIT_COMMIT ?= $(shell git rev-parse --short HEAD 2>/dev/null || echo "unknown")

# Colors
BLUE := \033[0;34m
GREEN := \033[0;32m
YELLOW := \033[1;33m
RED := \033[0;31m
NC := \033[0m

.PHONY: help build build-websocket build-user-frontend build-admin-frontend \
        dev-up dev-down dev-restart dev-logs dev-clean \
        prod-up prod-down prod-restart \
        test lint clean-images clean-all \
        push tag-latest

# Default target
help: ## Show this help message
	@echo "$(BLUE)User Admin Messaging - Docker Operations$(NC)"
	@echo ""
	@echo "$(YELLOW)Available targets:$(NC)"
	@awk 'BEGIN {FS = ":.*?## "} /^[a-zA-Z_-]+:.*?## / {printf "  $(GREEN)%-20s$(NC) %s\n", $$1, $$2}' $(MAKEFILE_LIST)

# Build targets
build: ## Build all Docker images
	@echo "$(BLUE)Building all Docker images...$(NC)"
	@./scripts/docker-build.sh all

build-websocket: ## Build WebSocket service image
	@echo "$(BLUE)Building WebSocket service image...$(NC)"
	@./scripts/docker-build.sh websocket

build-user-frontend: ## Build user frontend image
	@echo "$(BLUE)Building user frontend image...$(NC)"
	@./scripts/docker-build.sh user-frontend

build-admin-frontend: ## Build admin frontend image
	@echo "$(BLUE)Building admin frontend image...$(NC)"
	@./scripts/docker-build.sh admin-frontend

# Development targets
dev-up: ## Start development environment
	@echo "$(BLUE)Starting development environment...$(NC)"
	@./scripts/docker-dev.sh up

dev-down: ## Stop development environment
	@echo "$(BLUE)Stopping development environment...$(NC)"
	@./scripts/docker-dev.sh down

dev-restart: ## Restart development environment
	@echo "$(BLUE)Restarting development environment...$(NC)"
	@./scripts/docker-dev.sh restart

dev-logs: ## Show development logs
	@./scripts/docker-dev.sh logs

dev-status: ## Show development service status
	@./scripts/docker-dev.sh status

dev-clean: ## Clean development environment
	@echo "$(YELLOW)Cleaning development environment...$(NC)"
	@./scripts/docker-dev.sh clean

# Production targets
prod-up: ## Start production environment
	@echo "$(BLUE)Starting production environment...$(NC)"
	@docker-compose -f docker-compose.yml -f docker-compose.prod.yml up -d

prod-down: ## Stop production environment
	@echo "$(BLUE)Stopping production environment...$(NC)"
	@docker-compose -f docker-compose.yml -f docker-compose.prod.yml down

prod-restart: ## Restart production environment
	@echo "$(BLUE)Restarting production environment...$(NC)"
	@docker-compose -f docker-compose.yml -f docker-compose.prod.yml restart

prod-logs: ## Show production logs
	@docker-compose -f docker-compose.yml -f docker-compose.prod.yml logs -f

# Testing targets
test: ## Run tests in containers
	@echo "$(BLUE)Running tests...$(NC)"
	@./scripts/docker-dev.sh test

lint: ## Run linting in containers
	@echo "$(BLUE)Running linting...$(NC)"
	@docker-compose exec websocket npm run lint || echo "$(YELLOW)Linting not configured$(NC)"

# Registry operations
push: build ## Build and push images to registry
	@echo "$(BLUE)Pushing images to registry...$(NC)"
	@./scripts/docker-build.sh --push all

tag-latest: ## Tag current images as latest
	@echo "$(BLUE)Tagging images as latest...$(NC)"
	@docker tag $(DOCKER_REGISTRY)/websocket:$(GIT_COMMIT) $(DOCKER_REGISTRY)/websocket:latest
	@docker tag $(DOCKER_REGISTRY)/user-frontend:$(GIT_COMMIT) $(DOCKER_REGISTRY)/user-frontend:latest
	@docker tag $(DOCKER_REGISTRY)/admin-frontend:$(GIT_COMMIT) $(DOCKER_REGISTRY)/admin-frontend:latest

# Cleanup targets
clean-images: ## Remove all project Docker images
	@echo "$(YELLOW)Removing project Docker images...$(NC)"
	@docker images "$(DOCKER_REGISTRY)/*" -q | xargs -r docker rmi -f

clean-all: dev-clean clean-images ## Clean everything (containers, images, volumes)
	@echo "$(YELLOW)Cleaning all Docker resources...$(NC)"
	@docker system prune -f

# Utility targets
shell-websocket: ## Open shell in WebSocket container
	@./scripts/docker-dev.sh shell websocket

shell-redis: ## Open Redis CLI
	@./scripts/docker-dev.sh shell redis

inspect: ## Show detailed container information
	@echo "$(BLUE)Container information:$(NC)"
	@docker-compose ps
	@echo ""
	@echo "$(BLUE)Image information:$(NC)"
	@docker images "$(DOCKER_REGISTRY)/*" --format "table {{.Repository}}\t{{.Tag}}\t{{.Size}}\t{{.CreatedAt}}"

# Environment setup
setup: ## Setup development environment
	@echo "$(BLUE)Setting up development environment...$(NC)"
	@chmod +x scripts/*.sh
	@echo "$(GREEN)Development environment setup complete!$(NC)"
	@echo ""
	@echo "$(YELLOW)Next steps:$(NC)"
	@echo "  1. Run 'make build' to build all images"
	@echo "  2. Run 'make dev-up' to start development environment"
	@echo "  3. Visit http://localhost/user/ for user interface"
	@echo "  4. Visit http://localhost/admin/ for admin interface"