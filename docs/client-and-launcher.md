# Part 4: the game client and the launcher, step by step

At this point the game server (10.2.5.64) and the file server (10.2.5.65) are running, but players have nothing to install yet. This part makes the two things they download:

| What | Built where | Ends up on the file server as |
| --- | --- | --- |
| **The game client**: FFXI + PlayOnline + Ashita + xiloader + Era-DATs, packed for download | Your Windows PC, once (and again only after a game update) | `launcher/client/manifest.json` + `launcher/client/files/…` |
| **The launcher**: the program players install | GitHub (automatically, from a tag) | `launcher/GoombaXI-Setup.exe` and `launcher/GoombaXI.AppImage` |

Each step says **where** to run it. Plan on 1–2 hours, most of it waiting for FFXI to download and for the client to upload.

## Before you start: check the servers

From any PC's browser:

- `http://10.2.5.64` shows the Goomba XI website.
- `http://10.2.5.65/launcher/news.json` shows a short welcome message.

If either fails, finish parts 2 and 3 of [install.md](install.md) first.

## A. Prepare the Windows PC (once)

**Where: Windows PC.**

1. Install **Git for Windows** (https://git-scm.com/download/win, all defaults) and **Node.js 22 LTS** (https://nodejs.org, all defaults).
2. Install **FINAL FANTASY XI** from Square Enix's official download page, then run **PlayOnline Viewer → Check Files / update** until it says the game is up to date. This is the copy the client is built from: **don't log in to a Square Enix account with it**, and don't play it.

   The server accepts this client version or newer (LandSandBoat's `CLIENT_VER` check), so a fully updated retail install is exactly right.

3. Open **PowerShell** and get the launcher repository and the parts it needs:

   ```powershell
   cd C:\
   git clone https://github.com/ricardo-monreal/goomba-xi-launcher
   cd C:\goomba-xi-launcher
   npm install
   mkdir vendor, overlay\Ashita\polplugins
   git clone https://github.com/AshitaXI/Ashita-v4beta vendor\Ashita-v4beta
   git -C vendor\Ashita-v4beta checkout 4171c74
   git clone https://github.com/phoenixffxi/Era-DATs vendor\Era-DATs
   ```

4. **xiloader** (the small program that logs the game in, with launch-token support):
   1. Open https://github.com/ricardo-monreal/goomba-xi-launcher/actions/workflows/xiloader.yml in a browser (signed in to GitHub).
   2. Click **Run workflow** → **Run workflow** (keep the default commit).
   3. When the run turns green (a few minutes), open it and download the **xiloader-phoenix** artifact. Unzip it and put `xiloader.exe` in `C:\goomba-xi-launcher\vendor\`.

5. **XIPivot** (loads the Era-DATs and optional HD packs without touching game files): download the latest Ashita v4 release from https://github.com/HealsCodes/XIPivot/releases and copy its `pivot.dll` to `C:\goomba-xi-launcher\overlay\Ashita\polplugins\`.

Check: `C:\goomba-xi-launcher\vendor` now has `Ashita-v4beta\`, `Era-DATs\` and `xiloader.exe`, and `overlay\Ashita\polplugins\pivot.dll` exists.

## B. Build the client

**Where: Windows PC, PowerShell in `C:\goomba-xi-launcher`.**

```powershell
node tools/build-client.mjs `
  --ffxi     "C:/Program Files (x86)/PlayOnline/SquareEnix/FINAL FANTASY XI" `
  --pol      "C:/Program Files (x86)/PlayOnline/SquareEnix/PlayOnlineViewer" `
  --ashita   ./vendor/Ashita-v4beta `
  --xiloader ./vendor/xiloader.exe `
  --era      ./vendor/Era-DATs `
  --overlay  ./overlay `
  --out      ./client

node tools/make-manifest.mjs ./client ./publish --gzip --version 2026.10.24-1
```

(If FFXI is installed somewhere else, change the two paths. The backtick at the end of each line continues the command in PowerShell.)

- `build-client` copies everything into `client\` (about 15 GB), leaves out personal data, and removes every Ashita addon or plugin that isn't on the approved list. It stops with a clear message if a part is missing.
- `make-manifest` compresses it into `publish\files\…` plus `publish\manifest.json`. It takes a while the first time; later runs only add what changed.

Check: `C:\goomba-xi-launcher\publish\manifest.json` exists.

## C. Upload the client to the file server

**Where: Windows PC, PowerShell.** Upload the files **first** and the manifest **last** (the manifest tells launchers the files are ready). `goomba-admin` is the upload user you created in part 3.

```powershell
scp -r .\publish\files goomba-admin@10.2.5.65:/srv/goomba/files/launcher/client/
scp .\publish\manifest.json goomba-admin@10.2.5.65:/srv/goomba/files/launcher/client/
```

Check: `http://10.2.5.65/launcher/client/manifest.json` opens in a browser.

(WinSCP works too: connect to 10.2.5.65 as `goomba-admin` and copy `publish\files` and then `publish\manifest.json` into `/srv/goomba/files/launcher/client/`.)

## D. Build and publish the launcher

The launcher has your server addresses built in, so it is built after you know them.

**Where: Windows PC, PowerShell in `C:\goomba-xi-launcher`.**

1. Point it at your servers, check, and publish a release:

   ```powershell
   git pull
   node tools/configure.mjs --server 10.2.5.64 --files http://10.2.5.65
   node tools/configure.mjs --show
   git commit -am "Point the launcher at 10.2.5.64 / 10.2.5.65"
   git tag v1.0.0
   git push origin main v1.0.0
   ```

   (`configure` may say there is nothing to change: the repository already uses these addresses. Then skip the commit line and just tag and push.)

2. On GitHub, **Actions → release** builds the Windows installer and the Linux AppImage (about 10 minutes) and attaches them to a release at https://github.com/ricardo-monreal/goomba-xi-launcher/releases. Download `GoombaXI-Setup-1.0.0.exe` and `GoombaXI-1.0.0-x86_64.AppImage`.

3. Copy them to the file server under the fixed names the website links to:

   ```powershell
   scp .\GoombaXI-Setup-1.0.0.exe goomba-admin@10.2.5.65:/srv/goomba/files/launcher/GoombaXI-Setup.exe
   scp .\GoombaXI-1.0.0-x86_64.AppImage goomba-admin@10.2.5.65:/srv/goomba/files/launcher/GoombaXI.AppImage
   ```

Check: the **Getting Started** page on `http://10.2.5.64` has working Windows and Linux download links.

(No GitHub? `npm run dist` builds the Windows installer locally into `dist\`; `npm run dist:linux` on any Linux machine builds the AppImage.)

## E. First login (part 5)

1. Register at `http://10.2.5.64/register`.
2. Download the launcher from **Getting Started**, install and open it, press **Install** (it downloads the client from 10.2.5.65).
3. Sign in with the website username and password, press **Play**, create a character.
4. On the game server: `sudo goomba gm <your account> 5`, then zone or log out and back in.

## When the game updates

Square Enix still patches FFXI. When LandSandBoat raises `CLIENT_VER` (see [updating.md](updating.md)): update the retail copy with PlayOnline, then repeat **B** with a new `--version` and **C**. Players' launchers download only the changed files. Steps A and D are not repeated.
