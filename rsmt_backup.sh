#!/bin/bash

set -euo pipefail

if [ $# -lt 1 ]; then
    echo "❌ Debes pasar el nombre del proyecto como primer argumento."
    echo "Uso: $0 <nombre_proyecto> [nombre_snapshot]"
    exit 1
fi

PROYECTNAME="$1"
echo "📂 Proyecto: $PROYECTNAME"

# Directorio base de volúmenes Docker
BASE="/var/lib/docker/volumes"

# Ruta del archivo docker-compose
COMPOSE_FILE="/home/matias/composes/frappe_docker-Generic/docker-compose-${PROYECTNAME}.yml"

# Detener servicios del proyecto
echo "🛑 Deteniendo docker compose..."
docker compose -p "$PROYECTNAME" -f "$COMPOSE_FILE" down

# 🏷️ Obtener nombre del snapshot
if [ $# -ge 2 ]; then
    SNAP_NAME="$2"
else
    read -p "¿Nombre del snapshot? (enter para usar la fecha de hoy): " SNAP_NAME
    SNAP_NAME="${SNAP_NAME:-$(date +%F)}"
fi

echo "📦 Iniciando backup con nombre: $SNAP_NAME..."

# Buscar volúmenes que empiecen con el nombre del proyecto
for dir in "$BASE"/${PROYECTNAME}_*; do
    vol_name=$(basename "$dir")
    data_dir="$dir/_data"
    snap_dir="$dir/snapshots/$SNAP_NAME"

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

# Levantar los servicios del proyecto
echo "🚀 Levantando docker compose..."
docker compose -p "$PROYECTNAME" -f "$COMPOSE_FILE" up -d
