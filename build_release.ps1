#!/usr/bin/env pwsh
# Build script for BLE PER Monitor
# Automatically extracts version from git tags and builds release

Write-Host "========================================" -ForegroundColor Cyan
Write-Host "BLE PER Monitor - Release Build Script" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

# Get the latest git tag
$gitTag = git describe --tags --abbrev=0 2>$null

if (-not $gitTag) {
    Write-Host "ERROR: No git tags found!" -ForegroundColor Red
    Write-Host "Please create a tag first, e.g.: git tag v1.0.0" -ForegroundColor Yellow
    exit 1
}

# Extract version number (remove 'v' prefix if present)
$version = $gitTag -replace '^v', ''

Write-Host "Building version: $version (from tag: $gitTag)" -ForegroundColor Green
Write-Host ""

# Update pubspec.yaml with the version from git tag
Write-Host "Updating pubspec.yaml with version $version..." -ForegroundColor Yellow
$pubspecPath = "pubspec.yaml"
$pubspecContent = Get-Content $pubspecPath -Raw
$pubspecContent = $pubspecContent -replace 'version:\s+[\d.+]+', "version: $version"
Set-Content $pubspecPath $pubspecContent -NoNewline

# Build the Windows release
Write-Host "Building Windows release..." -ForegroundColor Yellow
flutter build windows --release --build-name=$version

if ($LASTEXITCODE -ne 0) {
    Write-Host "ERROR: Build failed!" -ForegroundColor Red
    exit 1
}

Write-Host ""
Write-Host "Build completed successfully!" -ForegroundColor Green
Write-Host ""

# Create zip file
$zipName = "ble_per_monitor_${version}_release.zip"
Write-Host "Creating zip file: $zipName..." -ForegroundColor Yellow

# Remove old zip if exists
if (Test-Path $zipName) {
    Remove-Item $zipName -Force
}

# Create the zip
$sourcePath = "build\windows\x64\runner\Release"
Compress-Archive -Path $sourcePath -DestinationPath $zipName -Force

if ($LASTEXITCODE -eq 0 -or (Test-Path $zipName)) {
    $zipSize = [math]::Round((Get-Item $zipName).Length / 1MB, 2)
    Write-Host ""
    Write-Host "========================================" -ForegroundColor Cyan
    Write-Host "Release build complete!" -ForegroundColor Green
    Write-Host "========================================" -ForegroundColor Cyan
    Write-Host "Version:   $version" -ForegroundColor White
    Write-Host "Tag:       $gitTag" -ForegroundColor White
    Write-Host "Zip file:  $zipName ($zipSize MB)" -ForegroundColor White
    Write-Host "Location:  $(Get-Location)\$zipName" -ForegroundColor White
    Write-Host "========================================" -ForegroundColor Cyan
} else {
    Write-Host "ERROR: Failed to create zip file!" -ForegroundColor Red
    exit 1
}
