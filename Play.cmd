@echo off
setlocal
cd /d "%~dp0"
set "GODOT_LOCAL=%~dp0.tools\godot\Godot_v4.6.1-stable_win64.exe"
if exist "%GODOT_LOCAL%" (
    start "NOCTURNE" "%GODOT_LOCAL%" --path "%~dp0."
    exit /b 0
)
where godot >nul 2>nul
if not errorlevel 1 (
    start "NOCTURNE" godot --path "%~dp0."
    exit /b 0
)
echo Install Godot 4.6 or newer, import project.godot, and press F6 or F5.
echo Download: https://godotengine.org/download/windows/
pause
