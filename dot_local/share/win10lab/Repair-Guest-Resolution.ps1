# Remove an unintended dynamic client mode; preserve the configured IDD modes.
$ErrorActionPreference='Stop'
$reg='HKLM:\SOFTWARE\LookingGlass\IDD'
$settings=Get-ItemProperty $reg
if($settings.ExtraMode -notlike '1919x1200@*') {Write-Host 'No known stale 1919x1200 mode; nothing changed.';return}
$gpu=Get-CimInstance Win32_VideoController | Where-Object {$_.PNPDeviceID -like 'PCI\VEN_8086*'}
if(-not ($gpu | Where-Object {$_.ConfigManagerErrorCode -eq 0})){throw 'Intel GPU is not healthy; refusing display reconfiguration'}
$dir=Join-Path $env:ProgramData 'Win10Lab';New-Item -ItemType Directory $dir -Force | Out-Null
$backup=Join-Path $dir ('idd-resolution-before-'+(Get-Date -Format 'yyyyMMdd-HHmmss')+'.reg')
& reg.exe export 'HKLM\SOFTWARE\LookingGlass\IDD' $backup /y
if($LASTEXITCODE -ne 0){throw 'Cannot back up IDD registry'}
Remove-ItemProperty $reg -Name ExtraMode
# Reenumerate only the IDD device; no Windows reboot or Intel driver restart.
& pnputil.exe /restart-device 'ROOT\DISPLAY\0000'
if($LASTEXITCODE -ne 0){throw "IDD restart failed. Registry rollback: reg.exe import $backup"}
Start-Sleep -Seconds 3
$devices=@(Get-CimInstance Win32_VideoController)
$report=@("UTC=$((Get-Date).ToUniversalTime().ToString('o'))","Backup=$backup",($devices | Format-List Name,ConfigManagerErrorCode,CurrentHorizontalResolution,CurrentVerticalResolution,CurrentRefreshRate | Out-String))
$file=Join-Path $dir 'resolution-repair.txt';$report | Set-Content $file
$drive=[IO.DriveInfo]::GetDrives() | Where-Object {$_.IsReady -and $_.VolumeLabel -eq 'WIN10RPT'} | Select-Object -First 1
if($drive){Copy-Item $file (Join-Path $drive.RootDirectory.FullName 'resolution-repair.txt') -Force;Copy-Item $backup $drive.RootDirectory.FullName -Force}
$idd=$devices | Where-Object {$_.Name -like 'Looking Glass*'}
if($idd.CurrentHorizontalResolution -ne 1920 -or $idd.CurrentVerticalResolution -ne 1200){throw '1920x1200 is not active yet; inspect resolution-repair.txt'}
Write-Host 'VERIFIED: IDD active mode is 1920x1200'
