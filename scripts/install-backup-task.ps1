param(
  [string]$DailyAt = "03:00",
  [string]$MirrorRoot = ""
)

$ErrorActionPreference = "Stop"
$root = Split-Path -Parent $PSScriptRoot
$script = Join-Path $PSScriptRoot "backup-giss.ps1"
$arguments = "-NoProfile -ExecutionPolicy Bypass -File `"$script`""
if ($MirrorRoot) { $arguments += " -MirrorRoot `"$MirrorRoot`"" }

$action = New-ScheduledTaskAction -Execute "powershell.exe" -Argument $arguments -WorkingDirectory $root
$trigger = New-ScheduledTaskTrigger -Daily -At $DailyAt
$settings = New-ScheduledTaskSettingsSet -StartWhenAvailable -ExecutionTimeLimit (New-TimeSpan -Hours 2) -MultipleInstances IgnoreNew
$principal = New-ScheduledTaskPrincipal -UserId $env:USERNAME -LogonType Interactive -RunLevel Limited
Register-ScheduledTask -TaskName "GISS Daily Personal Backup" -Action $action -Trigger $trigger -Settings $settings -Principal $principal -Description "Daily checksum-verified GIS_P personal-data backup" -Force | Out-Null
$policyPath = Join-Path $root "data\maintenance\backup-policy.json"
New-Item -ItemType Directory -Force -Path (Split-Path -Parent $policyPath) | Out-Null
[IO.File]::WriteAllText($policyPath, ([ordered]@{
  taskName = "GISS Daily Personal Backup"
  dailyAt = $DailyAt
  installedAt = [DateTimeOffset]::Now.ToString("o")
  mirrorConfigured = [bool]$MirrorRoot
  mirrorRoot = if ($MirrorRoot) { [IO.Path]::GetFullPath($MirrorRoot) } else { $null }
} | ConvertTo-Json), (New-Object Text.UTF8Encoding($false)))
Write-Host "Installed GIS_P scheduled task (compatibility name: GISS Daily Personal Backup) at $DailyAt"
