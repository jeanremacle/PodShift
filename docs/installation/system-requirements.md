# System Requirements

Detailed system requirements and compatibility information for PodShift on macOS.

> **Navigation**: [Installation Guide](installation-guide.md) | [Installation Troubleshooting →](troubleshooting-installation.md)

**Related Documentation:**
- [Installation Guide](installation-guide.md) - Complete installation process
- [Installation Troubleshooting](troubleshooting-installation.md) - Installation issues and solutions
- [M1 Compatibility](../troubleshooting/m1-compatibility.md) - Apple Silicon specific considerations
- [Quick Start Guide](../migration-guide/quick-start.md) - Get started quickly after installation

## Table of Contents

1. [Hardware Requirements](#hardware-requirements)
2. [Software Requirements](#software-requirements)
3. [Apple Silicon Specifics](#apple-silicon-specifics)
4. [Resource Recommendations](#resource-recommendations)
5. [Compatibility Matrix](#compatibility-matrix)
6. [Performance Considerations](#performance-considerations)
7. [Network Requirements](#network-requirements)

## Hardware Requirements

### Minimum Requirements

| Component | Minimum | Recommended | Optimal |
|-----------|---------|-------------|---------|
| **CPU** | 2 cores | 4 cores | 8+ cores (M1 Pro/Max/Ultra) |
| **Memory** | 4GB RAM | 8GB RAM | 16GB+ RAM |
| **Storage** | 10GB free | 50GB free | 100GB+ SSD |
| **Architecture** | Intel x86_64 | Apple Silicon (ARM64) | Apple Silicon M2/M3 |

### Supported Mac Models

#### Apple Silicon (Recommended)
- **MacBook Air (M1, 2020)**
- **MacBook Air (M2, 2022)**
- **MacBook Pro 13" (M1, 2020)**
- **MacBook Pro 13" (M2, 2022)**
- **MacBook Pro 14" (M1 Pro/Max, 2021)**
- **MacBook Pro 16" (M1 Pro/Max, 2021)**
- **MacBook Pro 14" (M2 Pro/Max, 2023)**
- **MacBook Pro 16" (M2 Pro/Max, 2023)**
- **iMac 24" (M1, 2021)**
- **Mac mini (M1, 2020)**
- **Mac mini (M2, 2023)**
- **Mac Studio (M1 Max/Ultra, 2022)**
- **Mac Studio (M2 Max/Ultra, 2023)**
- **Mac Pro (M2 Ultra, 2023)**

#### Intel Macs (Supported)
- **MacBook Pro 13" (2016-2020)**
- **MacBook Pro 15" (2016-2019)**
- **MacBook Pro 16" (2019)**
- **iMac 21.5" (2017-2019)**
- **iMac 27" (2017-2020)**
- **iMac Pro 27" (2017)**
- **Mac mini (2018)**
- **Mac Pro (2019)**

### Storage Requirements

#### Disk Space Breakdown
```
Base Installation:     ~500MB
Python Dependencies:   ~200MB
Docker Analysis:       ~1-5GB (varies by environment)
Generated Reports:     ~10-100MB per analysis
Logs and Backups:     ~50-500MB
Recommended Buffer:    10GB+
```

#### Storage Type Performance
- **NVMe SSD**: Optimal performance (all modern Macs)
- **SATA SSD**: Good performance (some older iMacs)
- **Fusion Drive**: Acceptable performance (avoid if possible)
- **HDD**: Not recommended (very slow analysis)

## Software Requirements

### Operating System

| macOS Version | Support Level | Notes |
|---------------|---------------|-------|
| **macOS 14.0+ (Sonoma)** | ✅ Fully Supported | Latest features, optimal performance |
| **macOS 13.0+ (Ventura)** | ✅ Fully Supported | Recommended minimum |
| **macOS 12.0+ (Monterey)** | ✅ Supported | Minimum required version |
| **macOS 11.0+ (Big Sur)** | ⚠️ Limited Support | Security updates recommended |
| **macOS 10.15 (Catalina)** | ❌ Not Supported | Too old, security risks |

### Required Software

#### Core Dependencies
- **Python 3.8+**: Required for all analysis scripts
- **Git**: Version control and repository cloning
- **Homebrew**: Package management for macOS
- **Xcode Command Line Tools**: Compilation tools

#### Python Packages
```python
# Core requirements (automatically installed)
docker>=6.1.0,<8.0.0    # Docker API client
PyYAML>=6.0,<7.0         # YAML parsing

# Development requirements (optional)
pytest>=7.0.0,<8.0.0     # Testing framework
black>=23.0.0,<24.0.0    # Code formatting
flake8>=6.0.0,<7.0.0     # Code linting
mypy>=1.0.0,<2.0.0       # Type checking
```

#### System Tools
```bash
# Installed via Homebrew
jq          # JSON processing
curl        # HTTP client
wget        # File downloads
```

### Optional Software

#### Docker Environment (Source)
- **Docker Desktop 4.0+**: For analyzing existing Docker installations
- **Docker CLI**: Command-line interface
- **Docker Compose**: Multi-container application management

#### Development Tools (Optional)
- **Visual Studio Code**: Code editing with Python extensions
- **PyCharm**: Full-featured Python IDE
- **iTerm2**: Enhanced terminal experience

## Apple Silicon Specifics

### M1/M2/M3 Advantages
- **Native ARM64 Performance**: No emulation overhead
- **Unified Memory Architecture**: Efficient memory usage
- **Efficient Power Usage**: Longer battery life during analysis
- **Fast NVMe Storage**: Quick file operations

### Architecture Detection
The toolkit automatically detects your Mac architecture:

```bash
# Check your architecture
uname -m

# Expected outputs:
# arm64    - Apple Silicon (M1/M2/M3)
# x86_64   - Intel processor
```

### Rosetta 2 Considerations
- **Installation**: Required for x86_64 container compatibility analysis
- **Performance Impact**: Minimal for toolkit operation
- **Installation Command**: `softwareupdate --install-rosetta`

## Resource Recommendations

### Memory Allocation

#### Small Environments (< 10 containers)
- **Minimum**: 4GB system RAM
- **Recommended**: 8GB system RAM
- **Toolkit Usage**: ~500MB during analysis

#### Medium Environments (10-50 containers)
- **Minimum**: 8GB system RAM
- **Recommended**: 16GB system RAM
- **Toolkit Usage**: ~1-2GB during analysis

#### Large Environments (50+ containers)
- **Minimum**: 16GB system RAM
- **Recommended**: 32GB+ system RAM
- **Toolkit Usage**: ~2-4GB during analysis

### CPU Usage

#### Analysis Workload Distribution
```
System Resource Analysis:  Light (1 core, ~30 seconds)
Docker Inventory:         Medium (2-4 cores, ~1-5 minutes)  
Dependency Mapping:       Heavy (4+ cores, ~2-10 minutes)
Report Generation:        Light (1 core, ~10 seconds)
```

### Storage I/O Patterns
- **Read-Heavy**: Docker image and container inspection
- **Write-Heavy**: JSON report generation and logging
- **Sequential Access**: Log file writing
- **Random Access**: Configuration file reading

## Compatibility Matrix

### Python Version Compatibility

| Python Version | Support Status | Performance | Notes |
|----------------|----------------|-------------|-------|
| **3.12** | ✅ Fully Supported | Excellent | Latest features |
| **3.11** | ✅ Fully Supported | Excellent | Recommended |
| **3.10** | ✅ Fully Supported | Very Good | Stable choice |
| **3.9** | ✅ Supported | Good | Older but reliable |
| **3.8** | ✅ Minimum Support | Good | Minimum required |
| **3.7** | ❌ Not Supported | N/A | End of life |

### Docker Version Compatibility

| Docker Version | Analysis Support | Notes |
|----------------|------------------|-------|
| **Docker Desktop 4.20+** | ✅ Full Support | Latest features |
| **Docker Desktop 4.10-4.19** | ✅ Full Support | Recommended |
| **Docker Desktop 4.0-4.9** | ✅ Basic Support | Some limitations |
| **Docker Desktop 3.x** | ⚠️ Limited Support | Upgrade recommended |
| **Docker Desktop 2.x** | ❌ Not Supported | Too old |

### Homebrew Compatibility
- **Homebrew 4.0+**: Fully supported
- **Homebrew 3.x**: Supported with warnings
- **Homebrew 2.x**: Not recommended

## Performance Considerations

### Apple Silicon Optimization

#### Performance Cores vs Efficiency Cores
```bash
# M1/M2/M3 core distribution examples:
M1:      4 performance + 4 efficiency cores
M1 Pro:  8 performance + 2 efficiency cores  
M1 Max:  8 performance + 2 efficiency cores
M2:      4 performance + 4 efficiency cores
M2 Pro:  8 performance + 4 efficiency cores
M2 Max:  8 performance + 4 efficiency cores
```

#### Memory Bandwidth
- **M1**: 68.25 GB/s unified memory bandwidth
- **M1 Pro/Max**: Up to 200-400 GB/s
- **M2**: 100 GB/s unified memory bandwidth
- **M2 Pro/Max**: Up to 200-400 GB/s

### Performance Benchmarks

#### Typical Analysis Times (M1 MacBook Pro, 16GB RAM)

| Environment Size | Docker Inventory | Dependency Mapping | Total Time |
|------------------|------------------|-------------------|------------|
| **Small (1-10 containers)** | 30 seconds | 15 seconds | ~1 minute |
| **Medium (10-50 containers)** | 2 minutes | 1 minute | ~4 minutes |
| **Large (50-100 containers)** | 5 minutes | 3 minutes | ~10 minutes |
| **Very Large (100+ containers)** | 10+ minutes | 8+ minutes | ~20+ minutes |

### Optimization Tips

#### System Optimization
```bash
# Free up memory before analysis
sudo purge

# Close unnecessary applications
# Ensure adequate disk space (10GB+)
# Use SSD storage for best performance
```

#### Analysis Optimization
```bash
# Use parallel processing where available
make discovery  # Uses optimal parallelization

# Increase verbosity only when needed
# --verbose flag adds overhead
```

## Network Requirements

### Internet Connectivity
- **Required for**: Initial setup and dependency installation
- **Bandwidth**: Minimum 1 Mbps for setup
- **Protocols**: HTTPS (443), HTTP (80), Git (22)

### Corporate Networks
- **Proxy Support**: Configure HTTP/HTTPS proxy settings
- **Firewall**: Allow access to package repositories
- **Certificate Issues**: May require corporate CA certificates

### Offline Usage
- **After Installation**: Toolkit can run completely offline
- **Docker Analysis**: No internet required for local Docker analysis
- **Updates**: Internet required for toolkit updates

## Verification Commands

### System Check Script
```bash
# Run comprehensive system check
make system-check

# Or directly
bash scripts/discovery/system_resources.sh --verbose
```

### Manual Verification
```bash
# Check macOS version
sw_vers -productVersion

# Check architecture  
uname -m

# Check available memory
system_profiler SPHardwareDataType | grep "Memory:"

# Check disk space
df -h /

# Check Python version
python3 --version

# Check required tools
jq --version
git --version
```

## Troubleshooting Requirements Issues

### Common Issues

#### Insufficient Memory
```bash
# Check memory usage
top -l 1 | grep "PhysMem"

# Free up memory
sudo purge

# Close memory-intensive applications
```

#### Insufficient Disk Space
```bash
# Check disk usage
du -sh * | sort -hr

# Clean system caches
sudo rm -rf ~/Library/Caches/*
sudo rm -rf /System/Library/Caches/*

# Clean Docker (if installed)
docker system prune -a
```

#### Outdated macOS
```bash
# Check for updates
sudo softwareupdate -l

# Install updates
sudo softwareupdate -ia
```

---

**Note**: These requirements ensure optimal performance and compatibility. The toolkit may work with lower specifications but performance and reliability may be affected.