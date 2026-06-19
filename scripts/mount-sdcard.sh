#!/bin/bash
# Script mount SDCard sebagai storage utama
# Usage: sudo bash mount-sdcard.sh

SDCARD_MOUNT="/mnt/sdcard"
RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'
BLUE='\033[0;34m'; CYAN='\033[0;36m'; BOLD='\033[1m'; DIM='\033[2m'; NC='\033[0m'

[ "$EUID" -ne 0 ] && { echo -e "${RED}[!] sudo bash $0${NC}"; exit 1; }

echo -e "${BLUE}${BOLD}━━━ SDCARD MOUNT & STORAGE REDIRECT ━━━${NC}"
echo ""

# Deteksi SDCard
SDCARD_DEV=""
for dev in mmcblk1 mmcblk2 sda sdb; do
    if [ -b "/dev/${dev}" ] && ! mount | grep -q "/dev/${dev}.* / "; then
        SDCARD_DEV="/dev/${dev}"
        break
    fi
done

if [ -z "$SDCARD_DEV" ]; then
    echo -e "${RED}[!] SDCard tidak terdeteksi${NC}"
    echo -e "  ${DIM}Cek dengan: lsblk${NC}"
    echo -e "  ${DIM}Coba: echo scan > /sys/class/mmc_host/mmc*/device/uevent 2>/dev/null${NC}"
    exit 1
fi

echo -e "  ${DIM}SDCard terdeteksi:${NC} ${YELLOW}$SDCARD_DEV${NC}"
echo ""
lsblk -o NAME,SIZE,FSTYPE,LABEL,MOUNTPOINT "$SDCARD_DEV" 2>/dev/null
echo ""

if mount | grep -q "$SDCARD_DEV"; then
    CUR_MOUNT=$(mount | grep "$SDCARD_DEV" | awk '{print $3}')
    echo -e "  ${YELLOW}⚠ SDCard sudah ter-mount di $CUR_MOUNT${NC}"
    if [ "$CUR_MOUNT" != "$SDCARD_MOUNT" ]; then
        echo -ne "${BOLD}Pindahkan ke $SDCARD_MOUNT? [Y/n]:${NC} "
        read -r konfirmasi
        [[ "$konfirmasi" =~ ^[Nn] ]] || { umount "$SDCARD_DEV" 2>/dev/null; }
    fi
fi

# Mount SDCard
if ! mount | grep -q "$SDCARD_DEV.*$SDCARD_MOUNT"; then
    mkdir -p "$SDCARD_MOUNT"

    FSTYPE=$(blkid -o value -s TYPE "$SDCARD_DEV" 2>/dev/null || echo "")
    if [ -z "$FSTYPE" ] || [ "$FSTYPE" = "unknown" ]; then
        echo -e "${YELLOW}[!] SDCard belum diformat${NC}"
        echo -ne "${BOLD}Format sebagai ext4? (semua data hilang!) [y/N]:${NC} "
        read -r fmt
        [[ "$fmt" =~ ^[Yy] ]] && { mkfs.ext4 -F "$SDCARD_DEV" > /dev/null 2>&1; echo -e "  ${GREEN}✓${NC} Format selesai"; }
    fi

    mount "$SDCARD_DEV" "$SDCARD_MOUNT" && echo -e "  ${GREEN}✓${NC} SDCard ter-mount di $SDCARD_MOUNT"

    # fstab
    UUID=$(blkid -o value -s UUID "$SDCARD_DEV" 2>/dev/null)
    if [ -n "$UUID" ] && ! grep -q "$UUID" /etc/fstab; then
        echo "UUID=$UUID $SDCARD_MOUNT ext4 defaults,noatime,errors=remount-ro 0 2" >> /etc/fstab
        echo -e "  ${GREEN}✓${NC} Auto-mount ditambahkan ke /etc/fstab"
    fi
fi

# Redirect storage
echo ""
echo -e "${BLUE}${BOLD}━━━ REDIRECT STORAGE ━━━${NC}"
echo ""

# Buat folder di SDCard
for folder in www squid-cache squid-logs adblock apt-cache; do
    mkdir -p "$SDCARD_MOUNT/$folder"
done

# Pindahkan dan symlink
for target in /var/www /var/spool/squid /var/log/squid /etc/adblock; do
    basen=$(basename "$target")
    if [ -d "$target" ] && [ ! -L "$target" ]; then
        size=$(du -sh "$target" 2>/dev/null | cut -f1)
        echo -e "  ${DIM}Memindahkan $target (${size})...${NC}"
        cp -a "$target" "$SDCARD_MOUNT/$basen" 2>/dev/null && rm -rf "$target" && ln -sf "$SDCARD_MOUNT/$basen" "$target"
        echo -e "  ${GREEN}✓${NC} $target → SDCard"
    elif [ -L "$target" ]; then
        echo -e "  ${DIM}○${NC} $target sudah symlink"
    else
        echo -e "  ${DIM}○${NC} $target tidak ada"
    fi
done

# Redirect apt cache
if [ ! -L "/var/cache/apt/archives" ]; then
    rm -rf /var/cache/apt/archives 2>/dev/null
    mkdir -p "$SDCARD_MOUNT/apt-cache"
    ln -sf "$SDCARD_MOUNT/apt-cache" /var/cache/apt/archives 2>/dev/null
    echo -e "  ${GREEN}✓${NC} APT cache → SDCard"
fi

echo ""
echo -e "${GREEN}${BOLD}✓ SDCard siap!${NC}"
echo -e "  ${DIM}Mount:${NC} $SDCARD_MOUNT ($(df -h "$SDCARD_MOUNT" | awk 'NR==2{print $4}') free)"
echo ""
