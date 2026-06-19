#!/bin/bash
# Module: Squid Cache Monitor & Browser Extension
# Sumber: modules/cache.sh

CACHE_MONITOR_DIR="/var/www/html/cache-monitor"
CACHE_CLEANUP_SCRIPT="/usr/local/bin/clean-squid-cache.sh"
EXTENSION_DIR="/var/www/html/squid-extension"

INSTALL_CACHE_MONITOR() {
    clear
    MSG_TITLE "SQUID CACHE MONITOR & EXTENSION"

    local IFACE IP_ADDR
    IFACE=$(GET_IP)
    IP_ADDR=$(GET_IP_ADDR "$IFACE")

    if ! command -v squid &>/dev/null; then
        MSG_FAIL "Squid belum terinstall. Install Squid dulu (menu 4)."
        PRESS_ENTER
        return 1
    fi

    if ! command -v nginx &>/dev/null; then
        MSG_INFO "Web server diperlukan..."
        INSTALL_WEBSERVER
    fi

    # Deploy cleanup script
    local src_clean
    src_clean="$(dirname "$0")/scripts/clean-squid-cache.sh"
    if [ -f "$src_clean" ]; then
        cp "$src_clean" "$CACHE_CLEANUP_SCRIPT" && chmod +x "$CACHE_CLEANUP_SCRIPT"
        MSG_OK "Cleanup script: $CACHE_CLEANUP_SCRIPT"
    fi

    # Cron untuk monitor otomatis setiap jam
    local cron_job="0 * * * * $CACHE_CLEANUP_SCRIPT --monitor"
    (crontab -l 2>/dev/null | grep -v "clean-squid-cache"; echo "$cron_job") | crontab - 2>/dev/null || true
    MSG_OK "Cron: auto-monitor cache setiap jam"

    chmod +x "$CACHE_CLEANUP_SCRIPT" 2>/dev/null

    # Deploy cache monitor API
    mkdir -p "$CACHE_MONITOR_DIR"
    local src_api
    src_api="$(dirname "$0")/web/cache-monitor/index.php"
    if [ -f "$src_api" ]; then
        cp "$src_api" "$CACHE_MONITOR_DIR/index.php"
        MSG_OK "Cache Monitor API: http://$IP_ADDR/cache-monitor/"
    else
        MSG_WARN "Source cache-monitor tidak ditemukan"
        GENERATE_CACHE_MONITOR "$CACHE_MONITOR_DIR/index.php"
    fi

    # Deploy browser extension
    mkdir -p "$EXTENSION_DIR"
    local src_ext
    src_ext="$(dirname "$0")/browser-extension/"
    if [ -d "$src_ext" ]; then
        cp -r "$src_ext"* "$EXTENSION_DIR/"
        MSG_OK "Browser extension: http://$IP_ADDR/squid-extension/"
    fi

    echo ""
    MSG_OK "Cache Monitor siap!"
    echo -e "  ${DIM}API:${NC}       http://$IP_ADDR/cache-monitor/"
    echo -e "  ${DIM}Extension:${NC} http://$IP_ADDR/squid-extension/"
    echo ""
    echo -e "  ${YELLOW}Cara pakai extension:${NC}"
    echo -e "  1. Buka chrome://extensions/"
    echo -e "  2. Aktifkan 'Developer mode'"
    echo -e "  3. Klik 'Load unpacked', pilih folder download"
    echo -e "  4. Atau download zip dari link di atas"
    echo ""
    PRESS_ENTER
}

GENERATE_CACHE_MONITOR() {
    local output=$1
    cat > "$output" << 'PHPEOF'
<?php
header('Access-Control-Allow-Origin: *');
header('Access-Control-Allow-Methods: GET, POST, OPTIONS');
header('Content-Type: application/json');
if ($_SERVER['REQUEST_METHOD'] === 'OPTIONS') { http_response_code(204); exit; }
$action = isset($_GET['action']) ? $_GET['action'] : 'status';
function stats() {
    $dir = '/var/spool/squid'; $max = 10240;
    $out = []; exec('du -sm '.escapeshellarg($dir).' 2>/dev/null', $out, $rc);
    $mb = $rc === 0 && isset($out[0]) ? (int)explode("\t", $out[0])[0] : 0;
    $obj = 0;
    if (is_dir($dir)) { $it = new RecursiveIteratorIterator(new RecursiveDirectoryIterator($dir, RecursiveDirectoryIterator::SKIP_DOTS)); foreach ($it as $f) { if ($f->isFile()) $obj++; } }
    $info = shell_exec('squid -k info 2>/dev/null');
    $hit = '-';
    if ($info) {
        preg_match('/Request Hit Ratios.*?:.*?([\d.]+)%/', $info, $m);
        if (isset($m[1])) $hit = $m[1].'%';
    }
    $pct = $max > 0 ? round($mb * 100 / $max) : 0;
    return ['size_mb'=>$mb, 'max_mb'=>$max, 'pct'=>$pct, 'objects'=>$obj, 'hit_rate'=>$hit, 'status'=>$pct>=95?'critical':($pct>=85?'warning':'ok')];
}
function clean() {
    $b = stats();
    if ($b['pct'] < 85) return ['success'=>true, 'message'=>'Cache masih cukup ('.$b['pct'].'%)', 'before'=>$b, 'after'=>$b];
    exec('systemctl stop squid 2>/dev/null'); sleep(1);
    exec('find /var/spool/squid -type f -atime +7 2>/dev/null | head -5000 | xargs rm -f 2>/dev/null');
    exec('find /var/spool/squid -type f -atime +3 2>/dev/null | head -3000 | xargs rm -f 2>/dev/null');
    exec('rm -rf /var/spool/squid/00 /var/spool/squid/01 2>/dev/null');
    exec('squid -z > /dev/null 2>&1'); exec('systemctl start squid 2>/dev/null'); sleep(2);
    $a = stats();
    return ['success'=>true, 'message'=>'Cache: '.$b['size_mb'].'MB -> '.$a['size_mb'].'MB', 'before'=>$b, 'after'=>$a];
}
switch ($action) {
    case 'status': echo json_encode(stats()); break;
    case 'clean': echo json_encode(clean()); break;
    default: http_response_code(400); echo json_encode(['error'=>'Unknown action']);
}
PHPEOF
    MSG_OK "Cache monitor API fallback dibuat"
}

REMOVE_CACHE_MONITOR() {
    MSG_TITLE "HAPUS CACHE MONITOR"
    CONFIRM "Hapus?" "n" || return
    rm -rf "$CACHE_MONITOR_DIR" "$EXTENSION_DIR" "$CACHE_CLEANUP_SCRIPT"
    crontab -l 2>/dev/null | grep -v "clean-squid-cache" | crontab - 2>/dev/null || true
    MSG_OK "Cache monitor dihapus"
    PRESS_ENTER
}
