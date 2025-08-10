# Quick Start Migration Guide

Get started with Docker to Podman migration on your M1 Mac in under 30 minutes.

> **Navigation**: [← Back to README](../../README.md) | [Discovery Process →](discovery-process.md) | [Migration Planning →](migration-planning.md) | [Best Practices →](best-practices.md)

**Related Documentation:**
- [Installation Guide](../installation/installation-guide.md) - Complete setup instructions
- [Discovery Process](discovery-process.md) - Detailed analysis techniques
- [Migration Planning](migration-planning.md) - Strategic migration execution
- [Best Practices](best-practices.md) - M1 Mac optimization tips
- [Troubleshooting](../troubleshooting/common-issues.md) - Common issues and solutions

## Table of Contents

1. [Prerequisites](#prerequisites)
2. [Quick Setup](#quick-setup)
3. [Discovery Phase](#discovery-phase)
4. [Analysis Phase](#analysis-phase)
5. [Migration Planning](#migration-planning)
6. [Next Steps](#next-steps)

## Prerequisites

Before starting your migration:

- ✅ **macOS 12.0+** with Apple Silicon (M1/M2/M3) recommended
- ✅ **Docker Desktop** installed and running
- ✅ **8GB+ RAM** for optimal performance
- ✅ **20GB+ free disk space** for analysis and reports
- ✅ **Administrative access** for software installation

## Quick Setup

### 1. Install PodShift (5 minutes)

```bash
# Clone the repository
git clone <repository-url>
cd podshift

# Run automated setup
./setup.sh

# Activate environment
source ./activate.sh
```

### 2. Verify Installation

```bash
# Check system status
make status

# Should show:
# ✓ Virtual Environment: Present
# ✓ Docker SDK: Installed
# ✓ PyYAML: Installed
```

## Discovery Phase

### 1. System Analysis (2 minutes)

```bash
# Analyze your M1 Mac capabilities
make system-check
```

**What this does:**
- Detects Apple Silicon architecture
- Checks memory and storage availability
- Identifies potential compatibility issues
- Generates system recommendations

**Expected output:**
```
=== M1 MAC SYSTEM RESOURCES SUMMARY ===
Architecture: Apple M1
CPU Cores: 8
Memory: 16 GB
Available Storage: 250 GB
Podman Readiness Score: 95/100
Status: ready
```

### 2. Docker Environment Discovery (5 minutes)

```bash
# Discover all Docker resources
make discovery
```

**What this analyzes:**
- All containers (running, stopped, paused)
- Docker images and architectures
- Volumes and their usage
- Networks and configurations
- Docker Compose files
- Container dependencies

**Generated files:**
- `docker_inventory_TIMESTAMP.json` - Complete resource inventory
- `container_dependencies_TIMESTAMP.json` - Dependency mapping
- `docker_discovery_summary_TIMESTAMP.txt` - Human-readable summary

## Analysis Phase

### 1. Review Discovery Summary (5 minutes)

```bash
# View the generated summary
cat docker_discovery_summary_*.txt
```

**Key sections to review:**
- **Container count** and status distribution
- **Architecture compatibility** (ARM64 vs AMD64 images)
- **Dependency relationships** between containers
- **Potential migration issues** identified

### 2. Check M1 Compatibility (3 minutes)

Open `docker_inventory_TIMESTAMP.json` and look for:

```json
{
  "m1_compatibility": {
    "overall_compatibility_score": 85,
    "arm64_images": 12,
    "amd64_images": 8,
    "potential_issues": [
      {
        "category": "Architecture Compatibility",
        "issue": "Found 8 AMD64 images that will require emulation",
        "severity": "medium",
        "recommendation": "Consider finding ARM64 alternatives"
      }
    ]
  }
}
```

**Compatibility scoring:**
- **90-100**: Excellent - Ready for migration
- **75-89**: Good - Minor issues to address
- **60-74**: Fair - Several issues need attention
- **Below 60**: Poor - Significant preparation required

### 3. Analyze Dependencies (5 minutes)

Review `container_dependencies_TIMESTAMP.json` for:

```json
{
  "migration_sequence": {
    "phases": [
      {
        "name": "Phase 1",
        "containers": ["database", "redis"],
        "parallel": true,
        "description": "Independent services"
      },
      {
        "name": "Phase 2", 
        "containers": ["api-server"],
        "parallel": false,
        "description": "Services depending on Phase 1"
      }
    ]
  }
}
```

## Migration Planning

### 1. Identify Migration Phases (5 minutes)

Based on dependency analysis, plan your migration:

**Phase 1 - Foundation Services**
- Databases (PostgreSQL, MySQL, Redis)
- Message queues (RabbitMQ, Apache Kafka)
- Independent utility services

**Phase 2 - Application Services**
- API servers and backends
- Services with database dependencies

**Phase 3 - Frontend Services**
- Web servers (Nginx, Apache)
- Frontend applications
- Load balancers

### 2. Address Compatibility Issues (10 minutes)

For each issue found in the analysis:

#### AMD64 Images on Apple Silicon
```bash
# Problem: Image only available for AMD64
# Solution options:
# 1. Find ARM64 alternative: docker pull arm64v8/nginx
# 2. Use multi-arch image: docker pull nginx:latest
# 3. Build custom ARM64 image
```

#### Privileged Containers
```bash
# Problem: Container requires privileged mode
# Solution: Review and minimize required capabilities
# Instead of --privileged, use specific capabilities:
# --cap-add=NET_ADMIN --cap-add=SYS_TIME
```

#### Docker Socket Mounts
```bash
# Problem: Container mounts /var/run/docker.sock
# Solution: Replace with Podman socket
# Docker: -v /var/run/docker.sock:/var/run/docker.sock
# Podman: -v /run/user/$(id -u)/podman/podman.sock:/var/run/docker.sock
```

### 3. Resource Planning

Based on system analysis, plan resource allocation:

```bash
# Example M1 Mac with 16GB RAM recommendations:
# - Reserve 4GB for macOS (25%)
# - Allocate 12GB for containers (75%)
# - CPU: Use 6 of 8 cores for containers (75%)
```

## Next Steps

### Immediate Actions (Next 1-2 days)

1. **Review Generated Reports**
   - Study compatibility issues in detail
   - Plan resolution for each identified problem
   - Estimate migration timeline

2. **Prepare Docker Compose Files**
   - Update image references to ARM64 versions where available
   - Modify privileged containers to use specific capabilities
   - Update socket mounts for Podman compatibility

3. **Plan Migration Schedule**
   - Schedule migration phases based on dependency analysis
   - Plan maintenance windows for each phase
   - Prepare rollback procedures

### Medium-term Planning (Next 1-2 weeks)

1. **Install Podman**
   - Follow [Podman Installation Guide](https://podman.io/getting-started/installation)
   - Configure Podman Machine for your M1 Mac
   - Test basic Podman functionality

2. **Test Migration**
   - Start with Phase 1 containers in test environment
   - Validate functionality after migration
   - Document any additional issues found

3. **Create Migration Scripts**
   - Automate container recreation with Podman
   - Script volume and network migration
   - Prepare monitoring and validation scripts

### Long-term Migration (Next 2-4 weeks)

1. **Execute Migration Phases**
   - Follow planned sequence from dependency analysis
   - Monitor each phase for issues
   - Update documentation with lessons learned

2. **Optimize Performance**
   - Tune resource allocation for Apple Silicon
   - Optimize images for ARM64 architecture
   - Configure Podman-specific optimizations

3. **Cleanup and Documentation**
   - Remove old Docker resources
   - Document new Podman configuration
   - Create operational runbooks

## Common Quick Wins

### Easy Migrations (Start Here)
- **Stateless applications** without complex dependencies
- **Standard images** with ARM64 support (nginx, postgres, redis)
- **Single-container applications** without networking complexity

### ARM64-Ready Images
Many popular images already support ARM64:
```bash
# Web servers
nginx:latest, httpd:latest, caddy:latest

# Databases  
postgres:latest, mysql:latest, redis:latest, mongodb:latest

# Languages/Runtimes
node:latest, python:latest, openjdk:latest, golang:latest

# Tools
alpine:latest, ubuntu:latest, debian:latest
```

### Migration Commands Quick Reference
```bash
# Discovery and analysis
make discovery              # Full environment analysis
make system-check          # M1 Mac capability check
make docker-inventory      # Detailed Docker inventory
make dependency-mapping    # Container dependency analysis

# View results
cat docker_discovery_summary_*.txt    # Human-readable summary
jq '.m1_compatibility' docker_inventory_*.json    # Compatibility issues
jq '.migration_sequence' container_dependencies_*.json    # Migration plan
```

## Troubleshooting Quick Start

### Discovery Fails
```bash
# Check Docker is running
docker info

# Restart Docker Desktop if needed
killall Docker\ Desktop && open -a Docker

# Wait and retry
make discovery
```

### Low Compatibility Score
- Focus on architecture issues first (AMD64 → ARM64)
- Address privileged containers second
- Network and volume issues are usually easier to fix

### Complex Dependencies
- Start with leaf nodes (containers with no dependents)
- Migrate databases and storage first
- Applications and frontends last

---

**🎉 You're Ready!** 

With your discovery complete and issues identified, you're ready to begin the detailed migration process. Continue with the [Discovery Process Guide](discovery-process.md) for in-depth analysis techniques, or jump to [Migration Planning](migration-planning.md) for detailed execution strategies.

**Estimated Total Time**: 30 minutes for discovery + 2-4 weeks for complete migration depending on environment complexity.