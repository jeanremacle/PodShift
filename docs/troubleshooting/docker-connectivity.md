# Docker Connectivity Troubleshooting

Detailed troubleshooting guide for Docker connection and communication issues specific to PodShift.

> **Navigation**: [Common Issues](common-issues.md) | [M1 Compatibility →](m1-compatibility.md)

**Related Documentation:**
- [Common Issues](common-issues.md) - General troubleshooting guide
- [M1 Compatibility](m1-compatibility.md) - Apple Silicon specific connectivity issues
- [Installation Troubleshooting](../installation/troubleshooting-installation.md) - Docker installation problems
- [Configuration Options](../api/configuration-options.md) - Docker connection settings
- [Script Reference](../api/script-reference.md) - Connection-related command options

## Table of Contents

1. [Connection Diagnosis](#connection-diagnosis)
2. [Docker Desktop Issues](#docker-desktop-issues)
3. [Socket and Permission Problems](#socket-and-permission-problems)
4. [Network and Firewall Issues](#network-and-firewall-issues)
5. [API and Version Compatibility](#api-and-version-compatibility)
6. [Remote Docker Connections](#remote-docker-connections)
7. [Docker in Docker Issues](#docker-in-docker-issues)
8. [Advanced Troubleshooting](#advanced-troubleshooting)

## Connection Diagnosis

### Quick Connection Test

```bash
# Test Docker daemon connection
docker info

# Test Docker API connectivity
curl --unix-socket /var/run/docker.sock http://localhost/version

# Test Python Docker SDK
python3 -c "
import docker
try:
    client = docker.from_env()
    print('✅ Docker SDK connection successful')
    print(f'Docker version: {client.version()["Version"]}')
except Exception as e:
    print(f'❌ Docker SDK connection failed: {e}')
"
```

### Connection Status Matrix

| Command | Success | Failure | Diagnosis |
|---------|---------|---------|-----------|
| `docker info` | ✅ | ❌ | Docker daemon status |
| `curl --unix-socket` | ✅ | ❌ | Socket accessibility |
| `python docker SDK` | ✅ | ❌ | Python library connection |
| `docker ps` | ✅ | ❌ | Container listing capability |

### Detailed Connection Diagnostics

```bash
#!/bin/bash
# docker_connection_diagnostics.sh - Comprehensive Docker connection test

echo "=== DOCKER CONNECTION DIAGNOSTICS ==="

# 1. Check Docker installation
echo "1. Docker Installation:"
if command -v docker >/dev/null 2>&1; then
    echo "   ✅ Docker command found: $(which docker)"
    docker --version
else
    echo "   ❌ Docker command not found"
    exit 1
fi

# 2. Check Docker daemon status
echo -e "\n2. Docker Daemon Status:"
if docker info >/dev/null 2>&1; then
    echo "   ✅ Docker daemon is running"
    docker info --format "   Server Version: {{.ServerVersion}}"
    docker info --format "   OS/Arch: {{.OperatingSystem}}/{{.Architecture}}"
else
    echo "   ❌ Docker daemon not accessible"
    echo "   Error details:"
    docker info 2>&1 | sed 's/^/     /'
fi

# 3. Check Docker socket
echo -e "\n3. Docker Socket:"
if [ -S /var/run/docker.sock ]; then
    echo "   ✅ Docker socket exists: /var/run/docker.sock"
    ls -la /var/run/docker.sock
else
    echo "   ❌ Docker socket not found"
fi

# 4. Check Docker context
echo -e "\n4. Docker Context:"
docker context ls
echo "   Current context: $(docker context show)"

# 5. Test Python Docker SDK
echo -e "\n5. Python Docker SDK:"
python3 -c "
import sys
try:
    import docker
    print('   ✅ Docker SDK imported successfully')
    try:
        client = docker.from_env()
        version = client.version()
        print(f'   ✅ API connection successful')
        print(f'   Client API Version: {client.api.api_version}')
        print(f'   Server API Version: {version[\"ApiVersion\"]}')
    except Exception as e:
        print(f'   ❌ API connection failed: {e}')
except ImportError:
    print('   ❌ Docker SDK not installed')
    print('   Install with: pip install docker')
"

# 6. Check container listing
echo -e "\n6. Container Operations:"
if docker ps >/dev/null 2>&1; then
    container_count=$(docker ps -q | wc -l | tr -d ' ')
    echo "   ✅ Container listing works ($container_count running containers)"
else
    echo "   ❌ Cannot list containers"
fi

# 7. Test image operations
echo -e "\n7. Image Operations:"
if docker images >/dev/null 2>&1; then
    image_count=$(docker images -q | wc -l | tr -d ' ')
    echo "   ✅ Image listing works ($image_count images)"
else
    echo "   ❌ Cannot list images"
fi

echo -e "\n=== DIAGNOSTICS COMPLETE ==="
```

## Docker Desktop Issues

### Docker Desktop Won't Start

#### Symptom: Docker Desktop Fails to Launch
```bash
# Check if Docker processes are running
ps aux | grep -i docker | grep -v grep

# Look for error messages
tail -f ~/Library/Containers/com.docker.docker/Data/log/host/Docker.log
```

**Solutions**:

1. **Reset Docker Desktop**
```bash
# Complete reset
killall Docker\ Desktop
rm -rf ~/Library/Group\ Containers/group.com.docker/
rm -rf ~/Library/Containers/com.docker.docker/
open -a Docker
```

2. **Check System Resources**
```bash
# Ensure sufficient memory (>4GB recommended)
system_profiler SPHardwareDataType | grep Memory

# Check disk space (>10GB required)
df -h /
```

3. **Update Docker Desktop**
```bash
# Check current version
docker --version

# Update via Homebrew
brew upgrade --cask docker

# Or download latest from Docker website
open https://www.docker.com/products/docker-desktop/
```

### Docker Desktop Stuck on Starting

#### Symptom: "Docker Desktop is starting..." Never Completes
```bash
# Force quit Docker Desktop
killall Docker\ Desktop

# Check for conflicting processes
lsof -i :2375 -i :2376

# Reset Docker Desktop settings
defaults delete com.docker.docker
```

**Solutions**:

1. **Reset Docker VM**
```bash
# Reset to factory defaults
# Docker Desktop -> Troubleshoot -> Reset to factory defaults

# Or via command line
rm -rf ~/Library/Group\ Containers/group.com.docker/
```

2. **Check Virtualization Framework**
```bash
# Ensure Apple Virtualization Framework is available (macOS 11+)
sw_vers -productVersion

# Check if other VM software is conflicting
ps aux | grep -E "(VirtualBox|VMware|Parallels)" | grep -v grep
```

### Docker Desktop Performance Issues

#### Symptom: Docker Desktop Using Excessive Resources
```bash
# Monitor Docker Desktop resource usage
top -pid $(pgrep Docker)

# Check Docker Desktop settings
# Docker Desktop -> Preferences -> Resources
```

**Solutions**:

1. **Optimize Resource Allocation**
```bash
# Recommended settings for M1 Mac:
# CPUs: 6 (out of 8)
# Memory: 12GB (out of 16GB)
# Swap: 2GB
# Disk image size: 64GB
```

2. **Enable Apple Virtualization Framework**
```bash
# Docker Desktop -> Preferences -> General
# ✅ Use the new Virtualization framework
# ✅ Enable VirtioFS accelerated directory sharing
```

## Socket and Permission Problems

### Socket Permission Denied

#### Symptom: "Permission denied" accessing Docker socket
```bash
# Test socket access
ls -la /var/run/docker.sock
# Should show: srw-rw----  1 root  docker

# Test direct socket communication
curl --unix-socket /var/run/docker.sock http://localhost/version
```

**Solutions**:

1. **Add User to Docker Group (Linux)**
```bash
# Note: This doesn't apply to macOS Docker Desktop
# But useful for remote Linux Docker hosts
sudo usermod -aG docker $USER
# Logout and login for changes to take effect
```

2. **Fix Docker Desktop Socket**
```bash
# On macOS, restart Docker Desktop
killall Docker\ Desktop
open -a Docker

# Wait for socket to be recreated
while [ ! -S /var/run/docker.sock ]; do
    echo "Waiting for Docker socket..."
    sleep 2
done
```

### Socket Not Found

#### Symptom: "/var/run/docker.sock: No such file or directory"
```bash
# Check if socket exists
ls -la /var/run/docker.sock

# Check Docker Desktop status
docker context ls
```

**Solutions**:

1. **Start Docker Desktop**
```bash
open -a Docker

# Wait for startup
until docker info >/dev/null 2>&1; do
    echo "Waiting for Docker Desktop to start..."
    sleep 5
done
```

2. **Check Docker Context**
```bash
# List available contexts
docker context ls

# Switch to default context
docker context use default

# Inspect context
docker context inspect default
```

## Network and Firewall Issues

### Corporate Firewall Problems

#### Symptom: Cannot pull images or connect to Docker Hub
```bash
# Test Docker Hub connectivity
docker pull hello-world

# Test direct connectivity
curl -I https://registry-1.docker.io
```

**Solutions**:

1. **Configure HTTP Proxy**
```bash
# Docker Desktop -> Preferences -> Resources -> Proxies
# HTTP Proxy: http://proxy.company.com:8080
# HTTPS Proxy: http://proxy.company.com:8080

# Or via environment variables
export HTTP_PROXY=http://proxy.company.com:8080
export HTTPS_PROXY=http://proxy.company.com:8080
export NO_PROXY=localhost,127.0.0.1
```

2. **Configure Docker Daemon Proxy**
```bash
# Create Docker daemon config
mkdir -p ~/.docker
cat > ~/.docker/daemon.json << EOF
{
  "proxies": {
    "default": {
      "httpProxy": "http://proxy.company.com:8080",
      "httpsProxy": "http://proxy.company.com:8080",
      "noProxy": "localhost,127.0.0.1"
    }
  }
}
EOF

# Restart Docker Desktop
```

### DNS Resolution Issues

#### Symptom: Cannot resolve hostnames from containers
```bash
# Test DNS resolution from container
docker run --rm alpine nslookup google.com
```

**Solutions**:

1. **Configure DNS Servers**
```bash
# Docker Desktop -> Preferences -> Resources -> Network
# DNS Server: 8.8.8.8, 8.8.4.4

# Or in daemon.json
cat > ~/.docker/daemon.json << EOF
{
  "dns": ["8.8.8.8", "8.8.4.4"]
}
EOF
```

2. **Check System DNS**
```bash
# Check system DNS settings
scutil --dns

# Test system DNS resolution
nslookup google.com
```

## API and Version Compatibility

### API Version Mismatch

#### Symptom: "API version X.Y is not supported"
```bash
# Check Docker API versions
docker version --format json | jq '{client: .Client.ApiVersion, server: .Server.ApiVersion}'
```

**Solutions**:

1. **Set Compatible API Version**
```bash
# Find supported version
docker version

# Set environment variable
export DOCKER_API_VERSION=1.41

# Test with toolkit
python scripts/discovery/docker_inventory.py
```

2. **Update Docker Desktop**
```bash
# Update to latest version
brew upgrade --cask docker

# Or manual update
# Docker Desktop -> Check for Updates
```

### Python Docker SDK Issues

#### Symptom: Docker SDK compatibility problems
```bash
# Check Docker SDK version
pip show docker

# Test SDK functionality
python3 -c "
import docker
client = docker.from_env()
print('API Version:', client.api.api_version)
print('Server Version:', client.version()['Version'])
"
```

**Solutions**:

1. **Update Docker SDK**
```bash
# Update to compatible version
pip install --upgrade docker

# Or install specific version
pip install docker==6.1.3
```

2. **Downgrade if Necessary**
```bash
# If newer SDK has compatibility issues
pip install docker==6.0.0
```

## Remote Docker Connections

### SSH Tunnel Issues

#### Symptom: Cannot connect to remote Docker via SSH
```bash
# Test SSH connection
ssh user@docker-host docker info

# Test Docker over SSH
export DOCKER_HOST=ssh://user@docker-host
docker info
```

**Solutions**:

1. **Configure SSH Keys**
```bash
# Generate SSH key if needed
ssh-keygen -t rsa -b 4096

# Copy to remote host
ssh-copy-id user@docker-host

# Test key-based auth
ssh user@docker-host "echo 'SSH working'"
```

2. **Configure Docker Context**
```bash
# Create SSH context
docker context create remote-docker \
  --docker "host=ssh://user@docker-host"

# Use remote context
docker context use remote-docker
docker info
```

### TLS Connection Issues

#### Symptom: TLS verification failures
```bash
# Test TLS connection
export DOCKER_HOST=tcp://docker-host:2376
export DOCKER_TLS_VERIFY=1
export DOCKER_CERT_PATH=/path/to/certs
docker info
```

**Solutions**:

1. **Verify Certificate Files**
```bash
# Check certificate files exist
ls -la $DOCKER_CERT_PATH/
# Should contain: ca.pem, cert.pem, key.pem

# Test certificate validity
openssl x509 -in $DOCKER_CERT_PATH/cert.pem -text -noout
```

2. **Regenerate Certificates**
```bash
# On Docker host, regenerate certificates
# Follow Docker documentation for TLS setup
```

## Docker in Docker Issues

### DinD Permission Problems

#### Symptom: Cannot access Docker from within container
```bash
# Test DinD access
docker run --rm -v /var/run/docker.sock:/var/run/docker.sock docker:latest docker info
```

**Solutions**:

1. **Mount Docker Socket**
```bash
# Ensure proper socket mounting
docker run --rm \
  -v /var/run/docker.sock:/var/run/docker.sock \
  -v $(pwd):/workspace \
  -w /workspace \
  python:3.11 \
  pip install docker && python scripts/discovery/docker_inventory.py
```

2. **Use Docker-in-Docker Image**
```bash
# Use official DinD image
docker run --privileged --name dind -d docker:dind

# Connect to DinD instance
docker run --rm --link dind:docker docker:latest docker info
```

## Advanced Troubleshooting

### Docker Daemon Debugging

#### Enable Docker Debug Mode
```bash
# Edit Docker Desktop settings
# Docker Desktop -> Preferences -> Docker Engine
# Add: "debug": true

# Or create daemon.json
cat > ~/.docker/daemon.json << EOF
{
  "debug": true,
  "log-level": "debug"
}
EOF
```

#### Analyze Docker Logs
```bash
# Docker Desktop logs (macOS)
tail -f ~/Library/Containers/com.docker.docker/Data/log/host/Docker.log

# Container logs
docker logs --details container_name

# System logs (Linux)
journalctl -u docker.service -f
```

### Network Debugging

#### Inspect Docker Networks
```bash
# List all networks
docker network ls

# Inspect specific network
docker network inspect bridge

# Test container networking
docker run --rm --network host alpine ping -c 3 google.com
```

#### Port Binding Issues
```bash
# Check port usage
lsof -i :8080

# Test port binding
docker run --rm -p 8080:80 nginx:alpine

# Check if port is accessible
curl -I http://localhost:8080
```

### Performance Debugging

#### Monitor Docker Resource Usage
```bash
# Monitor Docker Desktop resources
docker system df
docker system events

# Container resource usage
docker stats --no-stream

# System resource usage
top -pid $(pgrep Docker)
```

#### Optimize Docker Performance
```bash
# Clean up unused resources
docker system prune -a

# Optimize Docker Desktop settings
# Reduce resource allocation if system is struggling
# Enable file sharing optimization
# Use Apple Virtualization Framework (M1 Macs)
```

### Recovery Procedures

#### Complete Docker Reset
```bash
#!/bin/bash
# complete_docker_reset.sh - Nuclear option for Docker issues

echo "WARNING: This will remove all Docker data!"
read -p "Continue? (y/N): " -n 1 -r
echo
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    exit 1
fi

# 1. Stop Docker Desktop
killall Docker\ Desktop

# 2. Remove all Docker data
rm -rf ~/Library/Group\ Containers/group.com.docker/
rm -rf ~/Library/Containers/com.docker.docker/
rm -rf ~/.docker/

# 3. Remove Homebrew installation (if applicable)
brew uninstall --cask docker 2>/dev/null || true

# 4. Reinstall Docker Desktop
brew install --cask docker

# 5. Start Docker Desktop
open -a Docker

echo "Docker reset complete. Wait for Docker Desktop to initialize."
```

---

**Prevention**: Most Docker connectivity issues can be prevented by keeping Docker Desktop updated, monitoring system resources, and following Docker best practices for your environment.

**Next Steps**: If Docker connectivity issues persist after following this guide, check [M1 Mac Compatibility Issues](m1-compatibility.md) for Apple Silicon-specific problems.