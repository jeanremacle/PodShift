# Common Issues and Solutions

Comprehensive troubleshooting guide for common problems encountered when using PodShift.

> **Navigation**: [← Back to README](../../README.md) | [Docker Connectivity →](docker-connectivity.md) | [M1 Compatibility →](m1-compatibility.md)

**Related Documentation:**
- [Docker Connectivity Issues](docker-connectivity.md) - Docker connection and API problems
- [M1 Mac Compatibility Issues](m1-compatibility.md) - Apple Silicon specific issues
- [Installation Troubleshooting](../installation/troubleshooting-installation.md) - Setup and installation problems
- [Script Reference](../api/script-reference.md) - Command-line options and usage
- [System Requirements](../installation/system-requirements.md) - Verify your system meets requirements

## Table of Contents

1. [Quick Diagnostics](#quick-diagnostics)
2. [Installation Issues](#installation-issues)
3. [Discovery Problems](#discovery-problems)
4. [Docker Connection Issues](#docker-connection-issues)
5. [M1 Mac Specific Issues](#m1-mac-specific-issues)
6. [Performance Issues](#performance-issues)
7. [Output and Reporting Issues](#output-and-reporting-issues)
8. [Getting Help](#getting-help)

## Quick Diagnostics

### First Steps for Any Issue

```bash
# 1. Check system status
make status

# 2. Verify installation
source ./activate.sh
python --version
pip list | grep -E "(docker|PyYAML)"

# 3. Check Docker connectivity
docker info

# 4. Review recent logs
ls -la logs/
tail -50 logs/*$(date +%Y%m%d)*.log
```

### Common Status Indicators

| Status | Meaning | Action Required |
|--------|---------|-----------------|
| ✅ | Working correctly | None |
| ⚠️ | Working with warnings | Review and consider fixing |
| ❌ | Not working | Immediate attention required |
| 🔄 | In progress | Wait for completion |

## Installation Issues

### Python Environment Problems

#### Issue: "python3: command not found"
```bash
# Symptoms
./setup.sh
# Output: python3: command not found

# Solutions
# 1. Install Python via Homebrew
brew install python@3.11

# 2. Add Python to PATH (Apple Silicon)
echo 'export PATH="/opt/homebrew/bin:$PATH"' >> ~/.zshrc
source ~/.zshrc

# 3. Verify installation
python3 --version
```

#### Issue: "No module named 'docker'"
```bash
# Symptoms
python scripts/discovery/docker_inventory.py
# Output: ModuleNotFoundError: No module named 'docker'

# Solutions
# 1. Activate virtual environment
source ./activate.sh

# 2. Install dependencies
pip install -r requirements.txt

# 3. If still failing, recreate environment
rm -rf venv/
./setup.sh
```

#### Issue: Virtual Environment Not Activating
```bash
# Symptoms
source ./activate.sh
# Output: Virtual environment not found

# Solutions
# 1. Check if venv directory exists
ls -la venv/

# 2. Recreate virtual environment
python3 -m venv venv

# 3. Run setup again
./setup.sh --skip-homebrew-install
```

### Homebrew Installation Issues

#### Issue: "Homebrew installation failed"
```bash
# Symptoms
./setup.sh
# Output: Failed to install Homebrew

# Solutions
# 1. Check internet connectivity
ping brew.sh

# 2. Install manually
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"

# 3. For corporate networks
export https_proxy=http://proxy.company.com:8080
./setup.sh
```

#### Issue: "brew: command not found" (Apple Silicon)
```bash
# Symptoms
brew --version
# Output: brew: command not found

# Solutions
# 1. Add Homebrew to PATH
echo 'eval "$(/opt/homebrew/bin/brew shellenv)"' >> ~/.zprofile
source ~/.zprofile

# 2. Verify installation
brew --version

# 3. If still not working, check installation
ls -la /opt/homebrew/bin/brew
```

### Permission Issues

#### Issue: "Permission denied" during setup
```bash
# Symptoms
./setup.sh
# Output: Permission denied: cannot create directory

# Solutions
# 1. Fix ownership of project directory
sudo chown -R $(whoami) .

# 2. Fix Homebrew permissions (Apple Silicon)
sudo chown -R $(whoami) /opt/homebrew

# 3. For Intel Macs
sudo chown -R $(whoami) /usr/local/Homebrew
```

## Discovery Problems

### Docker Inventory Issues

#### Issue: "Docker daemon not running"
```bash
# Symptoms
python scripts/discovery/docker_inventory.py
# Output: Failed to connect to Docker daemon

# Solutions
# 1. Start Docker Desktop
open -a Docker

# 2. Wait for Docker to start
until docker info >/dev/null 2>&1; do
    echo "Waiting for Docker to start..."
    sleep 2
done

# 3. Verify Docker is running
docker ps
```

#### Issue: "Docker inventory analysis failed"
```bash
# Symptoms
make docker-inventory
# Output: Analysis failed with exit code 2

# Solutions
# 1. Check Docker permissions
docker ps
# If permission denied, restart Docker Desktop

# 2. Check for Docker Desktop updates
# Use Docker Desktop -> Check for Updates

# 3. Run with increased timeout
DOCKER_TIMEOUT=120 python scripts/discovery/docker_inventory.py
```

#### Issue: "Inventory file is empty or corrupted"
```bash
# Symptoms
cat docker_inventory_*.json
# Output: Empty file or invalid JSON

# Solutions
# 1. Check disk space
df -h .

# 2. Check file permissions
ls -la docker_inventory_*.json

# 3. Re-run with verbose output
python scripts/discovery/docker_inventory.py --verbose
```

### System Analysis Issues

#### Issue: "System requirements not met"
```bash
# Symptoms
bash scripts/discovery/system_resources.sh
# Output: System requirements check failed

# Solutions
# 1. Check specific requirements
sw_vers -productVersion  # macOS version
uname -m                # Architecture
df -h /                 # Disk space

# 2. Free up disk space if needed
# Use Storage Management in System Preferences

# 3. Update macOS if version too old
sudo softwareupdate -ia
```

#### Issue: "Low system readiness score"
```bash
# Symptoms
# Readiness score: 45/100
# Status: not_ready

# Solutions
# 1. Check critical issues
jq '.recommendations.critical_issues[]' system_resources_*.json

# 2. Address major issues first:
# - Upgrade macOS version
# - Free up disk space
# - Install missing dependencies

# 3. Install Rosetta 2 if needed
softwareupdate --install-rosetta
```

### Dependency Mapping Issues

#### Issue: "Circular dependency detected"
```bash
# Symptoms
python scripts/discovery/dependency_mapper.py
# Output: Detected 2 dependency cycles

# Solutions (this is informational, not an error)
# 1. Review cycles in output
jq '.dependency_graph.cycles' container_dependencies_*.json

# 2. Plan manual intervention for cycles
# 3. Consider breaking dependencies if possible
```

#### Issue: "No Docker Compose files found"
```bash
# Symptoms
# Output: No Docker Compose files found

# Solutions
# 1. Specify compose files manually
python scripts/discovery/dependency_mapper.py --compose-files docker-compose.yml

# 2. Check common locations
find ~ -name "docker-compose*.yml" -o -name "compose*.yml" 2>/dev/null

# 3. Run container-only analysis
python scripts/discovery/dependency_mapper.py --containers-only
```

## Docker Connection Issues

### Connection Problems

#### Issue: "Cannot connect to Docker daemon socket"
```bash
# Symptoms
docker info
# Output: Cannot connect to the Docker daemon at unix:///var/run/docker.sock

# Solutions
# 1. Check if Docker Desktop is running
ps aux | grep -i docker

# 2. Start Docker Desktop
open -a Docker

# 3. Check Docker Desktop settings
# Preferences -> Advanced -> Allow default Docker socket
```

#### Issue: "Docker API version mismatch"
```bash
# Symptoms
# Output: Docker API version X.Y is not supported

# Solutions
# 1. Update Docker Desktop
# Help -> Check for Updates

# 2. Specify API version
export DOCKER_API_VERSION=1.41
python scripts/discovery/docker_inventory.py

# 3. Check compatibility
docker version
```

### Docker Desktop Issues

#### Issue: "Docker Desktop won't start"
```bash
# Symptoms
# Docker Desktop fails to start or gets stuck

# Solutions
# 1. Reset Docker Desktop
# Troubleshoot -> Reset to factory defaults

# 2. Check system resources
# Activity Monitor -> Check memory usage

# 3. Restart with clean slate
killall Docker\ Desktop
rm -rf ~/Library/Group\ Containers/group.com.docker
open -a Docker
```

#### Issue: "Docker containers not visible"
```bash
# Symptoms
docker ps
# Output: No containers (but you know containers exist)

# Solutions
# 1. Check Docker context
docker context ls
docker context use default

# 2. Check if using different Docker installation
which docker
# Should point to Docker Desktop

# 3. Restart Docker Desktop
```

## M1 Mac Specific Issues

### Architecture Issues

#### Issue: "ARM64 image not available"
```bash
# Symptoms
# Output: platform linux/arm64 not found

# Solutions
# 1. Check for multi-arch image
docker manifest inspect nginx:latest

# 2. Use platform-specific pull
docker pull --platform linux/amd64 nginx:latest

# 3. Find ARM64 alternative
# Check Docker Hub for arm64v8/nginx or similar
```

#### Issue: "Performance issues with x86_64 containers"
```bash
# Symptoms
# Containers running slowly on M1 Mac

# Solutions
# 1. Check if running under emulation
docker inspect container_name | jq '.Platform'

# 2. Find native ARM64 image
docker search arm64v8/your-image

# 3. Accept performance trade-off or rebuild for ARM64
```

### Rosetta 2 Issues

#### Issue: "Rosetta 2 not installed"
```bash
# Symptoms
# Warning: Rosetta 2 not detected

# Solutions
# 1. Install Rosetta 2
softwareupdate --install-rosetta --agree-to-license

# 2. Verify installation
ls -la /Library/Apple/usr/share/rosetta/

# 3. Test x86_64 compatibility
arch -x86_64 uname -m  # Should output: x86_64
```

### Memory and Performance Issues

#### Issue: "High memory usage on M1 Mac"
```bash
# Symptoms
# System becoming slow during analysis

# Solutions
# 1. Monitor memory pressure
memory_pressure

# 2. Reduce analysis scope
python scripts/discovery/docker_inventory.py --containers-only

# 3. Close other applications
# Especially browsers and development tools

# 4. Increase virtual memory if needed
# System Preferences -> Memory
```

## Performance Issues

### Slow Analysis

#### Issue: "Discovery taking too long"
```bash
# Symptoms
# Analysis running for > 30 minutes

# Solutions
# 1. Check what's running
ps aux | grep -E "(python|docker)"

# 2. Reduce analysis scope
python scripts/discovery/docker_inventory.py --containers-only --timeout 120

# 3. Check system resources
top -l 1 | head -10
```

#### Issue: "System becomes unresponsive"
```bash
# Symptoms
# Mac becomes slow or unresponsive during analysis

# Solutions
# 1. Stop analysis immediately
pkill -f docker_inventory.py

# 2. Check thermal throttling
pmset -g thermlog | tail -5

# 3. Reduce concurrent operations
export PODSHIFT_MAX_WORKERS=2
python scripts/discovery/docker_inventory.py
```

### Resource Usage

#### Issue: "High CPU usage"
```bash
# Symptoms
# CPU usage > 80% during analysis

# Solutions
# 1. Limit CPU usage
nice -n 10 python scripts/discovery/docker_inventory.py

# 2. Run analysis in background
nohup make discovery > discovery.log 2>&1 &

# 3. Schedule during off-hours
# Use cron or similar scheduling
```

## Output and Reporting Issues

### File Generation Problems

#### Issue: "No output files generated"
```bash
# Symptoms
# Scripts complete but no JSON files created

# Solutions
# 1. Check current directory permissions
ls -la .
mkdir -p test-output

# 2. Specify output directory explicitly
python scripts/discovery/docker_inventory.py --output-dir ./reports

# 3. Check disk space
df -h .
```

#### Issue: "Corrupted or invalid JSON output"
```bash
# Symptoms
cat docker_inventory_*.json
# Output: Invalid JSON or truncated file

# Solutions
# 1. Validate JSON
python -m json.tool docker_inventory_*.json

# 2. Check for partial writes (disk full)
df -h .

# 3. Re-run with verbose logging
python scripts/discovery/docker_inventory.py --verbose 2>&1 | tee debug.log
```

### Report Analysis Issues

#### Issue: "Cannot parse compatibility scores"
```bash
# Symptoms
# Compatibility analysis shows errors

# Solutions
# 1. Check JSON structure
jq '.m1_compatibility' docker_inventory_*.json

# 2. Verify all required fields present
jq 'keys' docker_inventory_*.json

# 3. Re-run specific analysis
python scripts/discovery/docker_inventory.py --images-only
```

## Getting Help

### Diagnostic Information to Collect

When reporting issues, collect this information:

```bash
#!/bin/bash
# diagnostic_info.sh - Collect diagnostic information

echo "=== SYSTEM INFORMATION ==="
sw_vers
uname -a
sysctl hw.memsize hw.ncpu

echo -e "\n=== SOFTWARE VERSIONS ==="
python3 --version
pip --version
brew --version
docker --version 2>/dev/null || echo "Docker not available"

echo -e "\n=== PROJECT STATUS ==="
make status

echo -e "\n=== RECENT LOGS ==="
find logs/ -name "*.log" -mtime -1 -exec tail -20 {} \;

echo -e "\n=== ENVIRONMENT ==="
env | grep -E "(PYTHON|DOCKER|PODSHIFT_|PATH)" | sort

echo -e "\n=== DISK SPACE ==="
df -h .

echo -e "\n=== RUNNING PROCESSES ==="
ps aux | grep -E "(python|docker)" | grep -v grep
```

### Support Channels

1. **Documentation**: Check other guides in `docs/troubleshooting/`
2. **GitHub Issues**: Create an issue with diagnostic information
3. **Logs**: Always include relevant log files from `logs/` directory
4. **System Info**: Include output from diagnostic script above

### Self-Help Checklist

Before asking for help:

- [ ] Checked this troubleshooting guide
- [ ] Verified system requirements
- [ ] Reviewed recent logs for error messages
- [ ] Tried restarting Docker Desktop
- [ ] Attempted clean reinstallation
- [ ] Collected diagnostic information

### Common Quick Fixes

```bash
# Universal troubleshooting sequence
# 1. Clean restart
killall Docker\ Desktop
rm -rf logs/*
./setup.sh

# 2. Verify everything works
source ./activate.sh
make status

# 3. Try discovery again
make discovery

# 4. If still failing, get help with diagnostics
bash diagnostic_info.sh > diagnostic_report.txt
```

### Emergency Recovery

If the toolkit is completely broken:

```bash
#!/bin/bash
# emergency_recovery.sh - Nuclear option recovery

echo "Starting emergency recovery..."

# 1. Kill all related processes
pkill -f "docker_inventory"
pkill -f "dependency_mapper"

# 2. Clean up environment
rm -rf venv/
rm -rf logs/*
rm -rf *.json

# 3. Reset Docker if needed
killall Docker\ Desktop
# Restart Docker Desktop manually

# 4. Complete reinstallation
./setup.sh --verbose

# 5. Test basic functionality
source ./activate.sh
python -c "import docker; print('Docker SDK working')"
bash scripts/discovery/system_resources.sh --help

echo "Emergency recovery complete"
```

---

**Remember**: Most issues are caused by Docker connectivity problems or environment setup issues. Start with the basics (Docker running, environment activated) before investigating complex problems.

**Next Steps**: For specific issue categories, see:
- [Docker Connectivity Issues](docker-connectivity.md)
- [M1 Mac Compatibility Issues](m1-compatibility.md)
- [Installation Troubleshooting](../installation/troubleshooting-installation.md)