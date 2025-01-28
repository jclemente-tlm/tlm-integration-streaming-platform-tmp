#!/bin/bash

# Configurar logging
LOG_FILE="./logs/deploy_$(date +%Y%m%d_%H%M%S).log"
exec 1> >(tee -a "$LOG_FILE") 2>&1

# set -euo pipefail

# Función para mostrar ayuda
function show_help() {
    echo "Uso: $0 <ambiente> [componente]"
    echo ""
    echo "Despliega los componentes especificados en el ambiente dado."
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
deploy_env_file="./config/env/$1/deploy.env"

# Comprobar si el archivo .env existe
if [ ! -f "$deploy_env_file" ]; then
    echo "[Advertencia] El archivo $deploy_env_file no existe."

    # Sugerir la generación del archivo .env
    echo "[Info] Puedes generar el archivo de entorno usando el script generate-env.sh:"
    echo "   ./scripts/generate-env.sh $1"
    echo "[Info] Después de generarlo, asegúrate de completar todas las variables requeridas en el archivo"

    exit 1
fi

# Cargar variables de entorno
source "$deploy_env_file"
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

# Función para crear estructura de directorios remota
create_remote_dirs() {
    local component_name=$1
    local remote_ip=$2
    local pem_key_path=$3
    local base_path="/home/${REMOTE_USER}/apps/${component_name}"

    echo "[Info] Creando estructura de directorios en ${remote_ip} para ${component_name}"
    sudo ssh -i $pem_key_path ${REMOTE_USER}@${remote_ip} "mkdir -p ${base_path}/{config,plugins,env,logs}"
}

# Función para copiar archivos comunes
copy_common_files() {
    local component_name=$1
    local remote_ip=$2
    local pem_key_path=$3
    local base_path="/home/${REMOTE_USER}/apps/${component_name}"

    echo "[Info] Copiando archivos comunes a ${remote_ip} para ${component_name}"

    # Copiar scripts de gestión
    sudo scp -i $pem_key_path \
        ./scripts/deploy/aws/docker-compose-manager.sh \
        ${REMOTE_USER}@${remote_ip}:${base_path}/

    # Copiar archivos de configuración
    sudo scp -i $pem_key_path \
        ./config/env/common/common.env \
        ${REMOTE_USER}@${remote_ip}:${base_path}/env/common.env
    sudo scp -i $pem_key_path \
        $deploy_env_file \
        ${REMOTE_USER}@${remote_ip}:${base_path}/env/deploy.env

    # Copiar JMX Exporter si es necesario
    if [[ "$component_name" =~ ^(controller|broker|.*connector) ]]; then
        echo "[Info] Copiando jmx-exporter para ${component_name}"
        sudo scp -i $pem_key_path \
            -r ./plugins/jmx-exporter \
            ${REMOTE_USER}@${remote_ip}:${base_path}/plugins/jmx-exporter
    fi
}

# Función para copiar archivos específicos de componentes
copy_component_files() {
    local component_name=$1
    local remote_ip=$2
    local pem_key_path=$3
    local base_path="/home/${REMOTE_USER}/apps/${component_name}"

    # Validar que los argumentos no estén vacíos
    if [ -z "$component_name" ] || [ -z "$remote_ip" ]; then
        echo "[Error] Se requieren component_name y remote_ip"
        return 1
    fi

    case "$component_name" in
    grafana)
        echo "[Info] Copiando archivos de configuración para grafana"
        if [ ! -d "./config/monitoring/grafana" ]; then
            echo "[Error] Directorio de grafana no encontrado"
            return 1
        fi
        sudo scp -i $pem_key_path \
            -r ./config/monitoring/grafana/provisioning \
            ${REMOTE_USER}@${remote_ip}:${base_path}/config
        ;;
    prometheus)
        echo "[Info] Copiando archivos de configuración para prometheus"
        if [ ! -d "./config/monitoring/prometheus" ]; then
            echo "[Error] Directorio de prometheus no encontrado"
            return 1
        fi
        sudo scp -i $pem_key_path \
            -r ./config/monitoring/prometheus \
            ${REMOTE_USER}@${remote_ip}:${base_path}/config
        ;;
    source-connector | sink-connector)
        echo "[Info] Copiando archivos para ${component_name}"
        if [ ! -d "./plugins/converters" ]; then
            echo "[Error] Directorio de ${component_name} no encontrado"
            return 1
        fi
        sudo scp -i $pem_key_path \
            -r ./plugins/converters \
            ${REMOTE_USER}@${remote_ip}:${base_path}/plugins/converters
        ;;
    *)
        echo "[Advertencia] No hay archivos específicos para copiar para ${component_name}"
        ;;
    esac
}

# Función para desplegar un componente
deploy_component() {
    local component_name=$1
    local remote_ip=$2
    local pem_key_path=$3
    local docker_compose_file=$4
    local base_path="/home/${REMOTE_USER}/apps/${component_name}"

    echo "[Info] Desplegando ${component_name} en ${remote_ip}"

    echo "[Info] docker compose file copiado: ${docker_compose_file} "

    # Copiar archivo docker-compose
    sudo scp -i $pem_key_path \
        ${docker_compose_file} \
        ${REMOTE_USER}@${remote_ip}:${base_path}/

    # Ejecutar docker-compose
    sudo ssh -i $pem_key_path ${REMOTE_USER}@${remote_ip} \
        "cd ${base_path} && ./docker-compose-manager.sh up $(basename ${docker_compose_file})"
}

# Función para desplegar un componente completo
deploy_single_component() {
    local component_name=$1
    local remote_ip=$2
    local pem_key_path=$3
    local docker_compose_file=$4

    echo "[Info] Iniciando despliegue de ${component_name} en ${remote_ip}"
    create_remote_dirs "${component_name}" "${remote_ip}" "${pem_key_path}"
    copy_common_files "${component_name}" "${remote_ip}" "${pem_key_path}"
    copy_component_files "${component_name}" "${remote_ip}" "${pem_key_path}"
    deploy_component "${component_name}" "${remote_ip}" "${pem_key_path}" "${docker_compose_file}"
}

# Lista de componentes a desplegar
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

# Si se especifica un solo componente
if [ -n "${2:-}" ]; then
    component_name="$2"
    echo "[Info] Desplegando componente ${component_name}..."
    for component in "${components[@]}"; do
        component_array=($component)
        if [[ "${component_array[0]}" == "$component_name" ]]; then
            deploy_single_component "${component_array[0]}" "${component_array[1]}" "${component_array[2]}" "${component_array[3]}"
        fi
    done
else
    # Si no se especifica componente, desplegar todos
    echo "[Info] Desplegando todos los componentes..."
    for component in "${components[@]}"; do
        component_array=($component)
        deploy_single_component "${component_array[0]}" "${component_array[1]}" "${component_array[2]}" "${component_array[3]}"
    done
fi

echo "[Ok] Despliegue completado."
