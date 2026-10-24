# Updating Goomba XI

Goomba XI runs LandSandBoat at one pinned commit, `LSB_REF` in `/etc/goomba/goomba.conf`. Nothing changes until you move that pin, so the server never updates itself by surprise. For a preservation server, updating rarely is fine: do it for fixes you want, not on a schedule.

## Updating this repository's settings and modules

```bash
sudo goomba update
```

`update` first pulls this repository, then rebuilds and restarts. If `LSB_REF` didn't change, the build is quick (ccache) and the database step is a no-op.

## Moving to a newer LandSandBoat

1. **Pick a commit.** Look at https://github.com/LandSandBoat/server/commits/base and choose a recent commit whose checks are green. Copy its full hash.
2. **Snapshot the VM** in Proxmox (VM → Snapshots → Take Snapshot). It's the fastest way back.
3. **Set the pin** in `/etc/goomba/goomba.conf`, and in `config/goomba.conf.example` in this repository so the next install uses it too:

   ```bash
   LSB_REF="<new commit hash>"
   ```

4. **Update:**

   ```bash
   sudo goomba update
   ```

   It fetches the new source, re-applies the settings, modules and `patches/`, rebuilds, stops the game, **backs up both databases**, applies new SQL and migrations, and starts the game again. Players are disconnected for the database step only (a minute or two).

5. **Regenerate the era zone patches** from the new checkout (they replace whole lists, so they must match it):

   ```bash
   sudo apt install -y python3-yaml
   cd /opt/goomba-xi-server
   sudo python3 tools/gen-era-zone-patches.py /opt/goomba/server
   sudo goomba apply && sudo goomba restart game
   sudo git add -A modules/goomba_era config/goomba.conf.example
   sudo git commit -m "LandSandBoat <short hash>"
   ```

6. **Check:** `goomba status`, log in, zone a few times. Rebuild the website too (`sudo goomba web-update`) so its game tables (experience, item stats, ferries) come from the new data.

### If the client version changed

LandSandBoat follows the retail client. When `CLIENT_VER` in `/opt/goomba/server/settings/default/login.lua` changes, players' clients must match: patch your Windows client build with PlayOnline, rebuild the client and publish a new manifest (launcher README, step 2) **before** updating the server. Until then you can keep the old value by adding `CLIENT_VER = '<old value>'` to `settings/login.lua`.

### If the launch-token patch doesn't apply

`update` stops with `0001-launch-token-login.patch doesn't apply` when LandSandBoat changed the login code. Nothing has been rebuilt at that point; the running servers keep working.

- **Quick way back:** put `LSB_REF` back to the commit `goomba version` shows and run `sudo goomba update`.
- **Refresh the patch:** the change is small (about 100 lines in `src/login/auth_session.cpp`, `auth_session.h` and `otp_helpers.h`, each marked `[Goomba] Launch token`). In a LandSandBoat checkout at the new commit, make the same edits, then:

  ```bash
  git diff > /opt/goomba-xi-server/patches/0001-launch-token-login.patch
  ```

  Commit it to this repository and run `sudo goomba update` again. If LandSandBoat itself ever adds launch tokens, delete the patch.

### If the build fails

The error is at the end of the output. `sudo goomba build` rebuilds without the other steps. If the new commit simply doesn't build, go back to the previous `LSB_REF` (or restore the Proxmox snapshot) and pick a newer commit later.

### If the database update fails

The backup taken a moment before is in `/opt/goomba/backups`. Restore it with `sudo goomba restore xidb-<date>.sql.gz` after going back to the previous `LSB_REF`.

## Carrying your own source changes

For a one-off C++ or core Lua change, add another numbered file to `patches/` (`0002-my-change.patch`, made with `git diff` in a LandSandBoat checkout). For many changes, fork `LandSandBoat/server`, set `LSB_REPO` to your fork and `LSB_REF` to your branch or commit; the patches still apply on top.

## Updating the website and the launcher

- Website: push to `goomba-xi-web`, then `sudo goomba web-update`.
- Launcher: bump `version` in its `package.json`, tag `v<version>`, and copy the new installers to the file server (launcher README, step 3). Installed launchers keep working; players get the new one from the website.
