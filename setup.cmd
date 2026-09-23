@echo off
chcp 65001 >nul
title GoodbyeDPI - Tek Tikla Kurulum / One-Click Setup
cd /d "%~dp0"

rem Yonetici yetkisi kontrol
net session >nul 2>&1
if %errorlevel% neq 0 (
    echo Yonetici yetkisi isteniyor... / Requesting admin...
    powershell -Command "Start-Process -FilePath '%~f0' -Verb RunAs"
    exit /b
)

echo.
echo  ================================================
echo   GoodbyeDPI - Tek Tikla Kurulum / One-Click Setup
echo  ================================================
echo.

set "EXE=%~dp0goodbyedpi.exe"
set "NAME=GoodbyeDPI"
set "MODE=-5 --set-ttl 3"

if exist "%EXE%" (
    echo  [OK] goodbyedpi.exe zaten mevcut / already exists
    goto :install
)

echo  [..] GoodbyeDPI indiriliyor / Downloading...
echo.

powershell -NoProfile -ExecutionPolicy Bypass -Command ^
    "$ProgressPreference='SilentlyContinue'; " ^
    "$dir='%~dp0'; " ^
    "try { " ^
    "  $rel = Invoke-RestMethod 'https://api.github.com/repos/ValdikSS/GoodbyeDPI/releases/latest'; " ^
    "  $asset = $rel.assets | Where-Object { $_.name -like '*.zip' } | Select-Object -First 1; " ^
    "  if (-not $asset) { throw 'ZIP bulunamadi / ZIP not found' }; " ^
    "  Write-Host ('  Indiriliyor / Downloading: ' + $asset.name); " ^
    "  $zip = Join-Path $dir 'goodbyedpi_download.zip'; " ^
    "  Invoke-WebRequest $asset.browser_download_url -OutFile $zip; " ^
    "  Write-Host '  Cikariliyor / Extracting...'; " ^
    "  $tmp = Join-Path $dir 'goodbyedpi_tmp'; " ^
    "  if (Test-Path $tmp) { Remove-Item $tmp -Recurse -Force }; " ^
    "  Expand-Archive $zip -DestinationPath $tmp -Force; " ^
    "  $arch = if ([Environment]::Is64BitOperatingSystem) { 'x86_64' } else { 'x86' }; " ^
    "  $archDir = Get-ChildItem $tmp -Recurse -Directory | Where-Object { $_.Name -eq $arch } | Select-Object -First 1; " ^
    "  if ($archDir) { " ^
    "    Copy-Item (Join-Path $archDir.FullName '*') -Destination $dir -Force " ^
    "  } else { " ^
    "    $exeFile = Get-ChildItem $tmp -Recurse -Filter 'goodbyedpi.exe' | Select-Object -First 1; " ^
    "    if ($exeFile) { Copy-Item (Join-Path $exeFile.DirectoryName '*') -Destination $dir -Force } " ^
    "    else { throw 'goodbyedpi.exe bulunamadi / not found in archive' } " ^
    "  }; " ^
    "  Remove-Item $zip -Force -EA SilentlyContinue; " ^
    "  Remove-Item $tmp -Recurse -Force -EA SilentlyContinue; " ^
    "  Write-Host '  [OK] Indirme tamamlandi / Download complete!'; " ^
    "} catch { " ^
    "  Write-Host ('  [HATA/ERROR] ' + $_.Exception.Message); " ^
    "  exit 1 " ^
    "}"

if %errorlevel% neq 0 (
    echo.
    echo  Indirme basarisiz. Manuel olarak indirin:
    echo  Download failed. Download manually from:
    echo  https://github.com/ValdikSS/GoodbyeDPI/releases
    echo.
    pause
    exit /b 1
)

if not exist "%EXE%" (
    echo.
    echo  [HATA] goodbyedpi.exe bulunamadi / not found
    echo  Manuel olarak indirin / Download manually:
    echo  https://github.com/ValdikSS/GoodbyeDPI/releases
    echo.
    pause
    exit /b 1
)

:install
echo.
echo  [..] Servis kuruluyor / Installing service...

rem Eski servis varsa kaldir
sc stop "%NAME%" >nul 2>&1
sc delete "%NAME%" >nul 2>&1
timeout /t 1 /nobreak >nul

rem Servis olustur
set "BL=%~dp0blacklist.txt"
if exist "%BL%" (
    echo  [OK] Blacklist bulundu, sadece listedeki sitelere bypass uygulanacak
    echo       Blacklist found, bypass will only apply to listed sites
    sc create "%NAME%" binPath= "\"%EXE%\" %MODE% --blacklist \"%BL%\"" start= auto DisplayName= "GoodbyeDPI"
) else (
    sc create "%NAME%" binPath= "\"%EXE%\" %MODE%" start= auto DisplayName= "GoodbyeDPI"
)
sc description "%NAME%" "GoodbyeDPI - DPI bypass (otomatik baslatma)"
sc failure "%NAME%" reset= 0 actions= restart/5000/restart/5000/restart/5000

rem Servisi baslat
sc start "%NAME%"

echo.
echo  [..] DoH aciliyor / Enabling DoH (DNS encryption)...

netsh dns add encryption server=8.8.8.8 dohtemplate=https://dns.google/dns-query autoupgrade=yes udpfallback=no >nul 2>&1
netsh dns add encryption server=8.8.4.4 dohtemplate=https://dns.google/dns-query autoupgrade=yes udpfallback=no >nul 2>&1

for /f "delims=" %%A in ('powershell -NoProfile -Command "(Get-NetAdapter | ? {$_.Status -eq 'Up'} | Sort-Object ifIndex | Select -First 1).Name"') do set "ADAPTER=%%A"
if defined ADAPTER (
    netsh interface ipv4 set dnsservers name="%ADAPTER%" static 8.8.8.8 primary >nul 2>&1
    netsh interface ipv4 add dnsservers name="%ADAPTER%" 8.8.4.4 index=2 >nul 2>&1
)
ipconfig /flushdns >nul 2>&1

echo  [OK] DoH acildi / DoH enabled

echo.
echo  ================================================
echo   [OK] Kurulum tamamlandi! / Setup complete!
echo.
echo   Servis kuruldu ve baslatildi.
echo   Service installed and started.
echo   DoH (DNS sifreleme) acildi.
echo   DoH (DNS encryption) enabled.
echo   Mod / Mode: %MODE%
echo.
echo   Bir site acilmiyorsa panelden
echo   "Otomatik Bul" ile dogru modu buldur.
echo  ================================================
echo.

rem Paneli ac
if exist "%~dp0GoodbyeDPI-Panel.hta" (
    echo  Panel aciliyor / Opening panel...
    start "" mshta.exe "%~dp0GoodbyeDPI-Panel.hta"
)

pause
exit /b 0
