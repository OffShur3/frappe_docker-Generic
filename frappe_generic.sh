#!/bin/bash

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

# === Continuar con el resto del script original ===

git clone https://github.com/OffShur3/frappe_docker-Generic
cd frappe_docker-Generic

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

OUTPUT_FILE="docker-compose-${PROJECT_NAME}.yml"
sed "s/frappe_network/${PROJECT_NAME}_net/g; s/8080:8080/${CUSTOM_PORT}:8080/g" "$TEMPLATE" > "$OUTPUT_FILE"

echo "✅ Archivo generado: $OUTPUT_FILE"
echo "👉 Para levantar la instancia, se usó:"
echo "   docker compose -p ${PROJECT_NAME} -f ${OUTPUT_FILE} up -d"
docker compose -p ${PROJECT_NAME} -f ${OUTPUT_FILE} up -d
