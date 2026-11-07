param([ValidateSet('initial','capture','restart','cycle')][string]$Phase='initial')
# Read-only, bounded verification; no Windows services or network policies changed.
$ErrorActionPreference='Stop'
$result=[ordered]@{phase=$Phase;timestamp=(Get-Date -Format o)}
function Check($name,[scriptblock]$body) {
    try { $result[$name]=[ordered]@{ok=$true;data=(& $body)} }
    catch { $result[$name]=[ordered]@{ok=$false;error=$_.Exception.Message} }
}
Check os {Get-CimInstance Win32_OperatingSystem | Select-Object Caption,Version,BuildNumber,TotalVisibleMemorySize,FreePhysicalMemory,LastBootUpTime}
Check nic {Get-CimInstance Win32_NetworkAdapter | Where-Object {$_.NetEnabled} | Select-Object Name,PNPDeviceID,ConfigManagerErrorCode,MACAddress}
Check dhcp {Get-CimInstance Win32_NetworkAdapterConfiguration | Where-Object {$_.IPEnabled} | Select-Object DHCPEnabled,IPAddress,IPSubnet,DefaultIPGateway,DNSServerSearchOrder,DHCPServer}
Check dns {@(Resolve-DnsName example.com -Type A -DnsOnly -QuickTimeout -ErrorAction Stop | Where-Object IPAddress | Select-Object Name,IPAddress)}
Check ipv4 {
    $tcp=New-Object Net.Sockets.TcpClient([Net.Sockets.AddressFamily]::InterNetwork)
    try {$pending=$tcp.BeginConnect('1.1.1.1',443,$null,$null);if(-not $pending.AsyncWaitHandle.WaitOne(5000)){throw 'IPv4 TCP timeout'};$tcp.EndConnect($pending);'TCP 1.1.1.1:443 connected'} finally {$tcp.Dispose()}
}
[Net.ServicePointManager]::SecurityProtocol=[Net.SecurityProtocolType]::Tls12
function Https($url) {
    $req=[Net.HttpWebRequest]::Create($url);$req.Timeout=10000;$req.ReadWriteTimeout=10000;$req.Proxy=$null
    $response=$req.GetResponse()
    try {[ordered]@{url=$url;status=[int]$response.StatusCode;finalUrl=$response.ResponseUri.AbsoluteUri}} finally {$response.Close()}
}
Check https {Https 'https://www.microsoft.com/'}
Check updateEndpoint {Https 'https://fe2.update.microsoft.com/v6/ClientWebService/client.asmx?WSDL'}
Check updateServices {Get-CimInstance Win32_Service | Where-Object {$_.Name -in 'wuauserv','BITS','UsoSvc'} | Select-Object Name,State,StartMode}
Check updateAgent {$manager=New-Object -ComObject Microsoft.Update.ServiceManager;@($manager.Services | Select-Object Name,IsManaged,IsDefaultAUService)}
Check display {Get-CimInstance Win32_VideoController | Select-Object Name,DriverVersion,PNPDeviceID,ConfigManagerErrorCode,CurrentHorizontalResolution,CurrentVerticalResolution,CurrentRefreshRate}
Check idd {Get-ItemProperty 'HKLM:\SOFTWARE\LookingGlass\IDD' | Select-Object DefaultRefresh,Modes,ForceIndirectCopy,ForceFullDirectCopy,ExclusiveMonitor}
Check d3d {Add-Type -TypeDefinition ([IO.File]::ReadAllText((Join-Path $PSScriptRoot 'Probe-IntelD3D.cs')));[XLiteGpuProbe]::Run()}
Check wudfModules {@(Get-Process WUDFHost -ErrorAction SilentlyContinue | ForEach-Object { $p=$_;[ordered]@{pid=$p.Id;modules=@($p.Modules | Where-Object {$_.ModuleName -match 'lgidd|lginput|iddcx'} | Select-Object -ExpandProperty FileName)} })}
Check cpu {
    $before=@{};Get-Process | ForEach-Object {$before[$_.Id]=$_.CPU}
    $clock=[Diagnostics.Stopwatch]::StartNew();Start-Sleep -Seconds 8;$elapsed=$clock.Elapsed.TotalSeconds
    $after=@(Get-Process);$rows=@($after | Where-Object {$before.ContainsKey($_.Id)} | ForEach-Object {
        $delta=[math]::Max(0,$_.CPU-$before[$_.Id]);[pscustomobject]@{name=$_.ProcessName;pid=$_.Id;oneCorePercent=[math]::Round(100*$delta/$elapsed,2);guestPercent=[math]::Round(100*$delta/$elapsed/[Environment]::ProcessorCount,2);workingSetMiB=[math]::Round($_.WorkingSet64/1MB,1)}
    } | Sort-Object oneCorePercent -Descending)
    [ordered]@{elapsedSeconds=$elapsed;vcpus=[Environment]::ProcessorCount;processCount=$after.Count;top=@($rows | Select-Object -First 8);wudf=@($rows | Where-Object name -eq WUDFHost)}
}
$dir=Join-Path $env:ProgramData 'Win10Lab';New-Item -ItemType Directory $dir -Force | Out-Null
$json=$result | ConvertTo-Json -Depth 9
$file=Join-Path $dir ('verification-'+$Phase+'.json');[IO.File]::WriteAllText($file,$json,(New-Object Text.UTF8Encoding($false)))
$report=[IO.DriveInfo]::GetDrives() | Where-Object {$_.IsReady -and $_.VolumeLabel -eq 'WIN10RPT'} | Select-Object -First 1
if(-not $report){throw 'WIN10RPT report drive unavailable'}
$dest=Join-Path $report.RootDirectory.FullName ('verify-'+$Phase+'.json');[IO.File]::WriteAllText($dest,$json,(New-Object Text.UTF8Encoding($false)))
try {Write-VolumeCache -DriveLetter $report.Name.Substring(0,1) -ErrorAction Stop} catch {Write-Warning 'Report copied; read after shutdown if guest volume cache has not flushed.'}
Write-Host "Verification complete: $dest"
