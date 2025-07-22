#!/bin/bash

set -euo pipefail

# === CONFIGURACIÓN ===
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
COMPOSE_FILE="/home/matias/composes/frappe_docker-Generic/docker-compose-"$PROYECTNAME".yml"

# === DEPENDENCIAS ===
command -v fzf >/dev/null 2>&1 || {
  echo "❌ fzf no está instalado. Instalalo con: sudo zypper install fzf"
  exit 1
}

# === DETENER CONTENEDORES ===
echo "🛑 Deteniendo docker compose..."
docker compose -p "$PROYECTNAME" -f "$COMPOSE_FILE" down

# === SELECCIONAR VOLUMEN ===
vol_dir=$(find "$BASE"/"$PROYECTNAME"_* -maxdepth 0 -type d | fzf --prompt="🔍 Elegí el volumen a restaurar: ")
[[ -z "$vol_dir" ]] && { echo "❌ No se seleccionó volumen."; exit 1; }

# === SELECCIONAR SNAPSHOT ===
snap_dir=$(find "$vol_dir/snapshots"/* -maxdepth 0 -type d 2>/dev/null | fzf --prompt="📸 Elegí el snapshot para restaurar: ")
[[ -z "$snap_dir" ]] && { echo "❌ No se seleccionó snapshot."; exit 1; }

# === CONFIRMAR ===
echo "⚠️ Se restaurará el snapshot: $(basename "$snap_dir") en el volumen: $(basename "$vol_dir")"
read -p "¿Confirmás la restauración? Esto reemplazará completamente el subvolumen _data. (s/N): " conf
[[ "$conf" =~ ^[Ss]$ ]] || exit 0

# === BACKUP Y RESTAURACIÓN ===
timestamp=$(date +%s)
echo "📦 Moviendo _data actual a _data.bak.$timestamp"
mv "$vol_dir/_data" "$vol_dir/_data.bak.$timestamp"

echo "🔁 Restaurando snapshot..."
btrfs subvolume snapshot "$snap_dir" "$vol_dir/_data"

echo "✅ Restauración completada."
echo "📁 Backup anterior guardado en: $vol_dir/_data.bak.$timestamp"

echo ""
echo "📌 Para volver al estado anterior, podés ejecutar:"
echo "sudo btrfs subvolume snapshot $vol_dir/_data.bak.$timestamp $vol_dir/_data"

# === INICIAR CONTENEDORES NUEVAMENTE ===
echo "🚀 Levantando servicios Docker..."
docker compose -p "$PROYECTNAME" -f "$COMPOSE_FILE" up -d
