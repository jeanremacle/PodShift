# Best Practices for Apple Silicon Mac Migration

Optimize your Docker to Podman migration for maximum performance and reliability on Apple Silicon Macs.

> **Navigation**: [← Migration Planning](migration-planning.md) | [Discovery Process](discovery-process.md) | [Quick Start](quick-start.md)

**Related Documentation:**
- [Migration Planning](migration-planning.md) - Strategic migration approach
- [Discovery Process](discovery-process.md) - Analyze your environment first
- [Apple Silicon Compatibility](../troubleshooting/m1-compatibility.md) - Apple Silicon specific issues
- [Configuration Options](../api/configuration-options.md) - Performance tuning settings
- [Common Issues](../troubleshooting/common-issues.md) - Troubleshooting optimization problems

## Table of Contents

1. [Apple Silicon Optimization](#apple-silicon-optimization)
2. [Container Image Best Practices](#container-image-best-practices)
3. [Resource Management](#resource-management)
4. [Security Considerations](#security-considerations)
5. [Performance Tuning](#performance-tuning)
6. [Monitoring and Observability](#monitoring-and-observability)
7. [Operational Best Practices](#operational-best-practices)
8. [Development Workflow](#development-workflow)

## Apple Silicon Optimization

### ARM64 Architecture Advantages

**Leverage Native Performance**
```bash
# Verify you're running ARM64 native
uname -m  # Should output: arm64

# Check Podman is using native architecture
podman version --format "{{.Server.Os}}/{{.Server.Arch}}"  # Should output: linux/arm64
```

**Unified Memory Architecture Benefits**
- **Lower memory latency**: Direct CPU-memory connection
- **Shared memory pools**: GPU and CPU share same memory space
- **Efficient memory allocation**: Better cache utilization

```bash
# Optimize for unified memory architecture
podman run --memory-swappiness=1 \  # Minimize swap usage
  --oom-kill-disable=false \         # Allow OOM killer for memory pressure
  --memory=4g \                      # Set explicit memory limits
  your-container
```

### M1/M2/M3 Specific Configurations

**Performance vs Efficiency Cores**
```bash
# Apple Silicon configurations:
# M1: 4 performance + 4 efficiency cores
# M1 Pro/Max: 8 performance + 2 efficiency cores
# M2: 4 performance + 4 efficiency cores
# M2 Pro/Max: 8-12 performance + 4 efficiency cores
# M3: 4-8 performance + 4 efficiency cores
# M3 Pro/Max: 8-12 performance + 4-6 efficiency cores

# Check your core configuration
sysctl hw.perflevel0.physicalcpu  # Performance cores
sysctl hw.perflevel1.physicalcpu  # Efficiency cores

# Configure CPU allocation for performance-critical containers
podman run --cpus="4.0" \           # Use performance cores
  --cpu-shares=1024 \                # High priority
  performance-critical-app

# Configure CPU allocation for background services  
podman run --cpus="2.0" \           # Use efficiency cores
  --cpu-shares=512 \                 # Lower priority
  background-service
```

**Rosetta 2 Optimization**
```bash
# Install Rosetta 2 for x86_64 compatibility
softwareupdate --install-rosetta --agree-to-license

# Check if running under Rosetta
sysctl sysctl.proc_translated  # 1 = Rosetta, 0 = native

# Prefer native ARM64 images when available
podman pull --platform linux/arm64 nginx:latest

# For x86_64 only images, optimize for emulation
podman run --platform linux/amd64 \
  --memory=2g \                      # Extra memory for emulation overhead
  --cpus="2.0" \                     # Limit CPU to prevent overheating
  legacy-x86-app
```

## Container Image Best Practices

### ARM64 Image Selection Strategy

**Priority Order for Image Selection:**
1. **Multi-architecture official images** (recommended)
2. **Native ARM64 images** (arm64v8/ prefix)
3. **Custom built ARM64 images**
4. **x86_64 images with Rosetta 2** (last resort)

```bash
# Check image architecture support
podman manifest inspect nginx:latest

# Example output showing multi-arch support:
{
  "manifests": [
    {
      "platform": {
        "architecture": "amd64",
        "os": "linux"
      }
    },
    {
      "platform": {
        "architecture": "arm64",
        "os": "linux",
        "variant": "v8"
      }
    }
  ]
}
```

### Building ARM64 Images

**Dockerfile Best Practices for ARM64**
```dockerfile
# Use multi-stage builds for efficiency
FROM --platform=$BUILDPLATFORM node:18-alpine AS builder
ARG TARGETPLATFORM
ARG BUILDPLATFORM
RUN echo "Building on $BUILDPLATFORM for $TARGETPLATFORM"

# Install dependencies
WORKDIR /app
COPY package*.json ./
RUN npm ci --only=production

# Production stage
FROM node:18-alpine
WORKDIR /app
COPY --from=builder /app/node_modules ./node_modules
COPY . .

# Optimize for ARM64
ENV NODE_OPTIONS="--max-old-space-size=2048"
EXPOSE 3000
CMD ["node", "server.js"]
```

**Building Multi-Architecture Images**
```bash
# Setup buildx for multi-arch builds
podman build --platform linux/amd64,linux/arm64 \
  -t myapp:latest \
  --push \
  .

# Build ARM64 specific optimized image
podman build --platform linux/arm64 \
  -t myapp:arm64 \
  --build-arg OPTIMIZE_FOR_M1=true \
  .
```

### Image Optimization Techniques

**Size Optimization**
```dockerfile
# Use Alpine Linux for smaller images
FROM alpine:3.18

# Install only required packages
RUN apk add --no-cache \
    nodejs \
    npm \
    && npm cache clean --force

# Use multi-stage builds to exclude build dependencies
FROM alpine:3.18 AS runtime
COPY --from=builder /app/dist /app
```

**Layer Optimization**
```dockerfile
# Optimize layer ordering (least to most frequently changing)
FROM node:18-alpine

# System packages (changes rarely)
RUN apk add --no-cache curl

# Application dependencies (changes occasionally)
COPY package*.json ./
RUN npm ci --only=production

# Application code (changes frequently)
COPY . .
```

## Resource Management

### Memory Management on M1 Macs

**Unified Memory Architecture Optimization**
```bash
# Calculate optimal memory allocation
total_memory_gb=$(( $(sysctl -n hw.memsize) / 1024 / 1024 / 1024 ))
container_memory_gb=$(( total_memory_gb * 75 / 100 ))

echo "Total: ${total_memory_gb}GB, Available for containers: ${container_memory_gb}GB"

# Configure memory limits per container type
podman run --memory="${container_memory_gb}g" \
  --memory-reservation="$((container_memory_gb / 2))g" \
  --memory-swappiness=10 \
  database-container

# Memory-intensive applications
podman run --memory="4g" \
  --memory-reservation="3g" \
  --oom-kill-disable=false \
  memory-intensive-app

# Lightweight services
podman run --memory="512m" \
  --memory-reservation="256m" \
  lightweight-service
```

**Memory Monitoring and Alerting**
```bash
#!/bin/bash
# memory_monitor.sh - Monitor container memory usage

monitor_container_memory() {
    while true; do
        podman stats --no-stream --format "table {{.Container}}\t{{.MemUsage}}\t{{.MemPerc}}" | \
        while IFS=$'\t' read -r container mem_usage mem_perc; do
            if [[ "$mem_perc" =~ ([0-9.]+)% ]]; then
                perc=${BASH_REMATCH[1]}
                if (( $(echo "$perc > 80" | bc -l) )); then
                    echo "ALERT: Container $container using ${perc}% memory ($mem_usage)"
                    # Send notification or take action
                fi
            fi
        done
        sleep 30
    done
}
```

### CPU Management Strategies

**CPU Affinity and Scheduling**
```bash
# High-performance applications - use performance cores
podman run --cpuset-cpus="0-3" \    # Performance cores on M1
  --cpu-shares=1024 \
  --cpus="4.0" \
  high-performance-app

# Background services - use efficiency cores  
podman run --cpuset-cpus="4-7" \    # Efficiency cores on M1
  --cpu-shares=512 \
  --cpus="2.0" \
  background-service

# Mixed workload - let scheduler decide
podman run --cpus="2.0" \
  --cpu-shares=768 \
  mixed-workload-app
```

**CPU Thermal Management**
```bash
# Monitor CPU temperature (requires additional tools)
monitor_cpu_thermal() {
    while true; do
        # Check thermal pressure (macOS specific)
        thermal_state=$(pmset -g thermlog | tail -1)
        
        if [[ "$thermal_state" =~ "High" ]]; then
            echo "THERMAL WARNING: Reducing container CPU limits"
            # Temporarily reduce CPU limits for all containers
            reduce_container_cpu_limits
        fi
        
        sleep 60
    done
}
```

### Storage Optimization

**APFS Optimization for Containers**
```bash
# Use APFS clones for efficient storage
create_apfs_clone() {
    local source_volume="$1"
    local clone_name="$2"
    
    # Create APFS snapshot first
    tmutil localsnapshot
    
    # Use copy-on-write for container volumes
    podman volume create "$clone_name" \
      --opt type=bind \
      --opt o=bind,copy-up
}

# Optimize Podman storage for APFS
configure_podman_storage() {
    cat > ~/.config/containers/storage.conf << EOF
[storage]
driver = "overlay"
runroot = "/tmp/podman-run"
graphroot = "/Users/$USER/.local/share/containers/storage"

[storage.options]
pull_options = {enable_partial_images = "true"}
mountopt = "nodev,metacopy=on"
EOF
}
```

## Security Considerations

### Rootless Container Security

**Podman Rootless Configuration**
```bash
# Configure rootless Podman for M1 Mac
podman system reset  # Clean slate

# Setup user namespaces
echo "$USER:100000:65536" | sudo tee /etc/subuid
echo "$USER:100000:65536" | sudo tee /etc/subgid

# Initialize rootless Podman
podman system migrate

# Verify rootless operation
podman info | grep -i root
# Should show: rootless: true
```

**Security Best Practices**
```bash
# Run containers with minimal privileges
podman run --read-only \              # Read-only root filesystem
  --tmpfs /tmp \                      # Writable tmp directory
  --user 1000:1000 \                  # Non-root user
  --cap-drop=ALL \                    # Drop all capabilities
  --cap-add=NET_BIND_SERVICE \        # Add only required capabilities
  secure-app

# Use security profiles
podman run --security-opt seccomp=default \
  --security-opt apparmor=default \
  --security-opt no-new-privileges \
  security-conscious-app
```

### Network Security

**Secure Network Configuration**
```bash
# Create isolated networks for different tiers
podman network create --driver bridge \
  --subnet 172.20.0.0/16 \
  --gateway 172.20.0.1 \
  frontend-network

podman network create --driver bridge \
  --subnet 172.21.0.0/16 \
  --gateway 172.21.0.1 \
  --internal \                        # No external access
  backend-network

# Run containers with network isolation
podman run --network frontend-network \
  --ip 172.20.0.10 \
  web-server

podman run --network backend-network \
  --ip 172.21.0.10 \
  database-server
```

### Secret Management

**Secure Secret Handling**
```bash
# Use Podman secrets instead of environment variables
echo "supersecret" | podman secret create db-password -

# Mount secrets in containers
podman run --secret db-password,type=mount,target=/run/secrets/db-password \
  database-container

# Access secret in container
# File available at: /run/secrets/db-password
```

## Performance Tuning

### Application-Specific Optimizations

**Database Containers**
```bash
# PostgreSQL optimization for Apple Silicon Mac
podman run -d --name postgres \
  --memory=4g \
  --memory-reservation=3g \
  --cpus="2.0" \
  --cpuset-cpus="0-1" \              # Use performance cores
  -e POSTGRES_SHARED_BUFFERS=1GB \
  -e POSTGRES_EFFECTIVE_CACHE_SIZE=3GB \
  -e POSTGRES_WORK_MEM=64MB \
  -v postgres-data:/var/lib/postgresql/data \
  postgres:15

# Redis optimization for Apple Silicon Mac
podman run -d --name redis \
  --memory=1g \
  --memory-reservation=768m \
  --cpus="1.0" \
  -e REDIS_MAXMEMORY=768mb \
  -e REDIS_MAXMEMORY_POLICY=allkeys-lru \
  redis:7-alpine
```

**Web Server Optimization**
```bash
# Nginx optimization for Apple Silicon Mac
podman run -d --name nginx \
  --memory=512m \
  --cpus="1.0" \
  -p 80:80 \
  -p 443:443 \
  -v nginx-conf:/etc/nginx/conf.d \
  nginx:alpine

# Nginx configuration optimized for Apple Silicon
cat > nginx.conf << EOF
worker_processes auto;  # Auto-detect CPU cores
worker_cpu_affinity auto;
worker_rlimit_nofile 4096;

events {
    worker_connections 1024;
    use kqueue;  # Efficient on macOS
    multi_accept on;
}

http {
    sendfile on;
    tcp_nopush on;
    tcp_nodelay on;
    keepalive_timeout 65;
    
    # Optimize for Apple Silicon memory architecture
    client_body_buffer_size 128k;
    client_max_body_size 10m;
    client_header_buffer_size 1k;
    large_client_header_buffers 4 4k;
}
EOF
```

### Monitoring Performance

**Performance Monitoring Setup**
```bash
#!/bin/bash
# performance_monitor.sh - Monitor container performance on Apple Silicon

monitor_performance() {
    echo "Container Performance Monitor for Apple Silicon Mac"
    echo "========================================"
    
    while true; do
        echo "$(date): Container Resource Usage"
        
        # CPU and Memory stats
        podman stats --no-stream --format "table {{.Container}}\t{{.CPUPerc}}\t{{.MemUsage}}\t{{.MemPerc}}\t{{.PIDs}}"
        
        # Disk I/O stats
        echo -e "\nDisk I/O:"
        podman stats --no-stream --format "table {{.Container}}\t{{.BlockIO}}\t{{.NetIO}}"
        
        # System thermal state
        echo -e "\nSystem Thermal State:"
        pmset -g thermlog | tail -1
        
        echo "----------------------------------------"
        sleep 30
    done
}
```

**Performance Benchmarking**
```bash
# Benchmark container startup time
benchmark_startup() {
    local image="$1"
    local iterations=5
    local total_time=0
    
    for i in $(seq 1 $iterations); do
        start_time=$(date +%s.%N)
        podman run --rm "$image" echo "Benchmark test $i"
        end_time=$(date +%s.%N)
        
        duration=$(echo "$end_time - $start_time" | bc)
        total_time=$(echo "$total_time + $duration" | bc)
        echo "Iteration $i: ${duration}s"
    done
    
    average=$(echo "scale=3; $total_time / $iterations" | bc)
    echo "Average startup time: ${average}s"
}
```

## Monitoring and Observability

### Health Monitoring

**Container Health Checks**
```dockerfile
# Add health checks to Dockerfiles
HEALTHCHECK --interval=30s --timeout=10s --start-period=5s --retries=3 \
  CMD curl -f http://localhost:8080/health || exit 1
```

```bash
# Run containers with health monitoring
podman run -d --name app \
  --health-cmd="curl -f http://localhost:8080/health" \
  --health-interval=30s \
  --health-timeout=10s \
  --health-retries=3 \
  myapp:latest

# Monitor health status
podman ps --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}"
```

### Logging and Metrics

**Centralized Logging**
```bash
# Configure JSON logging
podman run -d --name app \
  --log-driver=journald \
  --log-opt tag="{{.Name}}" \
  myapp:latest

# View structured logs
podman logs --since=1h --follow app | jq '.'
```

**System Metrics Collection**
```bash
#!/bin/bash
# metrics_collector.sh - Collect M1 Mac container metrics

collect_metrics() {
    local output_file="metrics_$(date +%Y%m%d_%H%M%S).json"
    
    {
        echo "{"
        echo "  \"timestamp\": \"$(date -Iseconds)\","
        echo "  \"system\": {"
        echo "    \"architecture\": \"$(uname -m)\","
        echo "    \"cpu_cores\": $(sysctl -n hw.ncpu),"
        echo "    \"memory_gb\": $(( $(sysctl -n hw.memsize) / 1024 / 1024 / 1024 ))"
        echo "  },"
        echo "  \"containers\": ["
        
        podman ps --format json | jq -c '.' | while read -r container; do
            name=$(echo "$container" | jq -r '.Names[0]')
            stats=$(podman stats --no-stream --format json "$name")
            echo "    $stats,"
        done | sed '$ s/,$//'
        
        echo "  ]"
        echo "}"
    } > "$output_file"
    
    echo "Metrics saved to $output_file"
}
```

## Operational Best Practices

### Backup and Recovery

**Automated Backup Strategy**
```bash
#!/bin/bash
# backup_containers.sh - Automated container backup for Apple Silicon

backup_containers() {
    local backup_dir="/Users/$USER/container-backups/$(date +%Y%m%d)"
    mkdir -p "$backup_dir"
    
    # Backup container configurations
    podman ps -a --format json > "$backup_dir/containers.json"
    
    # Backup volumes
    podman volume ls --format json > "$backup_dir/volumes.json"
    
    # Backup each volume data
    podman volume ls --format "{{.Name}}" | while read -r volume; do
        if [[ -n "$volume" ]]; then
            podman run --rm \
              -v "$volume":/source:ro \
              -v "$backup_dir":/backup \
              alpine tar czf "/backup/${volume}.tar.gz" -C /source .
        fi
    done
    
    # Create APFS snapshot for system-level backup
    tmutil localsnapshot
    
    echo "Backup completed: $backup_dir"
}
```

### Update Management

**Container Update Strategy**
```bash
#!/bin/bash
# update_containers.sh - Rolling container updates

update_containers() {
    local containers=($(podman ps --format "{{.Names}}"))
    
    for container in "${containers[@]}"; do
        echo "Updating $container..."
        
        # Get current image
        current_image=$(podman inspect "$container" --format "{{.ImageName}}")
        
        # Pull latest image
        podman pull "$current_image"
        
        # Recreate container with new image
        podman stop "$container"
        podman rm "$container"
        
        # Recreate with same configuration (simplified)
        recreate_container "$container" "$current_image"
        
        # Verify health
        sleep 30
        if ! podman healthcheck run "$container"; then
            echo "Health check failed for $container"
            # Rollback logic here
        fi
    done
}
```

### Resource Cleanup

**Automated Cleanup Tasks**
```bash
#!/bin/bash
# cleanup_tasks.sh - Regular maintenance tasks

cleanup_containers() {
    echo "=== Container Cleanup Tasks ==="
    
    # Remove stopped containers older than 7 days
    podman container prune --filter "until=168h" --force
    
    # Remove unused images
    podman image prune --all --filter "until=72h" --force
    
    # Remove unused volumes (be careful!)
    podman volume prune --force
    
    # Remove unused networks
    podman network prune --force
    
    # Clean up system cache
    podman system prune --all --force --volumes
    
    # Report disk space saved
    echo "Cleanup completed"
    df -h "$HOME/.local/share/containers"
}

# Schedule cleanup via cron
# 0 2 * * 0 /path/to/cleanup_tasks.sh
```

## Development Workflow

### Local Development Setup

**Development Environment Configuration**
```yaml
# docker-compose.yml equivalent for Podman
version: '3.8'
services:
  web:
    image: nginx:alpine
    ports:
      - "80:80"
    volumes:
      - ./web:/usr/share/nginx/html:ro
    platform: linux/arm64  # Explicit ARM64
    
  api:
    build:
      context: .
      dockerfile: Dockerfile.arm64
      platforms:
        - linux/arm64
    ports:
      - "3000:3000" 
    environment:
      - NODE_ENV=development
    volumes:
      - ./api:/app
      - /app/node_modules  # Anonymous volume for node_modules
```

**Development Scripts**
```bash
#!/bin/bash
# dev_setup.sh - Development environment setup

setup_dev_environment() {
    echo "Setting up Apple Silicon Mac development environment..."
    
    # Create development network
    podman network create dev-network 2>/dev/null || true
    
    # Start development services
    podman-compose -f docker-compose.dev.yml up -d
    
    # Wait for services to be ready
    wait_for_services
    
    # Run database migrations
    podman exec api-container npm run migrate
    
    # Load test data
    podman exec api-container npm run seed
    
    echo "Development environment ready!"
    echo "Web: http://localhost"
    echo "API: http://localhost:3000"
}

# Hot reload setup for development
setup_hot_reload() {
    # Use bind mounts for live code updates
    podman run -d --name dev-api \
      -v "$(pwd)/api:/app:delegated" \
      -v "/app/node_modules" \
      -p 3000:3000 \
      --env NODE_ENV=development \
      --network dev-network \
      api:dev
}
```

### Testing Strategy

**Container Testing Framework**
```bash
#!/bin/bash
# test_containers.sh - Container testing suite

run_container_tests() {
    echo "=== Container Test Suite ==="
    
    # Unit tests
    run_unit_tests() {
        podman run --rm \
          -v "$(pwd):/app" \
          -w /app \
          node:18-alpine \
          npm test
    }
    
    # Integration tests
    run_integration_tests() {
        # Start test environment
        podman-compose -f docker-compose.test.yml up -d
        
        # Wait for services
        sleep 30
        
        # Run integration tests
        podman run --rm \
          --network test-network \
          -v "$(pwd):/app" \
          -w /app \
          node:18-alpine \
          npm run test:integration
        
        # Cleanup test environment
        podman-compose -f docker-compose.test.yml down
    }
    
    # Performance tests
    run_performance_tests() {
        # Start performance test environment
        podman run -d --name perf-test \
          --cpus="4.0" \
          --memory="2g" \
          app:latest
        
        # Run load tests
        podman run --rm \
          --network container:perf-test \
          loadtest-image \
          --url http://localhost:3000 \
          --requests 1000 \
          --concurrent 10
        
        # Cleanup
        podman stop perf-test
        podman rm perf-test
    }
    
    # Run all test suites
    run_unit_tests
    run_integration_tests
    run_performance_tests
}
```

---

**Summary**: Following these best practices will ensure optimal performance, security, and reliability when running Podman containers on your Apple Silicon Mac. The key is leveraging Apple Silicon's unique advantages while maintaining proper resource management and security practices.

**Next Steps**: Apply these practices during your migration execution, and continue to monitor and tune performance as your workload evolves on the new Podman environment.