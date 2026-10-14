# 用系统自带的 csc 把 install.ps1 + run.vbs + AllPets.zip 编成单个自解压 exe
$ErrorActionPreference = 'Stop'
$here = $PSScriptRoot
$dist = Join-Path $here 'dist'
$work = Join-Path $env:TEMP 'petexe'
if (Test-Path $work) { Remove-Item $work -Recurse -Force }
New-Item -ItemType Directory -Path $work -Force | Out-Null
Copy-Item (Join-Path $here 'stub.cs') $work -Force
Copy-Item (Join-Path $here 'install.ps1') $work -Force
Copy-Item (Join-Path $here 'run.vbs') $work -Force
Copy-Item (Join-Path $dist 'AllPets.zip') $work -Force
$csc = "$env:SystemRoot\Microsoft.NET\Framework64\v4.0.30319\csc.exe"
if (-not (Test-Path $csc)) { $csc = "$env:SystemRoot\Microsoft.NET\Framework\v4.0.30319\csc.exe" }
Push-Location $work
& $csc /nologo /target:winexe /out:PetsInstaller.exe `
    /resource:install.ps1,payload.install.ps1 `
    /resource:run.vbs,payload.run.vbs `
    /resource:AllPets.zip,payload.AllPets.zip `
    /reference:System.Windows.Forms.dll stub.cs 2>&1 | ForEach-Object { Write-Host "  $_" }
Pop-Location
$out = Join-Path $dist 'AI桌宠合集安装程序.exe'
if (Test-Path "$work\PetsInstaller.exe") {
    Copy-Item "$work\PetsInstaller.exe" $out -Force
    Write-Host ("  exe 生成成功: {0} MB" -f [math]::Round((Get-Item $out).Length/1MB,2))
} else { Write-Host '  exe 生成失败' }
Remove-Item $work -Recurse -Force -ErrorAction SilentlyContinue