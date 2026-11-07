# Driver-only Intel graphics install for the isolated Windows 10 X-Lite test guest.
# Signature enforcement stays enabled; optional Intel applications are not installed.
$ErrorActionPreference = 'Stop'
$dir = Join-Path $env:ProgramData 'Win10Lab'
New-Item -ItemType Directory -Path $dir -Force | Out-Null
$log = Join-Path $dir 'intel-install.log'

function Note([string]$message) {
    $entry = "[$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')] $message"
    Write-Host $entry
    Add-Content -Path $log -Value $entry -Encoding UTF8
}
function Publish {
    try {
        $d = [System.IO.DriveInfo]::GetDrives() |
            Where-Object { $_.IsReady -and $_.VolumeLabel -eq 'WIN10RPT' } |
            Select-Object -First 1
        if ($d) {
            Copy-Item $log (Join-Path $d.RootDirectory.FullName 'intel-install.log') -Force
            Write-Host "Report saved to $($d.RootDirectory.FullName)"
        } else { Write-Host 'No WIN10RPT drive; report remains in C:\ProgramData\Win10Lab.' }
    } catch { Write-Host "Report copy error: $_" }
}
try {
    $identity = [Security.Principal.WindowsIdentity]::GetCurrent()
    $principal = New-Object Security.Principal.WindowsPrincipal $identity
    if (-not $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
        Write-Host 'Requesting UAC elevation for signed Intel graphics driver install.'
        $args = '-NoProfile -ExecutionPolicy Bypass -NoExit -File "' + $PSCommandPath + '"'
        Start-Process powershell.exe -Verb RunAs -ArgumentList $args
        exit
    }
    Note 'Starting signed Intel graphics driver-only install'
    $inf = Join-Path $PSScriptRoot 'Graphics\iigd_dch.inf'
    $cat = Join-Path $PSScriptRoot 'Graphics\igdlh.cat'
    if (-not (Test-Path $inf) -or -not (Test-Path $cat)) {
        throw 'Intel graphics INF/catalog missing on installation USB'
    }
    $contents = Get-Content -LiteralPath $inf -Encoding Unicode -Raw
    if (-not $contents.Contains('PCI\VEN_8086&DEV_A78B')) {
        throw 'Driver INF does not list Intel 8086:A78B'
    }
    Note 'INF lists Windows 10 and PCI VEN_8086 DEV_A78B'
    $before = @(Get-CimInstance Win32_PnPEntity | Where-Object {
        $_.PNPDeviceID -match 'VEN_8086&DEV_A78B'
    })
    if ($before.Count -eq 0) {
        throw 'Intel 8086:A78B VF is not visible in Windows; check QEMU first'
    }
    foreach ($d in $before) {
        Note "Before: $($d.Name); Code=$($d.ConfigManagerErrorCode); ID=$($d.PNPDeviceID)"
    }
    $lines = @(& "$env:SystemRoot\System32\pnputil.exe" /add-driver $inf /install 2>&1)
    $resultCode = $LASTEXITCODE
    foreach ($line in $lines) { Note "$line" }
    Note "pnputil exit=$resultCode"
    if ($resultCode -notin @(0,3010)) { throw "pnputil failed with code $resultCode" }
    Start-Sleep -Seconds 8
    $after = @(Get-CimInstance Win32_PnPEntity | Where-Object {
        $_.PNPDeviceID -match 'VEN_8086&DEV_A78B'
    })
    foreach ($d in $after) {
        Note "After: $($d.Name); Code=$($d.ConfigManagerErrorCode); ID=$($d.PNPDeviceID)"
    }
    foreach ($d in @(Get-CimInstance Win32_VideoController)) {
        Note "Video: $($d.Name), driver $($d.DriverVersion), ID=$($d.PNPDeviceID)"
    }
    if ($after | Where-Object { $_.ConfigManagerErrorCode -eq 0 }) {
        Note 'SUCCESS: Intel VF reports device Code 0'
    } else {
        Note 'Driver staged, but Code 0 not confirmed. Reboot may be needed.'
    }
} catch {
    Note "FAILED: $($_.Exception.Message)"
} finally {
    Publish
    Write-Host 'Review report before installing the Looking Glass IDD.'
}
