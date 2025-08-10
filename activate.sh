#!/bin/bash
# activate.sh - Activate the PodShift environment
# Supports both traditional venv and modern uv virtual environments

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" &> /dev/null && pwd)"
VENV_DIR="$SCRIPT_DIR/venv"
UV_VENV_DIR="$SCRIPT_DIR/.venv"

# Color codes for output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Function to detect setup type
detect_setup_type() {
    if [[ -d "$UV_VENV_DIR" ]] && command -v uv >/dev/null 2>&1; then
        echo "uv"
    elif [[ -d "$VENV_DIR" ]]; then
        echo "venv"
    else
        echo "none"
    fi
}

# Function to activate uv environment
activate_uv_env() {
    echo -e "${GREEN}Detected modern uv setup${NC}"
    
    # Check if uv.lock exists for proper uv project
    if [[ -f "$SCRIPT_DIR/uv.lock" ]]; then
        echo -e "${BLUE}This project uses uv for dependency management${NC}"
        echo ""
        echo "To run Python commands, use one of:"
        echo -e "  ${YELLOW}uv run python [script.py]${NC}     # Run Python scripts"
        echo -e "  ${YELLOW}uv run python -m [module]${NC}     # Run Python modules"
        echo -e "  ${YELLOW}uv shell${NC}                      # Enter uv shell (if available)"
        echo ""
        echo "Examples:"
        echo "  uv run python scripts/discovery/docker_inventory.py --help"
        echo "  uv run python -m pytest"
        
        # Try to enter uv shell if available
        if uv shell --help >/dev/null 2>&1; then
            echo ""
            echo -e "${GREEN}Entering uv shell...${NC}"
            exec uv shell
        else
            echo ""
            echo -e "${YELLOW}Note: 'uv shell' not available in this uv version.${NC}"
            echo "Use 'uv run' commands above to execute Python code."
        fi
    else
        echo -e "${YELLOW}Warning: .venv directory found but no uv.lock file${NC}"
        echo "This might be a manually created .venv directory."
        echo ""
        echo "You can either:"
        echo "1. Use traditional activation: source .venv/bin/activate"
        echo "2. Initialize uv project: uv init"
        echo ""
        echo "Attempting traditional activation..."
        source "$UV_VENV_DIR/bin/activate"
        if [[ "$VIRTUAL_ENV" != "" ]]; then
            echo -e "${GREEN}Environment activated. Python: $(which python)${NC}"
            echo -e "To deactivate, run: ${YELLOW}deactivate${NC}"
        else
            echo -e "${RED}Failed to activate .venv environment${NC}"
            exit 1
        fi
    fi
}

# Function to activate traditional venv
activate_venv_env() {
    echo -e "${GREEN}Detected traditional venv setup${NC}"
    echo "Activating Python virtual environment..."
    source "$VENV_DIR/bin/activate"
    
    if [[ "$VIRTUAL_ENV" != "" ]]; then
        echo -e "${GREEN}Environment activated. Python: $(which python)${NC}"
        echo -e "To deactivate, run: ${YELLOW}deactivate${NC}"
    else
        echo -e "${RED}Failed to activate virtual environment${NC}"
        exit 1
    fi
}

# Main activation logic
setup_type=$(detect_setup_type)

case "$setup_type" in
    "uv")
        activate_uv_env
        ;;
    "venv")
        activate_venv_env
        ;;
    "none")
        echo -e "${RED}No virtual environment found${NC}"
        echo ""
        echo "Expected one of:"
        echo -e "  • ${YELLOW}.venv/${NC} (modern uv setup)"
        echo -e "  • ${YELLOW}venv/${NC} (traditional setup)"
        echo ""
        echo "To create a virtual environment:"
        echo -e "  • Traditional: ${YELLOW}./setup.sh --use-homebrew${NC}"
        echo -e "  • Modern: ${YELLOW}./setup.sh --use-pyenv-uv${NC}"
        echo -e "  • Auto-detect: ${YELLOW}./setup.sh${NC}"
        echo ""
        exit 1
        ;;
esac
