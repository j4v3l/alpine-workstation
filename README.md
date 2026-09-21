# Alpine Workstation

[![CI](https://github.com/j4v3l/alpine-workstation/actions/workflows/ci.yml/badge.svg)](https://github.com/j4v3l/alpine-workstation/actions/workflows/ci.yml)
[![Alpine 3.24](https://img.shields.io/badge/Alpine-3.24-0D597F?logo=alpinelinux&logoColor=white)](https://alpinelinux.org/releases/)
[![License](https://img.shields.io/badge/license-Apache--2.0-blue.svg)](LICENSE)

Turn a bare Alpine Linux TTY into a polished daily-driver workstation. Alpine Workstation handles a fresh whole-disk installation from official live media or upgrades an already installed Alpine 3.24 system with a desktop, hardware support, applications, and a carefully configured shell.

## Highlights

- GNOME by default, with Plasma, Xfce, and Sway available.
- Intel, AMD, NVIDIA Nouveau, hybrid graphics, and virtual-machine detection.
- PipeWire audio with ALSA, PulseAudio, JACK, Bluetooth, and SOF support.
- Optional fingerprint login and unlock with password fallback.
- NetworkManager, Flatpak and Flathub, printing, scanning, firmware updates, and a desktop firewall.
- Oh My Zsh, Starship, the Alpine glyph, JetBrains Mono Nerd Font, modern command-line tools, and safe aliases.
- Checkpointed stages, repeatable runs, configuration backups, and an actionable health check.

## Requirements

- x86_64 Alpine Linux 3.24.x.
- A working network connection.
- Root access for installation.
- Secure Boot disabled while installing from live media.

Older Alpine releases are intentionally refused. Reinstall with current Alpine media instead of attempting a long chain of unsupported upgrades.

> [!WARNING]
> A live-media installation erases the selected whole disk. The installer displays the disk model, size, and serial, then requires the exact device path before Alpine's own erase confirmation.

> [!IMPORTANT]
> Alpine uses musl. NVIDIA's proprietary Linux driver is unavailable; NVIDIA systems use Nouveau and may have reduced performance, power management, and compute support.

## Quick start

Download and verify the latest release:

```sh
wget -q https://github.com/j4v3l/alpine-workstation/releases/latest/download/alpine-workstation
wget -q https://github.com/j4v3l/alpine-workstation/releases/latest/download/alpine-workstation.sha256
sha256sum -c alpine-workstation.sha256
chmod +x alpine-workstation
```

Start the interactive installer:

```sh
doas ./alpine-workstation
```

The Alpine live ISO logs in as root, so run it directly there:

```sh
./alpine-workstation
```

Choose the safe default GNOME installation while retaining identity, password, SSH-key, and disk prompts:

```sh
./alpine-workstation --defaults
```

Preview without changing the system:

```sh
./alpine-workstation plan --desktop gnome --profile balanced
```

## Commands

| Command | Purpose |
| --- | --- |
| `install` or no command | Run the installer |
| `plan` | Print the detected system and planned stages without changing it |
| `resume` | Continue from the last incomplete checkpoint |
| `status` | Show saved configuration and completed stages |
| `doctor` | Check packages, services, desktop, audio, firewall, and SSH |
| `secure-ssh --user NAME` | Activate pending key-only SSH settings after testing a second login |

Run `./alpine-workstation --help` for all flags. Edge packages must include an explicit repository tag, such as `ghostty@edge-community`. Edge is never added to normal dependency resolution.

## Safety model

- Whole-disk installation supports one explicitly selected disk; dual boot and custom partition layouts are not managed.
- Plain ext4 is the default. `--encrypt` delegates LUKS/LVM creation to Alpine's `setup-disk`.
- Existing managed files are backed up under `/var/lib/alpine-workstation/backups`.
- A file changed locally after installation is preserved and the proposed update is written beside it with a `.new` suffix.
- Logs live in `/var/log/alpine-workstation` and do not capture passwords or private keys.
- Root and password SSH are disabled only after an administrator public key exists. Remote conversions stage this change until a separate user login is confirmed.

## Documentation

- [Architecture](docs/architecture.md)
- [Hardware support](docs/hardware.md)
- [Recovery](docs/recovery.md)
- [Troubleshooting](docs/troubleshooting.md)
- [Testing](docs/testing.md)
- [Contributing](CONTRIBUTING.md)
- [Security policy](SECURITY.md)

## License

Apache-2.0 © J4v3l
