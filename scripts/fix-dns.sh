#!/bin/bash
# Emergency DNS Recovery — fix resolv.conf yang terkunci atau rusak
# Jalankan: sudo bash fix-dns.sh

[ "$EUID" -ne 0 ] && { echo "[!] sudo bash $0"; exit 1; }

echo "=== Emergency DNS Recovery ==="
echo ""

# 1. Buka kunci immutable
if lsattr /etc/resolv.conf 2>/dev/null | grep -q "^....i"; then
    echo "  [*] File terkunci (chattr +i), buka..."
    chattr -i /etc/resolv.conf
    echo "  [✓] Kunci dibuka"
fi

# 2. Backup resolv.conf lama
cp /etc/resolv.conf /etc/resolv.conf.bak.emergency 2>/dev/null
echo "  [✓] Backup: /etc/resolv.conf.bak.emergency"

# 3. Tulis DNS publik
cat > /etc/resolv.conf << 'EOF'
nameserver 1.1.1.1
nameserver 8.8.8.8
EOF
echo "  [✓] DNS publik: 1.1.1.1, 8.8.8.8"

# 4. Verifikasi
sleep 1
if nslookup google.com 1.1.1.1 2>/dev/null >/dev/null; then
    echo "  [✓] DNS berfungsi!"
else
    # Coba gateway
    GW=$(ip route 2>/dev/null | grep default | awk '{print $3}' | head -1)
    if [ -n "$GW" ]; then
        echo "  [!] DNS publik gagal, coba gateway: $GW"
        echo "nameserver $GW" > /etc/resolv.conf
        sleep 1
        if nslookup google.com "$GW" 2>/dev/null >/dev/null; then
            echo "  [✓] DNS via gateway $GW berfungsi!"
        else
            echo "  [✗] DNS masih gagal. Cek koneksi jaringan."
        fi
    fi
fi

echo ""
echo "=== Selesai ==="
echo "Sekarang coba: ping -c 2 google.com"
