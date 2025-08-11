# Simple Makefile for demo install/uninstall helpers

NS ?= llm-d

.PHONY: help demo uninstall

help:
	@echo "Targets:"
	@echo "  demo       - Run scripts/make-demo.sh (installs demo)"
	@echo "  uninstall  - Run scripts/make-demo-uninstall.sh (removes demo)"
	@echo "Variables:"
	@echo "  NS=<namespace> to select namespace (default: llm-d)"

# Keeps existing install flow if you already have scripts/make-demo.sh
# Otherwise it will print a helpful message.
demo:
	@if [ -x scripts/make-demo.sh ]; then \
	  NS=$(NS) scripts/make-demo.sh; \
	else \
	  echo "scripts/make-demo.sh not found or not executable."; \
	  echo "Please create it or adjust the Makefile."; \
	  exit 1; \
	fi

uninstall:
	@NS=$(NS) scripts/make-demo-uninstall.sh

