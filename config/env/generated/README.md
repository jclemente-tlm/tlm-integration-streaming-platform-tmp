# Archivos de Configuración Generados

Esta carpeta contiene los archivos `.env` generados para cada ambiente.

## Estructura y Propósito

Cada ambiente contiene tres archivos:

- `deploy.env`:
  - Usado para el despliegue en instancias EC2
  - Contiene IPs y configuración de acceso SSH

- `aws.env`:
  - Usado para configurar sink connectors
  - Contiene credenciales y configuración de AWS

- `databases.env`:
  - Usado para configurar source y sink connectors
  - Contiene credenciales y configuración de bases de datos


## Uso de los Archivos

1. **deploy.env**
   - Propósito: Despliegue en instancias EC2
   - Contiene: IPs y configuración SSH
   - Se usa en: Scripts de despliegue

2. **aws.env**
   - Propósito: Configuración de sink connectors
   - Contiene: Credenciales AWS y config S3
   - Se usa en: Generación de configuraciones de conectores

3. **databases.env**
   - Propósito: Configuración de source y sink connectors
   - Contiene: Credenciales y endpoints de bases de datos
   - Se usa en: Generación de configuraciones de conectores

## Instrucciones de Uso

1. Generar archivos:
   ```bash
   ./scripts/generate-env.sh <ambiente>
   ```

2. Completar valores en los archivos generados
3. Validar la configuración:
   ```bash
   ./scripts/validate-env.sh <ambiente>
   ```

## ⚠️ Notas Importantes
- Esta carpeta está excluida del control de versiones
- No commitear archivos con valores sensibles
- Mantener respaldo seguro de las configuraciones