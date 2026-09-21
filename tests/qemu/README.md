# QEMU Acceptance Harness

The harness downloads and verifies Alpine 3.24.2, creates an isolated qcow2 disk, and opens the live ISO on a serial console.

BIOS test:

```sh
tests/qemu/boot.sh
```

UEFI test:

```sh
FIRMWARE=uefi tests/qemu/boot.sh
```

The disk is stored under `${TMPDIR:-/tmp}/alpine-workstation-qemu` unless `TEST_DIR` is set. Remove or rename that directory between destructive scenarios. Use `/dev/vda` inside the guest; never pass a host block device to the harness.

Inside the live guest, configure networking, fetch the installer from the host or repository, and exercise the checklist in [the testing guide](../../docs/testing.md).
