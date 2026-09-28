# TODO — Nextendo network

Network side only; each server repo keeps its own `TODO.md` (games too).

## In progress

- **Linking an offline user (2124-3121)**: baas-jwks now keeps what the console PATCHes into a user; retest.
- **News "failed to load channel information"**: `nextendo_bcat_sig` now patches all four bcat signature checks;
  reboot and retest Find channels.
- **Half-linked users (2002-0001 on delete)**: nextendo-nx Users → Unlink, reboot, delete; retest.

## Can't fix (for now)

- **Test Connection 2160-6000**: the check needs Nintendo's real certificates. Cosmetic; the console stays online.
- **BCAT key swap crashes bcat on 22.5.0**: replaced by the `nextendo_bcat_sig` patch, redone per firmware.

## Services

- **bcat-nx**: push new news to consoles (penne) instead of waiting for their scheduled check; opening a channel
  (qlaunch `online_archives` format); game BCAT data (`nx_data_*`); per-game channels.
- **penne (push)**: frontline protocol (capturing now), then push to consoles; own server and repo `penne-nx`
  (npns-nx removed: NPNS is gone since firmware 18).
- **baas-jwks**: test importing a new account; auto-add consoles linked on production.
- **nnaccount-nx**: sign-in page look; password reset; account settings.
- **sni-router**: no eShop server (eShop hosts dropped).

## Console

- **nextendo-nx**: install/remove `nextendo_bcat_sig` per mode; drop unused `account_link`; commit news buttons.
- **HOME menu crash 2168-0002** after a network stall: keep every service answering.

## Clients and stack

- **Citron testing-android**: 41 commits behind upstream (merge conflicts).
- **Friends and presence** between consoles and Citron: untested.
- **Hotspot switches itself off** when idle: turn off Mobile hotspot → Power saving.
- **ZeroTier**: after LAN; stays on the `zerotier` branches until then.
- **Production branch**: holds its keys back; makes its own with `gen_keys.ps1`.

## Credits

- [kinnay/NintendoClients wiki](https://github.com/kinnay/NintendoClients/wiki) and [CrustySean/BCAT-Toolbox](https://github.com/CrustySean/BCAT-Toolbox) — protocol references.
- The whole Nextendo Network team — https://nextendo.network. Nextendo is awesome.
