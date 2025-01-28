#!/bin/bash

# Configurar logging
LOG_FILE="./logs/docker_install_$(date +%Y%m%d_%H%M%S).log"
exec 1> >(tee -a "$LOG_FILE") 2>&1

# Comprobar que se ha pasado un ambiente como argumento
if [ -z "$1" ]; then
    echo "[Error] Por favor, especifica un ambiente: dev, qa, o prod."
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

install_docker() {
    local component_name=$1
    local remote_ip=$2
    local pem_key_path=$3

    echo "[Info] Instalando Docker y Docker Compose en $remote_ip..."

    # Ejecutar el script de instalación
    sudo ssh -i "$pem_key_path" -T -o StrictHostKeyChecking=no "${REMOTE_USER}@$remote_ip" <<EOF
    # set -e  # Detener en caso de error

    echo "[Info] Actualizando paquetes del sistema..."
    sudo apt update && sudo apt upgrade -y
    sudo apt install -y ca-certificates curl

    echo "[Info] Configurando repositorio de Docker..."
    # Añadir la clave GPG oficial de Docker
    sudo install -m 0755 -d /etc/apt/keyrings
    sudo curl -fsSL https://download.docker.com/linux/ubuntu/gpg -o /etc/apt/keyrings/docker.asc
    sudo chmod a+r /etc/apt/keyrings/docker.asc

    # Añadir el repositorio a las fuentes de APT:
    echo \
    "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.asc] https://download.docker.com/linux/ubuntu \
    $(. /etc/os-release && echo "$VERSION_CODENAME") stable" | \
    sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
    sudo apt update


    echo "[Info] Instalando Docker y Docker Compose..."
    # Instalar Docker y Docker Compose
    sudo apt install -y docker-ce docker-ce-cli containerd.io \
    docker-buildx-plugin docker-compose-plugin

    echo "[Info] Configurando permisos de usuario..."
    # Asignación de permisos al usuario para ejecutar docker cli
    sudo groupadd docker
    sudo usermod -aG docker $REMOTE_USER
    newgrp docker

    echo "[Info] Configurando servicios..."
    # Configurar servicios para inicio automático
    sudo systemctl enable docker.service
    sudo systemctl enable containerd.service

    sudo systemctl start docker.service
    sudo systemctl start containerd.service

    echo "[Info] Realizando limpieza post-instalación..."
    sudo apt clean
    sudo apt autoremove -y

    echo "[Info] Versiones instaladas:"
    docker --version
    docker compose version    
EOF
    echo "[Ok] Instalación completada exitosamente en $remote_ip"
    echo "======"
}

# Lista de instancias donde se instalará Docker y Docker compose
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

# Bucle para desinstalar Node Exporter en cada instancia
echo "[Info] Iniciando proceso de instalación de Docker y Docker compose en ${#components[@]} instancias..."
for component_info in "${components[@]}"; do
    IFS=" " read -r component_name remote_ip pem_key_path <<< "$component_info"
    install_docker "${component_name}" "${remote_ip}" "${pem_key_path}"
done

echo "[Ok] Proceso de instalación completado"
echo "[Info] Log completo disponible en: $LOG_FILE"
