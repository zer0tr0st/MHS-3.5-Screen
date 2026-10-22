# MHS35 SPI Raspberry Pi Touchscreen Setup

Setup scripts for the **MHS35 3.5" SPI touchscreen** (TFT35A-style) on a Raspberry Pi. Works on **Alpine Linux** and **Debian / Raspberry Pi OS**.

This repo contains two scripts:

| Script | Purpose |
| --- | --- |
| `mhs35-setup.sh` | Configures the display, touch input, and Linux console for the MHS35 |
| `screen-info.sh` | Full-screen, large-font system status display for the LCD (optional) |

## What the Setup Script Does

- Detects the OS (Alpine or Debian) and the correct boot partition path
- Installs the required packages (X server, `fbdev` and `evdev` drivers, CA certificates)
- Removes conflicting or old display configurations
- Downloads the MHS35 (`tft35a`) overlay and touchscreen calibration file
- Writes an X11 `fbdev` config pointing at the SPI framebuffer (`/dev/fb1`)
- Enables SPI and configures the TFT overlay with a 270° rotation
- Configures the Linux console to use the SPI display
- Creates one-time backups of the boot config files
- Is safe to re-run: config changes are written in a marked block and are not duplicated

## Installation

Clone the repository:

```sh
git clone https://github.com/zer0tr0st/MHS-3.5-Screen.git
cd MHS35-SPI
```

Make the script executable and run it as root:

```sh
chmod +x mhs35-setup.sh
sudo ./mhs35-setup.sh
```

On Alpine, run it as root without `sudo` if `sudo` isn't installed:

```sh
./mhs35-setup.sh
```

Reboot to apply the changes:

```sh
sudo reboot
```

## Requirements

- Raspberry Pi (developed on a Raspberry Pi 4)
- MHS35 3.5" SPI touchscreen
- Alpine Linux (64-bit) or Debian / Raspberry Pi OS
- Internet connection
- Root access

## Status Screen (`screen-info.sh`)

`screen-info.sh` fills the LCD with a large, easy-to-read system overview, refreshed every 2 seconds:

- Hostname, date, and time
- IP address of each network interface
- Wi-Fi SSID and signal strength
- Gateway and internet reachability
- CPU usage and load
- Temperature in Celsius
- Memory and disk usage
- Uptime
- Undervoltage / throttling warning (only shown when there is a problem)
- Pi model, OS, and kernel version

Values are colored green, yellow, or red depending on how healthy they are.

### Usage

```sh
sh screen-info.sh once        # draw once in the current terminal (test over SSH)
sudo sh screen-info.sh install    # install dependencies and start automatically at boot
sudo sh screen-info.sh uninstall  # remove the service and restore the login prompt
```

`install` uses OpenRC on Alpine and systemd on Debian.

> **Note:** `install` takes over `tty1`, so the login prompt no longer appears on the LCD. Use SSH to log in, or run `uninstall` to restore it.

### Options

Set these as environment variables, or edit the defaults at the top of the script:

| Variable | Default | Description |
| --- | --- | --- |
| `FONT_SIZE` | `24` | Console font height: `16`, `20`, `24`, `28`, or `32`. Larger = bigger text, fewer lines |
| `REFRESH` | `2` | Seconds between updates |
| `TTY` | `/dev/tty1` | Console to draw on |

At the default size the 480×320 screen fits about 40 columns by 13 rows.

## Backups

Before the first change, the setup script copies the boot configuration files to the boot partition:

```
config.txt.bak   (or usercfg.txt.bak on Alpine)
cmdline.txt.bak
```

The boot partition is `/boot` on older Raspberry Pi OS, `/boot/firmware` on newer Debian, and `/media/mmcblk0p1` on Alpine diskless installs. The script finds it automatically.

## Alpine Notes

- Alpine regenerates `config.txt` on kernel updates, so display settings go in `usercfg.txt` when it is available.
- On **diskless** installs, the script runs `lbu commit` so the changes survive a reboot. If you change anything by hand in `/etc`, run `lbu commit` yourself.
- The boot partition is mounted read-only on diskless installs. The script remounts it read-write temporarily and restores it afterwards.

## Troubleshooting

- **Blank screen after reboot:** the overlay depends on the `fbtft` and `ads7846` kernel modules. The script warns if it can't find them. Check with:
  ```sh
  find /lib/modules -name 'fbtft*' -o -name 'ads7846*'
  ```
  If they are missing, the overlay can't work on that kernel. Try an overlay your kernel provides, such as `dtoverlay=waveshare35a`, which works with many MHS35 panels.
- **No `/dev/fb1`:** the overlay didn't load. Check that `dtparam=spi=on` and `dtoverlay=tft35a:rotate=270` are in your boot config, then reboot.
- **Touch is offset or inverted:** the downloaded calibration was written for a different rotation. Recalibrate with `xinput_calibrator` and update `/etc/X11/xorg.conf.d/99-calibration.conf`.
- **Font not loading in `screen-info.sh`:** make sure `terminus-font` (Alpine) or `console-setup` (Debian) is installed. `screen-info.sh install` does this for you.
- **Script fails partway:** run it with `sh -x mhs35-setup.sh` to see exactly which line failed.

## Notes

This project is intended specifically for the MHS35 / TFT35A-style 3.5" SPI touchscreen. A reboot is required after setup for the changes to take effect.
