# **Proyecto CDC con Debezium, Kafka, Kafka Connect y Kafka UI**

## 📄 **Descripción del Proyecto**
Este proyecto implementa Change Data Capture (CDC) utilizando **Debezium**, **Apache Kafka**, **Kafka Connect** y **Kafka UI**. Su objetivo es capturar y replicar cambios en bases de datos Oracle hacia destinos como PostgreSQL y S3 en tiempo real, facilitando la integración de datos y análisis en la empresa.

---
## 📁 **Estructura del Proyecto**

El proyecto está organizado en varias carpetas, cada una con su propósito específico:

- **configs**: Archivos de configuración para diferentes entornos (dev, qa, prod).
- **deploy**: Scripts de despliegue, configuraciones y Docker Compose para servicios en AWS.
- **docker-compose.yml**: Configuración principal de Docker Compose para iniciar los servicios.
- **plugins**: Archivos relacionados con los conectores y exportadores JMX.
- **resources**: Scripts y configuraciones adicionales necesarias para la integración y configuración.
- **scripts**: Scripts Shell para aplicar configuraciones, desplegar y gestionar el proyecto.
- **templates**: Plantillas para los conectores y configuraciones de monitoreo.

```bash
.
├── Makefile                     # Archivo de automatización de tareas para compilar, construir y desplegar el proyecto
├── README.md                    # Documentación principal del proyecto, con instrucciones y descripciones generales
├── config/                      # Configuraciones del sistema
│   ├── env/                     # Variables de entorno para diferentes ambientes
│   │   ├── common/              # Variables comunes a todos los entornos
│   │   │   └── common.env       # Archivo con variables de entorno compartidas
│   │   ├── generated/           # Variables generadas específicas por entorno
│   │   │   ├── README.md        # Documentación de las variables generadas automáticamente
│   │   │   ├── dev/             # Variables de entorno para desarrollo
│   │   │   ├── qa/              # Variables de entorno para entorno qa
│   │   │   └── prod/            # Variables de entorno para producción
│   │   └── templates/           # Plantillas de variables de entorno para facilitar configuración
│   └── monitoring/              # Configuración para monitoreo de la aplicación
│       ├── grafana/             # Dashboards y datasources para Grafana
│       └── prometheus/          # Configuraciones y reglas de alertas para Prometheus
│
├── deploy/                      # Archivos y configuraciones para el despliegue del proyecto
│   ├── aws/                     # Scripts y configuraciones para desplegar en AWS
│   └── docker-compose/          # Configuraciones de Docker Compose por servicio
│       ├── connectors/          # Configuraciones de conectores para Kafka Connect
│       ├── kafka/               # Configuración de brokers y controllers de Kafka
│       └── monitoring/          # Servicios relacionados con el monitoreo (Prometheus, Grafana, etc.)
│
├── docker-compose.yml           # Archivo principal para orquestar servicios con Docker Compose
├── docs/                        # Documentación del proyecto
│   ├── architecture/            # Detalles y diagramas de arquitectura del sistema
│   ├── deployment/              # Guías paso a paso para desplegar el proyecto
│   └── monitoring/              # Documentación sobre cómo configurar y usar el monitoreo
│
├── plugins/                     # Plugins y extensiones adicionales
│   ├── converters/              # Convertidores personalizados para procesar datos
│   └── jmx-exporter/            # Configuración para exportar métricas JMX
│
├── resources/                   # Recursos y scripts para bases de datos
│   ├── additional-scripts/      # Scripts adicionales para mantenimiento o tareas especiales
│   └── oracle-setup-scripts/    # Scripts específicos para configurar bases de datos Oracle
│
├── scripts/                     # Scripts de automatización de tareas
│   ├── connectors/              # Scripts para administrar conectores de Kafka
│   ├── deploy/                  # Scripts de despliegue automatizado
│   ├── generate-env.sh          # Script para generar archivos de variables de entorno
│   ├── install-node-exporter-local.sh # Instala Node Exporter localmente para monitoreo
│   └── validate-env.sh          # Script para validar que las variables de entorno sean correctas
│
└── templates/                   # Plantillas para configuraciones
    └── connectors/              # Plantillas específicas para conectores Kafka Connect
        ├── sink/                # Plantillas para configuraciones sink (PostgreSQL, S3, etc.)
        └── source/              # Plantillas para configuraciones source (Oracle, etc.)

```
---

## 🛠️ **Tecnologías Utilizadas**
- **Debezium:** Captura los cambios en la base de datos origen.
- **Apache Kafka:** Distribuye los eventos de cambio capturados.
- **Kafka Connect:** Conecta Kafka con diferentes sistemas externos (bases de datos, almacenamiento en la nube, etc.).
- **Kafka UI:** Interfaz web para gestionar y monitorear clústeres de Kafka.
- **Prometheus y Grafana:** Monitorización y visualización de métricas.
- **Docker:** Contenedores para desplegar Kafka, Kafka Connect, Kafka UI y Prometheus.

---

## 🚀 **Requisitos Previos**
- **Docker y Docker Compose:** Instalados y configurados.
- **Bases de datos Oracle/PostgreSQL:** Acceso y permisos adecuados.
- **Conocimientos básicos de Kafka, Docker y CDC.**

---

## ⚙️ **Configuración del Proyecto**

### 1. **Clonar el Repositorio**
```bash
git clone https://github.com/tlm/tlm-integration-layer.git
cd tlm-integration-layer
```

### 2. Configuración de Variables de Entorno
Puedes generar los archivos automaticamente, ejemplo:

```bash
./scripts/generate-env.sh <ambiente>
```
Donde `<ambiente>` puede ser: dev, qa, o prod

---

## 📦 Despliegue del Proyecto (local)
### 1. Levantar los Contenedores
```bash
docker compose up -d
```

### 2. Verificar Servicios
- **Kafka UI**: http://localhost:9080
- **Kafka Connect**: http://localhost:8083
- **Prometheus**: http://localhost:9090
- **Grafana**: http://localhost:3000 (usuario: admin / contraseña por defecto)

---
## 📚 **Recursos Adicionales**

- **[Documentación oficial de Debezium](https://debezium.io/documentation/)**
- **[Guía de Apache Kafka](https://kafka.apache.org/documentation/)**
- **[Kafka Connect Documentation](https://docs.confluent.io/platform/current/connect/index.html)**
- **[Kafka UI en GitHub](https://github.com/provectus/kafka-ui)**