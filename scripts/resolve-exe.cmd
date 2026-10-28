@echo off
rem Sets GDPI_ARCH and EXE for the calling script.
rem   %1 = panel root folder (with trailing backslash)
rem Order: bundled bin\<arch>\goodbyedpi.exe, then an old-style copy next to
rem the panel (root\goodbyedpi.exe). EXE stays empty if neither exists.
set "GDPI_ROOT=%~1"
set "GDPI_ARCH="
set "EXE="

if /i "%PROCESSOR_ARCHITECTURE%"=="AMD64" set "GDPI_ARCH=x86_64"
if /i "%PROCESSOR_ARCHITECTURE%"=="x86" set "GDPI_ARCH=x86"
rem 32-bit cmd on 64-bit Windows
if /i "%PROCESSOR_ARCHITEW6432%"=="AMD64" set "GDPI_ARCH=x86_64"
rem ARM64: WinDivert has no ARM64 driver, so GoodbyeDPI cannot run.
if /i "%PROCESSOR_ARCHITECTURE%"=="ARM64" set "GDPI_ARCH=arm64"
if /i "%PROCESSOR_ARCHITEW6432%"=="ARM64" set "GDPI_ARCH=arm64"

if "%GDPI_ARCH%"=="arm64" exit /b 0
if not defined GDPI_ARCH exit /b 0

if exist "%GDPI_ROOT%bin\%GDPI_ARCH%\goodbyedpi.exe" (
    set "EXE=%GDPI_ROOT%bin\%GDPI_ARCH%\goodbyedpi.exe"
    exit /b 0
)
if exist "%GDPI_ROOT%goodbyedpi.exe" set "EXE=%GDPI_ROOT%goodbyedpi.exe"
exit /b 0
