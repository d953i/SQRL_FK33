@echo off
rem Install the test-signed sqrlfk.sys driver package from this folder (install.bat), or remove it
rem (install.bat /uninstall); see install.ps1. Asks for administrator rights.
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0install.ps1" %*
