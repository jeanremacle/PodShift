# Security Policy

## Supported Versions

The following versions of PodShift are currently supported with security updates:

| Version | Supported          |
| ------- | ------------------ |
| 1.0.x   | :white_check_mark: |
| < 1.0   | :x:                |

## Reporting a Vulnerability

We take the security of PodShift seriously. If you discover a security vulnerability, please follow these steps:

### 1. Do Not Report Publicly

**Please do not report security vulnerabilities through public GitHub issues.** This helps us ensure that vulnerabilities are handled responsibly.

### 2. Contact Information

Report security vulnerabilities by email to:
- **Email**: security@podshift.dev (if available)
- **Subject**: [SECURITY] Brief description of the vulnerability

### 3. Include the Following Information

Please include as much of the following information as possible:

- **Type of vulnerability** (e.g., remote code execution, privilege escalation, information disclosure)
- **Location** of the affected source code (file path, line numbers if possible)
- **Special configuration** required to reproduce the issue
- **Step-by-step instructions** to reproduce the vulnerability
- **Proof of concept** or exploit code (if available)
- **Impact** of the vulnerability and how an attacker might exploit it

### 4. Response Timeline

We will acknowledge receipt of your vulnerability report within **48 hours** and will strive to provide regular updates on our progress.

Our typical response timeline:
- **Initial response**: Within 48 hours
- **Vulnerability assessment**: Within 1 week
- **Fix development**: 2-4 weeks (depending on complexity)
- **Release and disclosure**: Within 30 days of initial report

## Security Considerations

### Docker and Podman Environments

This toolkit interacts with Docker and Podman systems, which have their own security implications:

#### Privileged Access
- Scripts may require elevated privileges to access Docker socket
- Container inspection may reveal sensitive configuration data
- Be cautious when running in production environments

#### Network Security
- Docker API communication should use secure channels
- Avoid running discovery scripts on untrusted networks
- Be aware of potential network-based attacks during migration

#### Data Handling
- Container configurations may contain sensitive information
- Backup files should be stored securely
- Log files may contain sensitive system information

### Best Practices for Users

1. **Run with Minimal Privileges**
   ```bash
   # Avoid running as root unless necessary
   ./setup.sh
   source ./activate.sh
   ```

2. **Secure Storage of Results**
   ```bash
   # Set appropriate permissions on output files
   chmod 600 *.json
   chmod 600 logs/*.log
   ```

3. **Clean Up Sensitive Data**
   ```bash
   # Use the cleanup commands after migration
   make clean-all
   ```

4. **Verify Downloads**
   - Always download from official sources
   - Verify checksums when available
   - Use the latest supported version

### Known Security Considerations

#### Docker Socket Access
- Accessing `/var/run/docker.sock` provides significant system access
- Equivalent to root access on the host system
- Scripts validate input but use caution in multi-user environments

#### System Information Disclosure
- System resource scripts collect detailed hardware information
- Container discovery reveals network configurations
- Consider privacy implications before sharing reports

#### File System Access
- Scripts create files in project directory
- Backup operations may access sensitive directories
- Ensure appropriate file permissions

## Vulnerability Disclosure Policy

### Responsible Disclosure

We follow a responsible disclosure process:

1. **Private notification** to maintainers
2. **Coordinated assessment** and fix development  
3. **Public disclosure** after fix is available
4. **Credit** to security researchers (with their permission)

### Disclosure Timeline

- **Day 0**: Vulnerability reported privately
- **Day 1-7**: Assessment and initial response
- **Day 7-30**: Fix development and testing
- **Day 30**: Public disclosure and release (may be extended for complex issues)

### Public Disclosure

Once a fix is available, we will:

1. Release a security advisory on GitHub
2. Update this security policy if needed
3. Credit the reporter (if they wish to be credited)
4. Provide migration guidance for affected users

## Security Updates

### Notification Channels

Security updates will be announced through:
- GitHub Security Advisories
- Release notes and CHANGELOG.md
- GitHub releases with security tags

### Update Process

To stay secure:

1. **Monitor releases** for security updates
2. **Subscribe** to repository notifications
3. **Update promptly** when security releases are available
4. **Review changes** in security-related releases

```bash
# Check for updates
git fetch origin
git log --oneline HEAD..origin/main

# Update to latest version
git pull origin main
./setup.sh
```

## Security Testing

### Regular Security Practices

We employ several security practices:

- **Dependency scanning** with automated tools
- **Static code analysis** with bandit and other tools
- **Regular security reviews** of critical components
- **Input validation** in all scripts and tools

### Security Testing Tools

The project uses:
- **Bandit**: Python security linting
- **Safety**: Dependency vulnerability scanning  
- **ShellCheck**: Shell script security analysis
- **Pre-commit hooks**: Automated security checks

## Contact Information

For security-related questions or concerns:

- **Security issues**: Use the reporting process above
- **General security questions**: Open a GitHub discussion
- **Documentation issues**: Submit a pull request

## Acknowledgments

We thank the security community for helping to keep PodShift secure. We appreciate responsible disclosure and will acknowledge security researchers who help improve our security posture.

## Additional Resources

- [Docker Security Best Practices](https://docs.docker.com/engine/security/)
- [Podman Security Documentation](https://docs.podman.io/en/latest/markdown/podman-security.1.html)
- [macOS Security Guidelines](https://support.apple.com/guide/security/welcome/web)
- [OWASP Security Guidelines](https://owasp.org/www-project-secure-coding-practices-quick-reference-guide/)

---

*This security policy is subject to change. Please check back regularly for updates.*