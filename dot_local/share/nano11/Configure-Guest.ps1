# Run elevated inside Nano11 after installing the signed Intel and matching IDD drivers.
# This changes only Looking Glass configuration and an on-disconnect console task.
#Requires -RunAsAdministrator
$ErrorActionPreference = 'Stop'
$root = Join-Path $env:ProgramData 'Nano11'
New-Item -ItemType Directory -Path $root -Force | Out-Null
$stamp = Get-Date -Format 'yyyyMMdd-HHmmss'
$reg = 'HKLM:\SOFTWARE\LookingGlass\IDD'
if (-not (Test-Path $reg)) { throw 'Install the matching Looking Glass IDD first.' }
reg export 'HKLM\SOFTWARE\LookingGlass\IDD' "$root\idd-before-$stamp.reg" /y
Set-ItemProperty $reg DefaultRefresh '165.004'
New-ItemProperty $reg Modes -PropertyType MultiString -Value @('1920x1200@165.004*','1920x1200@120','1920x1200@60') -Force | Out-Null
Set-ItemProperty $reg ExclusiveMonitor 1
# Intel VF direct shared-heap writes produced corruption even with full copies.
Set-ItemProperty $reg ForceFullDirectCopy 0
Set-ItemProperty $reg ForceIndirectCopy 1

# RDP owns a separate display session. Restore this lab user's console only
# after RDP disconnects so IDD can present the same desktop without a resident helper.
$labUser = $env:USERNAME.Replace("'", "''")
$restore = @'
$ErrorActionPreference = 'Stop'
quser '__LAB_USER__' 2>$null | ForEach-Object {
    if ($_ -match '\s+(\d+)\s+Disc\s') {
        tscon $Matches[1] /dest:console
    }
}
'@.Replace('__LAB_USER__', $labUser)
$restore | Set-Content "$root\Restore-Console.ps1" -Encoding UTF8
$taskName = 'Nano11RestoreConsole'
if (Get-ScheduledTask -TaskName $taskName -ErrorAction SilentlyContinue) {
    Export-ScheduledTask -TaskName $taskName | Set-Content "$root\task-before-$stamp.xml"
}
schtasks /Create /F /TN $taskName /RU SYSTEM /SC ONEVENT /EC 'Microsoft-Windows-TerminalServices-LocalSessionManager/Operational' /MO '*[System[EventID=24]]' /TR "powershell.exe -NoProfile -NonInteractive -ExecutionPolicy Bypass -File $root\Restore-Console.ps1"
if ($LASTEXITCODE -ne 0) { throw 'Could not register console recovery task.' }
$settings = New-ScheduledTaskSettingsSet -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries -ExecutionTimeLimit (New-TimeSpan -Minutes 1) -MultipleInstances IgnoreNew
Set-ScheduledTask -TaskName $taskName -Settings $settings | Out-Null
pnputil /restart-device 'ROOT\DISPLAY\0000'
if ($LASTEXITCODE -notin 0,3010) { throw 'Could not restart Looking Glass IDD.' }
