@echo off
rem === GoodbyeDPI servis KURULUM / service INSTALL ===
rem Kullanim / usage:  install.cmd [mod]     ornek / e.g.:  install.cmd -6
rem Mod verilmezse "-5 --set-ttl 3" kullanilir.
rem Yonetici yetkisi yoksa kendini yukseltir
net session >nul 2>&1
if %errorlevel%==0 goto :elevated
if "%~1"=="" powershell -NoProfile -Command "Start-Process -FilePath '%~f0' -Verb RunAs"
if not "%~1"=="" powershell -NoProfile -Command "Start-Process -FilePath '%~f0' -ArgumentList '%*' -Verb RunAs"
exit /b

:elevated
chcp 65001 >nul
cd /d "%~dp0"
set "NAME=GoodbyeDPI"
rem Varsayilan mod: Turkiye'de hem RST hem sessiz-drop DPI'yi asar (yazarin hattinda test edildi).
rem Saglayiciya gore oneriler ve "Otomatik Bul" icin panele bak.
set "MODE=-5 --set-ttl 3"
if not "%~1"=="" set "MODE=%*"

call "%~dp0scripts\resolve-exe.cmd" "%~dp0"
if "%GDPI_ARCH%"=="arm64" goto :arm64
if not defined EXE goto :noexe

echo GoodbyeDPI: "%EXE%"
echo Mod / mode: %MODE%
echo Eski servis varsa kaldiriliyor...
sc stop "%NAME%" >nul 2>&1
sc delete "%NAME%" >nul 2>&1
timeout /t 1 /nobreak >nul

echo Servis olusturuluyor...
rem --allow-no-sni: blacklist modunda SNI'si ilk TCP parcasinda olmayan
rem (Chromium/Electron post-quantum) ClientHello'lara da bypass uygular.
set "BL=%~dp0blacklist.txt"
set "ARGS=%MODE%"
if exist "%BL%" set "ARGS=%MODE% --blacklist \"%BL%\" --allow-no-sni"
sc create "%NAME%" binPath= "\"%EXE%\" %ARGS%" start= auto DisplayName= "GoodbyeDPI"
sc description "%NAME%" "GoodbyeDPI - DPI bypass (otomatik baslatma)"
sc failure "%NAME%" reset= 0 actions= restart/5000/restart/5000/restart/5000

echo Servis baslatiliyor...
sc start "%NAME%"

echo.
echo ============================================
echo  GoodbyeDPI servisi kuruldu ve baslatildi.
echo  (Otomatik baslangic - her acilista calisir)
echo ============================================
echo.
pause
exit /b 0

:arm64
echo HATA: ARM64 Windows desteklenmiyor (WinDivert'in ARM64 surucusu yok).
pause
exit /b 1

:noexe
echo HATA: goodbyedpi.exe bulunamadi (bin\%GDPI_ARCH%\ ya da panel klasoru).
echo setup.cmd'yi calistir: eksikse resmi surumu indirir.
pause
exit /b 1
