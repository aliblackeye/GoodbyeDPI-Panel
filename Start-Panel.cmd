@echo off
title GoodbyeDPI Panel
cd /d "%~dp0"

rem Zaten yonetici isek dogrudan ac
net session >nul 2>&1
if %errorlevel%==0 (
    start "" mshta.exe "%~dp0GoodbyeDPI-Panel.hta"
    exit /b
)

rem Yonetici degilsek: mshta.exe'yi yukseltip .hta'yi arguman ver
powershell -NoProfile -Command "$p=[char]34+'%~dp0GoodbyeDPI-Panel.hta'+[char]34; Start-Process mshta.exe -ArgumentList $p -Verb RunAs"
if %errorlevel% neq 0 (
    echo.
    echo  HATA: Panel yonetici olarak acilamadi.
    echo  UAC penceresinde "Evet" / "Yes" demen gerekiyor.
    echo.
    echo  Error: Could not open the panel as administrator.
    echo  You must click "Yes" on the UAC prompt.
    echo.
    pause
)
exit /b
