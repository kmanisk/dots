# Read-only Windows 10 X-Lite hardware D3D11 and idle-footprint probe.
# Stores results on the separate writable WIN10RPT USB image.
$ErrorActionPreference = 'Continue'
$dir = Join-Path $env:ProgramData 'Win10Lab'
New-Item -ItemType Directory -Path $dir -Force | Out-Null
$log = Join-Path $dir 'gpu-probe.log'
function Note([string]$line) {
    $entry = "[$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')] $line"
    Write-Host $entry
    Add-Content -LiteralPath $log -Value $entry -Encoding UTF8
}
try {
    Note 'Windows 10 X-Lite Intel hardware Direct3D and idle footprint read-only probe'
    $os = Get-CimInstance Win32_OperatingSystem
    Note "OS: $($os.Caption), $($os.Version) build $($os.BuildNumber)"
    $totalMiB = [math]::Round($os.TotalVisibleMemorySize / 1024, 1)
    $usedMiB = [math]::Round(($os.TotalVisibleMemorySize - $os.FreePhysicalMemory) / 1024, 1)
    $procCount = @(Get-Process).Count
    Note "MEMORY: totalMiB=$totalMiB usedMiB=$usedMiB processes=$procCount"
    foreach ($d in @(Get-CimInstance Win32_VideoController)) {
        Note "Video: name=$($d.Name), driver=$($d.DriverVersion), device=$($d.PNPDeviceID)"
    }
    foreach ($d in @(Get-CimInstance Win32_PnPEntity | Where-Object {
        $_.PNPDeviceID -match 'VEN_8086&DEV_A78B' -or $_.Name -match 'Looking Glass'
    })) {
        Note "PnP: name=$($d.Name), code=$($d.ConfigManagerErrorCode), device=$($d.PNPDeviceID)"
    }
    foreach ($svc in @(Get-Service | Where-Object {
        $_.Name -match 'LGIdd|Looking|ivshmem'
    })) {
        Note "Service: $($svc.Name) status=$($svc.Status) start=$($svc.StartType)"
    }
    $reg='HKLM:\SOFTWARE\LookingGlass\IDD'
    if (Test-Path $reg) {
        $p=Get-ItemProperty $reg
        Note "IDD: DefaultRefresh=$($p.DefaultRefresh), ForceIndirectCopy=$($p.ForceIndirectCopy), ForceFullDirectCopy=$($p.ForceFullDirectCopy), ExclusiveMonitor=$($p.ExclusiveMonitor), Modes=$(($p.Modes) -join ',')"
    }
    $source = Join-Path $PSScriptRoot 'Probe-IntelD3D.cs'
    if (-not (Test-Path $source)) {
        Note "D3D11 FAILED: missing local C# source $source"
    } else {
        try {
            Add-Type -TypeDefinition ([IO.File]::ReadAllText($source)) -ErrorAction Stop
            $result = [XLiteGpuProbe]::Run()
            foreach ($line in ($result -split [char]10)) {
                Note "D3D11 $($line.Trim([char]13))"
            }
        } catch {
            Note "D3D11 FAILED: $($_.Exception.ToString())"
        }
    }
} catch {
    Note "GUEST PROBE FAILED: $($_.Exception.ToString())"
} finally {
    try {
        $report = [System.IO.DriveInfo]::GetDrives() |
            Where-Object { $_.IsReady -and $_.VolumeLabel -eq 'WIN10RPT' } |
            Select-Object -First 1
        if ($report) {
            Copy-Item -LiteralPath $log -Destination (Join-Path $report.RootDirectory.FullName 'gpu-probe.log') -Force
            Write-Host "Report saved to $($report.RootDirectory.FullName)"
        } else { Write-Host "WIN10RPT missing; report remains at $log" }
    } catch { Write-Host "Report copy failed: $_" }
}
