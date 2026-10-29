# Goomba XI — server

Everything needed to run the **Goomba XI** FINAL FANTASY XI preservation server and its website on one Ubuntu 26.04 machine, plus the scripts for the separate file server.

Goomba XI runs upstream [LandSandBoat](https://github.com/LandSandBoat/server): a Level 75 era server (the original game, Rise of the Zilart, Chains of Promathia and Treasures of Aht Urhgan) with LandSandBoat's era-accuracy modules turned on. This repository holds only what Goomba XI adds on top, plus the scripts that install and run it:

| Path | What it is |
| --- | --- |
| `install.sh` | One-line installer for the game server (Ubuntu 26.04) or the file server (Debian 13). |
| `bin/goomba` | Install, update, build, start/stop, backups and restore, GM levels. |
| `settings/*.lua` | Goomba XI's setting overrides (era, level cap, rates, trusts, chat audit for the website). Anything not listed keeps LandSandBoat's default. |
| `modules/goomba/` | Goomba XI's Lua modules (solo-friendly trusts, Trust Liaison NPC, welcome message) and the launch-token table. |
| `modules/goomba_era/` | Era fixes LandSandBoat still has as broken SQL, applied as zone patches. |
| `patches/` | The one source change: launch-token sign-in for the launcher (from the Phoenix fork). |
| `systemd/`, `nginx/` | One service per game server grouped by `goomba-game.target`, the website, nightly backups; the website's reverse proxy. |
| `config/goomba.conf.example` | Addresses, pinned LandSandBoat commit, era modules, backups. |
| `tools/` | File server setup, Git mirror, era patch generator. |
| `docs/` | Install, gameplay features, operations, updating, file server, client and launcher, moving to a VPS, running without GitHub. Also published as an offline HTML site in `docs-site/`. |

The LandSandBoat source is not copied into this repository. `goomba install` clones it into `/opt/goomba/server` at the commit pinned in `LSB_REF`, so moving to a newer LandSandBoat is a one-line change followed by `goomba update`.

## What runs where

```
 Proxmox
 ├─ Ubuntu 26.04 VM  (game + web, e.g. 10.2.5.64)
 │    nginx :80 ──► website (Next.js :3000)        xi_connect  54001 54230 54231
 │                    │                            xi_search   54002
 │                    └──── MariaDB (localhost) ── xi_map      54230/udp
 │                          xidb + goomba_web      xi_world    (HTTP API :8088, localhost)
 │                                                 xi_profile  51220 51240
 │
 └─ Debian 13 LXC    (files, e.g. 10.2.5.65)
      nginx :80 ──► /srv/goomba/files   game client, launcher installers, addons, HD packs, item icons
      ssh         ► /srv/goomba/backups nightly copies of the game server's backups
```

The website and the game share the `xidb` database: website accounts *are* game accounts. The launcher signs in through the website, which mints a single-use **launch token** for xiloader, so no password is handed to the game client.

## Install

Full walkthrough, including creating the VM and the LXC in Proxmox: **[docs/install.md](docs/install.md)**.

On a fresh Ubuntu 26.04 VM (4 cores and 8 GB RAM is comfortable for the build):

```bash
curl -fsSLO https://raw.githubusercontent.com/ricardo-monreal/goomba-xi-server/main/install.sh
sudo bash install.sh
```

It asks three questions (the server's LAN address, the file server's URL, an optional domain), then installs packages, MariaDB, builds LandSandBoat (20–40 minutes the first time), creates the databases, services, firewall, nginx and the website. Safe to run again: each step skips what is already done.

On a fresh Debian 13 LXC, for the file server:

```bash
curl -fsSL https://raw.githubusercontent.com/ricardo-monreal/goomba-xi-server/main/install.sh | sudo bash -s -- --file-server --website http://10.2.5.64
```

When both are up:

1. Open `http://<server address>/register` and create your account.
2. Build the game client and the launcher: [docs/client-and-launcher.md](docs/client-and-launcher.md), step by step. Then sign in and create a character.
3. Give it GM rights: `sudo goomba gm <your account> 5`.

Secrets are generated during install and live only on the server: `/etc/goomba/server.env` (game database login) and `/etc/goomba/web.env` (website database login, session secret, optional SMTP for password-reset mail).

## Documentation

The full docs — install, gameplay features, operations, updating, the file server, the client and launcher, moving to a VPS, GM commands, zone IDs and NM IDs — are in [`docs/`](docs/) and are also published as a self-contained **offline HTML site** in [`docs-site/`](docs-site/) (open `docs-site/index.html` in any browser). On a running server they are served at `http://<server>/docs/`.

Rebuild the site after editing a doc, or to refresh the reference lists for a new LandSandBoat version:

```bash
sudo goomba docs                 # on the game server: regenerates the reference lists and the site
# or, from the repository, with Node:
node tools/gen-reference-docs.mjs   # GM commands, zones, NMs from /opt/goomba/server
node tools/build-docs.mjs           # docs/*.md -> docs-site/
```

## Day to day

```bash
goomba status                      # services, players online, last backup
goomba logs map                    # follow a server's log (world, connect, search, map, profile, web)
sudo goomba restart game           # or web, or all
sudo goomba backup                 # also runs every night at 04:30; keeps 14 days
sudo goomba restore                # lists backups; restore one with: sudo goomba restore <file>
```

More in **[docs/operations.md](docs/operations.md)**: changing settings, GM commands, backups to the file server, changing addresses.

### Changing settings

Edit `settings/*.lua` in this repository (commit it so it isn't lost), then:

```bash
sudo goomba apply && sudo goomba restart game
```

Any key from LandSandBoat's `settings/default/*.lua` can be added to the matching file here.

### Updating

```bash
sudo goomba update        # LandSandBoat at LSB_REF: backup, rebuild, database update, restart
sudo goomba web-update    # the website
```

Moving to a newer LandSandBoat commit, and what to do if the launch-token patch no longer applies: **[docs/updating.md](docs/updating.md)**.

## Ports

| Port | Protocol | Used by |
| --- | --- | --- |
| 80 (443 with a domain) | TCP | Website (nginx) |
| 54231 | TCP | Login (auth): launcher and xiloader |
| 54230 | TCP | Login (data) |
| 54001 | TCP | Login (view) |
| 54230 | UDP | Map server (gameplay) |
| 54002 | TCP | Search (`/sea`, auction house lists) |
| 51220 | TCP | Profile server |
| 51240 | TCP | Profile server (PlayOnline IRC) |
| 3306, 8088, 3000 | TCP | MariaDB, world HTTP API, website: **localhost only** |

`goomba install` opens exactly these with `ufw` (plus SSH). On a home network nothing else is needed; for players outside it see [docs/moving-to-vps.md](docs/moving-to-vps.md).

## Era and rates

Goomba XI matches the Era-DATs the launcher ships: the original game through Treasures of Aht Urhgan, Level 75 cap unlocked through Maat's quests, and later systems (Records of Eminence, Field/Grounds manuals, home point teleports, Mog Garden, …) turned off. See `settings/main.lua` and `GOOMBA_ERA_MODULES`.

It is meant to be playable solo or in a small group: trusts are on, up to five at once under retail's zone and battlefield rules (`modules/goomba/lua/solo_trusts.lua`), the Trust Liaison in Lower Jeuno sells 102 more for conquest points (Geomancer, Rune Fencer, Dancer and Scholar trusts are blocked), EXP, skill-up, crafting and fishing skill-up rates are raised and fishing is on (`settings/main.lua`, `settings/map.lua`). An optional Auction House bot keeps the AH stocked and buys what players list: `sudo goomba ahbot on` ([docs/auction-house.md](docs/auction-house.md)).

## Without GitHub

Goomba XI can be installed, updated and built entirely from your own machines: a Git mirror on the file server (`tools/git-mirror.sh`), `GIT_MIRROR` in `goomba.conf`, local launcher and xiloader builds, and the Linux runtime hosted on the file server. See [docs/without-github.md](docs/without-github.md).

## Credits and license

Built on [LandSandBoat](https://github.com/LandSandBoat/server). The launch-token sign-in, Era-DATs and xiloader come from the [Phoenix](https://github.com/phoenixffxi) project. Based on the Bahamut XI server scripts.

The scripts and settings in this repository are released under the GNU GPL v3, the same license as LandSandBoat. FINAL FANTASY XI is a registered trademark of Square Enix Holdings Co., Ltd.; Goomba XI is not affiliated with or endorsed by Square Enix.
