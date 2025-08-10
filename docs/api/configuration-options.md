# Configuration Options

Complete reference for all configuration options and settings in PodShift.

> **Navigation**: [Script Reference](script-reference.md) | [Output Formats →](output-formats.md)

**Related Documentation:**
- [Script Reference](script-reference.md) - Command-line script documentation
- [Output Formats](output-formats.md) - JSON schemas and data formats
- [Best Practices](../migration-guide/best-practices.md) - Performance optimization settings
- [Installation Guide](../installation/installation-guide.md) - Initial configuration setup
- [Common Issues](../troubleshooting/common-issues.md) - Configuration troubleshooting

## Table of Contents

1. [Configuration File Locations](#configuration-file-locations)
2. [Environment Variables](#environment-variables)
3. [Script Configuration](#script-configuration)
4. [Output Configuration](#output-configuration)
5. [Docker Connection Configuration](#docker-connection-configuration)
6. [Logging Configuration](#logging-configuration)
7. [Apple Silicon Mac Specific Settings](#apple-silicon-mac-specific-settings)
8. [Advanced Configuration](#advanced-configuration)

## Configuration File Locations

### Default Configuration Paths

```bash
# Project configuration files
├── pyproject.toml              # Project metadata and Python settings
├── requirements.txt            # Python dependencies
├── Makefile                   # Build and automation settings
├── .gitignore                 # Git ignore patterns
├── .pre-commit-config.yaml    # Pre-commit hooks configuration
└── configs/                   # Configuration templates and examples
    ├── templates/             # Default configuration templates
    ├── m1-optimized/         # M1 Mac optimized configurations
    └── validation/           # Configuration validation schemas
```

### User Configuration Paths

```bash
# User-specific configuration locations
~/.config/podshift/
├── config.yaml               # Main configuration file (optional)
├── docker-settings.yaml      # Docker connection settings
└── preferences.yaml          # User preferences
```

## Environment Variables

### Core Configuration Variables

#### Output and Logging
```bash
# Output directory for all generated files
export PODSHIFT_OUTPUT_DIR="/path/to/output"
# Default: current directory

# Log level control
export PODSHIFT_LOG_LEVEL="INFO"
# Options: DEBUG, INFO, WARN, ERROR
# Default: INFO

# Log file location
export PODSHIFT_LOG_DIR="/path/to/logs"
# Default: ./logs

# Timestamp format for files
export PODSHIFT_TIMESTAMP_FORMAT="%Y%m%d_%H%M%S"
# Default: %Y%m%d_%H%M%S

# Enable verbose output by default
export PODSHIFT_VERBOSE="true"
# Options: true, false
# Default: false
```

#### Python Environment
```bash
# Python executable path
export PODSHIFT_PYTHON="/path/to/python"
# Default: system python3

# Virtual environment path
export PODSHIFT_VENV_PATH="/path/to/venv"
# Default: ./venv

# Python path additions
export PYTHONPATH="/path/to/custom/modules:$PYTHONPATH"
```

#### Docker Configuration
```bash
# Docker daemon connection
export DOCKER_HOST="tcp://docker-host:2376"
# Default: unix:///var/run/docker.sock

# Docker TLS settings
export DOCKER_TLS_VERIFY="1"
export DOCKER_CERT_PATH="/path/to/certs"

# Docker API version
export DOCKER_API_VERSION="1.41"
# Default: auto-negotiated
```

### Discovery Configuration

#### System Analysis Settings
```bash
# Minimum system requirements override
export PODSHIFT_MIN_MACOS_VERSION="12.0"
export PODSHIFT_MIN_MEMORY_GB="4"
export PODSHIFT_MIN_DISK_GB="10"

# Resource allocation percentages
export PODSHIFT_CPU_ALLOCATION_PERCENT="75"
export PODSHIFT_MEMORY_ALLOCATION_PERCENT="75"

# System analysis timeout
export PODSHIFT_SYSTEM_ANALYSIS_TIMEOUT="300"  # seconds
```

#### Docker Analysis Settings
```bash
# Analysis scope control
export PODSHIFT_ANALYZE_STOPPED_CONTAINERS="true"
export PODSHIFT_ANALYZE_DANGLING_IMAGES="true"
export PODSHIFT_ANALYZE_UNUSED_VOLUMES="true"
export PODSHIFT_ANALYZE_CUSTOM_NETWORKS="true"

# Analysis depth control
export PODSHIFT_DEEP_IMAGE_ANALYSIS="false"      # Slower but more detailed
export PODSHIFT_INCLUDE_CONTAINER_STATS="true"   # Real-time stats collection
export PODSHIFT_ANALYZE_LAYER_HISTORY="false"    # Image layer analysis

# Timeout settings
export PODSHIFT_CONTAINER_STATS_TIMEOUT="30"     # seconds per container
export PODSHIFT_IMAGE_ANALYSIS_TIMEOUT="60"      # seconds per image
```

#### Dependency Analysis Settings
```bash
# Dependency detection scope
export PODSHIFT_ANALYZE_NETWORK_DEPS="true"
export PODSHIFT_ANALYZE_VOLUME_DEPS="true"
export PODSHIFT_ANALYZE_ENV_DEPS="true"
export PODSHIFT_ANALYZE_LINK_DEPS="true"
export PODSHIFT_ANALYZE_COMPOSE_DEPS="true"

# Compose file search paths
export PODSHIFT_COMPOSE_SEARCH_PATHS="/home:/opt:/var"
export PODSHIFT_COMPOSE_MAX_DEPTH="3"            # Directory search depth

# Dependency analysis timeouts
export PODSHIFT_DEPENDENCY_ANALYSIS_TIMEOUT="600"  # seconds
```

## Script Configuration

### setup.sh Configuration

```bash
# Default Python version to install
export PODSHIFT_PYTHON_VERSION="3.11"

# Homebrew installation control
export PODSHIFT_SKIP_HOMEBREW="false"
export PODSHIFT_HOMEBREW_PATH="/opt/homebrew"    # Apple Silicon
# export PODSHIFT_HOMEBREW_PATH="/usr/local"     # Intel Mac

# Package installation preferences
export PODSHIFT_INSTALL_DEV_DEPS="false"        # Install development dependencies
export PODSHIFT_UPDATE_PACKAGES="true"          # Update existing packages

# Setup script behavior
export PODSHIFT_SETUP_VERBOSE="false"
export PODSHIFT_SETUP_BACKUP_EXISTING="true"    # Backup existing configurations
```

### Discovery Script Configuration

#### system_resources.sh
```bash
# System analysis configuration file
cat > ~/.config/podshift/system-config.env << EOF
# Resource allocation rules
PODSHIFT_CPU_RESERVATION_PERCENT=25     # Reserve for macOS
PODSHIFT_MEMORY_RESERVATION_PERCENT=25  # Reserve for macOS
PODSHIFT_DISK_MINIMUM_FREE_GB=20       # Minimum free space required

# Analysis scope
PODSHIFT_CHECK_VIRTUALIZATION_CONFLICTS=true
PODSHIFT_CHECK_ROSETTA_STATUS=true
PODSHIFT_CHECK_SYSTEM_LIMITS=true

# Performance testing
PODSHIFT_RUN_PERFORMANCE_TESTS=false   # CPU/memory benchmarks
PODSHIFT_PERFORMANCE_TEST_DURATION=60  # seconds
EOF
```

#### docker_inventory.py
```bash
# Docker inventory configuration
cat > ~/.config/podshift/inventory-config.yaml << EOF
inventory:
  # Analysis scope
  include_stopped_containers: true
  include_dangling_images: true
  include_unused_volumes: true
  include_system_networks: false
  
  # Performance settings
  parallel_analysis: true
  max_workers: 4
  analysis_timeout: 300
  
  # M1 compatibility settings
  check_architecture: true
  prefer_arm64: true
  flag_emulation_required: true
  
  # Output settings
  human_readable_sizes: true
  include_timestamps: true
  compress_large_outputs: false
EOF
```

#### dependency_mapper.py
```bash
# Dependency mapping configuration
cat > ~/.config/podshift/dependency-config.yaml << EOF
dependency_mapping:
  # Analysis depth
  analyze_environment_variables: true
  analyze_network_connections: true
  analyze_volume_mounts: true
  analyze_compose_files: true
  
  # Search configuration
  compose_search_patterns:
    - "docker-compose*.yml"
    - "docker-compose*.yaml"
    - "compose*.yml"
    - "compose*.yaml"
  
  compose_search_locations:
    - "."
    - "$HOME"
    - "$HOME/Documents"
    - "$HOME/Projects"
    - "$HOME/Development"
  
  # Dependency resolution
  max_dependency_depth: 10
  detect_circular_dependencies: true
  resolve_environment_references: true
  
  # Migration planning
  parallel_migration_threshold: 3    # Min containers for parallel phases
  estimated_time_per_container: 5    # minutes
  parallel_efficiency_factor: 0.7
EOF
```

## Output Configuration

### File Naming Conventions

```bash
# Configure output file naming patterns
export PODSHIFT_FILE_NAME_PATTERN="{script}_{timestamp}.{ext}"

# Available placeholders:
# {script}    - Script name without extension
# {timestamp} - Formatted timestamp
# {hostname}  - System hostname
# {user}      - Current username
# {ext}       - File extension

# Examples:
export PODSHIFT_FILE_NAME_PATTERN="discovery_{timestamp}_{hostname}.json"
export PODSHIFT_FILE_NAME_PATTERN="{user}_{script}_{timestamp}.{ext}"
```

### Output Format Configuration

```yaml
# ~/.config/podman-migration-toolkit/output-config.yaml
output:
  # JSON formatting
  json:
    indent: 2
    sort_keys: true
    ensure_ascii: false
    compact: false                    # true for single-line output
  
  # Text formatting
  text:
    width: 120                       # Line width for tables
    show_headers: true
    align_columns: true
    date_format: "%Y-%m-%d %H:%M:%S"
  
  # File management
  files:
    backup_existing: true            # Backup files before overwrite
    compress_large_files: true       # Compress files > 10MB
    retention_days: 30               # Auto-cleanup old files
    create_manifest: true            # Create file manifest
```

### Report Configuration

```yaml
# ~/.config/podman-migration-toolkit/report-config.yaml
reports:
  # Summary report settings
  summary:
    include_graphs: false            # ASCII graphs in text output
    include_recommendations: true
    max_issues_displayed: 10
    group_similar_issues: true
  
  # Detailed report settings
  detailed:
    include_raw_data: false          # Include raw API responses
    include_system_info: true
    include_performance_data: true
    max_container_details: 100
  
  # Security report settings
  security:
    highlight_privileged: true
    flag_root_containers: true
    analyze_capabilities: true
    check_secrets_exposure: true
```

## Docker Connection Configuration

### Connection Settings

```bash
# Docker daemon connection methods
export DOCKER_HOST="unix:///var/run/docker.sock"     # Local socket (default)
export DOCKER_HOST="tcp://192.168.1.100:2376"        # Remote daemon
export DOCKER_HOST="ssh://user@docker-host"          # SSH tunnel

# Connection timeout settings
export DOCKER_TIMEOUT="60"                           # API timeout (seconds)
export DOCKER_CONNECTION_RETRIES="3"                 # Retry attempts
export DOCKER_RETRY_DELAY="5"                       # Delay between retries (seconds)
```

### TLS Configuration

```bash
# Docker TLS settings for secure connections
export DOCKER_TLS_VERIFY="1"                        # Enable TLS verification
export DOCKER_CERT_PATH="/path/to/docker/certs"     # Certificate directory

# Certificate files expected in DOCKER_CERT_PATH:
# ca.pem       - Certificate Authority
# cert.pem     - Client certificate  
# key.pem      - Client private key
```

### Multi-Host Configuration

```yaml
# ~/.config/podman-migration-toolkit/docker-hosts.yaml
docker_hosts:
  default:
    host: "unix:///var/run/docker.sock"
    tls_verify: false
    timeout: 60
    
  production:
    host: "tcp://prod-docker:2376"
    tls_verify: true
    cert_path: "/etc/docker/certs"
    timeout: 120
    
  staging:
    host: "ssh://deploy@staging-docker"
    ssh_key: "/home/user/.ssh/docker_key"
    timeout: 90
    
  development:
    host: "tcp://dev-docker:2375"
    tls_verify: false
    timeout: 30
```

## Logging Configuration

### Log Levels and Output

```bash
# Log level configuration
export PODSHIFT_LOG_LEVEL="INFO"
# Available levels: DEBUG, INFO, WARN, ERROR, CRITICAL

# Log output destinations
export PODSHIFT_LOG_TO_FILE="true"                       # Enable file logging
export PODSHIFT_LOG_TO_CONSOLE="true"                    # Enable console output
export PODSHIFT_LOG_TO_SYSLOG="false"                    # Enable syslog output

# Log file settings
export PODSHIFT_LOG_FILE_SIZE_MB="50"                    # Max file size before rotation
export PODSHIFT_LOG_FILE_COUNT="5"                       # Number of rotated files to keep
export PODSHIFT_LOG_FILE_FORMAT="detailed"               # Format: simple, detailed, json
```

### Log Format Configuration

```yaml
# ~/.config/podman-migration-toolkit/logging-config.yaml
logging:
  version: 1
  
  formatters:
    simple:
      format: "[%(levelname)s] %(message)s"
      
    detailed:
      format: "[%(asctime)s] [%(levelname)s] [%(name)s:%(lineno)d] %(message)s"
      datefmt: "%Y-%m-%d %H:%M:%S"
      
    json:
      format: '{"timestamp": "%(asctime)s", "level": "%(levelname)s", "logger": "%(name)s", "message": "%(message)s"}'
      
  handlers:
    console:
      class: logging.StreamHandler
      formatter: simple
      level: INFO
      
    file:
      class: logging.handlers.RotatingFileHandler
      formatter: detailed
      level: DEBUG
      filename: logs/podman-migration.log
      maxBytes: 52428800  # 50MB
      backupCount: 5
      
  loggers:
    docker_inventory:
      level: DEBUG
      handlers: [console, file]
      
    dependency_mapper:
      level: DEBUG
      handlers: [console, file]
      
    system_resources:
      level: INFO
      handlers: [console, file]
```

## Apple Silicon Mac Specific Settings

### Apple Silicon Optimization

```bash
# Apple Silicon Mac specific configuration
export PODSHIFT_APPLE_SILICON_OPTIMIZED="true"

# CPU configuration for Apple Silicon
export PODSHIFT_USE_PERFORMANCE_CORES="true"            # Prefer P-cores for analysis
export PODSHIFT_MAX_BACKGROUND_WORKERS="2"              # Limit background tasks

# Memory optimization
export PODSHIFT_UNIFIED_MEMORY_AWARE="true"            # Optimize for unified memory
export PODSHIFT_MEMORY_PRESSURE_MONITORING="true"      # Monitor memory pressure

# Architecture preferences
export PODSHIFT_PREFER_ARM64_IMAGES="true"             # Prefer ARM64 images
export PODSHIFT_FLAG_EMULATION_OVERHEAD="true"         # Warn about emulation
export PODSHIFT_ROSETTA_PERFORMANCE_WARNING="true"     # Performance warnings
```

### Performance Tuning

```yaml
# ~/.config/podshift/apple-silicon-config.yaml
apple_silicon_optimization:
  # CPU settings
  cpu:
    prefer_performance_cores: true
    max_analysis_threads: 6           # Leave 2 cores for macOS
    cpu_intensive_timeout: 300        # Longer timeout for CPU tasks
    
  # Memory settings  
  memory:
    unified_memory_optimization: true
    memory_pressure_threshold: 80     # Percentage
    reduce_memory_usage_on_pressure: true
    
  # Storage settings
  storage:
    use_apfs_optimization: true
    enable_apfs_snapshots: true       # For backups
    optimize_for_ssd: true
    
  # Compatibility settings
  compatibility:
    prioritize_arm64_images: true
    emulation_performance_factor: 0.7  # AMD64 performance factor
    multi_arch_preference: "arm64"
```

## Advanced Configuration

### Performance Monitoring

```yaml
# ~/.config/podman-migration-toolkit/monitoring-config.yaml
monitoring:
  # System monitoring
  system:
    monitor_cpu_temperature: true
    monitor_memory_pressure: true
    monitor_disk_io: true
    sample_interval_seconds: 30
    
  # Container monitoring
  containers:
    collect_runtime_stats: true
    stats_collection_interval: 10     # seconds
    max_stats_history: 100           # data points
    
  # Analysis monitoring
  analysis:
    track_analysis_performance: true
    benchmark_operations: false       # Detailed benchmarking
    profile_memory_usage: false      # Memory profiling
```

### Plugin Configuration

```yaml
# ~/.config/podman-migration-toolkit/plugins-config.yaml
plugins:
  # Discovery plugins
  discovery:
    enabled_plugins:
      - "custom_compatibility_checker"
      - "security_analyzer"
      - "performance_predictor"
    
    plugin_timeout_seconds: 120
    
  # Analysis plugins
  analysis:
    enabled_plugins:
      - "migration_cost_estimator"
      - "risk_assessor"
    
  # Output plugins
  output:
    enabled_plugins:
      - "html_report_generator"
      - "slack_notifier"
      - "jira_integration"
```

### Caching Configuration

```yaml
# ~/.config/podman-migration-toolkit/cache-config.yaml
caching:
  # Docker API response caching
  docker_api:
    enabled: true
    ttl_seconds: 300                 # 5 minutes
    max_cache_size_mb: 100
    
  # System information caching
  system_info:
    enabled: true
    ttl_seconds: 3600               # 1 hour
    
  # Image analysis caching
  image_analysis:
    enabled: true
    ttl_seconds: 86400              # 24 hours
    cache_location: "~/.cache/pmt"
```

### Notification Configuration

```yaml
# ~/.config/podman-migration-toolkit/notifications-config.yaml
notifications:
  # Slack notifications
  slack:
    enabled: false
    webhook_url: "https://hooks.slack.com/..."
    channel: "#migration-alerts"
    notify_on: ["error", "completion"]
    
  # Email notifications
  email:
    enabled: false
    smtp_server: "smtp.company.com"
    smtp_port: 587
    username: "notifications@company.com"
    recipients: ["team@company.com"]
    
  # Webhook notifications
  webhook:
    enabled: false
    url: "https://api.company.com/webhooks/migration"
    headers:
      Authorization: "Bearer token"
    notify_on: ["start", "phase_complete", "error", "completion"]
```

---

**Configuration Validation**: Use the validation tools in `configs/validation/` to check your configuration files for syntax and semantic errors before running analysis.

**Next**: See [Output Formats](output-formats.md) for detailed JSON schema documentation and output format specifications.