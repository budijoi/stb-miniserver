#!/bin/bash
# Bootstrap Installer — fix DNS dulu, baru clone & install
# Kalau DNS error (Could not resolve host), jalankan ini:
#   echo "nameserver 1.1.1.1" | sudo tee /etc/resolv.conf
#   wget -qO- https://raw.githubusercontent.com/budijoi/adblock-n-squid/main/bootstrap.sh | sudo bash

set -e

RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'
BOLD='\033[1m'; NC='\033[0m'

# Fix DNS jika mengarah ke localhost
CURRENT_DNS=$(head -1 /etc/resolv.conf 2>/dev/null || echo "")
if echo "$CURRENT_DNS" | grep -q "127.0.0.1"; then
    echo -e "${YELLOW}[!] DNS mengarah ke localhost, set publik dulu...${NC}"
    chattr -i /etc/resolv.conf 2>/dev/null || true
    cat > /etc/resolv.conf << 'EOF'
nameserver 1.1.1.1
nameserver 8.8.8.8
EOF
    echo -e "${GREEN}[✓] DNS publik: 1.1.1.1, 8.8.8.8${NC}"
fi

# Test DNS
if ! nslookup github.com 1.1.1.1 >/dev/null 2>&1; then
    echo -e "${RED}[!] DNS masih gagal. Coba manual:${NC}"
    echo -e "  ${BOLD}echo 'nameserver 1.1.1.1' | sudo tee /etc/resolv.conf${NC}"
    exit 1
fi

echo -e "${GREEN}[✓] DNS berfungsi${NC}"

# Clone repo
INSTALL_DIR="/opt/adblock-n-squid"
if [ -d "$INSTALL_DIR" ]; then
    echo -e "${YELLOW}[!] Repo sudah ada, update...${NC}"
    cd "$INSTALL_DIR" && git pull
else
    echo -e "${GREEN}[*] Clone repo...${NC}"
    git clone https://github.com/budijoi/adblock-n-squid.git "$INSTALL_DIR"
fi

# Jalankan installer
echo ""
echo -e "${GREEN}[✓] Siap! Menjalankan installer...${NC}"
echo ""
cd "$INSTALL_DIR" && sudo bash install.sh
