#!/bin/bash

# setup.sh - System Dependencies and Initial Setup Script
# Part of PodShift for M1 Macs
#
# This script installs required system dependencies and sets up the environment
# for running PodShift on macOS.

set -euo pipefail

# Script configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" &> /dev/null && pwd)"
PROJECT_ROOT="$SCRIPT_DIR"
LOGS_DIR="$PROJECT_ROOT/logs"
TIMESTAMP=$(date '+%Y%m%d_%H%M%S')
LOG_FILE="$LOGS_DIR/setup_$TIMESTAMP.log"
VERBOSE=false
SKIP_PYTHON_SETUP=false
SKIP_HOMEBREW_INSTALL=false

# Python management configuration
PYTHON_MANAGER="pyenv"      # homebrew|pyenv (default: pyenv for backward compatibility)
DEPENDENCY_TOOL="uv"        # pip|uv (default: uv for backward compatibility)
MIGRATION_MODE=false
FORCE_CLEANUP=false
AUTO_DETECT=true

# Minimum requirements
MIN_MACOS_VERSION="12.0"
MIN_PYTHON_VERSION="3.11"
REQUIRED_PYTHON_VERSION="3.11"

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Initialize logging
log() {
    local level="$1"
    shift
    local message="$*"
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    echo -e "[$timestamp] [$level] $message" | tee -a "$LOG_FILE"
}

log_info() {
    log "INFO" "$@"
    if [[ "$VERBOSE" == "true" ]]; then
        echo -e "${BLUE}[INFO]${NC} $*"
    fi
}

log_warn() {
    log "WARN" "$@"
    echo -e "${YELLOW}[WARN]${NC} $*"
}

log_error() {
    log "ERROR" "$@"
    echo -e "${RED}[ERROR]${NC} $*"
}

log_success() {
    log "SUCCESS" "$@"
    echo -e "${GREEN}[SUCCESS]${NC} $*"
}

log_header() {
    log "HEADER" "$@"
    echo -e "${CYAN}=== $* ===${NC}"
}

# Help function
show_help() {
    cat << EOF
PodShift - System Setup Script

USAGE:
    $0 [OPTIONS]

OPTIONS:
    -v, --verbose              Enable verbose output
    -h, --help                Show this help message
    --skip-python-setup       Skip Python environment setup
    --skip-homebrew-install    Skip Homebrew installation check
    --python-version VERSION   Specify Python version to use (default: $REQUIRED_PYTHON_VERSION)

PYTHON MANAGEMENT OPTIONS:
    --python-manager MODE      Python version manager: homebrew|pyenv (default: homebrew)
    --dependency-tool TOOL     Dependency manager: pip|uv (default: pip)
    --use-pyenv-uv            Shortcut for --python-manager pyenv --dependency-tool uv
    --use-homebrew            Shortcut for --python-manager homebrew --dependency-tool pip
    --migration-mode          Interactive migration from existing setup
    --auto-detect             Auto-detect existing Python setup (default: enabled)
    --no-auto-detect          Disable auto-detection, use explicit options

DESCRIPTION:
    This script sets up the system dependencies required for PodShift
    on macOS (M1/M2/M3 Macs). It supports both traditional Homebrew + pip/venv
    setup and modern pyenv + uv setup for improved performance and reproducibility.

PYTHON SETUP MODES:
    Homebrew Mode (Traditional):
        - Installs Python via Homebrew
        - Uses pip and venv for dependency management
        - Backward compatible with existing setups

    pyenv + uv Mode (Modern):
        - Installs Python via pyenv for version management
        - Uses uv for fast dependency resolution
        - Creates uv.lock for reproducible builds
        - Maintains requirements.txt compatibility

DEPENDENCIES INSTALLED:
    - Python version manager (Homebrew or pyenv)
    - Python $REQUIRED_PYTHON_VERSION+
    - Dependency tool (pip or uv)
    - jq (JSON processor)
    - git (version control)
    - curl and wget (download tools)

SYSTEM REQUIREMENTS:
    - macOS $MIN_MACOS_VERSION or later
    - Apple Silicon Mac (M1/M2/M3) recommended
    - At least 4GB free disk space
    - Administrative privileges for system installations

EXAMPLES:
    $0                                    # Default Homebrew setup
    $0 --use-pyenv-uv                    # Modern pyenv + uv setup
    $0 --migration-mode                  # Interactive migration
    $0 --python-manager pyenv --verbose  # pyenv with pip, verbose output

EOF
}

# Parse command line arguments
parse_args() {
    while [[ $# -gt 0 ]]; do
        case $1 in
            -v|--verbose)
                VERBOSE=true
                shift
                ;;
            -h|--help)
                show_help
                exit 0
                ;;
            --skip-python-setup)
                SKIP_PYTHON_SETUP=true
                shift
                ;;
            --skip-homebrew-install)
                SKIP_HOMEBREW_INSTALL=true
                shift
                ;;
            --python-version)
                REQUIRED_PYTHON_VERSION="$2"
                shift 2
                ;;
            --python-manager)
                if [[ "$2" == "homebrew" || "$2" == "pyenv" ]]; then
                    PYTHON_MANAGER="$2"
                    AUTO_DETECT=false
                else
                    log_error "Invalid python-manager: $2. Must be 'homebrew' or 'pyenv'"
                    exit 1
                fi
                shift 2
                ;;
            --dependency-tool)
                if [[ "$2" == "pip" || "$2" == "uv" ]]; then
                    DEPENDENCY_TOOL="$2"
                    AUTO_DETECT=false
                else
                    log_error "Invalid dependency-tool: $2. Must be 'pip' or 'uv'"
                    exit 1
                fi
                shift 2
                ;;
            --use-pyenv-uv)
                PYTHON_MANAGER="pyenv"
                DEPENDENCY_TOOL="uv"
                AUTO_DETECT=false
                shift
                ;;
            --use-homebrew)
                PYTHON_MANAGER="homebrew"
                DEPENDENCY_TOOL="pip"
                AUTO_DETECT=false
                shift
                ;;
            --migration-mode)
                MIGRATION_MODE=true
                shift
                ;;
            --auto-detect)
                AUTO_DETECT=true
                shift
                ;;
            --no-auto-detect)
                AUTO_DETECT=false
                shift
                ;;
            --force-cleanup)
                FORCE_CLEANUP=true
                shift
                ;;
            *)
                log_error "Unknown option: $1"
                show_help
                exit 1
                ;;
        esac
    done
}

# Detect existing Python setup
detect_existing_python_setup() {
    local setup_type="none"
    local detected_manager="homebrew"
    local detected_tool="pip"
    
    # Check for pyenv setup
    if [[ -f ".python-version" ]] && command -v pyenv >/dev/null 2>&1; then
        setup_type="pyenv"
        detected_manager="pyenv"
        
        # Check if uv is available and preferred
        if command -v uv >/dev/null 2>&1 && [[ -f "uv.lock" ]]; then
            detected_tool="uv"
        fi
    elif [[ -d "venv" ]] && [[ -f "venv/pyvenv.cfg" ]]; then
        # Check if it's a standard venv setup
        setup_type="venv"
        detected_manager="homebrew"  # Assume Homebrew Python for macOS
        
        if command -v uv >/dev/null 2>&1; then
            detected_tool="uv"
        fi
    fi
    
    echo "$setup_type:$detected_manager:$detected_tool"
}

# Auto-detect and configure Python setup
configure_python_setup() {
    if [[ "$AUTO_DETECT" == "true" ]]; then
        log_info "Auto-detecting existing Python setup..."
        
        local detection_result
        detection_result=$(detect_existing_python_setup)
        local setup_type="${detection_result%%:*}"
        local detected_manager="${detection_result#*:}"
        detected_manager="${detected_manager%%:*}"
        local detected_tool="${detection_result##*:}"
        
        case "$setup_type" in
            "pyenv")
                log_success "Detected existing pyenv setup"
                PYTHON_MANAGER="pyenv"
                DEPENDENCY_TOOL="$detected_tool"
                ;;
            "venv")
                log_success "Detected existing venv setup"
                PYTHON_MANAGER="homebrew"  # Keep existing Homebrew setup
                DEPENDENCY_TOOL="$detected_tool"
                ;;
            "none")
                log_info "No existing Python setup detected, using defaults"
                # Keep default values
                ;;
        esac
    fi
    
    # Validate configuration
    if [[ "$PYTHON_MANAGER" == "pyenv" && "$DEPENDENCY_TOOL" == "uv" ]]; then
        log_info "Using modern Python setup: pyenv + uv"
    elif [[ "$PYTHON_MANAGER" == "homebrew" && "$DEPENDENCY_TOOL" == "pip" ]]; then
        log_info "Using traditional Python setup: Homebrew + pip/venv"
    else
        log_info "Using hybrid Python setup: $PYTHON_MANAGER + $DEPENDENCY_TOOL"
    fi
}

# Migration mode handler
handle_migration_mode() {
    if [[ "$MIGRATION_MODE" == "true" ]]; then
        log_header "Migration Mode - Interactive Setup"
        
        local current_setup
        current_setup=$(detect_existing_python_setup)
        local setup_type="${current_setup%%:*}"
        
        if [[ "$setup_type" == "none" ]]; then
            log_info "No existing setup detected. Would you like to:"
            echo "1) Use Homebrew + pip (traditional, stable)"
            echo "2) Use pyenv + uv (modern, faster)"
            read -p "Choose (1 or 2): " choice
            
            case "$choice" in
                1)
                    PYTHON_MANAGER="homebrew"
                    DEPENDENCY_TOOL="pip"
                    ;;
                2)
                    PYTHON_MANAGER="pyenv"
                    DEPENDENCY_TOOL="uv"
                    ;;
                *)
                    log_error "Invalid choice. Using defaults."
                    ;;
            esac
        else
            log_info "Detected existing $setup_type setup. Migration options:"
            echo "1) Keep current setup"
            echo "2) Migrate to pyenv + uv"
            echo "3) Migrate to Homebrew + pip"
            read -p "Choose (1, 2, or 3): " choice
            
            case "$choice" in
                1)
                    log_info "Keeping existing setup"
                    configure_python_setup
                    return
                    ;;
                2)
                    PYTHON_MANAGER="pyenv"
                    DEPENDENCY_TOOL="uv"
                    log_info "Will migrate to pyenv + uv"
                    ;;
                3)
                    PYTHON_MANAGER="homebrew"
                    DEPENDENCY_TOOL="pip"
                    log_info "Will migrate to Homebrew + pip"
                    ;;
                *)
                    log_error "Invalid choice. Keeping existing setup."
                    configure_python_setup
                    return
                    ;;
            esac
        fi
        
        AUTO_DETECT=false  # Disable auto-detection after manual choice
    fi
}

# Install and setup pyenv
setup_pyenv() {
    if [[ "$PYTHON_MANAGER" != "pyenv" ]]; then
        return 0
    fi
    
    log_header "Setting up pyenv"
    
    # Check if pyenv is already installed
    if ! command -v pyenv >/dev/null 2>&1; then
        log_info "Installing pyenv..."
        
        # Try Homebrew first if available
        if command -v brew >/dev/null 2>&1; then
            if brew install pyenv; then
                log_success "pyenv installed via Homebrew"
            else
                log_error "Failed to install pyenv via Homebrew"
                return 1
            fi
        else
            # Fallback to official installer
            log_info "Installing pyenv via official installer..."
            if curl https://pyenv.run | bash; then
                log_success "pyenv installed via official installer"
            else
                log_error "Failed to install pyenv"
                return 1
            fi
        fi
    else
        log_success "pyenv is already installed"
        local pyenv_version=$(pyenv --version)
        log_info "$pyenv_version"
    fi
    
    # Setup pyenv shell integration
    setup_pyenv_shell_integration
    
    # Install required Python version
    install_python_via_pyenv
    
    log_success "pyenv setup completed"
}

# Setup pyenv shell integration
setup_pyenv_shell_integration() {
    log_info "Setting up pyenv shell integration..."
    
    # Determine shell configuration file
    local shell_config=""
    case "$SHELL" in
        */zsh)
            shell_config="$HOME/.zshrc"
            ;;
        */bash)
            shell_config="$HOME/.bash_profile"
            ;;
        *)
            log_warn "Unknown shell: $SHELL. Manual pyenv setup may be required."
            return 1
            ;;
    esac
    
    # Check if pyenv is already in shell config
    if [[ -f "$shell_config" ]] && grep -q "pyenv init" "$shell_config"; then
        log_info "pyenv shell integration already configured"
        return 0
    fi
    
    # Add pyenv initialization to shell config
    log_info "Adding pyenv to $shell_config..."
    cat >> "$shell_config" << 'EOF'

# pyenv configuration added by PodShift setup
export PYENV_ROOT="$HOME/.pyenv"
[[ -d $PYENV_ROOT/bin ]] && export PATH="$PYENV_ROOT/bin:$PATH"
eval "$(pyenv init -)"

EOF
    
    # Source the configuration for current session
    export PYENV_ROOT="$HOME/.pyenv"
    [[ -d $PYENV_ROOT/bin ]] && export PATH="$PYENV_ROOT/bin:$PATH"
    eval "$(pyenv init -)" 2>/dev/null || true
    
    log_success "pyenv shell integration configured"
}

# Install Python version via pyenv
install_python_via_pyenv() {
    log_info "Installing Python $REQUIRED_PYTHON_VERSION via pyenv..."
    
    # Check if pyenv is working properly
    if ! pyenv versions >/dev/null 2>&1; then
        log_error "pyenv command failed. Ensure pyenv is properly installed and initialized."
        return 1
    fi
    
    # Check if the required version is already installed (fixed regex)
    if pyenv versions --bare | grep -q "^${REQUIRED_PYTHON_VERSION}\\(\\.\\|$\\)"; then
        log_success "Python $REQUIRED_PYTHON_VERSION is already installed via pyenv"
    else
        log_info "Installing Python $REQUIRED_PYTHON_VERSION..."
        if pyenv install "$REQUIRED_PYTHON_VERSION"; then
            log_success "Python $REQUIRED_PYTHON_VERSION installed successfully"
        else
            log_error "Failed to install Python $REQUIRED_PYTHON_VERSION via pyenv"
            return 1
        fi
    fi
    
    # Set local Python version for the project
    log_info "Setting project Python version to $REQUIRED_PYTHON_VERSION..."
    if ! pyenv local "$REQUIRED_PYTHON_VERSION"; then
        log_error "Failed to set local Python version to $REQUIRED_PYTHON_VERSION"
        return 1
    fi
    
    # Verify installation (improved verification)
    if pyenv version-name >/dev/null 2>&1; then
        local python_version=$(pyenv version-name)
        log_success "Active Python version: $python_version"
        
        # Verify it matches our requirement
        if [[ "$python_version" =~ ^${REQUIRED_PYTHON_VERSION}(\.|$) ]]; then
            log_success "Python version verification passed"
        else
            log_warn "Active version ($python_version) doesn't match required version ($REQUIRED_PYTHON_VERSION)"
        fi
    else
        log_error "Failed to verify Python installation"
        return 1
    fi
}

# Install and setup uv
setup_uv() {
    if [[ "$DEPENDENCY_TOOL" != "uv" ]]; then
        return 0
    fi
    
    log_header "Setting up uv"
    
    # Check if uv is already installed
    if ! command -v uv >/dev/null 2>&1; then
        log_info "Installing uv..."
        
        # Try Homebrew first if available
        if command -v brew >/dev/null 2>&1; then
            if brew install uv; then
                log_success "uv installed via Homebrew"
            else
                log_warn "Failed to install uv via Homebrew, trying official installer..."
                install_uv_official
            fi
        else
            install_uv_official
        fi
    else
        log_success "uv is already installed"
        local uv_version=$(uv --version)
        log_info "$uv_version"
    fi
    
    log_success "uv setup completed"
}

# Install uv via official installer
install_uv_official() {
    log_info "Installing uv via official installer..."
    if curl -LsSf https://astral.sh/uv/install.sh | sh; then
        log_success "uv installed via official installer"
        # Add uv to PATH for current session
        export PATH="$HOME/.cargo/bin:$PATH"
    else
        log_error "Failed to install uv"
        return 1
    fi
}

# Check system requirements
check_system_requirements() {
    log_header "Checking System Requirements"
    
    # Check macOS version
    if [[ "$(uname -s)" != "Darwin" ]]; then
        log_error "This script requires macOS"
        exit 1
    fi
    
    local macos_version=$(sw_vers -productVersion)
    log_info "macOS version: $macos_version"
    
    # Simple version comparison (works for most cases)
    if [[ "$(printf '%s\n' "$MIN_MACOS_VERSION" "$macos_version" | sort -V | head -n1)" != "$MIN_MACOS_VERSION" ]]; then
        log_error "macOS version $macos_version is below minimum requirement $MIN_MACOS_VERSION"
        exit 1
    fi
    
    # Check architecture
    local architecture=$(uname -m)
    log_info "Architecture: $architecture"
    
    if [[ "$architecture" == "arm64" ]]; then
        log_success "Apple Silicon Mac detected - optimal for Podman"
    else
        log_warn "Intel Mac detected - Podman will work but Apple Silicon is recommended"
    fi
    
    # Check available disk space
    local available_space=$(df -h . | tail -1 | awk '{print $4}' | sed 's/G.*//')
    if [[ "$available_space" =~ ^[0-9]+$ ]] && [[ "$available_space" -lt 4 ]]; then
        log_warn "Available disk space is low ($available_space GB). Recommend at least 4GB free space."
    fi
    
    log_success "System requirements check passed"
}

# Install or check Homebrew
setup_homebrew() {
    if [[ "$SKIP_HOMEBREW_INSTALL" == "true" ]]; then
        log_info "Skipping Homebrew installation check"
        return 0
    fi
    
    log_header "Setting up Homebrew"
    
    if command -v brew >/dev/null 2>&1; then
        log_success "Homebrew is already installed"
        local brew_version=$(brew --version | head -1)
        log_info "$brew_version"
        
        # Update Homebrew
        log_info "Updating Homebrew..."
        brew update || log_warn "Failed to update Homebrew"
    else
        log_info "Installing Homebrew..."
        if /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"; then
            log_success "Homebrew installed successfully"
            
            # Add Homebrew to PATH for Apple Silicon Macs
            if [[ "$(uname -m)" == "arm64" ]]; then
                echo 'eval "$(/opt/homebrew/bin/brew shellenv)"' >> ~/.zprofile
                eval "$(/opt/homebrew/bin/brew shellenv)"
            fi
        else
            log_error "Failed to install Homebrew"
            exit 1
        fi
    fi
}

# Install system dependencies
install_system_dependencies() {
    log_header "Installing System Dependencies"
    
    local packages=(
        "jq"          # JSON processor
        "git"         # Version control
        "curl"        # Download tool
        "wget"        # Download tool
    )
    
    # Add Python to packages only if using Homebrew
    if [[ "$PYTHON_MANAGER" == "homebrew" ]]; then
        packages+=("python@$REQUIRED_PYTHON_VERSION")
    fi
    
    # Check if Docker is installed (we're migrating from it)
    if ! command -v docker >/dev/null 2>&1; then
        log_warn "Docker not found - you may need to install Docker Desktop to migrate from"
        log_info "Download from: https://www.docker.com/products/docker-desktop/"
    else
        local docker_version=$(docker --version 2>/dev/null || echo "Unknown version")
        log_info "Docker found: $docker_version"
    fi
    
    # Skip Homebrew package installation if not using Homebrew and Homebrew install is skipped
    if [[ "$PYTHON_MANAGER" != "homebrew" && "$SKIP_HOMEBREW_INSTALL" == "true" ]]; then
        log_info "Skipping Homebrew package installation (using $PYTHON_MANAGER)"
        return 0
    fi
    
    for package in "${packages[@]}"; do
        log_info "Checking/installing $package..."
        
        if brew list "$package" >/dev/null 2>&1; then
            log_info "$package is already installed"
        else
            log_info "Installing $package..."
            if brew install "$package"; then
                log_success "$package installed successfully"
            else
                log_error "Failed to install $package"
                exit 1
            fi
        fi
    done
    
    # Link Python if needed and using Homebrew
    if [[ "$PYTHON_MANAGER" == "homebrew" && "$REQUIRED_PYTHON_VERSION" != "3" ]]; then
        brew link --overwrite "python@$REQUIRED_PYTHON_VERSION" 2>/dev/null || true
    fi
}

# Setup Python environment (mode-aware)
setup_python_environment() {
    if [[ "$SKIP_PYTHON_SETUP" == "true" ]]; then
        log_info "Skipping Python environment setup"
        return 0
    fi
    
    log_header "Setting up Python Environment ($PYTHON_MANAGER + $DEPENDENCY_TOOL)"
    
    case "$PYTHON_MANAGER" in
        "pyenv")
            setup_python_environment_pyenv
            ;;
        "homebrew")
            setup_python_environment_homebrew
            ;;
        *)
            log_error "Unknown Python manager: $PYTHON_MANAGER"
            exit 1
            ;;
    esac
}

# Setup Python environment using Homebrew + pip/venv
setup_python_environment_homebrew() {
    # Find Python executable
    local python_cmd=""
    for cmd in "python$REQUIRED_PYTHON_VERSION" "python3" "python"; do
        if command -v "$cmd" >/dev/null 2>&1; then
            local version=$($cmd --version 2>&1 | grep -o '[0-9]\+\.[0-9]\+')
            if [[ "$(printf '%s\n' "$MIN_PYTHON_VERSION" "$version" | sort -V | head -n1)" == "$MIN_PYTHON_VERSION" ]]; then
                python_cmd="$cmd"
                log_success "Using Python: $cmd (version $version)"
                break
            fi
        fi
    done
    
    if [[ -z "$python_cmd" ]]; then
        log_error "Python $MIN_PYTHON_VERSION+ not found"
        exit 1
    fi
    
    # Check if pip is available
    if ! $python_cmd -m pip --version >/dev/null 2>&1; then
        log_info "Installing pip..."
        $python_cmd -m ensurepip --upgrade || {
            log_error "Failed to install pip"
            exit 1
        }
    fi
    
    # Install dependencies based on tool
    case "$DEPENDENCY_TOOL" in
        "pip")
            setup_dependencies_with_pip "$python_cmd"
            ;;
        "uv")
            setup_dependencies_with_uv_homebrew "$python_cmd"
            ;;
    esac
}

# Setup Python environment using pyenv + uv
setup_python_environment_pyenv() {
    # Ensure Python is available via pyenv
    if ! command -v python >/dev/null 2>&1; then
        log_error "Python not available via pyenv. Run with --verbose for details."
        return 1
    fi
    
    local python_version=$(python --version 2>&1)
    log_success "Using Python via pyenv: $python_version"
    
    # Install dependencies based on tool
    case "$DEPENDENCY_TOOL" in
        "pip")
            setup_dependencies_with_pip "python"
            ;;
        "uv")
            setup_dependencies_with_uv_pyenv
            ;;
    esac
}

# Setup dependencies using pip + venv
setup_dependencies_with_pip() {
    local python_cmd="$1"
    
    # Create virtual environment
    local venv_dir="$PROJECT_ROOT/venv"
    if [[ ! -d "$venv_dir" ]]; then
        log_info "Creating Python virtual environment..."
        $python_cmd -m venv "$venv_dir" || {
            log_error "Failed to create virtual environment"
            exit 1
        }
        log_success "Virtual environment created at $venv_dir"
    else
        log_info "Virtual environment already exists"
    fi
    
    # Activate virtual environment and install dependencies
    source "$venv_dir/bin/activate"
    
    # Upgrade pip
    log_info "Upgrading pip..."
    pip install --upgrade pip
    
    # Install project dependencies
    install_project_dependencies_pip
    
    deactivate
}

# Setup dependencies using uv with Homebrew Python
setup_dependencies_with_uv_homebrew() {
    local python_cmd="$1"
    
    # Initialize uv project if not exists
    initialize_uv_project "$python_cmd"
    
    # Install dependencies via uv
    install_project_dependencies_uv
}

# Setup dependencies using uv with pyenv Python
setup_dependencies_with_uv_pyenv() {
    # Initialize uv project if not exists
    initialize_uv_project "python"
    
    # Install dependencies via uv
    install_project_dependencies_uv
}

# Initialize uv project
initialize_uv_project() {
    local python_cmd="$1"
    
    if [[ ! -f "pyproject.toml" ]] || ! grep -q "\[build-system\]" pyproject.toml; then
        log_info "Initializing uv project..."
        uv init --no-readme --python "$($python_cmd --version | cut -d' ' -f2)"
    fi
    
    # Generate uv.lock from existing requirements if needed
    if [[ ! -f "uv.lock" ]] && [[ -f "requirements.txt" ]]; then
        migrate_requirements_to_uv
    fi
}

# Install project dependencies using pip
install_project_dependencies_pip() {
    if [[ -f "$PROJECT_ROOT/requirements.txt" ]]; then
        log_info "Installing Python dependencies from requirements.txt..."
        pip install -r "$PROJECT_ROOT/requirements.txt" || {
            log_error "Failed to install Python dependencies"
            exit 1
        }
        log_success "Python dependencies installed successfully"
    else
        log_warn "requirements.txt not found, skipping Python dependency installation"
    fi
    
    # Install development dependencies if pyproject.toml exists
    if [[ -f "$PROJECT_ROOT/pyproject.toml" ]]; then
        log_info "Installing development dependencies..."
        pip install -e ".[dev]" 2>/dev/null || {
            log_warn "Failed to install development dependencies (this is optional)"
        }
    fi
}

# Install project dependencies using uv
install_project_dependencies_uv() {
    if [[ -f "uv.lock" ]]; then
        log_info "Installing dependencies from uv.lock..."
        uv sync
        
        # Install development dependencies if requested
        if [[ -f "pyproject.toml" ]] && grep -q "\[project.optional-dependencies\]" pyproject.toml; then
            log_info "Installing development dependencies..."
            uv sync --group dev || log_warn "Failed to install some development dependencies"
        fi
        
        log_success "Dependencies installed successfully via uv"
    elif [[ -f "requirements.txt" ]]; then
        log_info "Installing dependencies from requirements.txt via uv..."
        uv pip install -r requirements.txt
        log_success "Dependencies installed successfully via uv"
    else
        log_warn "No dependency files found (uv.lock or requirements.txt)"
    fi
    
    # Ensure requirements.txt is updated for compatibility
    sync_requirements_txt
}

# Migrate requirements.txt to uv.lock
migrate_requirements_to_uv() {
    log_info "Migrating requirements.txt to uv project..."
    
    # Backup existing requirements
    cp requirements.txt requirements.txt.backup
    
    # Add dependencies to project
    while IFS= read -r line || [[ -n "$line" ]]; do
        # Skip comments and empty lines
        [[ "$line" =~ ^#.*$ ]] || [[ -z "$line" ]] && continue
        
        # Extract package name and version
        package=$(echo "$line" | sed 's/[<>=].*//')
        if [[ -n "$package" ]]; then
            log_info "Adding dependency: $line"
            uv add "$line" 2>/dev/null || log_warn "Failed to add: $line"
        fi
    done < requirements.txt
    
    # Verify migration
    if [[ -f "uv.lock" ]]; then
        log_success "Successfully migrated to uv.lock"
        sync_requirements_txt
    else
        log_error "Failed to create uv.lock"
        mv requirements.txt.backup requirements.txt
        return 1
    fi
}

# Maintain requirements.txt compatibility
sync_requirements_txt() {
    if [[ -f "uv.lock" ]] && command -v uv >/dev/null 2>&1; then
        log_info "Syncing requirements.txt from uv.lock..."
        uv export --format requirements-txt --no-hashes > requirements.txt || {
            log_warn "Failed to sync requirements.txt"
            return 1
        }
        log_success "requirements.txt updated from uv.lock"
    fi
}

# Create activation script
create_activation_script() {
    log_header "Creating Environment Activation Script"
    
    local activate_script="$PROJECT_ROOT/activate.sh"
    
    cat > "$activate_script" << 'EOF'
#!/bin/bash
# activate.sh - Activate the PodShift environment

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" &> /dev/null && pwd)"
VENV_DIR="$SCRIPT_DIR/venv"

if [[ -d "$VENV_DIR" ]]; then
    echo "Activating Python virtual environment..."
    source "$VENV_DIR/bin/activate"
    echo "Environment activated. Python: $(which python)"
    echo "To deactivate, run: deactivate"
else
    echo "Virtual environment not found at $VENV_DIR"
    echo "Run setup.sh first to create the environment"
    exit 1
fi
EOF
    
    chmod +x "$activate_script"
    log_success "Created activation script: $activate_script"
    log_info "To activate the environment, run: source ./activate.sh"
}

# Verify installation
verify_installation() {
    log_header "Verifying Installation"
    
    local errors=0
    
    # Check system tools
    local tools=("jq" "git" "curl" "wget")
    for tool in "${tools[@]}"; do
        if command -v "$tool" >/dev/null 2>&1; then
            local version=$($tool --version 2>&1 | head -1 || echo "Unknown")
            log_success "$tool: $version"
        else
            log_error "$tool not found"
            ((errors++))
        fi
    done
    
    # Check Python environment based on setup mode
    if [[ "$PYTHON_MANAGER" == "pyenv" && "$DEPENDENCY_TOOL" == "uv" ]]; then
        # pyenv + uv mode: Check for .venv and use uv run
        if [[ -d "$PROJECT_ROOT/.venv" ]]; then
            log_success "Found uv virtual environment at .venv"
            
            if uv run python --version >/dev/null 2>&1; then
                local py_version=$(uv run python --version)
                log_success "Python (uv): $py_version"
                
                # Check Python packages using uv run
                local packages=("docker" "yaml")
                for package in "${packages[@]}"; do
                    if uv run python -c "import $package" 2>/dev/null; then
                        log_success "Python package '$package' is available"
                    else
                        log_error "Python package '$package' not found"
                        ((errors++))
                    fi
                done
            else
                log_error "Python not working with uv"
                ((errors++))
            fi
        else
            log_error "uv virtual environment (.venv) not found"
            ((errors++))
        fi
    elif [[ -d "$PROJECT_ROOT/venv" ]]; then
        # Traditional venv mode: Use standard activation
        source "$PROJECT_ROOT/venv/bin/activate"
        
        if python --version >/dev/null 2>&1; then
            local py_version=$(python --version)
            log_success "Python (venv): $py_version"
            
            # Check Python packages
            local packages=("docker" "yaml")
            for package in "${packages[@]}"; do
                if python -c "import $package" 2>/dev/null; then
                    log_success "Python package '$package' is available"
                else
                    log_error "Python package '$package' not found"
                    ((errors++))
                fi
            done
        else
            log_error "Python not working in virtual environment"
            ((errors++))
        fi
        
        deactivate
    elif [[ "$PYTHON_MANAGER" == "pyenv" ]]; then
        # pyenv without uv: Use pyenv python directly
        if command -v pyenv >/dev/null 2>&1 && pyenv version-name >/dev/null 2>&1; then
            local py_version=$(python --version 2>&1)
            log_success "Python (pyenv): $py_version"
            
            # Check Python packages
            local packages=("docker" "yaml")
            for package in "${packages[@]}"; do
                if python -c "import $package" 2>/dev/null; then
                    log_success "Python package '$package' is available"
                else
                    log_error "Python package '$package' not found"
                    ((errors++))
                fi
            done
        else
            log_error "pyenv Python environment not working"
            ((errors++))
        fi
    else
        log_error "No Python environment found (expected venv, .venv, or pyenv setup)"
        ((errors++))
    fi
    
    if [[ $errors -eq 0 ]]; then
        log_success "All dependencies verified successfully"
        return 0
    else
        log_error "Found $errors errors during verification"
        return 1
    fi
}

# Display next steps
show_next_steps() {
    log_header "Setup Complete"
    
    echo ""
    echo "🎉 PodShift setup completed successfully!"
    echo ""
    echo "NEXT STEPS:"
    echo "1. Activate the environment:"
    echo "   source ./activate.sh"
    echo ""
    echo "2. Test the installation:"
    echo "   python scripts/discovery/docker_inventory.py --help"
    echo ""
    echo "3. Start Docker discovery (if Docker is running):"
    echo "   bash scripts/discovery/discover_containers.sh"
    echo ""
    echo "4. Review the generated reports and plan your migration"
    echo ""
    echo "USEFUL COMMANDS:"
    echo "• Run system analysis: bash scripts/discovery/system_resources.sh"
    echo "• Check dependencies: python scripts/discovery/dependency_mapper.py"
    echo "• View logs: tail -f logs/setup_$TIMESTAMP.log"
    echo ""
    echo "For help and documentation, check the README.md file."
}

# Cleanup function
cleanup_on_error() {
    local exit_code=$?
    if [[ $exit_code -ne 0 ]]; then
        log_error "Setup failed with exit code $exit_code"
        echo ""
        echo "Setup failed. Check the log file for details: $LOG_FILE"
        echo "You can re-run this script to retry the setup."
    fi
}

# Main execution function
main() {
    echo "=== PodShift - System Setup ==="
    echo "Setting up dependencies for M1 Mac Docker to Podman migration"
    echo "Started at $(date)"
    echo ""
    
    # Ensure required directories exist
    mkdir -p "$LOGS_DIR"
    
    # Initialize log file
    log_info "=== Setup Script Started ==="
    log_info "Script: $0"
    log_info "Arguments: $*"
    log_info "Project root: $PROJECT_ROOT"
    log_info "Verbose mode: $VERBOSE"
    
    # Parse command line arguments
    parse_args "$@"
    
    # Handle migration mode and configure Python setup
    handle_migration_mode
    configure_python_setup
    
    # Log configuration summary
    log_info "Python Manager: $PYTHON_MANAGER"
    log_info "Dependency Tool: $DEPENDENCY_TOOL"
    log_info "Auto-detect: $AUTO_DETECT"
    
    # Run setup operations
    check_system_requirements
    setup_homebrew
    setup_pyenv
    setup_uv
    install_system_dependencies
    setup_python_environment
    create_activation_script
    
    # Verify everything is working
    if verify_installation; then
        show_next_steps
        log_success "Setup completed successfully"
        exit 0
    else
        log_error "Setup completed with errors"
        exit 1
    fi
}

# Set trap for cleanup on error
trap cleanup_on_error EXIT

# Run main function with all arguments
main "$@"