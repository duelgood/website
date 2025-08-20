IMAGE_NAME := zkeulr/duelgood
TIMESTAMP := $(shell date +%Y%m%d-%H%M%S)
CONTAINER_NAME := duelgood-web

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
	git commit -m "Update $(TIMESTAMP)"
	git push

clean: 
	docker system prune -f
	docker volume prune -f

debug: 
	sudo docker logs duelgood-web
	sudo docker logs duelgood-backend
	sudo docker logs duelgood-db
	curl -v -H "Host: duelgood.org" http://127.0.0.1/health

.PHONY: docker git clean