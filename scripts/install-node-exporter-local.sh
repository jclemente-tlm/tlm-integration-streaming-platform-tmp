#!/bin/bash

# Versión por defecto de Node Exporter
NODE_EXPORTER_VERSION=${NODE_EXPORTER_VERSION:-"1.8.2"}
echo "📦 Usando Node Exporter versión: $NODE_EXPORTER_VERSION"

# Función principal de instalación
install_node_exporter() {
    echo "🚀 Instalando Node Exporter localmente..."

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

    # Crear servicio systemd con puerto por defecto (9100)
    echo "[Unit]
Description=Node Exporter
After=network.target

[Service]
User=node_exporter
ExecStart=/usr/local/bin/node_exporter

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
    timeout 10 bash -c "until nc -z localhost 9100; do sleep 1; done" || {
        echo "❌ Error: Node Exporter no está escuchando en el puerto 9100"
        exit 1
    }

    echo "✅ Node Exporter está ejecutándose correctamente en el puerto 9100"
}

# Ejecutar la instalación
install_node_exporter