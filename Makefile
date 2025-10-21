REGISTRY := ghcr.io
WEB_IMAGE := $(REGISTRY)/duelgood/duelgood-web
BACKEND_IMAGE := $(REGISTRY)/duelgood/duelgood-backend

TIMESTAMP := $(shell date +%Y%m%d-%H%M%S)

all: login git container

podman-web:
	podman build \
    --platform linux/amd64 \
    --tag $(WEB_IMAGE):latest \
    --tag $(WEB_IMAGE):$(TIMESTAMP) \
    .

	podman push $(WEB_IMAGE):latest
	podman push $(WEB_IMAGE):$(TIMESTAMP)

podman-backend:
	podman build \
    --platform linux/amd64 \
    --tag $(BACKEND_IMAGE):latest \
    --tag $(BACKEND_IMAGE):$(TIMESTAMP) \
    -f backend/Dockerfile backend
	podman push $(BACKEND_IMAGE):latest
	podman push $(BACKEND_IMAGE):$(TIMESTAMP)

container: podman-web podman-backend

scan:
	gitleaks detect --report-format json --report-path gitleaks-report.json

git:
	git add .
	git commit -m "Update $(TIMESTAMP)"
	git push

login:
	podman login ghcr.io --username $(PODMAN_USERNAME) --password $(GITHUB_GHCR_PAT)

.PHONY: podman-web podman-backend container scan git

