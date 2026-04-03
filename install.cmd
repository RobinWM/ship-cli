@echo off
setlocal

powershell -NoProfile -ExecutionPolicy Bypass -Command "irm https://raw.githubusercontent.com/RobinWM/ship-cli/main/install.ps1 | iex"
set "EXIT_CODE=%ERRORLEVEL%"

if not "%EXIT_CODE%"=="0" (
  exit /b %EXIT_CODE%
)

exit /b 0
