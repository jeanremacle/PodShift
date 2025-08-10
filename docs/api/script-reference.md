# Script Reference Guide

Complete reference documentation for all scripts in PodShift.

> **Navigation**: [← Back to README](../../README.md) | [Configuration Options →](configuration-options.md) | [Output Formats →](output-formats.md)

**Related Documentation:**
- [Configuration Options](configuration-options.md) - Complete configuration reference
- [Output Formats](output-formats.md) - JSON schemas and output documentation
- [Quick Start Guide](../migration-guide/quick-start.md) - Basic usage examples
- [Discovery Process](../migration-guide/discovery-process.md) - Detailed script usage
- [Troubleshooting](../troubleshooting/common-issues.md) - Script-specific issues

## Table of Contents

1. [Overview](#overview)
2. [Discovery Scripts](#discovery-scripts)
3. [System Scripts](#system-scripts)
4. [Utility Scripts](#utility-scripts)
5. [Common Parameters](#common-parameters)
6. [Exit Codes](#exit-codes)
7. [Environment Variables](#environment-variables)
8. [Examples](#examples)

## Overview

PodShift includes several scripts for different phases of the migration process:

| Script | Category | Purpose | Language |
|--------|----------|---------|----------|
| [`setup.sh`](../../setup.sh) | System | Initial system setup and dependency installation | Bash |
| [`activate.sh`](../../activate.sh) | System | Environment activation | Bash |
| [`system_resources.sh`](../../scripts/discovery/system_resources.sh) | Discovery | M1 Mac system analysis | Bash |
| [`discover_containers.sh`](../../scripts/discovery/discover_containers.sh) | Discovery | Main discovery orchestration | Bash |
| [`docker_inventory.py`](../../scripts/discovery/docker_inventory.py) | Discovery | Comprehensive Docker inventory | Python |
| [`dependency_mapper.py`](../../scripts/discovery/dependency_mapper.py) | Discovery | Container dependency analysis | Python |

## Discovery Scripts

### discover_containers.sh

**Purpose**: Main orchestration script that runs all discovery operations.

**Location**: [`scripts/discovery/discover_containers.sh`](../../scripts/discovery/discover_containers.sh)

**Usage**:
```bash
bash scripts/discovery/discover_containers.sh [OPTIONS]
```

**Options**:
- `-v, --verbose` - Enable verbose output
- `-h, --help` - Show help message
- `--skip-backup` - Skip Docker configuration backup
- `--output-dir DIR` - Specify custom output directory

**What it does**:
1. Checks Docker installation and status
2. Discovers containers, images, volumes, networks
3. Finds Docker Compose files
4. Backs up Docker configuration
5. Runs Python discovery scripts
6. Runs system analysis
7. Generates comprehensive reports

**Output Files**:
- `docker_discovery_report_TIMESTAMP.json` - Main discovery report
- `docker_discovery_summary_TIMESTAMP.txt` - Human-readable summary
- Various individual resource files (containers, images, etc.)

**Example**:
```bash
# Basic discovery
bash scripts/discovery/discover_containers.sh

# Verbose discovery with custom output
bash scripts/discovery/discover_containers.sh --verbose --output-dir ./reports
```

**Exit Codes**:
- `0` - Success
- `1` - Docker not found or not running
- `2` - Discovery operation failed

---

### docker_inventory.py

**Purpose**: Comprehensive Docker resource inventory with M1 Mac compatibility analysis.

**Location**: [`scripts/discovery/docker_inventory.py`](../../scripts/discovery/docker_inventory.py)

**Usage**:
```bash
python scripts/discovery/docker_inventory.py [OPTIONS]
```

**Options**:
- `--output-dir DIR` - Output directory for inventory files (default: current directory)
- `--timestamp STAMP` - Custom timestamp for output files
- `-v, --verbose` - Enable verbose output
- `--containers-only` - Discover containers only (skip images, volumes, networks)
- `--images-only` - Discover images only
- `--volumes-only` - Discover volumes only
- `--networks-only` - Discover networks only

**Analysis Features**:
- **Container Analysis**: Status, configuration, resource usage, M1 compatibility
- **Image Analysis**: Architecture detection, size analysis, layer information
- **Volume Analysis**: Usage mapping, size calculation, dependency tracking
- **Network Analysis**: Configuration, connectivity, custom networks
- **M1 Compatibility**: ARM64 vs AMD64 analysis, compatibility scoring, issue identification

**Output Structure**:
```json
{
  "metadata": {
    "timestamp": "20240104_120000",
    "generated_at": "2024-01-04T12:00:00",
    "script_version": "1.0.0",
    "docker_version": {...},
    "system_info": {...}
  },
  "containers": [...],
  "images": [...],
  "volumes": [...],
  "networks": [...],
  "statistics": {...},
  "m1_compatibility": {
    "overall_compatibility_score": 85.5,
    "arm64_images": 12,
    "amd64_images": 8,
    "potential_issues": [...]
  }
}
```

**M1 Compatibility Scoring**:
- **90-100**: Excellent - Ready for migration
- **75-89**: Good - Minor issues to address
- **60-74**: Fair - Several issues need attention
- **Below 60**: Poor - Significant preparation required

**Example**:
```bash
# Complete inventory analysis
python scripts/discovery/docker_inventory.py --verbose

# Analyze only containers with custom output
python scripts/discovery/docker_inventory.py --containers-only --output-dir ./analysis

# Quick image analysis
python scripts/discovery/docker_inventory.py --images-only --timestamp "$(date +%Y%m%d_%H%M%S)"
```

**Exit Codes**:
- `0` - Success
- `1` - Docker connection error
- `2` - Analysis failed
- `3` - File I/O error

---

### dependency_mapper.py

**Purpose**: Analyzes container dependencies and generates migration sequences.

**Location**: [`scripts/discovery/dependency_mapper.py`](../../scripts/discovery/dependency_mapper.py)

**Usage**:
```bash
python scripts/discovery/dependency_mapper.py [OPTIONS]
```

**Options**:
- `--output-dir DIR` - Output directory for dependency files
- `--timestamp STAMP` - Custom timestamp for output files
- `-v, --verbose` - Enable verbose output
- `--compose-files FILES` - Specific Docker Compose files to analyze
- `--containers-only` - Analyze only running containers (skip Compose files)

**Dependency Analysis**:
- **Network Dependencies**: Shared networks between containers
- **Volume Dependencies**: Shared volumes and bind mounts
- **Environment Dependencies**: Environment variable references
- **Link Dependencies**: Legacy container links
- **Compose Dependencies**: Docker Compose service relationships

**Migration Sequencing**:
- **Dependency Graph**: Visual representation of container relationships
- **Startup Order**: Topologically sorted container startup sequence
- **Migration Phases**: Grouped containers for parallel/sequential migration
- **Cycle Detection**: Identifies circular dependencies requiring manual intervention

**Output Structure**:
```json
{
  "metadata": {...},
  "containers": {
    "container-name": {
      "depends_on": ["dependency1", "dependency2"],
      "depended_by": ["dependent1"],
      "network_dependencies": [...],
      "volume_dependencies": [...],
      "migration_priority": "normal"
    }
  },
  "dependency_graph": {
    "nodes": ["container1", "container2", ...],
    "edges": [{"from": "container1", "to": "container2", "type": "depends_on"}],
    "cycles": [],
    "startup_order": ["container1", "container2", ...]
  },
  "migration_sequence": {
    "phases": [
      {
        "name": "Phase 1",
        "containers": ["database", "redis"],
        "parallel": true,
        "description": "Foundation services"
      }
    ],
    "estimated_duration": {
      "estimated_parallel_hours": 2.5,
      "time_savings_percent": 35
    }
  }
}
```

**Example**:
```bash
# Complete dependency analysis
python scripts/discovery/dependency_mapper.py --verbose

# Analyze specific Compose files
python scripts/discovery/dependency_mapper.py --compose-files docker-compose.yml docker-compose.prod.yml

# Container-only analysis (skip Compose)
python scripts/discovery/dependency_mapper.py --containers-only --output-dir ./deps
```

**Exit Codes**:
- `0` - Success
- `1` - Docker connection error
- `2` - Analysis failed
- `3` - File parsing error

---

### system_resources.sh

**Purpose**: M1 Mac system resources detection and Podman readiness assessment.

**Location**: [`scripts/discovery/system_resources.sh`](../../scripts/discovery/system_resources.sh)

**Usage**:
```bash
bash scripts/discovery/system_resources.sh [OPTIONS]
```

**Options**:
- `-v, --verbose` - Enable verbose output
- `-h, --help` - Show help message
- `--output-dir DIR` - Specify custom output directory
- `--timestamp STAMP` - Use custom timestamp
- `--json-only` - Output only JSON (no human-readable output)

**System Analysis**:
- **Architecture Detection**: M1/M2/M3 chip identification
- **CPU Analysis**: Core count, performance vs efficiency cores
- **Memory Analysis**: Total RAM, recommended allocation (75% rule)
- **Storage Analysis**: Disk space, storage type (SSD/HDD)
- **macOS Version**: Compatibility checking
- **Virtualization Conflicts**: Detection of running VM software
- **System Limits**: File descriptors, process limits, Rosetta 2 status

**Resource Recommendations**:
- **CPU Allocation**: Recommended container CPU limits
- **Memory Allocation**: Optimal memory distribution
- **Storage Requirements**: Disk space planning
- **Performance Optimization**: M1-specific tuning suggestions

**Output Structure**:
```json
{
  "metadata": {...},
  "architecture": {
    "architecture": "arm64",
    "is_apple_silicon": true,
    "cpu_model": "Apple M1",
    "podman_native_support": true
  },
  "cpu": {
    "total_cores": 8,
    "performance_cores": 4,
    "efficiency_cores": 4,
    "recommended_cpu_limit": 6
  },
  "memory": {
    "total_memory_gb": 16,
    "recommended_memory_limit_gb": 12,
    "memory_status": "adequate"
  },
  "storage": {
    "available_space_gb": 250,
    "storage_adequate": true,
    "storage_type": "SSD"
  },
  "recommendations": {
    "overall_readiness": "ready",
    "readiness_score": 95,
    "critical_issues": [],
    "warnings": [],
    "recommendations": [...]
  }
}
```

**Readiness Scoring**:
- **Score 90-100**: Ready for immediate migration
- **Score 75-89**: Minor preparation needed
- **Score 60-74**: Significant preparation required
- **Score <60**: Not ready for migration

**Example**:
```bash
# Basic system analysis
bash scripts/discovery/system_resources.sh

# Verbose analysis with custom output
bash scripts/discovery/system_resources.sh --verbose --output-dir ./system-analysis

# JSON-only output for automation
bash scripts/discovery/system_resources.sh --json-only > system-resources.json
```

**Exit Codes**:
- `0` - Success
- `1` - System requirements not met
- `2` - Analysis failed

## System Scripts

### setup.sh

**Purpose**: Automated system setup and dependency installation.

**Location**: [`setup.sh`](../../setup.sh)

**Usage**:
```bash
./setup.sh [OPTIONS]
```

**Options**:
- `-v, --verbose` - Enable verbose output
- `-h, --help` - Show help message
- `--skip-python-setup` - Skip Python environment setup
- `--skip-homebrew-install` - Skip Homebrew installation check
- `--python-version VERSION` - Specify Python version (default: 3.11)

**Setup Operations**:
1. **System Requirements Check**: macOS version, architecture, disk space
2. **Homebrew Installation**: Package manager setup for macOS
3. **System Dependencies**: jq, git, curl, wget, Python
4. **Python Environment**: Virtual environment creation and dependency installation
5. **Activation Script**: Creates convenient environment activation script
6. **Verification**: Tests all components for proper installation

**Dependencies Installed**:
- Homebrew (if not present)
- Python 3.11+ with pip
- jq (JSON processor)
- git (version control)
- curl and wget (download tools)
- Python packages: docker, PyYAML

**Example**:
```bash
# Standard setup
./setup.sh

# Verbose setup with custom Python version
./setup.sh --verbose --python-version 3.12

# Skip Homebrew installation (if already installed)
./setup.sh --skip-homebrew-install
```

**Exit Codes**:
- `0` - Setup completed successfully
- `1` - System requirements not met
- `2` - Homebrew installation failed
- `3` - Python setup failed
- `4` - Dependency installation failed

---

### activate.sh

**Purpose**: Activates the Python virtual environment for the toolkit.

**Location**: [`activate.sh`](../../activate.sh)

**Usage**:
```bash
source ./activate.sh
```

**What it does**:
- Activates the Python virtual environment
- Sets up environment variables
- Displays activation confirmation
- Provides deactivation instructions

**Example**:
```bash
# Activate environment
source ./activate.sh

# Should output:
# Activating Python virtual environment...
# Environment activated. Python: /path/to/venv/bin/python
# To deactivate, run: deactivate
```

## Utility Scripts

### Makefile Targets

**Purpose**: Convenient command interface for common operations.

**Location**: [`Makefile`](../../Makefile)

**Common Targets**:

```bash
# Setup and installation
make setup                # Complete system setup
make install              # Install dependencies only
make clean                # Clean generated files

# Discovery operations
make discovery            # Full Docker discovery
make system-check         # System requirements check
make docker-inventory     # Docker resource inventory
make dependency-mapping   # Container dependency analysis

# Development
make test                 # Run tests
make lint                 # Code linting
make format               # Code formatting

# Status and maintenance
make status               # Show project status
make backup-docker        # Backup Docker configuration
make clean-all            # Complete cleanup
```

**Example**:
```bash
# Quick start
make setup && make discovery

# Development workflow
make install && make test && make lint
```

## Common Parameters

### Timestamps

Most scripts support custom timestamps for consistent file naming:

```bash
# Use current timestamp (default)
script.py

# Custom timestamp
script.py --timestamp "20240104_120000"

# Consistent timestamp across multiple scripts
TIMESTAMP=$(date '+%Y%m%d_%H%M%S')
script1.py --timestamp "$TIMESTAMP"
script2.py --timestamp "$TIMESTAMP"
```

### Output Directories

All scripts support custom output directories:

```bash
# Default output (current directory)
script.py

# Custom output directory
script.py --output-dir ./reports

# Organized output structure
mkdir -p reports/{discovery,analysis,system}
docker_inventory.py --output-dir ./reports/discovery
dependency_mapper.py --output-dir ./reports/analysis
system_resources.sh --output-dir ./reports/system
```

### Verbosity Levels

Control output detail level:

```bash
# Standard output
script.py

# Verbose output (detailed progress)
script.py --verbose

# Quiet output (JSON only for some scripts)
system_resources.sh --json-only
```

## Exit Codes

Standard exit codes used across all scripts:

| Code | Meaning | Description |
|------|---------|-------------|
| `0` | Success | Operation completed successfully |
| `1` | General Error | Command failed or invalid usage |
| `2` | System Error | System requirements not met or environment issue |
| `3` | Docker Error | Docker daemon not running or connection failed |
| `4` | File Error | File I/O error or permission denied |
| `5` | Network Error | Network connectivity or download failed |

### Checking Exit Codes

```bash
# Check if script succeeded
if script.py; then
    echo "Script succeeded"
else
    echo "Script failed with exit code $?"
fi

# Handle specific exit codes
script.py
case $? in
    0) echo "Success" ;;
    1) echo "General error" ;;
    3) echo "Docker connection failed" ;;
    *) echo "Unknown error" ;;
esac
```

## Environment Variables

### Configuration Variables

```bash
# Output directory override
export PODSHIFT_OUTPUT_DIR="/path/to/output"

# Log level control
export PODSHIFT_LOG_LEVEL="DEBUG"  # DEBUG, INFO, WARN, ERROR

# Timestamp format
export PODSHIFT_TIMESTAMP_FORMAT="%Y%m%d_%H%M%S"

# Docker connection
export DOCKER_HOST="tcp://remote-docker:2376"
export DOCKER_TLS_VERIFY=1
export DOCKER_CERT_PATH="/path/to/certs"
```

### System Variables

```bash
# Python environment
export PYTHONPATH="/path/to/podshift:$PYTHONPATH"

# Virtual environment location
export VIRTUAL_ENV="/path/to/venv"

# Homebrew (Apple Silicon)
export PATH="/opt/homebrew/bin:$PATH"
```

## Examples

### Complete Discovery Workflow

```bash
#!/bin/bash
# complete_discovery.sh - Full discovery workflow example

set -euo pipefail

TIMESTAMP=$(date '+%Y%m%d_%H%M%S')
OUTPUT_DIR="./discovery-results-$TIMESTAMP"

echo "Starting complete discovery workflow..."

# 1. Setup environment
source ./activate.sh

# 2. System analysis
echo "=== System Analysis ==="
bash scripts/discovery/system_resources.sh \
    --verbose \
    --output-dir "$OUTPUT_DIR" \
    --timestamp "$TIMESTAMP"

# 3. Docker inventory
echo "=== Docker Inventory ==="
python scripts/discovery/docker_inventory.py \
    --verbose \
    --output-dir "$OUTPUT_DIR" \
    --timestamp "$TIMESTAMP"

# 4. Dependency mapping
echo "=== Dependency Analysis ==="
python scripts/discovery/dependency_mapper.py \
    --verbose \
    --output-dir "$OUTPUT_DIR" \
    --timestamp "$TIMESTAMP"

# 5. Generate summary report
echo "=== Generating Summary ==="
generate_summary_report "$OUTPUT_DIR" "$TIMESTAMP"

echo "Discovery complete. Results in: $OUTPUT_DIR"
```

### Automated Analysis Pipeline

```bash
#!/bin/bash
# analysis_pipeline.sh - Automated analysis with error handling

analyze_environment() {
    local output_dir="$1"
    local timestamp="$2"
    
    # Error handling function
    handle_error() {
        local script="$1"
        local exit_code="$2"
        echo "ERROR: $script failed with exit code $exit_code"
        case $exit_code in
            3) echo "Docker connection failed. Is Docker running?" ;;
            4) echo "File permission error. Check output directory permissions." ;;
            *) echo "Unknown error occurred." ;;
        esac
        return $exit_code
    }
    
    # Run system analysis
    if ! bash scripts/discovery/system_resources.sh \
        --output-dir "$output_dir" \
        --timestamp "$timestamp"; then
        handle_error "system_resources.sh" $?
        return 1
    fi
    
    # Run Docker inventory
    if ! python scripts/discovery/docker_inventory.py \
        --output-dir "$output_dir" \
        --timestamp "$timestamp"; then
        handle_error "docker_inventory.py" $?
        return 1
    fi
    
    # Run dependency analysis
    if ! python scripts/discovery/dependency_mapper.py \
        --output-dir "$output_dir" \
        --timestamp "$timestamp"; then
        handle_error "dependency_mapper.py" $?
        return 1
    fi
    
    echo "Analysis completed successfully"
    return 0
}

# Usage
TIMESTAMP=$(date '+%Y%m%d_%H%M%S')
OUTPUT_DIR="./analysis-$TIMESTAMP"
mkdir -p "$OUTPUT_DIR"

if analyze_environment "$OUTPUT_DIR" "$TIMESTAMP"; then
    echo "Analysis successful. Results in: $OUTPUT_DIR"
else
    echo "Analysis failed. Check error messages above."
    exit 1
fi
```

### Custom Analysis Script

```python
#!/usr/bin/env python3
"""
custom_analysis.py - Example of custom analysis using toolkit APIs
"""

import json
import sys
from pathlib import Path

# Add scripts directory to path
sys.path.append(str(Path(__file__).parent.parent / "scripts" / "discovery"))

from docker_inventory import DockerInventory
from dependency_mapper import DependencyMapper

def custom_analysis():
    """Run custom analysis combining multiple tools."""
    
    print("=== Custom Analysis Starting ===")
    
    # Initialize tools
    inventory = DockerInventory(verbose=True)
    mapper = DependencyMapper(verbose=True)
    
    # Run analysis
    print("Running Docker inventory...")
    inventory_file = inventory.run_full_discovery()
    
    print("Running dependency mapping...")
    dependency_file = mapper.run_full_analysis()
    
    # Load results
    with open(inventory_file) as f:
        inventory_data = json.load(f)
    
    with open(dependency_file) as f:
        dependency_data = json.load(f)
    
    # Custom analysis logic
    compatibility_score = inventory_data['m1_compatibility']['overall_compatibility_score']
    migration_phases = len(dependency_data['migration_sequence']['phases'])
    
    print(f"=== Analysis Results ===")
    print(f"Compatibility Score: {compatibility_score}/100")
    print(f"Migration Phases: {migration_phases}")
    
    if compatibility_score >= 90:
        print("✅ Ready for migration")
    elif compatibility_score >= 75:
        print("⚠️ Minor issues to address")
    else:
        print("❌ Significant preparation needed")
    
    return inventory_file, dependency_file

if __name__ == "__main__":
    try:
        inventory_file, dependency_file = custom_analysis()
        print(f"Analysis complete:")
        print(f"  Inventory: {inventory_file}")
        print(f"  Dependencies: {dependency_file}")
    except Exception as e:
        print(f"Analysis failed: {e}")
        sys.exit(1)
```

---

**Next**: See [Configuration Options](configuration-options.md) for detailed configuration reference, or [Output Formats](output-formats.md) for JSON schema documentation.