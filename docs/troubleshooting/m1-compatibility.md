# Apple Silicon Mac Compatibility Issues

Comprehensive troubleshooting guide for Apple Silicon (M1/M2/M3) specific issues in PodShift.

> **Navigation**: [← Docker Connectivity](docker-connectivity.md) | [Common Issues](common-issues.md)

**Related Documentation:**
- [Common Issues](common-issues.md) - General troubleshooting guide
- [Docker Connectivity](docker-connectivity.md) - Connection and API issues
- [Best Practices](../migration-guide/best-practices.md) - M1 Mac optimization techniques
- [System Requirements](../installation/system-requirements.md) - Apple Silicon requirements
- [Installation Troubleshooting](../installation/troubleshooting-installation.md) - M1 installation issues

## Table of Contents

1. [Architecture Detection Issues](#architecture-detection-issues)
2. [Image Compatibility Problems](#image-compatibility-problems)
3. [Performance Issues](#performance-issues)
4. [Rosetta 2 Problems](#rosetta-2-problems)
5. [Memory and Resource Issues](#memory-and-resource-issues)
6. [Docker Desktop on Apple Silicon](#docker-desktop-on-apple-silicon)
7. [Building and Multi-arch Issues](#building-and-multi-arch-issues)
8. [M1 Optimization Problems](#m1-optimization-problems)

## Architecture Detection Issues

### Wrong Architecture Detected

#### Symptom: System reports x86_64 instead of arm64
```bash
# Check actual architecture
uname -m
# Expected: arm64
# Actual: x86_64 (running under Rosetta)

# Check if running under Rosetta
sysctl sysctl.proc_translated
# 1 = Running under Rosetta, 0 = Native
```

**Root Causes & Solutions**:

1. **Terminal Running Under Rosetta**
```bash
# Check if Terminal is running under Rosetta
ps -ef | grep Terminal

# Fix: Ensure Terminal runs natively
# Applications -> Terminal -> Get Info -> Uncheck "Open using Rosetta"

# Or use native terminal
/System/Applications/Utilities/Terminal.app/Contents/MacOS/Terminal
```

2. **Shell Environment Issues**
```bash
# Check shell architecture
file /bin/zsh
# Should show: arm64

# Reset shell if needed
exec /bin/zsh -l

# Verify native execution
arch
# Should output: arm64
```

3. **Python Running Under Rosetta**
```bash
# Check Python architecture
python3 -c "import platform; print(platform.machine())"
# Should output: arm64

# If showing x86_64, reinstall Python natively
brew uninstall python@3.11
brew install python@3.11

# Recreate virtual environment
rm -rf venv/
python3 -m venv venv
```

### M1 Mac Not Recognized

#### Symptom: System analysis shows non-Apple Silicon
```bash
# Run system analysis
bash scripts/discovery/system_resources.sh

# Check output
jq '.architecture.is_apple_silicon' system_resources_*.json
# Expected: true
# Actual: false
```

**Solutions**:

1. **Update Detection Logic**
```bash
# Manual verification
sysctl machdep.cpu.brand_string
# Should contain "Apple M1", "Apple M2", or "Apple M3"

# Check CPU model detection
system_profiler SPHardwareDataType | grep "Chip"
```

2. **Override Detection**
```bash
# Set environment variable to force Apple Silicon mode
export PODSHIFT_APPLE_SILICON_OPTIMIZED=true
export PODSHIFT_FORCE_ARM64_DETECTION=true

# Re-run analysis
bash scripts/discovery/system_resources.sh
```

## Image Compatibility Problems

### AMD64 Images Won't Run

#### Symptom: "platform linux/amd64 not supported" on M1
```bash
# Test problematic image
docker run --platform linux/amd64 some-amd64-only-image
# Error: platform not supported or very slow
```

**Solutions**:

1. **Install Rosetta 2**
```bash
# Install Rosetta 2 for x86_64 emulation
softwareupdate --install-rosetta --agree-to-license

# Verify installation
ls -la /Library/Apple/usr/share/rosetta/rosetta
```

2. **Enable Docker Desktop x86_64 Emulation**
```bash
# Docker Desktop -> Settings -> Features in development
# ✅ Use Rosetta for x86/amd64 emulation on Apple Silicon

# Restart Docker Desktop
killall Docker\ Desktop
open -a Docker
```

3. **Find ARM64 Alternatives**
```bash
# Search for ARM64 version
docker search arm64v8/nginx

# Check multi-arch support
docker manifest inspect nginx:latest

# Use multi-arch official images when available
docker pull nginx:latest  # Should pull ARM64 automatically
```

### Multi-arch Image Issues

#### Symptom: Wrong architecture pulled despite M1 Mac
```bash
# Check pulled image architecture
docker image inspect nginx:latest | jq '.[0].Architecture'
# Expected: arm64
# Actual: amd64

# Or use docker buildx
docker buildx imagetools inspect nginx:latest
```

**Solutions**:

1. **Force ARM64 Pull**
```bash
# Explicitly specify platform
docker pull --platform linux/arm64 nginx:latest

# Verify architecture
docker image inspect nginx:latest | jq '.[0].Architecture'
```

2. **Configure Docker for ARM64 Preference**
```bash
# Set default platform
export DOCKER_DEFAULT_PLATFORM=linux/arm64

# Add to shell profile
echo 'export DOCKER_DEFAULT_PLATFORM=linux/arm64' >> ~/.zshrc
```

3. **Use Buildx for Multi-arch**
```bash
# Enable buildx
docker buildx create --use

# Build for multiple architectures
docker buildx build --platform linux/amd64,linux/arm64 -t myapp:latest .
```

### ARM64 Image Not Available

#### Symptom: Required image only exists for AMD64
```bash
# Check available architectures
docker manifest inspect legacy-app:latest
# Only shows amd64 manifest
```

**Solutions**:

1. **Build Custom ARM64 Image**
```dockerfile
# Dockerfile.arm64
FROM --platform=linux/arm64 alpine:latest

# Your application setup
COPY . /app
WORKDIR /app

# Build ARM64-specific optimizations
RUN apk add --no-cache gcc musl-dev

CMD ["./your-app"]
```

```bash
# Build ARM64 image
docker build --platform linux/arm64 -f Dockerfile.arm64 -t legacy-app:arm64 .
```

2. **Cross-compile Application**
```bash
# For Go applications
GOOS=linux GOARCH=arm64 go build -o app-arm64

# For Rust applications
cargo build --target aarch64-unknown-linux-gnu

# For Node.js applications
npm run build  # Usually architecture-independent
```

3. **Use Base Image Alternatives**
```bash
# Instead of ubuntu:18.04 (might be AMD64 only)
FROM arm64v8/ubuntu:18.04

# Or use newer versions with multi-arch support
FROM ubuntu:22.04  # Has ARM64 support
```

## Performance Issues

### Slow Container Performance

#### Symptom: Containers running significantly slower than expected
```bash
# Test container performance
time docker run --rm alpine echo "Performance test"

# Compare with native execution
time echo "Performance test"

# Check if running under emulation
docker run --rm alpine arch
# If shows x86_64 on M1 Mac, it's emulated
```

**Solutions**:

1. **Use Native ARM64 Images**
```bash
# Find ARM64 versions
docker search arm64v8/nginx
docker search --filter is-official=true nginx

# Pull ARM64 specifically
docker pull --platform linux/arm64 nginx:alpine
```

2. **Optimize Docker Desktop Settings**
```bash
# Docker Desktop -> Preferences -> Resources
# Enable: Use Apple Virtualization framework
# Enable: VirtioFS accelerated directory sharing
# CPU: 6-8 cores (leave 2 for macOS)
# Memory: 12-16GB (75% of total)
```

3. **Monitor Emulation Overhead**
```bash
# Check which containers are emulated
for container in $(docker ps --format "{{.Names}}"); do
    arch=$(docker exec $container arch 2>/dev/null || echo "unknown")
    echo "$container: $arch"
done
```

### High CPU Usage on M1

#### Symptom: Docker Desktop consuming excessive CPU
```bash
# Monitor Docker Desktop CPU usage
top -pid $(pgrep Docker)

# Check thermal throttling
pmset -g thermlog | tail -5
```

**Solutions**:

1. **Reduce CPU Allocation**
```bash
# Docker Desktop -> Preferences -> Resources
# Reduce CPU allocation from 8 to 6 cores
# This leaves performance cores for macOS
```

2. **Optimize Container Resource Limits**
```bash
# Limit container CPU usage
docker run --cpus="2.0" --memory="2g" your-container

# Use CPU shares for relative priority
docker run --cpu-shares=512 background-container
```

3. **Check for CPU-intensive Processes**
```bash
# Monitor container CPU usage
docker stats --no-stream

# Identify high-CPU containers
docker stats --format "table {{.Container}}\t{{.CPUPerc}}" --no-stream | sort -k2 -nr
```

## Rosetta 2 Problems

### Rosetta 2 Not Installing

#### Symptom: Rosetta 2 installation fails
```bash
# Attempt installation
softwareupdate --install-rosetta
# Error: Installation failed or command not found
```

**Solutions**:

1. **Manual Installation**
```bash
# Try with agreement acceptance
softwareupdate --install-rosetta --agree-to-license

# Check macOS version (Rosetta 2 requires macOS 11+)
sw_vers -productVersion
```

2. **Alternative Installation Method**
```bash
# Install via Software Update GUI
# System Preferences -> Software Update
# Look for Rosetta 2 in available updates

# Or trigger installation by running x86_64 binary
arch -x86_64 /usr/bin/true
```

3. **Verify Installation**
```bash
# Check if Rosetta is installed
ls -la /Library/Apple/usr/share/rosetta/

# Test x86_64 emulation
arch -x86_64 uname -m
# Should output: x86_64
```

### Rosetta 2 Performance Issues

#### Symptom: AMD64 containers extremely slow
```bash
# Test emulation performance
time docker run --platform linux/amd64 alpine echo "test"
# Taking > 10 seconds for simple commands
```

**Solutions**:

1. **Optimize Rosetta Settings**
```bash
# Ensure latest macOS version
sudo softwareupdate -ia

# Restart after Rosetta updates
sudo reboot
```

2. **Container-Specific Optimizations**
```bash
# Increase memory for emulated containers
docker run --platform linux/amd64 --memory=4g your-container

# Reduce concurrent emulated containers
# Run AMD64 containers sequentially when possible
```

3. **Consider ARM64 Migration**
```bash
# Instead of tolerating slow emulation
# Rebuild critical images for ARM64
docker buildx build --platform linux/arm64 -t your-app:arm64 .
```

## Memory and Resource Issues

### Memory Pressure on M1

#### Symptom: System becomes slow during Docker operations
```bash
# Check memory pressure
memory_pressure
# Output: "System-wide memory free percentage: 15%"

# Check swap usage
sysctl vm.swapusage
```

**Solutions**:

1. **Optimize Memory Allocation**
```bash
# Reduce Docker Desktop memory allocation
# Docker Desktop -> Preferences -> Resources
# Memory: 8GB instead of 16GB (on 16GB system)

# Configure swap
# Docker Desktop -> Preferences -> Resources
# Swap: 2GB (helps with memory pressure)
```

2. **Container Memory Limits**
```bash
# Set explicit memory limits
docker run --memory=2g --memory-swap=3g your-container

# Monitor container memory usage
docker stats --format "table {{.Container}}\t{{.MemUsage}}\t{{.MemPerc}}"
```

3. **System-wide Memory Management**
```bash
# Free up system memory
sudo purge

# Close memory-intensive applications
# Quit browsers, IDEs, etc. during migration analysis

# Monitor memory usage
vm_stat 1
```

### Unified Memory Architecture Issues

#### Symptom: Inefficient memory usage patterns
```bash
# Check memory statistics
vm_stat

# Look for high memory pressure indicators
# Pages paged in/out should be low
```

**Solutions**:

1. **Leverage Unified Memory Benefits**
```bash
# Configure containers to use shared memory efficiently
docker run --ipc=host --memory=4g your-container

# Use memory-mapped files when possible
docker run -v /dev/shm:/dev/shm your-container
```

2. **Optimize Memory Swappiness**
```bash
# Reduce swappiness for containers
docker run --memory-swappiness=10 your-container

# This works better with M1's unified memory
```

## Docker Desktop on Apple Silicon

### Docker Desktop Optimization

#### Symptom: Docker Desktop not optimized for M1
```bash
# Check if using optimized virtualization
docker info | grep -i virtualization
```

**Solutions**:

1. **Enable Apple Virtualization Framework**
```bash
# Docker Desktop -> Preferences -> General
# ✅ Use the new Virtualization framework
# ✅ Enable VirtioFS accelerated directory sharing

# Restart Docker Desktop to apply changes
```

2. **Optimize File Sharing**
```bash
# Docker Desktop -> Preferences -> Resources -> File sharing
# Use VirtioFS instead of gRPC FUSE
# Add only necessary directories to file sharing
```

3. **Configure Resource Limits**
```yaml
# Optimal settings for M1 MacBook Pro 16GB
cpus: 6                    # Leave 2 cores for macOS
memory: 12GB               # 75% of total memory
swap: 2GB                  # For memory pressure relief
disk: 64GB                 # Adequate for most workloads
```

### Docker Desktop Updates

#### Symptom: Older Docker Desktop version on M1
```bash
# Check Docker Desktop version
docker --version
# Docker version 20.10.x (older version)

# Check for M1-specific features
docker info | grep -i "Operating System"
```

**Solutions**:

1. **Update to Latest Version**
```bash
# Update via Homebrew
brew upgrade --cask docker

# Or manual update
# Docker Desktop -> Check for updates
```

2. **Enable Beta Features**
```bash
# Docker Desktop -> Preferences -> Features in development
# ✅ Access experimental features
# ✅ Use containerd for pulling and storing images
```

## Building and Multi-arch Issues

### Cross-compilation Problems

#### Symptom: Building for multiple architectures fails
```bash
# Multi-arch build failing
docker buildx build --platform linux/amd64,linux/arm64 -t myapp .
# Error: exec format error or build failures
```

**Solutions**:

1. **Setup Buildx Properly**
```bash
# Create new builder instance
docker buildx create --name multiarch --use

# Install QEMU for emulation
docker run --privileged --rm tonistiigi/binfmt --install all

# Verify supported platforms
docker buildx ls
```

2. **Fix Dockerfile for Multi-arch**
```dockerfile
# Use multi-arch base images
FROM --platform=$BUILDPLATFORM golang:1.19-alpine AS builder

# Use build arguments
ARG TARGETPLATFORM
ARG BUILDPLATFORM
ARG TARGETOS
ARG TARGETARCH

# Cross-compile in Go
RUN GOOS=$TARGETOS GOARCH=$TARGETARCH go build -o app .

# Use multi-arch runtime
FROM alpine:latest
COPY --from=builder /app/app /usr/local/bin/app
```

3. **Handle Architecture-Specific Dependencies**
```dockerfile
# Install packages based on architecture
RUN if [ "$TARGETARCH" = "arm64" ]; then \
        apk add --no-cache some-arm64-package; \
    else \
        apk add --no-cache some-amd64-package; \
    fi
```

## M1 Optimization Problems

### Suboptimal Performance Configuration

#### Symptom: Not getting optimal M1 performance
```bash
# Check current configuration
make system-check

# Look for optimization recommendations
jq '.recommendations.recommendations[]' system_resources_*.json
```

**Solutions**:

1. **Apply M1-Specific Settings**
```bash
# Set environment variables for M1 optimization
export PODSHIFT_APPLE_SILICON_OPTIMIZED=true
export PODSHIFT_USE_PERFORMANCE_CORES=true
export PODSHIFT_UNIFIED_MEMORY_AWARE=true

# Add to shell profile
cat >> ~/.zshrc << 'EOF'
# Apple Silicon Mac optimizations for PodShift
export PODSHIFT_APPLE_SILICON_OPTIMIZED=true
export PODSHIFT_USE_PERFORMANCE_CORES=true
export PODSHIFT_UNIFIED_MEMORY_AWARE=true
EOF
```

2. **Configure CPU Affinity**
```bash
# Use performance cores for intensive tasks
docker run --cpuset-cpus="0-3" cpu-intensive-task

# Use efficiency cores for background tasks
docker run --cpuset-cpus="4-7" background-service
```

3. **Optimize Memory Settings**
```bash
# Configure for unified memory architecture
docker run --memory=4g --memory-reservation=3g \
  --memory-swappiness=1 your-container
```

### Thermal Management Issues

#### Symptom: M1 Mac overheating during analysis
```bash
# Check thermal state
pmset -g thermlog | tail -5

# Monitor CPU temperature (requires additional tools)
sudo powermetrics --samplers smc -n 1 | grep -i temp
```

**Solutions**:

1. **Reduce Analysis Intensity**
```bash
# Limit concurrent operations
export PODSHIFT_MAX_WORKERS=2

# Add delays between operations
export PODSHIFT_ANALYSIS_DELAY=5  # seconds between containers

# Run analysis in smaller batches
python scripts/discovery/docker_inventory.py --containers-only
sleep 60
python scripts/discovery/docker_inventory.py --images-only
```

2. **Optimize Cooling**
```bash
# Ensure proper ventilation
# Clean vents and fans if necessary
# Use laptop stand for better airflow

# Reduce background processes
# Quit unnecessary applications during analysis
```

### Recovery and Fallback Procedures

#### Complete M1 Optimization Reset
```bash
#!/bin/bash
# m1_optimization_reset.sh - Reset M1-specific configurations

echo "Resetting M1 Mac optimizations..."

# 1. Reset Docker Desktop to defaults
# Docker Desktop -> Troubleshoot -> Reset to factory defaults

# 2. Clear environment variables
unset PODSHIFT_APPLE_SILICON_OPTIMIZED
unset PODSHIFT_USE_PERFORMANCE_CORES
unset PODSHIFT_UNIFIED_MEMORY_AWARE
unset DOCKER_DEFAULT_PLATFORM

# 3. Reinstall Docker Desktop with M1 optimization
brew uninstall --cask docker
brew install --cask docker

# 4. Reconfigure for M1
open -a Docker
# Wait for Docker to start, then configure:
# - Enable Apple Virtualization framework
# - Enable VirtioFS
# - Set appropriate resource limits

# 5. Test M1 optimization
source ./activate.sh
make system-check

echo "M1 optimization reset complete"
```

---

**Performance Tips**: M1 Macs excel with native ARM64 containers but can handle AMD64 containers through Rosetta 2 when necessary. Focus on finding ARM64 alternatives for critical workloads while accepting emulation for legacy applications.

**Monitoring**: Regularly monitor thermal state and memory pressure during intensive operations to prevent system slowdowns and ensure optimal performance.

**Next Steps**: For installation-specific M1 issues, see [Installation Troubleshooting](../installation/troubleshooting-installation.md). For general Docker problems, see [Docker Connectivity Issues](docker-connectivity.md).