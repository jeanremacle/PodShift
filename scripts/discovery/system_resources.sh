#!/bin/bash

# system_resources.sh - Apple Silicon Mac System Resources Detection Script
# Part of PodShift - Seamless Docker to Podman Migration for Apple Silicon
#
# This script detects Apple Silicon Mac architecture, system specifications, and
# resource availability for optimal Podman configuration planning.

set -euo pipefail

# Script configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" &> /dev/null && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
LOGS_DIR="$PROJECT_ROOT/logs"
TIMESTAMP=$(date '+%Y%m%d_%H%M%S')
LOG_FILE="$LOGS_DIR/system_resources_$TIMESTAMP.log"
VERBOSE=false
OUTPUT_DIR="$PROJECT_ROOT"

# Podman minimum requirements
MIN_MACOS_VERSION="12.0"
MIN_MEMORY_GB=4
MIN_DISK_GB=10
RECOMMENDED_MEMORY_GB=8
RECOMMENDED_DISK_GB=50

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
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

log_header() {
    log "HEADER" "$@"
    echo -e "${CYAN}[INFO]${NC} $*"
}

# Help function
show_help() {
    cat << EOF
Apple Silicon Mac System Resources Detection Script

USAGE:
    $0 [OPTIONS]

OPTIONS:
    -v, --verbose          Enable verbose output
    -h, --help            Show this help message
    --output-dir DIR      Specify custom output directory
    --timestamp STAMP     Use custom timestamp
    --json-only          Output only JSON (no human-readable output)

DESCRIPTION:
    This script analyzes Apple Silicon Mac system resources and capabilities for
    Podman migration planning. It detects hardware specifications,
    available resources, and potential compatibility issues.

DETECTION FEATURES:
    - Apple Silicon chip detection and specifications (M1/M2/M3)
    - CPU cores and performance characteristics
    - Memory capacity and allocation recommendations
    - Disk space availability and requirements
    - macOS version compatibility
    - Existing virtualization software conflicts
    - Resource allocation recommendations (75% rule)
    - Podman installation readiness assessment

OUTPUT:
    Results are saved as JSON files and optionally displayed
    in human-readable format.
EOF
}

# Parse command line arguments
parse_args() {
    JSON_ONLY=false
    
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
            --output-dir)
                OUTPUT_DIR="$2"
                shift 2
                ;;
            --timestamp)
                TIMESTAMP="$2"
                shift 2
                ;;
            --json-only)
                JSON_ONLY=true
                shift
                ;;
            *)
                log_error "Unknown option: $1"
                show_help
                exit 1
                ;;
        esac
    done
}

# Convert bytes to human readable format
bytes_to_human() {
    local bytes=$1
    local units=("B" "KB" "MB" "GB" "TB")
    local unit=0
    local size=$bytes
    
    while [[ $size -gt 1024 && $unit -lt $((${#units[@]} - 1)) ]]; do
        size=$((size / 1024))
        unit=$((unit + 1))
    done
    
    echo "${size}${units[$unit]}"
}

# Compare version numbers
version_compare() {
    local version1="$1"
    local version2="$2"
    
    # Convert versions to comparable numbers
    local v1=$(echo "$version1" | sed 's/\./0/g' | sed 's/^/1/')
    local v2=$(echo "$version2" | sed 's/\./0/g' | sed 's/^/1/')
    
    if [[ $v1 -ge $v2 ]]; then
        return 0  # version1 >= version2
    else
        return 1  # version1 < version2
    fi
}

# Detect system architecture
detect_architecture() {
    log_info "Detecting system architecture..."
    
    local architecture=$(uname -m)
    local cpu_brand=""
    local cpu_model=""
    local is_apple_silicon=false
    
    if [[ "$architecture" == "arm64" ]]; then
        is_apple_silicon=true
        
        # Get detailed CPU information
        local cpu_info=$(sysctl machdep.cpu.brand_string 2>/dev/null || echo "Unknown")
        cpu_brand=$(echo "$cpu_info" | cut -d':' -f2 | xargs)
        
        # Detect specific Apple Silicon chip
        if sysctl machdep.cpu.brand_string 2>/dev/null | grep -q "Apple M1"; then
            cpu_model="Apple M1"
        elif sysctl machdep.cpu.brand_string 2>/dev/null | grep -q "Apple M2"; then
            cpu_model="Apple M2"
        elif sysctl machdep.cpu.brand_string 2>/dev/null | grep -q "Apple M3"; then
            cpu_model="Apple M3"
        else
            cpu_model="Apple Silicon (Unknown)"
        fi
        
        log_success "Detected Apple Silicon: $cpu_model"
    else
        log_warn "Non-ARM64 architecture detected: $architecture"
        log_warn "This toolkit is optimized for Apple Silicon Macs"
        cpu_brand=$(sysctl machdep.cpu.brand_string 2>/dev/null | cut -d':' -f2 | xargs || echo "Unknown")
    fi
    
    # Store architecture information
    cat > "/tmp/arch_info_$TIMESTAMP.json" << EOF
{
    "architecture": "$architecture",
    "is_apple_silicon": $is_apple_silicon,
    "cpu_brand": "$cpu_brand",
    "cpu_model": "$cpu_model",
    "podman_native_support": $is_apple_silicon
}
EOF
    
    echo "$architecture"
}

# Detect CPU specifications
detect_cpu_specs() {
    log_info "Detecting CPU specifications..."
    
    local total_cores=$(sysctl -n hw.ncpu)
    local physical_cores=$(sysctl -n hw.physicalcpu)
    local logical_cores=$(sysctl -n hw.logicalcpu)
    local performance_cores=$(sysctl -n hw.perflevel0.physicalcpu 2>/dev/null || echo "0")
    local efficiency_cores=$(sysctl -n hw.perflevel1.physicalcpu 2>/dev/null || echo "0")
    
    # Calculate resource allocation (75% rule)
    local recommended_cpu_limit=$((total_cores * 75 / 100))
    if [[ $recommended_cpu_limit -lt 1 ]]; then
        recommended_cpu_limit=1
    fi
    
    # Get CPU cache information
    local l1_cache=$(sysctl -n hw.l1icachesize 2>/dev/null || echo "0")
    local l2_cache=$(sysctl -n hw.l2cachesize 2>/dev/null || echo "0")
    local l3_cache=$(sysctl -n hw.l3cachesize 2>/dev/null || echo "0")
    
    # Get CPU frequency information (if available)
    local cpu_freq=$(sysctl -n hw.cpufrequency_max 2>/dev/null || echo "0")
    
    log_success "CPU: $total_cores total cores ($physical_cores physical, $logical_cores logical)"
    if [[ $performance_cores -gt 0 || $efficiency_cores -gt 0 ]]; then
        log_info "Apple Silicon cores: $performance_cores performance + $efficiency_cores efficiency"
    fi
    log_info "Recommended CPU limit for containers: $recommended_cpu_limit cores (75%)"
    
    # Store CPU information
    cat > "/tmp/cpu_info_$TIMESTAMP.json" << EOF
{
    "total_cores": $total_cores,
    "physical_cores": $physical_cores,
    "logical_cores": $logical_cores,
    "performance_cores": $performance_cores,
    "efficiency_cores": $efficiency_cores,
    "recommended_cpu_limit": $recommended_cpu_limit,
    "cpu_utilization_percent": 75,
    "l1_cache_size": $l1_cache,
    "l2_cache_size": $l2_cache,
    "l3_cache_size": $l3_cache,
    "cpu_frequency_max": $cpu_freq
}
EOF
}

# Detect memory specifications
detect_memory_specs() {
    log_info "Detecting memory specifications..."
    
    local total_memory_bytes=$(sysctl -n hw.memsize)
    local total_memory_gb=$((total_memory_bytes / 1024 / 1024 / 1024))
    
    # Calculate memory allocation (75% rule)
    local recommended_memory_limit_gb=$((total_memory_gb * 75 / 100))
    local recommended_memory_limit_bytes=$((recommended_memory_limit_gb * 1024 * 1024 * 1024))
    
    # Get current memory usage
    local memory_pressure=$(memory_pressure 2>/dev/null | head -1 || echo "System-wide memory free percentage: 0%")
    local free_percent=$(echo "$memory_pressure" | grep -o '[0-9]*%' | head -1 | sed 's/%//' || echo "0")
    
    # Calculate available memory
    local available_memory_gb=$((total_memory_gb * free_percent / 100))
    
    # Check against minimum requirements
    local memory_adequate=true
    local memory_status="adequate"
    
    if [[ $total_memory_gb -lt $MIN_MEMORY_GB ]]; then
        memory_adequate=false
        memory_status="insufficient"
        log_warn "Total memory ($total_memory_gb GB) is below minimum requirement ($MIN_MEMORY_GB GB)"
    elif [[ $total_memory_gb -lt $RECOMMENDED_MEMORY_GB ]]; then
        memory_status="minimal"
        log_warn "Total memory ($total_memory_gb GB) is below recommended ($RECOMMENDED_MEMORY_GB GB)"
    else
        log_success "Memory: $total_memory_gb GB total (meets requirements)"
    fi
    
    log_info "Recommended memory limit for containers: $recommended_memory_limit_gb GB (75%)"
    log_info "Current system memory free: $free_percent%"
    
    # Get memory configuration details
    local memory_type=""
    if sysctl hw.memsize | grep -q "hw.memsize"; then
        # Try to get memory type from system_profiler (slower but more detailed)
        if command -v system_profiler >/dev/null 2>&1; then
            memory_type=$(system_profiler SPMemoryDataType 2>/dev/null | grep "Type:" | head -1 | awk '{print $2}' || echo "Unknown")
        fi
    fi
    
    # Store memory information
    cat > "/tmp/memory_info_$TIMESTAMP.json" << EOF
{
    "total_memory_bytes": $total_memory_bytes,
    "total_memory_gb": $total_memory_gb,
    "recommended_memory_limit_gb": $recommended_memory_limit_gb,
    "recommended_memory_limit_bytes": $recommended_memory_limit_bytes,
    "memory_utilization_percent": 75,
    "available_memory_gb": $available_memory_gb,
    "memory_free_percent": $free_percent,
    "memory_adequate": $memory_adequate,
    "memory_status": "$memory_status",
    "memory_type": "$memory_type",
    "minimum_required_gb": $MIN_MEMORY_GB,
    "recommended_gb": $RECOMMENDED_MEMORY_GB
}
EOF
}

# Detect disk space and storage
detect_storage_specs() {
    log_info "Detecting storage specifications..."
    
    # Get disk space for root filesystem
    local disk_info=$(df -h / | tail -1)
    local total_space=$(echo "$disk_info" | awk '{print $2}' | sed 's/[^0-9.]//g')
    local used_space=$(echo "$disk_info" | awk '{print $3}' | sed 's/[^0-9.]//g')
    local available_space=$(echo "$disk_info" | awk '{print $4}' | sed 's/[^0-9.]//g')
    local used_percent=$(echo "$disk_info" | awk '{print $5}' | sed 's/%//')
    
    # Convert to GB (approximation)
    local total_gb=$(echo "$total_space" | sed 's/G$//' | awk '{print int($1)}')
    local available_gb=$(echo "$available_space" | sed 's/G$//' | awk '{print int($1)}')
    
    # Check storage adequacy
    local storage_adequate=true
    local storage_status="adequate"
    
    if [[ $available_gb -lt $MIN_DISK_GB ]]; then
        storage_adequate=false
        storage_status="insufficient"
        log_error "Available disk space ($available_gb GB) is below minimum requirement ($MIN_DISK_GB GB)"
    elif [[ $available_gb -lt $RECOMMENDED_DISK_GB ]]; then
        storage_status="minimal"
        log_warn "Available disk space ($available_gb GB) is below recommended ($RECOMMENDED_DISK_GB GB)"
    else
        log_success "Storage: $available_gb GB available (meets requirements)"
    fi
    
    # Get storage device information
    local storage_type="Unknown"
    local storage_device=""
    
    if command -v diskutil >/dev/null 2>&1; then
        storage_device=$(df / | tail -1 | awk '{print $1}')
        if [[ -n "$storage_device" ]]; then
            local disk_info_detail=$(diskutil info "$storage_device" 2>/dev/null || echo "")
            if echo "$disk_info_detail" | grep -q "Solid State"; then
                storage_type="SSD"
            elif echo "$disk_info_detail" | grep -q "Rotational"; then
                storage_type="HDD"
            fi
        fi
    fi
    
    log_info "Storage type: $storage_type"
    log_info "Disk usage: $used_percent% used"
    
    # Store storage information
    cat > "/tmp/storage_info_$TIMESTAMP.json" << EOF
{
    "total_space_gb": $total_gb,
    "available_space_gb": $available_gb,
    "used_percent": $used_percent,
    "storage_adequate": $storage_adequate,
    "storage_status": "$storage_status",
    "storage_type": "$storage_type",
    "storage_device": "$storage_device",
    "minimum_required_gb": $MIN_DISK_GB,
    "recommended_gb": $RECOMMENDED_DISK_GB
}
EOF
}

# Detect macOS version
detect_macos_version() {
    log_info "Detecting macOS version..."
    
    local macos_version=$(sw_vers -productVersion)
    local macos_name=$(sw_vers -productName)
    local macos_build=$(sw_vers -buildVersion)
    
    # Check version compatibility
    local version_adequate=true
    local version_status="compatible"
    
    if ! version_compare "$macos_version" "$MIN_MACOS_VERSION"; then
        version_adequate=false
        version_status="incompatible"
        log_error "macOS version ($macos_version) is below minimum requirement ($MIN_MACOS_VERSION)"
    else
        log_success "macOS: $macos_name $macos_version (build $macos_build)"
    fi
    
    # Get additional system information
    local system_version=$(system_profiler SPSoftwareDataType 2>/dev/null | grep "System Version" | awk -F': ' '{print $2}' || echo "Unknown")
    local uptime=$(uptime | awk '{print $3, $4}' | sed 's/,//')
    
    # Store macOS information
    cat > "/tmp/macos_info_$TIMESTAMP.json" << EOF
{
    "product_name": "$macos_name",
    "product_version": "$macos_version",
    "build_version": "$macos_build",
    "system_version": "$system_version",
    "version_adequate": $version_adequate,
    "version_status": "$version_status",
    "minimum_required_version": "$MIN_MACOS_VERSION",
    "uptime": "$uptime"
}
EOF
}

# Detect virtualization software conflicts
detect_virtualization_conflicts() {
    log_info "Detecting existing virtualization software..."
    
    local conflicts=()
    local running_vms=()
    local installed_software=()
    
    # Check for running Docker Desktop
    if pgrep -x "Docker Desktop" >/dev/null 2>&1; then
        conflicts+=("Docker Desktop is currently running")
        running_vms+=("Docker Desktop")
    fi
    
    # Check for VMware Fusion
    if [[ -d "/Applications/VMware Fusion.app" ]]; then
        installed_software+=("VMware Fusion")
        if pgrep -x "VMware Fusion" >/dev/null 2>&1; then
            conflicts+=("VMware Fusion is currently running")
            running_vms+=("VMware Fusion")
        fi
    fi
    
    # Check for Parallels Desktop
    if [[ -d "/Applications/Parallels Desktop.app" ]]; then
        installed_software+=("Parallels Desktop")
        if pgrep -x "prl_client_app" >/dev/null 2>&1; then
            conflicts+=("Parallels Desktop is currently running")
            running_vms+=("Parallels Desktop")
        fi
    fi
    
    # Check for VirtualBox
    if [[ -d "/Applications/VirtualBox.app" ]] || command -v VBoxManage >/dev/null 2>&1; then
        installed_software+=("VirtualBox")
        if pgrep -x "VirtualBox" >/dev/null 2>&1 || pgrep -x "VBoxHeadless" >/dev/null 2>&1; then
            conflicts+=("VirtualBox is currently running")
            running_vms+=("VirtualBox")
        fi
    fi
    
    # Check for UTM
    if [[ -d "/Applications/UTM.app" ]]; then
        installed_software+=("UTM")
        if pgrep -x "UTM" >/dev/null 2>&1; then
            conflicts+=("UTM is currently running")
            running_vms+=("UTM")
        fi
    fi
    
    # Check for Lima
    if command -v lima >/dev/null 2>&1 || command -v limactl >/dev/null 2>&1; then
        installed_software+=("Lima")
        if limactl list 2>/dev/null | grep -q "Running"; then
            conflicts+=("Lima VMs are currently running")
            running_vms+=("Lima")
        fi
    fi
    
    # Report findings
    if [[ ${#conflicts[@]} -eq 0 ]]; then
        log_success "No virtualization conflicts detected"
    else
        log_warn "Found ${#conflicts[@]} potential conflicts:"
        for conflict in "${conflicts[@]}"; do
            log_warn "  - $conflict"
        done
    fi
    
    if [[ ${#installed_software[@]} -gt 0 ]]; then
        log_info "Installed virtualization software:"
        for software in "${installed_software[@]}"; do
            log_info "  - $software"
        done
    fi
    
    # Create JSON array for conflicts and software
    local conflicts_json=$(printf '%s\n' "${conflicts[@]}" | jq -R . | jq -s . 2>/dev/null || echo '[]')
    local running_vms_json=$(printf '%s\n' "${running_vms[@]}" | jq -R . | jq -s . 2>/dev/null || echo '[]')
    local installed_json=$(printf '%s\n' "${installed_software[@]}" | jq -R . | jq -s . 2>/dev/null || echo '[]')
    
    # Store virtualization information
    cat > "/tmp/virtualization_info_$TIMESTAMP.json" << EOF
{
    "conflicts_detected": ${#conflicts[@]},
    "conflicts": $conflicts_json,
    "running_vms": $running_vms_json,
    "installed_software": $installed_json,
    "has_conflicts": $([ ${#conflicts[@]} -gt 0 ] && echo "true" || echo "false")
}
EOF
}

# Check system limits and configurations
check_system_limits() {
    log_info "Checking system limits and configurations..."
    
    # Check file descriptor limits
    local soft_limit=$(ulimit -n)
    local hard_limit=$(ulimit -Hn)
    
    # Check process limits
    local process_limit=$(ulimit -u)
    
    # Check kernel parameters relevant to containers
    local max_files=$(sysctl -n kern.maxfiles 2>/dev/null || echo "0")
    local max_proc=$(sysctl -n kern.maxproc 2>/dev/null || echo "0")
    
    # Check if Rosetta 2 is installed (for x86_64 compatibility)
    local rosetta_installed=false
    if [[ -f "/Library/Apple/usr/share/rosetta/rosetta" ]]; then
        rosetta_installed=true
        log_success "Rosetta 2 is installed (x86_64 compatibility available)"
    else
        log_warn "Rosetta 2 not detected - x86_64 containers may not work"
    fi
    
    # Check SIP (System Integrity Protection) status
    local sip_status="unknown"
    if command -v csrutil >/dev/null 2>&1; then
        if csrutil status 2>/dev/null | grep -q "enabled"; then
            sip_status="enabled"
        elif csrutil status 2>/dev/null | grep -q "disabled"; then
            sip_status="disabled"
        fi
    fi
    
    log_info "File descriptor limits: $soft_limit (soft), $hard_limit (hard)"
    log_info "Process limit: $process_limit"
    log_info "System Integrity Protection: $sip_status"
    
    # Store system limits information
    cat > "/tmp/system_limits_$TIMESTAMP.json" << EOF
{
    "file_descriptor_soft_limit": $soft_limit,
    "file_descriptor_hard_limit": $hard_limit,
    "process_limit": $process_limit,
    "kernel_max_files": $max_files,
    "kernel_max_processes": $max_proc,
    "rosetta_installed": $rosetta_installed,
    "sip_status": "$sip_status"
}
EOF
}

# Generate recommendations
generate_recommendations() {
    log_info "Generating system recommendations..."
    
    local recommendations=()
    local warnings=()
    local critical_issues=()
    
    # Read previously generated info files
    local arch_info=$(cat "/tmp/arch_info_$TIMESTAMP.json" 2>/dev/null || echo '{}')
    local cpu_info=$(cat "/tmp/cpu_info_$TIMESTAMP.json" 2>/dev/null || echo '{}')
    local memory_info=$(cat "/tmp/memory_info_$TIMESTAMP.json" 2>/dev/null || echo '{}')
    local storage_info=$(cat "/tmp/storage_info_$TIMESTAMP.json" 2>/dev/null || echo '{}')
    local macos_info=$(cat "/tmp/macos_info_$TIMESTAMP.json" 2>/dev/null || echo '{}')
    local virt_info=$(cat "/tmp/virtualization_info_$TIMESTAMP.json" 2>/dev/null || echo '{}')
    local limits_info=$(cat "/tmp/system_limits_$TIMESTAMP.json" 2>/dev/null || echo '{}')
    
    # Architecture recommendations
    if echo "$arch_info" | jq -r '.is_apple_silicon' | grep -q "false"; then
        critical_issues+=("Non-Apple Silicon architecture detected - Podman performance will be suboptimal")
    else
        recommendations+=("Apple Silicon detected - Podman will run natively with optimal performance")
    fi
    
    # Memory recommendations
    local memory_adequate=$(echo "$memory_info" | jq -r '.memory_adequate' 2>/dev/null || echo "true")
    if [[ "$memory_adequate" == "false" ]]; then
        critical_issues+=("Insufficient memory for reliable container operations")
    else
        local memory_status=$(echo "$memory_info" | jq -r '.memory_status' 2>/dev/null || echo "adequate")
        if [[ "$memory_status" == "minimal" ]]; then
            warnings+=("Memory is minimal - consider upgrading for better performance")
        fi
    fi
    
    # Storage recommendations
    local storage_adequate=$(echo "$storage_info" | jq -r '.storage_adequate' 2>/dev/null || echo "true")
    if [[ "$storage_adequate" == "false" ]]; then
        critical_issues+=("Insufficient disk space for Podman installation and container images")
    fi
    
    # macOS version recommendations
    local version_adequate=$(echo "$macos_info" | jq -r '.version_adequate' 2>/dev/null || echo "true")
    if [[ "$version_adequate" == "false" ]]; then
        critical_issues+=("macOS version is too old - upgrade required")
    fi
    
    # Virtualization conflict recommendations
    local has_conflicts=$(echo "$virt_info" | jq -r '.has_conflicts' 2>/dev/null || echo "false")
    if [[ "$has_conflicts" == "true" ]]; then
        warnings+=("Stop running virtualization software before Podman installation")
    fi
    
    # Rosetta recommendations
    local rosetta_installed=$(echo "$limits_info" | jq -r '.rosetta_installed' 2>/dev/null || echo "false")
    if [[ "$rosetta_installed" == "false" ]]; then
        recommendations+=("Install Rosetta 2 for x86_64 container compatibility: softwareupdate --install-rosetta")
    fi
    
    # General recommendations
    recommendations+=("Configure Podman to use 75% of system resources for optimal performance")
    recommendations+=("Use Podman Desktop for GUI management if preferred")
    recommendations+=("Consider using Podman Machine for isolated environments")
    
    # Create JSON arrays (handle empty arrays safely)
    local recommendations_json='[]'
    if [[ ${#recommendations[@]} -gt 0 ]]; then
        recommendations_json=$(printf '%s\n' "${recommendations[@]}" | jq -R . | jq -s . 2>/dev/null || echo '[]')
    fi
    
    local warnings_json='[]'
    if [[ ${#warnings[@]} -gt 0 ]]; then
        warnings_json=$(printf '%s\n' "${warnings[@]}" | jq -R . | jq -s . 2>/dev/null || echo '[]')
    fi
    
    local critical_json='[]'
    if [[ ${#critical_issues[@]} -gt 0 ]]; then
        critical_json=$(printf '%s\n' "${critical_issues[@]}" | jq -R . | jq -s . 2>/dev/null || echo '[]')
    fi
    
    # Store recommendations
    cat > "/tmp/recommendations_$TIMESTAMP.json" << EOF
{
    "recommendations": $recommendations_json,
    "warnings": $warnings_json,
    "critical_issues": $critical_json,
    "overall_readiness": $([ ${#critical_issues[@]} -eq 0 ] && echo "\"ready\"" || echo "\"not_ready\""),
    "readiness_score": $((100 - ${#critical_issues[@]} * 30 - ${#warnings[@]} * 10))
}
EOF
    
    # Log recommendations
    if [[ ${#critical_issues[@]} -gt 0 ]]; then
        log_error "Critical issues found:"
        for issue in "${critical_issues[@]}"; do
            log_error "  - $issue"
        done
    fi
    
    if [[ ${#warnings[@]} -gt 0 ]]; then
        log_warn "Warnings:"
        for warning in "${warnings[@]}"; do
            log_warn "  - $warning"
        done
    fi
    
    if [[ ${#recommendations[@]} -gt 0 ]]; then
        log_info "Recommendations:"
        for rec in "${recommendations[@]}"; do
            log_info "  - $rec"
        done
    fi
}

# Compile final system report
compile_system_report() {
    log_info "Compiling comprehensive system report..."
    
    local output_file="$OUTPUT_DIR/system_resources_$TIMESTAMP.json"
    
    # Read all temporary info files
    local arch_info=$(cat "/tmp/arch_info_$TIMESTAMP.json" 2>/dev/null || echo '{}')
    local cpu_info=$(cat "/tmp/cpu_info_$TIMESTAMP.json" 2>/dev/null || echo '{}')
    local memory_info=$(cat "/tmp/memory_info_$TIMESTAMP.json" 2>/dev/null || echo '{}')
    local storage_info=$(cat "/tmp/storage_info_$TIMESTAMP.json" 2>/dev/null || echo '{}')
    local macos_info=$(cat "/tmp/macos_info_$TIMESTAMP.json" 2>/dev/null || echo '{}')
    local virt_info=$(cat "/tmp/virtualization_info_$TIMESTAMP.json" 2>/dev/null || echo '{}')
    local limits_info=$(cat "/tmp/system_limits_$TIMESTAMP.json" 2>/dev/null || echo '{}')
    local recommendations_info=$(cat "/tmp/recommendations_$TIMESTAMP.json" 2>/dev/null || echo '{}')
    
    # Create comprehensive report
    cat > "$output_file" << EOF
{
    "metadata": {
        "timestamp": "$TIMESTAMP",
        "generated_at": "$(date -Iseconds)",
        "script_version": "1.0.0",
        "hostname": "$(hostname)",
        "script_path": "$0"
    },
    "architecture": $arch_info,
    "cpu": $cpu_info,
    "memory": $memory_info,
    "storage": $storage_info,
    "operating_system": $macos_info,
    "virtualization": $virt_info,
    "system_limits": $limits_info,
    "recommendations": $recommendations_info,
    "podman_readiness": {
        "overall_score": $(echo "$recommendations_info" | jq -r '.readiness_score' 2>/dev/null || echo "0"),
        "status": $(echo "$recommendations_info" | jq -r '.overall_readiness' 2>/dev/null || echo "\"unknown\""),
        "critical_issues_count": $(echo "$recommendations_info" | jq '.critical_issues | length' 2>/dev/null || echo "0"),
        "warnings_count": $(echo "$recommendations_info" | jq '.warnings | length' 2>/dev/null || echo "0")
    }
}
EOF
    
    log_success "System report compiled: $output_file"
    
    # Cleanup temporary files
    rm -f "/tmp/"*"_info_$TIMESTAMP.json" "/tmp/recommendations_$TIMESTAMP.json" 2>/dev/null || true
    
    echo "$output_file"
}

# Display human-readable summary
display_summary() {
    local report_file="$1"
    
    if [[ "$JSON_ONLY" == "true" ]]; then
        return 0
    fi
    
    echo ""
    echo "=== APPLE SILICON MAC SYSTEM RESOURCES SUMMARY ==="
    echo "Generated: $(date)"
    echo ""
    
    # Extract key information using jq
    local architecture=$(jq -r '.architecture.cpu_model' "$report_file" 2>/dev/null || echo "Unknown")
    local total_cores=$(jq -r '.cpu.total_cores' "$report_file" 2>/dev/null || echo "0")
    local total_memory=$(jq -r '.memory.total_memory_gb' "$report_file" 2>/dev/null || echo "0")
    local available_storage=$(jq -r '.storage.available_space_gb' "$report_file" 2>/dev/null || echo "0")
    local macos_version=$(jq -r '.operating_system.product_version' "$report_file" 2>/dev/null || echo "Unknown")
    local readiness_score=$(jq -r '.podman_readiness.overall_score' "$report_file" 2>/dev/null || echo "0")
    local readiness_status=$(jq -r '.podman_readiness.status' "$report_file" 2>/dev/null || echo "unknown")
    
    echo "SYSTEM SPECIFICATIONS:"
    echo "  Architecture: $architecture"
    echo "  CPU Cores: $total_cores"
    echo "  Memory: ${total_memory} GB"
    echo "  Available Storage: ${available_storage} GB"
    echo "  macOS Version: $macos_version"
    echo ""
    
    echo "PODMAN READINESS:"
    echo "  Score: ${readiness_score}/100"
    echo "  Status: $readiness_status"
    echo ""
    
    # Show recommendations if any
    local recommendations=$(jq -r '.recommendations.recommendations[]?' "$report_file" 2>/dev/null)
    if [[ -n "$recommendations" ]]; then
        echo "RECOMMENDATIONS:"
        echo "$recommendations" | sed 's/^/  - /'
        echo ""
    fi
    
    # Show warnings if any
    local warnings=$(jq -r '.recommendations.warnings[]?' "$report_file" 2>/dev/null)
    if [[ -n "$warnings" ]]; then
        echo "WARNINGS:"
        echo "$warnings" | sed 's/^/  - /'
        echo ""
    fi
    
    # Show critical issues if any
    local critical=$(jq -r '.recommendations.critical_issues[]?' "$report_file" 2>/dev/null)
    if [[ -n "$critical" ]]; then
        echo "CRITICAL ISSUES:"
        echo "$critical" | sed 's/^/  - /'
        echo ""
    fi
    
    echo "Report saved to: $report_file"
}

# Main execution function
main() {
    echo "=== Apple Silicon Mac System Resources Detection ==="
    echo "Part of PodShift - Seamless Docker to Podman Migration"
    echo "Starting analysis at $(date)"
    echo ""
    
    # Ensure required directories exist
    mkdir -p "$LOGS_DIR" "$OUTPUT_DIR"
    
    # Initialize log file
    log_info "=== System Resources Detection Started ==="
    log_info "Script: $0"
    log_info "Arguments: $*"
    log_info "Output directory: $OUTPUT_DIR"
    log_info "Verbose mode: $VERBOSE"
    
    # Parse command line arguments
    parse_args "$@"
    
    # Check if we're running on macOS
    if [[ "$(uname -s)" != "Darwin" ]]; then
        log_error "This script is designed for macOS only"
        exit 1
    fi
    
    # Run detection operations
    detect_architecture
    detect_cpu_specs
    detect_memory_specs
    detect_storage_specs
    detect_macos_version
    detect_virtualization_conflicts
    check_system_limits
    generate_recommendations
    
    # Compile final report
    local report_file=$(compile_system_report)
    
    # Display summary
    display_summary "$report_file"
    
    log_success "System resources detection completed"
}

# Set trap for cleanup on exit
trap 'rm -f "/tmp/"*"_info_$TIMESTAMP.json" "/tmp/recommendations_$TIMESTAMP.json" 2>/dev/null || true' EXIT

# Run main function with all arguments
main "$@"