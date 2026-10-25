# Runbook · Pérdida de un datafile de aplicación (Oracle AI Database 26ai Free, contenedor `oralab-26ai`)

Para la persona de guardia, aunque no haya hecho el Lab 5. Probado en el simulacro D (`scripts/lab5/14d-perdida-datafile.sh`).
Objetivo: **RPO = 0** (no perder ningún COMMIT) y la CDB abierta durante toda la reparación.

## 1. Síntoma
Una consulta o el alert log muestran, para el mismo archivo `n`:
- `ORA-01116: error in opening database file n` → Oracle no puede abrir el archivo.
- `ORA-01110: data file n: '/opt/oracle/oradata/FREE/FREEPDB1/…dbf'` → **qué** archivo es.
- `ORA-27041: unable to open file` + `Linux-x86_64 Error: 2: No such file or directory` → **por qué** (el sistema operativo no lo encuentra).
- A veces, además, `ORA-63999: data file suffered media failure`: Oracle ha **cerrado la PDB** entera para protegerla.

Si el archivo es de **SYSTEM o UNDO de CDB$ROOT**, este runbook NO sirve (la instancia cae): escalar y seguir el procedimiento con la base en MOUNT.

## 2. Comprobaciones previas (no tocar nada antes de esto)
```bash
docker exec -it oralab-26ai sqlplus / as sysdba
```
```sql
SELECT log_mode FROM v$database;                       -- debe ser ARCHIVELOG (si no: solo cabe restaurar la última copia en frío)
SELECT name, open_mode FROM v$pdbs;                    -- ¿la PDB sigue READ WRITE o ya está MOUNTED?
SELECT file#, name, status FROM v$datafile WHERE file# = n;
```
```bash
docker exec -it oralab-26ai rman target /
RMAN> LIST BACKUP OF DATAFILE n;                       -- tiene que haber al menos una copia COMPLETED
```
Sin copia RMAN o en NOARCHIVELOG → **parar y escalar**: no improvisar.

## 3. Reparación
**Camino A — la PDB sigue en READ WRITE** (solo ese tablespace está caído; el resto da servicio):
```sql
ALTER SESSION SET CONTAINER = FREEPDB1;
ALTER DATABASE DATAFILE n OFFLINE;
```
```
RMAN> RESTORE DATAFILE n;
RMAN> RECOVER DATAFILE n;
```
```sql
ALTER SESSION SET CONTAINER = FREEPDB1;
ALTER DATABASE DATAFILE n ONLINE;
```

**Camino B — la PDB está MOUNTED (ORA-63999)** o se está cerrando (`ORA-01089`):
1. Esperar hasta que `SELECT open_mode FROM v$pdbs WHERE name = 'FREEPDB1';` diga **MOUNTED** (nunca lanzar RMAN a mitad del cierre).
2. `RMAN> RESTORE DATAFILE n;` y `RMAN> RECOVER DATAFILE n;`
3. `ALTER SESSION SET CONTAINER = FREEPDB1; ALTER DATABASE DATAFILE n ONLINE;`
4. `ALTER PLUGGABLE DATABASE FREEPDB1 OPEN;`

Errores típicos: `ORA-01113 file needs media recovery` al poner ONLINE → falta el `RECOVER`. `RMAN-06023 no backup or copy` → no hay copia: escalar.

## 4. Verificación (el incidente no está cerrado hasta que todo esto se cumpla)
```sql
SELECT name, open_mode FROM v$pdbs;                                         -- FREEPDB1 READ WRITE
SELECT file#, status FROM v$datafile WHERE file# = n;                       -- ONLINE
ALTER SESSION SET CONTAINER = FREEPDB1;
SELECT COUNT(*) FROM admin_academia.aca_estudiantes;                        -- la tabla responde (20000)
```
Comprobar que un cambio confirmado **después** de la última copia sigue ahí (en el simulacro, la fila 104): si está, el RPO fue 0.
Después: `bash scripts/ops/ro.sh scripts/lab5/15-healthcheck.sql` y anotar los ORA- del bloque 5 como huella de este incidente.

## 5. Comunicación
- Al empezar: avisar al responsable del servicio (qué PDB/tablespace está caído y estimación de RTO).
- Al terminar: hora del fallo, hora de vuelta (RTO), datos perdidos (RPO), causa raíz y acción preventiva.
- Hacer una copia RMAN nueva de ese tablespace y abrir una retrospectiva sin culpables.
