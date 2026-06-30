@echo off
rem === GoodbyeDPI servis KURULUM ===
rem Yonetici yetkisi yoksa kendini yukseltir
net session >nul 2>&1
if %errorlevel% neq 0 (
    powershell -Command "Start-Process -FilePath '%~f0' -Verb RunAs"
    exit /b
)
chcp 65001 >nul
cd /d "%~dp0"
set "EXE=%~dp0goodbyedpi.exe"
set "NAME=GoodbyeDPI"
rem Calisma modu (-5 --set-ttl 3 = Turkiye'de hem RST hem sessiz-drop DPI'yi asar; reddit+pornhub test edildi)
set "MODE=-5 --set-ttl 3"

if not exist "%EXE%" (
    echo HATA: goodbyedpi.exe bulunamadi: "%EXE%"
    pause
    exit /b 1
)

echo Eski servis varsa kaldiriliyor...
sc stop "%NAME%" >nul 2>&1
sc delete "%NAME%" >nul 2>&1
timeout /t 1 /nobreak >nul

echo Servis olusturuluyor...
sc create "%NAME%" binPath= "\"%EXE%\" %MODE%" start= auto DisplayName= "GoodbyeDPI"
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
