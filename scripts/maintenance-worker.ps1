param(
  [ValidateRange(1, 30)]
  [int]$PollSeconds = 2
)

$ErrorActionPreference = "Stop"
$root = Split-Path -Parent $PSScriptRoot
$maintenanceRoot = Join-Path $root "data\maintenance"
$jobsRoot = Join-Path $maintenanceRoot "jobs"
$logsRoot = Join-Path $maintenanceRoot "logs"
$workerPath = Join-Path $maintenanceRoot "worker.json"
$settingsPath = Join-Path $maintenanceRoot "settings.json"
$schedulerPath = Join-Path $maintenanceRoot "scheduler.json"
$stopPath = Join-Path $maintenanceRoot "stop.request"
$utf8 = New-Object Text.UTF8Encoding($false)

New-Item -ItemType Directory -Force -Path $jobsRoot, $logsRoot | Out-Null

function Read-JsonFile {
  param([string]$Path)
  if (-not (Test-Path -LiteralPath $Path -PathType Leaf)) { return $null }
  try { return Get-Content -Raw -LiteralPath $Path | ConvertFrom-Json }
  catch { return $null }
}

function Write-JsonFile {
  param([string]$Path, [object]$Value)
  $temporary = "$Path.$([Guid]::NewGuid().ToString('N')).tmp"
  [IO.File]::WriteAllText($temporary, ($Value | ConvertTo-Json -Depth 12), $utf8)
  Move-Item -LiteralPath $temporary -Destination $Path -Force
}

function Set-ObjectProperty {
  param([object]$Value, [string]$Name, [object]$PropertyValue)
  if ($Value.PSObject.Properties.Name -contains $Name) { $Value.$Name = $PropertyValue }
  else { $Value | Add-Member -NotePropertyName $Name -NotePropertyValue $PropertyValue }
}

function Write-WorkerState {
  param([string]$Status = "running", [string]$CurrentJobId = "")
  Write-JsonFile -Path $workerPath -Value ([ordered]@{
    schemaVersion = 2
    status = $Status
    pid = $PID
    heartbeatAt = [DateTimeOffset]::Now.ToString("o")
    currentJobId = $CurrentJobId
  })
}

function Get-ActiveJob {
  param([string]$ResourceId)
  foreach ($path in Get-ChildItem -LiteralPath $jobsRoot -Filter "*.json" -File -ErrorAction SilentlyContinue) {
    $job = Read-JsonFile -Path $path.FullName
    if ($job -and $job.resourceId -eq $ResourceId -and $job.status -in @("queued", "running")) { return $job }
  }
  return $null
}

function Restore-InterruptedJobs {
  foreach ($path in Get-ChildItem -LiteralPath $jobsRoot -Filter "*.json" -File -ErrorAction SilentlyContinue) {
    $job = Read-JsonFile -Path $path.FullName
    if (-not $job -or $job.status -ne "running") { continue }
    if ($job.operation -eq "shared-capabilities") {
      Stop-JobCandidates -JobId ([string]$job.id)
      Set-ObjectProperty -Value $job -Name "status" -PropertyValue "failed"
      Set-ObjectProperty -Value $job -Name "message" -PropertyValue "后台候选构建被系统中断；当前地图未切换，请检查后手动重试"
      Set-ObjectProperty -Value $job -Name "finishedAt" -PropertyValue ([DateTimeOffset]::Now.ToString("o"))
      Set-ObjectProperty -Value $job -Name "exitCode" -PropertyValue 1
    }
    else {
      Set-ObjectProperty -Value $job -Name "status" -PropertyValue "queued"
      Set-ObjectProperty -Value $job -Name "message" -PropertyValue "检测到维护服务中断，任务已恢复到队列"
      Set-ObjectProperty -Value $job -Name "startedAt" -PropertyValue $null
    }
    Write-JsonFile -Path $path.FullName -Value $job
  }
}

function Add-AutomaticJobs {
  $settings = Read-JsonFile -Path $settingsPath
  if (-not $settings -or -not $settings.enabled) { return }

  $schedule = @{}
  $storedSchedule = Read-JsonFile -Path $schedulerPath
  if ($storedSchedule -and $storedSchedule.resources) {
    foreach ($property in $storedSchedule.resources.PSObject.Properties) { $schedule[$property.Name] = $property.Value }
  }
  elseif ($storedSchedule -and $storedSchedule.lastScheduled) {
    foreach ($property in $storedSchedule.lastScheduled.PSObject.Properties) {
      $schedule[$property.Name] = [pscustomobject]@{ lastAttempted = [string]$property.Value; lastSucceeded = [string]$property.Value }
    }
  }
  $resources = @(
    [pscustomobject]@{ Id = "weather"; Label = "天气快照"; IntervalHours = 6 },
    [pscustomobject]@{ Id = "world-region-catalog"; Label = "全球区域目录"; IntervalHours = 168 },
    [pscustomobject]@{ Id = "overview-map"; Label = "全球概览地图"; IntervalHours = 720 }
  )
  $changed = $false
  foreach ($resource in $resources) {
    $resourceSetting = $settings.resources.PSObject.Properties[$resource.Id].Value
    if (-not $resourceSetting -or -not $resourceSetting.enabled) { continue }
    $intervalHours = if ($resourceSetting.intervalHours) { [double]$resourceSetting.intervalHours } else { [double]$resource.IntervalHours }
    $resourceSchedule = if ($schedule.ContainsKey($resource.Id)) { $schedule[$resource.Id] } else { $null }
    $lastSucceeded = if ($resourceSchedule -and $resourceSchedule.lastSucceeded) { [DateTimeOffset]::Parse([string]$resourceSchedule.lastSucceeded) } else { [DateTimeOffset]::MinValue }
    $lastAttempted = if ($resourceSchedule -and $resourceSchedule.lastAttempted) { [DateTimeOffset]::Parse([string]$resourceSchedule.lastAttempted) } else { [DateTimeOffset]::MinValue }
    if (([DateTimeOffset]::Now - $lastSucceeded).TotalHours -lt $intervalHours) { continue }
    if (([DateTimeOffset]::Now - $lastAttempted).TotalMinutes -lt 60) { continue }
    if (Get-ActiveJob -ResourceId $resource.Id) { continue }

    $jobId = [Guid]::NewGuid().ToString("N")
    $now = [DateTimeOffset]::Now.ToString("o")
    $job = [ordered]@{
      id = $jobId
      resourceId = $resource.Id
      action = "update"
      operation = $resource.Id
      label = $resource.Label
      heavy = $false
      priority = 50
      automatic = $true
      attempts = 0
      maxAttempts = 3
      nextAttemptAt = $now
      cancelRequested = $false
      status = "queued"
      message = "自动更新已加入队列"
      requestedAt = $now
      startedAt = $null
      finishedAt = $null
      exitCode = $null
      logFile = "logs/$jobId.log"
    }
    Write-JsonFile -Path (Join-Path $jobsRoot "$jobId.json") -Value $job
    $schedule[$resource.Id] = [ordered]@{ lastAttempted = $now; lastSucceeded = if ($resourceSchedule) { $resourceSchedule.lastSucceeded } else { $null } }
    $changed = $true
  }
  if ($changed) {
    Write-JsonFile -Path $schedulerPath -Value ([ordered]@{ resources = $schedule })
  }
}

function Set-ScheduleSuccess {
  param([string]$ResourceId)
  $stored = Read-JsonFile -Path $schedulerPath
  $resources = @{}
  if ($stored -and $stored.resources) {
    foreach ($property in $stored.resources.PSObject.Properties) { $resources[$property.Name] = $property.Value }
  }
  $now = [DateTimeOffset]::Now.ToString("o")
  $previous = if ($resources.ContainsKey($ResourceId)) { $resources[$ResourceId] } else { $null }
  $resources[$ResourceId] = [ordered]@{ lastAttempted = if ($previous -and $previous.lastAttempted) { $previous.lastAttempted } else { $now }; lastSucceeded = $now }
  Write-JsonFile -Path $schedulerPath -Value ([ordered]@{ resources = $resources })
}

function Stop-JobCandidates {
  param([string]$JobId)
  if (-not $JobId -or -not (Get-Command docker -ErrorAction SilentlyContinue)) { return }
  try {
    $containers = @(docker ps -aq --filter "label=giss.maintenance-job=$JobId" 2>$null)
    if ($containers.Count) { docker rm -f @containers *> $null }
    $volumes = @(docker volume ls -q --filter "label=giss.maintenance-job=$JobId" 2>$null)
    if ($volumes.Count) { docker volume rm @volumes *> $null }
  }
  catch {
    # Candidate cleanup is best-effort; the active map must never be stopped here.
  }
}

function Get-JobCommand {
  param([object]$Job)
  switch ([string]$Job.operation) {
    "region-pack" {
      $action = switch ([string]$Job.action) {
        "build" { "Build" }
        "rebuild" { "Build" }
        "rollback" { "Rollback" }
        "verify" { "Verify" }
        "remove" { "Remove" }
        default { "Update" }
      }
      $parameters = [ordered]@{ Action = $action; PackId = [string]$Job.resourceId }
      if ($action -eq "Remove") { $parameters.ConfirmRemove = $true }
      return [pscustomobject]@{ Script = (Join-Path $PSScriptRoot "region-pack.ps1"); Parameters = $parameters }
    }
    "shared-capabilities" { return [pscustomobject]@{ Script = (Join-Path $PSScriptRoot "rebuild-shared-indexes.ps1"); Parameters = [ordered]@{ ConfirmRebuild = $true; MaintenanceJobId = [string]$Job.id } } }
    "world-region-catalog" { return [pscustomobject]@{ Script = (Join-Path $PSScriptRoot "sync-world-catalog.ps1"); Parameters = [ordered]@{} } }
    "overview-map" { return [pscustomobject]@{ Script = (Join-Path $PSScriptRoot "sync-overview-resources.ps1"); Parameters = [ordered]@{} } }
    "weather" { return [pscustomobject]@{ Script = (Join-Path $PSScriptRoot "sync-weather.ps1"); Parameters = [ordered]@{} } }
    "nautical" { return [pscustomobject]@{ Script = (Join-Path $PSScriptRoot "build-nautical.ps1"); Parameters = [ordered]@{} } }
    "encyclopedia" { return [pscustomobject]@{ Script = (Join-Path $PSScriptRoot "download-encyclopedia.ps1"); Parameters = [ordered]@{} } }
    "travel-guide" { return [pscustomobject]@{ Script = (Join-Path $PSScriptRoot "download-travel-guide.ps1"); Parameters = [ordered]@{} } }
    default { throw "Maintenance operation is not allowlisted: $($Job.operation)" }
  }
}

function Invoke-MaintenanceJob {
  param([IO.FileInfo]$JobFile, [object]$Job)
  $jobId = [string]$Job.id
  $logPath = Join-Path $logsRoot "$jobId.log"
  $errorPath = Join-Path $logsRoot "$jobId.error.log"
  $invocationPath = Join-Path $logsRoot "$jobId.invocation.json"
  $resultPath = Join-Path $logsRoot "$jobId.result.json"
  $attempts = [int]$Job.attempts + 1
  Set-ObjectProperty -Value $Job -Name "attempts" -PropertyValue $attempts
  Set-ObjectProperty -Value $Job -Name "status" -PropertyValue "running"
  Set-ObjectProperty -Value $Job -Name "startedAt" -PropertyValue ([DateTimeOffset]::Now.ToString("o"))
  Set-ObjectProperty -Value $Job -Name "message" -PropertyValue "本机维护服务正在执行"
  Write-JsonFile -Path $JobFile.FullName -Value $Job
  Write-WorkerState -CurrentJobId $jobId

  $cancelled = $false
  try {
    $command = Get-JobCommand -Job $Job
    if (-not (Test-Path -LiteralPath $command.Script -PathType Leaf)) { throw "Maintenance script is missing: $($command.Script)" }
    Write-JsonFile -Path $invocationPath -Value ([ordered]@{
      script = $command.Script
      parameters = $command.Parameters
      resultFile = $resultPath
    })
    $wrapper = Join-Path $PSScriptRoot "invoke-maintenance-script.ps1"
    $arguments = @("-NoProfile", "-ExecutionPolicy", "Bypass", "-File", $wrapper, "-InvocationFile", $invocationPath)
    $process = Start-Process -FilePath "powershell.exe" -ArgumentList $arguments -WindowStyle Hidden -RedirectStandardOutput $logPath -RedirectStandardError $errorPath -PassThru
    while (-not $process.HasExited) {
      $latestJob = Read-JsonFile -Path $JobFile.FullName
      if ($latestJob -and $latestJob.cancelRequested) {
        $cancelled = $true
        Stop-Process -Id $process.Id -Force -ErrorAction SilentlyContinue
        Stop-JobCandidates -JobId $jobId
        throw "任务已由用户取消"
      }
      if (Test-Path -LiteralPath $stopPath -PathType Leaf) {
        Stop-Process -Id $process.Id -Force -ErrorAction SilentlyContinue
        Stop-JobCandidates -JobId $jobId
        throw "维护服务已停止，任务被中断"
      }
      Write-WorkerState -CurrentJobId $jobId
      Start-Sleep -Seconds $PollSeconds
      $process.Refresh()
    }
    $process.WaitForExit()
    $process.Refresh()
    $result = Read-JsonFile -Path $resultPath
    if (-not $result) { throw "维护包装器没有生成结果凭证，任务状态不可信。" }
    $exitCode = [int]$result.exitCode
    if ($exitCode -ne 0) {
      $errorMessage = if ($result.error) { [string]$result.error } elseif (Test-Path -LiteralPath $errorPath) { (Get-Content -LiteralPath $errorPath -Tail 3) -join " " } else { "脚本返回非零状态" }
      throw "退出码 ${exitCode}：$errorMessage"
    }
    Set-ObjectProperty -Value $Job -Name "status" -PropertyValue "succeeded"
    Set-ObjectProperty -Value $Job -Name "message" -PropertyValue "任务完成"
    Set-ObjectProperty -Value $Job -Name "exitCode" -PropertyValue 0
    Set-ObjectProperty -Value $Job -Name "nextAttemptAt" -PropertyValue $null
    # Keep the last complete inventory readable while the UI starts a fresh
    # background scan after observing this job transition.
    if ($Job.automatic) { Set-ScheduleSuccess -ResourceId ([string]$Job.resourceId) }
  }
  catch {
    $maxAttempts = if ($Job.maxAttempts) { [int]$Job.maxAttempts } else { 1 }
    if (-not $cancelled -and $attempts -lt $maxAttempts -and -not (Test-Path -LiteralPath $stopPath -PathType Leaf)) {
      $delayMinutes = [math]::Min(120, [math]::Pow(2, $attempts - 1) * 5)
      Set-ObjectProperty -Value $Job -Name "status" -PropertyValue "queued"
      Set-ObjectProperty -Value $Job -Name "message" -PropertyValue "执行失败，将在 $delayMinutes 分钟后重试：$($_.Exception.Message)"
      Set-ObjectProperty -Value $Job -Name "nextAttemptAt" -PropertyValue ([DateTimeOffset]::Now.AddMinutes($delayMinutes).ToString("o"))
      Set-ObjectProperty -Value $Job -Name "startedAt" -PropertyValue $null
      Set-ObjectProperty -Value $Job -Name "finishedAt" -PropertyValue $null
    }
    else {
      Set-ObjectProperty -Value $Job -Name "status" -PropertyValue $(if ($cancelled) { "cancelled" } else { "failed" })
      Set-ObjectProperty -Value $Job -Name "message" -PropertyValue $_.Exception.Message
      Set-ObjectProperty -Value $Job -Name "exitCode" -PropertyValue 1
    }
  }
  finally {
    Remove-Item -LiteralPath $invocationPath -Force -ErrorAction SilentlyContinue
    Remove-Item -LiteralPath $resultPath -Force -ErrorAction SilentlyContinue
    if ($Job.status -ne "queued") { Set-ObjectProperty -Value $Job -Name "finishedAt" -PropertyValue ([DateTimeOffset]::Now.ToString("o")) }
    Set-ObjectProperty -Value $Job -Name "cancelRequested" -PropertyValue $false
    Write-JsonFile -Path $JobFile.FullName -Value $Job
    Write-WorkerState
  }
}

function Remove-ExpiredHistory {
  $cutoff = [DateTimeOffset]::Now.AddDays(-30)
  $completed = Get-ChildItem -LiteralPath $jobsRoot -Filter "*.json" -File -ErrorAction SilentlyContinue |
    ForEach-Object { [pscustomobject]@{ File = $_; Job = (Read-JsonFile -Path $_.FullName) } } |
    Where-Object { $_.Job -and $_.Job.status -in @("succeeded", "failed", "cancelled") } |
    Sort-Object { [string]$_.Job.finishedAt } -Descending
  foreach ($entry in @($completed | Select-Object -Skip 200)) {
    Remove-Item -LiteralPath $entry.File.FullName -Force -ErrorAction SilentlyContinue
    Remove-Item -LiteralPath (Join-Path $logsRoot "$($entry.Job.id).log"), (Join-Path $logsRoot "$($entry.Job.id).error.log") -Force -ErrorAction SilentlyContinue
  }
  foreach ($entry in @($completed | Select-Object -First 200)) {
    if (-not $entry.Job.finishedAt) { continue }
    if ([DateTimeOffset]::Parse([string]$entry.Job.finishedAt) -ge $cutoff) { continue }
    Remove-Item -LiteralPath $entry.File.FullName -Force -ErrorAction SilentlyContinue
    Remove-Item -LiteralPath (Join-Path $logsRoot "$($entry.Job.id).log"), (Join-Path $logsRoot "$($entry.Job.id).error.log") -Force -ErrorAction SilentlyContinue
  }
}

$mutex = New-Object Threading.Mutex($false, "Local\GISS-MaintenanceWorker")
if (-not $mutex.WaitOne(0)) { exit 0 }

try {
  Write-WorkerState
  Restore-InterruptedJobs
  Remove-ExpiredHistory
  while (-not (Test-Path -LiteralPath $stopPath -PathType Leaf)) {
    Write-WorkerState
    Add-AutomaticJobs
    $nextJob = Get-ChildItem -LiteralPath $jobsRoot -Filter "*.json" -File -ErrorAction SilentlyContinue |
      ForEach-Object { [pscustomobject]@{ File = $_; Job = (Read-JsonFile -Path $_.FullName) } } |
      Where-Object { $_.Job -and $_.Job.status -eq "queued" } |
      Where-Object { -not $_.Job.nextAttemptAt -or [DateTimeOffset]::Parse([string]$_.Job.nextAttemptAt) -le [DateTimeOffset]::Now } |
      Sort-Object @{ Expression = { if ($_.Job.priority) { [int]$_.Job.priority } else { 100 } } }, @{ Expression = { [string]$_.Job.requestedAt } } |
      Select-Object -First 1
    if ($nextJob) { Invoke-MaintenanceJob -JobFile $nextJob.File -Job $nextJob.Job }
    else { Start-Sleep -Seconds $PollSeconds }
  }
}
finally {
  Write-WorkerState -Status "stopped"
  $mutex.ReleaseMutex()
  $mutex.Dispose()
}
