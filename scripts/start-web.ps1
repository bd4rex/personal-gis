$ErrorActionPreference = "Stop"

$root = Split-Path -Parent $PSScriptRoot
$services = Join-Path $root "services"

if (-not (Get-Command docker -ErrorAction SilentlyContinue)) {
  throw "Docker was not found on PATH. Install Docker Desktop, then run this script again."
}

Push-Location $services
try {
  docker compose up -d web
  if ($LASTEXITCODE -ne 0) { throw "Could not start the web service." }
}
finally {
  Pop-Location
}

Write-Host ""
Write-Host "Web: http://localhost:8080/"
