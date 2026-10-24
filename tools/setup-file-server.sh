#!/usr/bin/env bash
# Sets up the Goomba XI file server: a Debian 13 LXC (or any Debian/Ubuntu machine) that serves
# the game client, launcher installers, addons, HD packs and item icons over HTTP, keeps the
# game server's off-box backups and, optionally, a Git mirror for building without GitHub.
#
#   sudo tools/setup-file-server.sh [options]
#
#   --website URL        The Goomba XI website, e.g. http://192.168.1.50 (allowed to load item icons)
#   --owner USER         Who uploads files (owns /srv/goomba/files). Default: the user running sudo.
#   --backup-key 'KEY'   Authorize the game server's backup key (from: sudo goomba backup-key)
#   --git-mirror         Also serve /srv/git as a read-only Git mirror (tools/git-mirror.sh)
#   --root DIR           Data folder. Default /srv/goomba (mount big storage there first)
#
# Safe to run again: each run rewrites the nginx site and adds what is missing. The options are
# remembered in /etc/goomba/files.conf, so a later run only needs the ones that change.

set -Eeuo pipefail

SAVED=/etc/goomba/files.conf
WEBSITE=""
OWNER="${SUDO_USER:-root}"
BACKUP_KEY=""
GIT_MIRROR=0
ROOT="/srv/goomba"
# shellcheck source=/dev/null
[[ -f "$SAVED" ]] && source "$SAVED"

while [[ $# -gt 0 ]]; do
  case "$1" in
    --website) WEBSITE="${2%/}"; shift 2 ;;
    --owner) OWNER="$2"; shift 2 ;;
    --backup-key) BACKUP_KEY="$2"; shift 2 ;;
    --git-mirror) GIT_MIRROR=1; shift ;;
    --root) ROOT="${2%/}"; shift 2 ;;
    -h|--help) sed -n '2,15p' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
    *) echo "unknown option $1 (see --help)" >&2; exit 2 ;;
  esac
done

[[ $EUID -eq 0 ]] || { echo "run this with sudo" >&2; exit 1; }
id "$OWNER" &>/dev/null || { echo "no such user: $OWNER" >&2; exit 1; }

say() { printf '\e[1;36m==>\e[0m %s\n' "$*"; }

install -d -m 0755 /etc/goomba
cat > "$SAVED" <<EOF
# Options of the last tools/setup-file-server.sh run (read by the next one).
WEBSITE="$WEBSITE"
OWNER="$OWNER"
GIT_MIRROR=$GIT_MIRROR
ROOT="$ROOT"
EOF

say "Packages"
export DEBIAN_FRONTEND=noninteractive
apt-get update -q
pkgs=(nginx rsync openssh-server ca-certificates curl)
(( GIT_MIRROR )) && pkgs+=(git fcgiwrap)
apt-get install -y -q --no-install-recommends "${pkgs[@]}"

say "Folders under $ROOT"
FILES="$ROOT/files"
install -d -m 0755 "$ROOT"
install -d -o "$OWNER" -g "$OWNER" -m 0755 "$FILES" \
  "$FILES/launcher" "$FILES/launcher/client" "$FILES/launcher/client/files" \
  "$FILES/launcher/addons" "$FILES/launcher/packs" "$FILES/launcher/runtime" "$FILES/launcher/releases" \
  "$FILES/icons" "$FILES/icons/items"
# Starter news file so the launcher has something to show before the first real post.
if [[ ! -f "$FILES/launcher/news.json" ]]; then
  cat > "$FILES/launcher/news.json" <<'EOF'
[
  {
    "title": "Welcome to Goomba XI",
    "date": "2026-10-24",
    "body": "The file server is up. Install the game from the launcher's Home tab."
  }
]
EOF
  chown "$OWNER:$OWNER" "$FILES/launcher/news.json"
fi

say "Backups user"
BACKUPS="$ROOT/backups"
if ! id goomba-backup &>/dev/null; then
  # A shell is needed to run the forced rsync command below; the key can do nothing else.
  useradd --system --home-dir "$BACKUPS" --create-home --shell /bin/sh goomba-backup
fi
# The key's home holds .ssh; the dumps go in data/, the only folder the key can reach.
install -d -o goomba-backup -g goomba-backup -m 0750 "$BACKUPS" "$BACKUPS/.ssh" "$BACKUPS/data"
if [[ -n "$BACKUP_KEY" ]]; then
  [[ "$BACKUP_KEY" == ssh-* ]] || { echo "--backup-key must be the whole public key line (ssh-ed25519 AAAA...)" >&2; exit 1; }
  # rrsync limits the key to rsync inside the backups folder.
  rrsync="$(command -v rrsync || true)"
  [[ -z "$rrsync" && -x /usr/share/doc/rsync/scripts/rrsync ]] && rrsync=/usr/share/doc/rsync/scripts/rrsync
  if [[ -n "$rrsync" ]]; then
    line="command=\"$rrsync $BACKUPS/data\",restrict $BACKUP_KEY"
    remote_path="."
  else
    line="restrict $BACKUP_KEY"
    remote_path="data"
  fi
  auth="$BACKUPS/.ssh/authorized_keys"
  touch "$auth"
  grep -qF "$BACKUP_KEY" "$auth" || echo "$line" >> "$auth"
  chown -R goomba-backup:goomba-backup "$BACKUPS/.ssh"; chmod 0700 "$BACKUPS/.ssh"; chmod 0600 "$auth"
  echo "  authorized. On the game server set in /etc/goomba/goomba.conf:"
  echo "    BACKUP_REMOTE=\"goomba-backup@$(hostname -I | awk '{print $1}'):$remote_path\""
fi
systemctl enable --now ssh >/dev/null 2>&1 || systemctl enable --now sshd >/dev/null 2>&1 || true

say "nginx"
cors=""
[[ -n "$WEBSITE" ]] && cors="add_header Access-Control-Allow-Origin \"$WEBSITE\" always;"
git_block=""
if (( GIT_MIRROR )); then
  install -d -o "$OWNER" -g "$OWNER" -m 0755 /srv/git
  systemctl enable --now fcgiwrap
  git_block=$(cat <<'EOF'
    # Git mirror, read-only (tools/git-mirror.sh). Pushes go over SSH.
    location ~ ^/git(/.*)$ {
        client_max_body_size 0;
        fastcgi_pass unix:/run/fcgiwrap.socket;
        include fastcgi_params;
        fastcgi_param SCRIPT_FILENAME /usr/lib/git-core/git-http-backend;
        fastcgi_param GIT_PROJECT_ROOT /srv/git;
        fastcgi_param GIT_HTTP_EXPORT_ALL "";
        fastcgi_param PATH_INFO $1;
        # The repositories belong to the uploader; git-http-backend runs as www-data.
        fastcgi_param GIT_CONFIG_COUNT 1;
        fastcgi_param GIT_CONFIG_KEY_0 safe.directory;
        fastcgi_param GIT_CONFIG_VALUE_0 *;
    }
EOF
)
fi

# Listen on IPv6 too, unless this container has it switched off.
listen6="listen [::]:80 default_server;"
[[ -e /proc/net/if_inet6 ]] || listen6="# IPv6 is off on this machine"

cat > /etc/nginx/sites-available/goomba-files.conf <<EOF
# Goomba XI file server. Written by tools/setup-file-server.sh; run it again instead of editing.
server {
    listen 80 default_server;
    $listen6
    server_name _;
    root $FILES;

    autoindex off;
    sendfile on;
    tcp_nopush on;
    client_max_body_size 0;

    # Client blobs are content-addressed: once published they never change.
    location /launcher/client/files/ {
        expires 1y;
        add_header Cache-Control "public, immutable";
    }

    # Manifests, catalogs and news change with every release; always revalidate.
    location ~ \.json\$ {
        add_header Cache-Control "no-cache";
        $cors
    }

    # Item icons are shown on the website.
    location /icons/ {
        expires 30d;
        $cors
    }

$git_block

    # Range requests let the launcher resume interrupted downloads.
    location / {
        try_files \$uri =404;
    }
}
EOF
ln -sf /etc/nginx/sites-available/goomba-files.conf /etc/nginx/sites-enabled/goomba-files.conf
rm -f /etc/nginx/sites-enabled/default
nginx -t
systemctl enable nginx >/dev/null
systemctl reload nginx || systemctl restart nginx

ip="$(hostname -I | awk '{print $1}')"
printf '\n\e[1;32mFile server ready.\e[0m\n'
echo "  Files:    $FILES  ->  http://$ip/"
echo "  Backups:  $BACKUPS/data"
(( GIT_MIRROR )) && echo "  Git:      http://$ip/git/ (fill it with tools/git-mirror.sh, as $OWNER)"
echo "  Check:    curl -s http://$ip/launcher/news.json"
echo
echo "Use http://$ip as GOOMBA_FILES_URL on the game server and in the launcher's launcher.config.json."
