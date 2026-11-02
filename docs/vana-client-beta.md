# Modern client (beta)

> **Beta, opt-in, experimental.** This is a separate client you can try against Goomba XI to see a modern interface. The supported way to play is still the **launcher** (Ashita + xiloader) in [client-and-launcher.md](client-and-launcher.md). Nothing here changes your server, and you can stop using it at any time.

[**vana-client**](https://github.com/lenonk/vana-client) (by lenonk, MIT) is a native FINAL FANTASY XI client written in Rust. It runs without Wine or PlayOnline — it reads the game's data files and talks to a LandSandBoat server directly. It has two interfaces, switchable any time in **Config > Settings > Client > Interface**:

- **Classic** — the retail client's windows, drawn as the original draws them.
- **Modern** — a new interface over the same game: movable windows, a minimap, tabbed chat, tooltips and mouse support everywhere. See [its modern-UI notes](https://github.com/lenonk/vana-client/blob/main/docs/modern-ui.md) and [screenshots](https://github.com/lenonk/vana-client/tree/main/docs/screenshots).

It works with Goomba XI as-is: the ports (54231 / 54230 / 54001) and client version (`30261006_0`) it expects already match the server, and it signs in with your normal Goomba account. **No server change is required.**

## Requirements

- **Linux** or **Windows** (64-bit). macOS is not available yet.
- A **Vulkan-capable GPU**. On Linux, PipeWire or PulseAudio for sound.
- The **game data** from Square Enix's official installer (`FFXIFullSetup_US.part1.exe` and its parts), or an existing FFXI install to point at. No game data ships with vana-client or Goomba XI.
- A **Goomba XI account** — create it on the website as usual; the client's own account creation is turned off on this server.

## Try it on Linux or the Steam Deck

From this repository, run the helper with your server's address (the game server's LAN IP, or your domain / VPS):

```bash
bash tools/vana-beta.sh --server 10.2.5.64
```

It downloads the vana-client binary to `~/.local/bin/vana-client` and writes `~/.config/vana-client/config.json` pointed at your server. Then, once:

```bash
~/.local/bin/vana-client install /path/to/FFXIFullSetup_US.part1.exe   # or point game_dir at an FFXI install
~/.local/bin/vana-client update                                        # bring the data to current retail
```

And to play:

```bash
~/.local/bin/vana-client play
```

Log in with your Goomba username and password.

## Try it on Windows

1. Download `vana-client-windows-x86_64.exe` from the [releases page](https://github.com/lenonk/vana-client/releases) and put it in a folder of its own.
2. Run it once so it creates its config, or create `%USERPROFILE%\.config\vana-client\config.json` with:

   ```json
   {
     "server": "10.2.5.64",
     "client_version": "30261006_0"
   }
   ```

   (use your server's address). Ports default to Goomba's, so they don't need setting.
3. Add the game data (`vana-client.exe install <FFXIFullSetup_US.part1.exe>`, then `vana-client.exe update`), or point `game_dir` at an existing install.
4. `vana-client.exe play`, and log in with your Goomba account.

## Settings you may need

In `config.json` (most other options are in the in-game Config menus):

| Field | Default | Meaning |
| --- | --- | --- |
| `server` | `127.0.0.1` | **Set this** to your Goomba XI server address. |
| `auth_port`, `data_port`, `view_port` | `54231`, `54230`, `54001` | Already match Goomba; leave them. |
| `client_version` | `30261006_0` | Matches Goomba's `CLIENT_VER`; leave it. |
| `game_dir` | `~/.local/share/vana-client/game` | Folder holding `FINAL FANTASY XI`; set it to reuse an install. |
| `frame_limit` | `300` | Frame cap in fps (`0` = unlimited). |

## Known limits of the beta

- **Era data.** vana-client reads retail game data, not Goomba's Era-DATs (which the launcher overlays with XIPivot). Some item names, prices and menus will look like **current retail**, not the 75-era client. The interface itself is what this beta is for.
- **Unfinished in vana-client:** no gamepad support yet, a few event mini-games, and no macOS build.
- It is a young project under active development; treat it as a preview, not a replacement for the launcher.

## Credit and license

[vana-client](https://github.com/lenonk/vana-client) is by lenonk, released under the MIT License. It is an unofficial fan project and is not affiliated with, endorsed by or supported by Square Enix. FINAL FANTASY is a registered trademark of Square Enix Holdings Co., Ltd. No game data is included.
