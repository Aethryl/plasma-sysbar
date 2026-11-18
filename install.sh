#!/usr/bin/env bash
set -euo pipefail

repo="$(dirname "$(readlink -f "$0")")"
data="${XDG_DATA_HOME:-$HOME/.local/share}"

mkdir -p "$data/plasma/plasmoids"
ln -sfn "$repo/plasmoid" "$data/plasma/plasmoids/io.github.aethryl.sysbar"
