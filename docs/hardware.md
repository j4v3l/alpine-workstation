# Hardware Support

## Graphics

| Hardware | Installed support | Notes |
| --- | --- | --- |
| Intel | Mesa, Vulkan, VA-API, media driver, firmware, microcode | Legacy devices may need `libva-intel-driver` manually |
| AMD | Mesa, RADV Vulkan, VA-API, firmware, microcode | Open kernel and Mesa drivers are used |
| NVIDIA | Nouveau, Mesa, firmware | No proprietary driver or CUDA; recent cards may have reduced acceleration |
| Hybrid | Packages for every detected GPU | Application offload remains application-specific |
| QEMU/KVM | Mesa plus guest agent and SPICE agent | Intended for testing and virtual desktops |

The installer removes `nomodeset` only when graphics hardware is present and it recognizes the active bootloader configuration.

## Audio

PipeWire and WirePlumber provide the audio graph. ALSA, PulseAudio, and JACK compatibility packages are installed together with Bluetooth support, realtime limits, and `sof-firmware` for applicable Intel audio hardware. User-level OpenRC services are enabled for graphical and X11 sessions, and the older desktop autostart path is masked per user to prevent duplicate daemons.

Use these checks after login:

```sh
wpctl status
aplay -l
rc-status -Ur
```

## Fingerprint readers

Automatic detection uses common reader descriptions and vendor identifiers. Detection cannot guarantee that `libfprint` supports a particular device. After reboot, run:

```sh
alpine-workstation-fingerprint
```

The helper enrolls and verifies a print before enabling fingerprint authentication for the installed display manager or lock screen. Password authentication remains available. Root and SSH authentication are not changed.

## Laptops and peripherals

The balanced profile includes firmware updates, power profiles, brightness support supplied by the desktop, Bluetooth, webcam frameworks, removable storage, printing, and scanning. It does not install both TLP and power-profiles-daemon because their policies conflict.
