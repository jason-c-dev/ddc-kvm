# ddc-kvm

[![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg?style=flat)](./LICENSE)
[![CI](https://github.com/jason-c-dev/ddc-kvm/actions/workflows/ci.yml/badge.svg)](https://github.com/jason-c-dev/ddc-kvm/actions/workflows/ci.yml)
[![Claude Code plugin](https://img.shields.io/badge/Claude%20Code-plugin-8A2BE2.svg?style=flat)](#install)
[![Platform: Linux](https://img.shields.io/badge/platform-Linux-lightgrey.svg?style=flat)](#requirements)
[![shellcheck](https://img.shields.io/badge/shellcheck-clean-brightgreen.svg?style=flat)](./Makefile)
[![bats](https://img.shields.io/badge/tests-bats-brightgreen.svg?style=flat)](./tests)

Switch your monitor's input, and the USB KVM built into it, from a hotkey.
No reaching behind the monitor, no Dell Display Manager, no Windows or macOS
required.

`ddc-kvm` is two things: a small config-driven CLI that does the switch in
milliseconds, and a [Claude Code](https://claude.com/claude-code) skill that
does the investigation. Point Claude at your monitor and it probes it, decodes
the vendor's input codes, asks which machine is on which port, writes the
config, binds the keys, and sets up the return trip from the other machine.

```bash
$ ddc-kvm list
   mini      0x19  Mac mini (Thunderbolt 4)
   nuc       0x0f  NUC (DisplayPort 1 / USB-C2)
*> desktop       0x13  Desktop (DisplayPort 2 / USB-C3)
   macbook      0x11  Work MacBook (HDMI 1 / USB-C4)

$ ddc-kvm macbook          # screen, keyboard and mouse move to the MacBook
```

## How it works

Every DisplayPort, HDMI, USB-C and Thunderbolt video link carries DDC/CI, an
I2C side channel the monitor listens on. Its input selector is MCCS VCP
feature `0x60`. On monitors with a built-in KVM, the USB hub is bound to the
video input in the OSD, so **one write to `0x60` switches video and
keyboard/mouse together**. That is all Dell's DDM/DDPM apps do. On Linux,
[ddcutil](https://www.ddcutil.com/) does it:

```bash
ddcutil --bus 9 --noverify setvcp 60 0x11
```

`ddc-kvm` wraps that with a config file (machine names, input values, which
connector to find the bus on), a desktop notification, and sane errors, so a
hotkey can call it.

### The one-way problem

```
 Linux ── DP ───┐                          Linux ── DP ───┐   link down, no DDC,
                │ monitor ──hub──► kbd                    │   keyboard is on the Mac
 Mac ── HDMI ───┘  shows Linux             Mac ── HDMI ───┘   monitor shows Mac

   Linux: ddc-kvm macbook  ───────►   Mac: m1ddc set input 19  ───► back to Linux
```

The moment the monitor switches away, the sending machine loses its video
link and the DDC channel with it. **Each machine can only push the switch away
from itself**, so every machine that shares the monitor needs its own hotkey.
On Linux that is this tool; on a Mac it is one `m1ddc` or BetterDisplay
command. The skill walks through both sides.

Some monitors keep answering DDC on inactive inputs (the Dell U5226KW does,
as long as the cable stays connected). There, `ddc-kvm <self>` run over SSH
from the machine that currently has the monitor pulls it back, so the Linux
box can serve both directions.

## Install

### As a Claude Code plugin (recommended)

```
/plugin marketplace add jason-c-dev/ddc-kvm
/plugin install ddc-kvm@ddc-kvm
/ddc-kvm:setup
```

The setup skill installs the CLI to `~/.local/bin/ddc-kvm`, writes the config
with you, and binds the keys for your desktop.

### By hand

```bash
git clone https://github.com/jason-c-dev/ddc-kvm.git
cd ddc-kvm
make install                                   # symlinks scripts/ddc-kvm into ~/.local/bin
mkdir -p ~/.config/ddc-kvm
cp examples/config.example ~/.config/ddc-kvm/config   # then edit
```

### Requirements

- Linux with `ddcutil` (Arch: `pacman -S ddcutil`, Omarchy ships it;
  Debian/Ubuntu: `apt install ddcutil`) and access to `/dev/i2c-*` (ddcutil's
  udev rule handles it for the logged-in user).
- DDC/CI enabled in the monitor's OSD (Dell: Menu → Others → DDC/CI).
- A cable straight to the GPU. Docks and MST hubs often eat the DDC channel.

macOS and Windows are the *other side* for now; see the return-trip notes in
[`skills/setup/references/one-way-problem.md`](skills/setup/references/one-way-problem.md).

## Configure

`~/.config/ddc-kvm/config` (or `DDC_KVM_CONFIG`, or `--config`):

```ini
self      = desktop       # which entry is this machine
connector = DP-1         # DRM connector from `ddcutil detect`, to pick the i2c bus
notify    = auto         # auto | off

[machines]
# name    = vcp60  label
mini   = 0x19   Mac mini (Thunderbolt 4)
nuc    = 0x0F   NUC (DisplayPort 1 / USB-C2)
desktop    = 0x13   Desktop (DisplayPort 2 / USB-C3)
macbook   = 0x11   Work MacBook (HDMI 1 / USB-C4)
```

The value for each machine is what `ddcutil getvcp 60` reports while that
machine is the active input. Read your own live; take the others from the
vendor table below, and let the first real switch confirm them.

## Use

```
ddc-kvm <machine>        switch the monitor (and its USB KVM) to <machine>
                         (<self> is a no-op if already shown, else pulls the monitor back)
ddc-kvm next             switch to the machine listed after this one
ddc-kvm status           print the current input
ddc-kvm list             print the configured machines (* = self, > = current)

--config PATH  --bus N  --dry-run  --no-notify  -V  -h
exit codes: 0 ok, 1 DDC failure, 2 usage, 3 config, 4 backend missing
```

Failures raise a critical desktop notification as well as a message on
stderr, so a hotkey that does nothing is never silent.

## Hotkeys

Hyprland on Omarchy, in `~/.config/hypr/bindings.lua`:

```lua
o.bind("SUPER + CTRL + M", "Monitor to MacBook", "/home/you/.local/bin/ddc-kvm macbook")
```

Plain Hyprland: `bind = SUPER CTRL, M, exec, /home/you/.local/bin/ddc-kvm macbook`.
Sway, GNOME, KDE and the macOS side (Raycast, Hammerspoon, skhd, Shortcuts)
are in [`desktop-integration.md`](skills/setup/references/desktop-integration.md).

## Input values

Standard MCCS: `0x0F` DP1, `0x10` DP2, `0x11` HDMI1, `0x12` HDMI2. Dell adds
`0x13` DP2, `0x19` Thunderbolt, `0x1B` USB-C, and ddcutil prints them as
"Invalid value", which is normal. LG uses `0xD0`/`0xD1`/`0x90`/`0x91`/`0xD2`.
The full table, plus Dell's KVM (`0xE7`) and PIP/PBP (`0xE9`) codes, is in
[`dell-vcp-codes.md`](skills/setup/references/dell-vcp-codes.md).

## Development

```bash
make lint      # shellcheck
make test      # bats (needs bats-core, bats-support, bats-assert)
make validate  # claude plugin validate --strict .
```

Arch: `pacman -S bats bats-support bats-assert shellcheck`. Tests run the CLI
against a fake `ddcutil` that records its arguments, so no monitor is needed.

## Roadmap

- macOS backend in the same script (`m1ddc`, BetterDisplay), so one config
  serves every machine.
- Omarchy menu entry and bar widget.
- Windows notes.

## Credits

- [ddcutil](https://www.ddcutil.com/) by Sanford Rockowitz, and issues
  [#192](https://github.com/rockowitz/ddcutil/issues/192) /
  [#83](https://github.com/rockowitz/ddcutil/issues/83) for the Dell values and
  the inactive-input behaviour.
- [m1ddc](https://github.com/waydabber/m1ddc) and
  [BetterDisplay](https://github.com/waydabber/BetterDisplay) for the Mac side.
- [ekamil/dell-ddc-documentation](https://github.com/ekamil/dell-ddc-documentation)
  and the [U2723QE gist](https://gist.github.com/lainosantos/06d233f6c586305cde67489c2e4a764d)
  for Dell's KVM and PBP codes.
- [Omarchy](https://omarchy.org/) for the i2c-bus-by-connector detection idea
  in its brightness helper.

## License

[MIT](./LICENSE)
