#!/bin/bash

# Configurar logging
LOG_FILE="./logs/node_exporter_uninstall_$(date +%Y%m%d_%H%M%S).log"
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
        echo "[Sugerencia] Por favor, verifica el archivo de configuración"
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

uninstall_node_exporter() {
    local component_name=$1
    local remote_ip=$2
    local pem_key_path=$3
    local custom_port=$4

    echo "[Info] Desinstalando Node Exporter en $remote_ip..."

#     sudo ssh -i "$pem_key_path" -o StrictHostKeyChecking=no "${REMOTE_USER}@$remote_ip" <<EOF
#     # Detener y deshabilitar el servicio
#     sudo systemctl stop node_exporter
#     sudo systemctl disable node_exporter

#     # Eliminar el servicio systemd
#     sudo rm -f /etc/systemd/system/node_exporter.service
#     sudo systemctl daemon-reload

#     # Eliminar el binario
#     sudo rm -f /usr/local/bin/node_exporter

#     # Eliminar el usuario
#     sudo userdel node_exporter

#     echo "[Ok] Node Exporter desinstalado correctamente de $remote_ip"
#     echo "======"
# EOF

    sudo ssh -i "$pem_key_path" -T -o StrictHostKeyChecking=no "${REMOTE_USER}@$remote_ip" <<EOF
    set -e  # Detener el script en caso de error

    echo "[Info] Iniciando desinstalación de Node Exporter en $remote_ip..."

    # Detener y deshabilitar el servicio
    if systemctl is-active --quiet node_exporter; then
        sudo systemctl stop node_exporter
    fi

    if systemctl is-enabled --quiet node_exporter; then
        sudo systemctl disable node_exporter
    fi

    # Eliminar el servicio systemd
    if [ -f /etc/systemd/system/node_exporter.service ]; then
        sudo rm -f /etc/systemd/system/node_exporter.service
        sudo systemctl daemon-reload
    fi

    # Eliminar el binario
    if [ -f /usr/local/bin/node_exporter ]; then
        sudo rm -f /usr/local/bin/node_exporter
    fi

    # Eliminar el usuario
    if id "node_exporter" &>/dev/null; then
        sudo userdel -r node_exporter
    fi

    echo "[Ok] Node Exporter desinstalado correctamente de $remote_ip"
    echo "======"
EOF
}

# Lista de instancias donde se desinstalará Node Exporter
declare -a components=(
    "controller1 ${CONTROLLER_1_IP} ${CONTROLLER_1_PEM_KEY_PATH} 29092"
    "controller2 ${CONTROLLER_2_IP} ${CONTROLLER_2_PEM_KEY_PATH} 29092"
    "broker1 ${BROKER_1_IP} ${BROKER_1_PEM_KEY_PATH} 39092"
    "broker2 ${BROKER_2_IP} ${BROKER_2_PEM_KEY_PATH} 39092"
    "source-connector ${SOURCE_CONNECT_IP} ${SOURCE_CONNECT_PEM_KEY_PATH} 8080"
    "sink-connector ${SINK_CONNECT_IP} ${SINK_CONNECT_PEM_KEY_PATH} 8080"
)

# Bucle para desinstalar Node Exporter en cada instancia
echo "[Info] Iniciando proceso de desinstalación de Node Exporter en ${#components[@]} instancias..."
for component_info in "${components[@]}"; do
    IFS=" " read -r component_name remote_ip pem_key_path custom_port <<< "$component_info"
    uninstall_node_exporter "${component_name}" "${remote_ip}" "${pem_key_path}" "${custom_port}"
done

echo "[Ok] Desinstalación completada en todas las instancias."
