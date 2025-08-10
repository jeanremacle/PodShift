#!/bin/bash

# discover_containers.sh - Main Docker discovery orchestration script
# Part of PodShift - Seamless Docker to Podman Migration for Apple Silicon
#
# This script orchestrates all discovery operations to analyze existing Docker
# installations and prepare comprehensive reports for migration to Podman.

set -euo pipefail

# Script configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" &> /dev/null && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
LOGS_DIR="$PROJECT_ROOT/logs"
BACKUPS_DIR="$PROJECT_ROOT/backups"
TIMESTAMP=$(date '+%Y%m%d_%H%M%S')
LOG_FILE="$LOGS_DIR/discovery_$TIMESTAMP.log"
VERBOSE=false
OUTPUT_DIR="$PROJECT_ROOT"  # Default output directory
SKIP_BACKUP=false           # Default backup setting

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Initialize logging
log() {
    local level="$1"
    shift
    local message="$*"
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    echo -e "[$timestamp] [$level] $message" | tee -a "$LOG_FILE"
}

log_info() {
    log "INFO" "$@"
    if [[ "$VERBOSE" == "true" ]]; then
        echo -e "${BLUE}[INFO]${NC} $*"
    fi
}

log_warn() {
    log "WARN" "$@"
    echo -e "${YELLOW}[WARN]${NC} $*"
}

log_error() {
    log "ERROR" "$@"
    echo -e "${RED}[ERROR]${NC} $*"
}

log_success() {
    log "SUCCESS" "$@"
    echo -e "${GREEN}[SUCCESS]${NC} $*"
}

# Help function
show_help() {
    cat << EOF
Docker Container Discovery Script for PodShift Migration

USAGE:
    $0 [OPTIONS]

OPTIONS:
    -v, --verbose       Enable verbose output
    -h, --help         Show this help message
    --skip-backup      Skip Docker configuration backup
    --output-dir DIR   Specify custom output directory

DESCRIPTION:
    This script performs comprehensive discovery of Docker resources on Apple Silicon Macs
    to prepare for migration to Podman. It orchestrates multiple discovery
    operations and generates detailed reports.

OPERATIONS PERFORMED:
    - Docker installation and status check
    - Container discovery (running, stopped, paused)
    - Image inventory with dependencies
    - Volume analysis and usage mapping
    - Network configuration discovery
    - Docker Compose file detection
    - System resource assessment
    - Dependency mapping between containers
    - Configuration backup creation

OUTPUT:
    All results are saved to JSON files in the project directory and
    detailed logs are created in $LOGS_DIR/
EOF
}

# Parse command line arguments
parse_args() {
    while [[ $# -gt 0 ]]; do
        case $1 in
            -v|--verbose)
                VERBOSE=true
                shift
                ;;
            -h|--help)
                show_help
                exit 0
                ;;
            --skip-backup)
                SKIP_BACKUP=true
                shift
                ;;
            --output-dir)
                OUTPUT_DIR="$2"
                shift 2
                ;;
            *)
                log_error "Unknown option: $1"
                show_help
                exit 1
                ;;
        esac
    done
}

# Check if Docker is installed and running
check_docker() {
    log_info "Checking Docker installation and status..."
    
    if ! command -v docker &> /dev/null; then
        log_error "Docker is not installed or not in PATH"
        return 1
    fi
    
    if ! docker info &> /dev/null; then
        log_error "Docker daemon is not running or not accessible"
        log_info "Please start Docker Desktop or ensure Docker daemon is running"
        return 1
    fi
    
    local docker_version=$(docker --version)
    log_success "Docker is installed and running: $docker_version"
    
    # Check for M1 Mac specific Docker configuration
    local architecture=$(uname -m)
    if [[ "$architecture" == "arm64" ]]; then
        log_info "Detected ARM64 architecture (Apple Silicon Mac)"
        # Check if Docker is running with Rosetta 2 emulation
        local docker_info=$(docker info --format json 2>/dev/null || echo '{}')
        if echo "$docker_info" | grep -q "arm64"; then
            log_info "Docker is running natively on ARM64"
        else
            log_warn "Docker may be running under Rosetta 2 emulation"
        fi
    fi
    
    return 0
}

# Discover all containers
discover_containers() {
    log_info "Discovering Docker containers..."
    
    local output_file="$OUTPUT_DIR/docker_containers_$TIMESTAMP.json"
    
    # Get all containers (running, stopped, paused)
    if docker ps -a --format json > "$output_file" 2>/dev/null; then
        local container_count=$(cat "$output_file" | wc -l | tr -d ' ')
        log_success "Discovered $container_count containers, saved to $output_file"
    else
        log_error "Failed to discover containers"
        return 1
    fi
    
    # Get detailed container information
    log_info "Gathering detailed container information..."
    local containers_detail_file="$OUTPUT_DIR/docker_containers_detailed_$TIMESTAMP.json"
    docker ps -a --no-trunc --format "table {{.ID}}\t{{.Image}}\t{{.Command}}\t{{.CreatedAt}}\t{{.Status}}\t{{.Ports}}\t{{.Names}}" > "${containers_detail_file%.json}.txt" 2>/dev/null || true
}

# Discover all images
discover_images() {
    log_info "Discovering Docker images..."
    
    local output_file="$OUTPUT_DIR/docker_images_$TIMESTAMP.json"
    
    # Get all images including dangling ones
    if docker images --format json > "$output_file" 2>/dev/null; then
        local image_count=$(cat "$output_file" | wc -l | tr -d ' ')
        log_success "Discovered $image_count images, saved to $output_file"
    else
        log_error "Failed to discover images"
        return 1
    fi
    
    # Get dangling images separately
    local dangling_file="$OUTPUT_DIR/docker_dangling_images_$TIMESTAMP.json"
    docker images --filter "dangling=true" --format json > "$dangling_file" 2>/dev/null || echo "[]" > "$dangling_file"
    
    local dangling_count=$(cat "$dangling_file" | wc -l | tr -d ' ')
    if [[ "$dangling_count" -gt 0 ]]; then
        log_warn "Found $dangling_count dangling images"
    else
        log_info "No dangling images found"
    fi
}

# Discover volumes
discover_volumes() {
    log_info "Discovering Docker volumes..."
    
    local output_file="$OUTPUT_DIR/docker_volumes_$TIMESTAMP.json"
    
    if docker volume ls --format json > "$output_file" 2>/dev/null; then
        local volume_count=$(cat "$output_file" | wc -l | tr -d ' ')
        log_success "Discovered $volume_count volumes, saved to $output_file"
        
        # Get detailed volume information
        log_info "Gathering detailed volume information..."
        local volumes_detail_file="$OUTPUT_DIR/docker_volumes_detailed_$TIMESTAMP.json"
        docker volume ls --format "table {{.Driver}}\t{{.Name}}\t{{.Scope}}\t{{.Mountpoint}}" > "${volumes_detail_file%.json}.txt" 2>/dev/null || true
    else
        log_error "Failed to discover volumes"
        return 1
    fi
}

# Discover networks
discover_networks() {
    log_info "Discovering Docker networks..."
    
    local output_file="$OUTPUT_DIR/docker_networks_$TIMESTAMP.json"
    
    if docker network ls --format json > "$output_file" 2>/dev/null; then
        local network_count=$(cat "$output_file" | wc -l | tr -d ' ')
        log_success "Discovered $network_count networks, saved to $output_file"
        
        # Get detailed network information
        log_info "Gathering detailed network configurations..."
        local networks_detail_file="$OUTPUT_DIR/docker_networks_detailed_$TIMESTAMP.json"
        echo "[]" > "$networks_detail_file"
        
        # Inspect each network for detailed configuration
        while IFS= read -r network_line; do
            local network_id=$(echo "$network_line" | grep -o '"ID":"[^"]*"' | cut -d'"' -f4)
            if [[ -n "$network_id" ]]; then
                docker network inspect "$network_id" >> "${networks_detail_file%.json}_inspect.json" 2>/dev/null || true
            fi
        done < "$output_file"
    else
        log_error "Failed to discover networks"
        return 1
    fi
}

# Find Docker Compose files
find_compose_files() {
    log_info "Searching for Docker Compose files..."
    
    local output_file="$OUTPUT_DIR/docker_compose_files_$TIMESTAMP.json"
    local compose_files=()
    
    # Common Docker Compose file patterns
    local patterns=(
        "docker-compose.yml"
        "docker-compose.yaml"
        "compose.yml"
        "compose.yaml"
        "docker-compose.*.yml"
        "docker-compose.*.yaml"
    )
    
    # Search in common locations
    local search_paths=(
        "$HOME"
        "$HOME/Documents"
        "$HOME/Projects"
        "$HOME/Development"
        "$HOME/Docker"
        "/Users/Shared"
    )
    
    for search_path in "${search_paths[@]}"; do
        if [[ -d "$search_path" ]]; then
            log_info "Searching in $search_path..."
            for pattern in "${patterns[@]}"; do
                while IFS= read -r -d '' file; do
                    compose_files+=("$file")
                    log_info "Found Docker Compose file: $file"
                done < <(find "$search_path" -name "$pattern" -type f -print0 2>/dev/null || true)
            done
        fi
    done
    
    # Create JSON output
    if [[ ${#compose_files[@]} -gt 0 ]]; then
        printf '%s\n' "${compose_files[@]}" | jq -R . | jq -s . > "$output_file"
        log_success "Found ${#compose_files[@]} Docker Compose files, saved to $output_file"
    else
        echo "[]" > "$output_file"
        log_info "No Docker Compose files found"
    fi
}

# Backup Docker configuration
backup_docker_config() {
    if [[ "$SKIP_BACKUP" == "true" ]]; then
        log_info "Skipping Docker configuration backup (--skip-backup specified)"
        return 0
    fi
    
    log_info "Creating backup of Docker configuration..."
    
    local backup_dir="$BACKUPS_DIR/docker_config_$TIMESTAMP"
    mkdir -p "$backup_dir"
    
    # Backup Docker daemon configuration
    local docker_config_locations=(
        "$HOME/.docker"
        "/etc/docker"
        "$HOME/Library/Group Containers/group.com.docker"
    )
    
    for config_location in "${docker_config_locations[@]}"; do
        if [[ -d "$config_location" ]]; then
            log_info "Backing up configuration from $config_location"
            cp -r "$config_location" "$backup_dir/" 2>/dev/null || {
                log_warn "Could not backup $config_location (permission denied or not accessible)"
            }
        fi
    done
    
    # Export Docker context
    docker context export default "$backup_dir/default_context.tar" 2>/dev/null || {
        log_warn "Could not export Docker context"
    }
    
    log_success "Docker configuration backup created in $backup_dir"
}

# Run Python discovery scripts
run_python_discovery() {
    log_info "Running detailed Python discovery scripts..."
    
    # Check if Python 3 is available
    if ! command -v python3 &> /dev/null; then
        log_error "Python 3 is not installed or not in PATH"
        return 1
    fi
    
    # Run docker inventory script
    if [[ -f "$SCRIPT_DIR/docker_inventory.py" ]]; then
        log_info "Running Docker inventory analysis..."
        if python3 "$SCRIPT_DIR/docker_inventory.py" --output-dir "$OUTPUT_DIR" --timestamp "$TIMESTAMP" ${VERBOSE:+--verbose}; then
            log_success "Docker inventory analysis completed"
        else
            log_error "Docker inventory analysis failed"
        fi
    else
        log_warn "docker_inventory.py not found, skipping detailed inventory"
    fi
    
    # Run dependency mapper
    if [[ -f "$SCRIPT_DIR/dependency_mapper.py" ]]; then
        log_info "Running dependency mapping analysis..."
        if python3 "$SCRIPT_DIR/dependency_mapper.py" --output-dir "$OUTPUT_DIR" --timestamp "$TIMESTAMP" ${VERBOSE:+--verbose}; then
            log_success "Dependency mapping analysis completed"
        else
            log_error "Dependency mapping analysis failed"
        fi
    else
        log_warn "dependency_mapper.py not found, skipping dependency mapping"
    fi
}

# Run system resources detection
run_system_discovery() {
    log_info "Running system resources detection..."
    
    if [[ -f "$SCRIPT_DIR/system_resources.sh" ]]; then
        if bash "$SCRIPT_DIR/system_resources.sh" --output-dir "$OUTPUT_DIR" --timestamp "$TIMESTAMP" ${VERBOSE:+--verbose}; then
            log_success "System resources detection completed"
        else
            log_error "System resources detection failed"
        fi
    else
        log_warn "system_resources.sh not found, skipping system analysis"
    fi
}

# Generate final report
generate_report() {
    log_info "Generating comprehensive discovery report..."
    
    local report_file="$OUTPUT_DIR/docker_discovery_report_$TIMESTAMP.json"
    local summary_file="$OUTPUT_DIR/docker_discovery_summary_$TIMESTAMP.txt"
    
    # Create comprehensive JSON report
    cat > "$report_file" << EOF
{
    "discovery_metadata": {
        "timestamp": "$TIMESTAMP",
        "script_version": "1.0.0",
        "discovery_date": "$(date -Iseconds)",
        "system_architecture": "$(uname -m)",
        "operating_system": "$(uname -s)",
        "hostname": "$(hostname)"
    },
    "docker_status": {
        "installed": $(docker --version &>/dev/null && echo "true" || echo "false"),
        "running": $(docker info &>/dev/null && echo "true" || echo "false"),
        "version": "$(docker --version 2>/dev/null || echo 'Not installed')"
    },
    "discovery_files": {
        "containers": "docker_containers_$TIMESTAMP.json",
        "images": "docker_images_$TIMESTAMP.json",
        "volumes": "docker_volumes_$TIMESTAMP.json",
        "networks": "docker_networks_$TIMESTAMP.json",
        "compose_files": "docker_compose_files_$TIMESTAMP.json",
        "system_resources": "system_resources_$TIMESTAMP.json",
        "dependencies": "container_dependencies_$TIMESTAMP.json",
        "inventory": "docker_inventory_$TIMESTAMP.json"
    },
    "log_file": "$LOG_FILE"
}
EOF
    
    # Create human-readable summary
    cat > "$summary_file" << EOF
Docker Discovery Summary Report
Generated on: $(date)
Timestamp: $TIMESTAMP

=== SYSTEM INFORMATION ===
Architecture: $(uname -m)
Operating System: $(uname -s) $(sw_vers -productVersion 2>/dev/null || echo "Unknown")
Hostname: $(hostname)

=== DOCKER STATUS ===
EOF
    
    if docker --version &>/dev/null; then
        echo "Docker Version: $(docker --version)" >> "$summary_file"
        if docker info &>/dev/null; then
            echo "Docker Status: Running" >> "$summary_file"
            echo "Docker Info:" >> "$summary_file"
            docker info --format "  Root Dir: {{.DockerRootDir}}" 2>/dev/null >> "$summary_file" || true
            docker info --format "  Storage Driver: {{.Driver}}" 2>/dev/null >> "$summary_file" || true
        else
            echo "Docker Status: Not Running" >> "$summary_file"
        fi
    else
        echo "Docker: Not Installed" >> "$summary_file"
    fi
    
    echo "" >> "$summary_file"
    echo "=== DISCOVERY RESULTS ===" >> "$summary_file"
    
    # Count discovered resources
    for resource_file in "docker_containers_$TIMESTAMP.json" "docker_images_$TIMESTAMP.json" "docker_volumes_$TIMESTAMP.json" "docker_networks_$TIMESTAMP.json"; do
        if [[ -f "$OUTPUT_DIR/$resource_file" ]]; then
            local count=$(cat "$OUTPUT_DIR/$resource_file" | wc -l | tr -d ' ')
            local resource_type=$(echo "$resource_file" | sed 's/docker_//;s/_[0-9]*_[0-9]*.json//')
            echo "$resource_type: $count" >> "$summary_file"
        fi
    done
    
    echo "" >> "$summary_file"
    echo "=== FILES GENERATED ===" >> "$summary_file"
    echo "Report: $report_file" >> "$summary_file"
    echo "Summary: $summary_file" >> "$summary_file"
    echo "Log File: $LOG_FILE" >> "$summary_file"
    
    log_success "Discovery report generated: $report_file"
    log_success "Summary report generated: $summary_file"
}

# Cleanup function
cleanup() {
    log_info "Discovery operation completed"
    echo ""
    echo "=== DOCKER DISCOVERY COMPLETED ==="
    echo "Timestamp: $TIMESTAMP"
    echo "Log file: $LOG_FILE"
    echo "Output directory: $OUTPUT_DIR"
    echo ""
    echo "Next steps:"
    echo "1. Review the generated reports and logs"
    echo "2. Run the migration planning script"
    echo "3. Begin Podman installation and configuration"
}

# Main execution function
main() {
    echo "=== Docker Container Discovery Script ==="
    echo "Part of PodShift - Seamless Docker to Podman Migration for Apple Silicon"
    echo "Starting discovery at $(date)"
    echo ""
    
    # Ensure required directories exist
    mkdir -p "$LOGS_DIR" "$BACKUPS_DIR" "$OUTPUT_DIR"
    
    # Initialize log file
    log_info "=== Docker Discovery Started ==="
    log_info "Script: $0"
    log_info "Arguments: $*"
    log_info "Output directory: $OUTPUT_DIR"
    log_info "Verbose mode: $VERBOSE"
    
    # Parse command line arguments
    parse_args "$@"
    
    # Run discovery operations
    if ! check_docker; then
        log_error "Docker check failed, exiting"
        exit 1
    fi
    
    # Backup configuration first
    backup_docker_config
    
    # Discovery operations
    discover_containers
    discover_images
    discover_volumes
    discover_networks
    find_compose_files
    
    # Run additional discovery scripts
    run_system_discovery
    run_python_discovery
    
    # Generate final report
    generate_report
    
    # Cleanup and summary
    cleanup
}

# Set trap for cleanup on exit
trap cleanup EXIT

# Run main function with all arguments
main "$@"