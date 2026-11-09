# Security Policy

## Supported Versions

Gerber has not reached 1.0.0. Security fixes are provided for the latest published release only, including the latest prerelease while no stable release exists.

| Version                                | Supported          |
|----------------------------------------|--------------------|
| Latest release (including prerelease)  | :white_check_mark: |
| Older releases                         | :x:                |

This policy covers Gerber Core. Product plugins are separate repositories with their own security policy.

## Reporting a Vulnerability

If you discover a security vulnerability in Gerber, please report it privately and do **not** open a public issue.

### Preferred reporting method

Use GitHub's private vulnerability reporting for this repository:
[Report a vulnerability](https://github.com/stiwicourage/GerberCore/security/advisories/new).

### What to include

Please include as much of the following information as possible:

- A clear description of the issue
- Steps to reproduce the vulnerability
- The affected version(s)
- Any required configuration or environment details, for example the operating system and PowerShell version
- Proof-of-concept code or screenshots, if relevant
- Your assessment of the potential impact

Do not include real credentials, tokens or personal access tokens in a report. Redact them or use disposable values.

### Areas of particular interest

Gerber manages secrets and plugins, so reports about the following are especially valuable:

- credential and secret storage, retrieval, display or clipboard handling
- plugin approval, enablement and the Plugin API boundary
- update, installation and package-source handling
- configuration files and their handling of untrusted input

### What to expect

- You should receive an initial acknowledgement within **2 business days**
- We will investigate the report and may contact you for additional details within **5 business days**
- If the report is accepted, we will work on a fix and coordinate disclosure as appropriate
- If the report is declined, we will explain why (for example, if the behavior is expected, out of scope, or cannot be reproduced)

### Disclosure policy

Please allow time for the issue to be investigated and resolved before making any public disclosure.

Once a fix is available, we may:

- publish a security advisory
- include the fix in a supported release
- credit the reporter, if they would like to be acknowledged
