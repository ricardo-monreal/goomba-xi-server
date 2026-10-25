# The file server

Downloads come from a separate machine so big transfers never compete with the game. For Goomba XI that is a **Debian 13 LXC** on the same Proxmox host, set up by `tools/setup-file-server.sh` ([install.md](install.md), part 3). Any static web host works the same way later (nginx on a VPS, or object storage such as Cloudflare R2 or Backblaze B2 behind a CDN).

## Layout

```
/srv/goomba/
  files/                              served at http://<file server>/
    launcher/
      GoombaXI-Setup.exe              latest Windows launcher (fixed name; the website links to it)
      GoombaXI.AppImage               latest Linux launcher
      releases/                       older launcher versions, kept for reference
      news.json                       launcher news
      client/manifest.json            game client manifest   } from tools/make-manifest.mjs
      client/files/ab/abcdef….gz      game client blobs      } in the launcher repository
      addons.json, addons/*.zip       optional addons and plugins   } from tools/make-catalogs.mjs
      pivot.json,  packs/*.zip        optional HD packs (XIPivot)   }
      runtime/                        optional: GE-Proton, umu, winetricks for Linux players
    icons/
      items/<id>.png                  item icons for the website (website: scripts/import-items.mjs)
  backups/data/                       copies of the game server's backups (BACKUP_REMOTE)
/srv/git/                             optional Git mirror (tools/git-mirror.sh)
```

The paths match `launcher.config.json` in the launcher repository and `GOOMBA_FILES_URL` on the game server. Size: about 15 GB for the client, plus whatever HD packs you host, plus backups (a few MB a day).

## The setup script

```bash
sudo /opt/goomba-xi-server/tools/setup-file-server.sh [--website URL] [--owner USER] [--backup-key 'KEY'] [--git-mirror]
```

| Option | Meaning |
| --- | --- |
| `--website` | The website's URL; it is allowed to load item icons and JSON from here (CORS). |
| `--owner` | The user who uploads files (owns `/srv/goomba/files`). |
| `--backup-key` | Authorizes the game server's backup key (`sudo goomba backup-key` on the game server prints the full command). The key can only run rsync inside `/srv/goomba/backups/data`. |
| `--git-mirror` | Also serves `/srv/git` read-only at `/git/` (see [without-github.md](without-github.md)). |

Options are remembered in `/etc/goomba/files.conf`, so running it again later (to add a key, or after a Debian upgrade) only needs the options that change. The nginx site is `/etc/nginx/sites-available/goomba-files.conf`; re-run the script instead of editing it.

What nginx does: client blobs are cached forever (they are content-addressed and never change), JSON files are always revalidated, and range requests let the launcher resume interrupted downloads.

## Publishing order

Upload files before the files that point at them, so players never see a manifest whose files aren't there yet:

1. `client/files/…`, then `client/manifest.json`
2. `addons/*.zip`, `packs/*.zip`, then `addons.json`, `pivot.json`
3. A new launcher: keep the versioned file in `releases/`, then copy it over the fixed name

From the PC that built the client:

```bash
rsync -av publish/files/ goomba-admin@10.2.5.65:/srv/goomba/files/launcher/client/files/
rsync -av publish/manifest.json goomba-admin@10.2.5.65:/srv/goomba/files/launcher/client/
```

On Windows without rsync, `scp -r` works the same way (or WinSCP).

## Launcher news

`launcher/news.json` is a list of posts shown on the launcher's Home tab:

```json
[
  { "title": "Harvest Festival", "date": "Oct 31, 2026", "body": "Pumpkins have appeared in all three nations.", "url": "http://10.2.5.64/blog/harvest-festival" }
]
```

Edit it in place; launchers pick it up on their next start.

## Storage and backups of the LXC

The `/srv/goomba` mount point is a separate Proxmox volume, so the container's root disk stays small. Include the LXC in a Proxmox backup job (Datacenter → Backup) if you want the client and backups copied off the host too; the client can always be rebuilt, the database backups cannot.
