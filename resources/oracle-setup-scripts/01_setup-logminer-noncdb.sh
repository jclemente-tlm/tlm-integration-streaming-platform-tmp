#!/bin/sh

mkdir -p "/opt/oracle/oradata/recovery_area"

# Set archive log mode and enable GG replication
ORACLE_SID=ORCL
export ORACLE_SID
sqlplus /nolog <<- EOF
	CONNECT sys/Pass1234 AS SYSDBA
  ALTER SYSTEM SET db_recovery_file_dest_size = 20G;
  ALTER SYSTEM SET db_recovery_file_dest = '/opt/oracle/oradata/recovery_area' scope=spfile;

  -- If the above has been set, you will need to restart your database
  SHUTDOWN IMMEDIATE;
  STARTUP MOUNT;

  ALTER DATABASE ARCHIVELOG;
  ALTER DATABASE OPEN;

  -- You can then view the log status again which should have updated:
  ARCHIVE LOG LIST;
	exit;
EOF

# Enable LogMiner required database features/settings
sqlplus sys/Pass1234@ORCL as sysdba <<- EOF
  ALTER DATABASE ADD SUPPLEMENTAL LOG DATA;
  ALTER PROFILE DEFAULT LIMIT FAILED_LOGIN_ATTEMPTS UNLIMITED;
  exit;
EOF

# Create Log Miner Tablespace and User
sqlplus sys/Pass1234@ORCL as sysdba <<- EOF
  CREATE TABLESPACE LOGMINER_TBS DATAFILE '/opt/oracle/oradata/ORCL/logminer_tbs.dbf' SIZE 25M REUSE AUTOEXTEND ON MAXSIZE UNLIMITED;
  exit;
EOF

sqlplus sys/Pass1234@ORCL as sysdba <<- EOF
  CREATE USER cdc_user IDENTIFIED BY cdc123 DEFAULT TABLESPACE LOGMINER_TBS QUOTA UNLIMITED ON LOGMINER_TBS;

  GRANT CREATE SESSION TO cdc_user;
  GRANT SELECT ON V_\$DATABASE TO cdc_user;
  GRANT FLASHBACK ANY TABLE TO cdc_user;
  GRANT SELECT ANY TABLE TO cdc_user;
  GRANT SELECT_CATALOG_ROLE TO cdc_user;
  GRANT EXECUTE_CATALOG_ROLE TO cdc_user;
  GRANT SELECT ANY TRANSACTION TO cdc_user;
  GRANT SELECT ANY DICTIONARY TO cdc_user;
  GRANT LOGMINING TO cdc_user;

  GRANT CREATE TABLE TO cdc_user;
  GRANT LOCK ANY TABLE TO cdc_user;
  GRANT CREATE SEQUENCE TO cdc_user;

  GRANT EXECUTE ON DBMS_LOGMNR TO cdc_user;
  GRANT EXECUTE ON DBMS_LOGMNR_D TO cdc_user;
  GRANT SELECT ON V_\$LOGMNR_LOGS to cdc_user;
  GRANT SELECT ON V_\$LOGMNR_CONTENTS TO cdc_user;
  GRANT SELECT ON V_\$LOGFILE TO cdc_user;
  GRANT SELECT ON V_\$ARCHIVED_LOG TO cdc_user;
  GRANT SELECT ON V_\$ARCHIVE_DEST_STATUS TO cdc_user;

  exit;
EOF
