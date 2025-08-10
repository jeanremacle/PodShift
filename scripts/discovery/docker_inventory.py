#!/usr/bin/env python3

"""
docker_inventory.py - Comprehensive Docker Resource Inventory Script
Part of PodShift - Seamless Docker to Podman Migration for Apple Silicon

This script uses the Docker API to create detailed JSON inventory of all Docker
resources including containers, images, volumes, networks, and their relationships.
Designed specifically for Apple Silicon Mac migration planning to Podman.
"""

import argparse
import json
import logging
import os
import sys
import time
from datetime import datetime
from pathlib import Path
from typing import Any, Dict, List, Optional, Tuple

try:
    import docker
    from docker.errors import DockerException, APIError, NotFound
except ImportError:
    print("ERROR: Docker Python library not found. Install with: pip3 install docker", file=sys.stderr)
    sys.exit(1)

# Configuration
DEFAULT_OUTPUT_DIR = "."
LOG_LEVEL = logging.INFO

class DockerInventory:
    """Main class for Docker inventory operations."""
    
    def __init__(self, output_dir: str = DEFAULT_OUTPUT_DIR, timestamp: Optional[str] = None, verbose: bool = False):
        self.output_dir = Path(output_dir)
        self.timestamp = timestamp or datetime.now().strftime('%Y%m%d_%H%M%S')
        self.verbose = verbose
        self.logger = self._setup_logging()
        
        # Initialize Docker client
        try:
            self.client = docker.from_env()
            self.client.ping()  # Test connection
            self.logger.info("Successfully connected to Docker daemon")
        except DockerException as e:
            self.logger.error(f"Failed to connect to Docker daemon: {e}")
            raise
        
        # Initialize inventory data structure
        self.inventory = {
            "metadata": {
                "timestamp": self.timestamp,
                "generated_at": datetime.now().isoformat(),
                "script_version": "1.0.0",
                "docker_version": self._get_docker_version(),
                "system_info": self._get_system_info()
            },
            "containers": [],
            "images": [],
            "volumes": [],
            "networks": [],
            "statistics": {
                "total_containers": 0,
                "running_containers": 0,
                "stopped_containers": 0,
                "paused_containers": 0,
                "total_images": 0,
                "dangling_images": 0,
                "total_volumes": 0,
                "unused_volumes": 0,
                "total_networks": 0,
                "custom_networks": 0
            },
            "m1_compatibility": {
                "arm64_images": 0,
                "amd64_images": 0,
                "multi_arch_images": 0,
                "unknown_arch_images": 0,
                "potential_issues": []
            }
        }
    
    def _setup_logging(self) -> logging.Logger:
        """Set up logging configuration."""
        logger = logging.getLogger('docker_inventory')
        logger.setLevel(LOG_LEVEL if not self.verbose else logging.DEBUG)
        
        # Create console handler
        handler = logging.StreamHandler()
        handler.setLevel(LOG_LEVEL if not self.verbose else logging.DEBUG)
        
        # Create formatter
        formatter = logging.Formatter(
            '[%(asctime)s] [%(levelname)s] [%(name)s] %(message)s',
            datefmt='%Y-%m-%d %H:%M:%S'
        )
        handler.setFormatter(formatter)
        
        logger.addHandler(handler)
        return logger
    
    def _get_docker_version(self) -> Dict[str, Any]:
        """Get Docker version information."""
        try:
            version_info = self.client.version()
            return {
                "version": version_info.get("Version", "Unknown"),
                "api_version": version_info.get("ApiVersion", "Unknown"),
                "go_version": version_info.get("GoVersion", "Unknown"),
                "git_commit": version_info.get("GitCommit", "Unknown"),
                "built": version_info.get("BuildTime", "Unknown"),
                "os": version_info.get("Os", "Unknown"),
                "arch": version_info.get("Arch", "Unknown")
            }
        except Exception as e:
            self.logger.warning(f"Could not get Docker version: {e}")
            return {"error": str(e)}
    
    def _get_system_info(self) -> Dict[str, Any]:
        """Get Docker system information."""
        try:
            info = self.client.info()
            return {
                "containers": info.get("Containers", 0),
                "containers_running": info.get("ContainersRunning", 0),
                "containers_paused": info.get("ContainersPaused", 0),
                "containers_stopped": info.get("ContainersStopped", 0),
                "images": info.get("Images", 0),
                "server_version": info.get("ServerVersion", "Unknown"),
                "storage_driver": info.get("Driver", "Unknown"),
                "logging_driver": info.get("LoggingDriver", "Unknown"),
                "cgroup_driver": info.get("CgroupDriver", "Unknown"),
                "kernel_version": info.get("KernelVersion", "Unknown"),
                "operating_system": info.get("OperatingSystem", "Unknown"),
                "architecture": info.get("Architecture", "Unknown"),
                "ncpu": info.get("NCPU", 0),
                "mem_total": info.get("MemTotal", 0),
                "docker_root_dir": info.get("DockerRootDir", "Unknown")
            }
        except Exception as e:
            self.logger.warning(f"Could not get Docker system info: {e}")
            return {"error": str(e)}
    
    def _safe_get_stats(self, container) -> Optional[Dict[str, Any]]:
        """Safely get container statistics."""
        try:
            if container.status != 'running':
                return None
            
            # Get one-shot stats (non-streaming)
            stats = container.stats(stream=False, decode=True)
            
            # Calculate CPU percentage
            cpu_usage = 0
            if 'cpu_stats' in stats and 'precpu_stats' in stats:
                cpu_stats = stats['cpu_stats']
                precpu_stats = stats['precpu_stats']
                
                cpu_delta = cpu_stats.get('cpu_usage', {}).get('total_usage', 0) - \
                           precpu_stats.get('cpu_usage', {}).get('total_usage', 0)
                system_delta = cpu_stats.get('system_cpu_usage', 0) - \
                              precpu_stats.get('system_cpu_usage', 0)
                
                if system_delta > 0:
                    cpu_usage = (cpu_delta / system_delta) * 100
            
            # Get memory usage
            memory_stats = stats.get('memory_stats', {})
            memory_usage = memory_stats.get('usage', 0)
            memory_limit = memory_stats.get('limit', 0)
            memory_percent = (memory_usage / memory_limit * 100) if memory_limit > 0 else 0
            
            # Get network I/O
            networks = stats.get('networks', {})
            network_rx = sum(net.get('rx_bytes', 0) for net in networks.values())
            network_tx = sum(net.get('tx_bytes', 0) for net in networks.values())
            
            # Get block I/O
            blkio_stats = stats.get('blkio_stats', {})
            io_read = sum(item.get('value', 0) for item in blkio_stats.get('io_service_bytes_recursive', []) if item.get('op') == 'Read')
            io_write = sum(item.get('value', 0) for item in blkio_stats.get('io_service_bytes_recursive', []) if item.get('op') == 'Write')
            
            return {
                "cpu_percent": round(cpu_usage, 2),
                "memory_usage": memory_usage,
                "memory_limit": memory_limit,
                "memory_percent": round(memory_percent, 2),
                "network_rx_bytes": network_rx,
                "network_tx_bytes": network_tx,
                "block_read_bytes": io_read,
                "block_write_bytes": io_write,
                "pids": stats.get('pids_stats', {}).get('current', 0)
            }
        except Exception as e:
            self.logger.debug(f"Could not get stats for container: {e}")
            return None
    
    def _analyze_image_architecture(self, image) -> Tuple[str, List[str]]:
        """Analyze image architecture for M1 compatibility."""
        try:
            # Get image manifest/inspect info
            inspect_data = image.attrs
            architecture = inspect_data.get('Architecture', 'unknown')
            
            # Check for multi-architecture manifest
            platforms = []
            if 'RepoDigests' in inspect_data:
                # This is a simplification - in reality, you'd need to inspect the manifest
                platforms.append(architecture)
            else:
                platforms.append(architecture)
            
            return architecture, platforms
        except Exception as e:
            self.logger.debug(f"Could not analyze image architecture: {e}")
            return 'unknown', []
    
    def discover_containers(self) -> None:
        """Discover and analyze all Docker containers."""
        self.logger.info("Discovering Docker containers...")
        
        try:
            containers = self.client.containers.list(all=True)
            self.logger.info(f"Found {len(containers)} containers")
            
            for container in containers:
                try:
                    # Get container details
                    container_info = {
                        "id": container.short_id,
                        "full_id": container.id,
                        "name": container.name,
                        "image": container.image.tags[0] if container.image.tags else container.image.id,
                        "image_id": container.image.short_id,
                        "status": container.status,
                        "created": container.attrs['Created'],
                        "started_at": container.attrs['State'].get('StartedAt'),
                        "finished_at": container.attrs['State'].get('FinishedAt'),
                        "exit_code": container.attrs['State'].get('ExitCode'),
                        "restart_count": container.attrs['RestartCount'],
                        "platform": container.attrs.get('Platform', 'unknown')
                    }
                    
                    # Get container configuration
                    config = container.attrs['Config']
                    container_info['config'] = {
                        "hostname": config.get('Hostname'),
                        "user": config.get('User'),
                        "exposed_ports": list(config.get('ExposedPorts', {}).keys()),
                        "environment": config.get('Env', []),
                        "command": config.get('Cmd'),
                        "entrypoint": config.get('Entrypoint'),
                        "working_dir": config.get('WorkingDir'),
                        "labels": config.get('Labels', {}),
                        "stop_signal": config.get('StopSignal'),
                        "shell": config.get('Shell')
                    }
                    
                    # Get host configuration
                    host_config = container.attrs['HostConfig']
                    container_info['host_config'] = {
                        "port_bindings": host_config.get('PortBindings', {}),
                        "binds": host_config.get('Binds', []),
                        "volumes_from": host_config.get('VolumesFrom', []),
                        "network_mode": host_config.get('NetworkMode'),
                        "restart_policy": host_config.get('RestartPolicy', {}),
                        "memory": host_config.get('Memory', 0),
                        "memory_swap": host_config.get('MemorySwap', 0),
                        "cpu_shares": host_config.get('CpuShares', 0),
                        "cpu_period": host_config.get('CpuPeriod', 0),
                        "cpu_quota": host_config.get('CpuQuota', 0),
                        "cpuset_cpus": host_config.get('CpusetCpus'),
                        "privileged": host_config.get('Privileged', False),
                        "pid_mode": host_config.get('PidMode'),
                        "ipc_mode": host_config.get('IpcMode'),
                        "security_opt": host_config.get('SecurityOpt', []),
                        "cap_add": host_config.get('CapAdd', []),
                        "cap_drop": host_config.get('CapDrop', [])
                    }
                    
                    # Get network settings
                    network_settings = container.attrs['NetworkSettings']
                    container_info['network_settings'] = {
                        "networks": network_settings.get('Networks', {}),
                        "ports": network_settings.get('Ports', {}),
                        "ip_address": network_settings.get('IPAddress'),
                        "gateway": network_settings.get('Gateway'),
                        "bridge": network_settings.get('Bridge'),
                        "sandbox_id": network_settings.get('SandboxID'),
                        "hairpin_mode": network_settings.get('HairpinMode'),
                        "link_local_ipv6_address": network_settings.get('LinkLocalIPv6Address'),
                        "link_local_ipv6_prefix_len": network_settings.get('LinkLocalIPv6PrefixLen')
                    }
                    
                    # Get mounts information
                    mounts = container.attrs.get('Mounts', [])
                    container_info['mounts'] = []
                    for mount in mounts:
                        mount_info = {
                            "type": mount.get('Type'),
                            "source": mount.get('Source'),
                            "destination": mount.get('Destination'),
                            "mode": mount.get('Mode'),
                            "rw": mount.get('RW', True),
                            "propagation": mount.get('Propagation'),
                            "name": mount.get('Name'),
                            "driver": mount.get('Driver')
                        }
                        container_info['mounts'].append(mount_info)
                    
                    # Get resource usage statistics (for running containers)
                    container_info['stats'] = self._safe_get_stats(container)
                    
                    # Analyze for M1 compatibility issues
                    container_info['m1_compatibility'] = self._analyze_container_m1_compatibility(container_info)
                    
                    self.inventory['containers'].append(container_info)
                    
                    # Update statistics
                    if container.status == 'running':
                        self.inventory['statistics']['running_containers'] += 1
                    elif container.status == 'exited':
                        self.inventory['statistics']['stopped_containers'] += 1
                    elif container.status == 'paused':
                        self.inventory['statistics']['paused_containers'] += 1
                    
                except Exception as e:
                    self.logger.error(f"Error processing container {container.name}: {e}")
                    continue
            
            self.inventory['statistics']['total_containers'] = len(containers)
            self.logger.info(f"Successfully processed {len(self.inventory['containers'])} containers")
            
        except Exception as e:
            self.logger.error(f"Error discovering containers: {e}")
            raise
    
    def _analyze_container_m1_compatibility(self, container_info: Dict[str, Any]) -> Dict[str, Any]:
        """Analyze container for M1 Mac compatibility issues."""
        issues = []
        compatibility_score = 100  # Start with perfect score
        
        # Check image architecture
        platform = container_info.get('platform', 'unknown')
        if 'linux/amd64' in platform:
            issues.append("Container uses AMD64 architecture, may run slower on M1 via emulation")
            compatibility_score -= 20
        
        # Check for privileged mode
        if container_info.get('host_config', {}).get('privileged', False):
            issues.append("Container runs in privileged mode, may have compatibility issues")
            compatibility_score -= 10
        
        # Check for specific volume mounts that might be problematic
        for mount in container_info.get('mounts', []):
            source = mount.get('source', '')
            if '/var/run/docker.sock' in source:
                issues.append("Container mounts Docker socket, will need Podman socket adaptation")
                compatibility_score -= 15
            elif source.startswith('/sys') or source.startswith('/proc'):
                issues.append(f"Container mounts system directory: {source}")
                compatibility_score -= 5
        
        # Check for network host mode
        network_mode = container_info.get('host_config', {}).get('network_mode')
        if network_mode == 'host':
            issues.append("Container uses host networking, may need adjustment for Podman")
            compatibility_score -= 10
        
        # Check for specific capabilities
        cap_add = container_info.get('host_config', {}).get('cap_add', [])
        if 'SYS_ADMIN' in cap_add or 'ALL' in cap_add:
            issues.append("Container requires elevated capabilities")
            compatibility_score -= 10
        
        return {
            "compatibility_score": max(0, compatibility_score),
            "issues": issues,
            "recommended_actions": self._get_compatibility_recommendations(issues)
        }
    
    def _get_compatibility_recommendations(self, issues: List[str]) -> List[str]:
        """Get recommendations based on compatibility issues."""
        recommendations = []
        
        for issue in issues:
            if "AMD64 architecture" in issue:
                recommendations.append("Consider finding ARM64 version of the image or building multi-arch image")
            elif "privileged mode" in issue:
                recommendations.append("Review if privileged mode is necessary, consider using specific capabilities instead")
            elif "Docker socket" in issue:
                recommendations.append("Replace Docker socket mount with Podman socket: /run/user/$(id -u)/podman/podman.sock")
            elif "host networking" in issue:
                recommendations.append("Test container with Podman's host networking or use port mapping")
            elif "elevated capabilities" in issue:
                recommendations.append("Review and minimize required capabilities for security")
        
        return recommendations
    
    def discover_images(self) -> None:
        """Discover and analyze all Docker images."""
        self.logger.info("Discovering Docker images...")
        
        try:
            images = self.client.images.list(all=True)
            self.logger.info(f"Found {len(images)} images")
            
            for image in images:
                try:
                    # Get image details
                    image_info = {
                        "id": image.short_id,
                        "full_id": image.id,
                        "tags": image.tags,
                        "created": image.attrs['Created'],
                        "size": image.attrs['Size'],
                        "virtual_size": image.attrs.get('VirtualSize', image.attrs['Size']),
                        "architecture": image.attrs.get('Architecture', 'unknown'),
                        "os": image.attrs.get('Os', 'unknown'),
                        "parent": image.attrs.get('Parent', ''),
                        "docker_version": image.attrs.get('DockerVersion', ''),
                        "author": image.attrs.get('Author', ''),
                        "comment": image.attrs.get('Comment', '')
                    }
                    
                    # Get image configuration
                    config = image.attrs.get('Config', {})
                    image_info['config'] = {
                        "hostname": config.get('Hostname'),
                        "user": config.get('User'),
                        "exposed_ports": list(config.get('ExposedPorts', {}).keys()),
                        "environment": config.get('Env', []),
                        "command": config.get('Cmd'),
                        "entrypoint": config.get('Entrypoint'),
                        "working_dir": config.get('WorkingDir'),
                        "labels": config.get('Labels', {}),
                        "stop_signal": config.get('StopSignal'),
                        "shell": config.get('Shell'),
                        "volumes": list(config.get('Volumes', {}).keys())
                    }
                    
                    # Get history/layers
                    try:
                        history = image.history()
                        image_info['layers'] = len(history)
                        image_info['history'] = history[:5]  # First 5 layers for brevity
                    except Exception as e:
                        self.logger.debug(f"Could not get image history: {e}")
                        image_info['layers'] = 0
                        image_info['history'] = []
                    
                    # Analyze architecture for M1 compatibility
                    arch, platforms = self._analyze_image_architecture(image)
                    image_info['m1_compatibility'] = {
                        "architecture": arch,
                        "platforms": platforms,
                        "native_arm64": arch == 'arm64',
                        "emulation_required": arch == 'amd64',
                        "multi_arch": len(platforms) > 1
                    }
                    
                    # Update M1 compatibility statistics
                    if arch == 'arm64':
                        self.inventory['m1_compatibility']['arm64_images'] += 1
                    elif arch == 'amd64':
                        self.inventory['m1_compatibility']['amd64_images'] += 1
                    elif len(platforms) > 1:
                        self.inventory['m1_compatibility']['multi_arch_images'] += 1
                    else:
                        self.inventory['m1_compatibility']['unknown_arch_images'] += 1
                    
                    # Check if image is dangling
                    image_info['dangling'] = len(image.tags) == 0
                    if image_info['dangling']:
                        self.inventory['statistics']['dangling_images'] += 1
                    
                    self.inventory['images'].append(image_info)
                    
                except Exception as e:
                    self.logger.error(f"Error processing image {image.short_id}: {e}")
                    continue
            
            self.inventory['statistics']['total_images'] = len(images)
            self.logger.info(f"Successfully processed {len(self.inventory['images'])} images")
            
        except Exception as e:
            self.logger.error(f"Error discovering images: {e}")
            raise
    
    def discover_volumes(self) -> None:
        """Discover and analyze all Docker volumes."""
        self.logger.info("Discovering Docker volumes...")
        
        try:
            volumes = self.client.volumes.list()
            self.logger.info(f"Found {len(volumes)} volumes")
            
            for volume in volumes:
                try:
                    # Get volume details
                    volume_info = {
                        "name": volume.name,
                        "short_id": volume.short_id,
                        "created": volume.attrs['CreatedAt'],
                        "driver": volume.attrs['Driver'],
                        "mountpoint": volume.attrs['Mountpoint'],
                        "scope": volume.attrs['Scope'],
                        "labels": volume.attrs.get('Labels') or {},
                        "options": volume.attrs.get('Options') or {}
                    }
                    
                    # Check if volume is in use
                    try:
                        containers_using = []
                        for container in self.client.containers.list(all=True):
                            for mount in container.attrs.get('Mounts', []):
                                if mount.get('Name') == volume.name:
                                    containers_using.append({
                                        "container_name": container.name,
                                        "container_id": container.short_id,
                                        "mount_destination": mount.get('Destination'),
                                        "read_write": mount.get('RW', True)
                                    })
                        
                        volume_info['used_by'] = containers_using
                        volume_info['in_use'] = len(containers_using) > 0
                        
                        if not volume_info['in_use']:
                            self.inventory['statistics']['unused_volumes'] += 1
                    
                    except Exception as e:
                        self.logger.debug(f"Could not check volume usage: {e}")
                        volume_info['used_by'] = []
                        volume_info['in_use'] = False
                    
                    # Get volume size if possible
                    try:
                        volume_path = Path(volume.attrs['Mountpoint'])
                        if volume_path.exists():
                            # Calculate directory size
                            total_size = sum(f.stat().st_size for f in volume_path.rglob('*') if f.is_file())
                            volume_info['size_bytes'] = total_size
                        else:
                            volume_info['size_bytes'] = 0
                    except Exception as e:
                        self.logger.debug(f"Could not calculate volume size: {e}")
                        volume_info['size_bytes'] = 0
                    
                    self.inventory['volumes'].append(volume_info)
                    
                except Exception as e:
                    self.logger.error(f"Error processing volume {volume.name}: {e}")
                    continue
            
            self.inventory['statistics']['total_volumes'] = len(volumes)
            self.logger.info(f"Successfully processed {len(self.inventory['volumes'])} volumes")
            
        except Exception as e:
            self.logger.error(f"Error discovering volumes: {e}")
            raise
    
    def discover_networks(self) -> None:
        """Discover and analyze all Docker networks."""
        self.logger.info("Discovering Docker networks...")
        
        try:
            networks = self.client.networks.list()
            self.logger.info(f"Found {len(networks)} networks")
            
            for network in networks:
                try:
                    # Get network details
                    network_info = {
                        "id": network.short_id,
                        "full_id": network.id,
                        "name": network.name,
                        "created": network.attrs['Created'],
                        "scope": network.attrs['Scope'],
                        "driver": network.attrs['Driver'],
                        "enable_ipv6": network.attrs.get('EnableIPv6', False),
                        "internal": network.attrs.get('Internal', False),
                        "attachable": network.attrs.get('Attachable', False),
                        "ingress": network.attrs.get('Ingress', False),
                        "config_from": network.attrs.get('ConfigFrom', {}),
                        "config_only": network.attrs.get('ConfigOnly', False),
                        "labels": network.attrs.get('Labels') or {}
                    }
                    
                    # Get IPAM configuration
                    ipam = network.attrs.get('IPAM', {})
                    network_info['ipam'] = {
                        "driver": ipam.get('Driver'),
                        "config": ipam.get('Config', []),
                        "options": ipam.get('Options') or {}
                    }
                    
                    # Get containers connected to this network
                    containers = network.attrs.get('Containers', {})
                    network_info['connected_containers'] = []
                    for container_id, container_info in containers.items():
                        network_info['connected_containers'].append({
                            "container_id": container_id[:12],  # Short ID
                            "name": container_info.get('Name'),
                            "endpoint_id": container_info.get('EndpointID'),
                            "mac_address": container_info.get('MacAddress'),
                            "ipv4_address": container_info.get('IPv4Address'),
                            "ipv6_address": container_info.get('IPv6Address')
                        })
                    
                    # Get network options
                    network_info['options'] = network.attrs.get('Options') or {}
                    
                    # Check if this is a custom network
                    builtin_networks = ['bridge', 'host', 'none']
                    network_info['is_custom'] = network.name not in builtin_networks
                    if network_info['is_custom']:
                        self.inventory['statistics']['custom_networks'] += 1
                    
                    self.inventory['networks'].append(network_info)
                    
                except Exception as e:
                    self.logger.error(f"Error processing network {network.name}: {e}")
                    continue
            
            self.inventory['statistics']['total_networks'] = len(networks)
            self.logger.info(f"Successfully processed {len(self.inventory['networks'])} networks")
            
        except Exception as e:
            self.logger.error(f"Error discovering networks: {e}")
            raise
    
    def generate_compatibility_analysis(self) -> None:
        """Generate M1 Mac compatibility analysis."""
        self.logger.info("Generating M1 Mac compatibility analysis...")
        
        potential_issues = []
        
        # Analyze images for architecture compatibility
        amd64_images = [img for img in self.inventory['images'] if img.get('architecture') == 'amd64']
        if amd64_images:
            potential_issues.append({
                "category": "Architecture Compatibility",
                "issue": f"Found {len(amd64_images)} AMD64 images that will require emulation on M1 Macs",
                "severity": "medium",
                "affected_images": [img['tags'][0] if img['tags'] else img['id'] for img in amd64_images[:10]],
                "recommendation": "Consider finding ARM64 alternatives or building multi-architecture images"
            })
        
        # Analyze containers for problematic configurations
        privileged_containers = [c for c in self.inventory['containers'] if c.get('host_config', {}).get('privileged', False)]
        if privileged_containers:
            potential_issues.append({
                "category": "Security Configuration",
                "issue": f"Found {len(privileged_containers)} containers running in privileged mode",
                "severity": "high",
                "affected_containers": [c['name'] for c in privileged_containers],
                "recommendation": "Review privileged requirements and use specific capabilities instead"
            })
        
        # Check for Docker socket mounts
        docker_socket_containers = []
        for container in self.inventory['containers']:
            for mount in container.get('mounts', []):
                if '/var/run/docker.sock' in mount.get('source', ''):
                    docker_socket_containers.append(container['name'])
        
        if docker_socket_containers:
            potential_issues.append({
                "category": "Socket Mounting",
                "issue": f"Found {len(docker_socket_containers)} containers mounting Docker socket",
                "severity": "high",
                "affected_containers": docker_socket_containers,
                "recommendation": "Replace with Podman socket: /run/user/$(id -u)/podman/podman.sock"
            })
        
        # Check for host networking
        host_network_containers = [c for c in self.inventory['containers'] if c.get('host_config', {}).get('network_mode') == 'host']
        if host_network_containers:
            potential_issues.append({
                "category": "Network Configuration",
                "issue": f"Found {len(host_network_containers)} containers using host networking",
                "severity": "medium",
                "affected_containers": [c['name'] for c in host_network_containers],
                "recommendation": "Test with Podman host networking or convert to port mapping"
            })
        
        self.inventory['m1_compatibility']['potential_issues'] = potential_issues
        
        # Calculate overall compatibility score
        total_score = 0
        total_containers = len(self.inventory['containers'])
        
        if total_containers > 0:
            for container in self.inventory['containers']:
                compat = container.get('m1_compatibility', {})
                total_score += compat.get('compatibility_score', 100)
            
            average_score = total_score / total_containers
        else:
            average_score = 100
        
        self.inventory['m1_compatibility']['overall_compatibility_score'] = round(average_score, 2)
        
        self.logger.info(f"Compatibility analysis complete. Overall score: {average_score:.2f}%")
    
    def save_inventory(self) -> str:
        """Save inventory to JSON file."""
        output_file = self.output_dir / f"docker_inventory_{self.timestamp}.json"
        
        try:
            with open(output_file, 'w') as f:
                json.dump(self.inventory, f, indent=2, default=str)
            
            self.logger.info(f"Inventory saved to {output_file}")
            return str(output_file)
            
        except Exception as e:
            self.logger.error(f"Error saving inventory: {e}")
            raise
    
    def run_full_discovery(self) -> str:
        """Run complete Docker discovery and save results."""
        self.logger.info("Starting full Docker discovery...")
        
        start_time = time.time()
        
        try:
            # Run all discovery operations
            self.discover_containers()
            self.discover_images()
            self.discover_volumes()
            self.discover_networks()
            
            # Generate compatibility analysis
            self.generate_compatibility_analysis()
            
            # Save results
            output_file = self.save_inventory()
            
            elapsed_time = time.time() - start_time
            self.logger.info(f"Full discovery completed in {elapsed_time:.2f} seconds")
            
            return output_file
            
        except Exception as e:
            self.logger.error(f"Discovery failed: {e}")
            raise


def main():
    """Main entry point."""
    parser = argparse.ArgumentParser(
        description="Docker Inventory Script for PodShift Migration",
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog="""
Examples:
  %(prog)s --verbose
  %(prog)s --output-dir /tmp --timestamp 20240101_120000
  %(prog)s --containers-only
        """
    )
    
    parser.add_argument(
        '--output-dir',
        default=DEFAULT_OUTPUT_DIR,
        help=f'Output directory for inventory files (default: {DEFAULT_OUTPUT_DIR})'
    )
    
    parser.add_argument(
        '--timestamp',
        help='Custom timestamp for output files (default: current time)'
    )
    
    parser.add_argument(
        '-v', '--verbose',
        action='store_true',
        help='Enable verbose output'
    )
    
    parser.add_argument(
        '--containers-only',
        action='store_true',
        help='Discover containers only (skip images, volumes, networks)'
    )
    
    parser.add_argument(
        '--images-only',
        action='store_true',
        help='Discover images only'
    )
    
    parser.add_argument(
        '--volumes-only',
        action='store_true',
        help='Discover volumes only'
    )
    
    parser.add_argument(
        '--networks-only',
        action='store_true',
        help='Discover networks only'
    )
    
    args = parser.parse_args()
    
    try:
        # Initialize inventory
        inventory = DockerInventory(
            output_dir=args.output_dir,
            timestamp=args.timestamp,
            verbose=args.verbose
        )
        
        # Run specific discovery operations
        if args.containers_only:
            inventory.discover_containers()
        elif args.images_only:
            inventory.discover_images()
        elif args.volumes_only:
            inventory.discover_volumes()
        elif args.networks_only:
            inventory.discover_networks()
        else:
            # Run full discovery
            output_file = inventory.run_full_discovery()
            print(f"\nDocker inventory completed successfully!")
            print(f"Results saved to: {output_file}")
            
            # Print summary statistics
            stats = inventory.inventory['statistics']
            print(f"\nSummary:")
            print(f"  Containers: {stats['total_containers']} ({stats['running_containers']} running)")
            print(f"  Images: {stats['total_images']} ({stats['dangling_images']} dangling)")
            print(f"  Volumes: {stats['total_volumes']} ({stats['unused_volumes']} unused)")
            print(f"  Networks: {stats['total_networks']} ({stats['custom_networks']} custom)")
            
            # Print M1 compatibility summary
            m1_compat = inventory.inventory['m1_compatibility']
            print(f"\nM1 Compatibility:")
            print(f"  Overall Score: {m1_compat.get('overall_compatibility_score', 'N/A')}%")
            print(f"  ARM64 Images: {m1_compat['arm64_images']}")
            print(f"  AMD64 Images: {m1_compat['amd64_images']}")
            print(f"  Potential Issues: {len(m1_compat['potential_issues'])}")
            
            return 0
        
        # Save partial results if only specific discovery was run
        if args.containers_only or args.images_only or args.volumes_only or args.networks_only:
            output_file = inventory.save_inventory()
            print(f"Partial inventory saved to: {output_file}")
            return 0
            
    except KeyboardInterrupt:
        print("\nDiscovery interrupted by user")
        return 1
    except DockerException as e:
        print(f"Docker error: {e}", file=sys.stderr)
        return 1
    except Exception as e:
        print(f"Unexpected error: {e}", file=sys.stderr)
        return 1


if __name__ == '__main__':
    sys.exit(main())