# Scripts de Inicialización

Este directorio contiene los scripts necesarios para inicializar el contenedor Oracle con:

1. Configuración de LogMiner para CDC
2. Usuario y esquema OT (Oracle Tutorial) con datos de ejemplo
3. Usuario LIM para el ambiente de desarrollo

## Orden de Ejecución
1. `01_setup-logminer-noncdb.sh` - Configura LogMiner y crea usuario CDC
2. `02_ot_create_user.sql` - Crea usuario OT
3. `03_ot_schema.sql` - Crea las tablas del esquema OT
4. `04_ot_data.sql` - Inserta datos de ejemplo
5. `05_tlm_create_user.sql` - Crea usuario LIM