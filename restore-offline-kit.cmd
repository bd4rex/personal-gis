@echo off
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0scripts\restore-offline-kit.ps1" %*
