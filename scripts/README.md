# Scripts

Este directorio contiene todos los scripts del proyecto organizados por funcionalidad:

## Estructura
- `deploy/`: Scripts de despliegue por plataforma
  - `aws/`: Scripts para despliegue en AWS
    - `deploy.sh`: Despliegue de recursos
    - `undeploy.sh`: Limpieza de recursos
    - `docker-compose-manager.sh`: Gestión de contenedores
    - `generate-env.sh`: Generación de variables de ambiente
    - `install-docker-manager.sh`: Instalación de Docker
- `connectors/`: Scripts para gestión de conectores
  - `local/`: Configuración de conectores en local
  - `sink/`: Scripts para conectores sink (PostgreSQL, S3)
  - `source/`: Scripts para conectores source (Oracle)
- `monitoring/`: Scripts de monitoreo y observabilidad
  - `grafana/`: Generación de configs de Grafana
  - `prometheus/`: Generación de configs de Prometheus
