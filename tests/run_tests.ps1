param(
    [Parameter(Mandatory = $true)][string]$Godot,
    [switch]$WithRendering,
    [string[]]$Only = @()
)
$ErrorActionPreference = 'Stop'
$projectRoot = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
$testRoot = Join-Path $projectRoot '.godot\regression-project'
$logDirectory = Join-Path $projectRoot '.godot\test-results'
New-Item -ItemType Directory -Path $logDirectory,$testRoot -Force | Out-Null
foreach ($directory in @('data','definitions','simulation','game','ui','shaders','tests')) {
    Copy-Item -LiteralPath (Join-Path $projectRoot $directory) -Destination $testRoot -Recurse -Force
}
foreach ($name in @('project.godot','icon.svg')) { Copy-Item -LiteralPath (Join-Path $projectRoot $name) -Destination $testRoot -Force }
$script:failures = @()

function Invoke-GodotCheck([string]$Name, [string[]]$RunArguments) {
    if ($Name -ne 'import' -and $Only.Count -gt 0 -and $Name -notin $Only) { return }
    $stdoutPath = Join-Path $logDirectory "$Name.log"
    $stderrPath = Join-Path $logDirectory "$Name.errors.log"
    $process = Start-Process -FilePath $Godot -ArgumentList $RunArguments -WorkingDirectory $testRoot -PassThru -Wait -WindowStyle Hidden -RedirectStandardOutput $stdoutPath -RedirectStandardError $stderrPath
    $process.Refresh()
    Get-Content -LiteralPath $stdoutPath -Tail 20
    $errors = Get-Content -LiteralPath $stderrPath -Raw
    if ($errors) { Write-Output $errors }
    if ($process.ExitCode -ne 0 -or $errors -match '(?m)(SCRIPT ERROR:|ERROR:|FAIL)') {
        $script:failures += $Name
        Write-Output "$Name FAILED (exit $($process.ExitCode)). See $logDirectory"
    } else {
        Write-Output "$Name PASSED (exit 0)"
    }
}

Invoke-GodotCheck 'import' @('--headless', '--editor', '--path', '.', '--import', '--quit')
foreach ($test in @('validate_physics', 'validate_vehicle', 'validate_reentry_warp', 'validate_map', 'validate_parts', 'validate_modules', 'validate_structure', 'validate_surface_water', 'validate_celestial', 'validate_lunar_landing', 'profile_assemblies', 'validate_ascent', 'validate_lunar_mission')) {
    Invoke-GodotCheck $test @('--headless', '--path', '.', '--script', "tests/$test.gd")
}
Invoke-GodotCheck 'validate_manual_ascent' @('--headless', '--path', '.', '--script', 'tests/validate_ascent.gd', '--', '--manual-pilot')
Invoke-GodotCheck 'headless_scene' @('--headless', '--path', '.', '--quit-after', '30')
if ($WithRendering) {
    foreach ($test in @('validate_gameplay','validate_map_gameplay','validate_structure_gameplay','validate_editor','validate_surface_gameplay','validate_planet_visuals','validate_lunar_gameplay')) {
        Invoke-GodotCheck $test @('--audio-driver', 'Dummy', '--path', '.', '--script', "tests/$test.gd")
    }
}
if ($script:failures.Count) { throw "Failed checks: $($script:failures -join ', '). See $logDirectory" }
Write-Output 'All requested checks passed.'
