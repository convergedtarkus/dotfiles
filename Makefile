# Self-Documented Makefile see https://marmelab.com/blog/2016/02/29/auto-documented-makefile.html

.DEFAULT_GOAL := help

.PHONY: help

.PHONY: help
help:
	@awk 'BEGIN {FS = ":.*?## "} /^[a-zA-Z_-]+:.*?## / {printf "\033[36m%-30s\033[0m %s\n", $$1, $$2}' $(MAKEFILE_LIST)

.PHONY: .getAllBash
.getAllBash: ## Get all bash scripts
	@find . -type d -name ".bash-it" -prune -type d -name ".git" -prune -o -type f \( -name "*.sh" -o -name "*.bash" \) -print0

.PHONY: checkAllBash
checkAllBash: ## Check all bash scripts with shellcheck
	@make .getAllBash | xargs -0 shellcheck

.PHONY: formatAllBash
formatAllBash: ## Format all bash scripts with shfmt
	@make .getAllBash | xargs -0 shfmt -w

.PHONY: formatAndCheckAllBash
formatAndCheckAllBash: ## Format and check all bash scripts
	@make formatAllBash
	@make checkAllBash

.PHONY: pullSubmoduleChanges
pullSubmoduleChanges: ## Pull changes for all git submodules
	@git submodule update --init --recursive

.PHONY: installGoTools
installGoTools: ## Install from this repo.
	cd ./tools/smartgorunner && go install ./cmd/smartgorunner/