#!/bin/bash

# === Verificar si estás en la raíz del repositorio Git ===
if git rev-parse --is-inside-work-tree > /dev/null 2>&1; then
  repo_root=$(git rev-parse --show-toplevel)
  current_dir=$(pwd)

  if [ "$repo_root" != "$current_dir" ]; then
    echo "❌ No estás en la raíz del repositorio Git."
    echo "📍 Estás en: $current_dir"
    echo "🔝 Raíz del repo: $repo_root"
    echo "🛑 Por favor, ejecutá este script desde la raíz del repo."
    exit 1
  else
    echo "✅ Estás en la raíz del repositorio Git: $repo_root"
  fi
else
  echo "❌ Este directorio no está dentro de un repositorio Git."
  exit 1
fi

# === Verificar si Portainer está desplegado ===
if ! docker service ls | grep -q "portainer_portainer"; then
  echo "🔍 Portainer no está desplegado. Procediendo con instalación..."

  # Descargar el archivo de stack de Portainer
  echo "⬇️ Descargando docker-stack.yml de Portainer..."
  curl -fsSL -o docker-compose_portainer.yml https://raw.githubusercontent.com/portainer/portainer-compose/master/docker-stack.yml || {
    echo "❌ Error al descargar docker-compose_portainer.yml"
    exit 1
  }

  # Inicializar Swarm si no está iniciado
  if ! docker info | grep -q "Swarm: active"; then
    echo "🌀 Inicializando Docker Swarm..."
    docker swarm init || {
      echo "❌ Error al iniciar Docker Swarm"
      exit 1
    }
  else
    echo "✅ Docker Swarm ya está activo."
  fi

  # Desplegar Portainer
  echo "🚀 Desplegando Portainer..."
  docker stack deploy -c docker-compose_portainer.yml portainer || {
    echo "❌ Falló el despliegue de Portainer"
    exit 1
  }

  echo "✅ Portainer desplegado exitosamente. Accedé en http://localhost:9000"
else
  echo "✅ Portainer ya está desplegado. Continuando..."
fi

# === Continuar con el despliegue de Frappe ERP ===

# Clonar el repo si no existe
REPO_DIR="frappe_docker-Generic"
if [ ! -d "$REPO_DIR" ]; then
  git clone https://github.com/OffShur3/frappe_docker-Generic
fi
cd "$REPO_DIR" || exit 1

RESERVED_PORTS=(22 25 53 443 3306 5432 6379 8000 8443 9000)
TEMPLATE="pwd.yml"

if [ ! -f "$TEMPLATE" ]; then
  echo "❌ No se encuentra el archivo de plantilla '$TEMPLATE'"
  exit 1
fi

function is_reserved_port() {
  for p in "${RESERVED_PORTS[@]}"; do
    if [[ "$1" == "$p" ]]; then
      return 0
    fi
  done
  return 1
}

function is_valid_name() {
  [[ "$1" =~ ^[a-zA-Z0-9_-]+$ ]]
}

# Preguntar nombre de la instancia
while true; do
  read -p "Nombre del proyecto/instancia (sin espacios, solo letras, números, guiones o guiones bajos): " PROJECT_NAME
  if [[ -z "$PROJECT_NAME" ]]; then
    echo "❌ El nombre no puede estar vacío."
    continue
  fi
  if ! is_valid_name "$PROJECT_NAME"; then
    echo "❌ El nombre contiene caracteres inválidos. Usá solo letras, números, guiones (-) o guiones bajos (_)."
    continue
  fi
  break
done

# Puerto para frontend
while true; do
  read -p "Puerto a usar para el acceso web (evitar puertos comunes): " CUSTOM_PORT
  if ! [[ "$CUSTOM_PORT" =~ ^[0-9]+$ ]]; then
    echo "❌ Ingresá un número de puerto válido."
    continue
  fi
  if is_reserved_port "$CUSTOM_PORT"; then
    echo "❌ El puerto $CUSTOM_PORT está reservado. Elegí otro."
    continue
  fi
  if lsof -iTCP:"$CUSTOM_PORT" -sTCP:LISTEN -t >/dev/null ; then
    echo "❌ El puerto $CUSTOM_PORT ya está en uso por otro proceso. Probá con otro."
    continue
  fi
  break
done

# Generar stack y red personalizada
OUTPUT_FILE="stack-${PROJECT_NAME}.yml"
sed "s/frappe_network/${PROJECT_NAME}_net/g; s/8080:8080/${CUSTOM_PORT}:8080/g" "$TEMPLATE" > "$OUTPUT_FILE"

echo "✅ Stack generado: $OUTPUT_FILE"
echo "🧠 Creando red overlay si no existe: ${PROJECT_NAME}_net"
docker network inspect "${PROJECT_NAME}_net" >/dev/null 2>&1 || docker network create --driver overlay "${PROJECT_NAME}_net"

# Deploy del stack usando Swarm
echo "🚀 Desplegando stack con nombre '$PROJECT_NAME'..."
docker stack deploy -c "$OUTPUT_FILE" "$PROJECT_NAME"

echo "✅ Despliegue completado. Accedé en http://localhost:$CUSTOM_PORT"
