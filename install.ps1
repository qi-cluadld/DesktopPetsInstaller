# =====================================================================
#  AI 桌宠合集 · 安装程序(勾选界面)
#  --------------------------------------------------------------------
#  由同目录的 ZIP 捆绑包里解压用户选中的宠物, 可选建桌面快捷方式 / 开机自启。
#  用法(双击 exe 时会自动带界面运行):
#      powershell -File install.ps1                 # 图形界面
#      powershell -File install.ps1 -Silent -Pets QwenPet,GLMPet -Target D:\Pets
# =====================================================================
param(
    [string[]]$Pets,
    [string]$Target,
    [switch]$Silent,
    [switch]$NoShortcut,
    [switch]$NoStartup,
    [switch]$NoLaunch
)

Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing
Add-Type -AssemblyName System.IO.Compression.FileSystem

$ErrorActionPreference = 'Stop'
$script:LogPath = Join-Path $env:TEMP '桌宠安装.log'
function Log([string]$m) {
    $line = '[{0}] {1}' -f (Get-Date -Format 'HH:mm:ss'), $m
    try { Add-Content -LiteralPath $script:LogPath -Value $line -Encoding UTF8 } catch { }
}

# 捆绑包(优先精确名, 否则取目录里第一个 zip)
$zipPath = Join-Path $PSScriptRoot 'AllPets.zip'
foreach ($cand in @((Join-Path $PSScriptRoot 'dist\AllPets.zip'), (Join-Path $PSScriptRoot '..\dist\AllPets.zip'))) { if (-not (Test-Path -LiteralPath $zipPath) -and (Test-Path -LiteralPath $cand)) { $zipPath = $cand } }
if (-not (Test-Path -LiteralPath $zipPath)) {
    $cand = Get-ChildItem -LiteralPath $PSScriptRoot -Filter '*.zip' -File -ErrorAction SilentlyContinue | Select-Object -First 1
    if ($cand) { $zipPath = $cand.FullName }
}
if (-not (Test-Path -LiteralPath $zipPath)) {
    [System.Windows.Forms.MessageBox]::Show("找不到捆绑包 zip:`n$zipPath", 'AI 桌宠合集') | Out-Null
    exit 1
}

# 八只宠物(顺序即界面顺序)
$script:AllPets = @(
    @{ Dir = 'GeminiPet'; Name = 'Gemini ✨  四角星'; Desc = '紫粉四角星, 会转圈放烟花' },
    @{ Dir = 'DeepSeekPet'; Name = 'DeepSeek 🐋  蓝鲸'; Desc = '蓝色小鲸鱼, 会喷水翻滚' },
    @{ Dir = 'ChatGPTPet'; Name = 'ChatGPT ✦  花标'; Desc = '绿色花标团子, 会思考冒泡' },
    @{ Dir = 'ClaudePet'; Name = 'Claude ☀  陶土星号'; Desc = '陶土橙 12 齿放射星, 会发光' },
    @{ Dir = 'DoubaoPet'; Name = '豆包 🥟  小豆子'; Desc = '淡蓝豆子, 软乎乎' },
    @{ Dir = 'QwenPet'; Name = '通义千问 🌀  蓝方块'; Desc = '蓝方块 + 三个白块' },
    @{ Dir = 'CopilotPet'; Name = 'Copilot 🚀  双方块'; Desc = '两块圆角方块叠加的彩虹配色' },
    @{ Dir = 'GLMPet'; Name = '智谱 GLM ⭕  双环'; Desc = '两个交叠的蓝色圆环' }
)

function Resolve-Name([string]$dir) {
    $p = $script:AllPets | Where-Object { $_.Dir -eq $dir } | Select-Object -First 1
    if ($p) { return $p.Name }
    return $dir
}

function Install-Pets {
    param([string[]]$Selected, [string]$Dest, [bool]$Shortcut, [bool]$Startup, [bool]$Launch)
    if (-not (Test-Path -LiteralPath $Dest)) { New-Item -ItemType Directory -Path $Dest -Force | Out-Null }
    $zip = [System.IO.Compression.ZipFile]::OpenRead($zipPath)
    $installed = @()
    try {
        foreach ($pet in $Selected) {
            $n = 0
            foreach ($e in $zip.Entries) {
                if (-not $e.Name) { continue }
                $rel = $e.FullName.Replace([char]92, [char]47)
                if ($rel -notlike "$pet/*") { continue }
                $out = Join-Path $Dest ($rel.Replace([char]47, [char]92))
                $parent = Split-Path $out -Parent
                if (-not (Test-Path -LiteralPath $parent)) { New-Item -ItemType Directory -Path $parent -Force | Out-Null }
                [System.IO.Compression.ZipFileExtensions]::ExtractToFile($e, $out, $true)
                $n++
            }
            if ($n -gt 0) { $installed += $pet; Log "已安装 $pet ($n 个文件)" } else { Log "跳过 $pet (压缩包里没有)" }
        }
    } finally { $zip.Dispose() }

    $sh = New-Object -ComObject WScript.Shell
    foreach ($pet in $installed) {
        $dir = Join-Path $Dest $pet
        $vbs = Join-Path $dir '启动宠物.vbs'
        if (-not (Test-Path -LiteralPath $vbs)) { continue }
        $safe = ((Resolve-Name $pet) -replace '[\\/:*?"<>|]', '')
        if ($Shortcut) {
            $lnk = (Join-Path ([Environment]::GetFolderPath('Desktop')) $safe) + '.lnk'
            $s = $sh.CreateShortcut($lnk)
            $s.TargetPath = 'wscript.exe'; $s.Arguments = '"' + $vbs + '"'; $s.WorkingDirectory = $dir
            $s.Description = 'AI 桌宠 ' + $pet; $s.Save(); Log "桌面快捷方式: $lnk"
        }
        if ($Startup) {
            $lnk = Join-Path ([Environment]::GetFolderPath('Startup')) ('DeskPet-' + $pet + '.lnk')
            $s = $sh.CreateShortcut($lnk)
            $s.TargetPath = 'wscript.exe'; $s.Arguments = '"' + $vbs + '"'; $s.WorkingDirectory = $dir
            $s.Save(); Log "开机自启: $lnk"
        }
    }
    if ($Launch) {
        foreach ($pet in $installed) {
            $vbs = Join-Path (Join-Path $Dest $pet) '启动宠物.vbs'
            if (Test-Path -LiteralPath $vbs) { Start-Process -FilePath 'wscript.exe' -ArgumentList ('"' + $vbs + '"') | Out-Null; Start-Sleep -Milliseconds 400 }
        }
    }
    return $installed
}
# ---------------- 静默模式 ----------------
if ($Silent) {
    $sel = $Pets
    if (-not $sel) { $sel = $script:AllPets.Dir }
    $dest = $Target
    if (-not $dest) { $dest = Join-Path $env:USERPROFILE 'DesktopPets' }
    $done = Install-Pets -Selected $sel -Dest $dest -Shortcut (-not $NoShortcut) -Startup (-not $NoStartup -and $false) -Launch (-not $NoLaunch)
    "已安装: $($done -join ', ')  ->  $dest"
    exit 0
}

# ---------------- 图形界面 ----------------
$form = New-Object System.Windows.Forms.Form
$form.Text = 'AI 桌宠合集 · 安装程序'
$form.Size = New-Object System.Drawing.Size(560, 620)
$form.StartPosition = 'CenterScreen'
$form.FormBorderStyle = 'FixedDialog'
$form.MaximizeBox = $false
$form.BackColor = [System.Drawing.Color]::FromArgb(248, 249, 252)

$title = New-Object System.Windows.Forms.Label
$title.Text = '选择要安装的桌面宠物'
$title.Font = New-Object System.Drawing.Font('Microsoft YaHei UI', 14, [System.Drawing.FontStyle]::Bold)
$title.Location = New-Object System.Drawing.Point(20, 16)
$title.Size = New-Object System.Drawing.Size(500, 32)
$form.Controls.Add($title)

$sub = New-Object System.Windows.Forms.Label
$sub.Text = '八只都是纯 PowerShell + WPF, 零依赖; 一起开就会互相联动、聊天、送爱心。'
$sub.Font = New-Object System.Drawing.Font('Microsoft YaHei UI', 9)
$sub.ForeColor = [System.Drawing.Color]::FromArgb(110, 116, 134)
$sub.Location = New-Object System.Drawing.Point(22, 50)
$sub.Size = New-Object System.Drawing.Size(510, 22)
$form.Controls.Add($sub)

$list = New-Object System.Windows.Forms.CheckedListBox
$list.Location = New-Object System.Drawing.Point(22, 80)
$list.Size = New-Object System.Drawing.Size(500, 250)
$list.Font = New-Object System.Drawing.Font('Microsoft YaHei UI', 10)
$list.CheckOnClick = $true
$list.IntegralHeight = $false
foreach ($p in $script:AllPets) { [void]$list.Items.Add(('{0}    —  {1}' -f $p.Name, $p.Desc), $true) }
$form.Controls.Add($list)

$btnAll = New-Object System.Windows.Forms.Button
$btnAll.Text = '全选'
$btnAll.Location = New-Object System.Drawing.Point(22, 338)
$btnAll.Size = New-Object System.Drawing.Size(70, 26)
$btnAll.Add_Click({ for ($i = 0; $i -lt $list.Items.Count; $i++) { $list.SetItemChecked($i, $true) } })
$form.Controls.Add($btnAll)
$btnNone = New-Object System.Windows.Forms.Button
$btnNone.Text = '全不选'
$btnNone.Location = New-Object System.Drawing.Point(98, 338)
$btnNone.Size = New-Object System.Drawing.Size(70, 26)
$btnNone.Add_Click({ for ($i = 0; $i -lt $list.Items.Count; $i++) { $list.SetItemChecked($i, $false) } })
$form.Controls.Add($btnNone)

$lblDir = New-Object System.Windows.Forms.Label
$lblDir.Text = '安装到:'
$lblDir.Location = New-Object System.Drawing.Point(22, 378)
$lblDir.Size = New-Object System.Drawing.Size(60, 22)
$form.Controls.Add($lblDir)
$txtDir = New-Object System.Windows.Forms.TextBox
$txtDir.Location = New-Object System.Drawing.Point(82, 375)
$txtDir.Size = New-Object System.Drawing.Size(360, 24)
$txtDir.Text = (Join-Path $env:USERPROFILE 'DesktopPets')
$form.Controls.Add($txtDir)
$btnBrowse = New-Object System.Windows.Forms.Button
$btnBrowse.Text = '浏览…'
$btnBrowse.Location = New-Object System.Drawing.Point(448, 374)
$btnBrowse.Size = New-Object System.Drawing.Size(74, 26)
$btnBrowse.Add_Click({
    $dlg = New-Object System.Windows.Forms.FolderBrowserDialog
    $dlg.Description = '选择安装目录'
    if ($dlg.ShowDialog() -eq 'OK') { $txtDir.Text = $dlg.SelectedPath }
})
$form.Controls.Add($btnBrowse)

$chkSc = New-Object System.Windows.Forms.CheckBox
$chkSc.Text = '在桌面创建启动快捷方式'
$chkSc.Location = New-Object System.Drawing.Point(24, 410)
$chkSc.Size = New-Object System.Drawing.Size(240, 24)
$chkSc.Checked = $true
$form.Controls.Add($chkSc)
$chkSt = New-Object System.Windows.Forms.CheckBox
$chkSt.Text = '开机自动启动'
$chkSt.Location = New-Object System.Drawing.Point(280, 410)
$chkSt.Size = New-Object System.Drawing.Size(240, 24)
$form.Controls.Add($chkSt)
$chkRun = New-Object System.Windows.Forms.CheckBox
$chkRun.Text = '安装完成后立刻让它们出来'
$chkRun.Location = New-Object System.Drawing.Point(24, 438)
$chkRun.Size = New-Object System.Drawing.Size(300, 24)
$chkRun.Checked = $true
$form.Controls.Add($chkRun)

$btnOk = New-Object System.Windows.Forms.Button
$btnOk.Text = '开始安装'
$btnOk.Location = New-Object System.Drawing.Point(300, 480)
$btnOk.Size = New-Object System.Drawing.Size(110, 34)
$btnOk.BackColor = [System.Drawing.Color]::FromArgb(91, 141, 239)
$btnOk.ForeColor = [System.Drawing.Color]::White
$btnOk.FlatStyle = 'Flat'
$btnOk.Add_Click({
    $sel = @()
    for ($i = 0; $i -lt $list.Items.Count; $i++) { if ($list.GetItemChecked($i)) { $sel += $script:AllPets[$i].Dir } }
    if ($sel.Count -eq 0) { [System.Windows.Forms.MessageBox]::Show('至少选一只吧 ~', 'AI 桌宠合集') | Out-Null; return }
    $btnOk.Enabled = $false
    $btnOk.Text = '安装中…'
    $form.Refresh()
    try {
        $done = Install-Pets -Selected $sel -Dest $txtDir.Text -Shortcut $chkSc.Checked -Startup $chkSt.Checked -Launch $chkRun.Checked
        [System.Windows.Forms.MessageBox]::Show("装好了 $($done.Count) 只:$([Environment]::NewLine)$($done -join ', ')$([Environment]::NewLine)$([Environment]::NewLine)位置: $($txtDir.Text)$([Environment]::NewLine)以后想单独启动, 双击各目录里的 启动宠物.vbs 就行。", 'AI 桌宠合集 · 完成') | Out-Null
        $form.Close()
    } catch {
        $btnOk.Enabled = $true
        $btnOk.Text = '开始安装'
        [System.Windows.Forms.MessageBox]::Show("出错了:$([Environment]::NewLine)$($_.Exception.Message)", 'AI 桌宠合集') | Out-Null
    }
})
$form.Controls.Add($btnOk)

$btnCancel = New-Object System.Windows.Forms.Button
$btnCancel.Text = '取消'
$btnCancel.Location = New-Object System.Drawing.Point(420, 480)
$btnCancel.Size = New-Object System.Drawing.Size(100, 34)
$btnCancel.Add_Click({ $form.Close() })
$form.Controls.Add($btnCancel)

[void]$form.ShowDialog()
