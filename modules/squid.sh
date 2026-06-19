#!/bin/bash
# Module: Install dan Konfigurasi Squid-Cache
# Sumber: modules/squid.sh

SQUID_CONF="/etc/squid/squid.conf"

INSTALL_SQUID() {
    clear
    MSG_TITLE "INSTALL SQUID-CACHE"

    local IFACE IP_ADDR SUBNET
    IFACE=$(GET_IP)
    IP_ADDR=$(GET_IP_ADDR "$IFACE")
    SUBNET=$(GET_SUBNET "$IFACE" "$IP_ADDR")

    # Cek apakah sudah terinstall
    if command -v squid &>/dev/null; then
        MSG_WARN "Squid sudah terinstall"
        local action
        action=$(APP_MENU "Squid-Cache")
        case "$action" in
            1) # Update
                MSG_INFO "Memperbarui Squid..."
                apt install --only-upgrade -y squid > /dev/null 2>&1 || true
                MSG_OK "Squid diperbarui"
                RESTART_SERVICE squid
                PRESS_ENTER
                return 0
                ;;
            2) # Hapus
                REMOVE_SQUID
                PRESS_ENTER
                return 0
                ;;
            3) # Hapus dan install ulang
                REMOVE_SQUID
                ;;
            0) # Skip
                MSG_INFO "Melewati instalasi Squid"
                return 0
                ;;
        esac
    fi

    APT_UPDATE
    CONFLICTS=()
    DETECT_DISABLE_CONFLICTS "proxy" || return

    echo -e "  ${DIM}Menginstall Squid...${NC}"
    INSTALL_PKG squid || return

    BACKUP_FILE "$SQUID_CONF"

    local SQUID_PORT
    SQUID_PORT=$(PORT_CHECK_ADVANCED 3128 "Squid Proxy")
    [ -z "$SQUID_PORT" ] && SQUID_PORT=3128
    [ "$SQUID_PORT" = "3128" ] || MSG_INFO "Squid akan menggunakan port $SQUID_PORT"

    mkdir -p /etc/squid

    cat > "$SQUID_CONF" << CONF
# Squid Cache Config — AIO Installer
# LAN: $SUBNET | IP: $IP_ADDR | Port: $SQUID_PORT

acl localnet src 0.0.0.1-0.255.255.255
acl localnet src 10.0.0.0/8
acl localnet src 100.64.0.0/10
acl localnet src 169.254.0.0/16
acl localnet src 172.16.0.0/12
acl localnet src 192.168.0.0/16
acl localnet src fc00::/7
acl localnet src fe80::/10
CONF

    ! SUBNET_COVERED "$SUBNET" && echo "acl localnet src $SUBNET" >> "$SQUID_CONF"

    cat >> "$SQUID_CONF" << CONF
acl SSL_ports port 443
acl Safe_ports port 80
acl Safe_ports port 21
acl Safe_ports port 443
acl Safe_ports port 70
acl Safe_ports port 210
acl Safe_ports port 1025-65535
acl Safe_ports port 280
acl Safe_ports port 488
acl Safe_ports port 591
acl Safe_ports port 777
http_access deny !Safe_ports
http_access deny CONNECT !SSL_ports
http_access allow localhost manager
http_access deny manager
http_access allow localhost
http_access deny to_localhost
http_access deny to_linklocal
http_access allow localnet
http_access deny all
http_port $SQUID_PORT
cache_mem 256 MB
maximum_object_size_in_memory 512 KB
minimum_object_size 0 KB
maximum_object_size 64 MB
cache_dir ufs /var/spool/squid 10240 16 256
dns_nameservers 1.1.1.1 8.8.8.8
memory_replacement_policy heap GDSF
cache_replacement_policy heap LFUDA
access_log daemon:/var/log/squid/access.log squid
cache_log /var/log/squid/cache.log
coredump_dir /var/spool/squid
refresh_pattern ^ftp:           1440    20%     10080
refresh_pattern -i (/cgi-bin/|\?) 0     0%      0
refresh_pattern .               0       20%     4320
CONF

    squid -k parse 2>/dev/null | grep -q "unrecognized.*dns_order" && sed -i '/^dns_order/d' "$SQUID_CONF" 2>/dev/null || true
    mkdir -p /var/log/squid && chown proxy:proxy /var/log/squid 2>/dev/null || true
    squid -z > /dev/null 2>&1 || true
    MSG_OK "Cache directory siap"

    systemctl restart squid 2>/dev/null || systemctl start squid 2>/dev/null || true
    systemctl enable squid 2>/dev/null || true

    UFW_ALLOW "${SQUID_PORT}/tcp" "Squid Proxy"

    if SERVICE_ACTIVE squid; then
        echo ""
        MSG_OK "Squid berjalan di http://$IP_ADDR:$SQUID_PORT"
        echo ""
    else
        MSG_FAIL "Squid gagal start. Cek: sudo journalctl -u squid --no-pager -n 30"
    fi
    PRESS_ENTER
}

REMOVE_SQUID() {
    MSG_TITLE "HAPUS SQUID"
    CONFIRM "Hapus Squid?" || return

    systemctl stop squid 2>/dev/null || true
    pkill -9 squid 2>/dev/null || true
    sleep 1
    apt remove --purge -y squid > /dev/null 2>&1 || true
    rm -rf /etc/squid /var/spool/squid /var/log/squid
    UFW_DENY 3128/tcp
    CLEANUP_APT
    MSG_OK "Squid berhasil dihapus"
}

SUBNET_COVERED() {
    case "$1" in
        10.*) return 0 ;;
        192.168.*) return 0 ;;
        172.1[6-9].*|172.2[0-9].*|172.3[0-1].*) return 0 ;;
        100.6[4-9].*|100.1[0-1][0-9].*|100.12[0-7].*) return 0 ;;
        169.254.*) return 0 ;;
        fc*|fd*) return 0 ;;
        fe80:*) return 0 ;;
    esac
    return 1
}
