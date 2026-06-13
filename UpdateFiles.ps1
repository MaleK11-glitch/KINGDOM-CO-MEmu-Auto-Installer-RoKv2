$host.UI.RawUI.WindowTitle = "KINGDOM & CO - Checking MEmu..."

$memuUrl = "https://dl.memuplay.net/download/MEmu-setup-abroad-643b34e8.exe"
$installerPath = Join-Path $env:TEMP "MEmu_Installer.exe"

function Find-MEmu {
    $drives = Get-PSDrive -PSProvider FileSystem | Where-Object { (Test-Path ($_.Root + "Program Files")) -or (Test-Path ($_.Root + "Program Files (x86)")) }
    foreach ($drive in $drives) {
        $root = $drive.Root
        $paths = @(
            "$root\Program Files\Microvirt\MEmu\MEmu.exe",
            "$root\Program Files (x86)\Microvirt\MEmu\MEmu.exe",
            "$root\Program Files\Microvirt\MEmuHyperv\MEmuHyperv.exe",
            "$root\Program Files (x86)\Microvirt\MEmuHyperv\MEmuHyperv.exe"
        )
        foreach ($p in $paths) {
            if (Test-Path $p) {
                return (Get-Item $p).Directory.FullName
            }
        }
    }
    try {
        $key = Get-ItemProperty "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\*" -ErrorAction SilentlyContinue | Where-Object { $_.DisplayName -match "MEmu|Microvirt" } | Select-Object -First 1
        if ($key -and $key.InstallLocation -and (Test-Path $key.InstallLocation)) {
            return $key.InstallLocation
        }
        $key = Get-ItemProperty "HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall\*" -ErrorAction SilentlyContinue | Where-Object { $_.DisplayName -match "MEmu|Microvirt" } | Select-Object -First 1
        if ($key -and $key.InstallLocation -and (Test-Path $key.InstallLocation)) {
            return $key.InstallLocation
        }
    } catch {}
    return $null
}

$memuPath = Find-MEmu

if ($memuPath) {
    Write-Host "  [OK] MEmu found at: $memuPath" -ForegroundColor Green
    $env:MEMU_PATH = $memuPath
    $cMEmu = "C:\Program Files\Microvirt\MEmu"
    if ($memuPath -ne $cMEmu) {
        $cParent = "C:\Program Files\Microvirt"
        if (Test-Path $cMEmu) {
            Remove-Item -LiteralPath $cMEmu -Recurse -Force -ErrorAction SilentlyContinue
        }
        if (-not (Test-Path $cParent)) {
            New-Item -ItemType Directory -Path $cParent -Force -ErrorAction SilentlyContinue | Out-Null
        }
        if (Test-Path $cParent) {
            cmd /c mklink /D "$cMEmu" "$memuPath" | Out-Null
            if (Test-Path "$cMEmu\memuc.exe") {
                Write-Host "  [OK] Created symlink: C: -> $memuPath" -ForegroundColor Cyan
            }
        }
    }
} else {
    Write-Host ""
    Write-Host "  [..] MEmu not found." -ForegroundColor Yellow
    Write-Host ""
    Write-Host "  Available drives:" -ForegroundColor Cyan
    $drives = Get-PSDrive -PSProvider FileSystem | Where-Object { $_.Root -match '^[A-Z]:\\$' } | ForEach-Object { $_.Root[0] }
    $driveList = @()
    $i = 1
    foreach ($d in $drives) {
        $label = "  $i. Drive $d"
        try {
            $driveInfo = Get-PSDrive -Name $d -ErrorAction SilentlyContinue
            if ($driveInfo) {
                $freeBytes = $driveInfo.Free
                $totalBytes = (Get-PSDrive -Name $d).Used + $freeBytes
                $freeGB = [math]::Round($freeBytes / 1GB, 1)
                $totalGB = [math]::Round($totalBytes / 1GB, 1)
                $label += " ($freeGB GB free / $totalGB GB total)"
            }
        } catch {}
        Write-Host $label -ForegroundColor White
        $driveList += $d
        $i++
    }
    Write-Host ""
    $choice = Read-Host "  Choose drive number or letter (e.g. 1 or C)"
    $selectedDrive = $null
    $parsed = 0
    if ([int]::TryParse($choice, [ref]$parsed)) {
        if ($parsed -ge 1 -and $parsed -le $driveList.Count) {
            $selectedDrive = $driveList[$parsed - 1]
        }
    } else {
        $upper = $choice.ToUpper().Trim()
        if ($upper -match '^[A-Z]$' -and $driveList -contains $upper) {
            $selectedDrive = $upper
        }
    }
    if (-not $selectedDrive) {
        Write-Host "  [..] Invalid choice. Using C: drive." -ForegroundColor Yellow
        $selectedDrive = "C"
    }
    $installPath = "${selectedDrive}:\Program Files\Microvirt\MEmu"
    Write-Host "  [..] Downloading MEmu to $selectedDrive drive..." -ForegroundColor Yellow
    try {
        Write-Host "  Downloading... (this may take a while)" -ForegroundColor Gray
        $req = [System.Net.HttpWebRequest]::Create($memuUrl)
        $req.UserAgent = "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36"
        $req.Timeout = 300000
        $resp = $req.GetResponse()
        $totalBytes = $resp.ContentLength
        $respStream = $resp.GetResponseStream()
        $fs = [System.IO.File]::Create($installerPath)
        $buffer = New-Object byte[] 8192
        $read = 0
        $downloaded = 0
        $pct = 0
        while (($read = $respStream.Read($buffer, 0, $buffer.Length)) -gt 0) {
            $fs.Write($buffer, 0, $read)
            $downloaded += $read
            $newPct = [math]::Round(($downloaded / $totalBytes) * 100)
            if ($newPct -ne $pct) {
                $pct = $newPct
                $rec = [math]::Round($downloaded / 1MB, 1)
                $tot = [math]::Round($totalBytes / 1MB, 1)
                Write-Progress -Activity "Downloading MEmu" -Status "$rec MB / $tot MB ($pct%)" -PercentComplete $pct
            }
        }
        $respStream.Close(); $fs.Close(); $resp.Close()
        Write-Progress -Activity "Downloading MEmu" -Completed
        Write-Host "  [OK] Download complete." -ForegroundColor Green
        Write-Host "  [..] Installing MEmu to $installPath ..." -ForegroundColor Yellow
        Write-Host "  Installing... Close the installer when done." -ForegroundColor Yellow
        try {
            $proc = Start-Process -FilePath $installerPath -ArgumentList "/D=$installPath" -PassThru
            $exited = $proc.WaitForExit(600000)
            if (-not $exited) {
                Write-Host "`n  [..] Installer timed out (10 min). Killing..." -ForegroundColor Red
                $proc.Kill()
            } else {
                Write-Host "done." -ForegroundColor Green
            }
        } catch {
            Write-Host "  done." -ForegroundColor Green
        }
        $memuPath = Find-MEmu
        if ($memuPath) {
            Write-Host "  [OK] MEmu found at: $memuPath" -ForegroundColor Green
            $env:MEMU_PATH = $memuPath
            $cMEmu = "C:\Program Files\Microvirt\MEmu"
            if ($memuPath -ne $cMEmu -and -not (Test-Path $cMEmu)) {
                $cParent = "C:\Program Files\Microvirt"
                if (-not (Test-Path $cParent)) {
                    New-Item -ItemType Directory -Path $cParent -Force -ErrorAction SilentlyContinue | Out-Null
                }
                if (Test-Path $cParent) {
                    cmd /c mklink /D "$cMEmu" "$memuPath" | Out-Null
                    if (Test-Path $cMEmu) {
                        Write-Host "  [OK] Created symlink: C: -> $memuPath" -ForegroundColor Cyan
                    }
                }
            }
        } else {
            Write-Host "  [XX] MEmu not found after installation." -ForegroundColor Red
        }
    } catch {
        Write-Host "  [XX] Failed: $($_.Exception.Message)" -ForegroundColor Red
    }
    try { Remove-Item $installerPath -Force -ErrorAction SilentlyContinue } catch {}
}
