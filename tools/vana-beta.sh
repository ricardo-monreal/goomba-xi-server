#!/usr/bin/env bash
# Goomba XI — vana-client (Modern UI) BETA setup, for Linux and the Steam Deck.
#
# vana-client (https://github.com/lenonk/vana-client, MIT) is a separate, experimental native FFXI
# client with a modern interface (movable windows, minimap, tabbed chat, mouse support). This is an
# OPT-IN BETA for trying it against Goomba XI. It is not the supported client — the launcher
# (Ashita + xiloader) stays the normal way to play. No server change is needed: Goomba already uses
# the ports and client version vana-client expects.
#
# What this does, all under your home directory (no sudo):
#   1. downloads the vana-client Linux binary from its GitHub releases
#   2. points it at your Goomba XI server (writes ~/.config/vana-client/config.json)
#   3. tells you how to add the game data and start it
#
# Usage:
#   bash vana-beta.sh --server 10.2.5.64            # your Goomba server address (LAN IP, or domain/VPS)
#   bash vana-beta.sh --server play.example.com --version v1.0.1   # pin a release instead of latest
#
# Afterwards: `~/.local/bin/vana-client install <FFXIFullSetup_US.part1.exe>` (or point game_dir at an
# existing FFXI install), then `~/.local/bin/vana-client play` and log in with your Goomba account.
set -Eeuo pipefail

SERVER=""
VERSION="latest"
BINDIR="${XDG_BIN_HOME:-$HOME/.local/bin}"
CONF="${XDG_CONFIG_HOME:-$HOME/.config}/vana-client/config.json"
REPO="lenonk/vana-client"
ASSET="vana-client-linux-x86_64"

while [[ $# -gt 0 ]]; do
  case "$1" in
    --server)  SERVER="${2:?}"; shift 2 ;;
    --version) VERSION="${2:?}"; shift 2 ;;
    -h|--help) sed -n '2,24p' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
    *) echo "unknown option: $1" >&2; exit 1 ;;
  esac
done

say()  { printf '\e[1;36m==>\e[0m %s\n' "$*"; }
ok()   { printf '\e[1;32m ok\e[0m %s\n' "$*"; }
die()  { printf '\e[1;31merror:\e[0m %s\n' "$*" >&2; exit 1; }

[[ -n "$SERVER" ]] || die "give your Goomba server address: bash vana-beta.sh --server <address>"
command -v curl >/dev/null || die "curl is required"

# 1. Download the binary.
if [[ "$VERSION" == latest ]]; then
  url="https://github.com/$REPO/releases/latest/download/$ASSET"
else
  url="https://github.com/$REPO/releases/download/$VERSION/$ASSET"
fi
say "Downloading vana-client ($VERSION) from $url"
mkdir -p "$BINDIR"
tmp="$(mktemp)"
curl -fL --progress-bar -o "$tmp" "$url" || die "download failed. Check the version, or grab the binary from https://github.com/$REPO/releases"
install -Dm755 "$tmp" "$BINDIR/vana-client"
rm -f "$tmp"
ok "installed $BINDIR/vana-client"

# 2. Point it at Goomba. Ports and client version already match Goomba's defaults; only the address
#    differs. Merge into any existing config so other settings are kept.
say "Writing $CONF (server = $SERVER)"
mkdir -p "$(dirname "$CONF")"
if command -v python3 >/dev/null; then
  SERVER="$SERVER" CONF="$CONF" python3 - <<'PY'
import json, os
conf, server = os.environ['CONF'], os.environ['SERVER']
data = {}
if os.path.exists(conf):
    try:
        with open(conf) as f: data = json.load(f)
    except Exception: data = {}
data['server'] = server
data.setdefault('client_version', '30261006_0')  # Goomba's CLIENT_VER; vana defaults to this too
with open(conf, 'w') as f: json.dump(data, f, indent=2)
PY
else
  [[ -e "$CONF" ]] && cp "$CONF" "$CONF.bak.$(date +%s)" && echo "  (backed up your old config)"
  printf '{\n  "server": "%s",\n  "client_version": "30261006_0"\n}\n' "$SERVER" > "$CONF"
fi
ok "configured for $SERVER (ports 54231/54230/54001, client 30261006_0)"

cat <<EOF

$(printf '\e[1;32mvana-client is installed and pointed at Goomba XI (%s).\e[0m' "$SERVER")

This is a BETA client, separate from the launcher. Two steps left:

  1. Add the game data (once). Either install it from Square Enix's official setup:
       $BINDIR/vana-client install /path/to/FFXIFullSetup_US.part1.exe
       $BINDIR/vana-client update          # brings it to the current retail version
     or point "game_dir" in $CONF at an FFXI folder you already have.

  2. Start it and log in with your existing Goomba XI account (create accounts on the website):
       $BINDIR/vana-client play

Switch the look any time in Config > Settings > Client > Interface (Classic or Modern).
If $BINDIR isn't on your PATH, run the binary by its full path above.

Notes for the beta:
  - vana-client reads retail game data, not Goomba's Era-DATs, so some item names and menus look
    like current retail rather than the 75-era client. The interface is what you're testing.
  - No gamepad support yet; a few event mini-games are unfinished; no macOS build.
  - On Windows, download $ASSET.exe from https://github.com/$REPO/releases and set "server"
    to $SERVER in %APPDATA%\\..\\.config\\vana-client\\config.json (or see docs/vana-client-beta.md).

Credit: vana-client by lenonk (MIT). Not affiliated with Square Enix.
EOF
