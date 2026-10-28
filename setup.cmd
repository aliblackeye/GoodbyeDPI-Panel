@echo off
chcp 65001 >nul
title GoodbyeDPI - Tek Tikla Kurulum / One-Click Setup
cd /d "%~dp0"

rem Yonetici yetkisi kontrol
net session >nul 2>&1
if %errorlevel% neq 0 (
    echo Yonetici yetkisi isteniyor... / Requesting admin...
    powershell -NoProfile -Command "Start-Process -FilePath '%~f0' -Verb RunAs"
    exit /b
)

echo.
echo  ================================================
echo   GoodbyeDPI - Tek Tikla Kurulum / One-Click Setup
echo  ================================================
echo.

set "NAME=GoodbyeDPI"
set "BL=%~dp0blacklist.txt"

call "%~dp0scripts\resolve-exe.cmd" "%~dp0"
if "%GDPI_ARCH%"=="arm64" (
    echo  [HATA] ARM64 Windows desteklenmiyor: WinDivert surucusunun ARM64 surumu yok.
    echo  [ERROR] ARM64 Windows is not supported: WinDivert has no ARM64 driver.
    pause
    exit /b 1
)
rem Not: yol "Program Files (x86)" gibi parantez icerebilir; %EXE% parantezli
rem bloklarin icinde kullanilmaz.
if not defined EXE goto :fetch
echo  [OK] GoodbyeDPI paketle geldi / bundled: "%EXE%"
goto :pick

:fetch

rem Paketteki bin\ klasoru silinmisse: ayni resmi surumu indir (SHA-256 kontrollu)
echo  [..] bin\%GDPI_ARCH%\goodbyedpi.exe yok, resmi surum indiriliyor...
echo       bin\%GDPI_ARCH%\goodbyedpi.exe missing, downloading the official release...
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0scripts\fetch-goodbyedpi.ps1" -Root "%~dp0."
call "%~dp0scripts\resolve-exe.cmd" "%~dp0"
if not defined EXE (
    echo.
    echo  [HATA] goodbyedpi.exe bulunamadi / not found
    echo  Repoyu yeniden indir ya da manuel indir / Re-download the repo or get it from:
    echo  https://github.com/ValdikSS/GoodbyeDPI/releases
    echo.
    pause
    exit /b 1
)

:pick
rem Saglayiciya gore ilk mod (topluluk bilgisi; hat hatta degisebilir).
rem Panelde "Otomatik Bul" senin hattinda calisani bulur.
echo.
echo  Internet saglayicin hangisi? / Which ISP?
echo    1 = Turk Telekom      2 = TurkNet         3 = Superonline
echo    4 = Vodafone Net      5 = Kablonet        6 = Millenicom
echo    7 = Bilmiyorum / Diger (30 sn sonra otomatik secilir)
choice /c 1234567 /n /t 30 /d 7 /m "  Secim / Choice [1-7]: "
set "PICK=%errorlevel%"
set "MODE=-5 --set-ttl 3"
if "%PICK%"=="1" set "MODE=-5 --set-ttl 5"
if "%PICK%"=="2" set "MODE=-5 --set-ttl 5"
if "%PICK%"=="3" set "MODE=-5 --set-ttl 5"
if "%PICK%"=="4" set "MODE=-6"
if "%PICK%"=="5" set "MODE=-6"
if "%PICK%"=="6" set "MODE=-5 --set-ttl 5"

echo.
echo  [..] Servis kuruluyor / Installing service...

rem Eski servis varsa kaldir
sc stop "%NAME%" >nul 2>&1
sc delete "%NAME%" >nul 2>&1
timeout /t 1 /nobreak >nul

rem --allow-no-sni: Chromium/Electron (Discord uygulamasi dahil) buyuk
rem post-quantum ClientHello'yu 2 TCP parcasina boler; SNI ilk parcada
rem olmayinca blacklist onu taniyamaz. Bu bayrak o baglantilara da bypass uygular.
set "ARGS=%MODE%"
if exist "%BL%" set "ARGS=%MODE% --blacklist \"%BL%\" --allow-no-sni"
if exist "%BL%" echo  [OK] Blacklist bulundu, bypass listedeki sitelere uygulanacak / applies to listed sites
sc create "%NAME%" binPath= "\"%EXE%\" %ARGS%" start= auto DisplayName= "GoodbyeDPI"
sc description "%NAME%" "GoodbyeDPI - DPI bypass (otomatik baslatma)"
sc failure "%NAME%" reset= 0 actions= restart/5000/restart/5000/restart/5000

rem Servisi baslat
sc start "%NAME%"

echo.
echo  [..] DoH aciliyor / Enabling DoH (DNS encryption)...
set "DOHMSG=DoH acildi / DoH enabled (geri almak icin panelde DoH'u kapat / undo: turn DoH off in the panel)"
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0scripts\dns.ps1" -Action enable
set "DOHRC=%errorlevel%"
if "%DOHRC%"=="2" set "DOHMSG=Bu Windows surumunde yerlesik DoH yok (Windows 10). Panelde 'GoodbyeDPI DNS yonlendirme'yi dene. / No built-in DoH on this Windows."
if "%DOHRC%"=="1" set "DOHMSG=DoH acilamadi / could not enable DoH (yukaridaki hataya bak / see error above)"
echo  %DOHMSG%

echo.
echo  ================================================
echo   [OK] Kurulum tamamlandi! / Setup complete!
echo.
echo   Servis kuruldu ve baslatildi.
echo   Service installed and started.
echo   Mod / Mode: %MODE%
echo.
echo   Discord ya da bir site acilmiyorsa panelden
echo   "Otomatik Bul" ile hattinda calisan modu buldur.
echo   If Discord or a site won't open, run "Auto-Find" in the panel.
echo  ================================================
echo.

rem Paneli ac
if not exist "%~dp0GoodbyeDPI-Panel.hta" goto :done
echo  Panel aciliyor / Opening panel...
start "" mshta.exe "%~dp0GoodbyeDPI-Panel.hta"

:done

pause
exit /b 0
