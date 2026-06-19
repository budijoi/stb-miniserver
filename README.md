# AIO Home Server — AdBlock + Squid + Landing Page + File Manager

Jadikan STB **X96Mini** (RAM 2GB/ROM 16GB) atau **B860H v1** (RAM 1GB/ROM 8GB) kamu sebagai **adblocker jaringan + caching proxy + web dashboard** — semua dalam satu perangkat. OS Armbian terinstall di **SDCard** sebagai storage utama.

---

## Fitur Lengkap

### 🛡️ AdBlock (dnsmasq)
- Blokir 2-3 juta domain iklan/tracker/malware dari 4 sumber global + filter **ABPindo** khusus Indonesia
- DNS caching hingga 10.000 domain
- Auto-update setiap jam 3 pagi via cron

### 🚀 Squid-Cache
- HTTP/HTTPS proxy caching hingga 2GB
- Mempercepat browsing dengan cache halaman web
- Auto-detect port tersedia jika 3128 sudah dipakai

### 🌐 Landing Page
- Dashboard informasi sistem real-time:
  - CPU Temperature & Usage
  - RAM, Storage, SWAP/ZRAM Usage
  - Network RX / TX (throughput)
  - Uptime
- Tombol navigasi cepat ke aplikasi terinstall
- Manajemen layanan: Start, Stop, Restart, Cek Status
- **4 Tema**: Default, Modern, Techno, Cute — bisa dipilih langsung dari UI

### 📁 File Manager
- Akses folder **root (/)**
- Akses folder **/var/www** untuk edit landing page
- Folder default: **My Document**, **My Music**, **My Pictures**, **My Video**
- Upload, download, edit, hapus, rename file/folder
- Editor teks internal untuk edit file langsung

### 💾 SDCard sebagai Storage Utama
- Auto-mount SDCard saat boot
- Redirect storage otomatis: apt cache, web root, squid cache, log, adblock list
- Symlink system agar semua data tersimpan di SDCard

### 🔧 AIO Installer
- Deteksi aplikasi sejenis → pilihan: **Update**, **Hapus**, **Install Ulang**
- Deteksi port yang sudah dipakai → cari port alternatif otomatis
- Install per komponen atau **All-In-One** (semua sekaligus)
- Optimasi perangkat STB (kernel tuning, TCP BBR, ZRAM, nonaktifkan service tidak perlu)
- Pembersihan sistem (cache, log, temporary files)

---

## Persyaratan

| Komponen | Minimal | Rekomendasi |
|---|---|---|
| Perangkat | X96Mini / B860H v1 | X96Mini (RAM 2GB) |
| RAM | 512 MB | 1-2 GB |
| Storage | 4 GB SDCard | 16-32 GB SDCard |
| Network | 100 Mbps | 100/1000 Mbps |
| OS | Armbian (kernel 5.x+) | Armbian Jammy / Focal |
| Akses | Root via SSH | — |

---

## Instalasi

### 1. Set IP Static

```bash
sudo nmtui
```

Atau via CLI:
```bash
sudo nano /etc/network/interfaces
```

Contoh konfigurasi:
```ini
auto eth0
iface eth0 inet static
    address 192.168.1.100
    netmask 255.255.255.0
    gateway 192.168.1.1
    dns-nameservers 1.1.1.1 8.8.8.8
```

### 2. Download Installer

SSH ke STB:
```bash
ssh root@192.168.1.100
```

Via Git:
```bash
apt install -y git
git clone https://github.com/budijoi/adblock-n-squid.git /opt/adblock-n-squid
cd /opt/adblock-n-squid
sudo bash install.sh
```

Via wget:
```bash
wget -O /tmp/adblock-n-squid.zip https://github.com/budijoi/adblock-n-squid/archive/refs/heads/main.zip
unzip /tmp/adblock-n-squid.zip -d /opt/
cd /opt/adblock-n-squid-main
sudo bash install.sh
```

### 3. Pilih Menu Installer

```
━━━ APLIKASI TERSEDIA ━━━

[1] Squid-Cache            (Proxy Caching)
[2] AdBlock (dnsmasq)      (DNS Adblocker + Filter INDO)
[3] Web Server             (Nginx + PHP)
[4] Landing Page           (Dashboard dengan tema)
[5] File Manager           (Akses root + folder default)
[6] SDCard Storage         (Mount & redirect storage)

[7] Install Semua          (Squid + AdBlock + Web + Landing + FM)

━━━ UTILITY ━━━

[8] Optimasi Perangkat     (Tuning kernel, BBR, ZRAM)
[9] Bersihkan Sistem       (Hapus sampah, log, cache)
[10] Hapus Semua           (Uninstall bersih)

[0] Keluar
```

Pilih **7** untuk instalasi lengkap, atau pilih komponen satu per satu.

### 4. Akses Landing Page

Buka browser di perangkat lain:
```
http://192.168.1.100
```

### 5. Akses File Manager

```
http://192.168.1.100/filemanager/
```

---

## Setting Perangkat Lain

### AdBlocker (set DNS)

**Windows:**
- Settings > Network & Internet > Change adapter options
- Klik kanan koneksi > Properties
- Pilih **Internet Protocol Version 4 (TCP/IPv4)** > Properties
- **Use the following DNS server addresses**
- Preferred DNS: `192.168.1.100`

PowerShell (admin):
```powershell
netsh interface ip set dns "Ethernet" static 192.168.1.100
```

**Android:**
- Settings > Wi-Fi > tap & tahan jaringan > Modify network
- Advanced > IP settings > Static
- DNS 1: `192.168.1.100`

**iPhone/iPad:**
- Settings > Wi-Fi > tap icon ⓘ
- Configure DNS > Manual
- Tambah `192.168.1.100`

### Cache Proxy (set proxy)

**Windows:**
- Settings > Network & Internet > Proxy
- Use a proxy server → ON
- Address: `192.168.1.100`, Port: `3128`

PowerShell (admin):
```powershell
netsh winhttp set proxy 192.168.1.100:3128
```

**Android:**
- Settings > Wi-Fi > Modify network > Advanced
- Proxy > Manual
- Hostname: `192.168.1.100`, Port: `3128`

Sambungkan keduanya untuk hasil maksimal: iklan hilang + browsing cepat.

---

## Tema Landing Page

Landing page memiliki 4 tema yang bisa dipilih langsung dari browser:

| Tema | Suasana |
|---|---|
| **Default** | Dark minimalis, aksen merah |
| **Modern** | Biru elegan, profesional |
| **Techno** | Hijau matrix, hacker style |
| **Cute** | Pink pastel, imut |

Tema tersimpan di localStorage browser, akan muncul kembali saat下次 kunjungan.

---

## File Manager

File manager bisa mengakses:
- **/ (root)** — seluruh filesystem
- **/var/www** — folder web untuk edit landing page
- **files/My Document**, **My Music**, **My Pictures**, **My Video** — folder default

Fitur:
- Upload file via drag & click
- Buat folder/file baru
- Edit file teks langsung di browser
- Hapus file/folder
- Navigasi breadcrumb

> ⚠️ Hati-hati saat mengedit file di folder root! Pastikan tidak menghapus file sistem.

---

## SDCard Setup

SDCard akan di-mount di `/mnt/sdcard` dan terintegrasi dengan sistem:

```
SDCard (/mnt/sdcard)
├── www/              → /var/www (symlink)
├── squid-cache/      → /var/spool/squid
├── squid-logs/       → /var/log/squid
├── adblock/          → /etc/adblock
└── apt-cache/        → /var/cache/apt/archives
```

Jalankan dari menu installer (option 6) atau langsung:
```bash
sudo bash scripts/mount-sdcard.sh
```

---

## Verifikasi

### Tes AdBlocker
```bash
# Domain iklan harus balik 0.0.0.0
nslookup doubleclick.net 192.168.1.100

# Domain normal harus balik IP asli
nslookup google.com 192.168.1.100
```

### Tes Cache Proxy
```bash
curl -I --proxy http://192.168.1.100:3128 https://google.com
```

Cek header X-Cache:
```bash
# Pertama: MISS
curl -I --proxy http://192.168.1.100:3128 https://cdn.jsdelivr.net/npm/bootstrap@5.3.0/dist/css/bootstrap.min.css 2>&1 | grep -i x-cache

# Kedua: HIT (sudah di-cache)
curl -I --proxy http://192.168.1.100:3128 https://cdn.jsdelivr.net/npm/bootstrap@5.3.0/dist/css/bootstrap.min.css 2>&1 | grep -i x-cache
```

---

## Perintah Berguna

### AdBlock (dnsmasq)
| Perintah | Fungsi |
|---|---|
| `sudo systemctl status dnsmasq` | Cek status |
| `sudo systemctl restart dnsmasq` | Restart |
| `sudo journalctl -u dnsmasq --no-pager -n 30` | Cek log |
| `sudo grep -c '^0.0.0.0' /etc/adblock/blocked.hosts` | Cek jumlah blokir |
| `sudo bash /usr/local/bin/update-adblock.sh` | Update manual adblock |

### Squid-Cache
| Perintah | Fungsi |
|---|---|
| `sudo systemctl status squid` | Cek status |
| `sudo systemctl restart squid` | Restart |
| `sudo tail -f /var/log/squid/access.log` | Log request real-time |
| `sudo squid -k info` | Informasi cache |
| `du -sh /var/spool/squid` | Ukuran cache di disk |

### Landing Page API
| Endpoint | Fungsi |
|---|---|
| `http://IP/api/stats` | JSON system stats |
| `http://IP/api/services` | JSON service status |
| `http://IP/api/service?name=squid&action=restart` | Control service |

---

## Update AdBlock List

Otomatis setiap jam 3 pagi via cron. Manual:
```bash
sudo bash /usr/local/bin/update-adblock.sh
```

Sumber blocklist:
| Sumber | Domain | Update |
|---|---|---|
| [StevenBlack Unified](https://github.com/StevenBlack/hosts) | adware + malware + tracking | Harian |
| [someonewhocares.org](https://someonewhocares.org/) | hosts-based blocking | Harian |
| [OISD Big](https://oisd.nl/) | comprehensive domain block | Harian |
| [ABPindo](https://github.com/ABPindo/indonesianadblockrules) | iklan Indonesia | Berkala |

---

## Struktur File

```
adblock-n-squid/
├── install.sh                  # AIO Installer (entry point)
├── update-adblock.sh           # AdBlock list updater
├── README.md                   # Dokumentasi ini
├── modules/
│   ├── common.sh               # Library fungsi umum
│   ├── detect.sh               # Deteksi konflik & port
│   ├── squid.sh                # Install Squid-Cache
│   ├── adblock.sh              # Install AdBlock (dnsmasq)
│   ├── webserver.sh            # Install Nginx + PHP
│   ├── landing.sh              # Deploy Landing Page
│   ├── landing-api.sh          # API backend landing page
│   ├── filemanager.sh          # Deploy File Manager
│   ├── sdcard.sh               # Mount SDCard & redirect
│   └── optimize.sh             # Optimasi perangkat
├── scripts/
│   └── mount-sdcard.sh         # Script mount SDCard (standalone)
└── web/
    ├── landing/                # Source landing page
    │   └── index.html
    └── filemanager/            # Source file manager
        └── index.php
```

---

## Troubleshooting

| Masalah | Penyebab | Solusi |
|---|---|---|
| Landing page error | Web server belum nyala | `sudo systemctl restart nginx` |
| API stats kosong | Endpoint API belum dipasang | Install ulang Landing Page |
| File manager error | PHP belum terinstall | Pilih option 3 (Web Server) dulu |
| SDCard tidak terdeteksi | Belum di-scan | `echo scan > /sys/class/mmc_host/mmc*/device/uevent` |
| Port 3128 sudah dipakai | Service lain | Installer otomatis cari port lain |
| Iklan masih muncul | Belum masuk blocklist | `sudo bash /usr/local/bin/update-adblock.sh` |
| dnsmasq gagal start | Port 53 konflik | `sudo lsof -i :53`, matikan service lain |
| Squid lambat | Cache masih kosong | Biarkan, akan cepat setelah beberapa kunjungan |

---

## Spesifikasi Perangkat

| Model | RAM | ROM | Status |
|---|---|---|---|
| **B860H v1** | 1 GB | 8 GB | ⚠️ Error (terbatas) |
| **X96Mini** | 2 GB | 16 GB | ✅ Recomended |
| **Ext SDCard** | — | Tergantung SDCard | ✅ Storage Utama |

---

## Kredit

- [Squid-Cache](http://www.squid-cache.org/)
- [dnsmasq](https://thekelleys.org.uk/dnsmasq/doc.html)
- [StevenBlack/hosts](https://github.com/StevenBlack/hosts)
- [someonewhocares.org](https://someonewhocares.org/)
- [OISD](https://oisd.nl/)
- [ABPindo](https://github.com/ABPindo/indonesianadblockrules)

---

## Lisensi

MIT
