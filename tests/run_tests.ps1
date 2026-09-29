param(
    [Parameter(Mandatory = $true)][string]$Godot,
    [switch]$WithRendering
)
$ErrorActionPreference = 'Stop'
$projectRoot = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
$logDirectory = Join-Path $projectRoot '.godot\test-results'
New-Item -ItemType Directory -Path $logDirectory -Force | Out-Null

function Invoke-GodotCheck([string]$Name, [string[]]$RunArguments) {
    $stdoutPath = Join-Path $logDirectory "$Name.log"
    $stderrPath = Join-Path $logDirectory "$Name.errors.log"
    $process = Start-Process -FilePath $Godot -ArgumentList $RunArguments -WorkingDirectory $projectRoot -PassThru -Wait -WindowStyle Hidden -RedirectStandardOutput $stdoutPath -RedirectStandardError $stderrPath
    Get-Content -LiteralPath $stdoutPath
    $errors = Get-Content -LiteralPath $stderrPath -Raw
    if ($errors) { Write-Output $errors }
    if ($process.ExitCode -ne 0 -or $errors -match '(?m)(SCRIPT ERROR:|ERROR:|FAIL)') {
        throw "$Name failed. See $logDirectory"
    }
}

Invoke-GodotCheck 'import' @('--headless', '--editor', '--path', '.', '--import', '--quit')
foreach ($test in @('validate_physics', 'validate_vehicle', 'validate_reentry_warp', 'validate_map', 'validate_ascent')) {
    Invoke-GodotCheck $test @('--headless', '--path', '.', '--script', "tests/$test.gd")
}
Invoke-GodotCheck 'validate_manual_ascent' @('--headless', '--path', '.', '--script', 'tests/validate_ascent.gd', '--', '--manual-pilot')
Invoke-GodotCheck 'headless_scene' @('--headless', '--path', '.', '--quit-after', '30')
if ($WithRendering) {
    Invoke-GodotCheck 'validate_gameplay' @('--path', '.', '--script', 'tests/validate_gameplay.gd')
    Invoke-GodotCheck 'validate_map_gameplay' @('--path', '.', '--script', 'tests/validate_map_gameplay.gd')
}
Write-Output 'All requested checks passed.'
