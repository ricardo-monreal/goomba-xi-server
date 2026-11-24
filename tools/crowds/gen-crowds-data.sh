#!/usr/bin/env bash
# Regenerate modules/goomba/lua/crowds_data.lua for the ambient-crowds / field-party modules from
# the server's own tables, item data and navmeshes. Run after a `goomba update` to match a new
# LandSandBoat version. Needs python3 and the navmeshes present in the server tree.
#   bash tools/crowds/gen-crowds-data.sh [SERVER_DIR]      (default /opt/goomba/server)
set -Eeuo pipefail
HERE="$(cd "$(dirname "$0")" && pwd)"
REPO="$(cd "$HERE/../.." && pwd)"
SERVER="${1:-/opt/goomba/server}"
[[ -f "$SERVER/sql/weapon_skills.sql" ]] || { echo "No LandSandBoat tree at $SERVER (pass it as the first argument)." >&2; exit 1; }
[[ -d "$SERVER/navmeshes" ]] || echo "warning: $SERVER/navmeshes not found; field/town spots can't be validated and the result may be empty." >&2
echo "==> weapon_skills.yaml (from sql/weapon_skills.sql)"
python3 -I "$HERE/synth_weapon_skills.py" "$SERVER"
echo "==> crowds_data.lua"
python3 -I "$HERE/build_crowds_data.py" --server "$SERVER" --out "$REPO/modules/goomba/lua/crowds_data.lua"
echo "Done. Then: sudo goomba apply && sudo goomba restart game"
