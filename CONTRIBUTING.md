# Contributing to PodShift

Thank you for your interest in contributing to PodShift! This document provides guidelines and information for contributors.

## Table of Contents

- [Code of Conduct](#code-of-conduct)
- [Getting Started](#getting-started)
- [Development Setup](#development-setup)
- [Contributing Process](#contributing-process)
- [Coding Standards](#coding-standards)
- [Testing](#testing)
- [Documentation](#documentation)
- [Reporting Issues](#reporting-issues)
- [Security Issues](#security-issues)

## Code of Conduct

This project adheres to the [Contributor Covenant Code of Conduct](CODE_OF_CONDUCT.md). By participating, you are expected to uphold this code.

## Getting Started

### Prerequisites

- macOS 12.0+ (preferably on Apple Silicon M1/M2/M3)
- Python 3.8+
- Git
- Docker (for testing migration scenarios)
- Homebrew (for system dependencies)

### Development Setup

1. Fork the repository on GitHub
2. Clone your fork locally:
   ```bash
   git clone https://github.com/YOUR_USERNAME/podshift.git
   cd podshift
   ```

3. Set up the development environment:
   ```bash
   ./setup.sh
   source ./activate.sh
   ```

4. Install pre-commit hooks:
   ```bash
   pip install pre-commit
   pre-commit install
   ```

5. Verify your setup:
   ```bash
   make status
   make test
   ```

## Contributing Process

### 1. Create an Issue

Before starting work, create an issue to discuss:
- Bug reports
- Feature requests
- Documentation improvements
- Performance enhancements

### 2. Branch Naming

Create a descriptive branch name:
- `feature/add-podman-installer`
- `bugfix/fix-dependency-detection`
- `docs/update-installation-guide`
- `refactor/cleanup-discovery-scripts`

### 3. Development Workflow

1. Create a new branch:
   ```bash
   git checkout -b feature/your-feature-name
   ```

2. Make your changes following our [coding standards](#coding-standards)

3. Test your changes:
   ```bash
   make test
   make lint
   ```

4. Commit your changes:
   ```bash
   git add .
   git commit -m "feat: add new feature description"
   ```

5. Push to your fork:
   ```bash
   git push origin feature/your-feature-name
   ```

6. Create a Pull Request on GitHub

### 4. Pull Request Guidelines

- Provide a clear description of the changes
- Reference related issues with `Fixes #123` or `Closes #123`
- Include tests for new functionality
- Update documentation as needed
- Ensure all CI checks pass
- Request review from maintainers

## Coding Standards

### Python Code

- Follow [PEP 8](https://pep8.org/) style guidelines
- Use [Black](https://black.readthedocs.io/) for code formatting
- Use [isort](https://pycqa.github.io/isort/) for import sorting
- Add type hints where possible
- Include docstrings for all functions and classes
- Maximum line length: 100 characters

Example:
```python
#!/usr/bin/env python3

"""
Module docstring describing the purpose and functionality.
"""

import argparse
import logging
from typing import Dict, List, Optional

def analyze_containers(container_list: List[str]) -> Dict[str, str]:
    """
    Analyze Docker containers for migration compatibility.
    
    Args:
        container_list: List of container names or IDs to analyze
        
    Returns:
        Dictionary mapping container names to compatibility status
        
    Raises:
        ValueError: If container_list is empty
    """
    if not container_list:
        raise ValueError("Container list cannot be empty")
    
    # Implementation here
    return {}
```

### Shell Scripts

- Use `#!/bin/bash` shebang
- Enable strict mode: `set -euo pipefail`
- Quote variables: `"$variable"`
- Use meaningful function names
- Add comments for complex logic
- Follow [ShellCheck](https://www.shellcheck.net/) recommendations

Example:
```bash
#!/bin/bash

# Script description and purpose
# Usage: script.sh [options]

set -euo pipefail

# Constants
readonly SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly LOG_FILE="logs/script_$(date '+%Y%m%d_%H%M%S').log"

# Functions
log_info() {
    local message="$1"
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] [INFO] $message" | tee -a "$LOG_FILE"
}

main() {
    log_info "Starting script execution"
    # Implementation here
}

main "$@"
```

### Commit Messages

Follow [Conventional Commits](https://www.conventionalcommits.org/):

- `feat:` - New features
- `fix:` - Bug fixes
- `docs:` - Documentation changes
- `style:` - Code style changes (formatting, etc.)
- `refactor:` - Code refactoring
- `test:` - Adding or updating tests
- `chore:` - Maintenance tasks

Examples:
```
feat: add support for Podman 4.0+ installation
fix: resolve Docker socket permission issues on M1 Macs
docs: update README with new installation instructions
```

## Testing

### Running Tests

```bash
# Run all tests
make test

# Run specific test categories
make lint          # Code linting
make format        # Code formatting check
make type-check    # Type checking with mypy
```

### Test Coverage

- Aim for >80% test coverage for new code
- Include both unit and integration tests
- Test error conditions and edge cases
- Mock external dependencies (Docker API, file system, etc.)

### Test Structure

```
tests/
├── unit/
│   ├── test_docker_inventory.py
│   └── test_dependency_mapper.py
├── integration/
│   ├── test_discovery_workflow.py
│   └── test_system_setup.py
└── fixtures/
    ├── sample_containers.json
    └── mock_docker_responses.json
```

## Documentation

### Code Documentation

- Include docstrings for all public functions and classes
- Document complex algorithms and business logic
- Keep comments up-to-date with code changes

### User Documentation

- Update README.md for user-facing changes
- Add examples for new features
- Document configuration options
- Include troubleshooting guides

### API Documentation

- Document script parameters and options
- Include usage examples
- Document output formats and file structures

## Reporting Issues

### Bug Reports

Include:
- Clear description of the problem
- Steps to reproduce
- Expected vs. actual behavior
- System information (macOS version, architecture, Docker version)
- Relevant log files or error messages

Use the bug report template:
```markdown
**Bug Description**
A clear description of the bug.

**To Reproduce**
1. Run command '...'
2. See error

**Expected Behavior**
What should have happened.

**Environment**
- macOS version: 13.0
- Architecture: arm64 (M1)
- Docker version: 4.15.0
- Python version: 3.11.0

**Additional Context**
Any other context or screenshots.
```

### Feature Requests

Include:
- Clear description of the desired feature
- Use case and motivation
- Proposed implementation approach (if any)
- Examples of similar features in other tools

## Security Issues

**Do not report security vulnerabilities in public issues.**

For security-related issues:
1. Email the maintainers directly
2. Include "SECURITY" in the subject line
3. Provide detailed information about the vulnerability
4. Allow time for the issue to be addressed before public disclosure

See our [Security Policy](SECURITY.md) for more details.

## Development Tips

### Useful Commands

```bash
# Quick development setup
make setup && source ./activate.sh

# Run discovery with verbose output
make discovery

# Check system requirements
make system-check

# Clean up generated files
make clean

# Show project status
make status
```

### IDE Setup

#### VS Code
Recommended extensions:
- Python
- Pylance
- Black Formatter
- autoDocstring
- GitLens
- ShellCheck

#### PyCharm
Configure:
- Code style: Black
- Import sorting: isort
- Type checking: mypy
- Linting: flake8

### Debugging

- Use `--verbose` flag for detailed output
- Check log files in `logs/` directory
- Use Python debugger (`pdb`) for complex issues
- Test with different Docker configurations

## Release Process

For maintainers:

1. Update version in `pyproject.toml`
2. Update CHANGELOG.md
3. Create release commit: `git commit -m "chore: release v1.0.0"`
4. Tag the release: `git tag v1.0.0`
5. Push with tags: `git push origin main --tags`
6. GitHub Actions will handle the release automation

## Questions?

- Open a discussion on GitHub
- Check existing issues and pull requests
- Review the documentation in `docs/`

Thank you for contributing to PodShift! 🎉