# Changelog

All notable changes to this project are documented here. The format follows
[Keep a Changelog](https://keepachangelog.com/en/1.1.0/), and the project uses
[Semantic Versioning](https://semver.org/).

## [0.1.0] - 2026-09-04

### Added

- `ddc-kvm` CLI: switch a monitor's input (and its built-in USB KVM) by machine
  name over DDC/CI with `ddcutil`. Config-driven, with `status`, `list`, `next`,
  `--dry-run`, i2c bus detection by connector name, and desktop notifications.
- `/ddc-kvm:setup` skill for Claude Code: probes the monitor, decodes vendor
  input values, interviews the user about the machine layout, writes the config,
  installs the CLI, binds hotkeys, and sets up the return trip from the other
  machine.
- Reference documents on Dell VCP codes, the one-way problem, desktop
  integration (Hyprland/Omarchy, GNOME, KDE, macOS), and troubleshooting.
- bats test suite with fake `ddcutil`, shellcheck lint, GitHub Actions CI.

[0.1.0]: https://github.com/jason-c-dev/ddc-kvm/releases/tag/v0.1.0
