<#
.SYNOPSIS
  Builds every Nextendo server in this repo into stack/bin/<name>.exe. Needs Go and git.

  The submodules are left untouched: output goes to stack/bin, and game servers whose go.mod expects
  the NEX core as a sibling folder (replace => ../nextendo-nex) are built from a scratch copy laid out
  that way under stack/build/src.

  -Update   first move every server submodule to the latest of its testing branch.
#>
[CmdletBinding()]
param([switch]$Update)

$ErrorActionPreference = 'Stop'
$root = $PSScriptRoot
$bin  = Join-Path $root 'stack\bin'
$src  = Join-Path $root 'stack\build\src'
New-Item -ItemType Directory -Force -Path $bin, $src | Out-Null
$env:GOWORK = 'off'

$go = (Get-Command go -ErrorAction SilentlyContinue).Source
if (-not $go) { $go = 'C:\Program Files\Go\bin\go.exe' }
if (-not (Test-Path $go)) { throw 'Go not found: install it from https://go.dev/dl/' }

# Servers only: clients (emulators, apps) are large and not built here.
$paths = 'services', 'games', 'console'
if ($Update) { git -C $root submodule update --init --remote --depth 50 -- $paths }
else         { git -C $root submodule update --init --depth 50 -- $paths }

$dirs = @(Get-ChildItem (Join-Path $root 'services'), (Join-Path $root 'games') -Directory) +
        @(Get-Item (Join-Path $root 'stack\conntest'))
$ok = @(); $failed = @(); $skipped = @()
foreach ($d in $dirs) {
    $name = $d.Name
    $mod  = Join-Path $d.FullName 'go.mod'
    if (-not (Test-Path $mod)) { $skipped += $name; continue }
    $out  = Join-Path $bin "$name.exe"
    $dir  = $d.FullName
    if (Select-String -Path $mod -Pattern '=>\s*\.\./nextendo-nex' -Quiet) {
        # Lay out <game> next to nextendo-nex, as the go.mod expects.
        $nex = Join-Path $src 'nextendo-nex'
        if (-not (Test-Path $nex)) { Copy-Item (Join-Path $root 'services\nex') $nex -Recurse; Remove-Item (Join-Path $nex '.git') -Force -Recurse -ErrorAction SilentlyContinue }
        $dir = Join-Path $src $name
        if (Test-Path $dir) { Remove-Item $dir -Recurse -Force }
        Copy-Item $d.FullName $dir -Recurse; Remove-Item (Join-Path $dir '.git') -Force -Recurse -ErrorAction SilentlyContinue
        $env:GOFLAGS = '-mod=mod'
    } else { $env:GOFLAGS = '' }
    Push-Location $dir
    try {
        $log = & $go build -o $out . 2>&1
        if ($LASTEXITCODE -eq 0) { $ok += $name } else { $failed += $name; Write-Host "FAIL $name`n$($log | Select-Object -First 5 | Out-String)" -ForegroundColor Red }
    } finally { Pop-Location }
}
$env:GOFLAGS = ''

# nextendo-nx (the Prelude rewrite) as nextendo-nx.nro, pointed at this stack (needs devkitPro with the switch
# SDL2 portlibs, and a bash with make, e.g. Git Bash).
$dkp  = if ($env:DEVKITPRO) { $env:DEVKITPRO } else { 'C:\devkitPro' }
$bash = (Get-Command bash -ErrorAction SilentlyContinue).Source
if (-not $bash -and (Test-Path 'C:\Program Files\Git\bin\bash.exe')) { $bash = 'C:\Program Files\Git\bin\bash.exe' }
if ((Test-Path $dkp) -and $bash) {
    git -C $root submodule update --init --recursive --depth 50 -- console/prelude   # lib/Aether
    $ips = (& (Join-Path $root 'run_all.ps1') -Action ip) -split ' '
    $out = Join-Path $root 'stack\out'
    New-Item -ItemType Directory -Force -Path $out | Out-Null
    $pre = (Join-Path $root 'console\prelude') -replace '\\', '/' -replace '^([A-Za-z]):', { '/' + $_.Groups[1].Value.ToLower() }
    $dk  = $dkp -replace '\\', '/' -replace '^([A-Za-z]):', { '/' + $_.Groups[1].Value.ToLower() }
    & $bash -lc "cd '$pre' && export DEVKITPRO='$dk' DEVKITA64='$dk/devkitA64' && make -C lib/Aether -j8 >/dev/null 2>&1; make clean >/dev/null 2>&1; make -j8 LAN_HOST=$($ips[0]) LAN_HOST2=$($ips[1]) >/dev/null 2>&1"
    $nro = Join-Path $root 'console\prelude\nextendo-nx.nro'
    if (Test-Path $nro) { Copy-Item $nro $out -Force; $ok += "prelude (stack\out\nextendo-nx.nro for $($ips[0]))" }
    else { $failed += 'prelude' }
} else { $skipped += 'prelude (devkitPro or bash not found)' }

Write-Host ("built   {0}: {1}" -f $ok.Count, ($ok -join ' '))
if ($skipped) { Write-Host ("skipped {0} (no Go server): {1}" -f $skipped.Count, ($skipped -join ' ')) }
if ($failed)  { Write-Host ("FAILED  {0}: {1}" -f $failed.Count, ($failed -join ' ')) -ForegroundColor Red; exit 1 }
