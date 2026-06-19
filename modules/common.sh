#!/bin/bash
# Library fungsi umum untuk AIO Installer

RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'
BLUE='\033[0;34m'; CYAN='\033[0;36m'; MAGENTA='\033[0;35m'
BOLD='\033[1m'; DIM='\033[2m'; NC='\033[0m'

PUBLIC_NS="nameserver 1.1.1.1\nnameserver 8.8.8.8"

# ============================================================
# DNS — ini yang paling kritis, semua fungsi lain bergantung padanya
# Aturan ketat:
#   - /etc/resolv.conf TIDAK PERNAH dikunci dengan chattr +i
#   - DNS publik (1.1.1.1, 8.8.8.8) HARUS selalu ada di resolv.conf
#   - localhost (127.0.0.1) boleh ditambahkan hanya sebagai PREFERRED,
#     bukan satu-satunya DNS
#   - Setiap fungsi yang menyentuh resolv.conf wajib panggil DNS_SAFE dulu
# ============================================================

# Buka kunci immutable, pastikan resolv.conf berisi DNS publik yang bekerja
DNS_SAFE() {
    chattr -i /etc/resolv.conf 2>/dev/null || true
    local dns
    dns=$(cat /etc/resolv.conf 2>/dev/null)
    if ! echo "$dns" | grep -qE "^nameserver\s+(1\.1\.1\.1|8\.8\.8\.8|9\.9\.9\.9)"; then
        echo -e "  ${YELLOW}DNS tidak aman, set ke publik...${NC}"
        printf "$PUBLIC_NS\n" > /etc/resolv.conf
    fi
    if ! nslookup google.com 8.8.8.8 2>/dev/null >/dev/null; then
        echo -e "  ${YELLOW}DNS publik tidak bisa resolve, coba metode alternatif...${NC}"
        echo "nameserver 1.1.1.1" > /etc/resolv.conf
        sleep 1
        if ! nslookup google.com 1.1.1.1 2>/dev/null >/dev/null; then
            echo -e "  ${YELLOW}Coba gateway sebagai DNS...${NC}"
            local gw
            gw=$(ip route 2>/dev/null | grep default | awk '{print $3}' | head -1)
            [ -n "$gw" ] && echo "nameserver $gw" > /etc/resolv.conf
        fi
    fi
}

# Tambah localhost (127.0.0.1) sebagai preferred DNS,
# tapi publik tetap ada sebagai fallback.
# Fungsi ini HANYA dipanggil setelah dnsmasq terverifikasi running.
DNS_USE_LOCAL() {
    sleep 2
    if ! systemctl is-active --quiet dnsmasq 2>/dev/null; then
        MSG_WARN "dnsmasq belum running, DNS publik dipertahankan"
        return 1
    fi
    if ! nslookup google.com 127.0.0.1 2>/dev/null >/dev/null; then
        MSG_WARN "dnsmasq belum siap melayani query, DNS publik dipertahankan"
        return 1
    fi
    chattr -i /etc/resolv.conf 2>/dev/null || true
    cat > /etc/resolv.conf << 'EOF'
nameserver 127.0.0.1
nameserver 1.1.1.1
nameserver 8.8.8.8
EOF
    MSG_OK "DNS: localhost dnsmasq (fallback publik)"
}

# Kembalikan ke DNS publik saja
DNS_PUBLIC() {
    chattr -i /etc/resolv.conf 2>/dev/null || true
    printf "$PUBLIC_NS\n" > /etc/resolv.conf
    MSG_OK "DNS: publik (1.1.1.1, 8.8.8.8)"
}

ROOT_CHECK() {
    [ "$EUID" -ne 0 ] && { echo -e "${RED}${BOLD}[!] sudo bash $0${NC}"; exit 1; }
}

BANNER() {
    clear
    echo ""
    echo -e "  ${CYAN}╔══════════════════════════════════════════════════╗${NC}"
    echo -e "  ${CYAN}║${NC}      ${BOLD}${MAGENTA}░▀▐▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▌▀░${NC}                      ${CYAN}║${NC}"
    echo -e "  ${CYAN}║${NC}      ${BOLD}${MAGENTA}▄█▓▒░ADBLOCK ░▒▓█▄${NC}                      ${CYAN}║${NC}"
    echo -e "  ${CYAN}║${NC}      ${BOLD}${MAGENTA}▀▐▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▌▀${NC}                      ${CYAN}║${NC}"
    echo -e "  ${CYAN}║${NC}  ${BOLD}${YELLOW}AIO INSTALLER${NC} — Squid + AdBlock + Web UI   ${CYAN}║${NC}"
    echo -e "  ${CYAN}║${NC}  ${DIM}Untuk X96Mini / B860H (Armbian)${NC}             ${CYAN}║${NC}"
    echo -e "  ${CYAN}╚══════════════════════════════════════════════════╝${NC}"
    echo ""
}

LOADING() {
    local msg=$1 pid=$2 spin='⠋⠙⠹⠸⠼⠴⠦⠧⠇⠏' i=0
    while kill -0 "$pid" 2>/dev/null; do
        printf "\r${CYAN}%c${NC} %s" "${spin:$i:1}" "$msg"
        i=$(( (i + 1) % 10 )); sleep 0.1
    done
    printf "\r${GREEN}✓${NC} %s\n" "$msg"
}

RUN_BG() {
    local msg=$1; shift
    ("$@" > /dev/null 2>&1) &
    LOADING "$msg" $!
    wait $!; return $?
}

INSTALL_PKG() {
    local pkg=$1
    DNS_SAFE
    echo -ne "  ${DIM}Install ${CYAN}$pkg${NC}${DIM}...${NC} "
    if dpkg -s "$pkg" >/dev/null 2>&1; then echo -e "${GREEN}✓${NC} (sudah)"; return 0; fi
    local logfile
    logfile=$(mktemp)
    apt install -y "$pkg" > "$logfile" 2>&1; local ret=$?
    if [ $ret -ne 0 ]; then
        echo ""
        grep -E '(^E:|^W:|tidak dapat|unable|could not)' "$logfile" | head -3 | while read -r line; do
            echo -e "  ${RED}${line}${NC}"
        done
        rm -f "$logfile"; return 1
    fi
    rm -f "$logfile"; echo -e "${GREEN}✓${NC}"; return 0
}

APT_UPDATE() {
    DNS_SAFE
    echo -e "  ${DIM}Update package list...${NC}"
    RUN_BG "Memperbarui package list" apt update -qq
}

GET_IP() {
    local iface
    iface=$(ip route get 8.8.8.8 2>/dev/null | awk '{print $5; exit}')
    [ -z "$iface" ] && iface=$(ip link show | grep -E "^2:" | awk '{print $2}' | tr -d ':')
    echo "$iface"
}

GET_IP_ADDR() {
    local iface=$1
    [ -z "$iface" ] && iface=$(GET_IP)
    ip addr show "$iface" 2>/dev/null | grep "inet " | awk '{print $2}' | cut -d/ -f1 | head -1
}

GET_SUBNET() {
    local iface=$1 ip_addr=$2
    [ -z "$iface" ] && iface=$(GET_IP)
    [ -z "$ip_addr" ] && ip_addr=$(GET_IP_ADDR "$iface")
    local subnet
    subnet=$(ip route 2>/dev/null | grep -E "link src $ip_addr|$iface.*proto kernel" | grep -oP '\d+\.\d+\.\d+\.\d+/\d+' | head -1)
    [ -z "$subnet" ] && subnet=$(ip route 2>/dev/null | grep "$iface" | grep -oP '\d+\.\d+\.\d+\.\d+/\d+' | head -1)
    [ -z "$subnet" ] && subnet="192.168.1.0/24"
    echo "$subnet"
}

UFW_ALLOW() { command -v ufw &> /dev/null && ufw allow "$1" comment "$2" > /dev/null 2>&1 || true; }
UFW_DENY()  { command -v ufw &> /dev/null && ufw delete allow "$1" > /dev/null 2>&1 || true; }

MSG_OK()    { echo -e "  ${GREEN}✓${NC} $1"; }
MSG_FAIL()  { echo -e "  ${RED}✗${NC} $1"; }
MSG_INFO()  { echo -e "  ${CYAN}ℹ${NC} $1"; }
MSG_WARN()  { echo -e "  ${YELLOW}⚠${NC} $1"; }
MSG_TITLE() { echo -e "${BLUE}${BOLD}━━━ $1 ━━━${NC}"; }

PRESS_ENTER() { echo -e "${DIM}Tekan Enter untuk kembali...${NC}"; read -r; }

BACKUP_FILE() {
    local file=$1
    [ -f "$file" ] && cp "$file" "${file}.bak.$(date +%Y%m%d%H%M%S)" 2>/dev/null || true
}

RESTART_SERVICE() {
    local svc=$1
    systemctl restart "$svc" 2>/dev/null || systemctl start "$svc" 2>/dev/null
    sleep 1
    if systemctl is-active --quiet "$svc" 2>/dev/null; then MSG_OK "$svc berjalan"; return 0
    else MSG_FAIL "$svc gagal start"; return 1; fi
}

SERVICE_ACTIVE() { systemctl is-active --quiet "$1" 2>/dev/null; }
SERVICE_EXISTS() { systemctl list-units --type=service --all 2>/dev/null | grep -q "$1"; }

CLEANUP_APT() {
    apt autoremove -y > /dev/null 2>&1 || true
    apt autoclean > /dev/null 2>&1 || true
}

PORT_CHECK() {
    local port=$1
    ss -tuln 2>/dev/null | grep -q ":$port " && return 0
    lsof -i :"$port" 2>/dev/null | grep -q LISTEN && return 0
    return 1
}

PORT_FIND() {
    local port=$1 max_port=$((port + 100))
    while [ "$port" -le "$max_port" ]; do
        ! PORT_CHECK "$port" && { echo "$port"; return 0; }
        port=$((port + 1))
    done
    echo ""; return 1
}

CONFIRM() {
    local prompt=$1 default=${2:-y}
    local yn
    if [ "$default" = "y" ]; then echo -ne "${BOLD}$prompt [Y/n]:${NC} "
    else echo -ne "${BOLD}$prompt [y/N]:${NC} "; fi
    read -r yn
    if [ "$default" = "y" ]; then [[ "$yn" =~ ^[Nn] ]] && return 1 || return 0
    else [[ "$yn" =~ ^[Yy] ]] && return 0 || return 1; fi
}

MENU_CHOICE() {
    local prompt=$1 min=$2 max=$3 choice
    while true; do
        echo -ne "${BOLD}$prompt [${min}-${max}]:${NC} "
        read -r choice
        [[ "$choice" =~ ^[0-9]+$ ]] && [ "$choice" -ge "$min" ] && [ "$choice" -le "$max" ] && { echo "$choice"; return 0; }
        echo -e "${RED}Pilihan tidak valid${NC}"
    done
}

FORMAT_BYTES() {
    local bytes=$1
    if [ "$bytes" -lt 1024 ]; then echo "${bytes}B"
    elif [ "$bytes" -lt 1048576 ]; then echo "$((bytes / 1024))KB"
    elif [ "$bytes" -lt 1073741824 ]; then echo "$((bytes / 1048576))MB"
    else echo "$((bytes / 1073741824))GB"; fi
}

APP_DETECT() {
    local app_name=$1; shift
    local related=("$@") found=()
    for bin in "${related[@]}"; do command -v "$bin" &>/dev/null && found+=("$bin (binary)"); done
    for svc in "${related[@]}"; do systemctl is-enabled --quiet "$svc" 2>/dev/null && found+=("$svc (service)"); done
    if [ ${#found[@]} -gt 0 ]; then
        echo -e "  ${YELLOW}Aplikasi serupa ditemukan:${NC}"
        for f in "${found[@]}"; do echo -e "    ${RED}◈${NC} $f"; done
        return 0
    fi
    return 1
}

APP_MENU() {
    local app_name=$1
    echo ""
    echo -e "  ${BOLD}Pilih aksi untuk $app_name:${NC}"
    echo -e "  ${CYAN}[1]${NC} Update aplikasi"
    echo -e "  ${CYAN}[2]${NC} Hapus aplikasi"
    echo -e "  ${CYAN}[3]${NC} Hapus dan Install versi terbaru"
    echo -e "  ${CYAN}[0]${NC} Skip / Lewati"
    echo ""
    echo "$(MENU_CHOICE "Pilih aksi" 0 3)"
}
