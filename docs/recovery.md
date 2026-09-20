# Recovery

## Interrupted installation

Run the same release with:

```sh
doas ./alpine-workstation resume
```

Completed stages are skipped. If the live environment itself was rebooted before the target became bootable, start again from current Alpine media and inspect the disk before retrying.

## Configuration backups

Each run stores replaced files below:

```text
/var/lib/alpine-workstation/backups/RUN_ID/
```

Copy the required backup over the active file, restore its original permissions, and restart the affected service. Files with local edits are never replaced automatically; inspect the adjacent `.new` file and merge it manually.

## Graphical login failure

Switch to another TTY, log in, and inspect the active display manager:

```sh
rc-status -a
doas rc-service gdm status
doas rc-service sddm status
doas rc-service lightdm status
doas rc-service greetd status
```

Only one of those services should be enabled. Review `/var/log`, the display-manager log, and the latest installer log before changing configuration.

## SSH recovery

Remote conversions do not activate root lockout immediately. If the administrator login does not work, leave the pending file in place and correct the user's `~/.ssh/authorized_keys`. Activate hardening only after a second session succeeds:

```sh
doas ./alpine-workstation secure-ssh --user USER
```

For a machine already locked out, use its physical console or recovery media, mount the root filesystem, and restore the backed-up SSH configuration.
