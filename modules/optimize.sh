#!/bin/bash
# Module: Optimasi Perangkat STB (RAM rendah, flash storage)
# Sumber: modules/optimize.sh

OPTIMIZE_DEVICE() {
    clear
    MSG_TITLE "OPTIMASI PERANGKAT"

    echo -e "  ${DIM}Penerapan tuning untuk STB (RAM 512MB-2GB, flash storage)${NC}"
    echo ""

    CONFIRM "Terapkan optimasi?" || return

    BACKUP_FILE /etc/sysctl.conf

    # 1. vm.swappiness — kurangi swap (flash storage)
    echo -e "  ${BOLD}1.${NC} vm.swappiness = 10"
    sysctl -w vm.swappiness=10 > /dev/null 2>&1
    grep -q "vm.swappiness" /etc/sysctl.conf && sed -i 's/vm.swappiness=.*/vm.swappiness=10/' /etc/sysctl.conf || echo "vm.swappiness=10" >> /etc/sysctl.conf

    # 2. vfs cache pressure
    echo -e "  ${BOLD}2.${NC} vm.vfs_cache_pressure = 50"
    sysctl -w vm.vfs_cache_pressure=50 > /dev/null 2>&1
    grep -q "vm.vfs_cache_pressure" /etc/sysctl.conf && sed -i 's/vm.vfs_cache_pressure=.*/vm.vfs_cache_pressure=50/' /etc/sysctl.conf || echo "vm.vfs_cache_pressure=50" >> /etc/sysctl.conf

    # 3. TCP BBR
    echo -e "  ${BOLD}3.${NC} TCP BBR (congestion control)"
    grep -q "tcp_congestion_control" /etc/sysctl.conf 2>/dev/null && sed -i 's/net.core.default_qdisc=.*/net.core.default_qdisc=fq/' /etc/sysctl.conf && sed -i 's/net.ipv4.tcp_congestion_control=.*/net.ipv4.tcp_congestion_control=bbr/' /etc/sysctl.conf || cat >> /etc/sysctl.conf << EOF
net.core.default_qdisc=fq
net.ipv4.tcp_congestion_control=bbr
EOF
    sysctl -p > /dev/null 2>&1 || true

    # 4. Disable services tidak perlu
    echo -e "  ${BOLD}4.${NC} Nonaktifkan service tidak perlu..."
    for svc in bluetooth avahi-daemon cups whoopsie ModemManager; do
        if systemctl is-enabled --quiet "$svc" 2>/dev/null; then
            systemctl stop "$svc" 2>/dev/null || true
            systemctl disable "$svc" 2>/dev/null || true
            echo -e "     ${DIM}→ $svc dinonaktifkan${NC}"
        fi
    done

    # 5. noatime
    echo -e "  ${BOLD}5.${NC} Set noatime pada filesystem..."
    if mount | grep " / " | grep -v noatime > /dev/null 2>&1; then
        local root_dev
        root_dev=$(findmnt -n -o SOURCE /)
        if [ -n "$root_dev" ]; then
            mount -o remount,noatime "$root_dev" / 2>/dev/null && echo -e "     ${GREEN}✓${NC} noatime aktif"
        fi
    else
        echo -e "     ${GREEN}✓${NC} sudah noatime"
    fi

    # 6. Kernel printk
    echo -e "  ${BOLD}6.${NC} Kernel printk tuning"
    sysctl -w kernel.printk="3 3 3 3" > /dev/null 2>&1
    grep -q "kernel.printk" /etc/sysctl.conf && sed -i 's/kernel.printk=.*/kernel.printk=3 3 3 3/' /etc/sysctl.conf || echo "kernel.printk=3 3 3 3" >> /etc/sysctl.conf

    # 7. ZRAM setup (untuk RAM rendah)
    echo -e "  ${BOLD}7.${NC} Setup ZRAM..."
    if command -v zramctl &>/dev/null; then
        local ram_total
        ram_total=$(free -m | awk '/^Mem:/{print $2}')
        if [ "$ram_total" -le 1024 ]; then
            if ! zramctl | grep -q "^/dev/zram"; then
                modprobe zram 2>/dev/null || true
                echo lz4 > /sys/block/zram0/comp_algorithm 2>/dev/null || true
                echo $((ram_total * 512 * 1024)) > /sys/block/zram0/disksize 2>/dev/null || true
                mkswap /dev/zram0 2>/dev/null || true
                swapon -p 100 /dev/zram0 2>/dev/null || true
                MSG_OK "ZRAM: $((ram_total/2))MB (lz4)"
            else
                MSG_INFO "ZRAM sudah aktif"
            fi
        else
            MSG_INFO "RAM cukup besar ($((ram_total))MB), ZRAM tidak diperlukan"
        fi
    else
        MSG_INFO "zramctl tidak tersedia"
    fi

    echo ""
    MSG_OK "Optimasi selesai!"
    MSG_WARN "Beberapa perubahan butuh reboot"
    CONFIRM "Reboot sekarang?" && { MSG_INFO "Reboot..."; reboot; }
    PRESS_ENTER
}

CLEANUP_SYSTEM() {
    clear
    MSG_TITLE "PEMBERSIHAN SISTEM"

    echo -e "  ${BOLD}1.${NC} Paket tidak dipakai..."
    apt autoremove -y > /dev/null 2>&1 && MSG_OK "OK"

    echo -e "  ${BOLD}2.${NC} Cache apt..."
    apt autoclean > /dev/null 2>&1
    apt clean > /dev/null 2>&1
    MSG_OK "OK"

    echo -e "  ${BOLD}3.${NC} Journal log..."
    journalctl --vacuum-size=50M > /dev/null 2>&1 && MSG_OK "50MB"

    echo -e "  ${BOLD}4.${NC} Temporary files..."
    rm -rf /tmp/* /var/tmp/* 2>/dev/null
    MSG_OK "OK"

    echo -e "  ${BOLD}5.${NC} Log lama..."
    find /var/log -name "*.gz" -o -name "*.old" -o -name "*.1" 2>/dev/null | xargs rm -f 2>/dev/null || true
    MSG_OK "OK"

    local freed
    freed=$(df -h / | awk 'NR==2 {print $4}')
    echo ""
    MSG_OK "Disk tersedia: ${YELLOW}$freed${NC}"
    PRESS_ENTER
}
