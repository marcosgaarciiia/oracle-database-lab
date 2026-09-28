#!/usr/bin/env bash
# scripts/deployment/env/04-levantar-oracle.sh
echo "== Creando volumen persistente =="
docker volume create "$VOL_NAME"
echo 
echo "== Levantando contenedor Oracle 23ai =="
docker run -d \
  --name "$CONT_NAME" \
  -p "$PORT_DB":1521 \
  -p "$PORT_ORDS":8181 \
  -v "$VOL_NAME":/opt/oracle/oradata \
  --env-file config/.env \
  "$IMG"
echo 
echo "== Contenedor iniciado en segundo plano =="
docker ps --filter "name=$CONT_NAME"
