# Installation Guide

Complete step-by-step installation guide for PodShift on macOS with Apple Silicon (M1/M2/M3) support.

> **Navigation**: [← Back to README](../../README.md) | [System Requirements →](system-requirements.md) | [Troubleshooting →](troubleshooting-installation.md)

**Related Documentation:**
- [System Requirements](system-requirements.md) - Detailed compatibility information
- [Troubleshooting Installation](troubleshooting-installation.md) - Common installation issues
- [Quick Start Guide](../migration-guide/quick-start.md) - Get started after installation

## Table of Contents

1. [Prerequisites](#prerequisites)
2. [System Verification](#system-verification)
3. [Automated Installation](#automated-installation)
4. [Manual Installation](#manual-installation)
5. [Verification](#verification)
6. [Environment Setup](#environment-setup)
7. [Troubleshooting](#troubleshooting)

## Prerequisites

### Hardware Requirements
- **Mac Computer**: Apple Silicon (M1, M2, M3) recommended, Intel Macs supported
- **Memory**: Minimum 4GB RAM, 8GB+ recommended for large environments
- **Storage**: Minimum 10GB free space, 50GB+ recommended
- **Network**: Internet connection for downloading dependencies

### Software Requirements
- **macOS**: Version 12.0 (Monterey) or later
- **Xcode Command Line Tools**: Required for compilation
- **Administrative Access**: Required for Homebrew installation

## System Verification

Before beginning installation, verify your system meets the requirements:

```bash
# Check macOS version
sw_vers -productVersion

# Check architecture (should show 'arm64' for Apple Silicon)
uname -m

# Check available disk space
df -h /

# Check memory
system_profiler SPHardwareDataType | grep "Memory:"
```

### Expected Output
```
ProductVersion: 13.0.0 (or later)
Architecture: arm64
Available space: 50GB+ recommended
Memory: 8GB+ recommended
```

## Automated Installation

The quickest way to install the toolkit is using the automated setup script.

### Step 1: Clone Repository
```bash
# Choose installation location
cd ~/Development  # or your preferred directory

# Clone the repository
git clone <repository-url>
cd podshift
```

### Step 2: Run Setup Script
```bash
# Make setup script executable (if needed)
chmod +x setup.sh

# Run automated setup
./setup.sh
```

### Setup Script Options
```bash
# View all options
./setup.sh --help

# Verbose installation
./setup.sh --verbose

# Skip Homebrew installation (if already installed)
./setup.sh --skip-homebrew-install

# Skip Python environment setup
./setup.sh --skip-python-setup

# Specify custom Python version
./setup.sh --python-version 3.11
```

### Step 3: Activate Environment
```bash
# Activate the Python virtual environment
source ./activate.sh
```

## Manual Installation

If you prefer manual installation or the automated script fails, follow these detailed steps.

### Step 1: Install Xcode Command Line Tools
```bash
# Install command line tools
xcode-select --install

# Verify installation
xcode-select -p
# Should output: /Library/Developer/CommandLineTools
```

### Step 2: Install Homebrew
```bash
# Install Homebrew (if not already installed)
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"

# For Apple Silicon Macs, add Homebrew to PATH
echo 'eval "$(/opt/homebrew/bin/brew shellenv)"' >> ~/.zprofile
eval "$(/opt/homebrew/bin/brew shellenv)"

# Verify installation
brew --version
```

### Step 3: Install System Dependencies
```bash
# Update Homebrew
brew update

# Install required packages
brew install python@3.11 jq git curl wget

# Verify installations
python3.11 --version
jq --version
git --version
curl --version
wget --version
```

### Step 4: Create Python Virtual Environment
```bash
# Navigate to project directory
cd podshift

# Create virtual environment
python3.11 -m venv venv

# Activate virtual environment
source venv/bin/activate

# Upgrade pip
pip install --upgrade pip
```

### Step 5: Install Python Dependencies
```bash
# Install core dependencies
pip install -r requirements.txt

# Install development dependencies (optional)
pip install -e .[dev]

# Verify installations
python -c "import docker; print('Docker SDK installed')"
python -c "import yaml; print('PyYAML installed')"
```

### Step 6: Create Activation Script
```bash
# Create activation script for easy environment management
cat > activate.sh << 'EOF'
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

# Make script executable
chmod +x activate.sh
```

## Verification

After installation, verify everything is working correctly:

### Step 1: System Status Check
```bash
# Using Make (recommended)
make status

# Or manual verification
source ./activate.sh
python --version
pip list | grep -E "(docker|PyYAML)"
```

### Step 2: Script Verification
```bash
# Test system resources script
bash scripts/discovery/system_resources.sh --help

# Test Docker inventory script (requires Docker)
python scripts/discovery/docker_inventory.py --help

# Test dependency mapper script (requires Docker)
python scripts/discovery/dependency_mapper.py --help
```

### Step 3: Docker Integration Test
If Docker is installed and running:

```bash
# Test Docker connection
docker info

# Run quick discovery test
bash scripts/discovery/discover_containers.sh --help
```

### Expected Verification Output
```bash
✓ Virtual Environment: Present
✓ Python Version: 3.11.x
✓ Docker SDK: Installed
✓ PyYAML: Installed
✓ System Requirements: Met
✓ Scripts: Executable
```

## Environment Setup

### Daily Usage
```bash
# Activate environment when starting work
source ./activate.sh

# Run discovery operations
make discovery

# Deactivate when finished
deactivate
```

### Shell Integration
Add to your shell profile for convenient access:

```bash
# Add to ~/.zshrc or ~/.bash_profile
alias ps-activate='cd /path/to/podshift && source ./activate.sh'

# Usage
ps-activate
```

### Environment Variables
Optional environment variables for customization:

```bash
# Add to your shell profile or .env file
export PODSHIFT_OUTPUT_DIR="$HOME/podshift-reports"
export PODSHIFT_LOG_LEVEL="INFO"
export PODSHIFT_VERBOSE="true"
```

## Troubleshooting

### Common Installation Issues

#### Homebrew Installation Fails
```bash
# Check network connectivity
curl -I https://brew.sh

# Manually download and install
curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh | bash

# For corporate networks, check proxy settings
export https_proxy=http://proxy.company.com:8080
```

#### Python Version Issues
```bash
# List available Python versions
brew list | grep python

# Install specific version
brew install python@3.11

# Link Python (if needed)
brew link --overwrite python@3.11

# Verify Python executable
which python3.11
```

#### Virtual Environment Creation Fails
```bash
# Remove existing venv
rm -rf venv

# Ensure pip is updated
python3.11 -m ensurepip --upgrade

# Recreate virtual environment
python3.11 -m venv venv --clear
```

#### Permission Issues
```bash
# Fix common permission issues
sudo chown -R $(whoami) /opt/homebrew  # For Apple Silicon
sudo chown -R $(whoami) /usr/local     # For Intel Macs

# Or install Homebrew in user directory
mkdir ~/.homebrew && curl -L https://github.com/Homebrew/brew/tarball/master | tar xz --strip 1 -C ~/.homebrew
```

#### Docker-related Issues
```bash
# Install Docker Desktop if missing
brew install --cask docker

# Start Docker Desktop
open -a Docker

# Check Docker daemon
docker info
```

### Getting Help

If you encounter issues not covered here:

1. **Check Logs**: Review installation logs in `logs/setup_TIMESTAMP.log`
2. **System Requirements**: Verify using `make check-requirements`
3. **Clean Installation**: Remove `venv/` directory and restart
4. **Documentation**: Check [troubleshooting-installation.md](troubleshooting-installation.md)
5. **Community**: Open an issue on GitHub

### Clean Reinstallation

If you need to start fresh:

```bash
# Remove virtual environment
rm -rf venv/

# Remove generated files
make clean-all

# Re-run setup
./setup.sh --verbose
```

## Next Steps

After successful installation:

1. **Read the [Migration Guide](../migration-guide/quick-start.md)** to understand the migration process
2. **Review [System Requirements](system-requirements.md)** for detailed specifications
3. **Run System Check**: `make system-check` to verify M1 Mac compatibility
4. **Start Discovery**: `make discovery` to analyze your Docker environment

## Advanced Installation Options

### Docker-Free Installation
If you don't have Docker installed but want to use the system analysis features:

```bash
# Install without Docker SDK
pip install PyYAML

# Use system-only features
bash scripts/discovery/system_resources.sh
```

### Development Installation
For contributors and developers:

```bash
# Install with development dependencies
pip install -e .[dev]

# Install pre-commit hooks
pre-commit install

# Run tests
make test
```

### Corporate Environment Setup
For installations behind corporate firewalls:

```bash
# Set proxy settings
export https_proxy=http://proxy.company.com:8080
export http_proxy=http://proxy.company.com:8080

# Configure pip proxy
pip config set global.proxy http://proxy.company.com:8080

# Run setup with proxy
./setup.sh --verbose
```

---

**Installation complete!** You're now ready to migrate from Docker to Podman on your M1 Mac.