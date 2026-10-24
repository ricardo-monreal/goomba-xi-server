#!/usr/bin/env bash
# Goomba XI one-line installer.
#
# Game server + website (fresh Ubuntu 26.04 VM):
#   curl -fsSL https://raw.githubusercontent.com/ricardo-monreal/goomba-xi-server/main/install.sh | sudo bash
#
# File server (fresh Debian 13 LXC):
#   curl -fsSL https://raw.githubusercontent.com/ricardo-monreal/goomba-xi-server/main/install.sh | sudo bash -s -- --file-server
#
# It installs git, puts this repository in /opt/goomba-xi-server and runs the real installer
# (bin/goomba install, or tools/setup-file-server.sh with any extra options you pass).
# Set GOOMBA_REPO / GOOMBA_BRANCH to install from a fork or a Git mirror.

set -Eeuo pipefail

REPO="${GOOMBA_REPO:-https://github.com/ricardo-monreal/goomba-xi-server}"
BRANCH="${GOOMBA_BRANCH:-main}"
DIR="/opt/goomba-xi-server"

[[ $EUID -eq 0 ]] || { echo "run with sudo: curl -fsSL <url>/install.sh | sudo bash" >&2; exit 1; }

role=server
if [[ "${1:-}" == "--file-server" ]]; then role=files; shift; fi

export DEBIAN_FRONTEND=noninteractive
if ! command -v git >/dev/null; then
  apt-get update -q
  apt-get install -y -q --no-install-recommends git ca-certificates
fi

if [[ -d "$DIR/.git" ]]; then
  git -C "$DIR" pull --ff-only
else
  git clone --branch "$BRANCH" "$REPO" "$DIR"
fi

if [[ "$role" == files ]]; then
  exec bash "$DIR/tools/setup-file-server.sh" "$@"
else
  exec bash "$DIR/bin/goomba" install "$@"
fi
