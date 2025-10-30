REGISTRY := ghcr.io
frontend_IMAGE := $(REGISTRY)/duelgood/frontend
BACKEND_IMAGE := $(REGISTRY)/duelgood/backend
MAIL_IMAGE := $(REGISTRY)/duelgood/mail


TIMESTAMP := $(shell date +%Y%m%d-%H%M%S)

all: git container

podman-frontend:
	podman build \
    --platform linux/amd64 \
    --tag $(frontend_IMAGE):latest \
    --tag $(frontend_IMAGE):$(TIMESTAMP) \
    -f frontend/Containerfile frontend

	podman push $(frontend_IMAGE):latest
	podman push $(frontend_IMAGE):$(TIMESTAMP)

podman-backend:
	podman build \
    --platform linux/amd64 \
    --tag $(BACKEND_IMAGE):latest \
    --tag $(BACKEND_IMAGE):$(TIMESTAMP) \
    -f backend/Containerfile backend

	podman push $(BACKEND_IMAGE):latest
	podman push $(BACKEND_IMAGE):$(TIMESTAMP)

container: podman-frontend podman-backend

scan:
	gitleaks detect --report-format json --report-path gitleaks-report.json

git:
	git add .
	git commit -m "Update $(TIMESTAMP)"
	git push

login:
	podman login ghcr.io --username $(PODMAN_USERNAME) --password $(GITHUB_GHCR_PAT)

.PHONY: podman-frontend podman-backend podman-mail container scan git

