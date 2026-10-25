# Installing Goomba XI

This guide takes you from an empty Proxmox host to players logging in on your home network. It has five parts:

1. Create the game server VM (Ubuntu 26.04)
2. Install the game server and website
3. Create the file server LXC (Debian 13) and set it up
4. Build the game client and the launcher, and publish them
5. First account, GM rights and a test login

Plan on an afternoon: most of the time is the server build (20–40 minutes) and copying the game client (about 15 GB).

## Where you are

Tick these off as you go; each line links to its part.

| # | Step | Done when |
| --- | --- | --- |
| 1 | [Game server VM](#part-1-the-game-server-vm) | You can SSH into 10.2.5.64 |
| 2 | [Game server install](#part-2-install-the-game-server) | `goomba status` shows 6 services `active`; `http://10.2.5.64` loads |
| 3 | [File server LXC](#part-3-the-file-server-lxc) | `http://10.2.5.65/launcher/news.json` loads |
| 3b | [Off-box backups](#off-box-backups-recommended) (optional) | `sudo goomba backup` ends with `ok copied to goomba-backup@10.2.5.65:.` |
| 4 | [Client and launcher](client-and-launcher.md) | `http://10.2.5.65/launcher/client/manifest.json` loads; the website's download links work |
| 5 | [First login](#part-5-first-login) | You are in game with GM rights |
| 6 | [Community packs](file-server.md#community-packs-and-addons-maps-xi-view-targetlines) (optional) | Combined Maps, XI View and TargetLines show in the launcher's Addons screen |

## What you need

- A Proxmox VE host with about 4 free cores, 10 GB of free RAM and 200 GB of free disk.
- The **Ubuntu 26.04 Server** ISO uploaded to Proxmox (`local` → ISO Images) and the **Debian 13** container template downloaded (`local` → CT Templates → Templates → `debian-13-standard`).
- Two fixed addresses on your LAN, one for each machine. This guide uses **10.2.5.64** for the game server and **10.2.5.65** for the file server; use your own throughout. Either set them statically or reserve them in your router's DHCP.
- A **Windows PC** with a fully patched retail FINAL FANTASY XI install, used once to build the game client (part 4). Never log in to a Square Enix account with the copy you build from.
- A GitHub account (the repositories are under `ricardo-monreal/`). Everything can also run without GitHub; see [without-github.md](without-github.md).

## Part 1: The game server VM

In the Proxmox web UI, **Create VM**:

| Tab | Setting |
| --- | --- |
| General | Name `goomba-xi`, start at boot ✓ |
| OS | the Ubuntu 26.04 ISO |
| System | Machine `q35`, BIOS `OVMF (UEFI)` with an EFI disk, Qemu Agent ✓ |
| Disks | 60 GB, VirtIO SCSI single, Discard ✓, SSD emulation ✓ if the storage is SSD |
| CPU | 4 cores, type `host` |
| Memory | 8192 MB (the build is the heavy part; 4 GB is enough afterwards) |
| Network | VirtIO, bridge `vmbr0` |

Install Ubuntu Server with the defaults, plus:

- **Network**: set the static address (10.2.5.64/24, your gateway and DNS), or leave DHCP if you reserved the address in the router.
- **Profile**: your admin user.
- **SSH**: install OpenSSH server ✓.

After the first boot, log in and install the guest agent so Proxmox shows the address and can shut the VM down cleanly:

```bash
sudo apt update && sudo apt install -y qemu-guest-agent
```

It starts by itself once the VM has the agent's channel: make sure **Options → QEMU Guest Agent** is *Enabled* in Proxmox, then do a full **Shutdown** and **Start** from Proxmox (a reboot inside Ubuntu keeps the old virtual hardware). Until then `apt` prints "A dependency job for qemu-guest-agent.service failed", which is harmless. Check with `systemctl status qemu-guest-agent`.

## Part 2: Install the game server

On the VM (over SSH):

```bash
curl -fsSLO https://raw.githubusercontent.com/ricardo-monreal/goomba-xi-server/main/install.sh
sudo bash install.sh
```

(Download, then run: piped straight into `sudo bash`, the script can't read your answers. For an unattended install, pipe it with the answers instead: `curl -fsSL <url>/install.sh | sudo bash -s -- --ip 10.2.5.64 --files http://10.2.5.65`.)

It asks three questions. Press Enter to accept a suggestion:

| Question | Answer |
| --- | --- |
| Address players connect to | this VM's address, `10.2.5.64` |
| File server URL | `http://10.2.5.65` (part 3 creates it) |
| Domain name | leave empty on a home network |

Then it runs by itself: packages, MariaDB, the LandSandBoat build, the database, services, firewall, nginx and the website. When it prints **Goomba XI is installed**, check:

```bash
goomba status
```

All six services should be `active`. Open `http://10.2.5.64` in a browser: the website should load.

> Your answers are in `/etc/goomba/goomba.conf`. Everything in that file is explained by the comments inside it. If you got an address wrong: `sudo goomba zone-ip <address>` fixes the game address; for anything else edit the file and run `sudo goomba web-update`.

## Part 3: The file server LXC

The file server hosts the game client, the launcher installers, optional addons and HD packs, item icons for the website, and a copy of every backup.

### Create the container

In the Proxmox UI, **Create CT**:

| Tab | Setting |
| --- | --- |
| General | Hostname `goomba-files`, unprivileged ✓, a root password or your SSH key |
| Template | `debian-13-standard` |
| Disks | root disk 8 GB; **Add** a mount point: 150 GB, path `/srv/goomba` (holds the client and backups) |
| CPU | 2 cores |
| Memory | 1024 MB, swap 512 MB |
| Network | bridge `vmbr0`, IPv4 static `10.2.5.65/24` and your gateway |
| DNS | your router or `1.1.1.1` |

Start it at boot (Options → Start at boot ✓) and start it.

Or from the Proxmox host's shell (adjust the storage names to yours):

```bash
pveam list local | grep debian-13        # the exact template file name
pct create 151 local:vztmpl/debian-13-standard_<version>_amd64.tar.zst \
  --hostname goomba-files --unprivileged 1 --cores 2 --memory 1024 --swap 512 \
  --rootfs local-lvm:8 --mp0 local-lvm:150,mp=/srv/goomba \
  --net0 name=eth0,bridge=vmbr0,ip=10.2.5.65/24,gw=10.2.5.1 \
  --onboot 1 --start 1
```

### Set it up

Open the container's console (or `pct enter 151` on the host) and run:

```bash
apt update && apt install -y curl sudo
adduser goomba-admin          # the account you upload files with (scp/SFTP)
curl -fsSL https://raw.githubusercontent.com/ricardo-monreal/goomba-xi-server/main/install.sh | bash -s -- --file-server --owner goomba-admin --website http://10.2.5.64
```

It installs nginx and SSH, creates the folders under `/srv/goomba/files` (owned by `goomba-admin`), and serves them on `http://10.2.5.65`. Check from any PC: `http://10.2.5.65/launcher/news.json` shows a welcome message.

### Off-box backups (recommended)

The game server already dumps both databases to its own disk every night at 04:30 (`/opt/goomba/backups`). This one-time setup adds a second copy on the file server, so a broken VM disk can't take the backups with it. It lets the game server send files to the LXC over SSH without a password, using a key that can do only one thing: copy files into `/srv/goomba/backups/data` on the LXC.

Do it once both machines are installed (the file server setup puts the helper script on the LXC).

**1. On the game server (10.2.5.64): get the key and the command.**

```bash
cd /opt/goomba-xi-server && sudo git pull
sudo goomba backup-key
```

It prints something like:

```
Authorize this key for the backup user on the file server. On the Debian LXC run:

  sudo bash /opt/goomba-xi-server/tools/setup-file-server.sh --backup-key 'ssh-ed25519 AAAAC3Nz...xyz goomba-backup@goomba-xi'
```

Copy the whole `sudo bash … --backup-key '…'` line, with the quotes and the long key intact.

**2. On the file server (10.2.5.65): authorize the key.** In the LXC's console (Proxmox, or `pct enter <id>` on the host), paste the line and run it. It ends with:

```
  authorized. On the game server set in /etc/goomba/goomba.conf:
    BACKUP_REMOTE="goomba-backup@10.2.5.65:."
```

The `:.` at the end is correct: that key only sees the backups folder. (The script remembers the options from the first run, so `--owner` and `--website` don't need repeating.)

**3. On the game server: turn on the copy.**

```bash
sudo nano /etc/goomba/goomba.conf
```

Change the last line, `BACKUP_REMOTE=""`, to:

```
BACKUP_REMOTE="goomba-backup@10.2.5.65:."
```

Save with Ctrl+O, Enter, then exit with Ctrl+X.

**4. Test it.**

```bash
sudo goomba backup
```

The last line should be `ok copied to goomba-backup@10.2.5.65:.`, and on the file server `ls /srv/goomba/backups/data` lists the same `xidb-…`, `goomba_web-…` and `etc-goomba-…` files. From then on every backup (nightly, and the ones `goomba update` and `goomba restore` take) is copied there automatically, and old copies are pruned there too.

If it ends with `could not copy backups` instead:

| Cause | Check |
| --- | --- |
| The key wasn't authorized | Redo step 2, pasting the whole line |
| The LXC isn't reachable on SSH | `ssh goomba-backup@10.2.5.65` from the game server should answer (and then refuse a normal login); a timeout means the LXC is off or port 22 is blocked |
| Typo in `BACKUP_REMOTE` | It must be exactly `goomba-backup@10.2.5.65:.` |

## Part 4: The game client and the launcher

Players install one program, the **Goomba XI launcher**, which downloads the game from the file server and signs them in. You build the game client once on a Windows PC and let GitHub build the launcher. It has its own step-by-step page: **[client-and-launcher.md](client-and-launcher.md)**.

## Part 5: First login

1. Open `http://10.2.5.64/register` and create your account (it agrees to the rules page; edit the rules in the website repository's `src/app/rules/page.tsx`).
2. Install the launcher from the website's **Getting Started** page, press **Install**, then sign in with the same username and password.
3. Press **Play** and create a character.
4. Give yourself GM rights, then zone or log out and back in:

   ```bash
   sudo goomba gm <your account> 5
   ```

Players on your network do the same: register on the website, install the launcher, play.

## If something doesn't work

| Symptom | Check |
| --- | --- |
| `goomba status` shows a service `failed` | `sudo goomba status` prints its last log lines. Most often the database login: `sudo goomba db-update`. |
| The launcher says it can't reach the server | The launcher was built with the wrong address: `node tools/configure.mjs --show` in the launcher repository, then rebuild. |
| Login works, character list loads, then the game hangs at "Downloading data" | The zone IP: `sudo goomba zone-ip` should show the game server's LAN address. Fix with `sudo goomba zone-ip 10.2.5.64`. |
| "Install" in the launcher fails | The client isn't on the file server yet: `http://10.2.5.65/launcher/client/manifest.json` must open. |
| Website shows placeholder item icons | Item names and icons are imported once; see the website README, "Item names and icons". |
| The install stopped half-way | Fix what the error says and run `sudo goomba install` again; finished steps are skipped. |
| The installer shows a question and pressing Enter does nothing | It was piped into `sudo bash`, which can't read your keys. Ctrl+C, then `cd /opt/goomba-xi-server && sudo git pull && sudo bash bin/goomba install`. The half-written config from the first try is completed, not lost. |
| `bash: /opt/goomba-xi-server/bin/goomba: Permission denied` | An old copy of the repository: `cd /opt/goomba-xi-server && sudo git pull`, then `sudo bash bin/goomba install`. |
| `apt` says "A dependency job for qemu-guest-agent.service failed" | Harmless. Enable **Options → QEMU Guest Agent** for the VM in Proxmox, then Shutdown and Start it from Proxmox (part 1). |

Next: [operations.md](operations.md) for day-to-day running.
