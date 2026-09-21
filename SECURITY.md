# Security Policy

## Supported versions

The latest tagged release is supported on Alpine Linux 3.24.x. The `main` branch is development code and should be reviewed before use on a production workstation.

## Reporting a vulnerability

Use GitHub's private vulnerability reporting for issues that could cause data loss, authentication bypass, unsafe command execution, secret exposure, or an unexpected reduction in host security. Do not open a public issue for an unpatched vulnerability.

Include the affected version, execution context, reproduction steps, and expected impact. Reports will be acknowledged as soon as practical.

## Trust model

The installer runs as root. Download release assets over HTTPS, verify the published SHA-256 checksum and provenance, inspect changes before upgrading, and never run an installer copied from an untrusted mirror.
