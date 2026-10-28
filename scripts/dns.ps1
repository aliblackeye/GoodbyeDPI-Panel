# Windows DNS-over-HTTPS on/off with a backup so it can be undone.
#   -Action status   -> prints ON | OFF | UNSUPPORTED
#   -Action enable   -> backs up current DNS + DoH settings (first time only),
#                       sets Google + Cloudflare DNS (IPv4 and IPv6) on every
#                       connected adapter and forces DoH (no plain-UDP fallback).
#                       Prints ENABLED | UNSUPPORTED | ERROR:<msg>
#   -Action disable  -> restores the backup (DHCP or the old static servers and
#                       the old DoH table). Without a backup (DoH turned on by an
#                       older panel version) it turns DoH auto-upgrade off and
#                       resets the adapters to DHCP DNS.
#                       Prints DISABLED | DISABLED_NOBACKUP | ERROR:<msg>
# Windows DoH (Get-DnsClientDohServerAddress) exists on Windows 11 and
# Server 2022+. On Windows 10 this prints UNSUPPORTED and changes nothing.
# Keep this file ASCII-only: Windows PowerShell 5.1 reads BOM-less files as ANSI.
param(
    [ValidateSet('status', 'enable', 'disable')][string]$Action = 'status'
)
$ErrorActionPreference = 'Stop'

$StateDir = Join-Path $env:ProgramData 'GoodbyeDPI-Panel'
$Backup   = Join-Path $StateDir 'dns-backup.json'

$Google = 'https://dns.google/dns-query'
$Cf     = 'https://cloudflare-dns.com/dns-query'
$DohServers = @(
    @{ a = '8.8.8.8';              t = $Google },
    @{ a = '8.8.4.4';              t = $Google },
    @{ a = '1.1.1.1';              t = $Cf },
    @{ a = '1.0.0.1';              t = $Cf },
    @{ a = '2001:4860:4860::8888'; t = $Google },
    @{ a = '2001:4860:4860::8844'; t = $Google },
    @{ a = '2606:4700:4700::1111'; t = $Cf },
    @{ a = '2606:4700:4700::1001'; t = $Cf }
)
# Two providers so one blocked DoH endpoint does not kill DNS.
$V4 = @('8.8.8.8', '1.1.1.1')
$V6 = @('2001:4860:4860::8888', '2606:4700:4700::1111')

function Test-DohSupported {
    return [bool](Get-Command Get-DnsClientDohServerAddress -ErrorAction SilentlyContinue)
}

function Get-ActiveInterfaces {
    Get-NetIPConfiguration -ErrorAction SilentlyContinue | Where-Object {
        $_.NetAdapter -and $_.NetAdapter.Status -eq 'Up' -and ($_.IPv4DefaultGateway -or $_.IPv6DefaultGateway)
    }
}

function Get-StaticServers([string]$Guid, [int]$Family) {
    $svc = if ($Family -eq 6) { 'Tcpip6' } else { 'Tcpip' }
    $key = "HKLM:\SYSTEM\CurrentControlSet\Services\$svc\Parameters\Interfaces\$Guid"
    $v = (Get-ItemProperty -Path $key -Name NameServer -ErrorAction SilentlyContinue).NameServer
    if ($v) { return @($v -split '[ ,]' | Where-Object { $_ }) }
    return @()
}

function Get-DohEntry([string]$Addr) {
    return Get-DnsClientDohServerAddress -ServerAddress $Addr -ErrorAction SilentlyContinue
}

function Set-AdapterDns([int]$Index, [int]$Family, [string[]]$Servers) {
    $fam = if ($Family -eq 6) { 'ipv6' } else { 'ipv4' }
    $nameArg = 'name=' + $Index
    $Servers = @($Servers | Where-Object { $_ })
    if ($Servers.Count -eq 0) {
        & netsh interface $fam set dnsservers $nameArg source=dhcp | Out-Null
        return
    }
    & netsh interface $fam set dnsservers $nameArg static ([string]$Servers[0]) primary validate=no | Out-Null
    for ($i = 1; $i -lt $Servers.Count; $i++) {
        $indexArg = 'index=' + ($i + 1)
        & netsh interface $fam add dnsservers $nameArg ([string]$Servers[$i]) $indexArg validate=no | Out-Null
    }
}

function Save-Backup {
    $old = $null
    if (Test-Path $Backup) { $old = Get-Content $Backup -Raw | ConvertFrom-Json }
    $doh = @()
    $ifs = @()
    if ($old) {
        $doh = @($old.doh)
        $ifs = @($old.ifs)
    } else {
        foreach ($s in $DohServers) {
            $e = Get-DohEntry $s.a
            if ($e) {
                $doh += [pscustomobject]@{ a = $s.a; existed = $true; t = $e.DohTemplate; up = [bool]$e.AutoUpgrade; udp = [bool]$e.AllowFallbackToUdp }
            } else {
                $doh += [pscustomobject]@{ a = $s.a; existed = $false; t = ''; up = $false; udp = $false }
            }
        }
    }
    # Add adapters that are not in the backup yet (e.g. Wi-Fi joined later).
    foreach ($c in Get-ActiveInterfaces) {
        $idx = [int]$c.InterfaceIndex
        if (@($ifs | Where-Object { $_.idx -eq $idx }).Count -gt 0) { continue }
        $guid = [string]$c.NetAdapter.InterfaceGuid
        $ifs += [pscustomobject]@{
            idx   = $idx
            alias = [string]$c.InterfaceAlias
            v4    = @(Get-StaticServers $guid 4)
            v6    = @(Get-StaticServers $guid 6)
        }
    }
    if (-not (Test-Path $StateDir)) { New-Item -ItemType Directory -Path $StateDir -Force | Out-Null }
    [pscustomobject]@{ version = 1; saved = (Get-Date).ToString('s'); doh = $doh; ifs = $ifs } |
        ConvertTo-Json -Depth 5 | Set-Content -Path $Backup -Encoding UTF8
}

function Enable-Doh {
    Save-Backup
    foreach ($s in $DohServers) {
        if (Get-DohEntry $s.a) {
            Set-DnsClientDohServerAddress -ServerAddress $s.a -DohTemplate $s.t -AutoUpgrade $true -AllowFallbackToUdp $false | Out-Null
        } else {
            Add-DnsClientDohServerAddress -ServerAddress $s.a -DohTemplate $s.t -AutoUpgrade $true -AllowFallbackToUdp $false | Out-Null
        }
    }
    foreach ($c in Get-ActiveInterfaces) {
        Set-AdapterDns ([int]$c.InterfaceIndex) 4 $V4
        try { Set-AdapterDns ([int]$c.InterfaceIndex) 6 $V6 } catch { }
    }
    Clear-DnsClientCache
}

function Disable-Doh {
    if (Test-Path $Backup) {
        $b = Get-Content $Backup -Raw | ConvertFrom-Json
        foreach ($d in @($b.doh)) {
            $cur = Get-DohEntry $d.a
            if ($d.existed) {
                if ($cur) {
                    Set-DnsClientDohServerAddress -ServerAddress $d.a -DohTemplate $d.t -AutoUpgrade ([bool]$d.up) -AllowFallbackToUdp ([bool]$d.udp) | Out-Null
                } else {
                    Add-DnsClientDohServerAddress -ServerAddress $d.a -DohTemplate $d.t -AutoUpgrade ([bool]$d.up) -AllowFallbackToUdp ([bool]$d.udp) | Out-Null
                }
            } elseif ($cur) {
                Remove-DnsClientDohServerAddress -ServerAddress $d.a -Confirm:$false | Out-Null
            }
        }
        foreach ($i in @($b.ifs)) {
            if (-not (Get-NetAdapter -InterfaceIndex ([int]$i.idx) -ErrorAction SilentlyContinue)) { continue }
            Set-AdapterDns ([int]$i.idx) 4 @($i.v4)
            try { Set-AdapterDns ([int]$i.idx) 6 @($i.v6) } catch { }
        }
        Remove-Item $Backup -Force
        Clear-DnsClientCache
        return 'DISABLED'
    }
    # No backup: DoH was turned on by an older panel version.
    foreach ($s in $DohServers) {
        $e = Get-DohEntry $s.a
        if ($e) { Set-DnsClientDohServerAddress -ServerAddress $s.a -DohTemplate $e.DohTemplate -AutoUpgrade $false -AllowFallbackToUdp $false | Out-Null }
    }
    foreach ($c in Get-ActiveInterfaces) {
        Set-AdapterDns ([int]$c.InterfaceIndex) 4 @()
        try { Set-AdapterDns ([int]$c.InterfaceIndex) 6 @() } catch { }
    }
    Clear-DnsClientCache
    return 'DISABLED_NOBACKUP'
}

function Get-Status {
    foreach ($c in Get-ActiveInterfaces) {
        $srv = @((Get-DnsClientServerAddress -InterfaceIndex $c.InterfaceIndex -AddressFamily IPv4 -ErrorAction SilentlyContinue).ServerAddresses)
        if ($srv.Count -eq 0) { return 'OFF' }
        $e = Get-DohEntry $srv[0]
        if (-not ($e -and $e.AutoUpgrade)) { return 'OFF' }
    }
    if (@(Get-ActiveInterfaces).Count -eq 0) { return 'OFF' }
    return 'ON'
}

try {
    if (-not (Test-DohSupported)) { Write-Output 'UNSUPPORTED'; exit 2 }
    switch ($Action) {
        'status'  { Write-Output (Get-Status) }
        'enable'  { Enable-Doh; Write-Output 'ENABLED' }
        'disable' { Write-Output (Disable-Doh) }
    }
    exit 0
}
catch {
    Write-Output ('ERROR:' + $_.Exception.Message)
    exit 1
}
