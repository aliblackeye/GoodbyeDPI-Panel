# Connectivity probe used by the panel (site test + auto-find).
#   -Site <host>   extra site to check (optional; skipped if it is a Discord host)
#   -Quick         stop at the first failure (auto-find); otherwise check all
# Output: one line per check, then a summary line starting with "RESULT:".
#   RESULT: DNS:OK DISCORD:OK GATEWAY:OK CDN:OK UPDATES:OK SITE:OK NET:OK
# "OK" for HTTPS means the TLS handshake finished and the server sent ANY HTTP
# answer (4xx included): that is what DPI blocks, not the page content.
# Keep ASCII-only (Windows PowerShell 5.1 reads BOM-less files as ANSI).
param(
    [string]$Site = '',
    [int]$TimeoutSec = 6,
    [switch]$Quick
)
$ErrorActionPreference = 'Stop'
try { [Net.ServicePointManager]::SecurityProtocol = [Net.ServicePointManager]::SecurityProtocol -bor 3072 } catch { }

# What the Discord desktop app needs before its window opens:
# API (login), gateway (websocket), CDN (avatars/assets), updater.
$Checks = @(
    @{ k = 'DISCORD'; u = 'https://discord.com/api/v9/gateway' },
    @{ k = 'GATEWAY'; u = 'https://gateway.discord.gg/' },
    @{ k = 'CDN';     u = 'https://cdn.discordapp.com/' },
    @{ k = 'UPDATES'; u = 'https://updates.discord.com/distributions/app/manifests/latest?channel=stable&platform=win&arch=x64' }
)

function Test-Https([string]$Url) {
    $req = [Net.HttpWebRequest]::Create($Url)
    $req.Method = 'GET'
    $req.AllowAutoRedirect = $false
    $req.Timeout = $TimeoutSec * 1000
    $req.ReadWriteTimeout = $TimeoutSec * 1000
    $req.UserAgent = 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) GoodbyeDPI-Panel-Test'
    $resp = $null
    try {
        $resp = $req.GetResponse()
        return @('OK', ([int]$resp.StatusCode).ToString())
    } catch [Net.WebException] {
        if ($_.Exception.Response) {
            $resp = $_.Exception.Response
            return @('OK', ([int]$resp.StatusCode).ToString())
        }
        return @('FAIL', [string]$_.Exception.Status)
    } catch {
        return @('FAIL', $_.Exception.Message)
    } finally {
        if ($resp) { $resp.Close() }
    }
}

function Clean-Host([string]$h) {
    $h = $h.Trim() -replace '^[a-zA-Z]+://', ''
    $i = $h.IndexOf('/'); if ($i -ge 0) { $h = $h.Substring(0, $i) }
    return $h.ToLower()
}

$summary = New-Object System.Collections.ArrayList
$failed = $false
function Add-Result([string]$Key, [string]$State, [string]$Detail) {
    [void]$summary.Add($Key + ':' + $State)
    Write-Output ('{0,-8} {1,-4} {2}' -f $Key, $State, $Detail)
}

# 1) DNS through the Windows resolver (the one the desktop app uses).
try { Clear-DnsClientCache -ErrorAction SilentlyContinue } catch { }
try {
    $ips = [Net.Dns]::GetHostAddresses('discord.com') | ForEach-Object { $_.IPAddressToString }
    $note = ''
    if (-not ($ips | Where-Object { $_ -like '162.159.*' -or $_ -like '2606:4700:*' })) {
        $note = ' (beklenmeyen adres; DNS yonlendiriliyor olabilir / unexpected address, DNS may be hijacked)'
    }
    Add-Result 'DNS' 'OK' ('discord.com -> ' + ($ips -join ', ') + $note)
} catch {
    Add-Result 'DNS' 'FAIL' 'discord.com cozulemedi / could not resolve -> DoH ac / enable DoH'
    $failed = $true
}

# 2) Discord endpoints.
foreach ($c in $Checks) {
    if ($failed -and $Quick) { [void]$summary.Add($c.k + ':SKIP'); continue }
    $r = Test-Https $c.u
    Add-Result $c.k $r[0] ($c.u + ' -> ' + $r[1])
    if ($r[0] -ne 'OK') { $failed = $true }
}

# 3) Optional user site.
$h = Clean-Host $Site
if ($h -and $h -notmatch '(^|\.)(discord\.com|discord\.gg|discordapp\.com|discordapp\.net|discord\.media)$') {
    if ($failed -and $Quick) { [void]$summary.Add('SITE:SKIP') }
    else {
        $r = Test-Https ('https://' + $h + '/')
        Add-Result 'SITE' $r[0] ('https://' + $h + '/ -> ' + $r[1])
        if ($r[0] -ne 'OK') { $failed = $true }
    }
}

# 4) General internet must still work (a mode must not break other sites).
if ($failed -and $Quick) { [void]$summary.Add('NET:SKIP') }
else {
    $r = Test-Https 'https://www.google.com/'
    Add-Result 'NET' $r[0] ('https://www.google.com/ -> ' + $r[1])
}

Write-Output ('RESULT: ' + ($summary -join ' '))
