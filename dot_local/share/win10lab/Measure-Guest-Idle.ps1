# One-shot acceptance measurement, not a service or a repair/watchdog.
[CmdletBinding()]
param([ValidateRange(1800,3600)][int]$Seconds=1820,[ValidateSet('idle','selftest')][string]$Tag='idle')
$ErrorActionPreference='Stop'
Add-Type -TypeDefinition @'
using System;
using System.Runtime.InteropServices;
public static class Win10IdleProbe {
 [StructLayout(LayoutKind.Sequential)] public struct Input {public uint size; public uint tick;}
 [StructLayout(LayoutKind.Sequential)] public struct Power {public byte ac,battery,percent,status; public uint life,full;}
 [DllImport("user32.dll")] public static extern bool GetLastInputInfo(ref Input info);
 [DllImport("kernel32.dll")] public static extern uint GetTickCount();
 [DllImport("kernel32.dll")] public static extern bool GetSystemPowerStatus(out Power info);
 public static double IdleSeconds() {
  Input input=new Input(); input.size=(uint)Marshal.SizeOf(input);
  if(!GetLastInputInfo(ref input))throw new Exception("GetLastInputInfo failed");
  return unchecked(GetTickCount()-input.tick)/1000.0;
 }
 public static int ACLineStatus() {Power power; return GetSystemPowerStatus(out power)?power.ac:-1;}
}
'@
$dir=Join-Path $env:ProgramData 'Win10Lab';New-Item -ItemType Directory $dir -Force | Out-Null
function Write-JsonFile([string]$Path,[string]$Json) {
 $bytes=(New-Object Text.UTF8Encoding($false)).GetBytes($Json)
 $file=[IO.File]::Open($Path,[IO.FileMode]::Create,[IO.FileAccess]::Write,[IO.FileShare]::ReadWrite)
 try {$file.Write($bytes,0,$bytes.Length);$file.Flush($true)} finally {$file.Dispose()}
}
function Publish([string]$Name,$Data) {
 $json=$Data | ConvertTo-Json -Depth 8
 Write-JsonFile (Join-Path $dir $Name) $json
 $report=[IO.DriveInfo]::GetDrives() | Where-Object {$_.IsReady -and $_.VolumeLabel -eq 'WIN10RPT'} | Select-Object -First 1
 if($report){Write-JsonFile (Join-Path $report.RootDirectory.FullName $Name) $json}
 # No Storage CIM/Write-VolumeCache call: only flush the report's file handle.
}
$started=Get-Date
Publish ($Tag+'-start.json') ([ordered]@{pid=$PID;startUtc=$started.ToUniversalTime().ToString('o');seconds=$Seconds;acLineStatus=[Win10IdleProbe]::ACLineStatus();idleSeconds=[Win10IdleProbe]::IdleSeconds()})
$timer=[Diagnostics.Stopwatch]::StartNew()
Start-Sleep -Seconds $Seconds
$result=[ordered]@{pid=$PID;startUtc=$started.ToUniversalTime().ToString('o');endUtc=(Get-Date).ToUniversalTime().ToString('o');elapsedSeconds=$timer.Elapsed.TotalSeconds;idleSeconds=[Win10IdleProbe]::IdleSeconds();acLineStatus=[Win10IdleProbe]::ACLineStatus()}
$result['noInputFor30Minutes']=($result.idleSeconds -ge 1800)
$result['status']='input counter complete; optional diagnostics pending'
Publish ($Tag+'-result.json') $result
try {
 $result['display']=@(Get-CimInstance Win32_VideoController | Select-Object Name,DriverVersion,ConfigManagerErrorCode,CurrentHorizontalResolution,CurrentVerticalResolution,CurrentRefreshRate)
 $result['driverEvents']=@(Get-WinEvent -FilterHashtable @{LogName='System';ProviderName='Microsoft-Windows-DriverFrameworks-UserMode';StartTime=$started} -MaxEvents 100 -ErrorAction SilentlyContinue | Select-Object TimeCreated,Id,LevelDisplayName,Message)
 $result['status']='complete'
} catch {$result['diagnosticError']=$_.Exception.Message}
Publish ($Tag+'-result.json') $result
Write-Host 'Idle measurement complete. Physical input acceptance is a separate test.'
