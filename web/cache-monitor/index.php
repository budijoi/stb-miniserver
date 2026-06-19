<?php
header('Access-Control-Allow-Origin: *');
header('Access-Control-Allow-Methods: GET, POST, OPTIONS');
header('Content-Type: application/json');

if ($_SERVER['REQUEST_METHOD'] === 'OPTIONS') {
    http_response_code(204);
    exit;
}

$action = isset($_GET['action']) ? $_GET['action'] : 'status';

function get_cache_stats() {
    $cache_dir = '/var/spool/squid';
    $max_mb = 10240;

    $output = [];
    exec('du -sm ' . escapeshellarg($cache_dir) . ' 2>/dev/null', $output, $rc);
    $size_mb = $rc === 0 && isset($output[0]) ? (int)explode("\t", $output[0])[0] : 0;

    $obj_count = 0;
    $files = new RecursiveIteratorIterator(new RecursiveDirectoryIterator($cache_dir, RecursiveDirectoryIterator::SKIP_DOTS));
    foreach ($files as $f) {
        if ($f->isFile()) $obj_count++;
    }

    $swap_size = $size_mb;
    $swap_count = $obj_count;
    $cache_hit = '-';

    $squid_info = shell_exec('squid -k info 2>/dev/null');
    if ($squid_info) {
        preg_match('/Store Directory.*?:.*?(\d+)\s+KB/', $squid_info, $m);
        if (isset($m[1])) $swap_size = (int)($m[1] / 1024);

        preg_match('/Number of entries stored.*?:.*?(\d+)/', $squid_info, $m);
        if (isset($m[1])) $swap_count = (int)$m[1];

        preg_match('/Request Hit Ratios.*?:.*?([\d.]+)%/', $squid_info, $m);
        if (isset($m[1])) $cache_hit = $m[1] . '%';
    }

    $pct = $max_mb > 0 ? round($size_mb * 100 / $max_mb) : 0;

    return [
        'size_mb' => $size_mb,
        'max_mb' => $max_mb,
        'pct' => $pct,
        'objects' => $swap_count,
        'hit_rate' => $cache_hit,
        'status' => $pct >= 95 ? 'critical' : ($pct >= 85 ? 'warning' : 'ok')
    ];
}

function clean_cache() {
    $stats = get_cache_stats();

    if ($stats['pct'] < 85) {
        return ['success' => true, 'message' => 'Cache masih cukup (' . $stats['pct'] . '%)', 'before' => $stats, 'after' => $stats];
    }

    $before = $stats;

    exec('systemctl stop squid 2>/dev/null', $o, $rc);
    sleep(1);

    $target_mb = (int)($stats['max_mb'] * 0.5);
    exec('find /var/spool/squid -type f -atime +7 2>/dev/null | head -5000 | xargs rm -f 2>/dev/null');
    exec('find /var/spool/squid -type f -atime +3 2>/dev/null | head -3000 | xargs rm -f 2>/dev/null');
    exec('rm -rf /var/spool/squid/00 /var/spool/squid/01 2>/dev/null');
    exec('squid -z > /dev/null 2>&1');
    exec('systemctl start squid 2>/dev/null');
    sleep(2);

    $after = get_cache_stats();

    return [
        'success' => true,
        'message' => 'Cache dibersihkan: ' . $before['size_mb'] . 'MB -> ' . $after['size_mb'] . 'MB',
        'before' => $before,
        'after' => $after
    ];
}

switch ($action) {
    case 'status':
        echo json_encode(get_cache_stats());
        break;
    case 'clean':
        echo json_encode(clean_cache());
        break;
    default:
        http_response_code(400);
        echo json_encode(['error' => 'Unknown action. Use: status, clean']);
}
