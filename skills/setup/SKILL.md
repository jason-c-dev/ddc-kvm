---
name: setup
description: >
  Set up hotkey switching of a monitor's input and its built-in USB KVM over
  DDC/CI, using ddcutil on Linux, with the bundled ddc-kvm CLI. Use when the
  user wants to switch monitor inputs from the keyboard, control a
  USB-C/Thunderbolt KVM monitor (Dell UltraSharp U-series, LG, etc.) from
  Linux, replace Dell Display Manager / Dell Display and Peripheral Manager
  (DDM, DDPM) on Linux, decode VCP 0x60 input-source values, work out which
  i2c bus a monitor is on, or asks why a monitor input switch only works one
  way or why the keyboard follows the monitor. Also for troubleshooting an
  existing ddc-kvm install.
argument-hint: "[monitor model]"
---

# ddc-kvm setup

Turn "reach behind the monitor and press the input button" into a hotkey. The
CLI in this plugin does the switch; this skill does the investigation, the
interview, and the wiring. Work through the steps in order and keep the user
informed at each one. Never guess vendor-specific values; read them live.

## 1. The model in one paragraph

A monitor's input selector is MCCS VCP feature `0x60` (Input Source), reachable
over DDC/CI, an I2C side channel carried inside every DisplayPort, HDMI,
USB-C and Thunderbolt video link. On monitors with a built-in USB KVM, the USB
hub is bound to the video input in the OSD, so **one write to 0x60 switches
video and keyboard/mouse together**. Dell's DDM/DDPM apps do exactly this.
The catch: the moment the monitor switches away, the sending machine loses its
video link and the DDC channel with it. **Each machine can only push the
switch away from itself.** The other machine needs its own hotkey to come
back. Details: `references/one-way-problem.md`.

## 2. Probe the monitor (Linux)

`ddcutil` must be installed (Arch: `pacman -S ddcutil`; Omarchy ships it;
Debian/Ubuntu: `apt install ddcutil`). Run, read-only:

```bash
ddcutil detect                     # bus, DRM connector, model, serial
ddcutil capabilities | grep -A8 "Feature: 60"   # input values the monitor claims
ddcutil getvcp 60                  # the value for THIS machine's input, while it is active
```

- Note the `I2C bus` and `DRM connector` (e.g. `card1-DP-1` → connector `DP-1`).
- `getvcp 60` **while this machine is displayed** gives its own value. ddcutil
  prints `Invalid value (sl=0x13)` or `Unrecognized value` for vendor codes;
  that is normal, the number is what matters.
- `capabilities` lists candidate values but mislabels vendor ones. Treat it as
  a hint, never as the answer.
- If `detect` shows nothing, or `getvcp` fails: `references/troubleshooting.md`
  (DDC/CI off in the OSD, docks and MST hubs, permissions).

## 3. Decode the values

Standard MCCS: `0x0F` DisplayPort 1, `0x10` DisplayPort 2, `0x11` HDMI 1,
`0x12` HDMI 2. Vendors add their own, and Dell in particular numbers DP2 as
`0x13`, Thunderbolt as `0x19`, USB-C as `0x1B`. Full tables with sources,
plus the Dell KVM (`0xE7`) and PIP/PBP (`0xE9`) codes:
`references/dell-vcp-codes.md`.

## 4. Interview the user

Ask, and do not assume:

1. Which machines share this monitor, and what to call each (short lowercase
   name for the command line, a friendly label for notifications).
2. Which physical input each one is on. The OSD's input menu, or DDM/DDPM's
   main "Single Display" screen, shows this. If they have DDPM open, its KVM
   *wizard* pages can show stale state; trust the main screen.
3. Which USB upstream is paired with each input (OSD → USB / KVM). Every
   upstream must be unique; a duplicate means the config is wrong.
4. Which of those machines is *this* one (the `getvcp 60` value from step 2
   pins it down).
5. Which hotkey they want per remote machine. Check for collisions before
   proposing one (`references/desktop-integration.md`).

For inputs you cannot confirm live (the other machines' values), use the
vendor table and say so; the first real switch is the confirmation.

## 5. Write the config

Path: `~/.config/ddc-kvm/config`. Template in `examples/config.example`
(`${CLAUDE_PLUGIN_ROOT}/examples/config.example`). Shape:

```ini
self      = thispc          # the [machines] entry for this machine
connector = DP-1            # from ddcutil detect, used to pick the i2c bus
notify    = auto            # auto | off

[machines]
thispc    = 0x13   This PC (DisplayPort 2)
laptop    = 0x11   Work laptop (HDMI 1)
```

Values are hex `0x..`; the label runs to end of line. The same file, with
`self` and `connector` changed, goes on every machine that shares the monitor.

## 6. Install the CLI and verify

```bash
install -Dm755 "${CLAUDE_PLUGIN_ROOT}/scripts/ddc-kvm" ~/.local/bin/ddc-kvm
ddc-kvm list                  # * marks self, > marks the live input
ddc-kvm status                # must report self's value
ddc-kvm --dry-run laptop      # prints the exact ddcutil command, runs nothing
```

`~/.local/bin` must be on `PATH`. Do not run a real switch yet.

## 7. Bind hotkeys

One key per remote machine, running `ddc-kvm <name>` (absolute path is safest
in compositor configs). Desktop-specific recipes, including Hyprland/Omarchy
`o.bind`, GNOME and KDE custom shortcuts, and the collision checks for each:
`references/desktop-integration.md`. Reload and validate the compositor config
after editing.

## 8. Set up the return trip

Explain the one-way problem plainly, then set up the other machine:

- **Another Linux box**: same plugin, same config with `self`/`connector`
  changed.
- **macOS**: `m1ddc set input <decimal>` (Apple Silicon; not the built-in
  HDMI port on M1/base-M2) or the BetterDisplay CLI, bound via Raycast,
  Shortcuts, Hammerspoon or skhd. Decimal of `0x13` is 19.
- **Windows**: ControlMyMonitor or DDM's own hotkeys.
- **Any OS with SSH to the Linux box**, if the monitor keeps DDC alive on
  inactive inputs: `ssh linuxbox ddc-kvm <linuxbox-name>`. Test it; the
  U5226KW does, older Dells do not.

Commands and caveats: `references/one-way-problem.md`.

## 9. Live test protocol

Tell the user what will happen, then have *them* press the key:

1. Screen and keyboard/mouse should land on the other machine within ~1 s.
2. On that machine, run its return command. Screen comes back here.
3. Run `ddc-kvm status` here again; it should report `self`.

If step 1 does nothing, check `journalctl --user` or run the command by hand
for the error; the CLI raises a critical notification on failure.

## 10. Record what was learned

Put the input table, the config, and the hotkeys somewhere durable the user
already uses (their machine notes, dotfiles README, wiki). The vendor values
and the "which jack is DP-1" mapping are exactly the facts that cost an hour
to rediscover.

## Rules

- Never guess a vendor value when a live `getvcp 60` can confirm it.
- Never send a real switch from an automated session without telling the user
  it will take the screen and keyboard away; let them press the key.
- On Omarchy, never edit `/usr/share/omarchy`; user overrides go in `~/.config`.
- One machine per USB upstream. If two share one, stop and fix the OSD first.
- Problems: `references/troubleshooting.md`.
