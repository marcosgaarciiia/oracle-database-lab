# Lab 4 · Oracle DBA Workflow I — Respuestas

> Evidencias en `docs/bitacora/lab4/evidencia/` (`script/`, `spool/`, `config/`), todas de la ejecución del
> 2026-10-25 (marcas `20261025T1643…Z` a `20261025T1646…Z`). Se citan por su sufijo, p. ej. `*_06-arranque-por-etapas.script.log`.
>
> Contexto: el Lab 3 se hizo en otro equipo. En este se reconstruyó su estado exacto a partir del repositorio
> (imagen `database/free:latest`, `05-crear-contenedor.sh` del Lab 3 y migraciones V000 + V001) antes de empezar el Lab 4.
> La imagen actual (23.26.3, base creada el 2026-07-05) difiere en dos cosas de la del PDF: la base viene en
> **ARCHIVELOG** y `$ORACLE_HOME/dbs` es un **enlace simbólico al volumen**. Ambas se comentan donde influyen.

## Puntos de control

**B.2 — ¿Cuántos archivos salieron como FUERA en el paso 3?**
**0.** En `*_00-backup-lab3.script.log` (paso 3) todos salen «dentro», incluidos los cinco datafiles de negocio de
`$ORACLE_HOME/dbs` (`academia01.dbf` … `fintech01.dbf`), y el paso 6 dice «ninguno: el volumen contiene toda la base de
datos». Motivo, confirmado en `*_01-diagnostico.script.log` (sección B): en esta imagen
`/opt/oracle/product/26ai/dbhomeFree/dbs -> /opt/oracle/oradata/dbconfig/FREE/dbs`. Es el caso «Si todo sale dentro» del
PDF: los archivos sobrevivían a `docker rm`, pero estaban en una carpeta no estándar (`dbconfig/FREE/dbs`) y dependían
de un enlace que una nueva versión de la imagen puede cambiar. Por eso la corrección (llevarlos a `FREE/FREEPDB1`) sigue
siendo necesaria.

**E.1 — Los errores de la Parte E** (`*_06-arranque-por-etapas.script.log`).
- `ORA-01507: database not mounted` en NOMOUNT: `v$database` necesita el control file, que todavía no está abierto. En
  cambio `v$parameter` sí responde (`spfile`, `control_files`, `db_name = FREE`), porque los parámetros ya están en la
  memoria de la instancia: se leyeron del SPFILE.
- `ORA-01219` en MOUNT: `dba_tables` es una vista del diccionario, que está en el tablespace SYSTEM, un datafile aún
  cerrado. En MOUNT solo responden las vistas fijas (V$/X$): `v$controlfile` da los dos control files y `v$datafile`
  conoce 16 datafiles, pero sin abrirlos.
- La SGA del `STARTUP NOMOUNT` (Total 1 603 398 928 bytes; Variable Size 436 207 616 = 416 MB; Database Buffers
  1 157 627 904 = 1104 MB; Fixed 4,8 MB; Redo 4,3 MB) coincide con `v$sga` de `*_08-memoria.spool.log`.

**G.2 — El experimento de la caché.** Ver la respuesta 17.

---

## Preguntas tipo examen

| Nº | Respuesta | Justificación |
|---|---|---|
| P1 | **A, D** | Tras `SHUTDOWN IMMEDIATE` todos los archivos comparten el SCN de checkpoint: la copia es consistente, no necesita redo y se abre con un simple `STARTUP`. No exige ARCHIVELOG ni RMAN. |
| P2 | **B** | En Standard Edition no existe `MOVE DATAFILE` online (es de Enterprise); el método válido es OFFLINE, copia con el SO, `RENAME DATAFILE` (solo cambia el control file) y ONLINE. |
| P3 | **A, C** | `STARTUP_TIME` es de la instancia y cambia en cada arranque; `CREATED` es de la base. El DBID no cambia al recrear el contenedor, una instancia monta una sola base y `v$database` responde ya en MOUNT. |
| P4 | **A, C** | En NOMOUNT la instancia tiene los parámetros en memoria (`v$parameter`) y es la etapa para `CREATE CONTROLFILE`. `dba_users` necesita OPEN; ARCHIVELOG y renombrar SYSTEM necesitan MOUNT. |
| P5 | **B** | `ALTER DATABASE ARCHIVELOG` se ejecuta en MOUNT: hace falta el control file abierto, pero no los datafiles. |
| P6 | **B** | Con SPFILE, `ALTER SYSTEM SET` sin `SCOPE` usa `SCOPE=BOTH` por defecto: memoria y SPFILE. |
| P7 | **C** | PROCESSES es un parámetro de instancia (no modificable por PDB): desde una PDB falla con ORA-65040, como se ve en el bloque 5 de `*_07-parametros-cambios.script.log`. |
| P8 | **A, C** | Se arranca con un PFILE bueno (`STARTUP PFILE=...`) y se regenera el SPFILE con `CREATE SPFILE FROM PFILE=...`. RESETLOGS es de recuperación incompleta y SHUTDOWN ABORT no arregla nada. |
| P9 | **B** | Con `MEMORY_TARGET=0` y `SGA_TARGET>0` manda ASMM; un `DB_CACHE_SIZE` fijado actúa como mínimo, no como tamaño fijo. |
| P10 | **A, D** | En servidor dedicado, la PGA contiene las áreas de trabajo (sort area) y la memoria de sesión. Shared pool, log buffer y buffer cache son SGA. |
| P11 | **C** | El COMMIT espera a que LGWR escriba el redo en los redo logs online; DBWn escribe los bloques más tarde. |
| P12 | **B, D** | PMON y SMON son obligatorios (también DBWn, LGWR y CKPT, que no están entre las opciones). ARC0 solo existe en ARCHIVELOG, RECO no es «solo si hay database links» y CJQ0 es opcional. |

---

## Preguntas de comprobación

### Respaldo

**1. ¿Por qué la copia de la Parte B es consistente? ¿Qué pasaría si se tomara con la base abierta?**
`backup-estado.sh` hace `SHUTDOWN IMMEDIATE` antes de copiar (paso 4 de la evidencia 00: «Database closed / Database
dismounted / ORACLE instance shut down»): checkpoint final, bloques sucios escritos y archivos cerrados. Todos los
datafiles quedan con el mismo SCN de checkpoint y sin transacciones a medias, así que la copia abre sin aplicar redo.
Con la base abierta, DBWn seguiría escribiendo mientras `tar` copia: cada archivo quedaría en un SCN distinto (copia
*fuzzy*) y haría falta recuperación con redo. Mi base está en ARCHIVELOG (`log_mode=ARCHIVELOG` en el inventario,
4 procesos ARCn en `*_09-procesos.spool.log`), así que ese redo existiría en los archived logs. Aun así, un `tar` en
caliente no es una copia válida: Oracle no sabría qué recuperar en cada archivo. Para copiar en caliente se usa RMAN (o el
modo `BEGIN BACKUP`) con ARCHIVELOG, que es lo que se verá en el Lab 5.

**2. ¿Para qué sirven `manifiesto.txt` y `SHA256SUMS`? ¿Qué comprueba `restaurar-estado.sh` antes de tocar nada?**
`manifiesto.txt` describe la copia: `etiqueta=lab3-final`, `fecha_utc=20261025T164459Z`, contenedor `oralab-26ai`, volumen
`oralab-26ai-data`, imagen, `git_commit=97e1bf4`, `tipo=copia en frio consistente` y `archivos_fuera_del_volumen=0`.
`SHA256SUMS` guarda la huella de cada archivo (`volumen.tar.gz`, `inventario.txt`, `manifiesto.txt`, `extras.lst`): en
`*_00-comprobar-copia.script.log` los cuatro dan «OK». `restaurar-estado.sh` ejecuta primero `sha256sum --check` y, si
falla, se detiene sin tocar el volumen. Después exige escribir el nombre del volumen como confirmación (o `--si`) y solo
entonces vacía y restaura.

**3. Define RPO y RTO con los datos de tu propia copia.**
- **RPO** (cuántos datos puedo perder): todo lo hecho después del 2026-10-25 16:44:59 UTC. Si restauro
  `backups/20261025T164328Z_lab3-final`, pierdo la reubicación de datafiles, V003, V002 (20 000 estudiantes), C##OPS_RO
  y el resto del Lab 4.
- **RTO** (cuánto tardo en volver a dar servicio): lo que tarda `restaurar-estado.sh`. La copia ocupa 473 MB comprimidos
  (volumen de 4 571 MB). El backup completo tardó unos 1 min 45 s (de 16:43:28 a 16:45:11 UTC), incluidos la parada, el
  `tar` y la espera hasta READ WRITE, que fue de solo 10 s. La restauración hace el trabajo inverso, así que estimo un RTO
  de unos 2 minutos. La medición real con un simulacro es del Lab 5.

### Diagnóstico y correcciones

**4. ¿Dónde creó Oracle los datafiles de V000 y por qué? ¿Qué parámetro habría evitado el problema?**
En `/opt/oracle/product/26ai/dbhomeFree/dbs/` (`*_01-diagnostico.script.log`, sección 4: files 16–20,
`academia01.dbf` … `fintech01.dbf`, 100 MB cada uno). V000 usó rutas relativas (`DATAFILE 'academia01.dbf'`) y
`db_create_file_dest` estaba vacío (sección 5: «vacío: sin OMF»), así que Oracle resolvió la ruta desde `$ORACLE_HOME/dbs`.
En mi imagen esa carpeta es un enlace a `/opt/oracle/oradata/dbconfig/FREE/dbs`: los archivos sí estaban en el volumen,
pero en una carpeta de configuración, no en la de datos de la PDB, y dependiendo de un enlace de la imagen. En la imagen
del PDF estaban directamente fuera del volumen y se habrían perdido con `docker rm`. Se habría evitado con
`DB_CREATE_FILE_DEST` (OMF) apuntando a `/opt/oracle/oradata`, o escribiendo la ruta absoluta en el `CREATE TABLESPACE`.

**5. ¿Por qué `ALTER TABLESPACE ... RENAME DATAFILE` no basta para mover un archivo?**
Porque no mueve nada: solo cambia la ruta que guarda el control file. El archivo tiene que existir ya en la ruta nueva,
así que antes hay que copiarlo con el sistema operativo, con el tablespace OFFLINE para que nadie escriba en él. En
`*_03-reubicar-datafiles.script.log` se ve, para cada uno de los cinco `TBS_*`: OFFLINE → copia con `cp -p` → RENAME
(«Tablespace altered») → ONLINE, donde Oracle valida la cabecera («Tablespace altered») → `MAXSIZE 1G` («Database
altered») → borrado del original. El resultado son las cinco rutas en `/opt/oracle/oradata/FREE/FREEPDB1/`, `AVAILABLE`,
`AUT=YES`, `MAX_MB=1024`. La segunda ejecución responde «Nada que reubicar» (`*_03-reubicar-idempotencia.script.log`).

**6. ¿Por qué no se edita V000 y se crea V003? ¿Por qué invalidar una contraseña es mejor que borrarla del archivo?**
V000 ya está aplicada: una migración aplicada es historia y el repositorio debe describir lo que realmente se ejecutó
(*forward-only migrations*). De hecho, gracias a eso pude reconstruir en este equipo el estado exacto del Lab 3 a partir
del repositorio. Las correcciones van en migraciones nuevas. Borrar la contraseña del archivo no sirve porque sigue en el
historial de Git, y un secreto que ha estado en un repositorio se da por comprometido. V003 la invalida:
`ALTER USER ... NO AUTHENTICATION` deja a los cinco `ADMIN_*` como cuentas de solo esquema
(`AUTHENTICATION_TYPE = NONE`, `OPEN`, en `*_04-V003__cuentas_esquema_sin_password.spool.log`). El intento de entrar
como `admin_academia` con la contraseña de V000 devuelve `ORA-01017: invalid credential or not authorized; logon denied`
(`*_04-v003-login-rechazado.script.log`).

**7. ¿Qué demuestra la prueba de persistencia y por qué se ejecuta después de reubicar?**
Que la base vive en el volumen y el contenedor es desechable. En `*_03-prueba-persistencia.script.log` se para la base, se
borra el contenedor (el volumen `oralab-26ai-data` sigue en `docker volume ls`) y se recrea con `05-crear-contenedor.sh`
v2 («El volumen ... ya contiene la base FREE: se reutiliza (sin contraseñas)»). Antes y después aparecen los mismos cinco
`TBS_*` ONLINE y las mismas tablas (Academia 3, Clínica 3, Fintech 2, Logística 3, Retail 3), y `docker port` ya solo
muestra 1521: el 8181 desapareció. Prueba extra: el `HOST_NAME` de la instancia era `226b58d98670` en el diagnóstico y
pasó a ser `2aaaadf41294` tras recrear el contenedor (evidencia 05), mientras que la base es la misma. Se ejecuta después
de reubicar porque, con la imagen del PDF, el `docker rm` habría borrado los datafiles que estaban en la capa del
contenedor. Por eso va también después del backup.

### Instancia y arranque

**8. Tres datos que pertenecen a la instancia y tres que pertenecen a la base de datos.**
De `*_05-instancia-y-base.spool.log`:
- Instancia: `INSTANCE_NAME = FREE`, `ARRANCADA = 2026-10-25 16:45:34` (cambia en cada arranque) y
  `HOST_NAME = 2aaaadf41294` (cambia al recrear el contenedor, ver respuesta 7). También la SGA de 1536 MB y los
  procesos (`db_pmon_FREE`, `db_dbw0_FREE`…, 62 de background en `*_05-instancia-so.script.log`).
- Base de datos: `DBID = 1509902213` (no cambia nunca), `CREADA = 2026-07-05` (cuando se construyó la base de la imagen)
  y `LOG_MODE = ARCHIVELOG`, además de sus archivos: 16 datafiles (3 809 MB), 3 tempfiles (60 MB), 3 miembros de redo y
  2 control files.

**9. ¿Qué lee Oracle en NOMOUNT, en MOUNT y en OPEN? Relaciónalo con ORA-01507 y ORA-01219.**
- **NOMOUNT**: lee el SPFILE (`/opt/oracle/product/26ai/dbhomeFree/dbs/spfileFREE.ora`), reserva la SGA y arranca los
  procesos (STATUS `STARTED`). `v$parameter` responde; `v$database` da ORA-01507 porque necesita el control file.
- **MOUNT**: abre los control files (`control01.ctl` y `control02.ctl`) y conoce la estructura (STATUS `MOUNTED`,
  `LOG_MODE ARCHIVELOG`, 16 datafiles conocidos), pero no la abre. `dba_tables` da ORA-01219 porque el diccionario está en
  SYSTEM, que sigue cerrado.
- **OPEN**: abre datafiles y redo online (con recuperación de instancia si hiciera falta): STATUS `OPEN`, `READ WRITE`.
(Evidencia: `*_06-arranque-por-etapas.script.log`.)

**10. ¿Por qué FREEPDB1 se abre sola tras ALTER DATABASE OPEN? ¿Qué harías si no lo hiciera?**
Porque tiene un estado guardado: `dba_pdb_saved_states` muestra `FREEPDB1 / FREE / OPEN` y el script confirma
«FREEPDB1 abierta sola en READ WRITE: el estado guardado funciona» (bloque 4 de la evidencia 06). La imagen ejecutó en su
día `ALTER PLUGGABLE DATABASE FREEPDB1 SAVE STATE`. Si se quedara en MOUNTED, las aplicaciones recibirían ORA-01109. Lo
arreglaría con `ALTER PLUGGABLE DATABASE FREEPDB1 OPEN;` y, para que no se repita, `ALTER PLUGGABLE DATABASE FREEPDB1 SAVE STATE;`.

**11. Clasifica los errores del alert log** (`*_06-alert-log.script.log`).
- `ORA-00800 [Set Priority Failed] [VKTM]` y `[LGWR]`, que aparecen en cada `Starting ORACLE instance`: es **ruido
  conocido**. Oracle intenta subir la prioridad de esos procesos y el contenedor no tiene la capacidad `CAP_SYS_NICE`. Es
  un aviso *soft*: justo después aparecen `Completed: ALTER DATABASE MOUNT` y `Completed: ALTER DATABASE OPEN`.
- `ORA-20013 DBMS_QOPATCH` (inventario de parches no legible dentro de la imagen) no aparece en las 400 últimas líneas que
  filtra el script. Si apareciera, también sería ruido conocido, porque no afecta al funcionamiento.
- `ORA-27300/27301/27302/27303` (`chdir() failed ... No such file or directory`, al principio, antes del primer
  arranque del contenedor recreado): no está en la lista de ruido conocido, así que lo **investigo** antes de excluirlo.
  Es un proceso que intentó entrar en un directorio que no existía en el contenedor nuevo; la instancia arrancó y abrió
  con normalidad justo después y no se repite en el arranque por etapas, así que lo clasifico como no bloqueante, pero lo
  dejo anotado.
(«Crash Recovery excluding pdb 2/3 which was cleanly closed» es informativo: las PDB se cerraron limpiamente.)

### Parámetros

**12. Diferencia entre `v$parameter` y `v$spparameter` con el ejemplo de `db_files`.**
`v$parameter` muestra el valor vigente en la memoria de la instancia; `v$spparameter`, lo escrito en el SPFILE para el
próximo arranque. En `*_07-parametros-cambios.script.log`, `SCOPE=MEMORY` falla con ORA-02095 (parámetro estático). Tras
`SCOPE=SPFILE` se ve `db_files 200 | 300`: 200 en memoria y 300 pendiente en el SPFILE. Tras
`ALTER SYSTEM RESET db_files SCOPE=SPFILE` queda `200 | (no especificado)`: se borró la línea del SPFILE. La verificación
final lo confirma: «db_files sin línea pendiente en el SPFILE (FALSE)».

**13. ¿Qué hace SCOPE=BOTH y cuál es el SCOPE por defecto con SPFILE?**
`SCOPE=BOTH` cambia el valor en memoria (efecto inmediato) y lo escribe en el SPFILE (sobrevive al reinicio): bloque 2,
`open_cursors 500 | 500 | Lab4: prueba SCOPE=BOTH`. Con `SCOPE=MEMORY` (bloque 1) se veía `400 | 300`: solo en memoria.
BOTH es el SCOPE por defecto cuando la instancia arrancó con SPFILE, como esta (`spfile = .../spfileFREE.ora` en
`*_07-parametros-lectura.spool.log`). Si hubiera arrancado con PFILE, el defecto sería MEMORY. Al final `open_cursors`
volvió a 300.

**14. ¿Por qué PROCESSES rechaza el cambio en memoria aunque `v$parameter` lo marque IMMEDIATE?**
`*_07-parametros-lectura.spool.log` muestra `processes 200 ... SYS_MOD = IMMEDIATE`, pero el cambio con `SCOPE=MEMORY`
falla con `ORA-02097` + `ORA-02095` (bloque 4 de la evidencia 07). PROCESSES dimensiona estructuras de la SGA que se
reservan al arrancar, así que en la práctica (y en el examen) es estático: se cambia con `SCOPE=SPFILE` y se reinicia en
una ventana de mantenimiento. La metadata orienta; la prueba decide.

**15. ¿Para qué sirve versionar el PFILE? Explica «configuration drift».**
El PFILE (`config/initFREE_lab4.ora`) es una foto legible y versionada de la configuración. Sirve de copia para arrancar si
el SPFILE se estropea (`STARTUP PFILE=...` y luego `CREATE SPFILE FROM PFILE`) y permite ver cambios con `git diff`. La
*configuration drift* es que la configuración real se aleje de la documentada por cambios que nadie registró; comparar el
PFILE de hoy con el versionado la detecta. En `*_07-pfile.script.log` el PFILE del SPFILE tiene 32 líneas y el de memoria
122. Los parámetros con valor en memoria pero sin línea en el SPFILE (`log_buffer`, `job_queue_processes`,
`optimizer_mode`, `result_cache_max_size`…) son derivados o por defecto. Cuadra con la sección 4 de la evidencia 07:
564 parámetros documentados, solo 18 no por defecto y 134 estáticos.

### Memoria y procesos

**16. ¿Qué modelo de gestión de memoria usa tu instancia? Justifícalo con tres parámetros.**
ASMM (Automatic Shared Memory Management), según `*_08-memoria.spool.log`:
- `memory_target = 0` y `memory_size = 0`: no hay AMM.
- `sga_target = 1536M`: Oracle reparte la SGA entre los componentes. En `v$sga_dynamic_components`: buffer cache
  1 024 MB, shared pool 384 MB, Shared IO Pool 80 MB y large pool 16 MB, con `FIJADO_MB = 0`, es decir, sin mínimos
  salvo el Shared IO Pool.
- `pga_aggregate_target = 512M`: la PGA se gestiona aparte, con límite duro `pga_aggregate_limit = 2G`. Ahora hay
  437 MB asignados, 0 sobreasignaciones y un 100 % de cache hit.
`db_cache_size = 0` y `shared_pool_size = 0` significan «sin mínimo fijado: que decida ASMM». El asesor
`v$sga_target_advice` da las mismas 8 967 lecturas físicas estimadas para cualquier tamaño, de 768 MB a 3 072 MB: en una
base casi sin carga más memoria no cambia nada, así que no se puede concluir que la SGA sobre.

**17. Explica las cifras de tu experimento de caché** (`*_08-experimento-cache.script.log`).
`ACA_ESTUDIANTES` tiene 20 000 filas en 244 bloques.
- Ronda 1 (caché fría, tras `FLUSH BUFFER_CACHE`): 359 lecturas lógicas y 261 físicas.
- Ronda 2 (caché caliente): 247 lógicas y 0 físicas. La misma consulta (17 600 filas ACTIVO) no fue al disco.
- `v$bh`: 245 bloques de `ACA_ESTUDIANTES` quedan en el buffer cache (244 de datos más la cabecera del segmento).

Toda lectura física acaba en una lógica: el bloque se trae a la caché y desde ahí se lee. Las 247 lógicas de la ronda 2
son el coste real de recorrer la tabla (245 bloques del segmento más un par de visitas extra). En la ronda 1 hay más
lógicas y físicas que bloques (359 y 261) porque el `FLUSH` vació también los bloques del diccionario. Al ejecutar la
primera consulta, Oracle tuvo que releer de disco bloques de SYSTEM (llamadas recursivas: definición de la tabla,
estadísticas…); en la ronda 2 ya estaban en memoria. Tasa de acierto: ronda 1 = 1 − 261/359 ≈ **27 %**;
ronda 2 = 1 − 0/247 = **100 %**.

**18. ¿Por qué no se suma el RSS de los procesos para saber la memoria de la instancia?**
El RSS de cada proceso incluye las páginas de la SGA compartida que ha tocado, y son las mismas para todos: sumarlas las
contaría muchas veces. En `*_05-instancia-so.script.log` hay 62 procesos de background con entre 83 y 127 MB de RSS cada
uno (MMON llega a 299 MB en la evidencia 09); sumados darían más de 5 GB, pero `docker stats` mide 2,268 GiB para todo el
contenedor. La memoria real de la instancia es `v$sga` (≈1,5 GB) + `v$pgastat` (437 MB asignados) ≈ 2 GB, que cuadra con
`docker stats`.

**19. Relaciona el SPID de LGWR de `v$process` con el PID de /proc. ¿Por qué `docker top` muestra otro número?**
`*_09-procesos.spool.log` da `LGWR SPID = 707`, y `*_09-procesos-so.script.log` (sección 4, leyendo `/proc` dentro del
contenedor) muestra `707 … db_lgwr_FREE`: es el mismo proceso. Lo mismo con PMON 655, DBW0 705, CKPT 709, SMON 713, RECO
719, LREG 723, MMON 733 y MMNL 737. `docker top` muestra el PID visto desde el anfitrión (en la evidencia 05 los procesos
aparecen como 3551, 3555…), porque el contenedor tiene su propio espacio de nombres de PID: un mismo proceso tiene un PID
dentro y otro fuera. (La evidencia 05 se tomó antes del reinicio de la Parte E, pero aunque se tomaran a la vez los números
seguirían sin coincidir por el espacio de nombres.)
Nota: en las evidencias 05 y 09 no aparece ningún `oracleFREE` porque la sesión SQLcl auxiliar aún no había conectado.
El proceso servidor dedicado sí se ve desde Oracle: la sección 4 de la evidencia 09 muestra mi sesión `C##OPS_RO`
(SID 211, programa SQLcl, máquina DESKTOP-MARCOS) atendida por el proceso servidor con SPID 1154, uno de los 5 procesos
de tipo «servidor».

**20. ¿Qué hace PMON y qué hace SMON? Pon un ejemplo de cada uno.**
- **PMON** (*process monitor*, SPID 655): limpia los procesos de usuario que mueren. Deshace su transacción con el undo y
  libera bloqueos y recursos. Ejemplo: a un usuario se le apaga el portátil a mitad de un UPDATE; PMON hace rollback y
  libera las filas para la sesión que esperaba.
- **SMON** (*system monitor*, SPID 713): hace la recuperación de instancia al arrancar tras una caída y limpia segmentos
  temporales. Ejemplo: tras un `SHUTDOWN ABORT` o un corte de luz, en el siguiente `STARTUP` SMON aplica el redo y deshace
  lo no confirmado; el alert log lo anota como «Crash Recovery».

### Seguridad y trabajo profesional

**21. ¿Por qué C##OPS_RO y no SYSTEM para observar? ¿Qué no puede hacer C##OPS_RO?**
Por mínimo privilegio: para mirar no hace falta poder romper. Con SYSTEM, un error en un script de monitorización (o una
credencial robada) podría modificar datos o la configuración. C##OPS_RO es un usuario común (`COM = YES` en CDB$ROOT y
FREEPDB1, `*_02-cuenta-observabilidad.script.log`) con solo `CREATE SESSION`, `SET CONTAINER` y `SELECT_CATALOG_ROLE`, más
`CONTAINER_DATA = ALL` para ver las V$ y CDB_ de todos los contenedores. Toda la observación de las Partes D a H (05, 07
lectura, 08 memoria, 09 procesos) se hizo con ella. No puede leer ni modificar los datos de las tablas de negocio, ni
ejecutar DDL/DML, `ALTER SYSTEM`, `SHUTDOWN`/`STARTUP` o conectarse como SYSDBA: lo que cambia o para la base (06, 07
cambios, 08 experimento) se hizo como SYSDBA con autenticación del sistema operativo.

**22. ¿Qué dos vías de exposición de contraseñas corrige este laboratorio respecto al Lab 3?**
1. **Contraseñas en el repositorio:** V000 dejó las de los cinco propietarios de esquema en el historial de Git. Se
   corrige invalidándolas con V003 (cuentas de solo esquema, `NO AUTHENTICATION`), y se demuestra con ORA-01017.
2. **Contraseña de SYS en la línea de comandos:** el `08-aplicar-migraciones.sh` del Lab 3 construía
   `sys/$ORACLE_PWD@localhost:1521/FREEPDB1` y la pasaba a `docker exec ... sqlplus`, visible con `ps` y en los eventos de
   Docker. La v2 usa `/ as sysdba` (autenticación del SO), sin contraseña.

Además, `05-crear-contenedor.sh` v2 ya no pasa `ORACLE_PWD` al reutilizar el volumen, así que no queda en
`docker inspect`. La contraseña de C##OPS_RO viaja por la entrada estándar desde `config/.env`, que no se versiona, y el
control J.2 comprueba que ninguno de los dos secretos aparece en archivos ni en el historial.
