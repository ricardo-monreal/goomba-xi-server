# Running Goomba XI without GitHub

For a preservation project, everything Goomba XI needs should be able to live on your own machines. The file server keeps a Git mirror of every repository and the release files the launcher downloads; the game server and your build PC are told to use it; and all builds run locally instead of on GitHub Actions. Do the "download now" steps while GitHub is still reachable: after that, nothing depends on it.

## What uses GitHub

| Where | What it fetches | Without GitHub |
| --- | --- | --- |
| Game server install and `goomba update` | LandSandBoat, its submodules (navmeshes), the website | Git mirror + `GIT_MIRROR` |
| Game server build | About 15 C++ libraries (CPM: fmt, spdlog, asio, …) and CPM itself | Git mirror, plus a permanent cache in `/opt/goomba/cache/cpm` |
| Client build (Windows) | Ashita, Era-DATs, xiloader and its libraries | Git mirror |
| Launcher and xiloader releases | GitHub Actions | Local builds (below) |
| Launcher builds | Electron, NSIS, winCodeSign, AppImage tools | Downloaded once, then cached |
| Players' Linux launchers | GE-Proton, umu-launcher, winetricks | Hosted on the file server (`linux.*Url`) |

Not GitHub, still internet: Ubuntu/Debian packages, the npm registry, PyPI (LandSandBoat's Python tools), and Valve's Steam Linux Runtime that umu downloads on a player's first Play. For a fully offline archive, also keep an apt cache (`apt-cacher-ng`) and an npm/PyPI mirror, or a Proxmox backup of a working VM.

## 1. Git mirror on the file server

On the Debian LXC, as root:

```bash
/opt/goomba-xi-server/tools/setup-file-server.sh --git-mirror
su - goomba-admin -c /opt/goomba-xi-server/tools/git-mirror.sh
```

The first run copies about 40 repositories (several GB; LandSandBoat's navmeshes are the largest) into `/srv/git/github.com/<owner>/<repo>.git`. The list is `/srv/git/mirrors.txt`; the script also follows every mirror's submodules and the libraries its CMake files download, so new ones are picked up when LandSandBoat changes. Check it from the game server:

```bash
git ls-remote http://192.168.1.51/git/github.com/LandSandBoat/server | head -1
```

Keep it current with a nightly job (`crontab -e` as `goomba-admin`):

```
30 3 * * * /opt/goomba-xi-server/tools/git-mirror.sh >> /home/goomba-admin/git-mirror.log 2>&1
```

## 2. Point the game server at the mirror

In `/etc/goomba/goomba.conf` on the game server:

```bash
GIT_MIRROR="http://192.168.1.51/git"
```

The next `sudo goomba update` or `sudo goomba web-update` adds one system-wide Git setting that sends every `https://github.com/…` URL to the mirror: LandSandBoat, its submodules, the website and the libraries the build downloads. Clearing `GIT_MIRROR` removes it again. Check it with:

```bash
git config --system --get-regexp insteadof
git ls-remote --get-url https://github.com/LandSandBoat/server
```

Build libraries are also kept in `/opt/goomba/cache/cpm` from the first build on, so rebuilds work even without the mirror.

To install a **new** game server from the mirror, clone this repository from it and write the configuration yourself before installing, with `GIT_MIRROR` and the addresses filled in (the installer skips its questions when the file exists):

```bash
sudo apt install -y git
sudo git clone http://192.168.1.51/git/github.com/ricardo-monreal/goomba-xi-server /opt/goomba-xi-server
sudo install -d /etc/goomba
sudo cp /opt/goomba-xi-server/config/goomba.conf.example /etc/goomba/goomba.conf
sudo nano /etc/goomba/goomba.conf     # GIT_MIRROR, GOOMBA_ZONE_IP, GOOMBA_FILES_URL
sudo /opt/goomba-xi-server/bin/goomba install
```

## 3. Your PCs: read from the mirror, push to it

On the Windows build PC (and any machine you develop on):

```powershell
git config --global url."http://192.168.1.51/git/github.com/".insteadOf "https://github.com/"
git config --global url."goomba-admin@192.168.1.51:/srv/git/github.com/".pushInsteadOf "https://github.com/"
```

Repositories keep their GitHub-style addresses, but fetches come from the mirror and pushes go to it over SSH. When you stop pushing to GitHub, mark your own repositories in `/srv/git/mirrors.txt` so the nightly job stops overwriting them:

```
ricardo-monreal/goomba-xi-server local
ricardo-monreal/goomba-xi-web local
ricardo-monreal/goomba-xi-launcher local
```

## 4. Build releases locally

### xiloader (Windows)

Install Visual Studio 2022 Build Tools with "Desktop development with C++", plus CMake, then:

```powershell
git clone https://github.com/phoenixffxi/xiloader C:\xiloader
cd C:\xiloader
git checkout 806d1c79a3eef254572b56e069ba0ddd291b3ecf
$env:CPM_SOURCE_CACHE = "C:\goomba-cache\cpm"
cmake -S . -B build -A Win32 -DCMAKE_BUILD_TYPE=Release
cmake --build build --config Release
copy xiloader.exe C:\goomba-xi-launcher\vendor\
```

The exe is written to the source folder, not `build\`.

### Launcher, Windows installer

```powershell
cd C:\goomba-xi-launcher
git pull
npm.cmd ci
npm.cmd run dist
```

The installer is `dist\GoombaXI-Setup-<version>.exe`. The first build downloads Electron, NSIS and winCodeSign into `%LOCALAPPDATA%\electron\Cache` and `%LOCALAPPDATA%\electron-builder\Cache`. Copy those two folders to the file server (`/srv/goomba/files/build-cache/windows/`) and back onto any new build PC to build offline.

### Launcher, Linux AppImage

On any Ubuntu machine with Node.js 20+ (the game server works):

```bash
git clone https://github.com/ricardo-monreal/goomba-xi-launcher ~/goomba-xi-launcher
cd ~/goomba-xi-launcher
npm ci
npm run dist:linux
```

The AppImage is `dist/GoombaXI-<version>-x86_64.AppImage`. Its build tools are cached in `~/.cache/electron` and `~/.cache/electron-builder`; keep a copy of those too.

### Publish

1. Bump `version` in `package.json`, commit, and tag it: `git tag v1.0.1 && git push origin main v1.0.1` (goes to the mirror).
2. Copy the two files to the file server, keeping the versioned copies:

```bash
scp dist/GoombaXI-Setup-1.0.1.exe dist/GoombaXI-1.0.1-x86_64.AppImage goomba-admin@192.168.1.51:/srv/goomba/files/launcher/releases/
ssh goomba-admin@192.168.1.51 'cd /srv/goomba/files/launcher && cp releases/GoombaXI-Setup-1.0.1.exe GoombaXI-Setup.exe && cp releases/GoombaXI-1.0.1-x86_64.AppImage GoombaXI.AppImage'
```

## 5. Players' Linux runtime

Download these once, on any PC, and put them in `/srv/goomba/files/launcher/runtime/`:

| File | From |
| --- | --- |
| The GE-Proton11-5 `.tar.gz` (x86_64) and its `.sha512sum` | github.com/GloriousEggroll/proton-ge-custom/releases/tag/GE-Proton11-5 |
| The umu-launcher zipapp `.tar` | github.com/Open-Wine-Components/umu-launcher/releases (latest) |
| `winetricks` | raw.githubusercontent.com/Winetricks/winetricks/master/src/winetricks |

Then set the addresses in the launcher's `launcher.config.json`, build and publish a new launcher:

```json
"linux": {
  "protonVersion": "GE-Proton11-5",
  "protonUrl": "http://192.168.1.51/launcher/runtime/<the GE-Proton file>.tar.gz",
  "umuUrl": "http://192.168.1.51/launcher/runtime/<the umu zipapp file>.tar",
  "winetricksUrl": "http://192.168.1.51/launcher/runtime/winetricks"
}
```

## 6. Check it

Block GitHub for a moment (on the router, or `127.0.0.1 github.com` in the game server's `/etc/hosts`), then run `sudo goomba update`, build the launcher on each PC, and do a first Play on a fresh Linux install. Anything that still reaches GitHub fails loudly; remove the block afterwards.
