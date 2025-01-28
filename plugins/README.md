# Plugins

Este directorio contiene los plugins y extensiones necesarios para el proyecto.

## Estructura
- `converters/`: Convertidores personalizados
  - `TimestampConverter-1.2.5-FOX.jar`: Convertidor de timestamps
- `jmx-exporter/`: Exportador JMX para Prometheus
  - `jmx_prometheus_javaagent-0.20.0.jar`: Agente Java
  - `kafka-*.yml`: Configuraciones del exportador

## Notas
- Los conectores (Debezium, PostgreSQL, S3) se instalan vía Confluent Hub
- Las configuraciones de los conectores se encuentran en `templates/connectors/`
