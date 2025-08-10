#!/usr/bin/env python3

"""
dependency_mapper.py - Container Dependency Mapping Script
Part of PodShift - Seamless Docker to Podman Migration for Apple Silicon

This script analyzes container linking, networking dependencies, Docker Compose
service relationships, shared volumes, and startup order requirements to
generate dependency graphs for migration sequencing.
"""

import argparse
import json
import logging
import os
import sys
import yaml
from collections import defaultdict, deque
from datetime import datetime
from pathlib import Path
from typing import Any, Dict, List, Optional, Set, Tuple

try:
    import docker
    from docker.errors import DockerException, APIError, NotFound
except ImportError:
    print("ERROR: Docker Python library not found. Install with: pip3 install docker", file=sys.stderr)
    sys.exit(1)

# Configuration
DEFAULT_OUTPUT_DIR = "."
LOG_LEVEL = logging.INFO

class DependencyMapper:
    """Main class for analyzing container dependencies."""
    
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
        
        # Initialize dependency data structures
        self.dependencies = {
            "metadata": {
                "timestamp": self.timestamp,
                "generated_at": datetime.now().isoformat(),
                "script_version": "1.0.0"
            },
            "containers": {},
            "networks": {},
            "volumes": {},
            "compose_services": {},
            "dependency_graph": {
                "nodes": [],
                "edges": [],
                "cycles": [],
                "startup_order": []
            },
            "migration_sequence": {
                "phases": [],
                "parallel_groups": [],
                "sequential_order": []
            }
        }
        
        # Internal tracking
        self.container_dependencies = defaultdict(set)
        self.container_dependents = defaultdict(set)
        self.volume_dependencies = defaultdict(set)
        self.network_dependencies = defaultdict(set)
        self.compose_dependencies = defaultdict(set)
    
    def _setup_logging(self) -> logging.Logger:
        """Set up logging configuration."""
        logger = logging.getLogger('dependency_mapper')
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
    
    def analyze_container_dependencies(self) -> None:
        """Analyze dependencies between Docker containers."""
        self.logger.info("Analyzing container dependencies...")
        
        try:
            containers = self.client.containers.list(all=True)
            self.logger.info(f"Found {len(containers)} containers to analyze")
            
            for container in containers:
                container_name = container.name
                container_id = container.short_id
                
                # Initialize container info
                self.dependencies["containers"][container_name] = {
                    "id": container_id,
                    "status": container.status,
                    "depends_on": [],
                    "depended_by": [],
                    "network_dependencies": [],
                    "volume_dependencies": [],
                    "link_dependencies": [],
                    "environment_dependencies": [],
                    "startup_order": 0,
                    "migration_priority": "normal"
                }
                
                try:
                    # Analyze network dependencies
                    self._analyze_network_dependencies(container, container_name)
                    
                    # Analyze volume dependencies
                    self._analyze_volume_dependencies(container, container_name)
                    
                    # Analyze environment variable dependencies
                    self._analyze_environment_dependencies(container, container_name)
                    
                    # Analyze container links (legacy)
                    self._analyze_container_links(container, container_name)
                    
                    # Analyze depends_on from labels
                    self._analyze_depends_on_labels(container, container_name)
                    
                except Exception as e:
                    self.logger.error(f"Error analyzing container {container_name}: {e}")
                    continue
            
            self.logger.info(f"Analyzed dependencies for {len(self.dependencies['containers'])} containers")
            
        except Exception as e:
            self.logger.error(f"Error analyzing container dependencies: {e}")
            raise
    
    def _analyze_network_dependencies(self, container, container_name: str) -> None:
        """Analyze network-based dependencies between containers."""
        try:
            network_settings = container.attrs['NetworkSettings']
            networks = network_settings.get('Networks', {})
            
            for network_name, network_config in networks.items():
                if network_name == 'bridge':
                    continue  # Skip default bridge network
                
                # Find other containers on the same network
                try:
                    network = self.client.networks.get(network_name)
                    connected_containers = network.attrs.get('Containers', {})
                    
                    for connected_id, connected_info in connected_containers.items():
                        connected_name = connected_info.get('Name')
                        if connected_name and connected_name != container_name:
                            self.network_dependencies[container_name].add(connected_name)
                            self.dependencies["containers"][container_name]["network_dependencies"].append({
                                "container": connected_name,
                                "network": network_name,
                                "type": "network_shared"
                            })
                
                except Exception as e:
                    self.logger.debug(f"Could not analyze network {network_name}: {e}")
        
        except Exception as e:
            self.logger.debug(f"Could not analyze network dependencies for {container_name}: {e}")
    
    def _analyze_volume_dependencies(self, container, container_name: str) -> None:
        """Analyze volume-based dependencies between containers."""
        try:
            mounts = container.attrs.get('Mounts', [])
            
            for mount in mounts:
                mount_type = mount.get('Type')
                source = mount.get('Source')
                destination = mount.get('Destination')
                
                if mount_type == 'volume':
                    volume_name = mount.get('Name')
                    if volume_name:
                        # Find other containers using the same volume
                        for other_container in self.client.containers.list(all=True):
                            if other_container.name == container_name:
                                continue
                            
                            other_mounts = other_container.attrs.get('Mounts', [])
                            for other_mount in other_mounts:
                                if (other_mount.get('Type') == 'volume' and 
                                    other_mount.get('Name') == volume_name):
                                    
                                    self.volume_dependencies[container_name].add(other_container.name)
                                    self.dependencies["containers"][container_name]["volume_dependencies"].append({
                                        "container": other_container.name,
                                        "volume": volume_name,
                                        "type": "volume_shared",
                                        "source_path": destination,
                                        "target_path": other_mount.get('Destination')
                                    })
                
                elif mount_type == 'bind':
                    # Check for bind mount dependencies (shared host directories)
                    for other_container in self.client.containers.list(all=True):
                        if other_container.name == container_name:
                            continue
                        
                        other_mounts = other_container.attrs.get('Mounts', [])
                        for other_mount in other_mounts:
                            if (other_mount.get('Type') == 'bind' and 
                                other_mount.get('Source') == source):
                                
                                self.volume_dependencies[container_name].add(other_container.name)
                                self.dependencies["containers"][container_name]["volume_dependencies"].append({
                                    "container": other_container.name,
                                    "bind_source": source,
                                    "type": "bind_shared",
                                    "source_path": destination,
                                    "target_path": other_mount.get('Destination')
                                })
        
        except Exception as e:
            self.logger.debug(f"Could not analyze volume dependencies for {container_name}: {e}")
    
    def _analyze_environment_dependencies(self, container, container_name: str) -> None:
        """Analyze environment variable-based dependencies."""
        try:
            config = container.attrs.get('Config', {})
            env_vars = config.get('Env', [])
            
            for env_var in env_vars:
                if '=' not in env_var:
                    continue
                
                key, value = env_var.split('=', 1)
                
                # Look for container references in environment variables
                # Common patterns: container names, service names, hostnames
                for other_container in self.client.containers.list(all=True):
                    if other_container.name == container_name:
                        continue
                    
                    other_name = other_container.name
                    
                    # Check if environment variable references another container
                    if (other_name in value or 
                        other_name.replace('-', '_').upper() in key or
                        other_name.replace('_', '-') in value):
                        
                        self.container_dependencies[container_name].add(other_name)
                        self.dependencies["containers"][container_name]["environment_dependencies"].append({
                            "container": other_name,
                            "environment_variable": key,
                            "value": value,
                            "type": "env_reference"
                        })
        
        except Exception as e:
            self.logger.debug(f"Could not analyze environment dependencies for {container_name}: {e}")
    
    def _analyze_container_links(self, container, container_name: str) -> None:
        """Analyze legacy container links."""
        try:
            host_config = container.attrs.get('HostConfig', {})
            links = host_config.get('Links', [])
            
            for link in links:
                # Link format: /source_container:/target_container/alias
                if ':' in link:
                    parts = link.split(':')
                    if len(parts) >= 2:
                        source_container = parts[0].lstrip('/')
                        
                        self.container_dependencies[container_name].add(source_container)
                        self.dependencies["containers"][container_name]["link_dependencies"].append({
                            "container": source_container,
                            "link": link,
                            "type": "container_link"
                        })
        
        except Exception as e:
            self.logger.debug(f"Could not analyze container links for {container_name}: {e}")
    
    def _analyze_depends_on_labels(self, container, container_name: str) -> None:
        """Analyze depends_on information from container labels."""
        try:
            config = container.attrs.get('Config', {})
            labels = config.get('Labels', {})
            
            # Check for common dependency labels
            dependency_labels = [
                'com.docker.compose.depends_on',
                'com.docker.stack.depends_on',
                'depends_on',
                'requires'
            ]
            
            for label_key in dependency_labels:
                if label_key in labels:
                    depends_on = labels[label_key]
                    
                    # Parse dependency list (could be JSON, comma-separated, etc.)
                    dependencies = []
                    try:
                        # Try JSON format first
                        dependencies = json.loads(depends_on)
                        if not isinstance(dependencies, list):
                            dependencies = [dependencies]
                    except (json.JSONDecodeError, TypeError):
                        # Try comma-separated format
                        dependencies = [dep.strip() for dep in depends_on.split(',')]
                    
                    for dep in dependencies:
                        if dep and dep != container_name:
                            self.container_dependencies[container_name].add(dep)
                            self.dependencies["containers"][container_name]["depends_on"].append({
                                "container": dep,
                                "label": label_key,
                                "type": "label_dependency"
                            })
        
        except Exception as e:
            self.logger.debug(f"Could not analyze label dependencies for {container_name}: {e}")
    
    def analyze_compose_dependencies(self, compose_files: Optional[List[str]] = None) -> None:
        """Analyze Docker Compose service dependencies."""
        self.logger.info("Analyzing Docker Compose dependencies...")
        
        if not compose_files:
            # Find compose files in common locations
            compose_files = self._find_compose_files()
        
        if not compose_files:
            self.logger.info("No Docker Compose files found")
            return
        
        for compose_file in compose_files:
            try:
                self._analyze_compose_file(compose_file)
            except Exception as e:
                self.logger.error(f"Error analyzing compose file {compose_file}: {e}")
                continue
        
        self.logger.info(f"Analyzed {len(compose_files)} Docker Compose files")
    
    def _find_compose_files(self) -> List[str]:
        """Find Docker Compose files in common locations."""
        compose_files = []
        search_patterns = [
            "docker-compose.yml",
            "docker-compose.yaml",
            "compose.yml",
            "compose.yaml"
        ]
        
        search_paths = [
            Path.cwd(),
            Path.home(),
            Path.home() / "Documents",
            Path.home() / "Projects",
            Path.home() / "Development"
        ]
        
        for search_path in search_paths:
            if not search_path.exists():
                continue
            
            for pattern in search_patterns:
                for compose_file in search_path.rglob(pattern):
                    if compose_file.is_file():
                        compose_files.append(str(compose_file))
        
        return compose_files
    
    def _analyze_compose_file(self, compose_file: str) -> None:
        """Analyze a specific Docker Compose file."""
        self.logger.debug(f"Analyzing compose file: {compose_file}")
        
        try:
            with open(compose_file, 'r') as f:
                compose_data = yaml.safe_load(f)
            
            if not compose_data or 'services' not in compose_data:
                return
            
            services = compose_data['services']
            compose_name = Path(compose_file).parent.name
            
            self.dependencies["compose_services"][compose_name] = {
                "file_path": compose_file,
                "services": {},
                "networks": compose_data.get('networks', {}),
                "volumes": compose_data.get('volumes', {})
            }
            
            # Analyze each service
            for service_name, service_config in services.items():
                service_info = {
                    "depends_on": [],
                    "links": [],
                    "volumes_from": [],
                    "network_dependencies": [],
                    "volume_dependencies": [],
                    "environment_dependencies": []
                }
                
                # Analyze depends_on
                depends_on = service_config.get('depends_on', [])
                if isinstance(depends_on, dict):
                    depends_on = list(depends_on.keys())
                elif isinstance(depends_on, str):
                    depends_on = [depends_on]
                
                for dep in depends_on:
                    service_info["depends_on"].append(dep)
                    self.compose_dependencies[service_name].add(dep)
                
                # Analyze links
                links = service_config.get('links', [])
                for link in links:
                    if ':' in link:
                        linked_service = link.split(':')[0]
                    else:
                        linked_service = link
                    
                    service_info["links"].append(linked_service)
                    self.compose_dependencies[service_name].add(linked_service)
                
                # Analyze volumes_from
                volumes_from = service_config.get('volumes_from', [])
                for vol_from in volumes_from:
                    service_info["volumes_from"].append(vol_from)
                    self.compose_dependencies[service_name].add(vol_from)
                
                # Analyze shared networks
                networks = service_config.get('networks', [])
                if isinstance(networks, dict):
                    networks = list(networks.keys())
                elif networks is None:
                    networks = []
                
                # Find other services on same networks
                for other_service_name, other_service_config in services.items():
                    if other_service_name == service_name:
                        continue
                    
                    other_networks = other_service_config.get('networks', [])
                    if isinstance(other_networks, dict):
                        other_networks = list(other_networks.keys())
                    elif other_networks is None:
                        other_networks = []
                    
                    # Check for shared networks
                    shared_networks = set(networks) & set(other_networks)
                    if shared_networks:
                        service_info["network_dependencies"].append({
                            "service": other_service_name,
                            "shared_networks": list(shared_networks)
                        })
                
                self.dependencies["compose_services"][compose_name]["services"][service_name] = service_info
        
        except Exception as e:
            self.logger.error(f"Error parsing compose file {compose_file}: {e}")
    
    def build_dependency_graph(self) -> None:
        """Build comprehensive dependency graph."""
        self.logger.info("Building dependency graph...")
        
        # Collect all dependencies
        all_dependencies = defaultdict(set)
        
        # Add container dependencies
        for container, deps in self.container_dependencies.items():
            all_dependencies[container].update(deps)
        
        # Add network dependencies
        for container, deps in self.network_dependencies.items():
            all_dependencies[container].update(deps)
        
        # Add volume dependencies
        for container, deps in self.volume_dependencies.items():
            all_dependencies[container].update(deps)
        
        # Add compose dependencies
        for service, deps in self.compose_dependencies.items():
            all_dependencies[service].update(deps)
        
        # Build graph nodes
        all_nodes = set()
        all_nodes.update(all_dependencies.keys())
        for deps in all_dependencies.values():
            all_nodes.update(deps)
        
        self.dependencies["dependency_graph"]["nodes"] = list(all_nodes)
        
        # Build graph edges
        edges = []
        for source, targets in all_dependencies.items():
            for target in targets:
                edges.append({
                    "from": source,
                    "to": target,
                    "type": "depends_on"
                })
        
        self.dependencies["dependency_graph"]["edges"] = edges
        
        # Detect cycles
        cycles = self._detect_cycles(all_dependencies)
        self.dependencies["dependency_graph"]["cycles"] = cycles
        
        if cycles:
            self.logger.warning(f"Detected {len(cycles)} dependency cycles")
            for i, cycle in enumerate(cycles):
                self.logger.warning(f"  Cycle {i+1}: {' -> '.join(cycle + [cycle[0]])}")
        
        # Calculate startup order
        startup_order = self._calculate_startup_order(all_dependencies)
        self.dependencies["dependency_graph"]["startup_order"] = startup_order
        
        self.logger.info(f"Built dependency graph with {len(all_nodes)} nodes and {len(edges)} edges")
    
    def _detect_cycles(self, dependencies: Dict[str, Set[str]]) -> List[List[str]]:
        """Detect cycles in dependency graph using DFS."""
        cycles = []
        visited = set()
        rec_stack = set()
        path = []
        
        def dfs(node: str) -> bool:
            if node in rec_stack:
                # Found a cycle
                cycle_start = path.index(node)
                cycle = path[cycle_start:] + [node]
                cycles.append(cycle)
                return True
            
            if node in visited:
                return False
            
            visited.add(node)
            rec_stack.add(node)
            path.append(node)
            
            for neighbor in dependencies.get(node, []):
                if dfs(neighbor):
                    pass  # Continue to find all cycles
            
            rec_stack.remove(node)
            path.pop()
            return False
        
        for node in dependencies.keys():
            if node not in visited:
                dfs(node)
        
        return cycles
    
    def _calculate_startup_order(self, dependencies: Dict[str, Set[str]]) -> List[str]:
        """Calculate startup order using topological sort."""
        # Create reverse dependency graph
        in_degree = defaultdict(int)
        graph = defaultdict(list)
        
        all_nodes = set(dependencies.keys())
        for deps in dependencies.values():
            all_nodes.update(deps)
        
        # Initialize in-degrees
        for node in all_nodes:
            in_degree[node] = 0
        
        # Build graph and calculate in-degrees
        for source, targets in dependencies.items():
            for target in targets:
                graph[target].append(source)
                in_degree[source] += 1
        
        # Topological sort using Kahn's algorithm
        queue = deque([node for node in all_nodes if in_degree[node] == 0])
        startup_order = []
        
        while queue:
            node = queue.popleft()
            startup_order.append(node)
            
            for neighbor in graph[node]:
                in_degree[neighbor] -= 1
                if in_degree[neighbor] == 0:
                    queue.append(neighbor)
        
        return startup_order
    
    def generate_migration_sequence(self) -> None:
        """Generate optimized migration sequence."""
        self.logger.info("Generating migration sequence...")
        
        startup_order = self.dependencies["dependency_graph"]["startup_order"]
        cycles = self.dependencies["dependency_graph"]["cycles"]
        
        # Create migration phases
        phases = []
        parallel_groups = []
        sequential_order = []
        
        if not startup_order:
            # If no startup order (due to cycles), create simple sequential order
            all_containers = list(self.dependencies["containers"].keys())
            sequential_order = all_containers
            phases = [{"name": "Phase 1", "containers": all_containers, "parallel": False}]
        else:
            # Group containers by dependency level
            dependency_levels = defaultdict(list)
            processed = set()
            
            for node in startup_order:
                level = 0
                for dep in self.container_dependencies.get(node, []):
                    if dep in processed:
                        # Find the level of the dependency
                        for lvl, containers in dependency_levels.items():
                            if dep in containers:
                                level = max(level, lvl + 1)
                                break
                
                dependency_levels[level].append(node)
                processed.add(node)
            
            # Convert levels to phases
            for level in sorted(dependency_levels.keys()):
                containers = dependency_levels[level]
                phase_name = f"Phase {level + 1}"
                
                phases.append({
                    "name": phase_name,
                    "containers": containers,
                    "parallel": len(containers) > 1,
                    "description": f"Migrate containers with dependency level {level}"
                })
                
                if len(containers) > 1:
                    parallel_groups.append({
                        "phase": level + 1,
                        "containers": containers,
                        "reason": "No interdependencies within group"
                    })
            
            sequential_order = startup_order
        
        # Handle cycles
        if cycles:
            cycle_containers = set()
            for cycle in cycles:
                cycle_containers.update(cycle)
            
            # Create special phase for cyclic dependencies
            if cycle_containers:
                phases.insert(0, {
                    "name": "Phase 0 - Cycle Resolution",
                    "containers": list(cycle_containers),
                    "parallel": False,
                    "description": "Containers with circular dependencies - manual intervention required",
                    "special": True,
                    "cycles": cycles
                })
        
        self.dependencies["migration_sequence"] = {
            "phases": phases,
            "parallel_groups": parallel_groups,
            "sequential_order": sequential_order,
            "total_phases": len(phases),
            "estimated_duration": self._estimate_migration_duration(phases)
        }
        
        self.logger.info(f"Generated migration sequence with {len(phases)} phases")
    
    def _estimate_migration_duration(self, phases: List[Dict]) -> Dict[str, Any]:
        """Estimate migration duration based on container count and complexity."""
        # Simple estimation model
        base_time_per_container = 5  # minutes
        parallel_efficiency = 0.7  # 30% overhead for parallel operations
        
        total_containers = sum(len(phase["containers"]) for phase in phases)
        
        # Sequential time
        sequential_minutes = total_containers * base_time_per_container
        
        # Parallel time (accounting for phases)
        parallel_minutes = 0
        for phase in phases:
            containers_in_phase = len(phase["containers"])
            if phase.get("parallel", False):
                phase_time = base_time_per_container * parallel_efficiency
            else:
                phase_time = containers_in_phase * base_time_per_container
            parallel_minutes += phase_time
        
        return {
            "total_containers": total_containers,
            "estimated_sequential_minutes": sequential_minutes,
            "estimated_parallel_minutes": int(parallel_minutes),
            "estimated_sequential_hours": round(sequential_minutes / 60, 1),
            "estimated_parallel_hours": round(parallel_minutes / 60, 1),
            "time_savings_percent": round((1 - parallel_minutes/sequential_minutes) * 100, 1) if sequential_minutes > 0 else 0
        }
    
    def save_dependencies(self) -> str:
        """Save dependency analysis to JSON file."""
        output_file = self.output_dir / f"container_dependencies_{self.timestamp}.json"
        
        try:
            # Update container dependency lists
            for container_name in self.dependencies["containers"]:
                container_info = self.dependencies["containers"][container_name]
                
                # Add all dependencies to the main depends_on list
                all_deps = set()
                all_deps.update(self.container_dependencies.get(container_name, []))
                all_deps.update(self.network_dependencies.get(container_name, []))
                all_deps.update(self.volume_dependencies.get(container_name, []))
                
                container_info["depends_on"] = list(all_deps)
                
                # Calculate dependents
                dependents = []
                for other_container, other_deps in self.container_dependencies.items():
                    if container_name in other_deps:
                        dependents.append(other_container)
                
                container_info["depended_by"] = dependents
            
            with open(output_file, 'w') as f:
                json.dump(self.dependencies, f, indent=2, default=str)
            
            self.logger.info(f"Dependencies saved to {output_file}")
            return str(output_file)
            
        except Exception as e:
            self.logger.error(f"Error saving dependencies: {e}")
            raise
    
    def run_full_analysis(self) -> str:
        """Run complete dependency analysis."""
        self.logger.info("Starting full dependency analysis...")
        
        try:
            # Run all analysis operations
            self.analyze_container_dependencies()
            self.analyze_compose_dependencies()
            self.build_dependency_graph()
            self.generate_migration_sequence()
            
            # Save results
            output_file = self.save_dependencies()
            
            self.logger.info("Full dependency analysis completed")
            return output_file
            
        except Exception as e:
            self.logger.error(f"Dependency analysis failed: {e}")
            raise


def main():
    """Main entry point."""
    parser = argparse.ArgumentParser(
        description="Container Dependency Mapping Script for PodShift Migration",
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog="""
Examples:
  %(prog)s --verbose
  %(prog)s --output-dir /tmp --timestamp 20240101_120000
  %(prog)s --compose-files docker-compose.yml docker-compose.prod.yml
        """
    )
    
    parser.add_argument(
        '--output-dir',
        default=DEFAULT_OUTPUT_DIR,
        help=f'Output directory for dependency files (default: {DEFAULT_OUTPUT_DIR})'
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
        '--compose-files',
        nargs='*',
        help='Specific Docker Compose files to analyze'
    )
    
    parser.add_argument(
        '--containers-only',
        action='store_true',
        help='Analyze only running containers (skip Compose files)'
    )
    
    args = parser.parse_args()
    
    try:
        # Initialize dependency mapper
        mapper = DependencyMapper(
            output_dir=args.output_dir,
            timestamp=args.timestamp,
            verbose=args.verbose
        )
        
        # Run analysis
        if args.containers_only:
            mapper.analyze_container_dependencies()
            mapper.build_dependency_graph()
            mapper.generate_migration_sequence()
            output_file = mapper.save_dependencies()
        else:
            output_file = mapper.run_full_analysis()
        
        print(f"\nDependency analysis completed successfully!")
        print(f"Results saved to: {output_file}")
        
        # Print summary
        dependencies = mapper.dependencies
        container_count = len(dependencies["containers"])
        compose_count = len(dependencies["compose_services"])
        total_edges = len(dependencies["dependency_graph"]["edges"])
        cycles_count = len(dependencies["dependency_graph"]["cycles"])
        phases_count = dependencies["migration_sequence"]["total_phases"]
        
        print(f"\nSummary:")
        print(f"  Containers analyzed: {container_count}")
        print(f"  Compose services: {compose_count}")
        print(f"  Dependencies found: {total_edges}")
        print(f"  Circular dependencies: {cycles_count}")
        print(f"  Migration phases: {phases_count}")
        
        if "estimated_duration" in dependencies["migration_sequence"]:
            duration = dependencies["migration_sequence"]["estimated_duration"]
            print(f"  Estimated migration time: {duration['estimated_parallel_hours']} hours")
            print(f"  Time savings vs sequential: {duration['time_savings_percent']}%")
        
        return 0
        
    except KeyboardInterrupt:
        print("\nAnalysis interrupted by user")
        return 1
    except DockerException as e:
        print(f"Docker error: {e}", file=sys.stderr)
        return 1
    except Exception as e:
        print(f"Unexpected error: {e}", file=sys.stderr)
        return 1


if __name__ == '__main__':
    sys.exit(main())