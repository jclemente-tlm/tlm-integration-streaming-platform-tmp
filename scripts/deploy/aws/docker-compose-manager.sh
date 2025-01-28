#!/bin/bash

# Uso del script
usage() {
    echo "Uso: $0 {up|down|restart} <nombre_archivo_compose>"
    echo "Ejemplo: $0 up docker-compose-app1.yml"
    exit 1
}

# Verificación de argumentos
if [ $# -lt 2 ]; then
    usage
fi

# Variables
ACTION=$1
COMPOSE_FILE_PATH=$2
ENV_FILE_COMMON_PATH="./env/common.env"
ENV_FILE_DEPLOY_PATH="./env/deploy.env"

# Función para verificar Docker
check_docker() {
    if ! command -v docker &> /dev/null; then
        echo "Error: Docker no está instalado"
        exit 1
    fi

    if ! docker info &> /dev/null; then
        echo "Error: El servicio Docker no está en ejecución o no tienes permisos"
        exit 1
    fi
}

# Función para cargar variables de entorno
load_env_file() {
    local env_file_path=$1
    if [ -f "$env_file_path" ]; then
        set -o allexport
        source "$env_file_path"
        set +o allexport
    else
        echo "Error: No se encontró el archivo .env: $env_file_path"
        exit 1
    fi
}

# Comprobar que el archivo de Docker Compose existe
if [ ! -f "$COMPOSE_FILE_PATH" ]; then
    echo "Error: No se encontró el archivo de Docker Compose: $COMPOSE_FILE_PATH"
    exit 1
fi

# Verificar Docker y cargar variables de entorno
check_docker
load_env_file "$ENV_FILE_COMMON_PATH"
load_env_file "$ENV_FILE_DEPLOY_PATH"

# Función para iniciar Docker Compose
docker_compose_up() {
    echo "Iniciando Docker Compose con $COMPOSE_FILE_PATH..."
    if ! docker compose -f "$COMPOSE_FILE_PATH" up -d; then
        echo "Error al iniciar los contenedores"
        exit 1
    fi
    echo "Contenedores iniciados exitosamente"
}

# Función para detener Docker Compose
docker_compose_down() {
    echo "Deteniendo Docker Compose con $COMPOSE_FILE_PATH..."
    if ! docker compose -f "$COMPOSE_FILE_PATH" down; then
        echo "Error al detener los contenedores"
        exit 1
    fi
    echo "Contenedores detenidos exitosamente"
}

# Función para reiniciar Docker Compose
docker_compose_restart() {
    echo "Reiniciando Docker Compose con $COMPOSE_FILE_PATH..."
    docker_compose_down
    docker_compose_up
}

# Ejecutar la acción solicitada
case "$ACTION" in
    up)
        docker_compose_up
        ;;
    down)
        docker_compose_down
        ;;
    restart)
        docker_compose_restart
        ;;
    *)
        usage
        ;;
esac

exit 0
