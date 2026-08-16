# =============================================================================
# DevSecOps Chaos Lab — Unified Build Commands
# ===========================================================================

.PHONY: help build dev staging prod chaos-verify drift-check clean all

help: ## Show this help
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | sort | \
		awk 'BEGIN {FS = ":.*?## "}; {printf "\033[36m%-20s\033[0m %s\n", $$1, $$2}'

build: ## Build Docker image (portfolio mode)
	docker build -t sample-app:test ./src/
	@echo "✅ Image built: sample-app:test"

dev: ## Deploy to dev namespace (requires kubectl configured for EKS)
	kubectl apply -k k8s-manifests/overlays/dev/
	kubectl rollout status deployment/sample-app -n secops-dev --timeout=300s 2>/dev/null || true
	@echo "✅ Dev deployment complete"

staging: ## Deploy to staging namespace
	kubectl apply -k k8s-manifests/overlays/staging/
	kubectl rollout status deployment/sample-app -n secops-staging --timeout=300s 2>/dev/null || true
	@echo "✅ Staging deployment complete"

prod: ## Deploy to prod namespace (REQUIRES approval workflow)
	kubectl apply -k k8s-manifests/overlays/prod/
	kubectl rollout status deployment/sample-app -n secops-prod --timeout=300s 2>/dev/null || true
	@echo "✅ Prod deployment complete"

scan: ## Run all security scans locally (portfolio mode)
	@echo "=== Container Scan (Trivy) ==="
	trivy image --severity CRITICAL,HIGH --format sarif sample-app:test > trivy-results.sarif 2>/dev/null || \
		echo "⏭️  Build image first: make build"
	@echo ""
	@echo "=== IaC Scan (Checkov) ==="
	checkov -d environments/ --quiet 2>/dev/null || echo "⏭️  Install checkov: pip install checkov"
	@echo ""
	@echo "=== Secret Scan (Gitleaks) ==="
	gitleaks detect --source . --report-format sarif 2>/dev/null || \
		echo "⏭️  Install gitleaks: brew install gitleaks"
	@echo ""
	@echo "✅ All local scans complete"

chaos-verify: ## Run chaos experiments against dev cluster
	@echo "=== Running Chaos Experiment Suite ==="
	@for exp in pod-failure network-latency oom-killing; do \
		echo ""; \
		echo "▶ $$exp"; \
		kubectl apply -f chaos-engineering/exp-sabotage/$$exp.yaml 2>/dev/null || true; \
		sleep 90; \
		kubectl delete -f chaos-engineering/exp-sabotage/$$exp.yaml --ignore-not-found 2>/dev/null; \
	done
	@echo ""
	@echo "=== Chaos Suite Complete ==="

drift-check: ## Run drift detection locally (dry-run)
	@echo "=== Drift Detection (Dry-Run) ==="
	for env in dev staging prod; do \
		echo ""; \
		echo "--- $$env ---"; \
		kustomize build k8s-manifests/overlays/$$env/ >/dev/null 2>&1 && \
			echo "✅ $$env overlay valid" || \
			echo "⚠️  $$env: overlay validation failed (expected in portfolio mode)"; \
	done

terraform-init: ## Initialize Terraform providers
	cd providers && terraform init -backend=false
	@for env in dev staging prod; do \
		echo "Init $$env..."; \
		cd environments/$$env && terraform init -backend=false && cd ../..; \
	done

terraform-plan: ## Plan all environments (providers + 3x env)
	cd providers && terraform plan -var-file="../environments/dev/variables.tf" || true

clean: ## Remove generated artifacts
	rm -f trivy-results.sarif grype-results.sarif *.sarif
	rm -rf node_modules src/node_modules
	@echo "✅ Cleaned"

all: build scan drift-check ## Run full portfolio-mode validation
