const serverIp = document.getElementById('serverIp');
const statusMsg = document.getElementById('statusMsg');
const cleanBtn = document.getElementById('cleanBtn');
const refreshBtn = document.getElementById('refreshBtn');

chrome.storage.local.get(['squidServer'], (result) => {
  if (result.squidServer) {
    serverIp.value = result.squidServer;
    fetchStats();
  }
});

serverIp.addEventListener('change', () => {
  chrome.storage.local.set({ squidServer: serverIp.value });
  fetchStats();
});

cleanBtn.addEventListener('click', cleanCache);
refreshBtn.addEventListener('click', fetchStats);

function showMsg(text, type) {
  statusMsg.textContent = text;
  statusMsg.className = 'status-msg ' + type;
  setTimeout(() => { if (statusMsg.className === 'status-msg ' + type) statusMsg.className = 'status-msg'; }, 3000);
}

function setLoading(loading) {
  cleanBtn.disabled = loading;
  refreshBtn.disabled = loading;
  if (loading) {
    statusMsg.textContent = 'Memuat...';
    statusMsg.className = 'status-msg loading';
  } else {
    statusMsg.className = 'status-msg';
  }
}

function getApiUrl(path) {
  return 'http://' + serverIp.value + '/cache-monitor/' + path;
}

async function fetchStats() {
  if (!serverIp.value) return;
  setLoading(true);
  try {
    const res = await fetch(getApiUrl('index.php?action=status'), { cache: 'no-store' });
    if (!res.ok) throw new Error('HTTP ' + res.status);
    const data = await res.json();
    updateUI(data);
    setLoading(false);
  } catch (e) {
    setLoading(false);
    showMsg('Gagal connect: ' + e.message, 'error');
  }
}

function updateUI(data) {
  const sizeText = data.size_mb >= 1024 ? (data.size_mb / 1024).toFixed(1) + ' GB' : data.size_mb + ' MB';
  const maxText = data.max_mb >= 1024 ? (data.max_mb / 1024).toFixed(0) + ' GB' : data.max_mb + ' MB';

  document.getElementById('cacheSize').textContent = sizeText;
  document.getElementById('maxCache').textContent = maxText;
  document.getElementById('usagePct').textContent = data.pct + '%';
  document.getElementById('objectCount').textContent = data.objects.toLocaleString();

  const statusEl = document.getElementById('statusText');
  if (data.status === 'ok') {
    statusEl.textContent = 'Sehat';
    statusEl.className = 'value ok';
  } else if (data.status === 'warning') {
    statusEl.textContent = 'Hampir penuh';
    statusEl.className = 'value warn';
  } else {
    statusEl.textContent = 'Kritis!';
    statusEl.className = 'value bad';
  }

  const bar = document.getElementById('cacheBar');
  bar.style.width = data.pct + '%';
  bar.className = 'bar ' + data.status;

  document.getElementById('hitDisplay').innerHTML = data.hit_rate + ' <span class="sub">HIT RATE</span>';
}

async function cleanCache() {
  if (!serverIp.value) return;
  if (!confirm('Hapus cache Squid?')) return;
  setLoading(true);
  try {
    const res = await fetch(getApiUrl('index.php?action=clean'), { method: 'POST', cache: 'no-store' });
    if (!res.ok) throw new Error('HTTP ' + res.status);
    const data = await res.json();
    setLoading(false);
    if (data.success) {
      showMsg(data.message, 'success');
      fetchStats();
    } else {
      showMsg(data.message || 'Gagal', 'error');
    }
  } catch (e) {
    setLoading(false);
    showMsg('Gagal: ' + e.message, 'error');
  }
}
