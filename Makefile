# Makefile for PodShift
# Provides common operations for Docker to Podman migration on M1 Macs

.PHONY: help setup install clean test lint format discovery system-check docker-inventory dependency-mapping activate deactivate build dist upload docs install-uv sync-uv update-uv

# Default target
.DEFAULT_GOAL := help

# Variables
PYTHON := python3
PIP := pip3

# Detect Python environment setup
# Check for uv setup (.venv directory) vs traditional setup (venv directory)
UV_AVAILABLE := $(shell command -v uv >/dev/null 2>&1 && echo "true" || echo "false")
HAS_UV_VENV := $(shell test -d .venv && echo "true" || echo "false")
HAS_TRADITIONAL_VENV := $(shell test -d venv && echo "true" || echo "false")
HAS_UV_LOCK := $(shell test -f uv.lock && echo "true" || echo "false")

# Determine which approach to use
ifeq ($(HAS_UV_VENV),true)
    VENV_DIR := .venv
    USE_UV := true
else ifeq ($(and $(UV_AVAILABLE:true=),$(HAS_UV_LOCK:true=)),)
    VENV_DIR := .venv
    USE_UV := true
else
    VENV_DIR := venv
    USE_UV := false
endif

# Set Python and package management executables based on detected setup
VENV_PYTHON := $(VENV_DIR)/bin/python
VENV_PIP := $(VENV_DIR)/bin/pip
UV := uv

# Project directories
SCRIPTS_DIR := scripts
DISCOVERY_DIR := $(SCRIPTS_DIR)/discovery
LOGS_DIR := logs
OUTPUT_DIR := .
TIMESTAMP := $(shell date '+%Y%m%d_%H%M%S')

# Colors for output
RED := \033[0;31m
GREEN := \033[0;32m
YELLOW := \033[1;33m
BLUE := \033[0;34m
CYAN := \033[0;36m
NC := \033[0m # No Color

help: ## Show this help message
	@echo "$(CYAN)PodShift - Available Commands$(NC)"
	@echo ""
	@echo "$(YELLOW)Setup and Installation:$(NC)"
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | grep -E "(setup|install|clean|sync|update)" | awk 'BEGIN {FS = ":.*?## "}; {printf "  $(GREEN)%-20s$(NC) %s\n", $$1, $$2}'
	@echo ""
	@echo "$(YELLOW)Discovery and Analysis:$(NC)"
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | grep -E "(discovery|system|docker|dependency)" | awk 'BEGIN {FS = ":.*?## "}; {printf "  $(GREEN)%-20s$(NC) %s\n", $$1, $$2}'
	@echo ""
	@echo "$(YELLOW)Development:$(NC)"
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | grep -E "(test|lint|format|build)" | awk 'BEGIN {FS = ":.*?## "}; {printf "  $(GREEN)%-20s$(NC) %s\n", $$1, $$2}'
	@echo ""
	@echo "$(YELLOW)Environment:$(NC)"
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | grep -E "(activate|deactivate)" | awk 'BEGIN {FS = ":.*?## "}; {printf "  $(GREEN)%-20s$(NC) %s\n", $$1, $$2}'
	@echo ""
	@echo "$(BLUE)Examples:$(NC)"
	@echo "  make setup          # Initial system setup"
	@echo "  make discovery      # Run full Docker discovery"
	@echo "  make system-check   # Check system requirements"
	@echo "  make clean          # Clean generated files"

setup: ## Run complete system setup and install dependencies
	@echo "$(CYAN)Running system setup...$(NC)"
	@bash setup.sh
	@echo "$(GREEN)Setup completed successfully$(NC)"

install: $(VENV_DIR) ## Install Python dependencies in virtual environment
	@echo "$(CYAN)Installing Python dependencies...$(NC)"
ifeq ($(USE_UV),true)
	@if command -v uv >/dev/null 2>&1; then \
		if [ -f uv.lock ]; then \
			echo "$(CYAN)Using uv sync for dependency installation...$(NC)"; \
			$(UV) sync; \
		else \
			echo "$(CYAN)Using uv pip install from requirements.txt...$(NC)"; \
			$(UV) pip install -r requirements.txt; \
		fi; \
		if [ -f pyproject.toml ] && grep -q "\[project.optional-dependencies\]" pyproject.toml; then \
			$(UV) sync --group dev 2>/dev/null || echo "$(YELLOW)Development dependencies not installed (optional)$(NC)"; \
		fi; \
	else \
		echo "$(RED)uv not found but USE_UV=true. Please install uv or use traditional setup.$(NC)"; \
		exit 1; \
	fi
else
	@$(VENV_PIP) install --upgrade pip
	@$(VENV_PIP) install -r requirements.txt
	@if [ -f pyproject.toml ]; then \
		$(VENV_PIP) install -e .[dev] || echo "$(YELLOW)Development dependencies not installed (optional)$(NC)"; \
	fi
endif
	@echo "$(GREEN)Dependencies installed successfully$(NC)"

$(VENV_DIR): ## Create Python virtual environment
	@echo "$(CYAN)Creating Python virtual environment...$(NC)"
ifeq ($(USE_UV),true)
	@if command -v uv >/dev/null 2>&1; then \
		echo "$(CYAN)Creating uv virtual environment...$(NC)"; \
		$(UV) venv $(VENV_DIR); \
	else \
		echo "$(RED)uv not found but USE_UV=true. Creating traditional venv instead...$(NC)"; \
		$(PYTHON) -m venv $(VENV_DIR); \
		$(VENV_PIP) install --upgrade pip; \
	fi
else
	@$(PYTHON) -m venv $(VENV_DIR)
	@$(VENV_PIP) install --upgrade pip
endif
	@echo "$(GREEN)Virtual environment created$(NC)"

activate: ## Show command to activate virtual environment
	@echo "$(CYAN)To activate the virtual environment, run:$(NC)"
	@echo "  source $(VENV_DIR)/bin/activate"
	@echo ""
	@echo "$(CYAN)Or use the activation script:$(NC)"
	@echo "  source ./activate.sh"

deactivate: ## Show command to deactivate virtual environment
	@echo "$(CYAN)To deactivate the virtual environment, run:$(NC)"
	@echo "  deactivate"

discovery: system-check docker-inventory dependency-mapping ## Run complete Docker discovery analysis
	@echo "$(CYAN)Running complete Docker discovery...$(NC)"
	@bash $(DISCOVERY_DIR)/discover_containers.sh --verbose
	@echo "$(GREEN)Discovery completed. Check logs/ directory for results$(NC)"

system-check: ## Check system requirements and resources
	@echo "$(CYAN)Checking system requirements...$(NC)"
	@bash $(DISCOVERY_DIR)/system_resources.sh --verbose
	@echo "$(GREEN)System check completed$(NC)"

docker-inventory: check-venv check-docker ## Run detailed Docker inventory analysis
	@echo "$(CYAN)Running Docker inventory analysis...$(NC)"
	@$(VENV_PYTHON) $(DISCOVERY_DIR)/docker_inventory.py --verbose --output-dir $(OUTPUT_DIR)
	@echo "$(GREEN)Docker inventory completed$(NC)"

dependency-mapping: check-venv check-docker ## Analyze container dependencies
	@echo "$(CYAN)Analyzing container dependencies...$(NC)"
	@$(VENV_PYTHON) $(DISCOVERY_DIR)/dependency_mapper.py --verbose --output-dir $(OUTPUT_DIR)
	@echo "$(GREEN)Dependency mapping completed$(NC)"
# uv-specific targets
install-uv: ## Install dependencies using uv (forces uv usage)
	@echo "$(CYAN)Installing dependencies with uv...$(NC)"
	@if ! command -v uv >/dev/null 2>&1; then \
		echo "$(RED)Error: uv not found. Please install uv first.$(NC)"; \
		exit 1; \
	fi
	@if [ ! -d .venv ]; then \
		echo "$(CYAN)Creating uv virtual environment...$(NC)"; \
		$(UV) venv .venv; \
	fi
	@if [ -f uv.lock ]; then \
		echo "$(CYAN)Syncing dependencies from uv.lock...$(NC)"; \
		$(UV) sync; \
	else \
		echo "$(CYAN)Installing from requirements.txt...$(NC)"; \
		$(UV) pip install -r requirements.txt; \
	fi
	@echo "$(GREEN)uv installation completed$(NC)"

sync-uv: ## Sync dependencies using uv lock file
	@echo "$(CYAN)Syncing dependencies with uv...$(NC)"
	@if ! command -v uv >/dev/null 2>&1; then \
		echo "$(RED)Error: uv not found. Please install uv first.$(NC)"; \
		exit 1; \
	fi
	@if [ -f uv.lock ]; then \
		$(UV) sync; \
		echo "$(GREEN)Dependencies synced from uv.lock$(NC)"; \
	else \
		echo "$(YELLOW)uv.lock not found. Run 'make update-uv' to create it.$(NC)"; \
	fi

update-uv: ## Update dependencies with uv and create/update lock file
	@echo "$(CYAN)Updating dependencies with uv...$(NC)"
	@if ! command -v uv >/dev/null 2>&1; then \
		echo "$(RED)Error: uv not found. Please install uv first.$(NC)"; \
		exit 1; \
	fi
	@if [ ! -d .venv ]; then \
		echo "$(CYAN)Creating uv virtual environment...$(NC)"; \
		$(UV) venv .venv; \
	fi
	@if [ -f pyproject.toml ]; then \
		echo "$(CYAN)Updating from pyproject.toml...$(NC)"; \
		$(UV) lock; \
		$(UV) sync; \
	elif [ -f requirements.txt ]; then \
		echo "$(CYAN)Adding dependencies from requirements.txt...$(NC)"; \
		while IFS= read -r line || [[ -n "$$line" ]]; do \
			[[ "$$line" =~ ^#.*$$ ]] || [[ -z "$$line" ]] && continue; \
			$(UV) add "$$line" 2>/dev/null || echo "$(YELLOW)Failed to add: $$line$(NC)"; \
		done < requirements.txt; \
	fi
	@$(UV) export --format requirements-txt --no-hashes > requirements.txt || echo "$(YELLOW)Failed to update requirements.txt$(NC)"
	@echo "$(GREEN)Dependencies updated and locked$(NC)"

test: check-venv ## Run tests (if test suite exists)
	@echo "$(CYAN)Running tests...$(NC)"
	@if [ -d tests ]; then \
		$(VENV_PYTHON) -m pytest tests/ -v; \
	else \
		echo "$(YELLOW)No tests directory found$(NC)"; \
	fi

lint: check-venv ## Run code linting
	@echo "$(CYAN)Running code linting...$(NC)"
	@if $(VENV_PYTHON) -c "import flake8" 2>/dev/null; then \
		$(VENV_PYTHON) -m flake8 $(SCRIPTS_DIR)/; \
		echo "$(GREEN)Linting completed$(NC)"; \
	else \
		echo "$(YELLOW)flake8 not installed, skipping linting$(NC)"; \
	fi

format: check-venv ## Format code with black
	@echo "$(CYAN)Formatting code...$(NC)"
	@if $(VENV_PYTHON) -c "import black" 2>/dev/null; then \
		$(VENV_PYTHON) -m black $(SCRIPTS_DIR)/; \
		echo "$(GREEN)Code formatting completed$(NC)"; \
	else \
		echo "$(YELLOW)black not installed, skipping formatting$(NC)"; \
	fi

type-check: check-venv ## Run type checking with mypy
	@echo "$(CYAN)Running type checking...$(NC)"
	@if $(VENV_PYTHON) -c "import mypy" 2>/dev/null; then \
		$(VENV_PYTHON) -m mypy $(SCRIPTS_DIR)/; \
		echo "$(GREEN)Type checking completed$(NC)"; \
	else \
		echo "$(YELLOW)mypy not installed, skipping type checking$(NC)"; \
	fi

build: check-venv ## Build distribution packages
	@echo "$(CYAN)Building distribution packages...$(NC)"
	@$(VENV_PYTHON) -m pip install --upgrade build
	@$(VENV_PYTHON) -m build
	@echo "$(GREEN)Build completed. Check dist/ directory$(NC)"

dist: build ## Create distribution packages (alias for build)

clean: ## Clean up generated files and directories
	@echo "$(CYAN)Cleaning up generated files...$(NC)"
	@rm -rf build/
	@rm -rf dist/
	@rm -rf *.egg-info/
	@rm -rf .pytest_cache/
	@rm -rf .mypy_cache/
	@rm -rf htmlcov/
	@find . -type d -name __pycache__ -exec rm -rf {} + 2>/dev/null || true
	@find . -type f -name "*.pyc" -delete 2>/dev/null || true
	@find . -type f -name "*.pyo" -delete 2>/dev/null || true
	@find . -type f -name "*.coverage" -delete 2>/dev/null || true
	@echo "$(GREEN)Cleanup completed$(NC)"

clean-logs: ## Clean up log files (but keep directory)
	@echo "$(CYAN)Cleaning up log files...$(NC)"
	@find $(LOGS_DIR) -name "*.log" -type f -delete 2>/dev/null || true
	@echo "$(GREEN)Log files cleaned$(NC)"

clean-output: ## Clean up generated output files
	@echo "$(CYAN)Cleaning up output files...$(NC)"
	@find . -maxdepth 1 -name "*.json" -type f \( \
		-name "docker_*" -o \
		-name "container_*" -o \
		-name "system_*" \
	\) -delete 2>/dev/null || true
	@echo "$(GREEN)Output files cleaned$(NC)"

clean-all: clean clean-logs clean-output ## Clean everything including logs and output files
	@echo "$(GREEN)Complete cleanup finished$(NC)"

docs: ## Generate documentation (placeholder)
	@echo "$(CYAN)Documentation generation...$(NC)"
	@echo "$(YELLOW)Documentation generation not implemented yet$(NC)"
	@echo "$(BLUE)Check README.md for current documentation$(NC)"

backup-docker: ## Create backup of Docker configuration
	@echo "$(CYAN)Creating Docker configuration backup...$(NC)"
	@mkdir -p backups/docker_config_$(TIMESTAMP)
	@if [ -d ~/.docker ]; then cp -r ~/.docker backups/docker_config_$(TIMESTAMP)/ 2>/dev/null || true; fi
	@if command -v docker >/dev/null 2>&1; then \
		docker context export default backups/docker_config_$(TIMESTAMP)/default_context.tar 2>/dev/null || true; \
	fi
	@echo "$(GREEN)Docker configuration backed up to backups/docker_config_$(TIMESTAMP)/$(NC)"

check-requirements: ## Check if system requirements are met
	@echo "$(CYAN)Checking system requirements...$(NC)"
	@echo "macOS version: $$(sw_vers -productVersion)"
	@echo "Architecture: $$(uname -m)"
	@if command -v docker >/dev/null 2>&1; then \
		echo "Docker: $$(docker --version)"; \
	else \
		echo "$(YELLOW)Docker: Not installed$(NC)"; \
	fi
	@if command -v jq >/dev/null 2>&1; then \
		echo "jq: $$(jq --version)"; \
	else \
		echo "$(YELLOW)jq: Not installed$(NC)"; \
	fi
	@if [ -d $(VENV_DIR) ]; then \
		echo "Python venv: $(GREEN)Present$(NC)"; \
	else \
		echo "Python venv: $(YELLOW)Not created$(NC)"; \
	fi

# Helper targets (internal)
check-venv: ## Check if virtual environment exists
	@if [ ! -d $(VENV_DIR) ]; then \
		echo "$(RED)Virtual environment not found at $(VENV_DIR). Run 'make setup' or 'make install' first.$(NC)"; \
		exit 1; \
	fi

check-docker: ## Check if Docker is available
	@if ! command -v docker >/dev/null 2>&1; then \
		echo "$(YELLOW)Warning: Docker not found. Some operations may not work.$(NC)"; \
	elif ! docker info >/dev/null 2>&1; then \
		echo "$(YELLOW)Warning: Docker daemon not running. Some operations may not work.$(NC)"; \
	fi

# Create necessary directories
$(LOGS_DIR):
	@mkdir -p $(LOGS_DIR)

# Status report
status: check-requirements ## Show current project status
	@echo "$(CYAN)Project Status Report$(NC)"
	@echo "===================="
	@echo ""
	@echo "$(YELLOW)Environment:$(NC)"
	@echo "  Python Manager: $(CYAN)$(if $(filter true,$(USE_UV)),uv workflow,traditional pip/venv)$(NC)"
	@echo "  Virtual Env Dir: $(CYAN)$(VENV_DIR)$(NC)"
	@if command -v uv >/dev/null 2>&1; then \
		echo "  uv Available: $(GREEN)✓ $(shell uv --version)$(NC)"; \
	else \
		echo "  uv Available: $(YELLOW)✗ Not installed$(NC)"; \
	fi
	@if [ -f uv.lock ]; then \
		echo "  uv.lock: $(GREEN)✓ Present$(NC)"; \
	else \
		echo "  uv.lock: $(YELLOW)✗ Not found$(NC)"; \
	fi
	@if [ -d $(VENV_DIR) ]; then \
		echo "  Virtual Environment: $(GREEN)✓ Present at $(VENV_DIR)$(NC)"; \
		if [ -f $(VENV_DIR)/bin/python ]; then \
			echo "  Python Version: $$($(VENV_PYTHON) --version)"; \
		fi; \
	else \
		echo "  Virtual Environment: $(RED)✗ Missing$(NC)"; \
	fi
	@echo ""
	@echo "$(YELLOW)Dependencies:$(NC)"
	@if $(VENV_PYTHON) -c "import docker" 2>/dev/null; then \
		echo "  Docker SDK: $(GREEN)✓ Installed$(NC)"; \
	else \
		echo "  Docker SDK: $(RED)✗ Missing$(NC)"; \
	fi
	@if $(VENV_PYTHON) -c "import yaml" 2>/dev/null; then \
		echo "  PyYAML: $(GREEN)✓ Installed$(NC)"; \
	else \
		echo "  PyYAML: $(RED)✗ Missing$(NC)"; \
	fi
	@echo ""
	@echo "$(YELLOW)Recent Files:$(NC)"
	@if [ -d $(LOGS_DIR) ] && [ "$$(ls -A $(LOGS_DIR) 2>/dev/null)" ]; then \
		echo "  Latest Log: $$(ls -t $(LOGS_DIR)/*.log 2>/dev/null | head -1 | xargs basename 2>/dev/null || echo 'None')"; \
	else \
		echo "  Latest Log: None"; \
	fi
	@echo "  Output Files: $$(ls -1 *.json 2>/dev/null | wc -l | tr -d ' ') JSON files"

# Quick start
quick-start: setup discovery ## Quick start: setup and run discovery
	@echo "$(GREEN)Quick start completed! Check the logs/ directory for results.$(NC)"