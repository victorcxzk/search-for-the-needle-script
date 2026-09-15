# Requires the official Luau CLI compiler (https://github.com/luau-lang/luau/releases).
# Usage: ./scripts/check-luau.ps1 -Compiler 'C:/path/to/luau-compile.exe'
[CmdletBinding()]
param(
    [string]$Compiler = 'luau-compile'
)

$ErrorActionPreference = 'Stop'
$projectRoot = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot '..')).Path
$compilerCommand = Get-Command $Compiler -CommandType Application -ErrorAction Stop
$mainPath = Join-Path $projectRoot 'main.lua'
$dumperPath = Join-Path $projectRoot 'dumper.lua'
$solverPath = Join-Path $projectRoot 'lib/basement_solver.luau'
$specPath = Join-Path $projectRoot 'tests/basement_solver.spec.luau'
$source = Get-Content -LiteralPath $mainPath -Raw
$metadata = Get-Content -LiteralPath (Join-Path $projectRoot 'version.json') -Raw | ConvertFrom-Json
$versionMatch = [regex]::Match($source, '(?m)^local SCRIPT_VERSION = "([^"]+)"\r?$')
if (-not $versionMatch.Success -or $versionMatch.Groups[1].Value -ne $metadata.version) {
    throw 'main.lua SCRIPT_VERSION and version.json must agree.'
}

# The HTTP loader is a single file. Test the pure module and verify the shipped
# embedded copy is identical, so module tests cannot validate an unshipped copy.
$solverSource = (Get-Content -LiteralPath $solverPath -Raw).Replace("`r`n", "`n").Trim()
$embedded = [regex]::Match($source.Replace("`r`n", "`n"), '(?s)-- BEGIN EMBEDDED BASEMENT SOLVER\n(.*?)\n-- END EMBEDDED BASEMENT SOLVER')
if (-not $embedded.Success -or $embedded.Groups[1].Value.Trim() -ne $solverSource) {
    throw 'main.lua embedded solver differs from lib/basement_solver.luau.'
}

# Parsing alone does not catch Luau's local/register limits. Compile each file
# separately at every optimization level, so no input can accidentally be skipped.
foreach ($scriptPath in @($mainPath, $dumperPath, $solverPath, $specPath)) {
    foreach ($optimization in 0..2) {
        & $compilerCommand.Source '--null' "-O$optimization" $scriptPath
        if ($LASTEXITCODE -ne 0) {
            throw "Luau compilation failed: $scriptPath (-O$optimization)"
        }
    }
}

$runtimePath = Join-Path (Split-Path $compilerCommand.Source) 'luau.exe'
if (-not (Test-Path -LiteralPath $runtimePath)) {
    throw 'Unit tests require luau.exe alongside luau-compile.exe.'
}
& $runtimePath $specPath
if ($LASTEXITCODE -ne 0) { throw 'Basement solver unit tests failed.' }

Write-Output "Luau compilation and basement solver tests passed; version $($metadata.version)."
