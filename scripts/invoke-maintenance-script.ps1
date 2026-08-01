param(
  [Parameter(Mandatory = $true)]
  [string]$InvocationFile
)

$ErrorActionPreference = "Stop"
$invocation = $null

function Write-InvocationResult([int]$ExitCode, [string]$ErrorMessage = "") {
  if (-not $invocation -or -not $invocation.resultFile) { return }
  $resultPath = [string]$invocation.resultFile
  $temporary = "$resultPath.$([Guid]::NewGuid().ToString('N')).tmp"
  $result = [ordered]@{
    exitCode = $ExitCode
    succeeded = $ExitCode -eq 0
    error = $ErrorMessage
    finishedAt = [DateTimeOffset]::Now.ToString("o")
  }
  [IO.File]::WriteAllText(
    $temporary,
    ($result | ConvertTo-Json -Depth 4),
    (New-Object Text.UTF8Encoding($false))
  )
  Move-Item -LiteralPath $temporary -Destination $resultPath -Force
}

try {
  $invocation = Get-Content -Raw -LiteralPath $InvocationFile | ConvertFrom-Json
  $script = [string]$invocation.script
  $parameters = @{}
  if ($invocation.parameters) {
    foreach ($property in $invocation.parameters.PSObject.Properties) {
      $parameters[$property.Name] = $property.Value
    }
  }
  if (-not (Test-Path -LiteralPath $script -PathType Leaf)) {
    throw "Maintenance script is missing: $script"
  }
  & $script @parameters
  if (-not $?) { throw "Maintenance script reported failure without a process exit code." }
  Write-InvocationResult -ExitCode 0
  exit 0
}
catch {
  $message = $_.Exception.Message
  Write-InvocationResult -ExitCode 1 -ErrorMessage $message
  Write-Error $message
  exit 1
}
