# Scripts de Conectores

Esta carpeta contiene los scripts relacionados con la gestión y configuración de conectores Kafka Connect.

## Estructura
- source/
  - oracle/
    - `apply-source-oracle-config.sh`: Configura conectores source de Oracle
- sink/
  - postgresql/
    - `apply-sink-postgresql-config.sh`: Configura conectores sink de PostgreSQL
  - s3/
    - `apply-sink-s3-config.sh`: Configura conectores sink de S3

## Uso
Los scripts deben ejecutarse desde la raíz del proyecto. Ejemplos:

```bash
# Configurar conectores source Oracle
./scripts/connectors/source/oracle/apply-source-oracle-config.sh

# Configurar conectores sink PostgreSQL
./scripts/connectors/sink/postgresql/apply-sink-postgresql-config.sh

# Configurar conectores sink S3
./scripts/connectors/sink/s3/apply-sink-s3-config.sh
```

## Notas
- Asegúrate de que Kafka Connect esté en ejecución antes de ejecutar estos scripts
- Verifica que los archivos de configuración JSON existan en las rutas especificadas
- Los scripts asumen que Kafka Connect está accesible en localhost:8083
