# FuelPlanner Build Script
# Builds both the Data Field (.iq) and Widget (.iq) for Connect IQ Store submission
#
# Usage:
#   .\build.ps1
#   .\build.ps1 -SdkPath "C:\path\to\sdk" -KeyPath "C:\path\to\developer_key.der"
#
# Prerequisites:
#   - Garmin Connect IQ SDK installed
#   - Developer key (.der file) generated via Garmin developer portal

param(
    [string]$SdkPath = "$env:APPDATA\Garmin\ConnectIQ\Sdks",
    [string]$KeyPath = "$env:USERPROFILE\developer_key"
)

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

# --- Ensure output dir exists ---
New-Item -ItemType Directory -Force -Path bin | Out-Null

$javaArgs = @("-Xms1g", "-Dfile.encoding=UTF-8", "-Dapple.awt.UIElement=true", "-jar", $monkeybrains)

# --- Build Data Field ---
Write-Host "`nBuilding Data Field..." -ForegroundColor Yellow
$dfArgs = $javaArgs + @(
    "-f", "monkey.jungle",
    "-o", "bin\FuelPlanner-DataField.iq",
    "-e",                          # export mode = .iq file for store
    "-y", $KeyPath,
    "-w"                           # warnings
)
& java @dfArgs
if ($LASTEXITCODE -ne 0) {
    Write-Error "Data Field build FAILED (exit $LASTEXITCODE)"
    exit $LASTEXITCODE
}
Write-Host "Data Field built: bin\FuelPlanner-DataField.iq" -ForegroundColor Green

# --- Build Widget ---
Write-Host "`nBuilding Widget..." -ForegroundColor Yellow
$widgetArgs = $javaArgs + @(
    "-f", "monkey-widget.jungle",
    "-o", "bin\FuelPlanner-Widget.iq",
    "-e",
    "-y", $KeyPath,
    "-w"
)
& java @widgetArgs
if ($LASTEXITCODE -ne 0) {
    Write-Error "Widget build FAILED (exit $LASTEXITCODE)"
    exit $LASTEXITCODE
}
Write-Host "Widget built:     bin\FuelPlanner-Widget.iq" -ForegroundColor Green

Write-Host "`nDone! Upload these files to the Connect IQ Store:" -ForegroundColor Cyan
Write-Host "  bin\FuelPlanner-DataField.iq"
Write-Host "  bin\FuelPlanner-Widget.iq"
