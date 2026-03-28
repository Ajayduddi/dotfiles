# Security Policy

This document describes how to report security vulnerabilities for this dotfiles and automation scripts repository, and what response/disclosure process to expect.

## Supported Versions / Branches

Security fixes are supported on all active branches in this repository.

| Branch | Supported |
|---|---|
| `main` | Yes |
| `linux_stow` | Yes |
| `linux` | Yes |
| `cloud` | Yes |

Notes:
- Fixes may land on the main working branch first and then be backported to other supported branches.
- Backport timing is best effort based on severity and maintainer availability.

## Reporting a Vulnerability

Please report vulnerabilities privately through **GitHub Security Advisories**:

1. Go to the repository on GitHub.
2. Open the **Security** tab.
3. Click **Report a vulnerability**.
4. Submit a private advisory with details.

Please include:
- Clear reproduction steps
- Impacted file(s)/script(s)
- Expected vs actual behavior
- Potential blast radius (local user, system-wide, credential exposure, network exposure)
- Suggested mitigation (if known)

Please **do not open a public GitHub issue** for unpatched security vulnerabilities.

## Response Expectations

Best-effort response targets:
- **Acknowledgement:** within **72 hours**
- **Status updates:** approximately every **7 days** until closure
- **Severity handling targets:**
  - Critical: initial mitigation/fix target within 7 days
  - High: initial mitigation/fix target within 14 days
  - Medium/Low: scheduled based on risk and maintenance capacity

These targets are goals, not guarantees.

## Coordinated Disclosure

This project follows a coordinated disclosure model:
- Keep reports private until a fix or mitigation is ready.
- Validate and patch the issue first.
- Publish disclosure details (advisory/changelog note) after patch availability.

## Scope Notes

### In Scope
- Script logic that can cause unsafe or destructive behavior
- Credential leakage paths in tracked files or generated backup artifacts
- Unsafe defaults in backup/restore/firewall flows
- Permission/privilege escalation mistakes caused by repository scripts

### Out of Scope
- Local machine compromise not caused by this repository
- User/environment misconfiguration without a repository defect
- Third-party service outages or vulnerabilities outside this repository

## Secrets Handling Reminder

This repo includes a preventive pre-push scan for high-confidence secret patterns.
Use it before pushing:

```bash
bash scripts/pre-push-safety-scan.sh
```

You can also enable the repo-managed pre-push hook:

```bash
git config core.hooksPath .githooks
chmod +x .githooks/pre-push scripts/pre-push-safety-scan.sh
```

This reminder is preventive guidance and does not replace private vulnerability reporting.
