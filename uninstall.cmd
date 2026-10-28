@echo off
rem === GoodbyeDPI servis KALDIRMA / service UNINSTALL ===
rem Yonetici yetkisi yoksa kendini yukseltir
net session >nul 2>&1
if %errorlevel% neq 0 (
    powershell -NoProfile -Command "Start-Process -FilePath '%~f0' -Verb RunAs"
    exit /b
)
chcp 65001 >nul
cd /d "%~dp0"
set "NAME=GoodbyeDPI"

echo Servis durduruluyor...
sc stop "%NAME%"
timeout /t 3 /nobreak >nul

echo Servis siliniyor...
sc delete "%NAME%"

echo WinDivert surucu kaydi temizleniyor...
sc stop WinDivert >nul 2>&1
sc delete WinDivert >nul 2>&1
sc stop WinDivert14 >nul 2>&1
sc delete WinDivert14 >nul 2>&1

echo.
choice /c EH /n /t 20 /d H /m "Panelin actigi DoH/DNS ayarlarini da geri al? / Also undo the panel's DoH/DNS settings? [E/H] "
if errorlevel 2 goto :done
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0scripts\dns.ps1" -Action disable

:done
echo.
echo ============================================
echo  GoodbyeDPI servisi kaldirildi.
echo ============================================
echo.
pause
