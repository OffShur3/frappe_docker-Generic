#!/bin/bash

set -euo pipefail
BASE="/var/lib/docker/volumes"

docker compose -p rsmt -f /home/matias/composes/frappe_docker-Generic/docker-compose-rsmt.yml down

# 🏷️ Obtener nombre del snapshot
if [ $# -ge 1 ]; then
    NAME="$1"
else
    read -p "¿Nombre del snapshot? (enter para usar la fecha de hoy): " NAME
    NAME="${NAME:-$(date +%F)}"
fi

echo "📦 Iniciando backup con nombre: $NAME..."

for dir in "$BASE"/rsmt_*; do
    vol_name=$(basename "$dir")
    data_dir="$dir/_data"
    snap_dir="$dir/snapshots/$NAME"

    [[ -d "$data_dir" ]] || continue

    # Convertir en subvolumen si no lo es
    if ! btrfs subvolume show "$data_dir" &>/dev/null; then
        echo "🔧 Convirtiendo $data_dir en subvolumen..."
        tmp="$dir/_data.bak.$RANDOM"
        mv "$data_dir" "$tmp"
        btrfs subvolume create "$data_dir"
        cp -a "$tmp"/. "$data_dir"/
        rm -rf "$tmp"
    fi

    mkdir -p "$(dirname "$snap_dir")"

    if [ ! -d "$snap_dir" ]; then
        echo "📸 Creando snapshot para $vol_name → $snap_dir"
        btrfs subvolume snapshot "$data_dir" "$snap_dir"
    else
        echo "✅ Ya existe: $snap_dir"
    fi
done

echo "✅ Backup finalizado."
docker compose -p rsmt -f /home/matias/composes/frappe_docker-Generic/docker-compose-rsmt.yml up -d
