# One-shot read-only collection. Run BEFORE applying power or device changes.
[CmdletBinding()]
param([ValidateSet('before','after','failure','idle30')][string]$Phase='before')
$ErrorActionPreference='Stop'
$dir=Join-Path $env:LOCALAPPDATA ('win10lab\evidence-'+(Get-Date -Format 'yyyyMMdd-HHmmss-fff')+'-'+$Phase)
New-Item -ItemType Directory -Path $dir -Force | Out-Null
function Capture([string]$Name,[scriptblock]$Body) {
    try { & $Body | Out-String -Width 300 | Set-Content -LiteralPath (Join-Path $dir ($Name+'.txt')) -Encoding UTF8 }
    catch { $_ | Out-String | Set-Content -LiteralPath (Join-Path $dir ($Name+'-ERROR.txt')) }
}
Capture time {Get-Date -Format o; Get-TimeZone; query.exe session}
Capture os {Get-CimInstance Win32_OperatingSystem | Format-List Caption,Version,BuildNumber,LastBootUpTime,TotalVisibleMemorySize,FreePhysicalMemory}
Capture power {powercfg.exe /getactivescheme; powercfg.exe /a; powercfg.exe /query SCHEME_CURRENT SUB_VIDEO VIDEOIDLE; powercfg.exe /query SCHEME_CURRENT SUB_SLEEP STANDBYIDLE; powercfg.exe /query SCHEME_CURRENT SUB_SLEEP HIBERNATEIDLE}
Capture gpu {Get-CimInstance Win32_VideoController | Format-List *; Get-PnpDevice -Class Display | Format-List *}
Capture idd {Get-ItemProperty 'HKLM:\SOFTWARE\LookingGlass\IDD' | Format-List *}
Capture services {Get-CimInstance Win32_Service | Where-Object {$_.Name -match 'Wudf|LGIdd|Looking|AppX|StateRepository|DcomLaunch|RpcSs|Power|EventLog|PlugPlay'} | Format-List Name,State,StartMode,PathName,ExitCode}
Capture appxHealth {
    Get-AppxPackage -AllUsers | Where-Object {$_.Name -match 'WindowsStore|DesktopAppInstaller|VCLibs|UI.Xaml'} | Format-List Name,Version,Status,InstallLocation,PackageUserInformation
    Get-AppxProvisionedPackage -Online | Where-Object {$_.DisplayName -match 'WindowsStore|DesktopAppInstaller'} | Format-List DisplayName,Version,PackageName
    Get-ChildItem (Join-Path $env:ProgramFiles 'WindowsApps') -Directory -Filter 'Microsoft.WindowsStore_*' -ErrorAction Stop | Select-Object Name,FullName
}
Capture wudf {Get-Process WUDFHost -ErrorAction SilentlyContinue | ForEach-Object {"PID=$($_.Id) CPU=$($_.CPU) WS=$($_.WorkingSet64)"; $_.Modules | Select-Object ModuleName,FileName | Format-Table -AutoSize}}
Capture cpu {
    $before=@{}; Get-Process | ForEach-Object {$before[$_.Id]=$_.CPU}
    $timer=[Diagnostics.Stopwatch]::StartNew(); Start-Sleep -Seconds 8; $elapsed=$timer.Elapsed.TotalSeconds
    Get-Process | Where-Object {$before.ContainsKey($_.Id)} | ForEach-Object {
        [pscustomobject]@{PID=$_.Id;Name=$_.ProcessName;OneCorePercent=[math]::Round(100*($_.CPU-$before[$_.Id])/$elapsed,2);WorkingSetMiB=[math]::Round($_.WorkingSet64/1MB,1)}
    } | Sort-Object OneCorePercent -Descending | Select-Object -First 20 | Format-Table -AutoSize
}
# System interrupts are not a normal process; collect their separate counters.
Capture interrupts {Get-CimInstance Win32_PerfFormattedData_PerfOS_Processor | Select-Object Name,PercentProcessorTime,PercentPrivilegedTime,PercentInterruptTime,PercentDPCTime,InterruptsPersec | Format-Table -AutoSize}
$since=(Get-Date).AddHours(-4)
foreach ($log in @('System','Application','Microsoft-Windows-DriverFrameworks-UserMode/Operational','Microsoft-Windows-AppXDeploymentServer/Operational')) {
    $eventLog=$log
    Capture ('events-'+($log -replace '[^A-Za-z0-9-]','_')) {
        Get-WinEvent -FilterHashtable @{LogName=$eventLog;StartTime=$since} -MaxEvents 500 -ErrorAction Stop |
            Select-Object TimeCreated,Id,LevelDisplayName,ProviderName,Message | Format-List
    }
}
# Export existing logs only; never enable channels or clear any event log.
foreach ($log in @('System','Application')) {
    Capture ('export-'+$log) {
        & wevtutil.exe epl $log (Join-Path $dir ($log+'.evtx')) '/ow:false'
        if ($LASTEXITCODE -ne 0) {throw "wevtutil exit=$LASTEXITCODE"}
    }
}
Capture crashReports {Get-ChildItem "$env:ProgramData\Microsoft\Windows\WER\ReportArchive" -Filter Report.wer -Recurse -ErrorAction Stop | Where-Object {$_.LastWriteTime -gt $since} | Select-Object -First 20 | ForEach-Object {Get-Content -LiteralPath $_.FullName}}
Capture crashConfiguration {
    Get-ItemProperty 'HKLM:\SYSTEM\CurrentControlSet\Control\CrashControl' | Format-List *
    Get-CimInstance Win32_PageFileUsage | Format-List Name,AllocatedBaseSize,CurrentUsage
    Get-ChildItem "$env:SystemRoot\Minidump","$env:SystemRoot\LiveKernelReports" -Recurse -ErrorAction SilentlyContinue | Select-Object FullName,Length,LastWriteTime | Format-Table -AutoSize
}
Capture umdfEventXml {
    Get-WinEvent -FilterHashtable @{LogName='System';Id=10110,10111;StartTime=$since} -MaxEvents 100 -ErrorAction Stop | ForEach-Object {$_.ToXml()}
}
Capture lookingGlassLogs {
    $logs=Join-Path $env:ProgramData 'Looking Glass (IDD)'
    Get-ChildItem -LiteralPath $logs -File -ErrorAction Stop | Where-Object {$_.Name -like 'looking-glass-*.txt*'} | ForEach-Object {
        "FILE=$($_.FullName) MODIFIED=$($_.LastWriteTime.ToUniversalTime().ToString('o'))"
        Get-Content -LiteralPath $_.FullName -Tail 1500
    }
}
Capture userDataModule {
    Get-ChildItem 'HKLM:\SYSTEM\CurrentControlSet\Services\UserDataSvc*' -ErrorAction Stop | ForEach-Object {
        $parameters=Join-Path $_.PSPath 'Parameters'
        $dll=(Get-ItemProperty $parameters -ErrorAction SilentlyContinue).ServiceDll
        [pscustomobject]@{Service=$_.PSChildName;ServiceDll=$dll;FilePresent=if($dll){Test-Path -LiteralPath ([Environment]::ExpandEnvironmentVariables($dll))}else{$null}}
    } | Format-Table -AutoSize
}
Write-Host "Evidence saved: $dir"
Write-Host 'No settings changed. Missing counters/channels are recorded as ERROR files.'
