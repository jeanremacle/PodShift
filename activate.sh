#!/bin/bash

# activate.sh - Activate the PodShift environment
# This script activates the Python virtual environment and sets up the environment
# for running PodShift on macOS.

set -eo pipefail

# Script configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" &> /dev/null && pwd)"
PROJECT_NAME="PodShift"

# Detect virtual environment type and set variables
VENV_TYPE=""
VENV_DIR=""
PYTHON_MANAGER=""

# Check for uv virtual environment first (.venv)
if [[ -d "$SCRIPT_DIR/.venv" ]]; then
    VENV_DIR="$SCRIPT_DIR/.venv"
    VENV_TYPE="uv"
    PYTHON_MANAGER="uv"
# Fall back to traditional venv (venv/)
elif [[ -d "$SCRIPT_DIR/venv" ]]; then
    VENV_DIR="$SCRIPT_DIR/venv"
    VENV_TYPE="venv"
    PYTHON_MANAGER="pip/venv"
fi

# Color codes for output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Check if any virtual environment exists
if [[ -z "$VENV_DIR" ]]; then
    echo -e "${RED}❌ No virtual environment found${NC}"
    echo -e "${YELLOW}💡 No virtual environment detected in either .venv or venv directory${NC}"
    echo -e "${YELLOW}💡 Run setup.sh first to create the environment:${NC}"
    echo -e "   ${CYAN}./setup.sh${NC}"
    exit 1
fi

# Check if virtual environment has Python
if [[ ! -f "$VENV_DIR/bin/python" ]]; then
    if [[ "$VENV_TYPE" == "uv" ]]; then
        echo -e "${RED}❌ Python not found in uv virtual environment (.venv)${NC}"
        echo -e "${YELLOW}💡 Virtual environment may be corrupted. Recreate it:${NC}"
        echo -e "   ${CYAN}rm -rf .venv && ./setup.sh${NC}"
    else
        echo -e "${RED}❌ Python not found in traditional virtual environment (venv)${NC}"
        echo -e "${YELLOW}💡 Virtual environment may be corrupted. Recreate it:${NC}"
        echo -e "   ${CYAN}rm -rf venv && ./setup.sh${NC}"
    fi
    exit 1
fi

# Activate the virtual environment
if [[ "$VENV_TYPE" == "uv" ]]; then
    echo -e "${CYAN}🚀 Activating $PROJECT_NAME environment (uv/.venv)...${NC}"
else
    echo -e "${CYAN}🚀 Activating $PROJECT_NAME environment (traditional/venv)...${NC}"
fi

source "$VENV_DIR/bin/activate"

# Verify activation
if [[ "$VIRTUAL_ENV" != "$VENV_DIR" ]]; then
    echo -e "${RED}❌ Failed to activate virtual environment${NC}"
    exit 1
fi

# Display environment information
echo -e "${GREEN}✅ Environment activated successfully!${NC}"
echo ""
echo -e "${BLUE}📋 Environment Information:${NC}"
echo -e "   Python: ${CYAN}$(python --version)${NC}"
echo -e "   Virtual Environment: ${CYAN}$VIRTUAL_ENV${NC}"
echo -e "   Environment Type: ${CYAN}$VENV_TYPE ${NC}(${CYAN}$PYTHON_MANAGER${NC})"
echo -e "   Environment Directory: ${CYAN}$(basename "$VENV_DIR")${NC}"
echo -e "   Project Directory: ${CYAN}$SCRIPT_DIR${NC}"

# Check if required dependencies are installed
echo ""
echo -e "${BLUE}🔍 Checking dependencies...${NC}"

# Check Python manager availability
if [[ "$VENV_TYPE" == "uv" ]]; then
    if command -v uv >/dev/null 2>&1; then
        echo -e "   ${GREEN}✅${NC} uv: Available ($(uv --version 2>/dev/null || echo "version unknown"))"
    else
        echo -e "   ${YELLOW}⚠️${NC}  uv: Not found (install with: pip install uv or brew install uv)"
    fi
fi

# Check Python packages
dependencies_ok=true

if python -c "import docker" 2>/dev/null; then
    echo -e "   ${GREEN}✅${NC} Docker SDK: Available"
else
    echo -e "   ${RED}❌${NC} Docker SDK: Missing"
    dependencies_ok=false
fi

if python -c "import yaml" 2>/dev/null; then
    echo -e "   ${GREEN}✅${NC} PyYAML: Available"
else
    echo -e "   ${RED}❌${NC} PyYAML: Missing"
    dependencies_ok=false
fi

# Check system tools
if command -v jq >/dev/null 2>&1; then
    echo -e "   ${GREEN}✅${NC} jq: Available"
else
    echo -e "   ${YELLOW}⚠️${NC}  jq: Not found (install with: brew install jq)"
fi

if command -v docker >/dev/null 2>&1; then
    if docker info >/dev/null 2>&1; then
        echo -e "   ${GREEN}✅${NC} Docker: Running"
    else
        echo -e "   ${YELLOW}⚠️${NC}  Docker: Installed but not running"
    fi
else
    echo -e "   ${YELLOW}⚠️${NC}  Docker: Not installed"
fi

# Display usage information
echo ""
if [[ "$dependencies_ok" == "true" ]]; then
    echo -e "${GREEN}🎉 All core dependencies are available!${NC}"
else
    echo -e "${YELLOW}⚠️  Some dependencies are missing. Install them with:${NC}"
    if [[ "$VENV_TYPE" == "uv" ]]; then
        echo -e "   ${CYAN}uv add -r requirements.txt${NC}     # Install with uv"
        echo -e "   ${CYAN}pip install -r requirements.txt${NC} # Or use pip"
    else
        echo -e "   ${CYAN}pip install -r requirements.txt${NC}"
    fi
fi

echo ""
echo -e "${BLUE}🛠️  Available Commands:${NC}"
echo -e "   ${CYAN}make help${NC}                    # Show all available commands"
echo -e "   ${CYAN}make discovery${NC}               # Run full Docker discovery"
echo -e "   ${CYAN}make system-check${NC}            # Check system requirements"
echo -e "   ${CYAN}make status${NC}                  # Show project status"
echo ""
echo -e "${BLUE}📊 Discovery Scripts:${NC}"
echo -e "   ${CYAN}python scripts/discovery/docker_inventory.py --help${NC}"
echo -e "   ${CYAN}python scripts/discovery/dependency_mapper.py --help${NC}"
echo -e "   ${CYAN}bash scripts/discovery/system_resources.sh --help${NC}"
echo -e "   ${CYAN}bash scripts/discovery/discover_containers.sh --help${NC}"
echo ""

# Environment-specific commands
if [[ "$VENV_TYPE" == "uv" ]]; then
    echo -e "${BLUE}🔧 uv Commands (detected uv environment):${NC}"
    echo -e "   ${CYAN}uv add <package>${NC}           # Add a new dependency"
    echo -e "   ${CYAN}uv remove <package>${NC}        # Remove a dependency"
    echo -e "   ${CYAN}uv sync${NC}                    # Sync dependencies"
    echo -e "   ${CYAN}uv lock${NC}                    # Update lock file"
    echo ""
fi

echo -e "${BLUE}💡 Quick Start:${NC}"
echo -e "   ${CYAN}make system-check${NC}            # Check your system"
echo -e "   ${CYAN}make discovery${NC}               # Analyze Docker setup"
echo ""
echo -e "${YELLOW}📝 To deactivate this environment later, run:${NC} ${CYAN}deactivate${NC}"
echo ""

# Set additional environment variables for PodShift
export PODSHIFT_ROOT="$SCRIPT_DIR"
export PODSHIFT_LOGS="$SCRIPT_DIR/logs"
export PODSHIFT_ACTIVE=1

# Add project scripts to PATH for convenience
export PATH="$SCRIPT_DIR/scripts/discovery:$PATH"

# Create alias for common operations
alias ps-help='make help'
alias ps-discovery='make discovery'
alias ps-system='make system-check'
alias ps-status='make status'
alias ps-clean='make clean'

# Add environment-specific aliases
if [[ "$VENV_TYPE" == "uv" ]]; then
    alias ps-add='uv add'
    alias ps-remove='uv remove'
    alias ps-sync='uv sync'
    alias ps-lock='uv lock'
    echo -e "${GREEN}🔧 Environment variables and aliases set up!${NC}"
    echo -e "${BLUE}   Standard aliases: ${CYAN}ps-help, ps-discovery, ps-system, ps-status, ps-clean${NC}"
    echo -e "${BLUE}   uv aliases: ${CYAN}ps-add, ps-remove, ps-sync, ps-lock${NC}"
else
    echo -e "${GREEN}🔧 Environment variables and aliases set up!${NC}"
    echo -e "${BLUE}   Available aliases: ${CYAN}ps-help, ps-discovery, ps-system, ps-status, ps-clean${NC}"
fi