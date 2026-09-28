<#
.SYNOPSIS
  Runs the Nextendo stack from stack/bin (see build_all.ps1), configured by stack.cfg and config/*.env.

  -Action start    stop anything running, then start SERVICES and GAMES from stack.cfg (default)
          stop     stop every server started from stack/bin
          status   which configured ports are listening
          hosts    write stack/out/hosts.txt (Atmosphere hosts for this PC's LAN address)
          ip       print the resolved HOST and HOST2

  Each server's config/<name>.env is its environment. Special keys: PORTS (checked by status), CWD
  (working directory; default stack/state/<name>), EXE (binary name; default <name>). Values may use
  ${ROOT} ${HOST} ${HOST2} ${CERTS} ${SECRETS} ${STATE} ${LOGS}. Game servers get config/_games.env
  first; every server gets stack/secrets/stack.env first.
#>
[CmdletBinding()]
param([ValidateSet('start', 'stop', 'status', 'hosts', 'ip')][string]$Action = 'start')

$ErrorActionPreference = 'Stop'
$root    = $PSScriptRoot
$bin     = Join-Path $root 'stack\bin'
$logs    = Join-Path $root 'stack\logs'
$state   = Join-Path $root 'stack\state'
$certs   = Join-Path $root 'stack\certs'
$secrets = Join-Path $root 'stack\secrets'
New-Item -ItemType Directory -Force -Path $logs, $state | Out-Null

function Read-KeyValues([string]$path) {
    $kv = [ordered]@{}
    if (-not (Test-Path $path)) { return $kv }
    foreach ($line in Get-Content $path) {
        $t = $line.Trim()
        if (-not $t -or $t.StartsWith('#')) { continue }
        $i = $t.IndexOf('=')
        if ($i -gt 0) { $kv[$t.Substring(0, $i).Trim()] = $t.Substring($i + 1).Trim() }
    }
    return $kv
}

$cfg = Read-KeyValues (Join-Path $root 'stack.cfg')

function Resolve-Host([string]$value) {
    if ($value -and $value -ne 'auto') { return $value }
    $addrs = Get-NetIPAddress -AddressFamily IPv4 -ErrorAction SilentlyContinue |
        Where-Object { $_.InterfaceAlias -notlike '*ZeroTier*' -and $_.IPAddress -notlike '169.254.*' -and $_.IPAddress -ne '127.0.0.1' }
    $hotspot = $addrs | Where-Object IPAddress -eq '192.168.137.1'
    if ($hotspot) { return '192.168.137.1' }
    $private = $addrs | Where-Object { $_.IPAddress -match '^(10\.|192\.168\.|172\.(1[6-9]|2\d|3[01])\.)' } | Select-Object -First 1
    if ($private) { return $private.IPAddress }
    throw 'No LAN address found: set HOST in stack.cfg'
}

$hostIp  = Resolve-Host $cfg['HOST']
$hostIp2 = if ($cfg['HOST2']) { $cfg['HOST2'] } else { '127.0.0.1' }
if (-not $cfg['HOST2'] -and $Action -eq 'start') { Write-Host '[stack] HOST2 not set: nncs uses 127.0.0.1 as its second address (Pia NAT checks need a real one)' -ForegroundColor Yellow }

function Expand([string]$v, [string]$name) {
    $v.Replace('${ROOT}', $root).Replace('${HOST2}', $hostIp2).Replace('${HOST}', $hostIp).
       Replace('${CERTS}', $certs).Replace('${SECRETS}', $secrets).Replace('${LOGS}', $logs).
       Replace('${STATE}', (Join-Path $state $name))
}

function Stop-Stack {
    $procs = Get-Process -ErrorAction SilentlyContinue | Where-Object { $_.Path -and $_.Path.StartsWith($bin, 'OrdinalIgnoreCase') }
    $procs | Stop-Process -Force -ErrorAction SilentlyContinue
    Write-Host "[stack] stopped $(@($procs).Count) server(s)"
}

function Get-Units {
    $services = @($cfg['SERVICES'] -split ',' | ForEach-Object Trim | Where-Object { $_ })
    $games    = @($cfg['GAMES']    -split ',' | ForEach-Object Trim | Where-Object { $_ })
    # sni-router last: it owns :443 and forwards to everything else.
    $router = $services | Where-Object { $_ -eq 'sni-router' }
    $units  = @($services | Where-Object { $_ -ne 'sni-router' } | ForEach-Object { @{ Name = $_; Game = $false } })
    $units += @($games | ForEach-Object { @{ Name = $_; Game = $true } })
    if ($router) { $units += @{ Name = 'sni-router'; Game = $false } }
    return $units
}

function Get-UnitEnv($unit) {
    $env = [ordered]@{}
    foreach ($f in @((Join-Path $secrets 'stack.env')) + $(if ($unit.Game) { @(Join-Path $root 'config\_games.env') } else { @() }) + @(Join-Path $root "config\$($unit.Name).env")) {
        foreach ($e in (Read-KeyValues $f).GetEnumerator()) { $env[$e.Key] = Expand $e.Value $unit.Name }
    }
    return $env
}

switch ($Action) {
    'stop' { Stop-Stack }

    'ip' { Write-Output "$hostIp $hostIp2" }

    'hosts' {
        $out = Join-Path $root 'stack\out'
        New-Item -ItemType Directory -Force -Path $out | Out-Null
        $text = (Get-Content (Join-Path $root 'stack\hosts.template') -Raw).Replace('${HOST2}', $hostIp2).Replace('${HOST}', $hostIp)
        Set-Content -Path (Join-Path $out 'hosts.txt') -Value $text -NoNewline
        Write-Host "[stack] wrote stack\out\hosts.txt for ${hostIp}: copy it to sd:/atmosphere/hosts/emummc.txt (or sysmmc.txt), then reboot"
    }

    'status' {
        $listening = Get-NetTCPConnection -State Listen -ErrorAction SilentlyContinue | Select-Object -ExpandProperty LocalPort -Unique
        foreach ($u in Get-Units) {
            $uenv  = Get-UnitEnv $u
            $ports = $uenv['PORTS']
            $exe   = Join-Path $bin "$(if ($uenv['EXE']) { $uenv['EXE'] } else { $u.Name }).exe"
            $running = @(Get-Process -ErrorAction SilentlyContinue | Where-Object { $_.Path -eq $exe }).Count -gt 0
            $p = if ($ports) { ($ports -split ',' | ForEach-Object { $x = $_.Trim(); if ($listening -contains [int]$x) { ":$x up" } else { ":$x DOWN" } }) -join ' ' } else { '' }
            Write-Host ("  {0,-22} {1,-8} {2}" -f $u.Name, $(if ($running) { 'running' } else { 'stopped' }), $p)
        }
    }

    'start' {
        Stop-Stack
        Write-Host "[stack] LAN address $hostIp (second $hostIp2)"
        foreach ($u in Get-Units) {
            $env = Get-UnitEnv $u
            $exe = Join-Path $bin "$(if ($env['EXE']) { $env['EXE'] } else { $u.Name }).exe"
            if (-not (Test-Path $exe)) { Write-Host ("  {0,-22} not built (run build_all.ps1)" -f $u.Name) -ForegroundColor Yellow; continue }
            $cwd = if ($env['CWD']) { $env['CWD'] } else { Join-Path $state $u.Name }
            New-Item -ItemType Directory -Force -Path $cwd, (Join-Path $state $u.Name) | Out-Null
            if ($u.Name -eq 'account') { $ef = Join-Path (Join-Path $state 'account') 'nextendo.env'; if (-not (Test-Path $ef)) { New-Item -ItemType File -Path $ef | Out-Null } }

            $psi = New-Object System.Diagnostics.ProcessStartInfo
            $psi.FileName = $env:ComSpec
            $log = Join-Path $logs "$($u.Name).log"
            $psi.Arguments = "/c `"`"$exe`" > `"$log`" 2>&1`""
            $psi.WorkingDirectory = $cwd
            $psi.UseShellExecute = $false
            $psi.CreateNoWindow = $true
            foreach ($e in $env.GetEnumerator()) { if ($e.Key -notin 'PORTS', 'CWD', 'EXE') { $psi.Environment[$e.Key] = $e.Value } }
            [System.Diagnostics.Process]::Start($psi) | Out-Null
            Write-Host ("  {0,-22} started" -f $u.Name)
        }
        Start-Sleep -Seconds 3
        & $PSCommandPath -Action status
        Write-Host "[stack] logs in stack\logs; for the console: .\run_all.ps1 -Action hosts"
    }
}
