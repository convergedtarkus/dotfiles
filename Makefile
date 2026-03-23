# Self-Documented Makefile see https://marmelab.com/blog/2016/02/29/auto-documented-makefile.html

.DEFAULT_GOAL := help

.PHONY: help

help:
	@awk 'BEGIN {FS = ":.*?## "} /^[a-zA-Z_-]+:.*?## / {printf "\033[36m%-30s\033[0m %s\n", $$1, $$2}' $(MAKEFILE_LIST)

.getAllBash: ## Get all bash scripts
	@find . -type d -name ".bash-it" -prune -type d -name ".git" -prune -o -type f \( -name "*.sh" -o -name "*.bash" \) -print0

checkAllBash: ## Check all bash scripts with shellcheck
	@make .getAllBash | xargs -0 shellcheck

formatAllBash: ## Format all bash scripts with shfmt
	@make .getAllBash | xargs -0 shfmt -w

formatAndCheckAllBash: ## Format and check all bash scripts
	@make formatAllBash
	@make checkAllBash

pullSubmoduleChanges: ## Pull changes for all git submodules
	@git submodule update --init --recursive