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
	@make .getAllBash | xargs -0 shellcheck -e SC1090,SC1091 -o add-default-case,avoid-negated-conditions,avoid-nullary-conditions,check-set-e-suppressed,deprecate-which,require-double-brackets,useless-use-of-cat

.PHONY: formatAllBash
formatAllBash: ## Format all bash scripts with shfmt
	@make .getAllBash | xargs -0 shfmt -w -s

.PHONY: formatAndCheckAllBash
formatAndCheckAllBash: ## Format and check all bash scripts
	@make formatAllBash
	@make checkAllBash

.PHONY: pullSubmoduleChanges
pullSubmoduleChanges: ## Pull changes for all git submodules
	@git --git-dir=$$HOME/.myconfig/ --work-tree=$$HOME submodule update --init --recursive

.PHONY: installGoTools
installGoTools: ## Install from this repo.
	cd ./tools/smartgorunner && go install ./cmd/smartgorunner/

.PHONY: backupSublimeConfigs
backupSublimeConfigs: ## Backup sublime configs to this repo.
	@cp -r $$HOME/Library/Application\ Support/Sublime\ Text/Packages/User/ ./AppConfigs/sublimeConfig/

.PHONY: installSublimeConfigs
installSublimeConfigs: ## Install sublime configs from this repo.
	@cp -r ./AppConfigs/sublimeConfig/ $$HOME/Library/Application\ Support/Sublime\ Text/Packages/User/
