#!/bin/bash
# Bootstrap Installer — fix DNS, clone repo, jalankan installer
#
# Cara pakai (kalau DNS rusak, jalankan ini manual via SSH):
#   sudo bash -c "$(cat <<'CMD'
#   chattr -i /etc/resolv.conf 2>/dev/null
#   echo 'nameserver 1.1.1.1' > /etc/resolv.conf
#   CMD
#   )"
#   wget -qO- https://raw.githubusercontent.com/budijoi/adblock-n-squid/main/bootstrap.sh | sudo bash
#
# Atau copy file ini ke STB via USB/SCP, lalu:
#   sudo bash bootstrap.sh

set -euo pipefail

RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; BOLD='\033[1m'; NC='\033[0m'

echo -e "${BOLD}=== AIO Installer Bootstrap ===${NC}"
echo ""

# ========== FASE 1: Fix DNS ==========
echo -e "${BOLD}[1/3] Memeriksa DNS...${NC}"

# Buka immutable jika ada, set publik
chattr -i /etc/resolv.conf 2>/dev/null || true
CURRENT=$(head -1 /etc/resolv.conf 2>/dev/null || echo "")
if echo "$CURRENT" | grep -qE "127\.0\.0\.1|0\.0\.0\.0"; then
    echo -e "  ${YELLOW}DNS localhost, alihkan ke publik...${NC}"
    printf "nameserver 1.1.1.1\nnameserver 8.8.8.8\n" > /etc/resolv.conf
fi

# Verifikasi DNS berfungsi
DNS_OK=false
for ns in 1.1.1.1 8.8.8.8; do
    if nslookup google.com "$ns" 2>/dev/null >/dev/null; then
        DNS_OK=true; break
    fi
done

if [ "$DNS_OK" = false ]; then
    GW=$(ip route 2>/dev/null | grep default | awk '{print $3}' | head -1)
    if [ -n "$GW" ] && nslookup google.com "$GW" 2>/dev/null >/dev/null; then
        echo "nameserver $GW" > /etc/resolv.conf
        DNS_OK=true
    fi
fi

if [ "$DNS_OK" = false ]; then
    echo -e "${RED}[!] DNS GAGAL. Perbaiki manual:${NC}"
    echo -e "  ${BOLD}sudo chattr -i /etc/resolv.conf && echo 'nameserver 1.1.1.1' | sudo tee /etc/resolv.conf${NC}"
    echo -e "  ${BOLD}sudo bash $0${NC}"
    exit 1
fi

echo -e "  ${GREEN}[✓] DNS OK${NC}"

# ========== FASE 2: Clone / Update Repo ==========
echo ""
echo -e "${BOLD}[2/3] Clone repository...${NC}"

REPO_URL="https://github.com/budijoi/adblock-n-squid.git"
INSTALL_DIR="/opt/adblock-n-squid"

if ! command -v git &>/dev/null; then
    echo -e "  ${YELLOW}Git tidak ada, install...${NC}"
    apt update -qq && apt install -y git > /dev/null 2>&1
fi

if [ -d "$INSTALL_DIR" ]; then
    echo -e "  ${YELLOW}Repo sudah ada, update...${NC}"
    cd "$INSTALL_DIR" && git pull
else
    echo -e "  ${GREEN}[*] Clone ke $INSTALL_DIR${NC}"
    git clone "$REPO_URL" "$INSTALL_DIR"
fi

# ========== FASE 3: Jalankan Installer ==========
echo ""
echo -e "${BOLD}[3/3] Menjalankan installer...${NC}"
echo ""
cd "$INSTALL_DIR/stb-miniserver"
sudo bash install.sh
