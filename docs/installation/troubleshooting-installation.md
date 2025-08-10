# Troubleshooting Installation

Common installation issues and their solutions for PodShift on macOS.

> **Navigation**: [← System Requirements](system-requirements.md) | [Installation Guide](installation-guide.md) | [Quick Start →](../migration-guide/quick-start.md)

**Related Documentation:**
- [Installation Guide](installation-guide.md) - Complete installation process
- [System Requirements](system-requirements.md) - Hardware and software requirements
- [M1 Compatibility](../troubleshooting/m1-compatibility.md) - Apple Silicon specific issues
- [Common Issues](../troubleshooting/common-issues.md) - General troubleshooting guide

## Table of Contents

1. [Quick Diagnostics](#quick-diagnostics)
2. [Setup Script Issues](#setup-script-issues)
3. [Homebrew Problems](#homebrew-problems)
4. [Python Environment Issues](#python-environment-issues)
5. [Dependency Installation Problems](#dependency-installation-problems)
6. [Permission Issues](#permission-issues)
7. [Network and Proxy Issues](#network-and-proxy-issues)
8. [Apple Silicon Specific Issues](#apple-silicon-specific-issues)
9. [Docker Integration Problems](#docker-integration-problems)
10. [Clean Reinstallation](#clean-reinstallation)

## Quick Diagnostics

### System Check Command
```bash
# Run comprehensive system diagnostics
make check-requirements

# Or manual checks
sw_vers -productVersion  # macOS version
uname -m                # Architecture
python3 --version       # Python version
brew --version          # Homebrew version
```

### Common Status Indicators
```bash
✅ Success - Component working correctly
⚠️  Warning - Component working but needs attention  
❌ Error - Component not working, action required
🔄 In Progress - Installation/update in progress
```

## Setup Script Issues

### Setup Script Won't Run

#### Issue: Permission Denied
```bash
# Error message:
./setup.sh: Permission denied
```

**Solution:**
```bash
# Make script executable
chmod +x setup.sh

# Run setup
./setup.sh
```

#### Issue: Command Not Found
```bash
# Error message:
setup.sh: command not found
```

**Solution:**
```bash
# Ensure you're in the correct directory
cd podshift

# Run with full path
./setup.sh

# Or with bash explicitly
bash setup.sh
```

### Setup Script Failures

#### Issue: Xcode Command Line Tools Missing
```bash
# Error during setup:
xcode-select: error: invalid developer directory
```

**Solution:**
```bash
# Install Xcode Command Line Tools
xcode-select --install

# Wait for installation to complete, then retry
./setup.sh
```

#### Issue: Insufficient Disk Space
```bash
# Error message:
No space left on device
```

**Solution:**
```bash
# Check available space
df -h /

# Free up space (examples)
# Clear downloads
rm -rf ~/Downloads/*

# Clear caches
rm -rf ~/Library/Caches/*

# Empty trash
rm -rf ~/.Trash/*

# Use Storage Management in System Preferences
```

#### Issue: Network Timeout During Setup
```bash
# Error message:
curl: (28) Connection timed out
```

**Solution:**
```bash
# Check internet connection
curl -I https://google.com

# Use alternative DNS
export DNS=8.8.8.8

# Retry with verbose output
./setup.sh --verbose
```

## Homebrew Problems

### Homebrew Installation Issues

#### Issue: Homebrew Installation Fails
```bash
# Error message:
curl: (7) Failed to connect to raw.githubusercontent.com
```

**Solution:**
```bash
# Check network connectivity
ping raw.githubusercontent.com

# Try alternative installation method
cd /opt
sudo mkdir homebrew && curl -L https://github.com/Homebrew/brew/tarball/master | sudo tar xz --strip 1 -C homebrew

# Add to PATH
echo 'export PATH="/opt/homebrew/bin:$PATH"' >> ~/.zshrc
```

#### Issue: Apple Silicon PATH Problems
```bash
# Error message:
brew: command not found
```

**Solution:**
```bash
# For Apple Silicon Macs, add Homebrew to PATH
echo 'eval "$(/opt/homebrew/bin/brew shellenv)"' >> ~/.zprofile
source ~/.zprofile

# Verify installation
brew --version
```

### Homebrew Update Issues

#### Issue: Homebrew Update Fails
```bash
# Error message:
Error: Failure while executing: git pull --quiet origin refs/heads/master:refs/remotes/origin/master
```

**Solution:**
```bash
# Reset Homebrew git repository
cd /opt/homebrew  # or /usr/local for Intel Macs
sudo git fetch --all
sudo git reset --hard origin/master

# Update again
brew update
```

#### Issue: Permission Denied on Homebrew Directories
```bash
# Error message:
Permission denied @ dir_s_mkdir - /opt/homebrew/var
```

**Solution:**
```bash
# Fix Homebrew permissions (Apple Silicon)
sudo chown -R $(whoami) /opt/homebrew

# Or for Intel Macs
sudo chown -R $(whoami) /usr/local/Homebrew
```

## Python Environment Issues

### Python Installation Problems

#### Issue: Python Version Too Old
```bash
# Error message:
Python 3.7.x is not supported, minimum version is 3.8
```

**Solution:**
```bash
# Install newer Python version
brew install python@3.11

# Update symlinks
brew link --overwrite python@3.11

# Verify version
python3.11 --version
```

#### Issue: Multiple Python Versions Conflict
```bash
# Error message:
ModuleNotFoundError: No module named '_ctypes'
```

**Solution:**
```bash
# List installed Python versions
ls -la /usr/bin/python*
brew list | grep python

# Use specific Python version
python3.11 -m venv venv

# Or reinstall Python
brew uninstall --ignore-dependencies python@3.11
brew install python@3.11
```

### Virtual Environment Issues

#### Issue: Virtual Environment Creation Fails
```bash
# Error message:
Error: could not create virtual environment
```

**Solution:**
```bash
# Ensure Python has venv module
python3 -m ensurepip --upgrade

# Remove any existing venv
rm -rf venv

# Create with specific Python version
python3.11 -m venv venv --clear

# Activate and upgrade pip
source venv/bin/activate
pip install --upgrade pip
```

#### Issue: Virtual Environment Activation Fails
```bash
# Error message:
venv/bin/activate: No such file or directory
```

**Solution:**
```bash
# Check if virtual environment exists
ls -la venv/

# If missing, recreate
python3 -m venv venv

# Use full path for activation
source $(pwd)/venv/bin/activate
```

## Dependency Installation Problems

### Python Package Installation Issues

#### Issue: Docker SDK Installation Fails
```bash
# Error message:
ERROR: Failed building wheel for docker
```

**Solution:**
```bash
# Update pip and setuptools
pip install --upgrade pip setuptools wheel

# Install build dependencies
brew install rust  # For some native dependencies

# Retry installation
pip install docker
```

#### Issue: PyYAML Installation Fails
```bash
# Error message:
Failed to build PyYAML
```

**Solution:**
```bash
# Install system dependencies
brew install libyaml

# Use pre-built wheel
pip install --only-binary=all PyYAML

# Or install from source with correct flags
pip install PyYAML --install-option="--with-libyaml"
```

#### Issue: SSL Certificate Errors
```bash
# Error message:
SSL: CERTIFICATE_VERIFY_FAILED
```

**Solution:**
```bash
# Update certificates
/Applications/Python\ 3.11/Install\ Certificates.command

# Or bypass SSL (not recommended for production)
pip install --trusted-host pypi.org --trusted-host files.pythonhosted.org docker PyYAML
```

### System Package Installation Issues

#### Issue: jq Installation Fails
```bash
# Error message:
Error: jq: Permission denied
```

**Solution:**
```bash
# Install with sudo if needed
sudo brew install jq

# Or fix Homebrew permissions first
sudo chown -R $(whoami) $(brew --prefix)
brew install jq
```

## Permission Issues

### File System Permissions

#### Issue: Cannot Write to Project Directory
```bash
# Error message:
Permission denied: '/path/to/podman-migration-toolkit'
```

**Solution:**
```bash
# Check directory permissions
ls -la /path/to/

# Fix ownership
sudo chown -R $(whoami) /path/to/podman-migration-toolkit

# Fix permissions
chmod -R 755 /path/to/podman-migration-toolkit
```

#### Issue: Cannot Create Log Files
```bash
# Error message:
Permission denied: 'logs/setup_timestamp.log'
```

**Solution:**
```bash
# Create logs directory with correct permissions
mkdir -p logs
chmod 755 logs

# Or run setup with sudo (not recommended)
sudo ./setup.sh
sudo chown -R $(whoami) .
```

### Administrative Privileges

#### Issue: Homebrew Requires Admin Rights
```bash
# Error message:
Don't run this as root!
```

**Solution:**
```bash
# Never run Homebrew with sudo
# Instead, fix permissions:
sudo chown -R $(whoami) /opt/homebrew

# Or install in user directory
mkdir ~/.homebrew
curl -L https://github.com/Homebrew/brew/tarball/master | tar xz --strip 1 -C ~/.homebrew
export PATH="$HOME/.homebrew/bin:$PATH"
```

## Network and Proxy Issues

### Corporate Firewall Issues

#### Issue: Cannot Access Package Repositories
```bash
# Error message:
Could not fetch URL https://pypi.org/simple/
```

**Solution:**
```bash
# Configure proxy settings
export https_proxy=http://proxy.company.com:8080
export http_proxy=http://proxy.company.com:8080

# Configure pip proxy
pip config set global.proxy http://proxy.company.com:8080

# Configure git proxy
git config --global http.proxy http://proxy.company.com:8080
git config --global https.proxy http://proxy.company.com:8080
```

#### Issue: SSL Certificate Issues in Corporate Environment
```bash
# Error message:
SSL certificate problem: unable to get local issuer certificate
```

**Solution:**
```bash
# Get corporate CA certificate
# Contact IT department for certificate file

# Install certificate
sudo security add-trusted-cert -d -r trustRoot -k /Library/Keychains/System.keychain corporate-ca.crt

# Or disable SSL verification (not recommended)
pip config set global.trusted-host "pypi.org files.pythonhosted.org"
```

### DNS Resolution Issues

#### Issue: Cannot Resolve Domain Names
```bash
# Error message:
getaddrinfo failed: nodename nor servname provided
```

**Solution:**
```bash
# Check DNS resolution
nslookup pypi.org

# Use alternative DNS servers
sudo networksetup -setdnsservers Wi-Fi 8.8.8.8 8.8.4.4

# Flush DNS cache
sudo dscacheutil -flushcache
```

## Apple Silicon Specific Issues

### Rosetta 2 Issues

#### Issue: x86_64 Binary Compatibility Warnings
```bash
# Warning message:
This process is running under Rosetta 2
```

**Solution:**
```bash
# Install Rosetta 2 if not already installed
softwareupdate --install-rosetta

# For Homebrew, use native ARM64 version
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
```

#### Issue: Mixed Architecture Binaries
```bash
# Error message:
Architecture mismatch: expected arm64, got x86_64
```

**Solution:**
```bash
# Remove Intel-based Homebrew
sudo rm -rf /usr/local/Homebrew

# Install ARM64 Homebrew
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"

# Reinstall packages
brew install python@3.11 jq git curl wget
```

### Performance Issues on Apple Silicon

#### Issue: Slow Performance with Docker Analysis
```bash
# Symptom: Analysis takes much longer than expected
```

**Solution:**
```bash
# Ensure Docker Desktop is using Apple Silicon optimizations
# Check Docker Desktop settings: 
# Preferences > General > "Use Apple Virtualization framework"

# Ensure native ARM64 Python
python3 -c "import platform; print(platform.machine())"
# Should output: arm64

# Use Activity Monitor to check for Rosetta 2 processes
```

## Docker Integration Problems

### Docker Connection Issues

#### Issue: Docker Daemon Not Running
```bash
# Error message:
Cannot connect to the Docker daemon
```

**Solution:**
```bash
# Start Docker Desktop
open -a Docker

# Wait for Docker to start
until docker info >/dev/null 2>&1; do
    echo "Waiting for Docker to start..."
    sleep 2
done

# Verify Docker is working
docker version
```

#### Issue: Docker Socket Permission Denied
```bash
# Error message:
Permission denied while trying to connect to Docker daemon socket
```

**Solution:**
```bash
# Check Docker Desktop is running
docker info

# On macOS, this usually means Docker Desktop isn't running
# or needs to be restarted
killall Docker\ Desktop
open -a Docker
```

### Docker Version Compatibility

#### Issue: Old Docker Version
```bash
# Error message:
Docker API version is too old
```

**Solution:**
```bash
# Update Docker Desktop
brew upgrade --cask docker

# Or download latest from Docker website
open https://www.docker.com/products/docker-desktop/
```

## Clean Reinstallation

### Complete Clean Installation

When all else fails, perform a clean reinstallation:

```bash
# 1. Remove virtual environment
rm -rf venv/

# 2. Remove generated files
rm -rf logs/ *.json

# 3. Remove Python cache
find . -name "*.pyc" -delete
find . -name "__pycache__" -delete

# 4. Reset git repository (if needed)
git clean -fdx
git reset --hard HEAD

# 5. Reinstall system dependencies
brew uninstall python@3.11 jq git curl wget
brew install python@3.11 jq git curl wget

# 6. Run setup again
./setup.sh --verbose
```

### Nuclear Option - Complete Homebrew Reinstall

```bash
# WARNING: This removes ALL Homebrew packages

# 1. Uninstall Homebrew
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/uninstall.sh)"

# 2. Remove Homebrew directories
sudo rm -rf /opt/homebrew
sudo rm -rf /usr/local/Homebrew

# 3. Clean PATH
# Edit ~/.zshrc or ~/.bash_profile and remove Homebrew PATH entries

# 4. Reinstall Homebrew
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"

# 5. Add to PATH (Apple Silicon)
echo 'eval "$(/opt/homebrew/bin/brew shellenv)"' >> ~/.zprofile
source ~/.zprofile

# 6. Reinstall dependencies
brew install python@3.11 jq git curl wget

# 7. Run setup
./setup.sh --verbose
```

## Getting Additional Help

### Diagnostic Information to Collect

When reporting issues, include:

```bash
# System information
sw_vers -productVersion
uname -m
system_profiler SPHardwareDataType | grep -E "(Model|Memory|Processor)"

# Software versions
python3 --version
brew --version
git --version

# Environment information
echo $PATH
echo $SHELL
env | grep -E "(PYTHON|HOMEBREW|PATH)"

# Log files
cat logs/setup_*.log | tail -50
```

### Support Channels

1. **Documentation**: Check other files in `docs/troubleshooting/`
2. **GitHub Issues**: Open an issue with diagnostic information
3. **Community Forums**: Homebrew, Docker, or Python communities
4. **Apple Developer Forums**: For Apple Silicon specific issues

### Professional Support

For enterprise environments or complex issues:
- Consider professional consultation
- Check with your IT department for corporate proxy/firewall configurations
- Review company policies for software installation

---

**Remember**: Most installation issues are resolved by ensuring system requirements are met and following the installation steps in order. When in doubt, try a clean reinstallation.