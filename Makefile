.PHONY: setup setup-dev deploy teardown check check-ready validate docs-build docs-serve docs-stop help

setup: ## Interactive setup wizard (installs tools, configures deployment)
	./bootstrap.sh

setup-dev: ## Setup for maintainers/contributors (includes linters)
	./bootstrap.sh --mode dev

deploy: ## Deploy hub + student clusters
	./agnosticd/deploy.sh

teardown: ## Destroy all clusters
	./agnosticd/teardown.sh

check: ## Run AWS quota pre-flight check
	./agnosticd/check-quota.sh

check-ready: ## Validate environment readiness (no install, no deploy)
	./bootstrap.sh --check-only

validate: ## Validate Fleet Virtualization on hub cluster
	./agnosticd/validate-fleet-virt.sh

docs-build: ## Build Showroom lab content locally
	./utilities/lab-build

docs-serve: ## Serve lab content at http://localhost:8080
	./utilities/lab-serve

docs-stop: ## Stop local lab content server
	./utilities/lab-stop

help: ## Show this help
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | \
		awk 'BEGIN {FS = ":.*?## "}; {printf "  \033[36m%-14s\033[0m %s\n", $$1, $$2}'

.DEFAULT_GOAL := help
