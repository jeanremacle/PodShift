# PodShift

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)
[![Python 3.8+](https://img.shields.io/badge/python-3.8+-blue.svg)](https://www.python.org/downloads/)
[![macOS 12.0+](https://img.shields.io/badge/macOS-12.0+-green.svg)](https://www.apple.com/macos/)
[![Apple Silicon](https://img.shields.io/badge/Apple_Silicon-M1%2FM2%2FM3-red.svg)](https://www.apple.com/mac/)

**PodShift - Seamless Docker to Podman Migration for Apple Silicon**

## 🚀 Overview

PodShift provides a complete solution for analyzing your existing Docker environment and migrating containers, images, volumes, and networks to Podman with optimal performance on Apple Silicon Macs. PodShift includes intelligent dependency mapping, system resource analysis, and automated migration sequencing.

### Key Features

- **🔍 Comprehensive Discovery**: Deep analysis of Docker containers, images, volumes, networks, and Compose files
- **🧠 Intelligent Dependency Mapping**: Automatically detects container relationships and startup dependencies
- **⚡ M1 Mac Optimization**: Native Apple Silicon support with architecture compatibility analysis
- **📊 System Resource Analysis**: Detailed system requirements checking and resource allocation recommendations
- **🔗 Migration Sequencing**: Automated planning for parallel and sequential migration phases
- **💾 Configuration Backup**: Safe backup of Docker configurations before migration
- **📈 Compatibility Scoring**: M1 Mac compatibility assessment with actionable recommendations
- **🔧 Multiple Output Formats**: JSON reports, human-readable summaries, and detailed logs

## 📋 System Requirements

### Minimum Requirements
- **Operating System**: macOS 12.0 (Monterey) or later
- **Architecture**: Apple Silicon (M1/M2/M3) recommended, Intel Macs supported
- **Memory**: 4GB RAM minimum, 8GB recommended
- **Storage**: 10GB free disk space minimum, 50GB recommended
- **Python**: Python 3.8 or later
- **Tools**: Git, curl, wget (installed via Homebrew)

### Recommended Configuration
- **macOS**: Latest version for optimal compatibility
- **Memory**: 16GB RAM for large container environments
- **Storage**: SSD with 100GB+ free space
- **Docker**: Docker Desktop 4.0+ (for migration source analysis)

## 🛠 Installation

### Quick Start
```bash
# Clone the repository
git clone <repository-url>
cd podshift

# Run automated setup
./setup.sh

# Activate the environment
source ./activate.sh
```

### Manual Installation
```bash
# Install system dependencies via Homebrew
brew install python@3.11 jq git curl wget

# Create Python virtual environment
python3 -m venv venv
source venv/bin/activate

# Install Python dependencies
pip install -r requirements.txt
```

### Using Make
```bash
# Complete setup
make setup

# Install dependencies only
make install

# Check system status
make status
```

## 🔧 Usage

### Basic Discovery
```bash
# Run complete Docker discovery
bash scripts/discovery/discover_containers.sh

# Or using Make
make discovery
```

### Individual Operations

#### System Analysis
```bash
# Check M1 Mac system resources
bash scripts/discovery/system_resources.sh --verbose

# Using Make
make system-check
```

#### Docker Inventory
```bash
# Comprehensive Docker resource inventory
python scripts/discovery/docker_inventory.py --verbose

# Using Make
make docker-inventory
```

#### Dependency Mapping
```bash
# Analyze container dependencies
python scripts/discovery/dependency_mapper.py --verbose

# Using Make
make dependency-mapping
```

### Command Line Options

#### Discovery Scripts
```bash
# System resources script
./scripts/discovery/system_resources.sh [OPTIONS]
  --verbose              Enable detailed output
  --output-dir DIR       Custom output directory
  --timestamp STAMP      Custom timestamp
  --json-only           JSON output only

# Docker inventory script
python scripts/discovery/docker_inventory.py [OPTIONS]
  --verbose              Enable detailed output
  --output-dir DIR       Custom output directory
  --timestamp STAMP      Custom timestamp
  --containers-only      Analyze containers only
  --images-only         Analyze images only
  --volumes-only        Analyze volumes only
  --networks-only       Analyze networks only

# Dependency mapper script
python scripts/discovery/dependency_mapper.py [OPTIONS]
  --verbose              Enable detailed output
  --output-dir DIR       Custom output directory
  --timestamp STAMP      Custom timestamp
  --compose-files FILES  Specific Compose files
  --containers-only      Skip Compose analysis
```

## 📊 Output Files

PodShift generates comprehensive reports in multiple formats:

### JSON Reports
- `docker_inventory_TIMESTAMP.json` - Complete Docker resource inventory
- `container_dependencies_TIMESTAMP.json` - Dependency mapping and migration sequence
- `system_resources_TIMESTAMP.json` - M1 Mac system analysis
- `docker_discovery_report_TIMESTAMP.json` - Comprehensive discovery summary

### Human-Readable Reports
- `docker_discovery_summary_TIMESTAMP.txt` - Executive summary
- Various `.txt` files with tabular data for easy reading

### Log Files
- `logs/discovery_TIMESTAMP.log` - Main discovery operations log
- `logs/system_resources_TIMESTAMP.log` - System analysis log
- `logs/setup_TIMESTAMP.log` - Installation log

## 🏗 Project Structure

```
podshift/
├── README.md                          # This file
├── setup.sh                          # Automated system setup
├── activate.sh                       # Environment activation
├── Makefile                          # Common operations
├── requirements.txt                   # Python dependencies
├── pyproject.toml                    # Project configuration
├── CONTRIBUTING.md                   # Contribution guidelines
├── SECURITY.md                       # Security policy
├── CHANGELOG.md                      # Version history
├── docs/                             # Documentation
│   ├── installation/                 # Installation guides
│   ├── migration-guide/              # Migration documentation
│   ├── api/                          # Script reference
│   └── troubleshooting/              # Troubleshooting guides
├── scripts/                          # Core scripts
│   ├── discovery/                    # Discovery scripts
│   │   ├── docker_inventory.py       # Docker resource inventory
│   │   ├── dependency_mapper.py      # Dependency analysis
│   │   ├── system_resources.sh       # System analysis
│   │   └── discover_containers.sh    # Main orchestration
│   ├── migration/                    # Migration scripts
│   ├── podman-setup/                # Podman installation
│   ├── cleanup/                      # Cleanup utilities
│   └── utils/                        # Helper utilities
├── configs/                          # Configuration files
│   ├── templates/                    # Configuration templates
│   ├── m1-optimized/                # M1-specific configs
│   └── validation/                   # Config validation
├── logs/                             # Log files
├── backups/                          # Configuration backups
├── rollback/                         # Rollback scripts
└── tests/                            # Test suite
    ├── unit/                         # Unit tests
    ├── integration/                  # Integration tests
    └── fixtures/                     # Test data
```

## 🧭 Migration Workflow

### 1. Pre-Migration Analysis
```bash
# Check system readiness
make system-check

# Discover Docker resources
make docker-inventory

# Analyze dependencies
make dependency-mapping
```

### 2. Review Reports
- Examine generated JSON reports for compatibility issues
- Review dependency graphs and migration sequences
- Check system resource recommendations

### 3. Plan Migration
- Use dependency analysis to plan migration phases
- Identify containers requiring architecture changes
- Plan downtime windows for critical services

### 4. Execute Migration
- Follow migration sequences from dependency analysis
- Use recommended resource allocations
- Monitor logs for issues

## 📈 M1 Mac Compatibility Features

### Architecture Analysis
- **Native ARM64 Detection**: Identifies containers running natively on Apple Silicon
- **Emulation Detection**: Flags containers running under Rosetta 2 emulation
- **Multi-Architecture Support**: Detects and recommends multi-arch images
- **Performance Optimization**: Provides M1-specific configuration recommendations

### Resource Optimization
- **75% Rule**: Recommends optimal resource allocation (75% of system resources)
- **Performance Cores**: Utilizes M1 performance and efficiency cores effectively
- **Memory Management**: Optimizes memory allocation for Apple Silicon
- **Storage Optimization**: SSD-optimized configuration recommendations

### Compatibility Scoring
- **Overall Compatibility Score**: 0-100 score for migration readiness
- **Issue Identification**: Specific compatibility problems and solutions
- **Actionable Recommendations**: Step-by-step migration guidance

## 🔧 Configuration

### Environment Variables
```bash
# Custom output directory
export PODSHIFT_OUTPUT_DIR="/path/to/output"

# Custom log level
export PODSHIFT_LOG_LEVEL="DEBUG"

# Custom timestamp format
export PODSHIFT_TIMESTAMP_FORMAT="%Y%m%d_%H%M%S"
```

### Configuration Files
- `configs/templates/` - Default configuration templates
- `configs/m1-optimized/` - M1 Mac optimized configurations
- `configs/validation/` - Configuration validation schemas

## 🚨 Troubleshooting

### Common Issues

#### Docker Connection Issues
```bash
# Check Docker status
docker info

# Restart Docker Desktop
open -a "Docker Desktop"
```

#### Permission Issues
```bash
# Fix Docker socket permissions
sudo chmod 666 /var/run/docker.sock

# Or add user to docker group (requires logout/login)
sudo dseditgroup -o edit -a $(whoami) -t user docker
```

#### Python Environment Issues
```bash
# Recreate virtual environment
rm -rf venv
make setup
```

### Getting Help
- Check the `docs/troubleshooting/` directory for detailed guides
- Review log files in the `logs/` directory
- Consult the FAQ in `docs/troubleshooting/common-issues.md`

## 🤝 Contributing

We welcome contributions! Please see [CONTRIBUTING.md](CONTRIBUTING.md) for guidelines on:
- Code standards and formatting
- Testing requirements
- Pull request process
- Development environment setup

### Development Setup
```bash
# Clone and setup development environment
make setup

# Install development dependencies
pip install -e .[dev]

# Run tests
make test

# Run linting
make lint

# Format code
make format
```

## 📄 License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## 🔒 Security

For security-related issues, please see [SECURITY.md](SECURITY.md) for our security policy and reporting procedures.

## 📚 Documentation

### Quick Links
- [Installation Guide](docs/installation/installation-guide.md)
- [Migration Guide](docs/migration-guide/quick-start.md)
- [API Reference](docs/api/script-reference.md)
- [Troubleshooting](docs/troubleshooting/common-issues.md)

### External Resources
- [Podman Official Documentation](https://podman.io/docs)
- [Docker to Podman Migration Guide](https://podman.io/docs/migrating-from-docker)
- [Apple Silicon Developer Guide](https://developer.apple.com/documentation/apple-silicon)

## 📞 Support

- **Documentation**: Check the `docs/` directory
- **Issues**: Open an issue on GitHub
- **Discussions**: Use GitHub Discussions for questions
- **Community**: Join the Podman community forums

## 🎯 Roadmap

### Current Version (1.0.0)
- ✅ Comprehensive Docker discovery
- ✅ M1 Mac system analysis
- ✅ Dependency mapping
- ✅ Configuration backup

### Upcoming Features
- 🔄 Automated Podman installation
- 🔄 Real-time migration execution
- 🔄 Web-based GUI interface
- 🔄 Integration with CI/CD pipelines
- 🔄 Advanced rollback capabilities

---

**Made with ❤️ for the Apple Silicon community**

*PodShift is optimized for M1, M2, and M3 Macs to provide the best possible Docker to Podman migration experience.*