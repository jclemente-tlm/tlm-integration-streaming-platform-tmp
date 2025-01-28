#!/bin/bash

# Configurar logging
LOG_FILE="./logs/undeploy_$(date +%Y%m%d_%H%M%S).log"
exec 1> >(tee -a "$LOG_FILE") 2>&1

# set -euo pipefail

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
    echo "[Error] Falta especificar el ambiente"
    show_help
fi

ssh_env_file="./config/env/$1/ssh.env"
source "$ssh_env_file"

# Ruta al archivo de entorno
deploy_env_file="./config/env/$1/deploy.env"

# Comprobar si el archivo .env existe
if [ ! -f "$deploy_env_file" ]; then
    echo "[Error] El archivo $deploy_env_file no existe."

    # Sugerir la generación del archivo .env
    echo "[Acción] Puedes generar el archivo de entorno usando el script generate-env.sh:"
    echo "   ./scripts/generate-env.sh $1"
    echo "[Acción] Después de generarlo, asegúrate de completar todas las variables requeridas en el archivo"

    exit 1
fi

# Cargar variables de entorno
source "$deploy_env_file"
echo "[Ok] Archivo de configuración cargado correctamente"

# Validación de las variables necesarias
echo "[Info] Verificando variables de entorno..."

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
        echo "[Error] La variable $var no está definida"
        echo "[Info] Por favor, verifica el archivo de configuración"
        exit 1
    fi
done

echo "[Ok] Todas las variables de entorno están correctamente definidas"
echo "================"

echo "[Info] Verificando la existencia de las claves PEM..."

pem_keys=(
    "$CONTROLLER_1_PEM_KEY_PATH"
    "$CONTROLLER_2_PEM_KEY_PATH"
    "$BROKER_1_PEM_KEY_PATH"
    "$BROKER_2_PEM_KEY_PATH"
    "$SOURCE_CONNECT_PEM_KEY_PATH"
    "$SINK_CONNECT_PEM_KEY_PATH"
    "$MONITORING_PEM_KEY_PATH"
)

for key in "${pem_keys[@]}"; do
    if [ ! -f "$key" ]; then
        echo "[Error] La clave PEM no existe en la ruta especificada: $key"
        exit 1
    fi

    # Ajustar permisos si es necesario
    if [ "$(stat -c %a "$key")" != "400" ]; then
        echo "[Advertencia] Ajustando permisos de la clave PEM en $key..."
        sudo chmod 400 "$key"
    fi
done

echo "[Ok] Todos los archivos de claves PEM están listos."
echo "================"

# Función para limpiar recursos comunes
cleanup_common_files() {
    local component_name=$1
    local remote_ip=$2
    local pem_key_path=$3
    local app_path="/home/${REMOTE_USER}/apps/${component_name}"
    # local base_path="/home/${REMOTE_USER}/apps/${component_name}"

    echo "[Info] Limpiando archivos de ${component_name} en ${remote_ip}..."
    sudo ssh -i $pem_key_path ${REMOTE_USER}@${remote_ip} "sudo rm -rf ${app_path}"
    echo "[Ok] Limpieza completada para ${component_name}"
}

# Función para hacer undeploy de un componente
undeploy_component() {
    local component_name=$1
    local remote_ip=$2
    local pem_key_path=$3
    local docker_compose_file=$4
    local app_path="/home/${REMOTE_USER}/apps/${component_name}"

    # Detener y eliminar los contenedores, redes y volúmenes
    echo "[Info] Iniciando undeploy de ${component_name} en '${remote_ip}'..."
    sudo ssh -i $pem_key_path ${REMOTE_USER}@${remote_ip} "cd ${app_path} && docker compose -f $(basename ${docker_compose_file}) down --volumes --remove-orphans"

    cleanup_common_files "${component_name}" "${remote_ip}" "${pem_key_path}"
    echo "[Ok] Undeploy exitoso de ${component_name}"
}

# Lista de componentes a hacer undeploy
declare -a components=(
    "controller1 ${CONTROLLER_1_IP} ${CONTROLLER_1_PEM_KEY_PATH} ./deploy/aws/docker-compose/kafka/controller1.yml"
    "controller2 ${CONTROLLER_2_IP} ${CONTROLLER_2_PEM_KEY_PATH} ./deploy/aws/docker-compose/kafka/controller2.yml"
    "broker1 ${BROKER_1_IP} ${BROKER_1_PEM_KEY_PATH} ./deploy/aws/docker-compose/kafka/broker1.yml"
    "broker2 ${BROKER_2_IP} ${BROKER_2_PEM_KEY_PATH} ./deploy/aws/docker-compose/kafka/broker2.yml"
    "source-connector ${SOURCE_CONNECT_IP} ${SOURCE_CONNECT_PEM_KEY_PATH} ./deploy/aws/docker-compose/connectors/source.yml"
    "sink-connector ${SINK_CONNECT_IP} ${SINK_CONNECT_PEM_KEY_PATH} ./deploy/aws/docker-compose/connectors/sink.yml"
    "kafka-ui ${MONITORING_IP} ${MONITORING_PEM_KEY_PATH} ./deploy/aws/docker-compose/monitoring/kafka-ui.yml"
    "grafana ${MONITORING_IP} ${MONITORING_PEM_KEY_PATH} ./deploy/aws/docker-compose/monitoring/grafana.yml"
    "prometheus ${MONITORING_IP} ${MONITORING_PEM_KEY_PATH} ./deploy/aws/docker-compose/monitoring/prometheus.yml"
)

# Verificar si se ha pasado un componente específico para hacer undeploy
if [ -n "$2" ]; then
    # Realizar undeploy solo para el componente especificado
    echo "[Info] Haciendo undeploy solo del componente $2"
    for component_info in "${components[@]}"; do
        # IFS=" " read -r component_name remote_ip docker_compose_file <<< "$component_info"
        IFS=" " read -r component_name remote_ip pem_key_path docker_compose_file <<<"$component_info"
        if [[ "$component_name" == "$2" ]]; then
            # undeploy_component "${component_name}" "${remote_ip}" "${docker_compose_file}"
            undeploy_component "${component_name}" "${remote_ip}" "${pem_key_path}" "${docker_compose_file}"
        fi
    done
else
    # Realizar undeploy de todos los componentes
    echo "[Info] Estás a punto de hacer undeploy de todos los componentes en el ambiente $1."
    read -p "[Info] ¿Estás seguro? (yes/no): " confirm
    if [[ "$confirm" != "yes" ]]; then
        echo "[Info] Operación cancelada por el usuario."
        exit 0
    fi

    # Iterar sobre los componentes y hacer undeploy
    for component_info in "${components[@]}"; do
        IFS=" " read -r component_name remote_ip pem_key_path docker_compose_file <<<"$component_info"
        undeploy_component "${component_name}" "${remote_ip}" "${pem_key_path}" "${docker_compose_file}"
    done
fi

echo "[Ok] Proceso de undeploy completado exitosamente."
