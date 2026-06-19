#!/bin/bash
# AIO Installer — AdBlock + Squid + Landing Page + File Manager
# Untuk X96Mini / B860H v1 (Armbian)
# Usage: sudo bash install.sh

# === LOAD MODULES ===
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
for mod in common detect squid adblock webserver landing landing-api filemanager sdcard optimize cache; do
    mod_file="$SCRIPT_DIR/modules/${mod}.sh"
    [ -f "$mod_file" ] && source "$mod_file"
done

ROOT_CHECK

# DNS harus working sebelum apa pun — ini fix utama untuk error "Could not resolve host"
chattr -i /etc/resolv.conf 2>/dev/null || true
DNS_SAFE

# Trap: pastikan DNS publik saat exit (apapun penyebabnya)
trap 'chattr -i /etc/resolv.conf 2>/dev/null; DNS_PUBLIC' EXIT

CONFLICTS=()

# === MENU UTAMA ===
MAIN_MENU() {
    BANNER
    SYSINFO

    echo -e "${BLUE}${BOLD}━━━ PILIH INSTALASI ━━━${NC}"
    echo ""
    echo -e "  ${CYAN}[1]${NC} ${BOLD}Instal Landing Page${NC}   ${DIM}(Dashboard 4 tema)${NC}"
    echo -e "  ${CYAN}[2]${NC} ${BOLD}Instal File Manager${NC}   ${DIM}(Akses root + folder default)${NC}"
    echo -e "  ${CYAN}[3]${NC} ${BOLD}Instal Ad-Block${NC}       ${DIM}(DNS blocker + Filter INDO)${NC}"
    echo -e "  ${CYAN}[4]${NC} ${BOLD}Instal Squid${NC}          ${DIM}(Proxy caching)${NC}"
    echo ""
    echo -e "  ${CYAN}[5]${NC} ${BOLD}Instal Semua${NC}          ${DIM}(Landing + FM + AdBlock + Squid)${NC}"
    echo -e "  ${CYAN}[6]${NC} ${RED}${BOLD}Hapus Semua${NC}      ${DIM}(Uninstall bersih)${NC}"
    echo ""
    echo -e "  ${CYAN}[7]${NC} ${BOLD}Cache Monitor${NC}         ${DIM}(Monitoring + Browser Extension)${NC}"
    echo ""
    echo -e "  ${CYAN}[0]${NC} Keluar"
    echo ""

    local choice
    choice=$(MENU_CHOICE "Pilih" 0 7)
    echo ""

    case "$choice" in
        1) INSTALL_LANDING ;;
        2) INSTALL_FILEMANAGER ;;
        3) INSTALL_ADBLOCK ;;
        4) INSTALL_SQUID ;;
        5) INSTALL_ALL ;;
        6) UNINSTALL_ALL ;;
        7) INSTALL_CACHE_MONITOR ;;
        0) echo -e "${DIM}Keluar.${NC}"; exit 0 ;;
    esac

    MAIN_MENU
}

# === SYSINFO ===
SYSINFO() {
    echo -e "${BLUE}${BOLD}━━━ SYSTEM ━━━${NC}"
    echo -e "  ${DIM}Hostname :${NC} $(hostname)"
    echo -e "  ${DIM}Kernel   :${NC} $(uname -r)"
    echo -e "  ${DIM}Arch     :${NC} $(uname -m)"
    echo -e "  ${DIM}Memory   :${NC} $(free -h | awk '/^Mem:/ {print $2}')"
    echo -e "  ${DIM}Disk     :${NC} $(df -h / | awk 'NR==2 {print $4}') free"
    echo ""

    local iface ip_addr
    iface=$(GET_IP)
    ip_addr=$(GET_IP_ADDR "$iface")
    echo -e "  ${DIM}IP  :${NC} ${GREEN}$ip_addr${NC}"
    echo ""

    # Status aplikasi terinstall
    echo -e "  ${DIM}Aplikasi terinstall:${NC}"
    command -v squid &>/dev/null && echo -e "    ${GREEN}✓${NC} Squid-Cache" || echo -e "    ${DIM}○${NC} Squid-Cache"
    command -v dnsmasq &>/dev/null && echo -e "    ${GREEN}✓${NC} AdBlock (dnsmasq)" || echo -e "    ${DIM}○${NC} AdBlock (dnsmasq)"
    command -v nginx &>/dev/null && echo -e "    ${GREEN}✓${NC} Nginx" || echo -e "    ${DIM}○${NC} Nginx"
    DETECT_LANDING_PAGE && echo -e "    ${GREEN}✓${NC} Landing Page" || echo -e "    ${DIM}○${NC} Landing Page"
    DETECT_FILEMANAGER && echo -e "    ${GREEN}✓${NC} File Manager" || echo -e "    ${DIM}○${NC} File Manager"
    mount | grep -q "/mnt/sdcard" && echo -e "    ${GREEN}✓${NC} SDCard Ter-mount" || echo -e "    ${DIM}○${NC} SDCard Belum di-mount"
    echo ""
}

# === INSTALL ALL ===
INSTALL_ALL() {
    clear
    MSG_TITLE "INSTAL SEMUA"
    echo ""
    MSG_WARN "Akan menginstall: Landing Page + File Manager + AdBlock + Squid"
    CONFIRM "Lanjutkan?" || return

    INSTALL_LANDING
    INSTALL_FILEMANAGER
    INSTALL_ADBLOCK
    INSTALL_SQUID
    INSTALL_CACHE_MONITOR

    local iface ip_addr
    iface=$(GET_IP)
    ip_addr=$(GET_IP_ADDR "$iface")

    clear
    echo -e "${GREEN}${BOLD}"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "      INSTALASI SELESAI!"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo -e "${NC}"
    echo -e "  ${BOLD}Landing Page${NC}  ${CYAN}http://$ip_addr${NC}"
    echo -e "  ${BOLD}File Manager${NC}  ${CYAN}http://$ip_addr/filemanager/${NC}"
    echo -e "  ${BOLD}Squid Proxy${NC}   ${CYAN}http://$ip_addr:3128${NC} (cache max 10GB)"
    echo -e "  ${BOLD}AdBlock DNS${NC}   ${CYAN}$ip_addr (port 53)${NC}"
    echo -e "  ${BOLD}Cache Monitor${NC} ${CYAN}http://$ip_addr/cache-monitor/${NC}"
    echo ""
    echo -e "  ${DIM}Gunakan theme selector di landing page untuk ganti tema${NC}"
    echo -e "  ${DIM}File manager bisa akses root, /var/www, dan folder default${NC}"
    echo -e "  ${DIM}Browser extension: Load folder browser-extension/ di chrome://extensions${NC}"
    echo ""
    PRESS_ENTER
}

# === UNINSTALL ALL ===
UNINSTALL_ALL() {
    clear
    MSG_TITLE "HAPUS SEMUA APLIKASI"
    echo ""
    echo -e "  ${RED}${BOLD}Akan dihapus:${NC}"
    echo -e "    • Squid (package + config + cache)"
    echo -e "    • dnsmasq (package + config + adblock)"
    echo -e "    • Nginx + PHP (package + config)"
    echo -e "    • Landing Page + File Manager"
    echo -e "    • Cache Monitor + Extension"
    echo -e "    • Cron job update adblock"
    echo -e "    • Firewall rules"
    echo ""
    CONFIRM "Lanjutkan?" "n" || return

    REMOVE_SQUID
    REMOVE_ADBLOCK
    REMOVE_WEBSERVER
    REMOVE_LANDING
    REMOVE_FILEMANAGER
    REMOVE_CACHE_MONITOR

    CLEANUP_APT
    MSG_OK "Semua aplikasi berhasil dihapus"
    PRESS_ENTER
}

# === MAIN ===
MAIN_MENU
