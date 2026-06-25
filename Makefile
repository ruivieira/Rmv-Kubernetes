.PHONY: lint check unit integration test secrets stamp pre-commit all help \
	docs-deps docs-weave docs-weave-check docs kind-up kind-down docs-kind

KIND_CLUSTER ?= rmv-kubernetes
DOC          ?= docs/tutorial.md
DOCS_ENV     = LC_ALL=C.UTF-8 LANG=C.UTF-8 NO_COLOR=1
RAKU_SITE_BIN := $(shell raku -e 'print $$*EXECUTABLE.parent.parent.Str')/share/perl6/site/bin
export PATH := $(RAKU_SITE_BIN):$(PATH)

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

docs-deps: ## Install Text::CodeProcessing for literate docs
	zef install Text::CodeProcessing

docs-weave: docs-deps ## Evaluate code cells → docs/tutorial_woven.md
	$(DOCS_ENV) file-code-chunks-eval $(DOC)
	$(MAKE) docs-weave-check

docs-weave-check: ## Fail if woven output has errors or UTF-8 mojibake
	@test -f docs/tutorial_woven.md
	@if grep -q '#ERROR:' docs/tutorial_woven.md; then \
		echo "Weave errors in docs/tutorial_woven.md:"; \
		grep '#ERROR:' docs/tutorial_woven.md; exit 1; \
	fi
	@if grep -q 'â€"' docs/tutorial_woven.md; then \
		echo "UTF-8 mojibake detected in woven output"; exit 1; \
	fi

docs: docs-weave ## Weave literate tutorial

kind-up: ## Create KinD cluster (skip if already exists)
	@if ! kind get clusters 2>/dev/null | grep -qx '$(KIND_CLUSTER)'; then \
		kind create cluster --name $(KIND_CLUSTER); \
	else \
		echo "KinD cluster '$(KIND_CLUSTER)' already exists"; \
	fi

kind-down: ## Delete KinD cluster
	kind delete cluster --name $(KIND_CLUSTER) 2>/dev/null || true

docs-kind: docs-deps ## Create KinD cluster, weave tutorial, delete cluster
	@set -e; \
	trap 'kind delete cluster --name $(KIND_CLUSTER) 2>/dev/null || true' EXIT; \
	if ! kind get clusters 2>/dev/null | grep -qx '$(KIND_CLUSTER)'; then \
		kind create cluster --name $(KIND_CLUSTER); \
	fi; \
	kubectl cluster-info --context "kind-$(KIND_CLUSTER)"; \
	$(DOCS_ENV) file-code-chunks-eval $(DOC); \
	$(MAKE) docs-weave-check

all: check lint test secrets ## Run everything
