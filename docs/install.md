# Installing Goomba XI

This guide takes you from an empty Proxmox host to players logging in on your home network. It has five parts:

1. Create the game server VM (Ubuntu 26.04)
2. Install the game server and website
3. Create the file server LXC (Debian 13) and set it up
4. Build the game client and the launcher, and publish them
5. First account, GM rights and a test login

Plan on an afternoon: most of the time is the server build (20–40 minutes) and copying the game client (about 15 GB).

## What you need

- A Proxmox VE host with about 4 free cores, 10 GB of free RAM and 200 GB of free disk.
- The **Ubuntu 26.04 Server** ISO uploaded to Proxmox (`local` → ISO Images) and the **Debian 13** container template downloaded (`local` → CT Templates → Templates → `debian-13-standard`).
- Two fixed addresses on your LAN, one for each machine. This guide uses **192.168.1.50** for the game server and **192.168.1.51** for the file server; use your own throughout. Either set them statically or reserve them in your router's DHCP.
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

- **Network**: set the static address (192.168.1.50/24, your gateway and DNS), or leave DHCP if you reserved the address in the router.
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
curl -fsSL https://raw.githubusercontent.com/ricardo-monreal/goomba-xi-server/main/install.sh | sudo bash
```

It asks three questions. Press Enter to accept a suggestion:

| Question | Answer |
| --- | --- |
| Address players connect to | this VM's address, `192.168.1.50` |
| File server URL | `http://192.168.1.51` (part 3 creates it) |
| Domain name | leave empty on a home network |

Then it runs by itself: packages, MariaDB, the LandSandBoat build, the database, services, firewall, nginx and the website. When it prints **Goomba XI is installed**, check:

```bash
goomba status
```

All six services should be `active`. Open `http://192.168.1.50` in a browser: the website should load.

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
| Network | bridge `vmbr0`, IPv4 static `192.168.1.51/24` and your gateway |
| DNS | your router or `1.1.1.1` |

Start it at boot (Options → Start at boot ✓) and start it.

Or from the Proxmox host's shell (adjust the storage names to yours):

```bash
pveam list local | grep debian-13        # the exact template file name
pct create 151 local:vztmpl/debian-13-standard_<version>_amd64.tar.zst \
  --hostname goomba-files --unprivileged 1 --cores 2 --memory 1024 --swap 512 \
  --rootfs local-lvm:8 --mp0 local-lvm:150,mp=/srv/goomba \
  --net0 name=eth0,bridge=vmbr0,ip=192.168.1.51/24,gw=192.168.1.1 \
  --onboot 1 --start 1
```

### Set it up

Open the container's console (or `pct enter 151` on the host) and run:

```bash
apt update && apt install -y curl sudo
adduser goomba-admin          # the account you upload files with (scp/SFTP)
curl -fsSL https://raw.githubusercontent.com/ricardo-monreal/goomba-xi-server/main/install.sh | bash -s -- --file-server --owner goomba-admin --website http://192.168.1.50
```

It installs nginx and SSH, creates the folders under `/srv/goomba/files` (owned by `goomba-admin`), and serves them on `http://192.168.1.51`. Check from any PC: `http://192.168.1.51/launcher/news.json` shows a welcome message.

### Off-box backups (recommended)

The game server backs up both databases every night at 04:30. To keep a copy on the file server as well, on the **game server**:

```bash
sudo goomba backup-key
```

It prints a command. Run that command on the **file server** (it authorizes the key, limited to copying backups), then put the `BACKUP_REMOTE=...` line it prints into `/etc/goomba/goomba.conf` on the game server and test:

```bash
sudo goomba backup        # ends with: ok copied to goomba-backup@192.168.1.51:.
```

From then on every backup, nightly or manual, is copied to `/srv/goomba/backups/data` on the file server.

## Part 4: The game client and the launcher

Players install one program, the **Goomba XI launcher**, which downloads the game from your file server, keeps it updated and signs them in. You build two things, both described step by step in the [launcher README](https://github.com/ricardo-monreal/goomba-xi-launcher#readme):

1. **The game client** (once, and again only when the game data changes): on the Windows PC, `tools/build-client.mjs` packs FFXI, PlayOnline, Ashita, xiloader and the Era-DATs into one folder, and `tools/make-manifest.mjs` turns it into a manifest plus compressed files. Copy the result to the file server:

   ```powershell
   scp -r .\publish\files goomba-admin@192.168.1.51:/srv/goomba/files/launcher/client/
   scp .\publish\manifest.json goomba-admin@192.168.1.51:/srv/goomba/files/launcher/client/
   ```

2. **The launcher** (Windows installer and Linux AppImage): point it at your servers, then build it:

   ```bash
   node tools/configure.mjs --server 192.168.1.50 --files http://192.168.1.51
   git commit -am "Point the launcher at my servers" && git tag v1.0.0 && git push origin main v1.0.0
   ```

   The tag starts the GitHub **release** workflow, which builds `GoombaXI-Setup-1.0.0.exe` and `GoombaXI-1.0.0-x86_64.AppImage`. Download them from the release and copy them to the file server under fixed names, so the website's download buttons always get the latest:

   ```bash
   scp GoombaXI-Setup-1.0.0.exe goomba-admin@192.168.1.51:/srv/goomba/files/launcher/GoombaXI-Setup.exe
   scp GoombaXI-1.0.0-x86_64.AppImage goomba-admin@192.168.1.51:/srv/goomba/files/launcher/GoombaXI.AppImage
   ```

   (Local builds work too: `npm run dist` on Windows, `npm run dist:linux` on Linux.)

The website's **Getting Started** page links to those two files.

## Part 5: First login

1. Open `http://192.168.1.50/register` and create your account (it agrees to the rules page; edit the rules in the website repository's `src/app/rules/page.tsx`).
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
| Login works, character list loads, then the game hangs at "Downloading data" | The zone IP: `sudo goomba zone-ip` should show the game server's LAN address. Fix with `sudo goomba zone-ip 192.168.1.50`. |
| "Install" in the launcher fails | The client isn't on the file server yet: `http://192.168.1.51/launcher/client/manifest.json` must open. |
| Website shows placeholder item icons | Item names and icons are imported once; see the website README, "Item names and icons". |
| The install stopped half-way | Fix what the error says and run `sudo goomba install` again; finished steps are skipped. |

Next: [operations.md](operations.md) for day-to-day running.
