SHELL := /bin/bash

# Self-Documented Makefile see https://marmelab.com/blog/2016/02/29/auto-documented-makefile.html
.DEFAULT_GOAL := help

.PHONY: help

.PHONY: help
help:
	@awk 'BEGIN {FS = ":.*?## "} /^[a-zA-Z_-]+:.*?## / {printf "\033[36m%-30s\033[0m %s\n", $$1, $$2}' $(MAKEFILE_LIST)

.PHONY: enableBashItScripts
enableBashItScripts: ## Enables the alias, completion and plugin extensions for bash-it that I use.
	@# Start by disabling everything in the user's interactive Bash shell.
	@bash -i -c 'bash-it disable alias all'
	@bash -i -c 'bash-it disable completion all'
	@bash -i -c 'bash-it disable plugin all'
	@# Now enable the ones we want in the user's interactive Bash shell.
	@bash -i -c 'bash-it enable alias custom'
	@bash -i -c 'bash-it enable completion aliases bash-it brew custom dart defaults docker git go makefile system'

.PHONY: .getAllBash
.getAllBash: ## Get all bash scripts
	@make .runGitCommand CMD='-C . ls-files -z ' \
	| xargs -0 -n1 dirname \
	| sort -u \
	| while IFS= read -r d; do \
		find "$$d" -maxdepth 1 \
			-type d \( -name ".bash-it" -o -name ".vim" -o -name ".git" \) -prune -o \
			-type f \
			-exec awk 'NR==1 { exit ($$0 ~ /^#!(\/(usr\/)?bin\/(env[[:space:]]+)?(ba)?sh([[:space:]]|$$))/ ? 0 : 1) } END { if (NR==0) exit 1 }' {} \; \
			-print0; \
	done

.PHONY: checkAllBash
checkAllBash: formatAllBash ## Check all bash scripts with shellcheck
	@# SC1090 = Can't follow non-constant source. Use a directive to specify location
	@#     Generally this is just noise that I have to add a directive to ignore, so ignore it by default.
	@# SC1091 = Not following: (error message here)
	@#     Same as above.
	@# Pipe to sed to convert the line number format so IDEs can link to the file and line number.
	@# This will run the shellcheck alias above.
	@# --color=always is needed to preserve the colors when piping to sed.
	@make .getAllBash | xargs -0 shellcheck \
		-e SC1090,SC1091 \
		-o avoid-negated-conditions,avoid-nullary-conditions,check-set-e-suppressed,deprecate-which,require-double-brackets,useless-use-of-cat \
		--color=always \
		| \
		sed -E 's#In (.\/)?(.*) line ([0-9]+):#In ./\2:\3:#'

.PHONY: formatAllBash
formatAllBash: ## Format all bash scripts with shfmt
	@make .getAllBash | xargs -0 shfmt -w -s

.PHONY: pullSubmoduleChanges
pullSubmoduleChanges: ## Pull changes for all git submodules
	@make .runGitCommand CMD='submodule update --init --recursive'

.PHONY: installGoTools
installGoTools: ## Install from this repo.
	@if command -v asdf > /dev/null; then asdf install; fi
	@if ! command -v go > /dev/null || ! go version > /dev/null; then \
		echo "Go is not installed."; \
		exit 1; \
	fi
	cd ./tools/smartgorunner && go install ./cmd/smartgorunner/
	cd ./tools/smartGoInstall && go install .
	cd ./tools/pubCacheClean && go install .
	cd ./tools/diskHog && go install .

.PHONY: backupSublimeConfigs
backupSublimeConfigs: ## Backup sublime configs to this repo.
	@cp -Rv $$HOME/Library/Application\ Support/Sublime\ Text/Packages/User/ ./AppConfigs/sublimeConfig/

.PHONY: installSublimeConfigs
installSublimeConfigs: ## Install sublime configs from this repo.
	@cp -Rv "./AppConfigs/sublimeConfig/" "$$HOME/Library/Application Support/Sublime Text/Packages/User/"

.PHONY: generateFileIgnoreConfig
generateFileIgnoreConfig: ## Generates a string of files to ignore for IntelliJ's exclude files option. Helpful when this repo is installed at roo.
	@shopt -s dotglob; \
	trap "shopt -u dotglob" EXIT; \
	output=""; \
	for file in *; do \
		if [[ -d $$file ]]; then \
			continue; \
		fi; \
		if ! make .runGitCommand CMD="ls-files '$$file' --error-unmatch" &>/dev/null; then \
			if [[ -z $$output ]]; then \
				output="$$file"; \
			else \
				output="$$output;$$file"; \
			fi; \
		fi; \
	done; \
	echo "$$output"; \

.PHONY: .deleteRepository
.deleteRepository: ## Deletes this repository and all of its contents. Use with caution. Must pass in FOR_REAL=true to actually delete. Otherwise, it is a dry run.
	@shopt -s dotglob; \
	trap "shopt -u dotglob" EXIT; \
	shouldDelete="$(FOR_REAL)"; \
	for file in *; do \
		if make .runGitCommand CMD="ls-files '$$file' --error-unmatch" &>/dev/null; then \
			if [[ $$shouldDelete == "true" ]]; then \
				rm -rf "$$file"; \
			else \
				echo "Would delete: $$file"; \
			fi; \
		fi; \
	done; \
	if [[ -d ".myconfig" ]]; then \
		if [[ $$shouldDelete == "true" ]]; then \
			rm -rf ".myconfig"; \
		else \
			echo "Would delete: .myconfig"; \
		fi; \
	fi; \

.PHONY: .runGitCommand
.runGitCommand: ## Run a myconfig git command. Usage: make myconfigGit CMD='status -sb'
	@# Handle if this is being used with the myconfig setup or not.
	@ if [ -d ".myconfig" ]; then \
		git --git-dir=$$HOME/.myconfig/ --work-tree=$$HOME $(CMD); \
	else \
		git $(CMD); \
	fi