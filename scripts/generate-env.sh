#!/bin/bash

set -euo pipefail

# Función para mostrar ayuda
function show_help() {
    echo "Uso: $0 <ambiente>"
    echo ""
    echo "Genera los archivos .env para el ambiente especificado."
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

# Validar que se ha pasado un argumento
if [ -z "${1:-}" ]; then
    echo "❌ Error: Por favor, especifica un ambiente: local, dev, qa, o prod."
    show_help
fi

# Definir ambientes permitidos y la variable ENVIRONMENT
ALLOWED_ENVIRONMENTS=("dev" "qa" "prod" "local")
ENVIRONMENT="$1"

# Validar que el ambiente sea permitido
if [[ ! " ${ALLOWED_ENVIRONMENTS[@]} " =~ " ${ENVIRONMENT} " ]]; then
    echo "❌ Error: Ambiente no válido: $ENVIRONMENT"
    echo "Ambientes permitidos: ${ALLOWED_ENVIRONMENTS[*]}"
    exit 1
fi

TEMPLATES_DIR="config/env/templates"
OUTPUT_DIR="config/env/generated/$ENVIRONMENT"

# Validar que exista el directorio de templates
if [ ! -d "$TEMPLATES_DIR" ]; then
    echo "❌ Error: No se encuentra el directorio de templates: $TEMPLATES_DIR"
    exit 1
fi

# Crear directorio si no existe
mkdir -p "$OUTPUT_DIR"

echo "🔧 Generando archivos .env para ambiente: $ENVIRONMENT"
echo "📁 Directorio de salida: $OUTPUT_DIR"
echo "----------------------------------------"

# Generar archivos .env para cada template
for template in "$TEMPLATES_DIR"/*.template.env; do
    filename=$(basename "$template" .template.env)
    output_file="$OUTPUT_DIR/${filename}.env"

    cp "$template" "$output_file"
    sed -i "s/<ENVIRONMENT>/$ENVIRONMENT/g" "$output_file"

    echo "✅ Generado: ${filename}.env"
    case "$filename" in
        "aws")
            echo "   👉 Usar para: Configuración de sink connectors"
            ;;
        "databases")
            echo "   👉 Usar para: Configuración de source y sink connectors"
            ;;
    esac
done

echo "----------------------------------------"
echo "✨ Archivos .env generados exitosamente en: $OUTPUT_DIR"
echo ""
echo "📝 Próximos pasos:"
echo "1. Completa los valores en los archivos generados:"
echo "   - aws.env       → Para configuración de sink connectors"
echo "   - databases.env → Para configuración de source/sink connectors"
echo ""
echo "2. Valida la configuración:"
echo "   ./scripts/validate-env.sh $ENVIRONMENT"