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

## Community packs and addons (maps, XI View, TargetLines, MobDB)

The launcher's **Addons** screen offers optional extras from the file server: **Pivot** packs that replace game graphics without touching game files (each category is pick-one), and **Catalog** addons from the approved list. One script builds these community ones straight from their GitHub repositories and publishes the catalogs:

| Extra | From | Shown in the launcher as |
| --- | --- | --- |
| Combined maps, 1024x1024 | [CriticalXI/XICombinedMaps](https://github.com/CriticalXI/XICombinedMaps) | Pivot → Maps → **Combined Maps: Basic** |
| Combined maps, 2048x2048 | same | Pivot → Maps → **Combined Maps: HD** |
| XI View UI, standard | [KenshiDRK/XiView](https://github.com/KenshiDRK/XiView) | Pivot → UI → **XI View: Standard** |
| XI View UI, widescreen | same | Pivot → UI → **XI View: Widescreen** |
| TargetLines addon | [Jyouya/targetlines](https://github.com/Jyouya/targetlines) | Catalog → **TargetLines** |
| MobDB addon | [ThornyFFXI/mobdb](https://github.com/ThornyFFXI/mobdb) | Catalog → **MobDB** |

**Where: the file server (10.2.5.65), as root** — in the LXC's console in Proxmox, or `pct enter <id>` on the Proxmox host. Not on the game server: there the script stops with "This is the game server".

```bash
cd /opt/goomba-xi-server && git pull
bash tools/community-packs.sh --base-url http://10.2.5.65
```

The first run downloads about 2.3 GB (the maps) and takes a while to zip them; it ends with **Done.** and these files:

```
/srv/goomba/files/launcher/
  packs/combined-maps-basic-<date>.zip     ~250 MB
  packs/combined-maps-hd-<date>.zip        ~800 MB
  packs/xiview-standard-<date>.zip         ~3 MB
  packs/xiview-widescreen-<date>.zip       ~3 MB
  addons/targetlines-<version>.zip
  addons/mobdb-<version>.zip
  pivot.json, addons.json                  the catalogs the launcher reads
```

Check `http://10.2.5.65/launcher/pivot.json` in a browser. Launchers see the new entries the next time the Addons screen opens; nothing needs rebuilding.

Run the script again whenever you want the latest versions: it updates the repositories, rebuilds only what changed, and moves old zips to `packs/old/` and `addons/old/`.

Notes:

- The script also lists the other entries in the launcher's `file-server/catalog-sources.json` (NextHD, NextLore, Normal Maps - Labeled, …). Their zips aren't built by it, so it reports them as missing and leaves them out; put such a zip in `packs/` under the name the sources file gives and run the script again to offer it.
- None of these packs touch the Era-DATs (no shared files), so they combine safely with the era text.
- These are other people's work, credited in the launcher with links to their pages. They're shared freely by their authors; ask before hosting them anywhere public.
- To give every player TargetLines by default, add `"targetlines"` to `defaultAddons` in the launcher's `launcher.config.json` and publish a new launcher.

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
