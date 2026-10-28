# Fallback only: the GoodbyeDPI binaries normally ship in bin\x86_64 and bin\x86.
# If they are missing, this downloads the SAME pinned official release from
# github.com/ValdikSS/GoodbyeDPI, checks its SHA-256 and copies bin\<arch>.
# Prints SUCCESS or ERROR:<message>. Exit code 0 = ok, 1 = error.
param(
    [Parameter(Mandatory = $true)][string]$Root
)
$ErrorActionPreference = 'Stop'
$ProgressPreference = 'SilentlyContinue'

$Url    = 'https://github.com/ValdikSS/GoodbyeDPI/releases/download/0.2.3rc3/goodbyedpi-0.2.3rc3-2.zip'
$Sha256 = '37F96B32D050DADCC930A639EBA68E1CCD57ED5C04A5F77DFCA908F01905A4C5'
$Inner  = 'goodbyedpi-0.2.3rc3-2'

$work = Join-Path ([IO.Path]::GetTempPath()) ('gdpi-fetch-' + [guid]::NewGuid().ToString('N'))
try {
    # GitHub needs TLS 1.2; older .NET defaults may not offer it.
    [Net.ServicePointManager]::SecurityProtocol = [Net.ServicePointManager]::SecurityProtocol -bor 3072

    New-Item -ItemType Directory -Path $work | Out-Null
    $zip = Join-Path $work 'goodbyedpi.zip'
    Invoke-WebRequest -Uri $Url -OutFile $zip -UseBasicParsing

    $hash = (Get-FileHash -Path $zip -Algorithm SHA256).Hash
    if ($hash -ne $Sha256) { throw ('SHA-256 uyusmuyor / mismatch: ' + $hash) }

    $ex = Join-Path $work 'x'
    Expand-Archive -Path $zip -DestinationPath $ex -Force

    foreach ($arch in @('x86_64', 'x86')) {
        $src = Join-Path (Join-Path $ex $Inner) $arch
        if (-not (Test-Path (Join-Path $src 'goodbyedpi.exe'))) { throw ('arsivde ' + $arch + ' yok / missing in archive') }
        $dst = Join-Path (Join-Path $Root 'bin') $arch
        New-Item -ItemType Directory -Path $dst -Force | Out-Null
        Copy-Item -Path (Join-Path $src '*') -Destination $dst -Force
    }
    $lic = Join-Path (Join-Path $ex $Inner) 'licenses'
    if (Test-Path $lic) {
        $ldst = Join-Path $Root 'licenses'
        New-Item -ItemType Directory -Path $ldst -Force | Out-Null
        Get-ChildItem $lic -File | Where-Object { -not (Test-Path (Join-Path $ldst $_.Name)) } |
            Copy-Item -Destination $ldst
    }
    $result = 'SUCCESS'
    $code = 0
}
catch {
    $result = 'ERROR:' + $_.Exception.Message
    $code = 1
}
if (Test-Path $work) { Remove-Item $work -Recurse -Force -ErrorAction SilentlyContinue }
Write-Output $result
exit $code
