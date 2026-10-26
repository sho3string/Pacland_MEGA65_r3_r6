# Pac-Land - for MEGA65

**Pac-Land** is Namco's 1984 side-scrolling arcade platform game, featuring Pac-Man travelling through towns, forests and other stages to return lost fairies to Fairyland.

This project ports the **Pac-Land** FPGA core from **Jotego's JTCORES project** to the MEGA65.

The upstream core used as the basis of this port is:

[Jotego JTCORES - Pac-Land](https://github.com/jotego/jtcores/tree/master/cores/paclan)

The original FPGA implementation, JTFRAME infrastructure and associated supporting cores are the work of **Jotego and the JTCORES contributors**.

The MEGA65 port uses the [MiSTer2MEGA65](https://github.com/sy2002/MiSTer2MEGA65) framework and [QNICE-FPGA](https://github.com/sy2002/QNICE-FPGA) for MEGA65 integration, including FAT32 ROM loading and the on-screen menu.

## Credits

*Pac-Land* was originally developed and released by **Namco** in 1984.

This MEGA65 core would not exist without the work of **Jotego and the JTCORES contributors**. The MEGA65 version is based on the JTCORES Pac-Land implementation linked above.

Additional credit goes to **sy2002, MJoergen and the MiSTer2MEGA65 contributors** for the MiSTer2MEGA65 framework and QNICE-FPGA integration used by this port.

## How to install the core

### 1. Obtain the Pac-Land ROM archive

The conversion scripts require the original **Pac-Land (World)** MAME ROM archive:

```text
pacland.zip
```

**Do not extract the ZIP archive.** The scripts read its contents directly. No separate prepared MEGA65 ROM archive is required.

The scripts expect the World-set chip filenames, including `pl5_01b.8b`, `pl5_02.8d` and `cus60-60a1.mcu`. Other revisions or clones may not match.

### 2. Generate the MEGA65 ROM images

Three independent ROM conversion scripts are provided:

- `pacland.py` — Python 3 (standard library only)
- `pacland.sh` — Linux Bash, using `unzip`, Perl and `Compress::Zlib`
- `pacland.ps1` — Windows PowerShell 5.1+, using .NET ZIP support

**Each script performs the conversion itself.** The Bash and PowerShell scripts do not call Python.

Place `pacland.zip` alongside the scripts in the project directory.

#### Windows / PowerShell

```powershell
.\pacland.ps1
```

If Windows warns about a downloaded script you trust, unblock it first:

```powershell
Unblock-File .\pacland.ps1
```

The PowerShell script uses `pacland.zip` beside the script and writes the ROMs to `arcade\pacland`. You can override the paths:

```powershell
.\pacland.ps1 -MameZip 'D:\ROMs\pacland.zip' -Output '.\arcade\pacland'
```

#### Linux

```bash
chmod +x pacland.sh
./pacland.sh pacland.zip
```

The Bash script requires `bash`, `unzip`, `perl` and the Perl module `Compress::Zlib`. To specify a different output directory:

```bash
./pacland.sh pacland.zip arcade/pacland
```

#### Python

```bash
python3 pacland.py pacland.zip
```

Python 3 is required; no third-party Python packages are needed.

#### Output directory

By default, the scripts write **11 individual ROM files** to:

```text
arcade/pacland
```

The conversion applies the graphics transformations required by the MEGA65 implementation:

| ROM region | Conversion |
|---|---|
| Main CPU (`pl_main.rom`) | 32 KiB `0xFF` prefix, followed by six program ROMs |
| Sub CPU (`pl_mcusub.rom`) | Original ROM data |
| Scroll 0 (`pl_scr0.rom`) | JTFRAME address-bit sorting |
| Scroll 1 (`pl_scr1.rom`) | JTFRAME address-bit sorting |
| Objects (`pl_obj.rom`) | Interleave four sprite ROMs, then JTFRAME address-bit sorting |
| MCU (`pl_mcu.rom`) | Original ROM data |
| Palette PROMs | Original ROM data |

The graphics sorting is performed automatically. **No combined ROM is generated.**

### 3. Generated ROM files

| File | Size (bytes) | CRC32 |
|---|---:|---|
| `pl_main.rom` | 131072 | `7F29C304` |
| `pl_mcusub.rom` | 8192 | `8C5BECAE` |
| `pl_scr0.rom` | 8192 | `45C8F31C` |
| `pl_scr1.rom` | 8192 | `64735A2F` |
| `pl_obj.rom` | 65536 | `87BB56FC` |
| `pl_mcu.rom` | 4096 | `076EA82A` |
| `pl_rgpal.rom` | 1024 | `472885DE` |
| `pl_bpal.rom` | 1024 | `A78EBDAF` |
| `pl_scr0pal.rom` | 1024 | `4B7EE712` |
| `pl_scr1pal.rom` | 1024 | `3A7BE418` |
| `pl_objpal.rom` | 1024 | `80558DA8` |

These sizes and checksums match the known-good MEGA65 ROM images used during development. The scripts check the generated output. A missing ZIP entry or a checksum mismatch indicates an incorrect or incompatible source archive.

### 4. Copy the ROMs to the MEGA65 SD card

Copy all 11 generated ROM files to:

```text
/arcade/pacland
```

Also copy the Pac-Land configuration file:

```text
/arcade/pacland/plcfg
```

The supplied initial `plcfg` is **82 bytes of `0xFF`**. The configuration file size should match the `OPTM_SIZE` used by the release build; regenerate it if the menu definition changes.

Both the bottom and rear SD card slots can be used. As with other MEGA65 cores, the rear SD card takes precedence when both are present.

Install the Pac-Land `.cor` file using the normal MEGA65 core installation procedure.

## Game setup

Press the **HELP** key while the core is running to open the MiSTer2MEGA65 on-screen menu.

### Video output

Pac-Land is a horizontally oriented arcade game. The MEGA65 port provides HDMI display settings, CRT emulation and VGA output options, including retro 15 kHz modes.


### Controls

Pac-Land originally uses **three buttons**: **Left**, **Jump** and **Right**. The MEGA65 port offers three control modes, selectable from **HELP → Control Settings**.

#### 3-Button mode

Use a three-button joystick connected to the MEGA65 joystick port. The inputs are **POTX**, **Fire** and **POTY**.

By default:

| Input | Action |
|---|---|
| POTX | Move left |
| Fire | Jump |
| POTY | Move right |

Under **Control Settings**, select one of the six button layouts to match your joystick's physical button order.

The menu also provides **POT Active Low / Active High** settings for compatible hardware.

The joystick's directional inputs are not used for left/right movement in this mode.

#### Joystick mode

Use a conventional joystick:

| Input | Action |
|---|---|
| Joystick left | Move left |
| Joystick right | Move right |
| Fire | Jump |

This mode does not require POTX/POTY buttons.

#### Keyboard mode

Select **Control Mode: Keyboard** in **Control Settings**.

| Key | Action |
|---|---|
| Left cursor or X | Move left |
| Right cursor or C | Move right |
| Z or V | Jump |

Keyboard movement and jumping are disabled in the two joystick modes. Physical joystick controls are ignored in Keyboard mode.

#### Common keys

| Key | Action |
|---|---|
| 1 | Start Player 1 |
| 2 | Start Player 2 |
| 5 | Insert coin 1 |
| 6 | Insert coin 2 |
| Caps Lock | Pause |
| HELP | Open the on-screen menu |

In the current upright implementation, both players share the selected gameplay controls.

The control mode applies to gameplay movement and jumping; the common keyboard keys remain available.

### DIP switches

The **DIP SW1** and **DIP SW2** menus expose the original arcade settings:

| Switch | Setting |
|---|---|
| SW1-1 | Service |
| SW1-2 to SW1-3 | Lives |
| SW1-4 to SW1-5 | Coin A |
| SW1-6 | Demo Sounds |
| SW1-7 to SW1-8 | Coin B |
| SW2-1 to SW2-3 | Bonus Life |
| SW2-4 to SW2-5 | Difficulty |
| SW2-6 | Round Select |
| SW2-7 | Freeze |
| SW2-8 | Trip Select |

An existing `plcfg` may retain saved menu settings. If menu entries or `OPTM_SIZE` change, use a configuration file matching that build.

## Upstream projects

This port builds upon several open-source FPGA projects:

- [Jotego JTCORES](https://github.com/jotego/jtcores)
- [Pac-Land core in JTCORES](https://github.com/jotego/jtcores/tree/master/cores/paclan)
- [MiSTer2MEGA65](https://github.com/sy2002/MiSTer2MEGA65)
- [QNICE-FPGA](https://github.com/sy2002/QNICE-FPGA)

Please support the upstream projects and developers whose work made this MEGA65 port possible.

## Status

An upstream JTCORES fix for the Round 19/30 headlamp effects and CUS30 noise was merged as [JTCORES PR #1636](https://github.com/jotego/jtcores/pull/1636).

Please report MEGA65-specific problems through the Pac-Land MEGA65 project rather than to the upstream JTCORES project, unless the problem is also reproducible upstream on the MiSTer

## Known issues

No confirmed specific issues are currently documented.
