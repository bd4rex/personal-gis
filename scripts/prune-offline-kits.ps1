param(
  [int]$Keep = 2,
  [switch]$KeepFailed
)

$ErrorActionPreference = "Stop"
$root = Split-Path -Parent $PSScriptRoot
$kitRoot = Join-Path $root "offline-kit"
if (-not (Test-Path -LiteralPath $kitRoot -PathType Container)) { exit 0 }

$resolvedRoot = (Resolve-Path -LiteralPath $kitRoot).Path.TrimEnd('\')
$directories = @(Get-ChildItem -LiteralPath $resolvedRoot -Directory -Force)
$valid = @($directories | Where-Object {
  -not $_.Name.EndsWith(".failed", [StringComparison]::OrdinalIgnoreCase) -and
  (Test-Path -LiteralPath (Join-Path $_.FullName "manifest.json") -PathType Leaf)
} | Sort-Object Name -Descending)

if ($valid.Count -lt 1) { throw "Refusing to prune offline kits because no verified kit was found." }
$remove = New-Object System.Collections.Generic.List[IO.DirectoryInfo]
foreach ($directory in @($valid | Select-Object -Skip ([math]::Max(1, $Keep)))) { $remove.Add($directory) }
if (-not $KeepFailed) {
  foreach ($directory in @($directories | Where-Object { $_.Name.EndsWith(".failed", [StringComparison]::OrdinalIgnoreCase) })) { $remove.Add($directory) }
}

foreach ($directory in $remove | Sort-Object FullName -Unique) {
  $resolved = (Resolve-Path -LiteralPath $directory.FullName).Path
  if (-not $resolved.StartsWith($resolvedRoot + '\', [StringComparison]::OrdinalIgnoreCase)) {
    throw "Refusing to remove an offline kit outside $resolvedRoot"
  }
  Write-Host "Removing old offline kit: $resolved"
  Remove-Item -LiteralPath $resolved -Recurse -Force
}

Write-Host "Offline-kit retention complete. Kept $([math]::Min($valid.Count, [math]::Max(1, $Keep))) verified kits."
