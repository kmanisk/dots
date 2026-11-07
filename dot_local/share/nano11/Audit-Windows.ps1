# Nano11 Windows optimization inventory. Read-only; Windows PowerShell 5.1 compatible.
# Captures baseline and installed packages without mutating services, drivers, registry, or apps.
[CmdletBinding()]
param(
  [string]$OutputDir = '\\tsclient\shared\nano11-tuning\reports'
)
$ErrorActionPreference = 'Continue'
$ProgressPreference = 'SilentlyContinue'
New-Item -Path $OutputDir -ItemType Directory -Force | Out-Null

function Try-Capture([scriptblock]$Action) {
    try { @(& $Action) } catch { @() }
}
$os = Get-CimInstance Win32_OperatingSystem
$machine = Get-CimInstance Win32_ComputerSystem
$processes = @(Get-Process | Select-Object ProcessName,Id,CPU,WorkingSet64,PrivateMemorySize64,Handles,StartTime)
$services = @(Get-CimInstance Win32_Service |
  Select-Object Name,DisplayName,State,StartMode,ProcessId,PathName)
$apps = Try-Capture { Get-AppxPackage -AllUsers | Select-Object Name,PackageFullName,NonRemovable,InstallLocation,SignatureKind }
if (!$apps -or $apps.Count -eq 0) {
    $apps = Try-Capture { Get-AppxPackage | Select-Object Name,PackageFullName,NonRemovable,InstallLocation,SignatureKind }
}
$tasks = Try-Capture { Get-ScheduledTask | Where-Object { $_.State -ne 'Disabled' } |
  Select-Object TaskName,TaskPath,State }
$startup = Try-Capture { Get-CimInstance Win32_StartupCommand |
  Select-Object Name,Command,Location,User }
$display = Try-Capture { Get-CimInstance Win32_VideoController |
  Select-Object Name,DriverVersion,PNPDeviceID,Status }
$drivers = Try-Capture { Get-PnpDevice -Class Display |
  Select-Object FriendlyName,Status,InstanceId }
$agent = Try-Capture { Get-Service 'LGIddHelper','TermService','UmRdpService','WinDefend','wuauserv','WSearch','DiagTrack','SysMain' |
  Select-Object Name,Status,StartType }
$idd = $null
if (Test-Path 'HKLM:\SOFTWARE\LookingGlass\IDD') {
  $idd = Get-ItemProperty 'HKLM:\SOFTWARE\LookingGlass\IDD' |
    Select-Object DefaultRefresh,Modes,ExclusiveMonitor,ForceIndirectCopy,ForceFullDirectCopy
}
$installed = Try-Capture {
  $paths = @(
    'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\*',
    'HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall\*'
  )
  Get-ItemProperty $paths |
    Where-Object { $_.DisplayName } |
    Select-Object DisplayName,DisplayVersion,Publisher,UninstallString
}
$report = [ordered]@{
    generatedAt = (Get-Date).ToString('o')
    osCaption = $os.Caption
    osVersion = $os.Version
    osBuild = $os.BuildNumber
    bootTime = $os.LastBootUpTime
    memoryTotalGB = [math]::Round($machine.TotalPhysicalMemory/1GB,2)
    memoryFreeGB = [math]::Round(($os.FreePhysicalMemory*1KB)/1GB,2)
    visibleProcessCount = $processes.Count
    processWorkingSetGB = [math]::Round((($processes | Measure-Object WorkingSet64 -Sum).Sum/1GB),2)
    processes = $processes
    services = $services
    apps = $apps
    tasks = $tasks
    startup = $startup
    display = $display
    drivers = $drivers
    protectedServices = $agent
    idd = $idd
    installedPrograms = $installed
}
$stamp = Get-Date -Format 'yyyyMMdd-HHmmss'
$json = Join-Path $OutputDir "before-$stamp.json"
$report | ConvertTo-Json -Depth 8 | Set-Content -LiteralPath $json -Encoding UTF8
$summary = Join-Path $OutputDir 'latest-summary.txt'
@(
"Generated: $($report.generatedAt)"
"OS: $($report.osCaption) $($report.osVersion), build $($report.osBuild)"
"Physical RAM: $($report.memoryTotalGB) GiB; available: $($report.memoryFreeGB) GiB"
"Processes: $($report.visibleProcessCount); process working sets: $($report.processWorkingSetGB) GiB"
"Display: $(($display | ForEach-Object { $_.Name }) -join '; ')"
"Packages: $($apps.Count), services: $($services.Count), enabled/active tasks: $($tasks.Count)"
"Uninstall entries: $($installed.Count)"
"Report JSON: $json"
) | Set-Content -LiteralPath $summary -Encoding UTF8
Write-Output "GPUVM_AUDIT_COMPLETE=$json"
Get-Content -LiteralPath $summary
