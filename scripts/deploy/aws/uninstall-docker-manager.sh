#!/bin/bash

# Configurar logging
LOG_FILE="./logs/docker_uninstall_$(date +%Y%m%d_%H%M%S).log"
exec 1> >(tee -a "$LOG_FILE") 2>&1

# Comprobar que se ha pasado un ambiente como argumento
if [ -z "$1" ]; then
    echo "[Error] Especifica un ambiente: dev, qa, o prod."
    exit 1
fi

ssh_env_file="./config/env/$1/ssh.env"
source "$ssh_env_file"

# Ruta al archivo de entorno
deploy_env_file="./config/env/generated/$1/deploy.env"

# Comprobar si el archivo .env existe
if [ ! -f "$deploy_env_file" ]; then
    echo "[Error] El archivo $deploy_env_file no existe."

    # Sugerir la generación del archivo .env
    echo "[Acción] Usa el script generate-env.sh para crear el archivo:"
    echo "   ./scripts/generate-env.sh $1"
    echo "[Acción] Completa las variables requeridas en el archivo."

    exit 1
fi

# Cargar variables de entorno
source "$deploy_env_file"
echo "[Ok] Archivo de configuración cargado."

# Validación de las variables necesarias
echo "[Info] Verificando variables..."

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
        echo "[Error] $var no definida."
        echo "[Acción] Verifica el archivo de configuración."
        exit 1
    fi
done

echo "[Ok] Variables verificadas."
echo "================"

echo "[Info] Verificando claves PEM..."

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
        echo "[Error] Clave PEM no encontrada: $key"
        exit 1
    fi

    # Ajustar permisos si es necesario
    if [ "$(stat -c %a "$key")" != "400" ]; then
        echo "[Advertencia] Ajustando permisos de la clave: $key"
        sudo chmod 400 "$key"
    fi
done

echo "[Ok] Claves PEM listas."
echo "================"

# Función para desinstalar Docker
uninstall_docker() {
    local component_name=$1
    local remote_ip=$2
    local pem_key_path=$3

    echo "[Info] Desinstalando Docker en $remote_ip..."

    # Ejecutar el script de desinstalación
    sudo ssh -i "$pem_key_path" -T -o StrictHostKeyChecking=no "${REMOTE_USER}@$remote_ip" <<EOF
    set -e  # Detener en caso de error

    echo "[Info] Verificando Docker..."
    if ! command -v docker &> /dev/null; then
        echo "[Info] Docker no instalado."
        exit 0
    fi

    echo "[Info] Deteniendo servicios Docker..."
    sudo systemctl stop docker.service
    sudo systemctl stop containerd.service

    echo "[Info] Deshabilitando servicios Docker..."
    sudo systemctl disable docker.service
    sudo systemctl disable containerd.service

    echo "[Info] Desinstalando paquetes Docker..."
    sudo apt purge -y docker-ce docker-ce-cli containerd.io \
        docker-buildx-plugin docker-compose-plugin

    echo "[Info] Eliminando archivos..."
    sudo rm -rf /var/lib/docker
    sudo rm -rf /var/lib/containerd
    sudo rm -rf /etc/docker
    sudo rm -rf /etc/containerd

    echo "[Info] Eliminando configuraciones..."
    sudo rm -f /etc/apt/keyrings/docker.asc
    sudo rm -f /etc/apt/sources.list.d/docker.list

    echo "[Info] Eliminando grupo docker..."
    sudo groupdel docker || true

    echo "[Info] Limpiando paquetes..."
    sudo apt autoremove -y
    sudo apt clean    

    sudo reboot
EOF
    echo "[Ok] Docker desinstalado en $remote_ip"
    echo "======"
}

# Lista de instancias donde se desinstalará Docker y Docker compose
declare -a components=(
    "controller1 ${CONTROLLER_1_IP} ${CONTROLLER_1_PEM_KEY_PATH}"
    "controller2 ${CONTROLLER_2_IP} ${CONTROLLER_2_PEM_KEY_PATH}"
    "broker1 ${BROKER_1_IP} ${BROKER_1_PEM_KEY_PATH}"
    "broker2 ${BROKER_2_IP} ${BROKER_2_PEM_KEY_PATH}"
    "source-connector ${SOURCE_CONNECT_IP} ${SOURCE_CONNECT_PEM_KEY_PATH}"
    "sink-connector ${SINK_CONNECT_IP} ${SINK_CONNECT_PEM_KEY_PATH}"
    "kafka-ui ${MONITORING_IP} ${MONITORING_PEM_KEY_PATH}"
    "grafana ${MONITORING_IP} ${MONITORING_PEM_KEY_PATH}"
    "prometheus ${MONITORING_IP} ${MONITORING_PEM_KEY_PATH}"
)

# Bucle para desinstalar Docker en cada instancia
echo "[Info] Iniciando desinstalación en ${#components[@]} instancias..."
for component_info in "${components[@]}"; do
    IFS=" " read -r component_name remote_ip pem_key_path <<< "$component_info"
    uninstall_docker "${component_name}" "${remote_ip}" "${pem_key_path}"
done

echo "[Ok] Desinstalación completada."
echo "[Info] Log disponible en: $LOG_FILE"
