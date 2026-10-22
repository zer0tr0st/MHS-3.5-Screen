#!/bin/sh
# MHS35 (tft35a) SPI touchscreen setup for Raspberry Pi
# Works on Alpine Linux and Debian / Raspberry Pi OS. Safe to re-run.
set -eu

log()  { printf '==> %s\n' "$*"; }
warn() { printf 'WARN: %s\n' "$*" >&2; }
die()  { printf 'ERROR: %s\n' "$*" >&2; exit 1; }

[ "$(id -u)" = 0 ] || die "Run as root."

# ---------- detect OS ----------
. /etc/os-release
case "${ID:-} ${ID_LIKE:-}" in
  *alpine*)                 OS=alpine ;;
  *debian*|*raspbian*)      OS=debian ;;
  *) die "Unsupported OS: ${ID:-unknown}" ;;
esac
log "Detected OS: $OS"

# ---------- detect boot partition ----------
BOOT=""
for d in /boot/firmware /media/mmcblk0p1 /boot; do
  if [ -f "$d/config.txt" ]; then BOOT=$d; break; fi
done
[ -n "$BOOT" ] || die "Could not find boot partition (no config.txt)."
log "Boot partition: $BOOT"

# remount read-write if needed (Alpine diskless mounts it read-only)
WAS_RO=0
if grep -E " $BOOT .*[ ,]ro[ ,]" /proc/mounts >/dev/null 2>&1; then
  WAS_RO=1
  mount -o remount,rw "$BOOT"
fi

# ---------- install packages ----------
log "Installing packages..."
case "$OS" in
  alpine)
    apk add --no-cache ca-certificates ssl_client wget \
      xorg-server xinit xf86-video-fbdev xf86-input-evdev eudev
    setup-devd udev >/dev/null 2>&1 || true
    ;;
  debian)
    apt-get update
    DEBIAN_FRONTEND=noninteractive apt-get install -y \
      ca-certificates wget xserver-xorg xinit \
      xserver-xorg-video-fbdev xserver-xorg-input-evdev
    ;;
esac

# ---------- helper ----------
fetch() {  # fetch URL DEST
  tmp="$2.tmp"
  wget -O "$tmp" "$1" || { rm -f "$tmp"; die "Download failed: $1"; }
  [ -s "$tmp" ] || { rm -f "$tmp"; die "Downloaded file is empty: $1"; }
  mv "$tmp" "$2"
}

# ---------- overlay ----------
log "Downloading overlay..."
mkdir -p "$BOOT/overlays"
rm -f "$BOOT/overlays/mhs35.dtbo"
fetch "https://raw.githubusercontent.com/goodtft/LCD-show/master/usr/tft35a-overlay.dtb" \
      "$BOOT/overlays/tft35a.dtbo"

# ---------- X11 config ----------
log "Writing X11 config..."
mkdir -p /etc/X11/xorg.conf.d
rm -f /etc/X11/xorg.conf.d/99-calibration.conf
rm -f /usr/share/X11/xorg.conf.d/99-fbturbo.conf

fetch "https://raw.githubusercontent.com/goodtft/LCD-show/master/usr/99-calibration.conf-35-0" \
      /etc/X11/xorg.conf.d/99-calibration.conf

cat > /etc/X11/xorg.conf.d/99-spi-fbdev.conf <<'EOF'
Section "Device"
    Identifier "SPI LCD"
    Driver     "fbdev"
    Option     "fbdev" "/dev/fb1"
EndSection
EOF

# ---------- config.txt (idempotent, marker block) ----------
CFG="$BOOT/config.txt"
# Alpine regenerates config.txt on kernel updates; prefer usercfg.txt if included
if [ -f "$BOOT/usercfg.txt" ] || grep -q '^include usercfg.txt' "$CFG"; then
  CFG="$BOOT/usercfg.txt"
  touch "$CFG"
fi
log "Updating $CFG..."
[ -f "$CFG.bak" ] || cp "$CFG" "$CFG.bak"

sed -i '/# BEGIN MHS35/,/# END MHS35/d' "$CFG"
sed -i '/^dtoverlay=tft35a/d' "$CFG"
cat >> "$CFG" <<'EOF'

# BEGIN MHS35
dtparam=spi=on
dtoverlay=tft35a:rotate=270
# END MHS35
EOF

# ---------- cmdline.txt (idempotent) ----------
CMD="$BOOT/cmdline.txt"
log "Updating $CMD..."
[ -f "$CMD.bak" ] || cp "$CMD" "$CMD.bak"
grep -q 'fbcon=map:10'          "$CMD" || sed -i 's/[[:space:]]*$/ fbcon=map:10/' "$CMD"
grep -q 'fbcon=font:VGA10x10'   "$CMD" || sed -i 's/[[:space:]]*$/ fbcon=font:VGA10x10/' "$CMD"

# ---------- sanity check: kernel modules ----------
if ! find /lib/modules -name 'fbtft*' -o -name 'ads7846*' 2>/dev/null | grep -q .; then
  warn "fbtft / ads7846 kernel modules not found. The overlay will not work"
  warn "without them. Try another kernel, or an overlay your kernel provides"
  warn "(e.g. dtoverlay=waveshare35a)."
fi

# ---------- persist / restore ----------
if [ "$OS" = alpine ] && command -v lbu >/dev/null 2>&1; then
  lbu commit >/dev/null 2>&1 || true   # no-op on non-diskless installs
fi
[ "$WAS_RO" = 1 ] && mount -o remount,ro "$BOOT" || true

log "Done. Reboot to apply changes."
