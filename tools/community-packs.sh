#!/usr/bin/env bash
# Publishes the community packs and addons the Goomba XI launcher offers (Addons → Pivot and
# Addons → Catalog), straight from their GitHub repositories. Run it on the file server:
#
#   sudo bash /opt/goomba-xi-server/tools/community-packs.sh [--base-url http://10.2.5.65]
#
#   XICombinedMaps (CriticalXI)  → packs/combined-maps-basic-<date>.zip  (1024x1024 maps)
#                                  packs/combined-maps-hd-<date>.zip     (2048x2048 maps)
#   XiView (KenshiDRK)           → packs/xiview-standard-<date>.zip       (4:3 / standard UI)
#                                  packs/xiview-widescreen-<date>.zip     (16:9 / 16:10 UI)
#   targetlines (Jyouya)         → addons/targetlines-<version>.zip      (Ashita addon)
#   mobdb (ThornyFFXI)           → addons/mobdb-<version>.zip            (Ashita addon)
#
# then rebuilds launcher/pivot.json and launcher/addons.json with the launcher repository's
# tools/make-catalogs.mjs and file-server/catalog-sources.json (names, descriptions, credits).
# Launchers pick the new catalogs up the next time they open the Addons tab: no launcher rebuild.
#
# Safe to run again: repositories are updated in place, a zip is rebuilt only when its source
# changed, and old zips are moved to packs/old/ and addons/old/.

set -Eeuo pipefail

SAVED=/etc/goomba/files.conf
ROOT="/srv/goomba"
OWNER="root"
# shellcheck source=/dev/null
[[ -f "$SAVED" ]] && source "$SAVED"
BASE_URL=""
LAUNCHER_REPO="${GOOMBA_LAUNCHER_REPO:-https://github.com/ricardo-monreal/goomba-xi-launcher}"

while [[ $# -gt 0 ]]; do
  case "$1" in
    --base-url) BASE_URL="${2%/}"; shift 2 ;;
    -h|--help) sed -n '2,20p' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
    *) echo "unknown option $1 (see --help)" >&2; exit 2 ;;
  esac
done
[[ $EUID -eq 0 ]] || { echo "run this with sudo" >&2; exit 1; }
[[ -n "$BASE_URL" ]] || BASE_URL="http://$(hostname -I | awk '{print $1}')"

say() { printf '\e[1;36m==>\e[0m %s\n' "$*"; }
ok()  { printf '\e[1;32m ok\e[0m %s\n' "$*"; }

FILES="$ROOT/files/launcher"
SRC="$ROOT/src"
if [[ ! -d "$FILES" ]]; then
  if [[ -f /etc/goomba/goomba.conf ]]; then
    echo "This is the game server ($(hostname)). Run this script on the file server (the Debian LXC) instead:" >&2
    echo "  open the LXC's console in Proxmox (or: pct enter <id> on the Proxmox host), then" >&2
    echo "  cd /opt/goomba-xi-server && git pull && bash tools/community-packs.sh --base-url http://<file server IP>" >&2
  else
    echo "$FILES not found: set this machine up as the file server first (tools/setup-file-server.sh)" >&2
  fi
  exit 1
fi

say "Packages"
need=()
command -v git >/dev/null || need+=(git)
command -v zip >/dev/null || need+=(zip)
command -v node >/dev/null || need+=(nodejs)
if ((${#need[@]})); then
  export DEBIAN_FRONTEND=noninteractive
  apt-get update -q
  apt-get install -y -q --no-install-recommends ca-certificates "${need[@]}"
fi
ok "git, zip, node $(node -v)"

install -d -m 0755 "$SRC" "$FILES/packs" "$FILES/addons" "$FILES/packs/old" "$FILES/addons/old"

# fetch <owner/repo> → $SRC/<repo>, shallow, updated in place.
fetch() {
  local repo="$1" dir="$SRC/${1##*/}"
  if [[ -d "$dir/.git" ]]; then
    git -C "$dir" fetch -q --depth 1 origin HEAD
    git -C "$dir" reset -q --hard FETCH_HEAD
  else
    git clone -q --depth 1 "https://github.com/$repo" "$dir"
  fi
  echo "$dir"
}

# A date version (YYYY.MM.DD) from the repository's last commit.
commit_date() { git -C "$1" log -1 --format=%cd --date=format:%Y.%m.%d; }

# pack <source dir> <dest dir> <name>: zips the contents of <source dir> (its ROM folders at the
# top of the zip) as <dest dir>/<name>, unless that file already exists. Older zips with the same
# prefix move to old/.
pack() {
  local from="$1" dest="$2" name="$3" prefix="${3%-*}"
  [[ -d "$from" ]] || { echo "  ! $from is missing; skipped" >&2; return 0; }
  if [[ -f "$dest/$name" ]]; then ok "$name (up to date)"; return 0; fi
  local old
  for old in "$dest/$prefix"-*.zip; do [[ -e "$old" ]] && mv -f "$old" "$dest/old/"; done
  (cd "$from" && zip -qr -9 "$dest/$name.part" . -x '.git/*' -x '*.md') && mv -f "$dest/$name.part" "$dest/$name"
  ok "$name ($(du -h "$dest/$name" | cut -f1))"
}

say "XICombinedMaps (about 2.3 GB to download the first time)"
maps="$(fetch CriticalXI/XICombinedMaps)"
ver="$(commit_date "$maps")"
pack "$maps/1024x1024" "$FILES/packs" "combined-maps-basic-$ver.zip"
pack "$maps/2048x2048" "$FILES/packs" "combined-maps-hd-$ver.zip"
MAPS_VER="$ver"

say "XiView"
xiview="$(fetch KenshiDRK/XiView)"
ver="$(commit_date "$xiview")"
pack "$xiview/Normal" "$FILES/packs" "xiview-standard-$ver.zip"
pack "$xiview/Widescreen" "$FILES/packs" "xiview-widescreen-$ver.zip"
XIVIEW_VER="$ver"

say "targetlines"
tl="$(fetch Jyouya/targetlines)"
ver="$(sed -n "s/^addon.version *= *'\([^']*\)'.*/\1/p" "$tl/targetlines.lua" | head -1)"
ver="${ver:-$(commit_date "$tl")}"
# The zip holds the addon folder itself: targetlines/targetlines.lua, assets/, ...
stage="$(mktemp -d)"
cp -r "$tl" "$stage/targetlines"
rm -rf "$stage/targetlines/.git"
pack "$stage" "$FILES/addons" "targetlines-$ver.zip"
rm -rf "$stage"
TL_VER="$ver"

say "mobdb"
mdb="$(fetch ThornyFFXI/mobdb)"
ver="$(sed -n "s/^addon.version *= *'\([^']*\)'.*/\1/p" "$mdb/mobdb.lua" | head -1)"
ver="${ver:-$(commit_date "$mdb")}"
# The zip holds the addon folder itself: mobdb/mobdb.lua, data/, icons/, ...
stage="$(mktemp -d)"
cp -r "$mdb" "$stage/mobdb"
rm -rf "$stage/mobdb/.git"
pack "$stage" "$FILES/addons" "mobdb-$ver.zip"
rm -rf "$stage"
MOBDB_VER="$ver"

say "Catalogs (pivot.json, addons.json)"
launcher="$(fetch "${LAUNCHER_REPO#https://github.com/}")"
# catalog-sources.json lists every pack and addon the launcher can offer; point the entries for
# these three at the zips just built (versions are dates from their repositories).
node - "$launcher/file-server/catalog-sources.json" "$SRC/catalog-sources.json" "$MAPS_VER" "$XIVIEW_VER" "$TL_VER" "$MOBDB_VER" <<'JS'
const fs = require('fs')
const [src, out, maps, xiview, tl, mobdb] = process.argv.slice(2)
const s = JSON.parse(fs.readFileSync(src, 'utf8'))
const set = (list, id, version, file) => {
  const e = list.find((x) => (x.id ?? x.name) === id)
  if (e) Object.assign(e, { version, file })
}
set(s.packs, 'combined-maps-basic', maps, `packs/combined-maps-basic-${maps}.zip`)
set(s.packs, 'combined-maps-hd', maps, `packs/combined-maps-hd-${maps}.zip`)
set(s.packs, 'xiview-standard', xiview, `packs/xiview-standard-${xiview}.zip`)
set(s.packs, 'xiview-widescreen', xiview, `packs/xiview-widescreen-${xiview}.zip`)
set(s.addons, 'TargetLines', tl, `addons/targetlines-${tl}.zip`)
set(s.addons, 'MobDB', mobdb, `addons/mobdb-${mobdb}.zip`)
fs.writeFileSync(out, JSON.stringify(s, null, 2) + '\n')
JS
echo "  (other entries in catalog-sources.json without a zip here are reported as missing and left out; that is expected)"
(cd "$launcher" && node tools/make-catalogs.mjs --files "$FILES" --base-url "$BASE_URL/launcher" --sources "$SRC/catalog-sources.json")

chown -R "$OWNER:$OWNER" "$FILES/packs" "$FILES/addons" "$FILES/pivot.json" "$FILES/addons.json" 2>/dev/null || true

printf '\n\e[1;32mDone.\e[0m Check: %s/launcher/pivot.json and %s/launcher/addons.json\n' "$BASE_URL" "$BASE_URL"
echo "In the launcher: Addons → Pivot for the map and UI packs, Addons → Catalog for TargetLines and MobDB."
