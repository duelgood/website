WEB_IMAGE := zkeulr/duelgood-web
BACKEND_IMAGE := zkeulr/duelgood-backend
TIMESTAMP := $(shell date +%Y%m%d-%H%M%S)

# Multi-arch build for the web image
podman-web:
	# Create a manifest list
	podman manifest create $(WEB_IMAGE):$(TIMESTAMP)
	# Build amd64 image and add it
	podman build --arch amd64 \
		--tag $(WEB_IMAGE):$(TIMESTAMP)-amd64 \
		.
	podman manifest add $(WEB_IMAGE):$(TIMESTAMP) $(WEB_IMAGE):$(TIMESTAMP)-amd64
	# Build arm64 image and add it
	podman build --arch arm64 \
		--tag $(WEB_IMAGE):$(TIMESTAMP)-arm64 \
		.
	podman manifest add $(WEB_IMAGE):$(TIMESTAMP) $(WEB_IMAGE):$(TIMESTAMP)-arm64
	# Push manifest list as latest and timestamped tags
	podman tag $(WEB_IMAGE):$(TIMESTAMP) $(WEB_IMAGE):latest
	podman manifest push --all $(WEB_IMAGE):$(TIMESTAMP) docker://$(WEB_IMAGE):$(TIMESTAMP)
	podman manifest push --all $(WEB_IMAGE):latest docker://$(WEB_IMAGE):latest

# Multi-arch build for the backend image
podman-backend:
	podman manifest create $(BACKEND_IMAGE):$(TIMESTAMP)
	podman build --arch amd64 \
		--tag $(BACKEND_IMAGE):$(TIMESTAMP)-amd64 \
		-f backend/Dockerfile backend
	podman manifest add $(BACKEND_IMAGE):$(TIMESTAMP) $(BACKEND_IMAGE):$(TIMESTAMP)-amd64
	podman build --arch arm64 \
		--tag $(BACKEND_IMAGE):$(TIMESTAMP)-arm64 \
		-f backend/Dockerfile backend
	podman manifest add $(BACKEND_IMAGE):$(TIMESTAMP) $(BACKEND_IMAGE):$(TIMESTAMP)-arm64
	podman tag $(BACKEND_IMAGE):$(TIMESTAMP) $(BACKEND_IMAGE):latest
	podman manifest push --all $(BACKEND_IMAGE):$(TIMESTAMP) docker://$(BACKEND_IMAGE):$(TIMESTAMP)
	podman manifest push --all $(BACKEND_IMAGE):latest docker://$(BACKEND_IMAGE):latest

# Build both images
container: podman-web podman-backend

scan:
	gitleaks detect --report-format json --report-path gitleaks-report.json

git:
	git add .
	git commit -m "Update $(TIMESTAMP)"
	git push

.PHONY: podman-web podman-backend container scan git