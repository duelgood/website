IMAGE_NAME := zkeulr/duelgood
TIMESTAMP := $(shell date +%Y%m%d-%H%M%S)
CONTAINER_NAME := duelgood-web

git: 
	git add .
	git commit -m "Update $(TIMESTAMP)" || echo "No changes to commit"
	git push

docker: 
	docker buildx create --use --name multiarch-builder 2>/dev/null || true
	docker buildx build \
		--platform linux/amd64,linux/arm64 \
		--tag $(IMAGE_NAME):latest \
		--tag $(IMAGE_NAME):$(TIMESTAMP) \
		--push \
		.

run: docker
	docker-compose down 2>/dev/null || true
	docker pull $(IMAGE_NAME):latest
	docker-compose up -d

stop:
	docker-compose down