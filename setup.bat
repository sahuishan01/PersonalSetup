@echo off
setlocal
echo [INFO] Running PersonalSetup installer for Windows...
powershell -ExecutionPolicy Bypass -File "%~dp0install.ps1" %*
endlocal
