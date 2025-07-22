#!/bin/bash

set -e

# === CONFIGURACION INICIAL ===
REPO_URL="https://github.com/OffShur3/frappe_docker-Generic"
REPO_DIR="frappe_docker-Generic"
TEMPLATE_FILE="pwd.yml"
RESERVED_PORTS=(22 25 53 80 443 3306 5432 6379 8000 8443 9000)

# === FUNCIONES UTILES ===
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

function check_and_clone_repo() {
  # Si ya estamos en el repositorio, continuar
  if git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
    repo_root=$(git rev-parse --show-toplevel)
    if [[ "$repo_root" =~ "$REPO_DIR" ]]; then
      echo "ℹ️ Ya estás en el repositorio $REPO_DIR"
      cd "$repo_root"
      return
    fi
  fi

  # Si no existe el directorio del repo, clonarlo
  if [ ! -d "$REPO_DIR" ]; then
    echo "📦 Clonando repositorio Frappe..."
    git clone "$REPO_URL" "$REPO_DIR"
  fi

  cd "$REPO_DIR"
}

# === PORTAINER CON DOCKER COMPOSE ===
function setup_portainer() {
  # Verificar si ya hay un contenedor portainer corriendo
  if docker ps --filter "ancestor=portainer/portainer-ce" --format '{{.Names}}' | grep -q .; then
    echo "✅ Portainer ya está en ejecución."
    return
  fi

  # Verificar si el puerto 9000 ya está en uso
  if lsof -iTCP:9000 -sTCP:LISTEN -t >/dev/null ; then
    echo "⚠️ El puerto 9000 ya está en uso. Asumimos que Portainer (u otro servicio) ya está corriendo."
    return
  fi

  echo "🚀 Configurando Portainer con Docker Compose..."

  # Crear archivo compose para Portainer si no existe
  cat <<EOF > docker-compose-portainer.yml
services:
  portainer:
    image: portainer/portainer-ce:latest
    ports:
      - "9000:9000"
    volumes:
      - /var/run/docker.sock:/var/run/docker.sock
      - portainer_data:/data
    restart: unless-stopped

volumes:
  portainer_data:
EOF

  docker compose -f docker-compose-portainer.yml up -d
  echo "✅ Portainer desplegado: http://localhost:9000"
}

# === CONFIGURACION DEL PROYECTO FRAPPE ===
function configure_frappe_project() {
  # Verificar que exista la plantilla
  if [ ! -f "$TEMPLATE_FILE" ]; then
    echo "❌ No se encuentra el archivo de plantilla '$TEMPLATE_FILE'"
    exit 1
  fi

  # Solicitar nombre del proyecto
  while true; do
    read -p "📛 Nombre del proyecto (ej: gcnet): " PROJECT_NAME
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

  # Solicitar puerto
  while true; do
    read -p "🌐 Puerto web (ej: 8090): " CUSTOM_PORT
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

  # Generar archivo compose
  OUTPUT_FILE="docker-compose-${PROJECT_NAME}.yml"
  sed "s/frappe_network/${PROJECT_NAME}_net/g; s/8080:8080/${CUSTOM_PORT}:8080/g" "$TEMPLATE_FILE" > "$OUTPUT_FILE"

  # Crear red si no existe
  # if ! docker network inspect "${PROJECT_NAME}_net" >/dev/null 2>&1; then
  #   docker network create "${PROJECT_NAME}_net"
  # fi

  echo "✅ Stack generado: $OUTPUT_FILE"

  # Desplegar el proyecto
  echo "🚀 Desplegando proyecto $PROJECT_NAME..."
  echo "🔧 Comando ejecutado:"
  echo "    docker compose -p \"$PROJECT_NAME\" -f \"$OUTPUT_FILE\" up -d"
  docker compose -p "$PROJECT_NAME" -f "$OUTPUT_FILE" up -d

  echo "🎉 ¡Listo! El proyecto $PROJECT_NAME está en ejecución."
  echo "🔗 Accedé en: http://localhost:${CUSTOM_PORT}"
}

# === EJECUCION PRINCIPAL ===
check_and_clone_repo
setup_portainer
configure_frappe_project
