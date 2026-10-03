param([string]$Test = 'validate_parts', [switch]$Render, [switch]$ImportOnly)
$ErrorActionPreference = 'Stop'
$projectRoot = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
$sandboxRoot = Join-Path $projectRoot '.godot\sandbox-development-v2'
$logsRoot = Join-Path $projectRoot '.godot\phase-results'
New-Item -ItemType Directory -Path $sandboxRoot,$logsRoot -Force | Out-Null
foreach ($directory in @('data','definitions','simulation','game','ui','shaders','tests')) {
    Copy-Item -LiteralPath (Join-Path $projectRoot $directory) -Destination $sandboxRoot -Recurse -Force
}
foreach ($name in @('project.godot','icon.svg')) { Copy-Item -LiteralPath (Join-Path $projectRoot $name) -Destination $sandboxRoot -Force }
$engine = 'C:\Users\m.vetere\Desktop\Godot_v4.6.1-stable_win64.exe'
function Run-Check([string]$Name,[string[]]$Arguments) {
    $run = Start-Process -FilePath $engine -ArgumentList $Arguments -WorkingDirectory $sandboxRoot -PassThru -Wait -WindowStyle Hidden -RedirectStandardOutput (Join-Path $logsRoot "$Name.log") -RedirectStandardError (Join-Path $logsRoot "$Name.errors.log")
    $run.Refresh()
    Get-Content -LiteralPath (Join-Path $logsRoot "$Name.log") -Tail 30
    $errors = Get-Content -LiteralPath (Join-Path $logsRoot "$Name.errors.log") -Raw
    if ($errors) { Write-Output $errors }
    if ($run.ExitCode -ne 0 -or $errors -match '(SCRIPT ERROR:|ERROR:|FAIL)') { throw "$Name failed with exit $($run.ExitCode)" }
}
Run-Check 'import' @('--headless','--editor','--path','.','--import','--quit')
if (-not $ImportOnly) {
    $arguments = @('--path','.','--script',"tests/$Test.gd")
    if (-not $Render) { $arguments = @('--headless') + $arguments }
    else { $arguments = @('--audio-driver','Dummy') + $arguments }
    Run-Check $Test $arguments
}
