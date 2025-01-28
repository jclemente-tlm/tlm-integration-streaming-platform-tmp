# Templates de Configuración

Este directorio contiene las plantillas para generar configuraciones de conectores y monitoreo.

## Estructura
- **connectors/**: Templates para conectores Kafka Connect
  - **source/**: Conectores source (Oracle)
  - **sink/**: Conectores sink (PostgreSQL, S3)
- **monitoring/**: Templates para herramientas de monitoreo
  - **grafana/**: Configuraciones Grafana
  - **prometheus/**: Configuraciones Prometheus

## Uso
Para generar las configuraciones finales, usa el script:
```bash
./scripts/generate-configs/generate-connector-configs.sh <ambiente>
```
Donde `<ambiente>` puede ser: dev, qa, o prod
