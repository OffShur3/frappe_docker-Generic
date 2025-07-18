#!/bin/bash

set -e

echo "🔍 Verificando si estás en la raíz de un repositorio Git..."
if git rev-parse --is-inside-work-tree > /dev/null 2>&1; then
  repo_root=$(git rev-parse --show-toplevel)
  current_dir=$(pwd)
  if [ "$repo_root" != "$current_dir" ]; then
    echo "❌ Ejecutá el script desde la raíz del repo: $repo_root"
    exit 1
  fi
else
  echo "❌ No estás en un repositorio Git. Abortando."
  exit 1
fi

# === PORTAINER DEPLOY ===
if ! docker service ls | grep -q "portainer_portainer"; then
  echo "🚀 Desplegando Portainer..."

  docker swarm init 2>/dev/null || echo "ℹ️ Swarm ya inicializado."

  curl -fsSL -o docker-compose_portainer.yml https://raw.githubusercontent.com/portainer/portainer-compose/master/docker-stack.yml

  docker stack deploy -c docker-compose_portainer.yml portainer

  echo "✅ Portainer desplegado: http://localhost:9000"
else
  echo "✅ Portainer ya estaba desplegado."
fi

# === CLONAR REPO SI NO EXISTE ===
REPO_DIR="frappe_docker-Generic"
if [ ! -d "$REPO_DIR" ]; then
  echo "📦 Clonando repositorio Frappe..."
  git clone https://github.com/OffShur3/frappe_docker-Generic
fi
cd "$REPO_DIR"

# === PEDIR CONFIGURACIÓN AL USUARIO ===
read -p "📛 Nombre del proyecto (ej: gcnet): " PROJECT_NAME
read -p "🌐 Puerto web (ej: 8090): " CUSTOM_PORT

RESERVED_PORTS=(22 25 53 443 3306 5432 6379 8000 8443 9000)
for p in "${RESERVED_PORTS[@]}"; do
  if [[ "$CUSTOM_PORT" == "$p" ]]; then
    echo "❌ Puerto reservado. Elegí otro."
    exit 1
  fi
done

TEMPLATE="pwd.yml"
if [ ! -f "$TEMPLATE" ]; then
  echo "❌ No se encuentra la plantilla: $TEMPLATE"
  exit 1
fi

OUTPUT_FILE="stack-${PROJECT_NAME}.yml"
sed "s/frappe_network/${PROJECT_NAME}_net/g; s/8080:8080/${CUSTOM_PORT}:8080/g" "$TEMPLATE" > "$OUTPUT_FILE"

# CREAR RED OVERLAY (Portainer puede usarla luego)
docker network inspect "${PROJECT_NAME}_net" >/dev/null 2>&1 || \
  docker network create --driver overlay "${PROJECT_NAME}_net"

echo "✅ Stack generado: $OUTPUT_FILE"
echo
echo "🔗 Cargá este archivo en Portainer manualmente para que tenga control total:"
echo "   ➤ Navegá a http://localhost:9000 → Stacks → + Add Stack"
echo "   ➤ Elegí *Upload* y subí '${OUTPUT_FILE}'"
echo "   ➤ O copiá y pegá su contenido."
echo
echo "📂 Archivo YAML completo: $(realpath "$OUTPUT_FILE")"
