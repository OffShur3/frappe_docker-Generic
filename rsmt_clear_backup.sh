#!/bin/bash

set -euo pipefail

docker compose -p rsmt -f /home/matias/composes/frappe_docker-Generic/docker-compose-rsmt.yml down

BASE="/var/lib/docker/volumes"
REGEX_DATE='^[0-9]{4}-[0-9]{2}-[0-9]{2}$'

echo "🧽 Buscando snapshots con nombre de fecha..."

for dir in "$BASE"/rsmt_*; do
    snap_dir="$dir/snapshots"
    [[ -d "$snap_dir" ]] || continue

    # Buscar subvolúmenes con nombre de fecha
    date_snaps=()
    for snap in "$snap_dir"/*; do
        name=$(basename "$snap")
        if [[ "$name" =~ $REGEX_DATE ]]; then
            date_snaps+=("$snap")
        fi
    done

    num_snapshots=${#date_snaps[@]}
    echo "📦 $dir tiene $num_snapshots snapshots con nombre de fecha."

    if (( num_snapshots > 10 )); then
        echo "⚠️  Hay más de 10 snapshots con fecha. Se eliminarán los más antiguos..."

        # Ordenar y borrar los más antiguos, dejando los 10 más recientes
        to_delete=($(printf '%s\n' "${date_snaps[@]}" | sort | head -n -10))

        for snap in "${to_delete[@]}"; do
            echo "🗑️  Borrando $snap"
            btrfs subvolume delete "$snap"
        done
    else
        echo "✅ No hay más de 10 snapshots de fecha, no se borra nada en $dir."
    fi
done

echo "🧼 Limpieza finalizada."

docker compose -p rsmt -f /home/matias/composes/frappe_docker-Generic/docker-compose-rsmt.yml up -d
