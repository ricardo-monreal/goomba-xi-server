#!/usr/bin/env bash
# Keeps copies of every Git repository Goomba XI needs, so the server can be installed, updated
# and built without GitHub. Run it on the file server (as the user who owns /srv/git).
#
#   tools/git-mirror.sh                 create or update every mirror
#   tools/git-mirror.sh --root DIR      mirrors somewhere other than /srv/git
#
# Mirrors live at <root>/github.com/<owner>/<repo>.git (plus a <repo> link without .git), so a
# single Git setting on the game server sends every https://github.com/... URL here instead:
#   GIT_MIRROR="http://192.168.1.51/git" in /etc/goomba/goomba.conf (see docs/without-github.md).
#
# The list is <root>/mirrors.txt, one "owner/repo" per line; it is created with Goomba XI's
# repositories the first time. Besides the list, the script follows every mirror's submodules and
# the GITHUB_REPOSITORY entries in its CMake files (the libraries LandSandBoat and xiloader
# download while building), so new dependencies are picked up when you update LandSandBoat.
#
# Add " local" after a repository to stop fetching it from GitHub: do that for your own
# repositories once you push to the mirror instead of GitHub (it becomes the original).

set -Eeuo pipefail

ROOT=/srv/git
while [[ $# -gt 0 ]]; do
  case "$1" in
    --root) ROOT="$2"; shift 2 ;;
    -h|--help) sed -n '2,19p' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
    *) echo "unknown option $1" >&2; exit 2 ;;
  esac
done

LIST="$ROOT/mirrors.txt"
UPSTREAM="https://github.com"

mkdir -p "$ROOT/github.com"
if [[ ! -f "$LIST" ]]; then
  cat > "$LIST" <<'EOF'
# Repositories mirrored by tools/git-mirror.sh, one owner/repo per line.
# " local" after a name: the mirror is the original now; don't fetch it from GitHub.

# Goomba XI
ricardo-monreal/goomba-xi-server
ricardo-monreal/goomba-xi-web
ricardo-monreal/goomba-xi-launcher

# Game server and client
LandSandBoat/server
LandSandBoat/xiloader
phoenixffxi/xiloader
phoenixffxi/Era-DATs
AshitaXI/Ashita-v4beta
HealsCodes/XIPivot

# CMake's package manager, downloaded by LandSandBoat's build
cpm-cmake/CPM.cmake
EOF
fi

declare -A seen=()
queue=()
while read -r line; do
  line="${line%%#*}"; line="$(echo "$line" | xargs)"
  [[ -n "$line" ]] && queue+=("$line")
done < "$LIST"

failed=0
sync_repo() {
  local name="$1" mode="$2"
  local dir="$ROOT/github.com/$name.git"
  if [[ ! -d "$dir" ]]; then
    if [[ "$mode" == local ]]; then
      echo "  ! $name is marked local but has no mirror yet; push it there first" >&2
      return 1
    fi
    echo "==> new mirror: $name"
    mkdir -p "$(dirname "$dir")"
    git clone --quiet --mirror "$UPSTREAM/$name.git" "$dir"
  elif [[ "$mode" != local ]]; then
    echo "==> update: $name"
    git -C "$dir" fetch --quiet --prune --tags origin
  else
    echo "==> local: $name (not fetched)"
  fi
  # Smart HTTP needs these: partial clones (the installer uses --filter=blob:none), and submodule
  # commits fetched by hash.
  git -C "$dir" config uploadpack.allowFilter true
  git -C "$dir" config uploadpack.allowReachableSHA1InWant true
  git -C "$dir" config http.receivepack false
  git -C "$dir" update-server-info
  ln -sfn "$(basename "$dir")" "${dir%.git}"
}

# Repositories referenced by a mirror: its submodules and its CMake GITHUB_REPOSITORY entries.
deps_of() {
  local dir="$ROOT/github.com/$1.git"
  git -C "$dir" rev-parse --verify --quiet HEAD >/dev/null || return 0
  { git -C "$dir" show HEAD:.gitmodules 2>/dev/null || true; } \
    | sed -n 's#^\s*url\s*=\s*https://github.com/\([^ ]*\)#\1#p' | sed 's#\.git$##; s#/$##'
  { git -C "$dir" ls-tree -r --name-only HEAD 2>/dev/null || true; } | { grep -E '(^|/)(CMakeLists\.txt|[^/]+\.cmake)$' \
    | grep -vE '(^|/)(tests?|examples?|docs?)/' | head -400 || true; } | while read -r f; do
      { git -C "$dir" show "HEAD:$f" 2>/dev/null || true; } | sed -n 's#.*GITHUB_REPOSITORY[[:space:]]\+\([A-Za-z0-9_.-]*/[A-Za-z0-9_.-]*\).*#\1#p'
    done
}

i=0
while [[ $i -lt ${#queue[@]} ]]; do
  entry="${queue[$i]}"; i=$((i + 1))
  name="${entry%% *}"; mode=""
  [[ "$entry" == *" local" ]] && mode=local
  key="${name,,}"
  [[ -n "${seen[$key]:-}" ]] && continue
  seen[$key]=1
  if ! sync_repo "$name" "$mode"; then
    echo "  ! could not mirror $name" >&2
    failed=$((failed + 1))
    continue
  fi
  while read -r dep; do
    [[ -n "$dep" && -z "${seen[${dep,,}]:-}" ]] && queue+=("$dep")
  done < <(deps_of "$name" | sort -u)
done

echo "done: ${#seen[@]} repositories under $ROOT/github.com ($failed failed)"
[[ $failed -eq 0 ]]
