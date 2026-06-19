#!/bin/bash
# Module: Deteksi konflik, port, dan aplikasi sejenis
# Sumber: modules/detect.sh

# Deteksi dan nonaktifkan service yang konflik
DETECT_DISABLE_CONFLICTS() {
    local filter="$1"

    if [ "$filter" = "dns" ] || [ "$filter" = "all" ]; then
        echo -e "  ${DIM}Memeriksa konflik DNS...${NC}"
        for svc in systemd-resolved pihole-FTL adguardhome bind9 unbound stubby dnscrypt-proxy dnsmasq; do
            systemctl is-active --quiet "$svc" 2>/dev/null && CONFLICTS+=("$svc (running)")
            systemctl is-enabled --quiet "$svc" 2>/dev/null && CONFLICTS+=("$svc (enabled)")
        done
        command -v pihole &> /dev/null && ! systemctl is-enabled --quiet pihole-FTL 2>/dev/null && CONFLICTS+=("pihole (binary)")
        [ -f /opt/AdGuardHome/AdGuardHome ] && ! systemctl is-enabled --quiet adguardhome 2>/dev/null && CONFLICTS+=("AdGuard Home (binary)")
    fi

    if [ "$filter" = "proxy" ] || [ "$filter" = "all" ]; then
        echo -e "  ${DIM}Memeriksa konflik Proxy...${NC}"
        for svc in privoxy tinyproxy haproxy squid; do
            systemctl is-active --quiet "$svc" 2>/dev/null && CONFLICTS+=("$svc (running)")
            systemctl is-enabled --quiet "$svc" 2>/dev/null && CONFLICTS+=("$svc (enabled)")
        done
    fi

    if [ "$filter" = "webserver" ] || [ "$filter" = "all" ]; then
        echo -e "  ${DIM}Memeriksa konflik Web Server...${NC}"
        for svc in nginx apache2 lighttpd; do
            systemctl is-active --quiet "$svc" 2>/dev/null && CONFLICTS+=("$svc (running)")
            systemctl is-enabled --quiet "$svc" 2>/dev/null && CONFLICTS+=("$svc (enabled)")
        done
    fi

    if [ ${#CONFLICTS[@]} -eq 0 ]; then
        MSG_OK "Tidak ada konflik"
        return 0
    fi

    MSG_WARN "Konflik ditemukan:"
    for c in "${CONFLICTS[@]}"; do echo -e "    ${RED}◈${NC} $c"; done
    echo ""
    MSG_INFO "Akan dinonaktifkan (backup config otomatis)"
    CONFIRM "Lanjutkan?" || { MSG_INFO "Dibatalkan"; return 1; }

    if systemctl is-active --quiet systemd-resolved 2>/dev/null; then
        MSG_WARN "systemd-resolved akan dinonaktifkan. Memasang DNS fallback..."
        rm -f /etc/resolv.conf
        cat > /etc/resolv.conf << 'RESOLV'
nameserver 1.1.1.1
nameserver 8.8.8.8
RESOLV
        chattr -i /etc/resolv.conf 2>/dev/null || true
        chattr +i /etc/resolv.conf 2>/dev/null || true
        MSG_OK "DNS fallback: 1.1.1.1, 8.8.8.8"
    fi

    local svc_list=""
    [ "$filter" = "dns" ] || [ "$filter" = "all" ] && svc_list="$svc_list systemd-resolved pihole-FTL adguardhome bind9 unbound stubby dnscrypt-proxy dnsmasq"
    [ "$filter" = "proxy" ] || [ "$filter" = "all" ] && svc_list="$svc_list privoxy tinyproxy haproxy squid"
    [ "$filter" = "webserver" ] || [ "$filter" = "all" ] && svc_list="$svc_list nginx apache2 lighttpd"

    for svc in $svc_list; do
        systemctl is-active --quiet "$svc" 2>/dev/null || continue
        case "$svc" in
            dnsmasq) [ -f /etc/dnsmasq.conf ] && BACKUP_FILE /etc/dnsmasq.conf ;;
            squid)   [ -f /etc/squid/squid.conf ] && BACKUP_FILE /etc/squid/squid.conf ;;
            nginx)   [ -d /etc/nginx ] && tar czf "/etc/nginx.bak.$(date +%Y%m%d%H%M%S).tar.gz" /etc/nginx 2>/dev/null || true ;;
        esac
        systemctl stop "$svc" 2>/dev/null || true
        systemctl is-active --quiet "$svc" 2>/dev/null && { pkill -9 -x "$svc" 2>/dev/null || true; sleep 1; }
        systemctl disable "$svc" 2>/dev/null || true
    done
    MSG_OK "Konflik dibersihkan"
    return 0
}

# Cek port dan beri rekomendasi
PORT_CHECK_ADVANCED() {
    local port=$1 service_name=$2
    echo -e "  ${DIM}Memeriksa port $port ($service_name)...${NC}"

    if PORT_CHECK "$port"; then
        local used_by
        used_by=$(ss -tuln 2>/dev/null | grep ":$port " | awk '{print $1, $5}' | head -1)
        MSG_WARN "Port $port sudah dipakai: $used_by"

        local new_port
        new_port=$(PORT_FIND "$((port + 1))")
        if [ -n "$new_port" ]; then
            MSG_INFO "Port tersedia: $new_port"
            if CONFIRM "Gunakan port $new_port?"; then
                echo "$new_port"
                return 0
            fi
        else
            MSG_FAIL "Tidak ada port kosong di sekitar $port"
        fi
        echo ""
        return 1
    fi
    echo "$port"
    return 0
}

# Deteksi web server yang terinstall
DETECT_WEBSERVER() {
    if command -v nginx &>/dev/null; then
        echo "nginx"
    elif command -v apache2 &>/dev/null; then
        echo "apache2"
    elif command -v lighttpd &>/dev/null; then
        echo "lighttpd"
    else
        echo ""
    fi
}

# Cek apakah landing page sudah terdeploy
DETECT_LANDING_PAGE() {
    [ -f /var/www/html/index.html ] && grep -q "AIO Landing" /var/www/html/index.html 2>/dev/null && return 0
    [ -f /var/www/landing/index.html ] && return 0
    [ -d /usr/share/nginx/landing ] && return 0
    return 1
}

# Cek apakah file manager sudah terdeploy
DETECT_FILEMANAGER() {
    [ -f /var/www/html/filemanager/index.php ] && return 0
    [ -f /var/www/filemanager/index.php ] && return 0
    return 1
}

# Cek SDCard
DETECT_SDCARD() {
    local sdcard_dev=""
    for dev in mmcblk1 mmcblk2 sda sdb; do
        if [ -b "/dev/${dev}" ] && ! mount | grep -q "/dev/${dev}.* / "; then
            sdcard_dev="/dev/${dev}"
            break
        fi
    done

    if [ -n "$sdcard_dev" ]; then
        local partitions
        partitions=$(lsblk -ln "$sdcard_dev" 2>/dev/null | grep -c part || echo 0)
        if [ "$partitions" -gt 0 ]; then
            local first_part
            first_part=$(lsblk -ln "$sdcard_dev" 2>/dev/null | grep part | head -1 | awk '{print $1}')
            echo "/dev/$first_part"
        else
            echo "$sdcard_dev"
        fi
    else
        echo ""
    fi
}
