#!/bin/bash
# Module: Mount SDCard sebagai storage utama
# Sumber: modules/sdcard.sh

SDCARD_MOUNT="/mnt/sdcard"

INSTALL_SDCARD() {
    clear
    MSG_TITLE "SETUP SDCARD SEBAGAI STORAGE UTAMA"

    local sdcard_dev
    sdcard_dev=$(DETECT_SDCARD)

    if [ -z "$sdcard_dev" ]; then
        MSG_FAIL "Tidak terdeteksi SDCard"
        echo -e "  ${DIM}Pastikan SDCard terpasang dengan benar${NC}"
        PRESS_ENTER
        return 1
    fi

    MSG_INFO "SDCard terdeteksi: ${YELLOW}$sdcard_dev${NC}"

    local sdcard_info
    sdcard_info=$(lsblk -o NAME,SIZE,FSTYPE,LABEL,MOUNTPOINT "$sdcard_dev" 2>/dev/null)
    echo -e "  ${DIM}$sdcard_info${NC}"
    echo ""

    if mount | grep -q "$sdcard_dev"; then
        local current_mount
        current_mount=$(mount | grep "$sdcard_dev" | awk '{print $3}')
        MSG_WARN "SDCard sudah ter-mount di $current_mount"
        if [ "$current_mount" != "$SDCARD_MOUNT" ]; then
            CONFIRM "Pindahkan mount ke $SDCARD_MOUNT?" || return
            umount "$sdcard_dev" 2>/dev/null || true
        else
            MSG_INFO "SDCard sudah siap di $SDCARD_MOUNT"
            CONFIRM "Lanjutkan setup symlink storage?" || return
        fi
    else
        CONFIRM "Mount SDCard ke $SDCARD_MOUNT?" || return
    fi

    mkdir -p "$SDCARD_MOUNT"

    if ! mount | grep -q "$sdcard_dev.*$SDCARD_MOUNT"; then
        # Cek filesystem
        local fstype
        fstype=$(blkid -o value -s TYPE "$sdcard_dev" 2>/dev/null || echo "ext4")

        if [ "$fstype" = "" ] || [ "$fstype" = "unknown" ]; then
            MSG_WARN "SDCard belum diformat ($fstype)"
            echo -e "  ${YELLOW}Peringatan: Memformat akan menghapus semua data!${NC}"
            CONFIRM "Format SDCard sebagai ext4?" || return
            mkfs.ext4 -F "$sdcard_dev" > /dev/null 2>&1
            fstype="ext4"
            MSG_OK "SDCard diformat sebagai ext4"
        fi

        mount "$sdcard_dev" "$SDCARD_MOUNT"
        if [ $? -ne 0 ]; then
            MSG_FAIL "Gagal mount SDCard"
            PRESS_ENTER
            return 1
        fi
        MSG_OK "SDCard ter-mount di $SDCARD_MOUNT"
    fi

    # Tambahkan ke fstab untuk auto-mount
    if ! grep -q "$sdcard_dev" /etc/fstab 2>/dev/null; then
        local uuid
        uuid=$(blkid -o value -s UUID "$sdcard_dev" 2>/dev/null || echo "")
        if [ -n "$uuid" ]; then
            echo "UUID=$uuid $SDCARD_MOUNT ext4 defaults,noatime,errors=remount-ro 0 2" >> /etc/fstab
        else
            echo "$sdcard_dev $SDCARD_MOUNT ext4 defaults,noatime,errors=remount-ro 0 2" >> /etc/fstab
        fi
        MSG_OK "Auto-mount ditambahkan ke /etc/fstab"
    fi

    # Redirect storage ke SDCard
    SETUP_STORAGE_REDIRECT

    mkdir -p "$SDCARD_MOUNT"

    # Pindahkan direktori penting
    local dirs_to_move=(
        "/var/www:www-data:www-data"
        "/var/spool/squid:proxy:proxy"
        "/var/log/squid:proxy:proxy"
        "/var/log/nginx:www-data:www-data"
        "/etc/adblock:root:root"
    )

    echo ""
    MSG_TITLE "PINDAHKAN DATA KE SDCARD"

    for entry in "${dirs_to_move[@]}"; do
        local dir="${entry%%:*}"
        local owner="${entry##*:}"
        local dirname
        dirname=$(basename "$dir")

        if [ -d "$dir" ] && [ ! -L "$dir" ]; then
            local size
            size=$(du -sh "$dir" 2>/dev/null | cut -f1)
            MSG_INFO "Memindahkan $dir ($size) ke SDCard..."

            if [ -d "$SDCARD_MOUNT/$dirname" ]; then
                CONFIRM "Timpa $SDCARD_MOUNT/$dirname?" || continue
                rm -rf "$SDCARD_MOUNT/$dirname"
            fi

            cp -a "$dir" "$SDCARD_MOUNT/$dirname"
            rm -rf "$dir"
            ln -sf "$SDCARD_MOUNT/$dirname" "$dir"
            chown -R "$(echo $owner | tr ':' ' ')" "$SDCARD_MOUNT/$dirname" 2>/dev/null || true
            MSG_OK "$dir -> SDCard (symlink)"
        fi
    done

    echo ""
    MSG_OK "SDCard setup selesai!"
    echo -e "  ${DIM}Mount point:${NC} $SDCARD_MOUNT"
    echo -e "  ${DIM}Free space:${NC} $(df -h "$SDCARD_MOUNT" 2>/dev/null | awk 'NR==2 {print $4}')"
    echo ""
    PRESS_ENTER
}

SETUP_STORAGE_REDIRECT() {
    if [ ! -d "$SDCARD_MOUNT" ]; then
        MSG_WARN "SDCard belum di-mount, buat folder dulu"
        mkdir -p "$SDCARD_MOUNT"
    fi

    # Redirect apt cache ke SDCard
    if [ ! -L "/var/cache/apt/archives" ]; then
        mkdir -p "$SDCARD_MOUNT/apt-cache"
        rm -rf /var/cache/apt/archives 2>/dev/null
        ln -sf "$SDCARD_MOUNT/apt-cache" /var/cache/apt/archives 2>/dev/null || true
        MSG_OK "APT cache -> SDCard"
    fi

    # Redirect log ke SDCard
    if [ ! -L "/var/log" ]; then
        MSG_INFO "Me-redirect /var/log ke SDCard membutuhkan reboot manual"
    fi

    MSG_OK "Storage redirect selesai"
}

REMOVE_SDCARD() {
    MSG_TITLE "REMOVE SDCARD SETUP"
    CONFIRM "Hapus semua symlink dan kembalikan ke storage internal?" "n" || return

    # Kembalikan symlink
    for link in /var/www /var/spool/squid /var/log/squid /etc/adblock; do
        if [ -L "$link" ]; then
            local target
            target=$(readlink "$link")
            if [ -d "$target" ]; then
                rm -f "$link"
                cp -a "$target" "$link" 2>/dev/null || {
                    mkdir -p "$link"
                    MSG_WARN "Data $link tidak bisa dikembalikan, folder kosong dibuat"
                }
            fi
        fi
    done

    local sdcard_dev
    sdcard_dev=$(DETECT_SDCARD)
    if [ -n "$sdcard_dev" ]; then
        umount "$sdcard_dev" 2>/dev/null || true
        sed -i "\|$sdcard_dev|d" /etc/fstab 2>/dev/null || true
        sed -i "\|$SDCARD_MOUNT|d" /etc/fstab 2>/dev/null || true
    fi

    MSG_OK "SDCard setup dihapus"
    PRESS_ENTER
}
