REGISTRY := ghcr.io
WEB_IMAGE := $(REGISTRY)/duelgood/web
BACKEND_IMAGE := $(REGISTRY)/duelgood/backend
MAIL_IMAGE := $(REGISTRY)/duelgood/mail


TIMESTAMP := $(shell date +%Y%m%d-%H%M%S)

all: git container

podman-web:
	podman build \
    --platform linux/amd64 \
    --tag $(WEB_IMAGE):latest \
    --tag $(WEB_IMAGE):$(TIMESTAMP) \
    -f web/Containerfile web

	podman push $(WEB_IMAGE):latest
	podman push $(WEB_IMAGE):$(TIMESTAMP)

podman-backend:
	podman build \
    --platform linux/amd64 \
    --tag $(BACKEND_IMAGE):latest \
    --tag $(BACKEND_IMAGE):$(TIMESTAMP) \
    -f backend/Containerfile backend

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

.PHONY: podman-web podman-backend podman-mail container scan git

