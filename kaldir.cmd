@echo off
rem === GoodbyeDPI servis KALDIRMA ===
rem Yonetici yetkisi yoksa kendini yukseltir
net session >nul 2>&1
if %errorlevel% neq 0 (
    powershell -Command "Start-Process -FilePath '%~f0' -Verb RunAs"
    exit /b
)
chcp 65001 >nul
set "NAME=GoodbyeDPI"

echo Servis durduruluyor...
sc stop "%NAME%"
timeout /t 3 /nobreak >nul

echo Servis siliniyor...
sc delete "%NAME%"

echo WinDivert surucu kaydi temizleniyor...
sc stop WinDivert >nul 2>&1
sc delete WinDivert >nul 2>&1

echo.
echo ============================================
echo  GoodbyeDPI servisi kaldirildi.
echo ============================================
echo.
pause
