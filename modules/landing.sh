#!/bin/bash
# Module: Deploy Landing Page UI
# Sumber: modules/landing.sh

LANDING_DIR="/var/www/html"

INSTALL_LANDING() {
    clear
    MSG_TITLE "INSTALL LANDING PAGE"

    local IFACE IP_ADDR
    IFACE=$(GET_IP)
    IP_ADDR=$(GET_IP_ADDR "$IFACE")

    if DETECT_LANDING_PAGE; then
        MSG_WARN "Landing Page sudah terinstall"
        local action
        action=$(APP_MENU "Landing Page")
        case "$action" in
            1)
                MSG_INFO "Memperbarui Landing Page..."
                DEPLOY_LANDING_FILES
                MSG_OK "Landing Page diperbarui"
                PRESS_ENTER
                return 0
                ;;
            2)
                REMOVE_LANDING
                PRESS_ENTER
                return 0
                ;;
            3)
                REMOVE_LANDING
                DEPLOY_LANDING_FILES
                PRESS_ENTER
                return 0
                ;;
            0)
                MSG_INFO "Melewati instalasi Landing Page"
                return 0
                ;;
        esac
    fi

    if ! command -v nginx &>/dev/null; then
        MSG_INFO "Web server diperlukan, menginstall Nginx + PHP..."
        INSTALL_WEBSERVER
    fi
    mkdir -p "$LANDING_DIR"
    DEPLOY_LANDING_FILES
    INSTALL_LANDING_API
    MSG_OK "Landing Page: http://$IP_ADDR"
    PRESS_ENTER
}

DEPLOY_LANDING_FILES() {
    local src_landing
    src_landing="$(dirname "$0")/web/landing/"

    if [ -f "${src_landing}index.html" ]; then
        cp "${src_landing}index.html" "$LANDING_DIR/index.html"
        MSG_OK "Landing page deployed"
    else
        MSG_WARN "File landing page tidak ditemukan di $src_landing"
        # Fallback: buat landing page sederhana via script
        GENERATE_LANDING_PAGE "$LANDING_DIR/index.html"
    fi
}

REMOVE_LANDING() {
    MSG_TITLE "HAPUS LANDING PAGE"
    CONFIRM "Hapus Landing Page?" "n" || return

    if [ -f "$LANDING_DIR/index.html" ]; then
        rm -f "$LANDING_DIR/index.html"
        MSG_OK "Landing page dihapus"
    else
        MSG_WARN "Landing page tidak ditemukan"
    fi
}

GENERATE_LANDING_PAGE() {
    local output=$1
    local IFACE IP_ADDR
    IFACE=$(GET_IP)
    IP_ADDR=$(GET_IP_ADDR "$IFACE")

    cat > "$output" << 'HTMLEOF'
<!DOCTYPE html>
<html lang="id">
<head>
<meta charset="UTF-8">
<meta name="viewport" content="width=device-width, initial-scale=1.0">
<title>AIO Landing - Home Server</title>
<style>
*{margin:0;padding:0;box-sizing:border-box;font-family:'Segoe UI',system-ui,sans-serif}
:root{--bg:#0f0f1a;--card:#1a1a2e;--primary:#e94560;--text:#eee;--text2:#aaa;--accent:#16213e}
body{background:var(--bg);color:var(--text);min-height:100vh}
.header{padding:20px;text-align:center;border-bottom:1px solid #333}
.header h1{font-size:1.5em;color:var(--primary)}
.header p{color:var(--text2);font-size:.85em;margin-top:5px}
.container{max-width:1200px;margin:0 auto;padding:15px}
.grid{display:grid;gap:15px}
.stats-grid{grid-template-columns:repeat(auto-fit,minmax(180px,1fr))}
.app-grid{grid-template-columns:repeat(auto-fit,minmax(130px,1fr))}
.svc-grid{grid-template-columns:repeat(auto-fit,minmax(250px,1fr))}
.card{background:var(--card);border-radius:12px;padding:18px;border:1px solid #2a2a3e;transition:.3s}
.card:hover{border-color:var(--primary);transform:translateY(-2px)}
.card h3{font-size:.8em;color:var(--text2);text-transform:uppercase;letter-spacing:1px;margin-bottom:8px}
.card .value{font-size:1.5em;font-weight:700;color:var(--text)}
.card .value.good{color:#4ecca3}
.card .value.warn{color:#ffc107}
.card .value.bad{color:#e94560}
.app-btn{display:flex;flex-direction:column;align-items:center;justify-content:center;padding:20px 10px;text-decoration:none;color:var(--text);border-radius:12px;background:var(--card);border:1px solid #2a2a3e;transition:.3s;cursor:pointer}
.app-btn:hover{border-color:var(--primary);transform:translateY(-3px);background:#1e1e3a}
.app-btn .icon{font-size:2em;margin-bottom:8px}
.app-btn .name{font-size:.85em;font-weight:600;text-align:center}
.svc-card{background:var(--card);border-radius:12px;padding:15px;border:1px solid #2a2a3e}
.svc-card h4{font-size:.95em;margin-bottom:5px}
.svc-card .svc-status{font-size:.8em;padding:2px 8px;border-radius:4px;display:inline-block;margin-bottom:8px}
.svc-card .svc-status.running{background:#1a3a2a;color:#4ecca3}
.svc-card .svc-status.stopped{background:#3a1a1a;color:#e94560}
.svc-card .svc-actions{display:flex;gap:5px;flex-wrap:wrap}
.svc-card button{padding:4px 10px;border:none;border-radius:4px;cursor:pointer;font-size:.75em;transition:.2s}
.svc-btn-start{background:#4ecca3;color:#000}
.svc-btn-stop{background:#e94560;color:#fff}
.svc-btn-restart{background:#ffc107;color:#000}
.svc-btn-status{background:#333;color:#fff}
.svc-card button:hover{opacity:.8}
.theme-selector{display:flex;gap:8px;justify-content:center;margin:15px 0;flex-wrap:wrap}
.theme-btn{padding:6px 14px;border:1px solid #2a2a3e;border-radius:20px;cursor:pointer;font-size:.8em;transition:.3s;background:transparent;color:var(--text)}
.theme-btn.active,.theme-btn:hover{border-color:var(--primary);background:var(--primary);color:#fff}
.bar{height:6px;border-radius:3px;background:#2a2a3e;margin-top:8px;overflow:hidden}
.bar-fill{height:100%;border-radius:3px;transition:width .5s;background:linear-gradient(90deg,var(--primary),#ff6b6b)}
.bar-fill.good{background:linear-gradient(90deg,#4ecca3,#2ecc71)}
.bar-fill.warn{background:linear-gradient(90deg,#ffc107,#ff9800)}
.bar-fill.bad{background:linear-gradient(90deg,#e94560,#ff0000)}
.section-title{font-size:1.1em;margin:20px 0 10px;color:var(--primary);border-bottom:1px solid #333;padding-bottom:5px}
/* Themes */
.theme-modern{--bg:#1a1a2e;--card:#16213e;--primary:#0f3460;--text:#eee;--text2:#aaa;--accent:#533483}
.theme-modern .header{border-color:#0f3460}
.theme-techno{--bg:#0a0a0a;--card:#1a1a1a;--primary:#00ff41;--text:#00ff41;--text2:#008f20;--accent:#111}
.theme-techno .header{border-color:#00ff41}
.theme-techno .card{border-color:#00ff41;background:#0d0d0d}
.theme-techno .app-btn{border-color:#00ff41;background:#0d0d0d;color:#00ff41}
.theme-techno .bar-fill{background:linear-gradient(90deg,#00ff41,#00cc33)}
.theme-cute{--bg:#fff0f5;--card:#ffe4ec;--primary:#ff69b4;--text:#5a2d3c;--text2:#8a5a6a;--accent:#ffb6c1}
.theme-cute .header{border-color:#ff69b4}
.theme-cute .card{border-color:#ffb6c1}
.theme-cute .app-btn{border-color:#ffb6c1;background:#ffe4ec;color:#5a2d3c}
.theme-cute .bar-fill{background:linear-gradient(90deg,#ff69b4,#ff1493)}
@media(max-width:600px){.stats-grid{grid-template-columns:repeat(2,1fr)}.app-grid{grid-template-columns:repeat(3,1fr)}.svc-grid{grid-template-columns:1fr}}
</style>
</head>
<body>
<div class="header">
<h1>🏠 Home Server</h1>
<p id="hostname">Memuat...</p>
</div>
<div class="container">
<div class="theme-selector">
<button class="theme-btn active" onclick="setTheme('default')">🎨 Default</button>
<button class="theme-btn" onclick="setTheme('modern')">🏙️ Modern</button>
<button class="theme-btn" onclick="setTheme('techno')">🤖 Techno</button>
<button class="theme-btn" onclick="setTheme('cute')">🌸 Cute</button>
</div>

<h2 class="section-title">📊 System Status</h2>
<div class="grid stats-grid" id="stats">
<div class="card"><h3>CPU Temp</h3><div class="value" id="cpu-temp">-</div></div>
<div class="card"><h3>CPU Usage</h3><div class="value" id="cpu-usage">-</div><div class="bar"><div class="bar-fill" id="cpu-bar" style="width:0%"></div></div></div>
<div class="card"><h3>RAM Usage</h3><div class="value" id="ram-usage">-</div><div class="bar"><div class="bar-fill" id="ram-bar" style="width:0%"></div></div></div>
<div class="card"><h3>Storage</h3><div class="value" id="storage-usage">-</div><div class="bar"><div class="bar-fill" id="storage-bar" style="width:0%"></div></div></div>
<div class="card"><h3>SWAP / ZRAM</h3><div class="value" id="swap-usage">-</div><div class="bar"><div class="bar-fill" id="swap-bar" style="width:0%"></div></div></div>
<div class="card"><h3>Network RX</h3><div class="value" id="net-rx">-</div></div>
<div class="card"><h3>Network TX</h3><div class="value" id="net-tx">-</div></div>
<div class="card"><h3>Uptime</h3><div class="value" id="uptime">-</div></div>
</div>

<h2 class="section-title">📱 Aplikasi</h2>
<div class="grid app-grid" id="apps"></div>

<h2 class="section-title">⚙️ Layanan</h2>
<div class="grid svc-grid" id="services"></div>
</div>

<script>
const THEMES={default:{bg:'#0f0f1a',card:'#1a1a2e',primary:'#e94560',text:'#eee',text2:'#aaa'},modern:{bg:'#1a1a2e',card:'#16213e',primary:'#0f3460',text:'#eee',text2:'#aaa'},techno:{bg:'#0a0a0a',card:'#1a1a1a',primary:'#00ff41',text:'#00ff41',text2:'#008f20'},cute:{bg:'#fff0f5',card:'#ffe4ec',primary:'#ff69b4',text:'#5a2d3c',text2:'#8a5a6a'}};
const APPS=[
{name:'AdBlock DNS',icon:'🛡️',url:'/',desc:'DNS Adblocker'},
{name:'Squid Proxy',icon:'🌐',url:'http://'+location.hostname+':3128',desc:'Cache Proxy'},
{name:'File Manager',icon:'📁',url:'/filemanager/',desc:'File Manager'},
{name:'Landing Page',icon:'🏠',url:'/',desc:'Halaman Utama'},
{name:'Settings',icon:'⚙️',url:'/',desc:'Pengaturan'},
{name:'Monitor',icon:'📊',url:'/',desc:'System Monitor'}
];
const SERVICES=[
{name:'dnsmasq',label:'AdBlock DNS'},
{name:'squid',label:'Squid Proxy'},
{name:'nginx',label:'Web Server'},
{name:'php8.2-fpm',label:'PHP FPM'},
{name:'ssh',label:'SSH Server'}
];

function setTheme(name){
document.body.className=name==='default'?'':'theme-'+name;
document.querySelectorAll('.theme-btn').forEach(b=>b.classList.remove('active'));
document.querySelectorAll('.theme-btn').forEach(b=>{if(b.textContent.includes(name==='default'?'Default':name.charAt(0).toUpperCase()+name.slice(1)))b.classList.add('active')});
localStorage.setItem('theme',name);
}

function loadTheme(){
const saved=localStorage.getItem('theme')||'default';
if(saved!=='default')document.body.className='theme-'+saved;
document.querySelectorAll('.theme-btn').forEach(b=>{if(b.textContent.toLowerCase().includes(saved==='default'?'default':saved))b.classList.add('active')});
}

async function fetchStats(){
try{
const r=await fetch('/api/stats');
if(!r.ok)throw new Error('fetch failed');
const d=await r.json();
document.getElementById('cpu-temp').textContent=d.cpu_temp||'-';
document.getElementById('cpu-usage').textContent=d.cpu_usage||'-';
document.getElementById('cpu-bar').style.width=(d.cpu_pct||0)+'%';
const rp=d.ram_pct||0;
document.getElementById('ram-usage').textContent=d.ram_usage||'-';
document.getElementById('ram-bar').style.width=rp+'%';
document.getElementById('ram-bar').className='bar-fill'+(rp>80?' bad':rp>60?' warn':' good');
const sp=d.storage_pct||0;
document.getElementById('storage-usage').textContent=d.storage_usage||'-';
document.getElementById('storage-bar').style.width=sp+'%';
document.getElementById('storage-bar').className='bar-fill'+(sp>80?' bad':sp>60?' warn':' good');
const swp=d.swap_pct||0;
document.getElementById('swap-usage').textContent=d.swap_usage||'-';
document.getElementById('swap-bar').style.width=swp+'%';
document.getElementById('swap-bar').className='bar-fill'+(swp>80?' bad':swp>60?' warn':' good');
document.getElementById('net-rx').textContent=d.net_rx||'-';
document.getElementById('net-tx').textContent=d.net_tx||'-';
document.getElementById('uptime').textContent=d.uptime||'-';
document.getElementById('hostname').textContent=d.hostname||'-';
}catch(e){console.log('Stats unavailable (API not ready)');}
}

function renderApps(){
const container=document.getElementById('apps');
APPS.forEach(app=>{
const a=document.createElement('a');
a.className='app-btn';
a.href=app.url;
a.innerHTML='<div class="icon">'+app.icon+'</div><div class="name">'+app.name+'</div>';
container.appendChild(a);
});
}

async function fetchServices(){
try{
const r=await fetch('/api/services');
if(!r.ok)throw new Error('fetch failed');
const services=await r.json();
const container=document.getElementById('services');
container.innerHTML='';
services.forEach(s=>{
const div=document.createElement('div');
div.className='svc-card';
div.innerHTML='<h4>'+s.label+'</h4><span class="svc-status '+(s.active?'running':'stopped')+'">'+(s.active?'● Running':'○ Stopped')+'</span><div class="svc-actions"><button class="svc-btn-status" onclick="svcAction(\''+s.name+'\',\'status\')">Status</button><button class="svc-btn-start" onclick="svcAction(\''+s.name+'\',\'start\')">Start</button><button class="svc-btn-stop" onclick="svcAction(\''+s.name+'\',\'stop\')">Stop</button><button class="svc-btn-restart" onclick="svcAction(\''+s.name+'\',\'restart\')">Restart</button></div>';
container.appendChild(div);
});
}catch(e){console.log('Services unavailable');}
}

function renderServices(){
const container=document.getElementById('services');
container.innerHTML='<p style="color:var(--text2);grid-column:1/-1;text-align:center">Memuat layanan...</p>';
fetchServices();
}

async function svcAction(name,action){
try{
const r=await fetch('/api/service?name='+name+'&action='+action);
const d=await r.json();
alert(d.message||d.error||'OK');
fetchServices();
}catch(e){alert('Gagal: '+e.message);}
}

loadTheme();
renderApps();
fetchStats();
renderServices();
setInterval(fetchStats,5000);
</script>
</body>
</html>
HTMLEOF
    MSG_OK "Landing page default dibuat di $output"
}
