# VCP codes for input and KVM switching

DDC/CI carries MCCS "VCP" features: a one-byte feature code with a 16-bit
value. Input selection is feature `0x60`. Everything below was gathered from
live probes and community reverse engineering; sources are at the end.

## 0x60 Input Source

### Standard MCCS 2.2 values

| Value | Input |
|---|---|
| `0x01` | VGA 1 |
| `0x03` | DVI 1 |
| `0x04` | DVI 2 |
| `0x0F` | DisplayPort 1 |
| `0x10` | DisplayPort 2 |
| `0x11` | HDMI 1 |
| `0x12` | HDMI 2 |

### Dell values (non-standard beyond DP1/HDMI)

Confirmed on U5226KW (live), U2723QE, U3821DW, U4323QE, U4025QW, S3422DWG.

| Value | Dec | Input | Notes |
|---|---|---|---|
| `0x0F` | 15 | DisplayPort 1 | standard |
| `0x10` | 16 | mini-DP / DP2 | older models (UP2516D era) |
| `0x13` | 19 | DisplayPort 2 | newer models; ddcutil prints "Invalid value" |
| `0x11` | 17 | HDMI 1 | standard |
| `0x12` | 18 | HDMI 2 | standard |
| `0x19` | 25 | Thunderbolt 4 upstream | U5226KW and other TB hub monitors |
| `0x1B` | 27 | USB-C (DP Alt Mode) | U2723QE, U3223QE, U4323QE, ... |

**Naming trap:** the OSD's "DP 2" jack can show up as `DP-1` in Hyprland,
Xorg, or `ddcutil detect`, because the compositor numbers connectors on the
GPU, not the monitor. Record both names.

### Other vendors (community reports, verify live)

| Vendor | Value | Input |
|---|---|---|
| LG (UltraFine/UltraGear) | `0xD0` | DisplayPort 1 |
| LG | `0xD1` | DisplayPort 2 |
| LG | `0x90` | HDMI 1 |
| LG | `0x91` | HDMI 2 |
| LG | `0xD2` | USB-C |
| Samsung | `0x25` | DisplayPort |
| Samsung | `0x05`/`0x06` | HDMI 1/2 (some models use 0x11/0x12) |
| ASUS | `0x0F`/`0x11`/`0x12` | standard, plus `0x1B` USB-C on some |

`m1ddc` on macOS takes and prints these as decimals (`m1ddc set input 19`).

## Dell KVM and PIP/PBP codes

The USB KVM is *bound* to the video input in the OSD (Menu → USB), so a plain
`0x60` write moves the hub as well. These extra codes only matter for
picture-in-picture / picture-by-picture setups where the video does not move.

| Code | Meaning | Values |
|---|---|---|
| `0xE7` | USB upstream (KVM) selection | `0xFF00` = switch USB to the next input (U2723QE, U3821DW, U4919DW). On U4323QE a packed per-input USB index. DDM 1.x documented `E7 xxyy` = input bound to USB #2 / #1. Often returns "DDC null response" yet still acts. |
| `0xE5` | Swap PIP/PBP video sources | `0xF001` cycles sources |
| `0xE8` | PIP/PBP sub-window source | input values as above; U4323QE packs four windows into one word |
| `0xE9` | PIP/PBP mode | `0x00` off, `0x01` PIP large, `0x21` PIP small, `0x02` toggle position, `0x24` PBP 2-up, `0x41` 2x2 "Screen Partition" |

On the U5226KW, `ddcutil capabilities` lists `E7(00 01 02 03 FE FF)` and
`E9(00 01 02 21 22 24 29 2A ... 51)`.

## Reading and writing

```bash
ddcutil getvcp 60 --brief              # VCP 60 SNC x13
ddcutil --bus 9 --noverify setvcp 60 0x11
```

`--noverify` matters on `0x60`: when the write succeeds the video link drops,
so ddcutil's read-back fails and would report a false error.

## Sources

- ddcutil issue [#192](https://github.com/rockowitz/ddcutil/issues/192) (Dell
  `0x13` = DP2, `E7 0xFF00`), [#70](https://github.com/rockowitz/ddcutil/issues/70)
  (`0x1B` USB-C), [#268](https://github.com/rockowitz/ddcutil/issues/268) (S3422DWG)
- [ekamil/dell-ddc-documentation](https://github.com/ekamil/dell-ddc-documentation)
  (U4323QE `E7`/`E8`/`E9` tables)
- [lainosantos U2723QE gist](https://gist.github.com/lainosantos/06d233f6c586305cde67489c2e4a764d)
- [waydabber/m1ddc](https://github.com/waydabber/m1ddc) (input value list, `i2c.h`
  naming `0xE7` KVM, `0xE8` PBP_INPUT, `0xE9` PBP)
- Dell Display Manager 2.x user's guide (DDC/CI required; USB Switch; Network
  KVM is a LAN keyboard/mouse share, not a monitor command)
- Live probe of a Dell U5226KW, firmware level 65.4, 2026-09-04
