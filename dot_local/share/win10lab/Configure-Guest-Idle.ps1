# Inspect first. -Apply changes only monitor timeouts; -IncludeStandby is a separate test.
[CmdletBinding()]
param([switch]$Apply, [switch]$IncludeStandby)
$ErrorActionPreference = 'Stop'
if ($IncludeStandby -and -not $Apply) { throw '-IncludeStandby requires -Apply' }
$directory = Join-Path $env:LOCALAPPDATA 'win10lab'
New-Item -ItemType Directory -Path $directory -Force | Out-Null
$stamp = Get-Date -Format 'yyyyMMdd-HHmmss-fff'
$evidence = Join-Path $directory "idle-policy-$stamp.txt"
function Read-PowerCfg([string[]]$Arguments) {
    $text = (& powercfg.exe @Arguments 2>&1 | Out-String)
    if ($LASTEXITCODE -ne 0) { throw "powercfg $($Arguments -join ' '): $text" }
    return $text
}
function Snapshot([string]$Guid) {
    @(
        "UTC: $((Get-Date).ToUniversalTime().ToString('o'))"
        (Read-PowerCfg @('/getactivescheme'))
        (Read-PowerCfg @('/query', $Guid, 'SUB_VIDEO', 'VIDEOIDLE'))
        (Read-PowerCfg @('/query', $Guid, 'SUB_SLEEP', 'STANDBYIDLE'))
        (Read-PowerCfg @('/query', $Guid, 'SUB_SLEEP', 'HIBERNATEIDLE'))
        (Read-PowerCfg @('/a'))
    ) -join "`r`n"
}
$scheme = Read-PowerCfg @('/getactivescheme')
$guid = [regex]::Match($scheme, '[0-9a-fA-F]{8}(-[0-9a-fA-F]{4}){3}-[0-9a-fA-F]{12}').Value
if (-not $guid) { throw 'Cannot determine active power scheme' }
$before = Snapshot $guid
$before | Set-Content -LiteralPath $evidence -Encoding UTF8
if (-not $Apply) {
    Write-Host $before
    Write-Host "INSPECT ONLY; no power settings changed. Evidence: $evidence"
    return
}
$backup = Join-Path $directory "power-plan-before-$stamp.pow"
Read-PowerCfg @('/export', $backup, $guid) | Out-Null
if (-not (Test-Path -LiteralPath $backup) -or (Get-Item -LiteralPath $backup).Length -eq 0) { throw 'Power-plan backup missing/empty' }
# Preserve a restore procedure BEFORE any setting is changed. Import into a new
# GUID so rollback cannot overwrite the still-existing plan or destroy its backup.
$restoreGuid = [guid]::NewGuid().ToString()
$restore = Join-Path $directory "restore-power-$stamp.ps1"
@(
    "& powercfg.exe /import '$backup' $restoreGuid"
    'if ($LASTEXITCODE -ne 0) { throw "Power plan import failed; nothing activated" }'
    "& powercfg.exe /setactive $restoreGuid"
    'if ($LASTEXITCODE -ne 0) { throw "Power plan activation failed" }'
    '& powercfg.exe /getactivescheme'
) | Set-Content -LiteralPath $restore -Encoding UTF8
"Backup: $backup`r`nRestore script: $restore`r`nOriginal scheme: $guid" | Add-Content -LiteralPath $evidence
# Explicit GUID avoids /change silently targeting a different active scheme.
$settings = ,@('SUB_VIDEO','VIDEOIDLE')
if ($IncludeStandby) { $settings += ,@('SUB_SLEEP','STANDBYIDLE') }
try {
    foreach ($setting in $settings) {
        Read-PowerCfg @('/setacvalueindex', $guid, $setting[0], $setting[1], '0') | Out-Null
        Read-PowerCfg @('/setdcvalueindex', $guid, $setting[0], $setting[1], '0') | Out-Null
    }
    Read-PowerCfg @('/setactive', $guid) | Out-Null
    foreach ($setting in $settings) {
        $query = Read-PowerCfg @('/query', $guid, $setting[0], $setting[1])
        # This image is English. Fail verification explicitly on other locales.
        $indexes = [regex]::Matches($query, 'Current (AC|DC) Power Setting Index:\s*0x([0-9a-fA-F]{8})')
        if ($indexes.Count -ne 2 -or @($indexes | Where-Object {$_.Groups[2].Value -ne '00000000'}).Count -gt 0) {
            throw "Cannot prove both indexes are zero: $query"
        }
    }
    "AFTER`r`n$(Snapshot $guid)" | Add-Content -LiteralPath $evidence
    Write-Host "VERIFIED only the requested timeout values. Evidence: $evidence"
    Write-Host "Rollback: powershell -NoProfile -ExecutionPolicy Bypass -File `"$restore`""
} catch {
    "FAILED/POSSIBLY PARTIAL: $_`r`nRestore: $restore" | Add-Content -LiteralPath $evidence
    throw
}
# No hibernation disable, service changes, driver restart or guest reboot.
