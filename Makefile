IMAGE_NAME := zkeulr/duelgood
TIMESTAMP := $(shell date +%Y%m%d-%H%M%S)
CONTAINER_NAME := duelgood-web

ifneq (,$(wildcard ./.env))
	include .env
	export
endif

ifeq ($(ENVIRONMENT),production)
	COMPOSE_FILE := docker-compose.yml
	COMPOSE_FLAGS := -d
else
	COMPOSE_FILE := docker-compose.yml.dev
	COMPOSE_FLAGS := 
endif

up:
	@echo "Starting $(ENVIRONMENT) server..."
	@echo "Stopping any existing containers..."
	docker-compose -f $(COMPOSE_FILE) down --remove-orphans
	@echo "Starting new container..."
	docker-compose -f $(COMPOSE_FILE) up --build $(COMPOSE_FLAGS)

down:
	@echo "Stopping server..."
	docker-compose -f $(COMPOSE_FILE) down --remove-orphans

logs:
	docker-compose -f $(COMPOSE_FILE) logs -f

docker:
	docker buildx create --use --name multiarch-builder 2>/dev/null || true
	docker buildx build \
		--platform linux/amd64,linux/arm64 \
		--tag $(IMAGE_NAME):latest \
		--tag $(IMAGE_NAME):$(TIMESTAMP) \
		--push \
		.
		
git: 
	git add .
	git commit -m "Update $(TIMESTAMP)" || echo "No changes to commit"
	git push

clean: 
	docker system prune -f
	docker volume prune -f

health:
	curl -f http://localhost/health || echo "Service not healthy"

.PHONY: up down logs build-push git clean health