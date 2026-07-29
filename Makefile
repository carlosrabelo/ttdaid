MAKEFLAGS += --no-print-directory

.DEFAULT_GOAL := help

.PHONY: build clean fmt help setup test version

BINARY_NAME := ttdaid
CMD_PATH    := ./ttdaid/cmd/ttdaid
VERSION := $(shell git describe --tags --always --dirty 2>/dev/null || echo dev)
LDFLAGS := -s -w -X github.com/carlosrabelo/ttdaid/ttdaid/internal/version.Version=$(VERSION)

export BINARY_NAME CMD_PATH VERSION LDFLAGS

help: ## Show available targets
	@echo "ttdaid - Available targets"
	@echo ""
	@grep -hE '^[a-zA-Z_-]+:.*## ' $(MAKEFILE_LIST) \
		| sort \
		| awk 'BEGIN {FS = ":.*## "} {printf "  %-15s %s\n", $$1, $$2}'

setup: ## Download and tidy Go module dependencies
	@./.make/setup.sh

build: ## Build binary to bin/$(BINARY_NAME)
	@./.make/build.sh

test: ## Run tests
	@./.make/test.sh

fmt: ## Format Go sources
	@go fmt ./...

version: ## Show build version
	@echo "$(VERSION)"

clean: ## Remove build artifacts
	@./.make/clean.sh
