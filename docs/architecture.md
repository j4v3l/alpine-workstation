# Architecture

## Execution model

`install.sh` is the source and release artifact. It remains a single POSIX shell program so the Alpine live environment can run it without first installing a language runtime. Functions are grouped by responsibility: input validation, preflight checks, state and managed files, base installation, packages, desktop, hardware, services, user configuration, and validation.

The state machine uses versioned marker files under `/var/lib/alpine-workstation/stages`. A stage is marked complete only after its function returns successfully. `resume` reloads non-secret choices from `state.env` and skips completed markers. Passwords, private keys, and encryption passphrases are never persisted.

## Live installation

Live mode is selected only when the root filesystem resembles Alpine installation media and `setup-disk` is present. The script configures Alpine through a temporary `setup-alpine` answer file, but leaves password prompts attached directly to the TTY. It then calls `setup-disk` for the confirmed whole disk.

After the base filesystem is installed, the script mounts it again, binds the kernel filesystems, copies itself into the target, and executes the normal post-install stages in a chroot. Alpine continues to own partitioning, encryption, bootloader installation, package keys, and the base system layout.

## Installed-system conversion

Installed mode never calls a partitioning tool. It enables stable repositories, installs packages in ordered stages, configures the chosen desktop, applies detected hardware support, creates or updates the administrator, and validates the resulting system.

When invoked through an existing root SSH session, key-only settings are written with a `.pending` suffix. The administrator tests a separate login and then runs `secure-ssh` to validate and activate the configuration.

## Managed files

Before replacing an existing file, the installer copies it into a timestamped backup tree. The installed checksum is recorded separately. On a later run, a checksum mismatch means the file was locally edited; the installer keeps it intact and writes the proposed version with a `.new` suffix.

## Package sources

The system repositories are pinned to the Alpine 3.24 `main` and `community` branches. Optional edge entries use repository tags, and every edge package argument must carry one of those tags. A global upgrade can therefore never cross into edge accidentally.
