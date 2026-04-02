# FuelPlanner Build Script
# Builds the Data Field (.iq) for Connect IQ Store submission.
#
# Usage:
#   .\build.ps1
#   .\build.ps1 -SdkPath "C:\path\to\sdk" -KeyPath "C:\path\to\developer_key.der"
#   .\build.ps1 -JavaPath "C:\path\to\java.exe"
#
# Prerequisites:
#   - Garmin Connect IQ SDK installed
#   - Developer key (.der file) generated via Garmin developer portal
#   - Java 11+ with the java.desktop module

param(
    [string]$SdkPath = "$env:APPDATA\Garmin\ConnectIQ\Sdks",
    [string]$KeyPath = "$env:USERPROFILE\developer_key",
    [string]$JavaPath = "",
    [string]$OutputDir = "artifacts",
    [string]$Device = "fr955",
    [switch]$Test,
    [switch]$Clean
)

function Get-JavaMajorVersion([string]$versionLine) {
    if ($versionLine -notmatch '"([0-9]+)(?:\.([0-9]+))?') {
        return $null
    }

    $first = [int]$matches[1]
    if ($first -eq 1 -and $matches[2]) {
        return [int]$matches[2]
    }
    return $first
}

# --- Auto-detect newest SDK ---
$sdk = Get-ChildItem -Path $SdkPath -Directory | Sort-Object Name -Descending | Select-Object -First 1
if (-not $sdk) {
    Write-Error "No Garmin SDK found in $SdkPath. Install the Connect IQ SDK first."
    exit 1
}
$monkeybrains = Join-Path $sdk.FullName "bin\monkeybrains.jar"
Write-Host "Using SDK: $($sdk.Name)" -ForegroundColor Cyan

# --- Find developer key ---
if (-not (Test-Path $KeyPath) -and -not (Test-Path "$KeyPath.der")) {
    Write-Error "Developer key not found at $KeyPath. Generate one at https://developer.garmin.com/connect-iq/sdk/"
    exit 1
}
if (Test-Path "$KeyPath.der") { $KeyPath = "$KeyPath.der" }
Write-Host "Using key: $KeyPath" -ForegroundColor Cyan

# --- Resolve java executable ---
$javaExe = $null
if ($JavaPath -ne "") {
    if (-not (Test-Path $JavaPath)) {
        Write-Error "Java executable not found at $JavaPath."
        exit 1
    }
    $javaExe = (Resolve-Path $JavaPath).Path
} else {
    $javaCmd = Get-Command java -ErrorAction SilentlyContinue
    if ($javaCmd -eq $null) {
        Write-Error "No java executable found in PATH. Install Java 11+ and retry."
        exit 1
    }
    $javaExe = $javaCmd.Source
}

$javaVersionOutput = & $javaExe -version 2>&1
$javaVersionLine = $javaVersionOutput | Select-Object -First 1
$javaMajor = Get-JavaMajorVersion $javaVersionLine
if ($javaMajor -eq $null) {
    Write-Error "Unable to parse Java version from: $javaVersionLine"
    exit 1
}
if ($javaMajor -lt 11) {
    Write-Error "Java 11+ is required. Current java reports: $javaVersionLine"
    exit 1
}

$hasDesktopModule = (& $javaExe --list-modules 2>$null | Select-String "^java\.desktop@" -Quiet)
if (-not $hasDesktopModule) {
    Write-Error "Selected Java runtime is missing the java.desktop module. Use a full JDK/JRE (not a reduced jlink runtime)."
    exit 1
}
Write-Host "Using Java: $javaExe" -ForegroundColor Cyan
Write-Host "Java Version: $javaVersionLine" -ForegroundColor Cyan

# --- Ensure output dir exists ---
New-Item -ItemType Directory -Force -Path $OutputDir | Out-Null
$outputRoot = (Resolve-Path $OutputDir).Path

$standardPackagePath = Join-Path $outputRoot "FuelPlanner-DataField.iq"
$testBuildPath = Join-Path $outputRoot ("FuelPlannerTests-" + $Device + ".prg")
$testBuildDebugPath = $testBuildPath + ".debug.xml"
$testSettingsPath = Join-Path $outputRoot ("FuelPlannerTests-" + $Device + "-settings.json")
$testFitContribPath = Join-Path $outputRoot ("FuelPlannerTests-" + $Device + "-fit_contributions.json")

$javaArgs = @("-Xms1g", "-Dfile.encoding=UTF-8", "-Dapple.awt.UIElement=true", "-jar", $monkeybrains)

if ($Clean) {
    Remove-Item -LiteralPath $standardPackagePath -Force -ErrorAction SilentlyContinue
    Remove-Item -LiteralPath $testBuildPath -Force -ErrorAction SilentlyContinue
    Remove-Item -LiteralPath $testBuildDebugPath -Force -ErrorAction SilentlyContinue
    Remove-Item -LiteralPath $testSettingsPath -Force -ErrorAction SilentlyContinue
    Remove-Item -LiteralPath $testFitContribPath -Force -ErrorAction SilentlyContinue
    Write-Host "Cleaned generated build artifacts from $outputRoot" -ForegroundColor Green
    exit 0
}

if ($Test) {
    Write-Host "`nBuilding Test Bundle for $Device..." -ForegroundColor Yellow
    $testArgs = $javaArgs + @(
        "-f", "monkey.tests.jungle",
        "-o", $testBuildPath,
        "-d", $Device,
        "-t",
        "-y", $KeyPath,
        "-w"
    )
    & $javaExe @testArgs
    if ($LASTEXITCODE -ne 0) {
        Write-Error "Test build FAILED (exit $LASTEXITCODE)"
        exit $LASTEXITCODE
    }
    Write-Host "Test bundle built: $testBuildPath" -ForegroundColor Green
    exit 0
}

# --- Build Data Field ---
Write-Host "`nBuilding Data Field..." -ForegroundColor Yellow
$dfArgs = $javaArgs + @(
    "-f", "monkey.jungle",
    "-o", $standardPackagePath,
    "-e",                          # export mode = .iq file for store
    "-y", $KeyPath,
    "-w"                           # warnings
)
& $javaExe @dfArgs
if ($LASTEXITCODE -ne 0) {
    Write-Error "Data Field build FAILED (exit $LASTEXITCODE)"
    exit $LASTEXITCODE
}
Write-Host "Data Field built: $standardPackagePath" -ForegroundColor Green

Write-Host "`nDone! Upload these files to the Connect IQ Store:" -ForegroundColor Cyan
Write-Host "  $standardPackagePath"
