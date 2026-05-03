@echo off
pwsh.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0launch_game.ps1"
if %ERRORLEVEL% neq 0 powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0launch_game.ps1"
