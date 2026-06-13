# AutoUpdater.ps1 - Kingdom & Co Auto-Updater
# This script checks for updates, downloads a ZIP package, and extracts it to the current directory.

$VersionUrl = "https://raw.githubusercontent.com/MaleK11-glitch/KINGDOM-CO-MEmu-Auto-Installer-RoKv2/main/version.dll"
$ZipUrl = "https://github.com/MaleK11-glitch/KINGDOM-CO-MEmu-Auto-Installer-RoKv2/archive/refs/heads/main.zip"
$SilentUpdate = $false  # Set to $true to update automatically without asking the user

$LocalVersionFile = Join-Path $PSScriptRoot "version.dll"
$TempZipPath = Join-Path $env:TEMP "KingdomCo_Update.zip"
$TempExtractPath = Join-Path $env:TEMP "KingdomCo_Update_Extract"

Write-Host "=============================================" -ForegroundColor Cyan
Write-Host "        Auto-Updater - KINGDOM & CO" -ForegroundColor Cyan
Write-Host "=============================================" -ForegroundColor Cyan
Write-Host ""

# 1. Read Local Version
$LocalVersion = "missing"
if (Test-Path $LocalVersionFile) {
    $LocalVersion = (Get-Content $LocalVersionFile -Raw).Trim()
}
Write-Host "Local Version: $LocalVersion" -ForegroundColor White

# Helper function to check internet and fetch remote string
function Get-RemoteVersion {
    try {
        $req = [System.Net.WebRequest]::Create($VersionUrl)
        if ($req -is [System.Net.HttpWebRequest]) {
            $req.UserAgent = "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36"
        }
        $req.Timeout = 10000  # 10 seconds timeout
        $resp = $req.GetResponse()
        $respStream = $resp.GetResponseStream()
        $reader = New-Object System.IO.StreamReader($respStream)
        $val = $reader.ReadToEnd().Trim()
        $reader.Close(); $respStream.Close(); $resp.Close()
        return $val
    } catch {
        return $null
    }
}

# 2. Get Remote Version
Write-Host "Checking for updates..." -ForegroundColor Gray
$RemoteVersion = Get-RemoteVersion

if ($null -eq $RemoteVersion) {
    Write-Host "  [Warning] Could not connect to update server. Skipping update check." -ForegroundColor Yellow
    Write-Host ""
    exit 0
}

Write-Host "Remote Version: $RemoteVersion" -ForegroundColor White

# 3. Compare Versions
if ($LocalVersion -eq $RemoteVersion) {
    Write-Host "  [OK] You are running the latest version." -ForegroundColor Green
    Write-Host ""
    exit 0
}

# 4. Handle Update
Write-Host ""
Write-Host "New update found! Version $RemoteVersion is available." -ForegroundColor Yellow

if (-not $SilentUpdate) {
    $choice = Read-Host "  Do you want to download and install the update now? (Y/N)"
    if ($choice -notmatch '^[Yy]$') {
        Write-Host "  Update cancelled by user." -ForegroundColor Yellow
        Write-Host ""
        exit 0
    }
}

Write-Host "  [..] Downloading update package..." -ForegroundColor Yellow

try {
    # Custom Download with Progress Bar
    $req = [System.Net.WebRequest]::Create($ZipUrl)
    if ($req -is [System.Net.HttpWebRequest]) {
        $req.UserAgent = "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36"
    }
    $req.Timeout = 300000 # 5 minutes
    $resp = $req.GetResponse()
    $totalBytes = $resp.ContentLength
    $respStream = $resp.GetResponseStream()
    
    $fs = [System.IO.File]::Create($TempZipPath)
    $buffer = New-Object byte[] 8192
    $read = 0
    $downloaded = 0
    $pct = 0
    
    while (($read = $respStream.Read($buffer, 0, $buffer.Length)) -gt 0) {
        $fs.Write($buffer, 0, $read)
        $downloaded += $read
        if ($totalBytes -gt 0) {
            $newPct = [math]::Round(($downloaded / $totalBytes) * 100)
            if ($newPct -ne $pct) {
                $pct = $newPct
                $rec = [math]::Round($downloaded / 1MB, 1)
                $tot = [math]::Round($totalBytes / 1MB, 1)
                Write-Progress -Activity "Downloading Update Package" -Status "$rec MB / $tot MB ($pct%)" -PercentComplete $pct
            }
        } else {
            $rec = [math]::Round($downloaded / 1MB, 1)
            Write-Progress -Activity "Downloading Update Package" -Status "$rec MB downloaded (Unknown total size)"
        }
    }
    
    $respStream.Close(); $fs.Close(); $resp.Close()
    Write-Progress -Activity "Downloading Update Package" -Completed
    Write-Host "  [OK] Download complete." -ForegroundColor Green
    
    # Extract Archive
    Write-Host "  [..] Extracting files..." -ForegroundColor Yellow
    if (Test-Path $TempExtractPath) {
        Remove-Item -LiteralPath $TempExtractPath -Recurse -Force -ErrorAction SilentlyContinue
    }
    New-Item -ItemType Directory -Path $TempExtractPath -Force | Out-Null
    
    Expand-Archive -Path $TempZipPath -DestinationPath $TempExtractPath -Force
    
    # Resolve real source path (handles GitHub directory wrapping dynamically)
    $items = Get-ChildItem -Path $TempExtractPath
    $realSourcePath = $TempExtractPath
    if ($items.Count -eq 1 -and $items[0].PSIsContainer) {
        $realSourcePath = $items[0].FullName
    }
    
    # Overwrite Files
    Write-Host "  [..] Installing files..." -ForegroundColor Yellow
    Get-ChildItem -Path $realSourcePath -Recurse | ForEach-Object {
        $dest = Join-Path $PSScriptRoot $_.FullName.Substring($realSourcePath.Length + 1)
        if ($_.PSIsContainer) {
            if (-not (Test-Path $dest)) {
                New-Item -ItemType Directory -Path $dest -Force | Out-Null
            }
        } else {
            # Skip version.dll if it exists in the zip, we write it manually
            if ($_.Name -ne "version.dll") {
                Copy-Item -LiteralPath $_.FullName -Destination $dest -Force
            }
        }
    }
    
    # Update local version.dll
    Set-Content -Path $LocalVersionFile -Value $RemoteVersion -Force
    
    Write-Host "  [OK] Update successfully installed to version $RemoteVersion." -ForegroundColor Green
    Write-Host "=============================================" -ForegroundColor Cyan
    Write-Host ""
    
} catch {
    Write-Progress -Activity "Downloading Update Package" -Completed -ErrorAction SilentlyContinue
    Write-Host "  [XX] Update failed: $($_.Exception.Message)" -ForegroundColor Red
    Write-Host "  Continuing startup with current files..." -ForegroundColor Yellow
    Write-Host ""
} finally {
    # Cleanup temp files
    if (Test-Path $TempZipPath) {
        Remove-Item $TempZipPath -Force -ErrorAction SilentlyContinue
    }
    if (Test-Path $TempExtractPath) {
        Remove-Item -LiteralPath $TempExtractPath -Recurse -Force -ErrorAction SilentlyContinue
    }
}
