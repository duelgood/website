IMAGE_NAME := zkeulr/duelgood
TIMESTAMP := $(shell date +%Y%m%d-%H%M%S)
CONTAINER_NAME := duelgood-web

# Load environment variables from .env file if it exists
ifneq (,$(wildcard ./.env))
	include .env
	export
endif

# Determine which compose file to use based on ENVIRONMENT variable
ifeq ($(ENVIRONMENT),production)
	COMPOSE_FILE := docker-compose.yml
	COMPOSE_FLAGS := -d
else
	COMPOSE_FILE := docker-compose.yml.dev
	COMPOSE_FLAGS := 
endif

# Main commands - automatically use dev or prod based on .env
up:
	@echo "Starting $(ENVIRONMENT) server..."
	docker-compose -f $(COMPOSE_FILE) down --remove-orphans 2>/dev/null || true
	docker-compose -f $(COMPOSE_FILE) up --build $(COMPOSE_FLAGS)

down:
	@echo "Stopping server..."
	docker-compose -f $(COMPOSE_FILE) down --remove-orphans

logs:
	docker-compose -f $(COMPOSE_FILE) logs -f

# Build and push to registry
build-push:
	docker buildx create --use --name multiarch-builder 2>/dev/null || true
	docker buildx build \
		--platform linux/amd64,linux/arm64 \
		--tag $(IMAGE_NAME):latest \
		--tag $(IMAGE_NAME):$(TIMESTAMP) \
		--push \
		.

# Git operations
git: 
	git add .
	git commit -m "Update $(TIMESTAMP)" || echo "No changes to commit"
	git push

# Cleanup
clean: 
	docker system prune -f
	docker volume prune -f

# Health check
health:
	curl -f http://localhost/health || echo "Service not healthy"

.PHONY: up down logs build-push git clean health