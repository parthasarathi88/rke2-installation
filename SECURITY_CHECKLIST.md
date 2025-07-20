# Security Checklist for RKE2 Infrastructure

## Files That Should NEVER Be Committed

### 🔑 Credentials & Authentication
- [ ] SSH private keys (`id_rsa`, `id_ed25519`)
- [ ] Kubernetes config files (`kubeconfig`, `rke2.yaml`)
- [ ] SSL/TLS certificates and private keys (`.key`, `.crt`, `.pem`)
- [ ] Password files and secret files
- [ ] Ansible vault files with sensitive data

### 🔐 Configuration Files with Secrets
- [ ] Inventory files with passwords
- [ ] Helm values files with credentials
- [ ] Environment files (`.env`)
- [ ] Bootstrap secrets and tokens

### 📂 Directories with Sensitive Data
- [ ] `.kube/` directory
- [ ] `secrets/` directory
- [ ] `credentials/` directory
- [ ] `/tmp/` temporary files with credentials

## Security Best Practices

### ✅ Do's
- Use Ansible Vault for sensitive variables
- Store credentials in secure secret management systems
- Use environment variables for runtime secrets
- Implement proper RBAC in Kubernetes
- Regular security audits of committed files
- Use `.gitignore` patterns for sensitive file types

### ❌ Don'ts
- Never commit plain text passwords
- Don't include kubeconfig files in repositories
- Avoid hardcoding secrets in YAML files
- Don't commit SSH keys or certificates
- Never include database connection strings with credentials

## Pre-Commit Security Checks

1. **Scan for secrets**: Use tools like `git-secrets` or `truffleHog`
2. **Review .gitignore**: Ensure all sensitive patterns are covered
3. **Check committed files**: Verify no credentials in configuration files
4. **Validate Ansible vars**: Use vault for sensitive variables

## Incident Response

If sensitive data is accidentally committed:

1. **Immediate action**: Remove from all branches
2. **Rotate credentials**: Change all exposed passwords/keys
3. **History cleanup**: Use `git filter-branch` or BFG Repo-Cleaner
4. **Security review**: Audit all related systems
5. **Update procedures**: Improve security practices

## Tools for Security

- `git-secrets`: Prevents committing secrets
- `ansible-vault`: Encrypts sensitive variables
- `age` or `sops`: File-level encryption
- `detect-secrets`: Pre-commit hook for secret detection

## Regular Maintenance

- [ ] Monthly review of .gitignore file
- [ ] Quarterly security audit of repository
- [ ] Annual credential rotation
- [ ] Regular training on security practices

---
**Last Updated**: July 16, 2025
**Security Contact**: Infrastructure Team
