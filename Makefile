# Pantheon — AI team + skills harness for Claude Code.
# `make` or `make help` lists targets. Common variables:
#   PROFILES="core frontend"   skill profiles to install (default: all)
#   DRY_RUN=1                  print the plan, change nothing
#   FORCE=1                    replace existing files (backed up first, restored on uninstall)
#   CLAUDE_DIR=~/.claude       target Claude config dir

NAME           := pantheon
SHELL          := /bin/bash
PANTHEON       := ./bin/pantheon
PROFILES       ?= all
SKILLS_VERSION ?= 1.5.18
export PROFILES SKILLS_VERSION DRY_RUN FORCE CLAUDE_DIR

.DEFAULT_GOAL := help
.PHONY: help install uninstall install-core install-team install-skills install-plugins \
        uninstall-core uninstall-team uninstall-skills uninstall-plugins install-all uninstall-all \
        skill-add skill-remove search update capture list profiles status doctor validate test plan

help: ## Show this help
	@printf '\n\033[1m$(NAME)\033[0m — the Pantheon AI team for Claude Code\n\n'
	@awk 'BEGIN {FS = ":.*## "} /^[a-zA-Z_-]+:.*## / {printf "  \033[36m%-18s\033[0m %s\n", $$1, $$2}' $(MAKEFILE_LIST)
	@printf '\n  vars: PROFILES="$(PROFILES)" DRY_RUN=$(DRY_RUN) FORCE=$(FORCE) SKILLS_VERSION=$(SKILLS_VERSION)\n\n'

## ---- install / uninstall

install: ## Install core + team + skills (PROFILES=...)
	@$(PANTHEON) install core team skills

install-all: ## Install everything, including Claude plugins from plugins.tsv
	@$(PANTHEON) install all

uninstall: ## Remove everything Pantheon installed (and nothing else)
	@$(PANTHEON) uninstall

uninstall-all: uninstall ## Alias of uninstall

install-core: ## Rules, statusline, settings merge, guard hook
	@$(PANTHEON) install core
install-team: ## Agents, commands and Pantheon skills (symlinked — edits are live)
	@$(PANTHEON) install team
install-skills: ## Skills from skills/manifest.tsv via skills.sh + vendored skills
	@$(PANTHEON) install skills
install-plugins: ## Plugin marketplaces + plugins listed in plugins.tsv
	@$(PANTHEON) install plugins

uninstall-core: ## Remove core
	@$(PANTHEON) uninstall core
uninstall-team: ## Remove team
	@$(PANTHEON) uninstall team
uninstall-skills: ## Remove skills Pantheon installed
	@$(PANTHEON) uninstall skills
uninstall-plugins: ## Remove plugins Pantheon installed
	@$(PANTHEON) uninstall plugins

plan: ## Dry run of `make install-all` against your real config
	@DRY_RUN=1 $(PANTHEON) install all

## ---- skills

skill-add: ## Add one skill: make skill-add SRC=owner/repo SKILL=name [PROFILE=x]
	@$(PANTHEON) skill-add "$(SRC)" "$(SKILL)" "$(or $(PROFILE),misc)"

skill-remove: ## Remove one skill and drop it from the manifest: make skill-remove SKILL=name
	@$(PANTHEON) skill-remove "$(SKILL)"

search: ## Search skills.sh: make search Q=react
	@npx -y skills@$(SKILLS_VERSION) find $(Q)

update: ## Update installed skills.sh skills and plugin marketplaces
	@npx -y skills@$(SKILLS_VERSION) update -g -y
	@command -v claude >/dev/null && claude plugin marketplace update || true

capture: ## Snapshot this machine's skills, plugins and skillOverrides into the repo
	@./scripts/capture.sh

list: ## List manifest skills by profile
	@$(PANTHEON) list

profiles: ## Count skills per profile
	@grep -v '^#' skills/manifest.tsv | cut -f1 | sort | uniq -c

## ---- health

status: ## What Pantheon has installed
	@$(PANTHEON) status

doctor: ## Check tools, links, settings and manifests
	@$(PANTHEON) doctor

validate: ## Validate manifests, frontmatter, and skill quality (structure + trigger overlap)
	@claude plugin validate .
	@claude plugin validate plugins/$(NAME)
	@./tests/lint.sh
	@./tests/skills.sh

test: validate ## Lint + full install/uninstall round-trip in a throwaway HOME
	@./tests/roundtrip.sh
