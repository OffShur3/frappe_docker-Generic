#!/bin/bash

set -euo pipefail

# === CONFIGURACIÓN ===
if [ $# -lt 1 ]; then
    echo "❌ Debes pasar el nombre del proyecto como primer argumento."
    echo "Uso: $0 <nombre_proyecto>"
    exit 1
fi

PROYECTNAME="$1"
echo "📂 Proyecto: $PROYECTNAME"

# Directorio base de volúmenes Docker
BASE="/var/lib/docker/volumes"

# Ruta del archivo docker-compose
COMPOSE_FILE="/home/matias/composes/frappe_docker-Generic/docker-compose-${PROYECTNAME}.yml"

# Regex de nombre de snapshot con fecha YYYY-MM-DD
REGEX_DATE='^[0-9]{4}-[0-9]{2}-[0-9]{2}$'

# === DEPENDENCIAS ===
command -v fzf >/dev/null 2>&1 || {
    echo "❌ fzf no está instalado. Instalalo con: sudo zypper install fzf"
    exit 1
}

# === DETENER CONTENEDORES ===
echo "🛑 Deteniendo docker compose..."
docker compose -p "$PROYECTNAME" -f "$COMPOSE_FILE" down

# === BUSCAR Y LIMPIAR SNAPSHOTS ===
echo "🧽 Buscando snapshots con nombre de fecha..."

for dir in "$BASE"/${PROYECTNAME}_*; do
    snap_dir="$dir/snapshots"
    [[ -d "$snap_dir" ]] || continue

    date_snaps=()
    for snap in "$snap_dir"/*; do
        name=$(basename "$snap")
        if [[ "$name" =~ $REGEX_DATE ]]; then
            date_snaps+=("$snap")
        fi
    done

    num_snapshots=${#date_snaps[@]}
    echo "📦 $(basename "$dir") tiene $num_snapshots snapshots con nombre de fecha."

    if (( num_snapshots > 10 )); then
        echo "⚠️  Hay más de 10 snapshots. Se eliminarán los más antiguos, dejando los 10 más recientes..."
        to_delete=($(printf '%s\n' "${date_snaps[@]}" | sort | head -n -10))

        for snap in "${to_delete[@]}"; do
            echo "🗑️  Borrando $snap"
            btrfs subvolume delete "$snap"
        done
    else
        echo "✅ No hay más de 10 snapshots, no se borra nada en $(basename "$dir")."
    fi
done

echo "🧼 Limpieza finalizada."

# === LEVANTAR CONTENEDORES ===
echo "🚀 Levantando docker compose..."
docker compose -p "$PROYECTNAME" -f "$COMPOSE_FILE" up -d
