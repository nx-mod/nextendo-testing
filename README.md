# nextendo-testing

The whole **Nextendo Network** on nx-mod's `testing` branches, in one repo: every server, the console
homebrew and the clients, as submodules. Build it and run it on a LAN, then point a CFW Switch at it.

```powershell
git clone --recurse-submodules https://github.com/nx-mod/nextendo-testing
cd nextendo-testing
.\build_all.ps1            # every server into stack\bin, nextendo-nx.nro into stack\out  (-Update: latest testing)
.\run_all.ps1              # start everything (stop | status | hosts | ip)
.\run_all.ps1 -Action hosts   # Atmosphere hosts for your LAN address -> stack\out\hosts.txt
```

Needs Go and git; devkitPro (with the switch SDL2 portlibs) and Git Bash for `nextendo-nx.nro`.

## Configuration

| file | what |
|---|---|
| `stack.cfg` | `HOST` / `HOST2` (this PC's LAN addresses; nncs needs two), which `GAMES` and `SERVICES` run |
| `config/<server>.env` | each server's environment (`${HOST}`, `${CERTS}`, `${STATE}`... are filled in) |
| `config/_games.env` | shared by every game server |
| `stack/certs/`, `stack/secrets/` | the stack's CA, certificates, keys and secrets |

LAN testing only: keys and secrets are committed on purpose, so anyone on the LAN can run the stack. Never point
production at them. Servers keep their data under `stack\state`, logs in `stack\logs`.

## Layout

    services/  account, dauth (dauth + aauth + licences), scsi, nncs, nex, sni-router, baas-jwks, dashboard,
               site, docs, tls-front, and nx-mod's nnaccount-nx, bcat-nx, tagaya-nx, npns-nx,
               telemetry-nx, eos-nx, gamespy-nx
    games/     every Nextendo game server, nx-mod's diablo-3-nx, advance-wars-nx, borderlands-1-nx,
               torchlight-2-nx, and crash-team-racing
    console/   prelude (nextendo-nx, nx-mod's rewrite of Prelude), bcat-mitm-nx
    clients/   citron (testing-android), citron-android, ryujinx, app-android, app-ios

## nx-mod changes

Written from scratch by nx-mod (`-nx`):
- **nnaccount-nx** — the Nintendo Account side (a rewrite of a private upstream service).
- **diablo-3-nx**, **advance-wars-nx**, **borderlands-1-nx**, **torchlight-2-nx** — game servers.
- **bcat-nx** (+ **bcat-mitm-nx** on the console), **tagaya-nx**, **npns-nx**, **telemetry-nx**, **eos-nx**,
  **gamespy-nx** — services.
- **prelude** (`nextendo-nx`) — Prelude rewritten on the Aether GUI around the new servers.

Changes to Nextendo's own servers:
- **account** — local open mode (a new e-mail creates its account, everyone friends), RS256 BaaS id_tokens.
- **baas-jwks** — BaaS for a real console: camelCase tokens, device login, users, snapshot.
- **dauth** — the licence check online games need (`available_elicenses`).
- **sni-router** — table-driven routing for every host, a TLS record trace.
- **nex** — Eagle relay, rankings, MHGU; **nncs** — explicit binds; **scsi** — `SCSI_LISTEN`;
  **dashboard** — ARMS/MTA; **site** — no Turnstile locally; **splatoon-3** — builds.
- **citron** (`testing-android`) — LAN play (LDN, Android VPN tunnel), Diablo III hosts, Mii sync.
- **tls-front** — imported from the local stack: Nintendo Account traffic to nnaccount-nx, capture, traces.

Every repo's README lists its own changes. ZeroTier work is on separate `zerotier` branches, not here.

## Credits

The Nextendo Network is the work of the **Nextendo Network team** — https://nextendo.network. nx-mod builds on it
for LAN testing, with Crash Team Racing support by **CollectingW**. Nextendo is awesome.
