MAKEFLAGS += --no-print-directory

.DEFAULT_GOAL := help

.PHONY: build clean fmt help install install-system lint quality run setup shellcheck test tui uninstall version

# ---------------------------------------------------------------------------
# Variables
# ---------------------------------------------------------------------------

BINARY_NAME := ttdaid
CMD_PATH    := ./ttdaid/cmd/ttdaid

DISTRO  ?= debian
RELEASE ?= trixie

# Legacy alias (prefer RELEASE=)
ifneq ($(origin DEBIAN_VERSION), undefined)
    ifneq ($(DEBIAN_VERSION),)
        RELEASE := $(DEBIAN_VERSION)
    endif
endif

VERSION := $(shell git describe --tags --always --dirty 2>/dev/null || echo dev)
LDFLAGS := -s -w -X github.com/carlosrabelo/ttdaid/ttdaid/internal/version.Version=$(VERSION)

export BINARY_NAME CMD_PATH VERSION LDFLAGS

# ---------------------------------------------------------------------------
# Targets
# ---------------------------------------------------------------------------

help: ## Show available targets
	@echo "ttdaid - Available targets"
	@echo ""
	@grep -hE '^[a-zA-Z_-]+:.*## ' $(MAKEFILE_LIST) \
		| sort \
		| awk 'BEGIN {FS = ":.*## "} {printf "  %-15s %s\n", $$1, $$2}'
	@echo ""
	@echo "  DISTRO=$(DISTRO)  RELEASE=$(RELEASE)"

setup: ## Download and tidy Go module dependencies
	@./.make/setup.sh

build: ## Build binary to bin/$(BINARY_NAME)
	@./.make/build.sh

run: tui ## Alias for tui

tui: build ## Run the interactive checklist (Detect + Apply)
	@./bin/$(BINARY_NAME) --distro $(DISTRO) --release $(RELEASE)

test: ## Run tests
	@./.make/test.sh

fmt: ## Format Go sources
	@go fmt ./...

lint: ## Run go vet
	@go vet ./...

quality: fmt lint test ## Format, vet, and test

version: ## Show build version
	@echo "$(VERSION)"

install: build ## Build as user, install to ~/.local/bin
	@./.make/install.sh

install-system: build ## Build as user, install to /usr/local/bin (sudo only for copy)
	@SYSTEM=1 ./.make/install.sh

uninstall: ## Remove from ~/.local/bin and /usr/local/bin (sudo only if needed)
	@./.make/uninstall.sh

clean: ## Remove build artifacts
	@./.make/clean.sh

shellcheck: ## Lint component and .make shell scripts
	@./.make/shellcheck.sh
