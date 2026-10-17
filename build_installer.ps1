# 把八只宠物打成捆绑包 + 用 Windows 自带的 IExpress 生成自解压安装程序 .exe
$ErrorActionPreference = 'Stop'
$here = $PSScriptRoot
$root = Split-Path $here -Parent
$dist = Join-Path $here 'dist'
$build = Join-Path $env:TEMP 'petbuild'
if (Test-Path $build) { Remove-Item $build -Recurse -Force }
New-Item -ItemType Directory -Path $build -Force | Out-Null
$stage = Join-Path $build 'stage'
$pets = 'GeminiPet','DeepSeekPet','ChatGPTPet','ClaudePet','DoubaoPet','QwenPet','CopilotPet','GLMPet','GrokPet','ApplePet','GoogleGPet','GoogleFlatPet','GoogleOldPet','AppleLogoPet','Win7Pet','Win10Pet'
if (-not (Test-Path $dist)) { New-Item -ItemType Directory -Path $dist -Force | Out-Null }
New-Item -ItemType Directory -Path $stage -Force | Out-Null
# 1) 收集(排除 .git)
foreach ($p in $pets) {
    $src = Join-Path $root $p
    if (-not (Test-Path $src)) { Write-Host "  跳过缺失的 $p"; continue }
    robocopy $src (Join-Path $stage $p) /E /XD .git /NFL /NDL /NJH /NJS /NP | Out-Null
}
# 2) 打成捆绑包 zip
$zip = Join-Path $dist 'AllPets.zip'
if (Test-Path $zip) { Remove-Item $zip -Force }
Compress-Archive -Path (Join-Path $stage '*') -DestinationPath $zip -Force
Write-Host ("  捆绑包: {0}  {1} MB" -f $zip, [math]::Round((Get-Item $zip).Length/1MB,2))
# 3) 准备 exe 的载荷(3 个文件)
$payload = Join-Path $stage '_payload'
New-Item -ItemType Directory -Path $payload -Force | Out-Null
Copy-Item (Join-Path $here 'install.ps1') $payload -Force
Copy-Item (Join-Path $here 'run.vbs') $payload -Force
Copy-Item $zip (Join-Path $payload 'AllPets.zip') -Force
# 4) 写 IExpress 配置
$exeTmp = Join-Path $build 'PetsInstaller.exe'
$exe = Join-Path $dist 'AI桌宠合集安装程序.exe'
if (Test-Path $exe) { Remove-Item $exe -Force }
$sed = Join-Path $stage 'pets.sed'
$sedText = @"
[Version]
Class=IEXPRESS
SEDVersion=3
[Options]
PackagePurpose=InstallApp
ShowInstallProgramWindow=0
HideExtractAnimation=1
UseLongFileName=1
InsideCompressed=0
CAB_FixedSize=0
CAB_ResvCodeSigning=0
RebootMode=N
InstallPrompt=
DisplayLicense=
FinishMessage=
TargetName=$exeTmp
FriendlyName=AI Desktop Pets Installer
AppLaunched=wscript.exe run.vbs
PostInstallCmd=<None>
AdminQuietInstCmd=
UserQuietInstCmd=
SourceFiles=SourceFiles
[Strings]
FILE0=run.vbs
FILE1=install.ps1
FILE2=AllPets.zip
[SourceFiles]
SourceFiles0=$payload\
[SourceFiles0]
%FILE0%=
%FILE1%=
%FILE2%=
"@
[System.IO.File]::WriteAllText($sed, $sedText, (New-Object System.Text.ASCIIEncoding))
# 5) 生成 exe
Write-Host '  正在生成自解压安装程序...'
$out = & "$env:SystemRoot\System32\iexpress.exe" /N /Q $sed 2>&1
if (Test-Path $exeTmp) { Copy-Item $exeTmp $exe -Force; Write-Host ("  安装程序: {0}  {1} MB" -f $exe, [math]::Round((Get-Item $exe).Length/1MB,2)) }
else { Write-Host "  生成失败: $out" }
Remove-Item $stage -Recurse -Force -ErrorAction SilentlyContinue
