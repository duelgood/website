# DuelGood Website Makefile

# Variables
IMAGE_NAME := zkeulr/duelgood
TIMESTAMP := $(shell date +%Y%m%d-%H%M%S)
CONTAINER_NAME := duelgood-web

git: 
	git add .
	git commit -m "Update $(TIMESTAMP)" || echo "No changes to commit"

push: 
	docker buildx create --use --name multiarch-builder 2>/dev/null || true
	docker buildx build \
		--platform linux/amd64,linux/arm64 \
		--tag $(IMAGE_NAME):latest \
		--tag $(IMAGE_NAME):$(TIMESTAMP) \
		--push \
		.

deploy: push
	docker-compose down 2>/dev/null || true
	docker pull $(IMAGE_NAME):latest
	docker-compose up -d

stop: ## Stop the application
	docker-compose down

backup: ## Create backup of website files
	@echo "$(BLUE)Creating backup...$(NC)"
	tar -czf backup-$(TIMESTAMP).tar.gz pages/ includes/ static/ nginx.conf Dockerfile docker-compose.yml
	@echo "$(GREEN)Backup created: backup-$(TIMESTAMP).tar.gz$(NC)"

update: ## Pull latest image and restart
	@echo "$(BLUE)Updating application...$(NC)"
	docker pull $(IMAGE_NAME):latest
	docker-compose up -d
	@echo "$(GREEN)Update completed$(NC)"

# Oracle Cloud specific commands
oracle-setup: ## Setup Oracle Cloud specific configurations
	@echo "$(BLUE)Setting up Oracle Cloud configurations...$(NC)"
	@echo "Make sure to:"
	@echo "1. Configure Cloudflare DNS to point to your Oracle Cloud IP"
	@echo "2. Set up Oracle Cloud firewall rules for ports 80 and 443"
	@echo "3. Configure Cloudflare SSL/TLS to 'Full' or 'Full (strict)'"
	@echo "4. Enable Cloudflare proxy (orange cloud) for your domain"

# Development helpers
lint: ## Check nginx configuration
	docker run --rm -v $(PWD)/nginx.conf:/etc/nginx/nginx.conf nginx:alpine nginx -t

validate-html: ## Validate HTML files (requires htmlhint)
	@if command -v htmlhint >/dev/null 2>&1; then \
		htmlhint pages/*.shtml; \
	else \
		echo "$(YELLOW)htmlhint not installed. Run: npm install -g htmlhint$(NC)"; \
	fi

watch: ## Watch for file changes and rebuild (requires entr)
	@if command -v entr >/dev/null 2>&1; then \
		find pages includes static nginx.conf Dockerfile -type f | entr -r make dev; \
	else \
		echo "$(YELLOW)entr not installed. Run: apt-get install entr (Ubuntu) or brew install entr (macOS)$(NC)"; \
	fi
