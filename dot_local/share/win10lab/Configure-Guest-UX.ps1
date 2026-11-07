# Windows 10 X-Lite experimental guest only. Do not apply to Nano11.
# Use from the offline script media; writes diagnostics/backups to WIN10RPT (F:).
[CmdletBinding()]
param()
$ErrorActionPreference = 'Stop'
$ProgressPreference = 'SilentlyContinue'
$report = 'F:\win10-guest-ux-fix.log'

function Log([string]$message) {
  $line = ('{0} {1}' -f (Get-Date -Format 'yyyy-MM-ddTHH:mm:ss'), $message)
  Add-Content -LiteralPath $report -Value $line -Encoding UTF8
  Write-Output $line
}
try {
  Set-Content -LiteralPath $report -Value 'WIN10LAB_GUEST_UX_FIX' -Encoding UTF8
  $os = Get-CimInstance Win32_OperatingSystem
  if ($os.BuildNumber -ne '19045') { throw "Expected Windows 10 build 19045; found $($os.BuildNumber)" }
  $desktop = 'HKCU:\Control Panel\Desktop'
  $advanced = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced'
  $before = Get-ItemProperty -Path $desktop
  $beforeClock = Get-ItemProperty -Path $advanced -ErrorAction Stop
  Log ("BEFORE DPI: Win8DpiScaling={0} LogPixels={1} DesktopDPIOverride={2}" -f $before.Win8DpiScaling,$before.LogPixels,$before.DesktopDPIOverride)
  Log ("BEFORE CLOCK: ShowSecondsInSystemClock={0}" -f $beforeClock.ShowSecondsInSystemClock)
  # Export the actual current user's registry keys for full rollback, not system-wide changes.
  & reg.exe export 'HKCU\Control Panel\Desktop' 'F:\win10lab-desktop-reg-before.reg' /y | Out-Null
  if ($LASTEXITCODE -ne 0) {throw 'reg export Desktop failed'}
  & reg.exe export 'HKCU\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced' 'F:\win10lab-clock-reg-before.reg' /y | Out-Null
  if ($LASTEXITCODE -ne 0) {throw 'reg export clock failed'}
  Log 'REGISTRY_BACKUP=SUCCESS'

  # Windows 10 taskbar seconds, not the time-zone or short-time regional format.
  New-ItemProperty -Path $advanced -Name ShowSecondsInSystemClock -PropertyType DWord -Value 0 -Force | Out-Null

  # Remove nonstandard global custom scale (130 DPI ~= 135%) and use
  # the OS built-in per-display steps. +1 means one step above display default.
  New-ItemProperty -Path $desktop -Name Win8DpiScaling -PropertyType DWord -Value 0 -Force | Out-Null
  New-ItemProperty -Path $desktop -Name DesktopDPIOverride -PropertyType DWord -Value 1 -Force | Out-Null
  if (Get-ItemProperty -Path $desktop -Name LogPixels -ErrorAction SilentlyContinue) {
    Remove-ItemProperty -Path $desktop -Name LogPixels -ErrorAction Stop
  }

  $after = Get-ItemProperty -Path $desktop
  $clock = (Get-ItemProperty -Path $advanced).ShowSecondsInSystemClock
  Log ("AFTER DPI: Win8DpiScaling={0} LogPixels={1} DesktopDPIOverride={2}" -f $after.Win8DpiScaling,$after.LogPixels,$after.DesktopDPIOverride)
  Log ("AFTER CLOCK: ShowSecondsInSystemClock={0}" -f $clock)
  if ($clock -ne 0 -or $after.Win8DpiScaling -ne 0) {throw 'Failed registry verification'}
  Log 'APPLIED: effective DPI/text size and tray clock refresh after Windows sign-out/restart'

  $nics = @(Get-CimInstance Win32_NetworkAdapter | Where-Object { $_.PhysicalAdapter -eq $true })
  foreach($n in $nics) {
    Log ("NETWORK: {0} NetEnabled={1} PNP={2}" -f $n.Name,$n.NetEnabled,$n.PNPDeviceID)
  }
  & ipconfig.exe /all | ForEach-Object {Log $_}
  Log 'SUCCESS: guest registry changes applied. Intel VF, IDD and services not modified.'
} catch {
  try {Log ("FAILED: " + $_.Exception.Message)} catch {}
  throw
}
