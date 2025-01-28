# Templates de Conectores

Templates para la configuración de conectores Kafka Connect.

## Estructura
- **source/**
  - **oracle/**: Templates para conectores source Oracle
- **sink/**
  - **postgresql/**: Templates para conectores sink PostgreSQL
  - **s3/**: Templates para conectores sink S3

## Variables de Configuración
Las siguientes variables serán reemplazadas automáticamente según el ambiente:

### PostgreSQL
- `{{DB_TLMCLICK_PG_HOST}}`: Host de PostgreSQL
- `{{DB_TLMCLICK_PG_PORT}}`: Puerto de PostgreSQL
- `{{DB_TLMCLICK_PG_DBNAME}}`: Nombre de la base de datos
- `{{DB_TLMCLICK_PG_USER}}`: Usuario de PostgreSQL
- `{{DB_TLMCLICK_PG_PASS}}`: Contraseña de PostgreSQL

### S3
- `{{DA_S3_REGION}}`: Región de AWS S3
- `{{DA_BUCKET_NAME}}`: Nombre del bucket S3
- `{{DA_AWS_ACCESS_KEY_ID}}`: AWS Access Key ID
- `{{DA_AWS_SECRET_ACCESS_KEY}}`: AWS Secret Access Key

## Generación de Configuraciones
```bash
./scripts/generate-configs/generate-connector-configs.sh <ambiente>
```