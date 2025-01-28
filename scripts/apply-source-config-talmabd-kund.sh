#!/bin/bash

# Función para mostrar ayuda
function show_help() {
    echo "Uso: $0 <ambiente> [componente]"
    echo ""
    echo "Elimina el despliegue de los componentes especificados en el ambiente dado."
    echo ""
    echo "Ambientes disponibles:"
    echo "  - dev"
    echo "  - qa"
    echo "  - prod"
    echo ""
    echo "Opciones:"
    echo "  -h, --help    Muestra esta ayuda"
    exit 1
}

# Comprobar si se solicita ayuda o si no hay argumentos
if [ "${1:-}" = "-h" ] || [ "${1:-}" = "--help" ]; then
    show_help
fi

# Comprobar que se ha pasado un ambiente como argumento
if [ -z "${1:-}" ]; then
    echo "[Error] Por favor, especifica un ambiente: dev, qa, o prod."
    show_help
fi

ssh_env_file="./config/env/$1/ssh.env"
source "$ssh_env_file"

# Ruta al archivo de entorno
deploy_env_file="./config/env/generated/$1/deploy.env"
databases_env_file="./config/env/generated/$1/databases.env"

# Comprobar si el archivo deploy.env existe
if [ ! -f "$deploy_env_file" ]; then
    echo "[Advertencia] El archivo $deploy_env_file no existe."

    # Sugerir la generación del archivo .env
    echo "[Info] Puedes generar el archivo de entorno usando el script generate-env.sh:"
    echo "   ./scripts/generate-env.sh $1"
    echo "[Info] Después de generarlo, asegúrate de completar todas las variables requeridas en el archivo"

    exit 1
fi

# Comprobar si el archivo databases.env existe
if [ ! -f "$databases_env_file" ]; then
    echo "[Advertencia] El archivo $databases_env_file no existe."

    # Sugerir la generación del archivo .env
    echo "[Info] Puedes generar el archivo de entorno usando el script generate-env.sh:"
    echo "   ./scripts/generate-env.sh $1"
    echo "[Info] Después de generarlo, asegúrate de completar todas las variables requeridas en el archivo"

    exit 1
fi

# Cargar variables de entorno
source "$deploy_env_file"
source "$databases_env_file"
echo "[Ok] Archivo de configuración cargado correctamente"
echo "================"

# Validación de las variables necesarias
echo "[Info] Comprobando las variables de entorno..."

# Comprobar que las variables esenciales no estén vacías
required_vars=(
    "CONTROLLER_1_IP"
    "CONTROLLER_2_IP"
    "BROKER_1_IP"
    "BROKER_2_IP"
    "SOURCE_CONNECT_IP"
    "SINK_CONNECT_IP"
    "MONITORING_IP"
)

for var in "${required_vars[@]}"; do
    if [ -z "${!var}" ]; then
        echo "[Error] La variable $var no está definida o está vacía en el archivo de entorno."
        exit 1
    fi
done

echo "[Ok] Todas las variables de entorno necesarias están definidas."


# Verificar que el archivo de la plantilla exista
TEMPLATE_FILE="./templates/connectors/source/oracle/source_cdc_talmabd_LIM_W1_HL_KUND.json"
if [ ! -f "$TEMPLATE_FILE" ]; then
    echo "Error: No se encontró el archivo de plantilla $TEMPLATE_FILE"
    exit 1
fi


export DB_TALMABD_HOST
export DB_TALMABD_PORT
export DB_TALMABD_USER
export DB_TALMABD_PASSWORD
export DB_TALMABD_DBNAME
export BROKER_1_IP
export BROKER_2_IP
export SOURCE_CONNECT_IP

# Leer la plantilla
TEMPLATE=$(cat "$TEMPLATE_FILE")

# Sustitución de las llaves por formato compatible con envsubst
TEMPLATE_MODIFIED=$(cat "$TEMPLATE_FILE" | sed 's/{{\([^}]*\)}}/${\1}/g')

# Realizar la sustitución con envsubst
OUTPUT_JSON=$(echo "$TEMPLATE_MODIFIED" | envsubst)

# URL del Kafka Connect REST API
CONNECTOR_URL="http://${SOURCE_CONNECT_IP}:8083/connectors"

# Realizar la solicitud POST para crear el conector
# RESPONSE=$(curl -s -o /dev/null -w "%{http_code}" -X POST -H "Content-Type: application/json" -d "$OUTPUT_JSON" "$CONNECTOR_URL")
RESPONSE=$(curl -v -s -o /dev/null -w "%{http_code}" -X POST -H "Content-Type: application/json" -d "$OUTPUT_JSON" "$CONNECTOR_URL")

# Guardar el cuerpo de la respuesta
RESPONSE_BODY=$(curl -s -X POST -H "Content-Type: application/json" -d "$OUTPUT_JSON" "$CONNECTOR_URL")

# Capturamos el código de respuesta HTTP
HTTP_CODE="${RESPONSE: -3}"

# Verificar el código de respuesta y mostrar el resultado
if [ "$HTTP_CODE" -eq 201 ]; then
    echo "Conector creado exitosamente."
elif [ "$HTTP_CODE" -eq 409 ]; then
    echo "Error: El conector ya existe (Código 409)."
    echo "Respuesta completa:"
    echo "$RESPONSE_BODY"
else
    echo "Error al crear el conector. Código de respuesta: $HTTP_CODE"
    echo "Respuesta completa:"
    echo "$RESPONSE_BODY"
    exit 1
fi