#!/bin/bash

set -euo pipefail

# Función para mostrar ayuda
function show_help() {
    echo "Uso: $0 <ambiente>"
    echo ""
    echo "Valida los archivos .env generados para el ambiente especificado."
    echo ""
    echo "Ambientes disponibles:"
    echo "  - dev     (Desarrollo)"
    echo "  - qa      (Pruebas)"
    echo "  - prod    (Producción)"
    echo "  - local   (Desarrollo local)"
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
    echo "❌ Error: Por favor, especifica un ambiente: local, dev, qa, o prod."
    show_help
fi

ENVIRONMENT="$1"
ENV_DIR="config/env/generated/$ENVIRONMENT"

# Validar que exista el directorio
if [ ! -d "$ENV_DIR" ]; then
    echo "❌ Error: No se encuentra el directorio: $ENV_DIR"
    echo "Ejecuta primero: ./scripts/generate-env.sh $ENVIRONMENT"
    exit 1
fi

echo "🔍 Validando archivos .env para ambiente: $ENVIRONMENT"
echo "📁 Directorio: $ENV_DIR"
echo "----------------------------------------"

# Lista de archivos requeridos
required_files=("deploy.env" "aws.env" "databases.env")

# Contador de errores
errors=0

# Función para validar un archivo
function validate_file() {
    local file="$1"
    local full_path="$ENV_DIR/$file"
    echo "📝 Revisando $file..."

    # Verificar existencia del archivo
    if [ ! -f "$full_path" ]; then
        echo "❌ Error: Falta el archivo $file"
        errors=$((errors + 1))
        return
    fi

    # Buscar variables que aún tienen placeholders (ignorando comentarios y líneas vacías)
    local pending_vars
    pending_vars=$(grep -v "^#" "$full_path" | grep -v "^$" | grep -v "^=*$" | grep -n "<.*>" || true)

    # Buscar variables vacías (ignorando comentarios y líneas vacías)
    local empty_vars
    empty_vars=$(grep -v "^#" "$full_path" | grep -v "^$" | grep -v "^=*$" | grep -n "^[A-Z_]*=$" || true)

    if [ ! -z "$pending_vars" ]; then
        echo "⚠️  Variables pendientes de completar:"
        echo "$pending_vars"
        errors=$((errors + 1))
    fi

    if [ ! -z "$empty_vars" ]; then
        echo "⚠️  Variables vacías:"
        echo "$empty_vars"
        errors=$((errors + 1))
    fi

    if [ -z "$pending_vars" ] && [ -z "$empty_vars" ]; then
        echo "✅ Todas las variables están configuradas"
    fi

    echo "----------------------------------------"
}

# Validar cada archivo
for file in "${required_files[@]}"; do
    validate_file "$file"
done

# Resumen final
if [ $errors -eq 0 ]; then
    echo "✅ Validación exitosa: Todos los archivos están correctamente configurados"
    exit 0
else
    echo "❌ Se encontraron $errors problemas que necesitan ser corregidos"
    echo "📝 Por favor, completa todas las variables pendientes"
    exit 1
fi