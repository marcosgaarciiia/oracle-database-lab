#!/usr/bin/env bash
set -euo pipefail
source scripts/deployment/env/00-config.sh
set -a; source config/.env; set +a

SQL_FILE="scripts/deployment/env/12-ords-habilitar-alumno.sql"
CONN="sys/$ORACLE_PWD@localhost:1521/$SERVICE_PDB"
LOG_DIR="docs/bitacora/evidencia/spool"
mkdir -p "$LOG_DIR"
SPOOL_LOG="$LOG_DIR/$(date -u +%Y%m%dT%H%M%SZ)_12-ords-habilitar-alumno.spool.log"

{ 
  echo "DEFINE app_pwd = \"$APP_USER_PWD\""; 
  cat "$SQL_FILE"; 
} | docker exec -i "$CONT_NAME" sqlplus -s "$CONN" as sysdba | tee "$SPOOL_LOG"
