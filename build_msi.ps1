# =====================================================================
#  用 WiX v3 把十只桌宠打成 MSI(每只一个 Feature, 安装时可在功能树里勾选)
#  --------------------------------------------------------------------
#  用法:
#     powershell -File build_msi.ps1
#     powershell -File build_msi.ps1 -WixDir "D:\tools\wix314"
#  前提: 需要 WiX v3 的免安装二进制(heat.exe / candle.exe / light.exe)。
#        没装的话脚本会告诉你去哪下(wixtoolset/wix3 的 *-binaries.zip)。
#  产物: dist\AI桌宠合集.msi
# =====================================================================
param(
    [string]$WixDir = (Join-Path $env:TEMP 'wix314'),
    [string[]]$Pets = @('GeminiPet', 'DeepSeekPet', 'ChatGPTPet', 'ClaudePet', 'DoubaoPet', 'QwenPet', 'CopilotPet', 'GLMPet', 'GrokPet', 'ApplePet', 'GoogleGPet', 'GoogleFlatPet', 'GoogleOldPet', 'AppleLogoPet', 'Win7Pet', 'Win10Pet'),
    [string]$ProductName = 'AI 桌宠合集',
    [string]$Version = '1.1.0',
    [string]$Manufacturer = 'qi-cluadld'
)

$ErrorActionPreference = 'Stop'
$here = $PSScriptRoot
$root = Split-Path $here -Parent
$dist = Join-Path $here 'dist'
if (-not (Test-Path $dist)) { New-Item -ItemType Directory -Path $dist -Force | Out-Null }

# ---- 检查 WiX 工具 ----
$heat = Join-Path $WixDir 'heat.exe'
$candle = Join-Path $WixDir 'candle.exe'
$light = Join-Path $WixDir 'light.exe'
foreach ($t in @($heat, $candle, $light)) {
    if (-not (Test-Path $t)) {
        Write-Host "找不到 $t"
        Write-Host "请下载 WiX v3 免安装包(解压即可, 不需要安装):"
        Write-Host "  https://github.com/wixtoolset/wix3/releases  ->  wix314-binaries.zip"
        Write-Host "解压到某目录后加参数重跑, 例如:"
        Write-Host "  powershell -File build_msi.ps1 -WixDir D:\tools\wix314"
        exit 1
    }
}

# ---- 准备 ASCII 临时构建目录(WiX 的源文件路径别放中文) ----
$build = Join-Path $env:TEMP 'msibuild'
if (Test-Path $build) { Remove-Item $build -Recurse -Force }
New-Item -ItemType Directory -Path "$build\src", "$build\wxs", "$build\obj", "$build\extra" -Force | Out-Null

Write-Host "1/5 收集宠物文件(排除 .git) ..."
foreach ($p in $Pets) {
    $src = Join-Path $root $p
    if (-not (Test-Path $src)) { Write-Host "  跳过缺失的 $p"; continue }
    robocopy $src (Join-Path $build "src\$p") /E /XD .git /NFL /NDL /NJH /NJS /NP | Out-Null
    Write-Host ("  {0}: {1} 个文件" -f $p, (Get-ChildItem (Join-Path $build "src\$p") -Recurse -File -Force).Count)
}

# 一起启动的入口脚本(UTF-16 保存, VBS 里的中文文件名才不会乱码)
$launcher = @'
Option Explicit
Dim fso, sh, base, f
Set fso = CreateObject("Scripting.FileSystemObject")
Set sh = CreateObject("WScript.Shell")
base = fso.GetParentFolderName(WScript.ScriptFullName)
For Each f In fso.GetFolder(base).SubFolders
    If fso.FileExists(f.Path & "\启动宠物.vbs") Then
        sh.Run "wscript.exe """ & f.Path & "\启动宠物.vbs""", 0, False
        WScript.Sleep 300
    End If
Next
'@
[System.IO.File]::WriteAllText("$build\extra\启动全部桌宠.vbs", $launcher, [System.Text.Encoding]::Unicode)

# 许可页用的 rtf
[System.IO.File]::WriteAllText("$build\license.rtf", '{\rtf1\ansi\deff0{\fonttbl{\f0\fswiss Arial;}}\viewkind4\uc1\pard\f0\fs20 MIT License - free to use, modify and share. The desktop pets are provided as-is, without warranty of any kind.\par}', (New-Object System.Text.ASCIIEncoding))

Write-Host "2/5 heat: 每只生成一个组件组 ..."
$valid = @()
foreach ($p in $Pets) {
    if (-not (Test-Path (Join-Path $build "src\$p"))) { continue }
    & $heat dir (Join-Path $build "src\$p") -cg "${p}Group" -gg -g1 -sfrag -srd -dr "PetDir_$p" -var "var.Src_$p" -out (Join-Path $build "wxs\$p.wxs") -nologo | Out-Null
    if (Test-Path (Join-Path $build "wxs\$p.wxs")) { $valid += $p } else { Write-Host "  $p heat 失败" }
}

# ---- 主 wxs: 目录树 + 快捷方式 + 每只一个 Feature ----
$dirs = ($valid | ForEach-Object { '          <Directory Id="PetDir_' + $_ + '" Name="' + $_ + '" />' }) -join "`n"
$feats = ($valid | ForEach-Object {
    $title = switch ($_) {
        'GeminiPet' { 'Gemini 四角星' }
        'DeepSeekPet' { 'DeepSeek 蓝鲸' }
        'ChatGPTPet' { 'ChatGPT 花标' }
        'ClaudePet' { 'Claude 星号' }
        'DoubaoPet' { '豆包 小豆子' }
        'QwenPet' { '通义千问 蓝方块' }
        'CopilotPet' { 'Copilot 双方块' }
        'GLMPet' { '智谱 GLM 双环' }
        'GrokPet' { 'Grok 黑环斜杠' }
        'ApplePet' { 'Apple Intelligence 七环结' }
          'GoogleGPet' { 'Google G (gradient)' }
          'GoogleFlatPet' { 'Google G (flat)' }
        default { $_ }
    }
    '    <Feature Id="F' + $_ + '" Title="' + $title + '" Level="1"><ComponentGroupRef Id="' + $_ + 'Group" /></Feature>'
}) -join "`n"

$wxs = @"
<Wix xmlns="http://schemas.microsoft.com/wix/2006/wi">
  <Product Id="*" Name="$ProductName" Language="2052" Version="$Version" Manufacturer="$Manufacturer" UpgradeCode="7E2C9B14-5A3D-4C61-9F27-1B8E5D3A7C40">
    <Package InstallerVersion="500" Compressed="yes" InstallScope="perUser" Description="AI 桌面宠物合集(可自选装哪几只)" Comments="纯 PowerShell + WPF, 零依赖" />
    <MajorUpgrade DowngradeErrorMessage="已安装更新版本, 无需降级。" />
    <MediaTemplate EmbedCab="yes" />
    <WixVariable Id="WixUILicenseRtf" Value="license.rtf" />
    <UIRef Id="WixUI_FeatureTree" />
    <Directory Id="TARGETDIR" Name="SourceDir">
      <Directory Id="LocalAppDataFolder">
        <Directory Id="INSTALLFOLDER" Name="DesktopPets">
$dirs
        </Directory>
      </Directory>
      <Directory Id="ProgramMenuFolder">
        <Directory Id="AppMenuFolder" Name="$ProductName" />
      </Directory>
      <Directory Id="DesktopFolder" />
    </Directory>
    <DirectoryRef Id="INSTALLFOLDER">
      <Component Id="cLauncher" Guid="1A2B3C4D-5E6F-4A7B-8C9D-0E1F2A3B4C5D">
        <File Id="fLauncher" Source="extra\启动全部桌宠.vbs" KeyPath="yes" />
      </Component>
    </DirectoryRef>
    <DirectoryRef Id="AppMenuFolder">
      <Component Id="cMenu" Guid="2B3C4D5E-6F7A-4B8C-9D0E-1F2A3B4C5D6E">
        <Shortcut Id="scMenu" Name="启动全部桌宠" Target="[INSTALLFOLDER]启动全部桌宠.vbs" WorkingDirectory="INSTALLFOLDER" />
        <RemoveFolder Id="rfMenu" On="uninstall" />
        <RegistryValue Root="HKCU" Key="Software\qi-cluadld\DesktopPets" Name="menu" Type="integer" Value="1" KeyPath="yes" />
      </Component>
    </DirectoryRef>
    <DirectoryRef Id="DesktopFolder">
      <Component Id="cDesk" Guid="3C4D5E6F-7A8B-4C9D-0E1F-2A3B4C5D6E7F">
        <Shortcut Id="scDesk" Name="AI 桌宠" Target="[INSTALLFOLDER]启动全部桌宠.vbs" WorkingDirectory="INSTALLFOLDER" />
        <RegistryValue Root="HKCU" Key="Software\qi-cluadld\DesktopPets" Name="desk" Type="integer" Value="1" KeyPath="yes" />
      </Component>
    </DirectoryRef>
    <Feature Id="FMain" Title="启动器与快捷方式" Level="1" Absent="disallow">
      <ComponentRef Id="cLauncher" /><ComponentRef Id="cMenu" /><ComponentRef Id="cDesk" />
    </Feature>
$feats
  </Product>
</Wix>
"@
[System.IO.File]::WriteAllText("$build\pets.wxs", $wxs, (New-Object System.Text.UTF8Encoding($false)))

Write-Host "3/5 candle: 编译 ..."
$dargs = @()
foreach ($p in $valid) { $dargs += "-dSrc_$p=$build\src\$p" }
$allWxs = @(Get-ChildItem "$build\wxs" -File | ForEach-Object { $_.FullName }) + @("$build\pets.wxs")
& $candle -nologo @dargs -out "$build\obj\" $allWxs | ForEach-Object { Write-Host "  $_" }
$objs = @(Get-ChildItem "$build\obj" -Filter '*.wixobj' | ForEach-Object { $_.FullName })
Write-Host ("  wixobj: {0} 个" -f $objs.Count)

Write-Host "4/5 light: 链接成 MSI ..."
$msiTmp = Join-Path $build 'AIDesktopPets.msi'
if (Test-Path $msiTmp) { Remove-Item $msiTmp -Force }
& $light -nologo -sval -ext WixUIExtension -cultures:zh-CN -b $build -out $msiTmp $objs | ForEach-Object { Write-Host "  $_" }

Write-Host "5/5 输出 ..."
if (Test-Path $msiTmp) {
    $out = Join-Path $dist 'AI桌宠合集.msi'
    Copy-Item $msiTmp $out -Force
    Write-Host ("  MSI 生成成功: {0}  ({1} MB, {2} 只宠物)" -f $out, [math]::Round((Get-Item $out).Length / 1MB, 2), $valid.Count)
    Write-Host "  验证(管理员安装解包): msiexec /a `"$out`" TARGETDIR=`"$env:TEMP\msitest`" /qn"
} else {
    Write-Host "  MSI 生成失败"
    exit 1
}
