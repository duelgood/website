IMAGE_NAME := zkeulr/duelgood
TIMESTAMP := $(shell date +%Y%m%d-%H%M%S)
CONTAINER_NAME := duelgood-web

git: 
	git add .
	git commit -m "Update $(TIMESTAMP)" || echo "No changes to commit"
	git push

dev:
	docker build -f Dockerfile.dev -t $(IMAGE_NAME):dev .
	docker run -d --name $(CONTAINER_NAME)-dev -p 8080:80 $(IMAGE_NAME):dev

docker: 
	docker buildx create --use --name multiarch-builder 2>/dev/null || true
	docker buildx build \
		--platform linux/amd64,linux/arm64 \
		--tag $(IMAGE_NAME):latest \
		--tag $(IMAGE_NAME):$(TIMESTAMP) \
		--push \
		.

run:
	docker-compose down 2>/dev/null || true
	docker pull $(IMAGE_NAME):latest
	docker-compose up -d

stop:
	docker-compose down	

.PHONY: git docker dev run stop stop-dev