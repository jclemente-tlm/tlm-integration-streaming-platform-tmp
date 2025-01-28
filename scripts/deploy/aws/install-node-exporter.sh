#!/bin/bash

# Configurar logging
LOG_FILE="./logs/node_exporter_install_$(date +%Y%m%d_%H%M%S).log"
exec 1> >(tee -a "$LOG_FILE") 2>&1

# Comprobar que se ha pasado un ambiente como argumento
if [ -z "$1" ]; then
    echo "❌ Por favor, especifica un ambiente: dev, qa, o prod."
    exit 1
fi

common_env_file="./config/env/common/common.env"
source "$common_env_file"

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

install_node_exporter() {
    local component_name=$1
    local remote_ip=$2
    local pem_key_path=$3
    local custom_port=$4

    echo "[Info] Instalando Node Exporter en $remote_ip..."

    sudo ssh -i "$pem_key_path" -T -o StrictHostKeyChecking=no "${REMOTE_USER}@$remote_ip" <<EOF
    # Actualizar los paquetes del sistema
    sudo apt-get update -y

    # Descargar Node Exporter
    wget https://github.com/prometheus/node_exporter/releases/download/v$NODE_EXPORTER_VERSION/node_exporter-$NODE_EXPORTER_VERSION.linux-amd64.tar.gz

    # Extraer el archivo descargado
    tar xvf node_exporter-$NODE_EXPORTER_VERSION.linux-amd64.tar.gz

    # Mover el binario a /usr/local/bin
    sudo mv node_exporter-$NODE_EXPORTER_VERSION.linux-amd64/node_exporter /usr/local/bin/

    # Crear usuario para Node Exporter
    sudo useradd -rs /bin/false node_exporter

    # Crear servicio systemd con puerto personalizado
    echo "[Unit]
    Description=Node Exporter
    After=network.target

    [Service]
    User=node_exporter
    ExecStart=/usr/local/bin/node_exporter --web.listen-address=:${custom_port}

    [Install]
    WantedBy=default.target" | sudo tee /etc/systemd/system/node_exporter.service

    # Recargar systemd, habilitar y arrancar el servicio
    sudo systemctl daemon-reload
    sudo systemctl enable node_exporter
    sudo systemctl start node_exporter

    # Verificar el estado del servicio
    sudo systemctl status node_exporter --no-pager

    # Limpiar archivos temporales
    rm -rf node_exporter-$NODE_EXPORTER_VERSION.linux-amd64*

    # Verificar que el puerto está escuchando
    timeout 10 bash -c "until nc -z localhost ${custom_port}; do sleep 1; done" || {
        echo "[Error] Node Exporter no está escuchando en el puerto ${custom_port}"
        exit 1
    }

    echo "[Ok] Node Exporter está ejecutándose correctamente en el puerto ${custom_port}"
EOF

    # Verificar la instalación desde el host local
    if ! timeout 5 nc -z "$remote_ip" "$custom_port"; then
        echo "[Error] No se puede conectar a Node Exporter en ${remote_ip}:${custom_port}"
        return 1
    fi

    echo "[Ok] Node Exporter instalado y verificado en $remote_ip:$custom_port"
}

# Lista de instancias donde se instalará Node Exporter
declare -a components=(
    "controller1 ${CONTROLLER_1_IP} ${CONTROLLER_1_PEM_KEY_PATH} 29092"
    "controller2 ${CONTROLLER_2_IP} ${CONTROLLER_2_PEM_KEY_PATH} 29092"
    "broker1 ${BROKER_1_IP} ${BROKER_1_PEM_KEY_PATH} 39092"
    "broker2 ${BROKER_2_IP} ${BROKER_2_PEM_KEY_PATH} 39092"
    "source-connector ${SOURCE_CONNECT_IP} ${SOURCE_CONNECT_PEM_KEY_PATH} 8080"
    "sink-connector ${SINK_CONNECT_IP} ${SINK_CONNECT_PEM_KEY_PATH} 8080"
)

# Bucle para instalar Node Exporter en cada instancia
echo "[Info] Iniciando proceso de instalación de Node Exporter en ${#components[@]} instancias..."
for component_info in "${components[@]}"; do
    IFS=" " read -r component_name remote_ip pem_key_path custom_port <<< "$component_info"
    install_node_exporter "${component_name}" "${remote_ip}" "${pem_key_path}" "${custom_port}"
done

echo "[Ok] Instalación completada en todas las instancias."
