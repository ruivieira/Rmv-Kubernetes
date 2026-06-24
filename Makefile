.PHONY: lint check unit integration test secrets stamp pre-commit all help

help: ## Show this help
	@grep -E '^[a-zA-Z_-]+:.*?## ' $(MAKEFILE_LIST) | awk 'BEGIN {FS = ":.*?## "}; {printf "  %-14s %s\n", $$1, $$2}'

lint: ## Run Raku lint checks
	./scripts/raku-lint.sh lib/Kubernetes.rakumod lib/Kubernetes/*.rakumod lib/Kubernetes/**/*.rakumod

check: ## Run Raku syntax check on all source files
	find lib -name '*.rakumod' -exec raku -Ilib -c {} +

unit: ## Run unit tests (no cluster required)
	@for t in t/*.rakutest; do \
		echo "  $$t"; \
		raku -Ilib "$$t" || exit 1; \
	done

integration: ## Run KinD integration tests (requires KUBECONFIG)
	@for t in t/integration/*.rakutest; do \
		[ -e "$$t" ] || continue; \
		echo "  $$t"; \
		raku -Ilib "$$t" || exit 1; \
	done

test: unit ## Alias for unit tests

stamp: ## Stamp {{$NEXT}} in Changes with version and date
	./scripts/stamp-changes.sh

secrets: ## Scan for secrets (non-interactive, CI-safe)
	gitleaks detect --no-git --source . -v

pre-commit: ## Run all pre-commit hooks
	pre-commit run --all-files

all: check lint test secrets ## Run everything
