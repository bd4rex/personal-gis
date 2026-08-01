@echo off
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0scripts\verify-offline-kit.ps1" %*
