# Testing

## Local checks

Run the complete non-destructive suite:

```sh
scripts/check.sh
```

The suite validates POSIX syntax, ShellCheck findings, unit behavior, the release bundle, documentation formatting when the relevant tools are installed, and package names when executed on Alpine 3.24.

## Alpine container smoke test

```sh
docker run --rm -v "$PWD:/work:ro" -w /work alpine:3.24 \
  sh -c 'set -eu; printf "%s\n" \
    "https://dl-cdn.alpinelinux.org/alpine/v3.24/main" \
    "https://dl-cdn.alpinelinux.org/alpine/v3.24/community" \
    >/etc/apk/repositories; sh scripts/check-packages.sh; sh scripts/smoke.sh; sh tests/unit.sh'
```

## QEMU acceptance

Use disposable virtual disks. Test BIOS and UEFI independently, then cover the default GNOME path, encrypted storage, alternate desktops, interrupted-stage recovery, a second repeatable run, and an incorrect erase confirmation. Never point the test at the host disk.

After booting the guest, verify the display manager, user login, `doas`, SSH key access, root SSH refusal, nftables rules, NetworkManager, `wpctl status`, Flatpak, shell prompt, font selection, and `doctor`.
