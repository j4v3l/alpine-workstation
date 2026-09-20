# Contributing

Contributions should make Alpine Workstation safer, more predictable, or more useful without weakening its stable-first package policy.

## Workflow

1. Create a short-lived branch named `feat/...`, `fix/...`, `docs/...`, or `chore/...`.
2. Keep commits focused and use a Conventional Commit subject.
3. Run `scripts/check.sh` before pushing.
4. Open a pull request against `main` and complete the checklist.
5. Resolve all conversations and wait for the required `quality` check.

`main` requires signed commits, pull requests, linear history, and successful CI. Releases use signed semantic tags.

## Shell guidelines

- Keep `install.sh` compatible with POSIX `sh` and Alpine BusyBox.
- Quote expansions unless deliberate package-manifest splitting is documented for ShellCheck.
- Never accept passwords or disk-encryption secrets through command-line options, environment variables, state, or logs.
- Treat package and service operations as repeatable; a second run should be safe.
- Use `aw_write_managed` for configuration files so backups and local-change detection remain consistent.
- Add unit coverage for parsing, detection, or safety behavior that changes.

## Package changes

Packages must exist in Alpine 3.24 `main` or `community`. Packages from edge require a repository tag and must not become dependencies of the default profile. Run `scripts/check-packages.sh` inside Alpine 3.24 after changing a package group.

## Destructive changes

Changes to disk selection, partitioning, encryption, bootloaders, SSH authentication, PAM, or firewall policy require a focused test plan and a disposable QEMU installation before merge.
