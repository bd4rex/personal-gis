$ErrorActionPreference = "Stop"

$root = Split-Path -Parent $PSScriptRoot
$services = Join-Path $root "services"

if (-not (Get-Command docker -ErrorAction SilentlyContinue)) {
  throw "Docker was not found on PATH. Install Docker Desktop, then run this script again."
}

Set-Location $services
docker compose up -d

Write-Host ""
Write-Host "PostGIS: localhost:5432"
Write-Host "Martin:  http://localhost:3000"
Write-Host "Web:     run scripts/start-web.ps1, then open http://localhost:8080/web/"
