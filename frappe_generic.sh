#!/bin/bash

# Lista de puertos reservados
RESERVED_PORTS=(22 25 53 443 3306 5432 6379 8000 8443 9000)

# Archivo plantilla base
TEMPLATE="pwd.yml"

# Verificar que exista la plantilla
if [ ! -f "$TEMPLATE" ]; then
  echo "❌ No se encuentra el archivo de plantilla '$TEMPLATE'"
  exit 1
fi

# Función para verificar si un puerto está reservado
function is_reserved_port() {
  for p in "${RESERVED_PORTS[@]}"; do
    if [[ "$1" == "$p" ]]; then
      return 0
    fi
  done
  return 1
}

# Función para validar el nombre del proyecto (alfanumérico, guiones y guiones bajos)
function is_valid_name() {
  [[ "$1" =~ ^[a-zA-Z0-9_-]+$ ]]
}

# Solicitar nombre de proyecto válido
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

# Solicitar puerto válido
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

# Crear archivo de salida
OUTPUT_FILE="docker-compose-${PROJECT_NAME}.yml"

# Reemplazar nombre de red y puerto en la plantilla
sed "s/frappe_network/${PROJECT_NAME}_net/g; s/8080:8080/${CUSTOM_PORT}:8080/g" "$TEMPLATE" > "$OUTPUT_FILE"

echo "✅ Archivo generado: $OUTPUT_FILE"
echo "👉 Para levantar la instancia, usá:"
echo "   docker compose -p ${PROJECT_NAME} -f ${OUTPUT_FILE} up -d"
