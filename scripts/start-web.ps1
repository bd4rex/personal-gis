param(
  [ValidateRange(1, 65535)]
  [int]$Port = 8080,

  [ValidateNotNullOrEmpty()]
  [string]$BindAddress = "127.0.0.1"
)

$ErrorActionPreference = "Stop"

$root = Split-Path -Parent $PSScriptRoot

if (Get-NetTCPConnection -State Listen -LocalPort $Port -ErrorAction SilentlyContinue) {
  throw "Port $Port is already in use. Choose another port, for example: .\scripts\start-web.ps1 -Port 8081"
}

Set-Location $root
Write-Host "Web: http://${BindAddress}:$Port/web/"
python -m http.server $Port --bind $BindAddress
