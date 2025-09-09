WEB_IMAGE := zkeulr/duelgood-web
BACKEND_IMAGE := zkeulr/duelgood-backend
TIMESTAMP := $(shell date +%Y%m%d-%H%M%S)

# Build and push web image
podman-web:
	podman build \
		--tag $(WEB_IMAGE):latest \
		--tag $(WEB_IMAGE):$(TIMESTAMP) \
		.
	podman push $(WEB_IMAGE):latest
	podman push $(WEB_IMAGE):$(TIMESTAMP)

# Build and push backend image
podman-backend:
	podman build \
		--tag $(BACKEND_IMAGE):latest \
		--tag $(BACKEND_IMAGE):$(TIMESTAMP) \
		-f backend/Dockerfile backend
	podman push $(BACKEND_IMAGE):latest
	podman push $(BACKEND_IMAGE):$(TIMESTAMP)

# Build both
container: podman-web podman-backend

# Secret scanning
scan:
	gitleaks detect --report-format json --report-path gitleaks-report.json

# Commit & push repo
git:
	git add .
	git commit -m "Update $(TIMESTAMP)"
	git push

.PHONY: podman-web podman-backend container scan git