#!/bin/bash
# Module: Landing Page API (stats & service management)
# Sumber: modules/landing-api.sh
# Dipasang sebagai /var/www/html/api/ endpoint

INSTALL_LANDING_API() {
    local api_dir="/var/www/html/api"
    mkdir -p "$api_dir"

    cat > "$api_dir/stats" << 'APIEOF'
#!/bin/bash
# Simple stats API — dipanggil via nginx CGI atau alias
# Output JSON

C_TEMP=$(cat /sys/class/thermal/thermal_zone0/temp 2>/dev/null || echo 0)
C_TEMP=$((C_TEMP / 1000))
C_USAGE=$(top -bn1 2>/dev/null | grep "Cpu(s)" | awk '{print $2+$4}' | cut -d. -f1 || echo 0)
[ -z "$C_USAGE" ] && C_USAGE=0

RAM_TOTAL=$(free -k 2>/dev/null | awk '/^Mem:/{print $2}')
RAM_USED=$(free -k 2>/dev/null | awk '/^Mem:/{print $3}')
RAM_PCT=0
[ "$RAM_TOTAL" -gt 0 ] && RAM_PCT=$((RAM_USED * 100 / RAM_TOTAL))

RAM_HUMAN=$(free -h 2>/dev/null | awk '/^Mem:/{print $3"/"$2}')

STOR_TOTAL=$(df -k / 2>/dev/null | awk 'NR==2{print $2}')
STOR_USED=$(df -k / 2>/dev/null | awk 'NR==2{print $3}')
STOR_PCT=0
[ "$STOR_TOTAL" -gt 0 ] && STOR_PCT=$((STOR_USED * 100 / STOR_TOTAL))
STOR_HUMAN=$(df -h / 2>/dev/null | awk 'NR==2{print $3"/"$2}')

SWAP_TOTAL=$(free -k 2>/dev/null | awk '/^Swap/{print $2}')
SWAP_USED=$(free -k 2>/dev/null | awk '/^Swap/{print $3}')
SWAP_PCT=0
[ "$SWAP_TOTAL" -gt 0 ] && SWAP_PCT=$((SWAP_USED * 100 / SWAP_TOTAL))
SWAP_HUMAN=$(free -h 2>/dev/null | awk '/^Swap/{print $3"/"$2}')
[ "$SWAP_TOTAL" = "0" ] && SWAP_HUMAN="N/A"

IFACE=$(ip route get 8.8.8.8 2>/dev/null | awk '{print $5; exit}')
[ -z "$IFACE" ] && IFACE="eth0"
RX1=$(cat /sys/class/net/$IFACE/statistics/rx_bytes 2>/dev/null || echo 0)
TX1=$(cat /sys/class/net/$IFACE/statistics/tx_bytes 2>/dev/null || echo 0)
sleep 1
RX2=$(cat /sys/class/net/$IFACE/statistics/rx_bytes 2>/dev/null || echo 0)
TX2=$(cat /sys/class/net/$IFACE/statistics/tx_bytes 2>/dev/null || echo 0)
RX_DIFF=$(( (RX2 - RX1) / 1024 ))
TX_DIFF=$(( (TX2 - TX1) / 1024 ))

HOSTNAME=$(hostname)
UPTIME=$(uptime -p 2>/dev/null | sed 's/up //' || echo "-")

cat << JSON
{
"hostname":"$HOSTNAME",
"cpu_temp":"${C_TEMP}°C",
"cpu_usage":"${C_USAGE}%",
"cpu_pct":${C_USAGE},
"ram_usage":"$RAM_HUMAN",
"ram_pct":${RAM_PCT},
"storage_usage":"$STOR_HUMAN",
"storage_pct":${STOR_PCT},
"swap_usage":"$SWAP_HUMAN",
"swap_pct":${SWAP_PCT},
"net_rx":"${RX_DIFF}KB/s",
"net_tx":"${TX_DIFF}KB/s",
"uptime":"$UPTIME"
}
JSON
APIEOF
    chmod +x "$api_dir/stats"

    cat > "$api_dir/services" << 'APISVC'
#!/bin/bash
# Services status API — output JSON array

SERVICES=("dnsmasq" "squid" "nginx" "ssh" "php8.2-fpm" "php8.1-fpm" "php7.4-fpm")
echo "["
FIRST=true
for svc in "${SERVICES[@]}"; do
    systemctl list-units --type=service --all 2>/dev/null | grep -q "$svc" || continue
    ACTIVE=false
    systemctl is-active --quiet "$svc" 2>/dev/null && ACTIVE=true
    $FIRST || echo ","
    FIRST=false
    echo "{\"name\":\"$svc\",\"active\":$ACTIVE,\"label\":\"$svc\"}"
done
echo "]"
APISVC
    chmod +x "$api_dir/services"

    cat > "$api_dir/service" << 'APISVCCTL'
#!/bin/bash
# Service control API: ?name=<svc>&action=start|stop|restart|status
echo "Content-Type: application/json"
echo ""

QUERY_STRING="$1"
NAME=$(echo "$QUERY_STRING" | grep -oP 'name=\K[^&]+' || echo "")
ACTION=$(echo "$QUERY_STRING" | grep -oP 'action=\K[^&]+' || echo "")

if [ -z "$NAME" ] || [ -z "$ACTION" ]; then
    echo '{"error":"Missing name or action parameter"}'
    exit 1
fi

case "$ACTION" in
    start)
        systemctl start "$NAME" 2>/dev/null
        echo "{\"message\":\"Starting $NAME...\",\"name\":\"$NAME\",\"action\":\"$ACTION\"}"
        ;;
    stop)
        systemctl stop "$NAME" 2>/dev/null
        echo "{\"message\":\"Stopping $NAME...\",\"name\":\"$NAME\",\"action\":\"$ACTION\"}"
        ;;
    restart)
        systemctl restart "$NAME" 2>/dev/null
        echo "{\"message\":\"Restarting $NAME...\",\"name\":\"$NAME\",\"action\":\"$ACTION\"}"
        ;;
    status)
        if systemctl is-active --quiet "$NAME" 2>/dev/null; then
            echo "{\"message\":\"$NAME is running\",\"name\":\"$NAME\",\"active\":true}"
        else
            echo "{\"message\":\"$NAME is stopped\",\"name\":\"$NAME\",\"active\":false}"
        fi
        ;;
    *)
        echo "{\"error\":\"Unknown action: $ACTION\"}"
        ;;
esac
APISVCCTL
    chmod +x "$api_dir/service"

    # Pasang alias di nginx untuk CGI
    if [ -f /etc/nginx/sites-available/default ]; then
        if ! grep -q "api/stats" /etc/nginx/sites-available/default 2>/dev/null; then
            sed -i '/server_name _;/a\
    location /api/ {\
        alias /var/www/html/api/;\
        default_type application/json;\
    }' /etc/nginx/sites-available/default
            systemctl reload nginx 2>/dev/null || true
        fi
    fi

    MSG_OK "API stats: http://$IP_ADDR/api/stats"
    MSG_OK "API services: http://$IP_ADDR/api/services"
}
