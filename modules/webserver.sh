#!/bin/bash
# Module: Install Web Server (Nginx + PHP)
# Sumber: modules/webserver.sh

WEBSERVER_ROOT="/var/www/html"
NGINX_CONF="/etc/nginx/sites-available/default"

INSTALL_WEBSERVER() {
    clear
    MSG_TITLE "INSTALL WEB SERVER (Nginx + PHP)"

    local IFACE IP_ADDR
    IFACE=$(GET_IP)
    IP_ADDR=$(GET_IP_ADDR "$IFACE")

    if command -v nginx &>/dev/null; then
        MSG_WARN "Nginx sudah terinstall"
        local action
        action=$(APP_MENU "Nginx Web Server")
        case "$action" in
            1)
                MSG_INFO "Memperbarui Nginx..."
                apt install --only-upgrade -y nginx php-fpm php-json > /dev/null 2>&1 || true
                RESTART_SERVICE nginx
                PRESS_ENTER
                return 0
                ;;
            2)
                REMOVE_WEBSERVER
                PRESS_ENTER
                return 0
                ;;
            3)
                REMOVE_WEBSERVER
                ;;
            0)
                MSG_INFO "Melewati instalasi Web Server"
                return 0
                ;;
        esac
    fi

    APT_UPDATE
    CONFLICTS=()
    DETECT_DISABLE_CONFLICTS "webserver" || return

    INSTALL_PKG nginx || return

    local php_pkg="php-fpm"
    if ! command -v php &>/dev/null; then
        INSTALL_PKG "$php_pkg" || php_pkg="php7.4-fpm"
        INSTALL_PKG "$php_pkg" || true
        INSTALL_PKG php-json || true
        INSTALL_PKG php-xml || true
    fi

    local php_svc="php8.2-fpm"
    if ! systemctl list-units --type=service --all 2>/dev/null | grep -q "$php_svc"; then
        php_svc="php8.1-fpm"
        if ! systemctl list-units --type=service --all 2>/dev/null | grep -q "$php_svc"; then
            php_svc="php7.4-fpm"
            if ! systemctl list-units --type=service --all 2>/dev/null | grep -q "$php_svc"; then
                php_svc=$(systemctl list-units --type=service --all 2>/dev/null | grep "php.*-fpm" | head -1 | awk '{print $1}')
            fi
        fi
    fi

    mkdir -p "$WEBSERVER_ROOT"
    BACKUP_FILE "$NGINX_CONF"

    cat > "$NGINX_CONF" << 'NGINX'
server {
    listen 80 default_server;
    listen [::]:80 default_server;
    root /var/www/html;
    index index.php index.html index.htm;
    server_name _;
    location / {
        try_files $uri $uri/ =404;
    }
    location ~ \.php$ {
        include snippets/fastcgi-php.conf;
        fastcgi_pass unix:/var/run/php/php-fpm.sock;
    }
    location ~ /\.ht {
        deny all;
    }
}
NGINX

    # Sesuaikan path socket PHP
    local php_socket
    php_socket=$(find /var/run/php -name "php*-fpm.sock" 2>/dev/null | head -1)
    if [ -n "$php_socket" ]; then
        sed -i "s|unix:/var/run/php/php-fpm.sock|unix:$php_socket|" "$NGINX_CONF"
    fi

    systemctl enable nginx 2>/dev/null || true
    systemctl restart nginx 2>/dev/null || true

    if [ -n "$php_svc" ]; then
        systemctl enable "$php_svc" 2>/dev/null || true
        systemctl restart "$php_svc" 2>/dev/null || true
    fi

    UFW_ALLOW 80/tcp "Nginx HTTP"

    if SERVICE_ACTIVE nginx; then
        echo ""
        MSG_OK "Web Server: http://$IP_ADDR"
        echo ""
    else
        MSG_FAIL "Nginx gagal start"
    fi
    PRESS_ENTER
}

REMOVE_WEBSERVER() {
    MSG_TITLE "HAPUS WEB SERVER"
    CONFIRM "Hapus Nginx + PHP?" || return

    systemctl stop nginx 2>/dev/null || true
    pkill -9 nginx 2>/dev/null || true
    apt remove --purge -y nginx php-fpm php-json php-xml > /dev/null 2>&1 || true
    rm -rf /etc/nginx
    UFW_DENY 80/tcp
    UFW_DENY 443/tcp
    CLEANUP_APT
    MSG_OK "Web Server berhasil dihapus"
}
