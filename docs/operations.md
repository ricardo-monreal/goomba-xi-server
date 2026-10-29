# Running Goomba XI day to day

Everything is done with the `goomba` command on the game server. Commands that change something need `sudo`.

## The commands

| Command | What it does |
| --- | --- |
| `goomba status` | Services, players online, website address, LandSandBoat commit, last backup. With `sudo`, also the last log lines of anything that failed. |
| `goomba logs <server>` | Follow a log: `world`, `connect` (login), `search`, `map`, `profile`, `web`. Ctrl+C to stop. |
| `sudo goomba start\|stop\|restart [game\|web\|all]` | Control the game servers, the website, or both (default: all). |
| `sudo goomba backup` | Dump both databases now (also nightly at 04:30). |
| `sudo goomba restore [file]` | Without a file: list recent backups. With one: stop everything, back up what is there now, load the backup, start again. |
| `sudo goomba apply` | Copy `settings/` and `modules/` from this repository into the server. Follow with `restart game`. |
| `sudo goomba gm <account> <0-5>` | Set the GM level of every character on an account. Takes effect at the next zone or login. |
| `sudo goomba zone-ip [address\|auto]` | Show or change the address game clients are sent to after login. |
| `sudo goomba update` | Update LandSandBoat to `LSB_REF` (see [updating.md](updating.md)). |
| `sudo goomba web-update` | Update and rebuild the website. |
| `sudo goomba build` / `db-update` | Just rebuild the servers / just apply database updates. |
| `sudo goomba backup-key` | Show the SSH key for copying backups to the file server. |
| `sudo goomba ahbot on\|off\|refresh\|clear\|status` | The Auction House bot for solo play: [auction-house.md](auction-house.md). |
| `sudo goomba web-items` | Import item names, descriptions and icons for the website (item browser, equipment). Runs once during install; run again after an Era-DATs update. |
| `sudo goomba docs` | Rebuild the offline docs site and the GM-command / zone / NM reference lists from this server (served at `/docs/`). |
| `goomba version` | The exact commits running. |

## Files and folders

| Path | What |
| --- | --- |
| `/opt/goomba-xi-server` | This repository (settings, modules, scripts). Edit here, then `sudo goomba apply`. |
| `/etc/goomba/goomba.conf` | Addresses, LandSandBoat commit, era modules, backups. |
| `/etc/goomba/server.env`, `web.env` | Generated secrets (database passwords, session secret, SMTP). |
| `/opt/goomba/server` | LandSandBoat checkout and the built servers. Don't edit: `update` resets it. |
| `/opt/goomba/web` | The website checkout. |
| `/opt/goomba/backups` | Database dumps (`xidb-…`, `goomba_web-…`) and a copy of `/etc/goomba` (`etc-goomba-…`). |

## Changing game settings

Settings are in `settings/main.lua`, `map.lua`, `login.lua` and `network.lua` in this repository. Only the keys Goomba XI changes are listed; any key from `/opt/goomba/server/settings/default/*.lua` can be added to the matching file.

```bash
cd /opt/goomba-xi-server
sudo nano settings/main.lua            # e.g. EXP_RATE, MAX_LEVEL, START_GIL
sudo goomba apply && sudo goomba restart game
sudo git commit -am "Raise EXP rate"   # keep the change with the repository
```

Some common ones:

| Setting | File | Goomba XI value |
| --- | --- | --- |
| `EXP_RATE` | `main.lua` and `map.lua` (keep equal) | 3.0 |
| `SKILLUP_AMOUNT_MULTIPLIER` | `map.lua` | 2 |
| `CRAFT_CHANCE_MULTIPLIER` | `map.lua` | 2.0 |
| `FISHING_ENABLE`, `FISHING_SKILL_MULTIPLIER` | `map.lua` | true, 2.0 |
| `INITIAL_LEVEL_CAP`, `MAX_LEVEL` | `main.lua` | 50, 75 |
| `ENABLE_TRUST_CASTING` | `main.lua` | 1 (limits in `modules/goomba/lua/solo_trusts.lua`) |
| `ENABLE_<EXPANSION>` | `main.lua` | through ToAU on; keep `GOOMBA_ERA_MODULES` in step |

A tour of everything Goomba XI changes from stock LandSandBoat, and where, is in [features.md](features.md). Lua modules (`modules/goomba/lua/*.lua`) change behaviour beyond settings; see `modules/goomba/README.md`.

## GM commands

Give yourself level 5 with `sudo goomba gm <account> 5`. In game, commands start with `!`, for example `!pos`, `!zone`, `!additem`, `!setmod`, `!exec`. The full list is in `/opt/goomba/server/scripts/commands/`; each file starts with its permission level and usage.

## Backups

- **When:** every night at 04:30 (`goomba-backup.timer`), before every `goomba update` and before every `goomba restore`.
- **What:** both databases (`xidb` is the game, `goomba_web` the website) plus a copy of `/etc/goomba`.
- **Kept:** 14 days (`BACKUP_KEEP_DAYS`).
- **Off the box:** when `BACKUP_REMOTE` is set (for example `goomba-backup@10.2.5.65:.`), every backup is also copied to `/srv/goomba/backups/data` on the file server. One-time setup: [install.md](install.md), part 3, "Off-box backups". Every `sudo goomba backup` ends with `ok copied to …` when it works, or `could not copy backups` with the reason.

To bring the server back on a new machine:

1. Copy the backup files to the new Ubuntu 26.04 machine and unpack the settings first, so the install reuses them (same addresses, same secrets, everyone stays signed in):

   ```bash
   sudo tar -xzf etc-goomba-<date>.tar.gz -C /
   ```

2. Install as normal (`install.sh`); it asks no questions because `/etc/goomba/goomba.conf` exists.
3. Copy the `.sql.gz` files to `/opt/goomba/backups` and restore both:

   ```bash
   sudo goomba restore xidb-<date>.sql.gz
   sudo goomba restore goomba_web-<date>.sql.gz
   ```

Snapshots: Proxmox snapshots or `vzdump` backups of the VM and the LXC are a good second layer (Datacenter → Backup). Take a snapshot before a LandSandBoat update.

## Changing addresses

| Change | Do |
| --- | --- |
| The game server's IP | `sudo goomba zone-ip <new address>`. Without a domain, the website moves with it. Rebuild the launcher with the new address. |
| The file server's URL | Edit `GOOMBA_FILES_URL` in `/etc/goomba/goomba.conf`, `sudo goomba web-update`, rebuild the launcher. |
| Add a domain (and HTTPS) | Set `GOOMBA_DOMAIN` and `GOOMBA_ACME_EMAIL`, `sudo goomba web-update`. See [moving-to-vps.md](moving-to-vps.md). |

## Password-reset e-mail

Without mail settings, reset links are written to the website log (`goomba logs web`) and an admin can pass them on. To send them, set `SMTP_URL` (for example `smtps://user:password@smtp.example.com:465`) and `MAIL_FROM` in `/etc/goomba/web.env`, then `sudo goomba restart web`.

## Website content

News posts, rules, FAQ and the approved addons list live in the [website repository](https://github.com/ricardo-monreal/goomba-xi-web) (`content/blog/*.md`, `src/app/rules/page.tsx`, `src/data/approved-addons.txt`). Commit and push, then `sudo goomba web-update`. Launcher news is `launcher/news.json` on the file server.
