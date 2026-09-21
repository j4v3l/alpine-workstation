# Troubleshooting

Start with:

```sh
doas ./alpine-workstation status
doas ./alpine-workstation doctor
```

The latest detailed log is in `/var/log/alpine-workstation`.

## Unsupported Alpine release

The installer requires Alpine 3.24.x. Install current Alpine media rather than editing repository URLs on an old system. Cross-release upgrades from unsupported versions are intentionally outside the installer.

## No disks shown

Only unmounted devices reported as whole disks are listed. The boot medium and any disk with a mounted child partition are excluded. Unmount a data disk only after verifying its contents and backups.

## No graphical session

Check that the kernel command line no longer contains `nomodeset`, inspect `dmesg` for firmware failures, and verify the selected display manager. NVIDIA users should also review Nouveau support for the exact GPU generation.

## PipeWire has no devices

Run `aplay -l`. If ALSA sees no card, inspect `dmesg` for missing SOF or codec firmware. If ALSA sees the device, check `rc-status -Ur`, `wpctl status`, and the user's `XDG_RUNTIME_DIR`. Do not enable the package autostart and OpenRC user services at the same time.

## Bluetooth audio does not connect

Confirm `bluetooth` is enabled, unblock the radio with `rfkill`, pair again with `bluetoothctl`, and verify `pipewire-spa-bluez` is installed. Headset buttons may require the `uinput` kernel module.

## Fingerprint enrollment fails

Run `fprintd-enroll` manually and compare the USB identifier against the devices supported by `libfprint`. The installer will not activate PAM configuration until enrollment and verification succeed.

## A `.new` file appeared

The active file changed after Alpine Workstation last managed it. Compare both versions and merge the desired changes manually. Once the active file is intentionally updated, remove the unused candidate.
