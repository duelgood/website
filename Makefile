WEB_IMAGE := zkeulr/duelgood-web
BACKEND_IMAGE := zkeulr/duelgood-backend
TIMESTAMP := $(shell date +%Y%m%d-%H%M%S)

docker-web:
	docker buildx create --use --name multiarch-builder 2>/dev/null || true
	docker buildx build \
		--platform linux/amd64,linux/arm64 \
		--tag $(WEB_IMAGE):latest \
		--tag $(WEB_IMAGE):$(TIMESTAMP) \
		--push \
		.

docker-backend:
	docker buildx create --use --name multiarch-builder 2>/dev/null || true
	docker buildx build \
		--platform linux/amd64,linux/arm64 \
		--tag $(BACKEND_IMAGE):latest \
		--tag $(BACKEND_IMAGE):$(TIMESTAMP) \
		--push \
		-f backend/Dockerfile backend

docker: docker-web docker-backend

git: 
	git add .
	git commit -m "Update $(TIMESTAMP)"
	git push

clean: 
	docker system prune -f
	docker volume prune -f

debug: 
	docker logs duelgood-web || true
	docker logs duelgood-backend || true
	docker logs duelgood-db || true
	curl -v -H "Host: duelgood.org" http://127.0.0.1/health || true

.PHONY: docker docker-web docker-backend git clean debug