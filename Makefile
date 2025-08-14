# DuelGood Website Makefile

# Variables
IMAGE_NAME := zkeulr/duelgood
TIMESTAMP := $(shell date +%Y%m%d-%H%M%S)
CONTAINER_NAME := duelgood-web

# Colors for output
BLUE := \033[34m
GREEN := \033[32m
YELLOW := \033[33m
RED := \033[31m
NC := \033[0m # No Color

.PHONY: help build push deploy clean logs status test dev stop restart

# Default target
help: ## Show this help message
	@echo "$(BLUE)DuelGood Website Management$(NC)"
	@echo "Available commands:"
	@awk 'BEGIN {FS = ":.*?## "} /^[a-zA-Z_-]+:.*?## / {printf "  $(GREEN)%-15s$(NC) %s\n", $$1, $$2}' $(MAKEFILE_LIST)

build: ## Build the Docker image locally
	@echo "$(BLUE)Building Docker image...$(NC)"
	docker buildx create --use --name multiarch-builder 2>/dev/null || true
	docker buildx build \
		--platform linux/amd64,linux/arm64 \
		--tag $(IMAGE_NAME):latest \
		--tag $(IMAGE_NAME):$(TIMESTAMP) \
		--load \
		.
	@echo "$(GREEN)Build completed: $(IMAGE_NAME):$(TIMESTAMP)$(NC)"

push: ## Build and push to registry (original build.sh functionality)
	@echo "$(BLUE)Committing changes and pushing image...$(NC)"
	git add .
	git commit -m "Update $(TIMESTAMP)" || echo "No changes to commit"
	docker buildx create --use --name multiarch-builder 2>/dev/null || true
	docker buildx build \
		--platform linux/amd64,linux/arm64 \
		--tag $(IMAGE_NAME):latest \
		--tag $(IMAGE_NAME):$(TIMESTAMP) \
		--push \
		.
	@echo "$(GREEN)Push completed: $(IMAGE_NAME):$(TIMESTAMP)$(NC)"

deploy: push ## Deploy the application (build, push, and run)
	@echo "$(BLUE)Deploying application...$(NC)"
	docker-compose down 2>/dev/null || true
	docker pull $(IMAGE_NAME):latest
	docker-compose up -d
	@echo "$(GREEN)Deployment completed$(NC)"

dev: ## Start development environment
	@echo "$(BLUE)Starting development environment...$(NC)"
	docker-compose up --build

stop: ## Stop the application
	@echo "$(YELLOW)Stopping application...$(NC)"
	docker-compose down

restart: ## Restart the application
	@echo "$(BLUE)Restarting application...$(NC)"
	docker-compose restart

clean: ## Clean up Docker resources
	@echo "$(YELLOW)Cleaning up Docker resources...$(NC)"
	docker-compose down -v 2>/dev/null || true
	docker system prune -f
	docker volume prune -f
	docker image prune -f
	@echo "$(GREEN)Cleanup completed$(NC)"

clean-all: ## Remove all Docker resources including images
	@echo "$(RED)WARNING: This will remove ALL Docker resources$(NC)"
	@read -p "Are you sure? (y/N): " confirm && [ "$$confirm" = "y" ]
	docker-compose down -v 2>/dev/null || true
	docker system prune -af
	docker volume prune -f
	docker builder prune -af
	@echo "$(GREEN)Complete cleanup finished$(NC)"

logs: ## View application logs
	docker-compose logs -f

logs-nginx: ## View nginx access logs
	docker exec -it $(CONTAINER_NAME) tail -f /var/log/nginx/access.log

logs-error: ## View nginx error logs
	docker exec -it $(CONTAINER_NAME) tail -f /var/log/nginx/error.log

status: ## Show application status
	@echo "$(BLUE)Application Status:$(NC)"
	@docker-compose ps
	@echo "\n$(BLUE)Container Health:$(NC)"
	@docker inspect $(CONTAINER_NAME) --format='{{.State.Health.Status}}' 2>/dev/null || echo "Container not running"

test: ## Test the application
	@echo "$(BLUE)Testing application...$(NC)"
	@if curl -f http://localhost/health >/dev/null 2>&1; then \
		echo "$(GREEN)✓ Health check passed$(NC)"; \
	else \
		echo "$(RED)✗ Health check failed$(NC)"; \
		exit 1; \
	fi
	@if curl -f http://localhost/ >/dev/null 2>&1; then \
		echo "$(GREEN)✓ Homepage accessible$(NC)"; \
	else \
		echo "$(RED)✗ Homepage not accessible$(NC)"; \
		exit 1; \
	fi

shell: ## Access container shell
	docker exec -it $(CONTAINER_NAME) /bin/sh

backup: ## Create backup of website files
	@echo "$(BLUE)Creating backup...$(NC)"
	tar -czf backup-$(TIMESTAMP).tar.gz pages/ includes/ static/ nginx.conf Dockerfile docker-compose.yml
	@echo "$(GREEN)Backup created: backup-$(TIMESTAMP).tar.gz$(NC)"

update: ## Pull latest image and restart
	@echo "$(BLUE)Updating application...$(NC)"
	docker pull $(IMAGE_NAME):latest
	docker-compose up -d
	@echo "$(GREEN)Update completed$(NC)"

# Oracle Cloud specific commands
oracle-setup: ## Setup Oracle Cloud specific configurations
	@echo "$(BLUE)Setting up Oracle Cloud configurations...$(NC)"
	@echo "Make sure to:"
	@echo "1. Configure Cloudflare DNS to point to your Oracle Cloud IP"
	@echo "2. Set up Oracle Cloud firewall rules for ports 80 and 443"
	@echo "3. Configure Cloudflare SSL/TLS to 'Full' or 'Full (strict)'"
	@echo "4. Enable Cloudflare proxy (orange cloud) for your domain"

# Development helpers
lint: ## Check nginx configuration
	docker run --rm -v $(PWD)/nginx.conf:/etc/nginx/nginx.conf nginx:alpine nginx -t

validate-html: ## Validate HTML files (requires htmlhint)
	@if command -v htmlhint >/dev/null 2>&1; then \
		htmlhint pages/*.shtml; \
	else \
		echo "$(YELLOW)htmlhint not installed. Run: npm install -g htmlhint$(NC)"; \
	fi

watch: ## Watch for file changes and rebuild (requires entr)
	@if command -v entr >/dev/null 2>&1; then \
		find pages includes static nginx.conf Dockerfile -type f | entr -r make dev; \
	else \
		echo "$(YELLOW)entr not installed. Run: apt-get install entr (Ubuntu) or brew install entr (macOS)$(NC)"; \
	fi
