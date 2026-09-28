<#
.SYNOPSIS
  Generates the stack's own keys and certificates (LAN testing). Needs openssl on the PATH.

  By default only what is missing is created; -Force regenerates everything (every console then needs the
  new nextendo-nx: see the end). Files, and who uses them:

    stack/certs/local_ca.key, local_ca.pem   the local CA; the Switch browser trusts it (nextendo-nx romfs)
    stack/certs/key.pem, leaf.pem, cert.pem  shared TLS for services and games (cert.pem = leaf + CA)
    stack/certs/browser_cert.pem             tls-front: the account sign-in pages the browser opens
    stack/certs/bcat_cert.pem                bcat-nx (BCAT checks the host name)
    stack/certs/baas_signing_key.pem (+.pub) account + baas-jwks tokens
    stack/certs/dauth/dcert_key.pem, acert_key.pem   dauth
    stack/secrets/nextendo_secret.key        the Nextendo identity signer (games, baas-jwks)
    stack/secrets/ctr_auth_signing_key.pem (+_pub)   CTR replies (the CTR client mod needs the public key)
    stack/secrets/bcat_signing_key.pem       BCAT containers
    stack/secrets/stack.env                  NEXTENDO_SECURE_PASSWORD, NEXTENDO_INTERNAL_KEY
    config/account.env                       NEXTENDO_SECRET, NEXTENDO_SIGN_KEY, NEXTENDO_ADMIN_KEY

  Not generated (fixed values): stack/secrets/bcat_news_secrets.json (the console's News passphrase and
  salts) and each game's NEX access key in config/<game>.env.

.EXAMPLE
  .\gen_keys.ps1            # create what is missing
  .\gen_keys.ps1 -Force     # new keys for everything
#>
[CmdletBinding()]
param([switch]$Force)

$ErrorActionPreference = 'Stop'
$root    = $PSScriptRoot
$certs   = Join-Path $root 'stack\certs'
$secrets = Join-Path $root 'stack\secrets'
New-Item -ItemType Directory -Force -Path $certs, $secrets, (Join-Path $certs 'dauth') | Out-Null
if (-not (Get-Command openssl -ErrorAction SilentlyContinue)) { throw 'openssl not found on the PATH (Git for Windows or devkitPro msys2 ship one)' }

$made = New-Object System.Collections.Generic.List[string]
function Need([string]$path) { $Force -or -not (Test-Path $path) }
function Ossl { $out = & openssl @args 2>&1; if ($LASTEXITCODE -ne 0) { throw "openssl $($args -join ' '): $out" } }
function Rsa([string]$path) { Ossl genpkey -algorithm RSA -pkeyopt rsa_keygen_bits:2048 -out $path; $made.Add($path.Replace("$root\", '')) }
function RandText([int]$n) { -join ((48..57) + (65..90) + (97..122) | Get-Random -Count $n | ForEach-Object { [char]$_ }) }
function RandHex([int]$bytes) { $b = New-Object byte[] $bytes; [Security.Cryptography.RandomNumberGenerator]::Fill($b); -join ($b | ForEach-Object { $_.ToString('x2') }) }

# A server certificate from the local CA for these names, signed with key.pem.
function ServerCert([string]$out, [string]$cn, [string[]]$names) {
    $tmp = New-Item -ItemType Directory -Force (Join-Path $env:TEMP "nx-genkeys-$(Get-Random)")
    $san = ($names | ForEach-Object { if ($_ -match '^\d+(\.\d+){3}$') { "IP:$_" } else { "DNS:$_" } }) -join ','
    "basicConstraints=critical,CA:FALSE`nkeyUsage=critical,digitalSignature,keyEncipherment`nextendedKeyUsage=serverAuth`nsubjectAltName=$san" |
        Set-Content -Encoding ascii "$tmp\ext.cnf"
    Ossl req -new -key "$certs\key.pem" -subj "/O=Nextendo Local/CN=$cn" -out "$tmp\req.csr"
    Ossl x509 -req -in "$tmp\req.csr" -CA "$certs\local_ca.pem" -CAkey "$certs\local_ca.key" -CAcreateserial -CAserial "$certs\local_ca.srl" -days 397 -sha256 -extfile "$tmp\ext.cnf" -out $out
    Remove-Item $tmp -Recurse -Force
    $made.Add($out.Replace("$root\", ''))
}

# The local CA.
$newCA = $false
if (Need "$certs\local_ca.pem") {
    $old = if (Test-Path "$certs\local_ca.pem") { (Get-Content "$certs\local_ca.pem" -Raw).Trim() } else { $null }
    Rsa "$certs\local_ca.key"
    Ossl req -x509 -new -key "$certs\local_ca.key" -subj '/O=Nextendo Local/CN=Nextendo Local CA' -days 9125 -sha256 `
        -addext 'basicConstraints=critical,CA:TRUE' -addext 'keyUsage=critical,keyCertSign,cRLSign' -out "$certs\local_ca.pem"
    $made.Add('stack\certs\local_ca.pem'); $newCA = $true

    # The Switch browser trusts it through the RootCa bundles in nextendo-nx's romfs (our block is swapped;
    # romfs/sd/rootCA.pem is production Nextendo's CA and is left alone).
    $romfs = Join-Path $root 'console\nro-nx\romfs\sd'
    $ca = (Get-Content "$certs\local_ca.pem" -Raw).Trim()
    foreach ($b in Get-ChildItem "$romfs\atmosphere\contents\0100000000000803\romfs" -Recurse -Filter 'RootCa*.pem' -ErrorAction SilentlyContinue) {
        $text = (Get-Content $b.FullName -Raw)
        if ($old) { $text = $text.Replace($old, '') }
        [IO.File]::WriteAllText($b.FullName, $text.TrimEnd() + "`n" + $ca + "`n")
        $made.Add($b.FullName.Replace("$root\", ''))
    }
}

# Shared TLS key and certificates (regenerated with a new CA, since they are signed by it).
if (Need "$certs\key.pem") { Rsa "$certs\key.pem" }
$stackNames = 'accounts.nintendo.com', 'api.accounts.nintendo.com', 'nintendo.com', '*.nintendo.com', '*.accounts.nintendo.com',
              '*.baas.nintendo.com', '*.nintendo.net', '*.srv.nintendo.net', '*.ndas.srv.nintendo.net', '*.hac.lp1.srv.nintendo.net',
              '*.npln.nintendo.net', '*.cdn.nintendo.net', '*.nintendo.co.jp', 'nextendo.local', '127.0.0.1'
if ($newCA -or (Need "$certs\leaf.pem")) {
    ServerCert "$certs\leaf.pem" 'accounts.nintendo.com' $stackNames
    [IO.File]::WriteAllText("$certs\cert.pem", (Get-Content "$certs\leaf.pem" -Raw).Trim() + "`n" + (Get-Content "$certs\local_ca.pem" -Raw).Trim() + "`n")
    $made.Add('stack\certs\cert.pem')
}
if ($newCA -or (Need "$certs\browser_cert.pem")) {
    ServerCert "$certs\browser_cert.pem" 'accounts.nintendo.com' @('accounts.nintendo.com', 'api.accounts.nintendo.com', 'cdn.accounts.nintendo.com')
}
if ($newCA -or (Need "$certs\bcat_cert.pem")) {
    ServerCert "$certs\bcat_cert.pem" 'bcat-topics-lp1.cdn.nintendo.net' @('*.cdn.nintendo.net', 'bcat-topics-lp1.cdn.nintendo.net', 'bcat-list-lp1.cdn.nintendo.net', 'bcat-data-lp1.cdn.nintendo.net')
}

# Signing keys.
if (Need "$certs\baas_signing_key.pem") {
    Rsa "$certs\baas_signing_key.pem"
    Ossl pkey -in "$certs\baas_signing_key.pem" -pubout -out "$certs\baas_signing_key.pub.pem"
}
foreach ($k in 'dcert_key.pem', 'acert_key.pem') { if (Need "$certs\dauth\$k") { Rsa "$certs\dauth\$k" } }
if (Need "$secrets\ctr_auth_signing_key.pem") {
    Rsa "$secrets\ctr_auth_signing_key.pem"
    Ossl pkey -in "$secrets\ctr_auth_signing_key.pem" -pubout -out "$secrets\ctr_auth_signing_pub.pem"
}
if (Need "$secrets\bcat_signing_key.pem") { Rsa "$secrets\bcat_signing_key.pem" }
if (Need "$secrets\nextendo_secret.key") {
    [IO.File]::WriteAllText("$secrets\nextendo_secret.key", (RandHex 32)); $made.Add('stack\secrets\nextendo_secret.key')
}

# Passwords and shared secrets.
if (Need "$secrets\stack.env") {
    [IO.File]::WriteAllText("$secrets\stack.env", "# Stack secrets (LAN testing; published on purpose). Shared by every server.`nNEXTENDO_SECURE_PASSWORD=$(RandText 42)`nNEXTENDO_INTERNAL_KEY=$(RandText 31)`n`n")
    $made.Add('stack\secrets\stack.env')
}
$acct = Join-Path $root 'config\account.env'
if ($Force -and (Test-Path $acct)) {
    (Get-Content $acct) -replace '^NEXTENDO_SECRET=.*$', "NEXTENDO_SECRET=$(RandText 48)" `
                        -replace '^NEXTENDO_SIGN_KEY=.*$', "NEXTENDO_SIGN_KEY=$(RandText 62)" `
                        -replace '^NEXTENDO_ADMIN_KEY=.*$', "NEXTENDO_ADMIN_KEY=$(RandText 24)" | Set-Content -Encoding ascii $acct
    $made.Add('config\account.env (NEXTENDO_SECRET, NEXTENDO_SIGN_KEY, NEXTENDO_ADMIN_KEY)')
}

if ($made.Count -eq 0) { Write-Host '[keys] everything is already there (-Force regenerates it all)'; return }
Write-Host "[keys] written:"; $made | ForEach-Object { Write-Host "  $_" }
Write-Host '[keys] restart the stack: .\run_all.ps1'
if ($newCA) {
    Write-Host '[keys] NEW local CA: rebuild nextendo-nx (.\build_all.ps1) and copy stack\out\nextendo-nx.nro to every console, then switch it to Nextendo again so the browser trusts the new CA.' -ForegroundColor Yellow
}
if ($Force) {
    Write-Host '[keys] new signing keys: accounts made before keep working, but consoles must sign in again; the CTR client mod needs stack\secrets\ctr_auth_signing_pub.pem.' -ForegroundColor Yellow
}
