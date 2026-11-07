# Looking Glass IDD configuration for the isolated Windows 10 X-Lite test guest.
# Run elevated after Intel VF driver Code 0 and the matching B7-829 IDD are installed.
$ErrorActionPreference = 'Stop'
$dir = Join-Path $env:ProgramData 'Win10Lab'
New-Item -Path $dir -ItemType Directory -Force | Out-Null
$log = Join-Path $dir 'idd-config.log'
function Note([string]$line) {
    $entry = "[$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')] $line"
    Write-Host $entry
    Add-Content -Path $log -Value $entry -Encoding UTF8
}
function Publish {
    try {
        $d = [System.IO.DriveInfo]::GetDrives() |
            Where-Object { $_.IsReady -and $_.VolumeLabel -eq 'WIN10RPT' } |
            Select-Object -First 1
        if ($d) {
            Copy-Item $log (Join-Path $d.RootDirectory.FullName 'idd-config.log') -Force
            Write-Host "Report saved to $($d.RootDirectory.FullName)"
        }
    } catch { Write-Host "Report copy failed: $_" }
}
try {
    $id = [Security.Principal.WindowsIdentity]::GetCurrent()
    $principal = New-Object Security.Principal.WindowsPrincipal $id
    if (-not $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
        $args = '-NoProfile -ExecutionPolicy Bypass -NoExit -File "' + $PSCommandPath + '"'
        Start-Process powershell.exe -Verb RunAs -ArgumentList $args
        exit
    }
    Note 'Starting LG B7-829 IDD configuration on Windows 10'
    $gfx = @(Get-CimInstance Win32_PnPEntity | Where-Object {
        $_.PNPDeviceID -match 'VEN_8086&DEV_A78B'
    })
    if (-not ($gfx | Where-Object { $_.ConfigManagerErrorCode -eq 0 })) {
        throw 'Intel VF is not ready (PNP Code 0 required). Refusing IDD configuration.'
    }
    $reg = 'HKLM:\SOFTWARE\LookingGlass\IDD'
    if (-not (Test-Path $reg)) { throw 'Looking Glass IDD not installed, registry key is missing.' }
    $backup = Join-Path $dir ("idd-before-" + (Get-Date -Format 'yyyyMMdd-HHmmss') + ".reg")
    & reg.exe export 'HKLM\SOFTWARE\LookingGlass\IDD' $backup /y | Out-Null
    if ($LASTEXITCODE -ne 0) { throw 'Cannot back up existing IDD registry settings.' }
    Note "Saved registry backup $backup"

    Set-ItemProperty -Path $reg -Name DefaultRefresh -Value '165.004'
    New-ItemProperty -Path $reg -Name Modes -PropertyType MultiString -Value @(
        '1920x1200@165.004*',
        '1920x1200@120',
        '1920x1200@60'
    ) -Force | Out-Null
    Set-ItemProperty -Path $reg -Name ExclusiveMonitor -Value 1
    Set-ItemProperty -Path $reg -Name ForceFullDirectCopy -Value 0
    Set-ItemProperty -Path $reg -Name ForceIndirectCopy -Value 1
    Note 'Applied 1920x1200 modes, 165.004 refresh, indirect-copy workaround'

    & pnputil.exe /restart-device 'ROOT\DISPLAY\0000' 2>&1 | ForEach-Object { Note "$_" }
    Note "pnputil restart IDD exit=$LASTEXITCODE"
    Note 'SUCCESS: configuration written; check IDD capture and Linux LGMP separately.'
} catch { Note "FAILED: $($_.Exception.Message)" }
finally { Publish }
