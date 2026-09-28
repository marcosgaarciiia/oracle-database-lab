#!/usr/bin/env bash
# scripts/deployment/env/03-descargar-imagen.sh
echo "== Descargando la imagen de Oracle Database =="
echo "Imagen: $IMG"
docker pull "$IMG"
echo 
echo "== Verificando la imagen local =="
docker images | grep -i free
