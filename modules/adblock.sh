#!/bin/bash
# Module: Install AdBlock (dnsmasq)

ADBLOCK_DIR="/etc/adblock"
ADBLOCK_LIST="$ADBLOCK_DIR/blocked.hosts"
ADBLOCK_LOG="/var/log/adblock-update.log"
DNSMASQ_CONF="/etc/dnsmasq.conf"
ADBLOCK_UPDATER="/usr/local/bin/update-adblock.sh"

INSTALL_ADBLOCK() {
    clear
    MSG_TITLE "INSTALL AD-BLOCK (dnsmasq)"
    DNS_SAFE

    local IFACE IP_ADDR
    IFACE=$(GET_IP)
    IP_ADDR=$(GET_IP_ADDR "$IFACE")

    if command -v dnsmasq &>/dev/null; then
        MSG_WARN "dnsmasq sudah terinstall"
        case "$(APP_MENU "AdBlock")" in
            1) apt install --only-upgrade -y dnsmasq > /dev/null 2>&1 || true
               UPDATE_ADBLOCK_LISTS
               systemctl restart dnsmasq 2>/dev/null || true
               DNS_USE_LOCAL
               PRESS_ENTER; return 0 ;;
            2) REMOVE_ADBLOCK; PRESS_ENTER; return 0 ;;
            3) REMOVE_ADBLOCK ;;
            0) MSG_INFO "Skip"; PRESS_ENTER; return 0 ;;
        esac
    fi

    APT_UPDATE
    CONFLICTS=()
    DETECT_DISABLE_CONFLICTS "dns" || return

    INSTALL_PKG dnsmasq || return

    mkdir -p "$ADBLOCK_DIR" /etc/dnsmasq.d
    BACKUP_FILE "$DNSMASQ_CONF"

    cat > "$DNSMASQ_CONF" << EOF
interface=$IFACE
bind-interfaces
domain-needed
bogus-priv
no-resolv
server=1.1.1.1
server=8.8.8.8
cache-size=10000
addn-hosts=$ADBLOCK_LIST
conf-dir=/etc/dnsmasq.d/
EOF
    MSG_OK "Config dnsmasq ditulis"

    DEPLOY_UPDATER
    UPDATE_ADBLOCK_LISTS

    systemctl restart dnsmasq 2>/dev/null || systemctl start dnsmasq 2>/dev/null
    systemctl enable dnsmasq > /dev/null 2>&1 || true

    UFW_ALLOW 53/tcp "dnsmasq DNS"
    UFW_ALLOW 53/udp "dnsmasq DNS"

    local cron_job="0 3 * * * $ADBLOCK_UPDATER"
    (crontab -l 2>/dev/null | grep -v "update-adblock.sh"; echo "$cron_job") | crontab - 2>/dev/null || true
    MSG_OK "Cron: update adblock jam 3 pagi"

    if SERVICE_ACTIVE dnsmasq; then
        DNS_USE_LOCAL
        local count=0
        [ -f "$ADBLOCK_LIST" ] && count=$(grep -c "^0\.0\.0\.0" "$ADBLOCK_LIST" 2>/dev/null || echo 0)
        echo ""
        MSG_OK "AdBlock: DNS $IP_ADDR (port 53) — $count domain diblokir"
        echo ""
    else
        MSG_FAIL "dnsmasq gagal start. Cek: sudo journalctl -u dnsmasq --no-pager -n 30"
    fi
    PRESS_ENTER
}

REMOVE_ADBLOCK() {
    MSG_TITLE "HAPUS ADBLOCK"
    CONFIRM "Hapus?" || return
    systemctl stop dnsmasq 2>/dev/null || true
    pkill -9 dnsmasq 2>/dev/null || true
    sleep 1
    apt remove --purge -y dnsmasq > /dev/null 2>&1 || true
    rm -rf /etc/dnsmasq* /var/log/dnsmasq*
    rm -rf "$ADBLOCK_DIR" "$ADBLOCK_UPDATER" "$ADBLOCK_LOG"
    rm -f /etc/dnsmasq.d/adblock.conf
    crontab -l 2>/dev/null | grep -v "update-adblock.sh" | crontab - 2>/dev/null || true
    UFW_DENY 53/tcp; UFW_DENY 53/udp
    DNS_PUBLIC
    CLEANUP_APT
    MSG_OK "AdBlock berhasil dihapus"
}

DEPLOY_UPDATER() {
    local src_upd
    src_upd="$(dirname "$0")/update-adblock.sh"
    if [ -f "$src_upd" ]; then
        cp "$src_upd" "$ADBLOCK_UPDATER" && chmod +x "$ADBLOCK_UPDATER"
        MSG_OK "Updater dari lokal"
    elif [ ! -f "$ADBLOCK_UPDATER" ]; then
        DNS_SAFE
        curl -sSL -o "$ADBLOCK_UPDATER" "https://raw.githubusercontent.com/budijoi/adblock-n-squid/main/update-adblock.sh" 2>/dev/null && chmod +x "$ADBLOCK_UPDATER" || true
    fi
}

UPDATE_ADBLOCK_LISTS() {
    if [ -f "$ADBLOCK_UPDATER" ]; then
        bash "$ADBLOCK_UPDATER"
    else
        MSG_WARN "Updater tidak ditemukan"
        DEPLOY_UPDATER
        [ -f "$ADBLOCK_UPDATER" ] && bash "$ADBLOCK_UPDATER"
    fi
}
