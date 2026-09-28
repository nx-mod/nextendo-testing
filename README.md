nextendo-testing
================

The whole Nextendo Network, as nx-mod's `testing` branches, in one place: every
server, the console homebrew, the emulator clients. For running a complete
Nextendo stack on a LAN and testing a real (CFW) Switch against it.

Every submodule tracks its repo's `testing` branch:

    git clone --recurse-submodules https://github.com/nx-mod/nextendo-testing
    git submodule update --remote        # move everything to the latest testing

Layout
------

    services/  account, dauth, scsi, nncs, nex, sni-router, baas-jwks,
               dashboard, site, docs, and the nx-mod servers:
               aauth-nx, tagaya-nx, npns-nx, telemetry-nx, bcat-nx,
               eos-nx, gamespy-nx
    games/     demonware (Diablo III), ssbu, acnh, advance-wars,
               borderlands-1, torchlight-2
    console/   prelude (the Switch homebrew), bcat-mitm-nx (bcat module)
    clients/   citron, citron-android, ryujinx, app-android, app-ios

LAN testing only. Keys, certificates and secrets that a server needs to run
are committed on purpose: anyone on the LAN should be able to run the stack.
Never point a production console or server at these keys.

What nx-mod changes in the network
----------------------------------

Console sign-in, fully local (nothing goes to production):
- Nintendo Account side served locally (tokens, users/me, certificates,
  the account-link page; a new e-mail creates its account on first login).
- BaaS answers a real console: camelCase token replies (2124-3121 without),
  device-account login mapped to the console's user, users/<id>, devices
  snapshot, friends/blocks lists; the login idToken carries the signed
  Nextendo identity the game servers check.
- dauth/dragons: rights/available_elicenses answered (online games stopped
  at the licence check without it).
- A local CA for the stack's certificates, trusted by Prelude's browser
  bundles, so the console's browser accepts the stack (account-link page).

New services (nx-mod): aauth (application tokens), tagaya (title version
list), npns (push notifications), telemetry (sink), bcat (delivery cache,
with bcat-mitm-nx on the console), eos (Epic Online Services), gamespy
(Wii/DS Wi-Fi Connection).

Game servers: Diablo III (demonware) plays online on a CFW Switch;
Advance Wars, Borderlands 1 and Torchlight 2 record unhandled NEX methods
on the dashboard for further work.

Status
------

Not every nx-mod change is merged into these testing branches yet; merges
land repo by repo, then this repo is bumped. Games not listed here use
NextendoNetwork's own servers unchanged.
