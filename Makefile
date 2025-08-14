IMAGE_NAME := zkeulr/duelgood
TIMESTAMP := $(shell date +%Y%m%d-%H%M%S)
CONTAINER_NAME := duelgood-web

# Development commands
dev:
	@echo "Starting development server..."
	docker-compose -f docker-compose.yml.dev up --build

dev-down:
	@echo "Stopping development server..."
	docker-compose -f docker-compose.yml.dev down

dev-logs:
	docker-compose -f docker-compose.yml.dev logs -f

# Production commands
prod:
	@echo "Starting production server..."
	docker-compose up --build -d

prod-down:
	@echo "Stopping production server..."
	docker-compose down

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

.PHONY: dev dev-down dev-logs prod prod-down build-push git clean health