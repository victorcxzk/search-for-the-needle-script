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
$source = Get-Content -LiteralPath $mainPath -Raw
$metadata = Get-Content -LiteralPath (Join-Path $projectRoot 'version.json') -Raw | ConvertFrom-Json
$versionMatch = [regex]::Match($source, '(?m)^local SCRIPT_VERSION = "([^"]+)"\r?$')
if (-not $versionMatch.Success -or $versionMatch.Groups[1].Value -ne $metadata.version) {
    throw 'main.lua SCRIPT_VERSION and version.json must agree.'
}

# Parsing alone does not catch Luau's local/register limits. Compile each file
# separately at every optimization level, so no input can accidentally be skipped.
foreach ($scriptPath in @($mainPath, $dumperPath)) {
    foreach ($optimization in 0..2) {
        & $compilerCommand.Source '--null' "-O$optimization" $scriptPath
        if ($LASTEXITCODE -ne 0) {
            throw "Luau compilation failed: $scriptPath (-O$optimization)"
        }
    }
}

Write-Output "Luau compilation passed for main.lua and dumper.lua; version $($metadata.version)."
