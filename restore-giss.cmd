@echo off
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0scripts\restore-giss.ps1" %*
