#!/bin/bash
# Squid Cache Cleanup & Monitor
# Menghapus cache lama jika mendekati batas 10GB
# Usage: sudo bash clean-squid-cache.sh [--status|--clean|--monitor]

SQUID_CACHE_DIR="/var/spool/squid"
MAX_CACHE_MB=10240
WARN_PCT=85
CRIT_PCT=95

RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'
CYAN='\033[0;36m'; BOLD='\033[1m'; DIM='\033[2m'; NC='\033[0m'

[ "$EUID" -ne 0 ] && { echo -e "${RED}[!] sudo bash $0${NC}"; exit 1; }

get_cache_size() {
    du -sm "$SQUID_CACHE_DIR" 2>/dev/null | cut -f1
}

get_cache_pct() {
    local size
    size=$(get_cache_size)
    [ -z "$size" ] && size=0
    echo $((size * 100 / MAX_CACHE_MB))
}

get_cache_stats() {
    local cache_size cache_pct obj_count
    cache_size=$(get_cache_size)
    cache_pct=$(get_cache_pct)
    obj_count=$(find "$SQUID_CACHE_DIR" -type f 2>/dev/null | wc -l)

    local swap_size swap_count
    if command -v squid &>/dev/null; then
        local info
        info=$(squid -k info 2>/dev/null | head -20)
        swap_size=$(echo "$info" | grep "Store Directory" | awk '{print $NF}')
        swap_count=$(echo "$info" | grep "Number of entries stored" | awk '{print $NF}')
    fi

    [ -z "$swap_size" ] && swap_size=$cache_size
    [ -z "$swap_count" ] && swap_count=$obj_count

    echo "size_mb=$cache_size"
    echo "max_mb=$MAX_CACHE_MB"
    echo "pct=$cache_pct"
    echo "objects=$swap_count"
    echo "status=$([ "$cache_pct" -ge "$CRIT_PCT" ] && echo "critical" || [ "$cache_pct" -ge "$WARN_PCT" ] && echo "warning" || echo "ok")"
}

clean_cache() {
    local cache_size cache_pct
    cache_size=$(get_cache_size)
    cache_pct=$(get_cache_pct)

    echo -e "${CYAN}Cache saat ini: ${cache_size}MB / ${MAX_CACHE_MB}MB (${cache_pct}%)${NC}"

    if [ "$cache_pct" -lt "$WARN_PCT" ]; then
        echo -e "${GREEN}Cache masih cukup, tidak perlu dibersihkan${NC}"
        return 0
    fi

    echo -e "${YELLOW}Membersihkan cache...${NC}"

    systemctl stop squid 2>/dev/null
    sleep 1

    local target_mb=$((MAX_CACHE_MB * 50 / 100))
    local remove_mb=$((cache_size - target_mb))
    [ "$remove_mb" -lt 0 ] && remove_mb=0

    if [ "$remove_mb" -gt 0 ]; then
        echo -e "  ${DIM}Menargetkan ${target_mb}MB, perlu menghapus ~${remove_mb}MB${NC}"

        find "$SQUID_CACHE_DIR" -type f -atime +7 2>/dev/null | head -5000 | xargs rm -f 2>/dev/null
        find "$SQUID_CACHE_DIR" -type f -atime +3 2>/dev/null | head -3000 | xargs rm -f 2>/dev/null

        rm -rf "$SQUID_CACHE_DIR/00" "$SQUID_CACHE_DIR/01" 2>/dev/null
    fi

    squid -z > /dev/null 2>&1 || true
    systemctl start squid 2>/dev/null

    local new_size
    new_size=$(get_cache_size)
    echo -e "${GREEN}Cache dibersihkan: ${cache_size}MB → ${new_size}MB${NC}"
}

case "${1:---status}" in
    --status)
        get_cache_stats
        ;;
    --clean)
        clean_cache
        ;;
    --monitor)
        get_cache_stats
        pct=$(get_cache_pct)
        if [ "$pct" -ge "$CRIT_PCT" ]; then
            echo "CRITICAL: Cache ${pct}% penuh" >&2
            clean_cache
        elif [ "$pct" -ge "$WARN_PCT" ]; then
            echo "WARNING: Cache ${pct}% penuh" >&2
        else
            echo "OK: Cache ${pct}% terpakai"
        fi
        ;;
    *)
        echo "Usage: $0 [--status|--clean|--monitor]"
        ;;
esac
