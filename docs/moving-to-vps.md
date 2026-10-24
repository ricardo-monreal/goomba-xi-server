# Opening Goomba XI to the internet or moving it to a VPS

Goomba XI starts on a home network. Two ways to let players in from outside, from least to most work:

- **A. Keep it at home, forward ports** from your router to the game server VM.
- **B. Move it to a VPS** (any Ubuntu 26.04 virtual server with 4 GB of RAM or more; 8 GB for building).

Either way you will want a domain name (so the launcher isn't tied to an IP address) and HTTPS for the website.

## A. Port forwarding from home

1. Give the game server a fixed LAN address (it already has one if you followed the install guide).
2. On the router, forward these to it: TCP 80, 443, 54001, 54002, 54230, 54231, 51220, 51240 and UDP 54230. Forward TCP 80 on a second public port, or use a subdomain on a different IP, if the file server should be reachable too; or move the client downloads to object storage (step 4 below).
3. Point a domain at your public IP (`A` records for `goomba-xi.example` and `www`), or use a dynamic DNS name if your IP changes.
4. On the game server, set in `/etc/goomba/goomba.conf`:

   ```bash
   GOOMBA_ZONE_IP="<your public IP>"
   GOOMBA_DOMAIN="goomba-xi.example"
   GOOMBA_ACME_EMAIL="you@example.com"
   ```

   then:

   ```bash
   sudo goomba zone-ip <your public IP>
   sudo goomba web-update        # nginx for the domain, Let's Encrypt certificate, new SITE_URL
   ```

5. Players on your own LAN: most routers support "hairpin NAT" (reaching your public IP from inside). If yours doesn't, set `"hairpin": true` in the launcher's `launcher.config.json` and see `src/shared/types.ts` there.
6. Rebuild the launcher for the domain and publish it:

   ```bash
   node tools/configure.mjs --server goomba-xi.example --website https://goomba-xi.example --files https://files.goomba-xi.example
   ```

## B. Moving to a VPS

1. **Install fresh on the VPS** with the normal one-liner. Answer the questions with the VPS's public IP, your file server URL and your domain.
2. **Bring the data over.** On the home server: `sudo goomba backup`. Copy the three newest files from `/opt/goomba/backups` (`xidb-…`, `goomba_web-…`, `etc-goomba-…`) to the VPS's `/opt/goomba/backups`.
3. **On the VPS**, restore both databases:

   ```bash
   sudo goomba restore xidb-<date>.sql.gz
   sudo goomba restore goomba_web-<date>.sql.gz
   ```

   Accounts, characters and website data come across; players sign in to the website and launcher once more because the VPS has its own new secrets. (The `etc-goomba-…` file is there for reference: compare its `goomba.conf` with the new one for any settings you changed.)

4. **Downloads.** Either set up a second small VPS with `install.sh --file-server`, or put `/srv/goomba/files` in object storage (Cloudflare R2 has no egress fees, which matters when every new player downloads 15 GB). Set `GOOMBA_FILES_URL` and rebuild the launcher.
5. **DNS.** Point the domain at the VPS, rebuild and publish the launcher with the new addresses, and post the new download link.
6. **Firewall.** `goomba install` already configured `ufw`. Many VPS providers also have their own firewall in their dashboard: open the same ports there.

## Hardening checklist for a public server

- SSH: keys only (`PasswordAuthentication no` in `/etc/ssh/sshd_config`), or limit it to your IP.
- Keep Ubuntu updated: `sudo apt install unattended-upgrades`.
- The database, the world API (8088) and the website's own port (3000) are bound to localhost by default; keep them that way.
- The website rate-limits sign-in and registration (10 per minute per address, in `nginx/goomba-web.conf`).
- Off-box backups (`BACKUP_REMOTE`) to a machine that isn't the VPS.
