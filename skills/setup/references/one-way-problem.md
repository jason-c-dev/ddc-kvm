# The one-way problem, and the return trip

## Why a machine can only push the switch away from itself

DDC/CI rides on the I2C pins of the video connector. It only exists while the
monitor has that input selected and the link is up. When machine A writes
`0x60` and the monitor switches to machine B:

```
 A ── DP ──┐                                  A ── DP ──┐  (link down,
           │ monitor  ──USB hub──► keyboard             │   no DDC)
 B ── HDMI ┘   shows A                        B ── HDMI ┘  monitor shows B,
                                                           hub now on B
   A: ddc-kvm b   ─────────────────────────►   B: <its own command>  ──► back to A
```

- A's video link drops, so A's DDC channel is gone. A cannot switch back.
- The USB hub followed the input, so A's keyboard is now on B anyway.
- Whether a monitor keeps answering DDC on an *inactive* input is undefined by
  the MCCS spec. Older Dells (U2414H) do not. The Dell U5226KW **does**: with
  its cable still connected, the Linux box can read `0x60` and write it while
  the monitor shows another machine. Test yours: switch away, then from the
  other machine run `ssh <linuxbox> ddc-kvm status`. If it answers, `ssh
  <linuxbox> ddc-kvm <linuxbox-name>` is a working return trip with no extra
  software on the other side. Still set up the local command; SSH is a
  fallback, not a hotkey.

Therefore every machine that shares the monitor needs its own "push away"
command and hotkey. This is exactly how Dell's own DDM/DDPM works too: it is
installed on every PC.

## Return-trip commands per OS

### Linux

Same plugin, same config file with `self` and `connector` changed. `ddcutil`
is the only dependency.

### macOS (Apple Silicon)

**m1ddc** (free, MIT): <https://github.com/waydabber/m1ddc>

```bash
brew install m1ddc
m1ddc get input          # decimal value of the Mac's own input, while displayed
m1ddc set input 19       # 19 = 0x13 = DisplayPort 2 on Dell
m1ddc display list       # if more than one display
m1ddc display 1 set input 19
```

Limitation: m1ddc cannot drive the **built-in HDMI port on M1 and base-M2
Macs** (macOS exposes no DDC there). Thunderbolt/USB-C connections are fine.
Newer chips generally work over HDMI, but verify with `m1ddc get input`.

**BetterDisplay** CLI (Pro feature, supports all ports including M1 HDMI):

```bash
betterdisplaycli set -n=DELL -ddc=19 -vcp=inputSelect
# or over its local HTTP API
curl 'http://localhost:55777/set?namelike=DELL&ddc=19&vcp=inputSelect'
```

**Lunar** CLI: `lunar displays dell input displayPort2` or
`lunar ddc dell INPUT_SOURCE 19`.

Bind any of these with Raycast (Script Command), Shortcuts (Run Shell Script
+ keyboard shortcut), Hammerspoon (`hs.hotkey.bind`), or skhd. Recipes in
`desktop-integration.md`.

Dell's DDPM on macOS also has a per-input hotkey field on its main screen
("Hotkey: None" by default); that works too and needs nothing else.

### Windows

- Dell Display Manager / DDPM: assign a hotkey per input in the KVM settings.
- [ControlMyMonitor](https://www.nirsoft.net/utils/control_my_monitor.html):
  `ControlMyMonitor.exe /SetValue Primary 60 19`.
- `winddcutil` or PowerShell + `DDC/CI` via the Windows API for scripting.

## Alternatives when a machine cannot run a command

- **USB-triggered switching** ([display-switch](https://github.com/haimgel/display-switch)):
  a daemon on every PC watches for a specific USB device appearing (the KVM's
  hub) and switches the monitor to itself. No Apple Silicon support as of
  1.3.x, but the same idea works with a launchd USB watcher calling m1ddc.
- **An always-on controller on a spare input**: a Raspberry Pi or ESP32 on an
  unused HDMI port sends the DDC command on request over the network
  ([DDC-Trigger](https://github.com/SzozdaK/DDC-Trigger),
  [hdmi2c](https://github.com/wlcx/hdmi2c)). Bidirectional, but a project.
- **PIP/PBP mode**: with two inputs on screen at once both machines keep DDC,
  and Dell's `0xE7 0xFF00` swaps just the USB hub.
