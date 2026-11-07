# Inspect by default. -Apply enables small dumps and bugcheck logging only.
[CmdletBinding()]
param([switch]$Apply)
$ErrorActionPreference='Stop'
$key='HKLM:\SYSTEM\CurrentControlSet\Control\CrashControl'
$before=Get-ItemProperty -LiteralPath $key
$before | Select-Object CrashDumpEnabled,LogEvent,AutoReboot,MinidumpDir | Format-List
if(-not $Apply){Write-Host 'Inspection only.';return}
$identity=[Security.Principal.WindowsIdentity]::GetCurrent()
if(-not (New-Object Security.Principal.WindowsPrincipal($identity)).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)){throw 'Run elevated.'}
$os=Get-CimInstance Win32_OperatingSystem
if($os.ProductType -ne 1 -or $os.BuildNumber -ne '19045'){throw 'This helper is scoped to the Windows 10 lab.'}
$page=Get-CimInstance Win32_PageFileUsage | Where-Object {$_.Name -like ($env:SystemDrive+'\*') -and $_.AllocatedBaseSize -ge 2}
if(-not $page){throw 'No boot-volume paging file of at least 2 MiB; no settings changed.'}
$dir=Join-Path $env:ProgramData 'Win10Lab'
New-Item -ItemType Directory $dir -Force | Out-Null
$stamp=Get-Date -Format 'yyyyMMdd-HHmmss-fff'
$backup=Join-Path $dir ('crash-control-before-'+$stamp+'.reg')
& reg.exe export 'HKLM\SYSTEM\CurrentControlSet\Control\CrashControl' $backup /y | Out-Null
if($LASTEXITCODE -ne 0){throw 'Registry backup failed.'}
$values=@{}
foreach($name in @('CrashDumpEnabled','LogEvent')){
    $value=$before.PSObject.Properties[$name]
    $values[$name]=if($null -eq $value){$null}else{[int]$value.Value}
}
$saved=Join-Path $dir ('crash-values-before-'+$stamp+'.json')
$values | ConvertTo-Json | Set-Content -LiteralPath $saved -Encoding UTF8
$restore=Join-Path $dir ('restore-crash-evidence-'+$stamp+'.ps1')
@'
$ErrorActionPreference='Stop'
$key='HKLM:\SYSTEM\CurrentControlSet\Control\CrashControl'
$values=Get-Content -Raw -LiteralPath (Join-Path $PSScriptRoot '__VALUES__') | ConvertFrom-Json
foreach($name in @('CrashDumpEnabled','LogEvent')){
    $value=$values.PSObject.Properties[$name].Value
    if($null -eq $value){Remove-ItemProperty -LiteralPath $key -Name $name -ErrorAction SilentlyContinue}
    else{New-ItemProperty -LiteralPath $key -Name $name -Value ([int]$value) -PropertyType DWord -Force | Out-Null}
}
Get-ItemProperty -LiteralPath $key | Select-Object CrashDumpEnabled,LogEvent,AutoReboot | Format-List
'@.Replace('__VALUES__',[IO.Path]::GetFileName($saved)) | Set-Content -LiteralPath $restore -Encoding UTF8
New-ItemProperty -LiteralPath $key -Name CrashDumpEnabled -Value 3 -PropertyType DWord -Force | Out-Null
New-ItemProperty -LiteralPath $key -Name LogEvent -Value 1 -PropertyType DWord -Force | Out-Null
$after=Get-ItemProperty -LiteralPath $key
if($after.CrashDumpEnabled -ne 3 -or $after.LogEvent -ne 1 -or $after.AutoReboot -ne $before.AutoReboot){throw 'Crash evidence verification failed.'}
$after | Select-Object CrashDumpEnabled,LogEvent,AutoReboot,MinidumpDir | Format-List
Write-Host "Verified registry values. Backup: $backup; rollback: $restore"
Write-Host 'Paging file and automatic restart unchanged. Dump production is untested; use the next clean guest boot.'
