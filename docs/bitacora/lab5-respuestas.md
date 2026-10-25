# Lab 5 · Oracle DBA Workflow II — Respuestas

> Evidencias en `docs/bitacora/lab5/evidencia/` (`script/`, `spool/`, `config/`), todas de la ejecución del 2026-10-25
> (marcas `20261025T1855…Z` a `20261025T1907…Z`). Se citan por su sufijo, p. ej. `*_10-redo.script.log`.
>
> Contexto del entorno (influye en algunas cifras):
> - Imagen `database/free:latest` 23.26.3: la base ya venía en ARCHIVELOG, con **3 grupos de redo de 200 MB** (el PDF
>   supone 2 grupos de 20 MB).
> - Mi Lab 4 es la versión de 10 scripts, así que la comprobación inicial usa `scripts/lab4/10-verificacion-final.sh` y el
>   permiso de lectura del alert log para `C##OPS_RO` se concede antes de la Parte P (`*_15-permiso-alert-log.script.log`).
> - En `10-redo.sql` el paso 4c no se ejecuta: con 3 grupos Oracle sí permitiría borrar uno (respuesta 15).

---

## Preguntas de comprobación

### Punto de partida y banco de medida (A, B)

**1. Compara el paso 6 de tu copia lab4-final con el de la copia lab3-final. ¿Qué demuestra la diferencia?**
En las dos copias el paso 6 dice «ninguno: el volumen contiene toda la base de datos», pero por motivos distintos, y el
inventario (paso 2) lo explica:
- `lab3-final` (Lab 4, evidencia 00): los cinco datafiles de negocio estaban en
  `/opt/oracle/product/26ai/dbhomeFree/dbs/academia01.dbf`… Salían «dentro» solo porque, en mi imagen, `$ORACLE_HOME/dbs`
  es un enlace a `/opt/oracle/oradata/dbconfig/FREE/dbs`: estaban en el volumen por casualidad, en una carpeta de
  configuración y dependiendo de un enlace.
- `lab4-final` (`*_00-backup-lab4.script.log`): los mismos cinco archivos aparecen en
  `/opt/oracle/oradata/FREE/FREEPDB1/academia01.dbf` … `fintech01.dbf`, que es su carpeta estándar.

La diferencia demuestra que la reubicación del Lab 4 funcionó: ahora la base está entera en el volumen sin depender de
ningún enlace de la imagen. La copia pasó de 473 MB a 505 MB (volumen de 4 697 MB).

**2. Calcula el bfr de CLIENTE y de PEDIDO. ¿Por qué PEDIDO cabe casi el triple de filas por bloque?**
De `*_01-perfil-tiendasur.script.log`:
- CLIENTE: r = 100 000 filas, b = 1 517 bloques, R = 102 bytes → bfr = r / b = 100 000 / 1 517 ≈ **66**. Con la fórmula,
  b = ⌈100 000 / 66⌉ = 1 516, frente a 1 517 medidos: bfr es una media y no todos los bloques tienen las mismas filas.
- PEDIDO: r = 1 000 000 filas, b = 5 320 bloques, R = 32 bytes → bfr = **188**. b = ⌈1 000 000 / 188⌉ = 5 320, exacto.

PEDIDO cabe casi el triple porque su fila es tres veces más corta (32 bytes frente a 102). Sus columnas son números, una
fecha y códigos de 1–2 caracteres, mientras que CLIENTE lleva email, nombre, apellidos, teléfono y ciudad. Con 8 KB por
bloque, bfr ≈ espacio útil / R, así que filas más cortas significan más filas por bloque.

**3. ¿Por qué el banco de medida ejecuta cada sentencia dos veces y mide solo la segunda?**
Porque la primera ejecución incluye trabajo que solo ocurre una vez: el análisis duro del SQL (*hard parse*: leer el
diccionario, generar el plan), la limpieza diferida de bloques recién modificados (*delayed block cleanout*) y, si la
caché estaba fría, lecturas físicas. Todo eso suma lecturas lógicas que no son el coste del acceso. La segunda ejecución,
en caliente, mide solo el camino de acceso: en `*_02-anatomia-indice.script.log` la búsqueda por `PK_PEDIDO` da
exactamente 4 Buffers (3 del índice + 1 de la tabla), igual que en la prueba de `lab_tools.medir`
(`prueba_pk … lecturas lógicas = 4 físicas = 0`). Medir siempre igual permite comparar índices con números.

### Anatomía y tipos de índice (C, D)

**4. Altura, hojas y fan-out real de IX_PED_CLIENTE. ¿Qué altura tendría con mil millones de filas?**
`*_02-anatomia-indice.script.log`, secciones 1 y 2 (`VALIDATE STRUCTURE`): altura 3, 2 216 hojas, 6 bloques de rama,
1 000 000 de entradas (451 por hoja de media, máximo 503, llenado 90 %).
- Fan-out real fo = (hojas + ramas − 1) / ramas = (2 216 + 6 − 1) / 6 = **370**.
- Fan-out máximo = 8 028 / 14,8 = **543** entradas por bloque de rama.
- Altura = 1 + ⌈log₅₄₃(2 216)⌉ = 3, que coincide con lo medido.

Con mil millones de filas habría unas 2 208 969 hojas y la altura sería **4** (5 lecturas para encontrar una fila). Con
cien mil millones, 5. La altura crece con el logaritmo del número de filas.

**5. Descompón el ROWID de una entrada de la hoja de PK_CLIENTE. ¿Por qué no aparece el número de archivo?**
En el volcado de la primera hoja (bloque 789, `kdxconro 578` entradas, `kdxcoavs 8` bytes libres), la primera entrada es
`row#0 … data:(6): 00 00 03 1b 00 00` con clave `col 0; len 2: c1 02` (el número 1 en formato interno de Oracle).
- Los 4 primeros bytes, `00 00 03 1b` = 0x31B = **bloque 795**.
- Los 2 últimos, `00 00` = **ranura (fila) 0**.

La comprobación del script lo confirma: el cliente 1 está en el bloque 795 (`0000031B`), ranura 0. No aparece el número de
archivo porque TBS_TIENDASUR es un tablespace **bigfile**: tiene un único datafile, así que el archivo está implícito y los
4 bytes se usan enteros para el bloque. Además, un índice no particionado guarda un ROWID «corto» (6 bytes, sin número de
objeto), porque todas sus filas son de la misma tabla.

**6. Tres pruebas de la Parte D: por qué un tipo de índice gana al otro** (`*_03-tipos-indice.script.log`).
- **Único (Q13, DNI):** sin índice, 1 486 lecturas lógicas (recorrido completo de CLIENTE); con `UX_CLI_DNI`, **3**. Además
  la base impide el duplicado (ORA-00001 en el `INSERT` de prueba): busca y garantiza una regla de negocio.
- **Compuesto y cubriente (Q7, historial del cliente):** con `IX_PED_CLIENTE`, 15 lecturas más un `SORT ORDER BY`; con
  `(id_cliente, fecha)`, 7 lecturas y sin ordenar (igualdad primero, rango después, filas ya ordenadas); con el cubriente
  `IX_PED_CLI_FEC_CUB`, **3** lecturas, sin tocar la tabla. A cambio es el índice más grande (40 MB, 4 983 hojas).
- **Bitmap (Q14, almacén de datos):** sin bitmaps, 4 073 lecturas; con 4 bitmaps combinados (`BITMAP AND`), **528**. El
  bitmap de región ocupa 114 hojas frente a 1 954 del B-tree equivalente. Gana en un almacén de solo lectura; en OLTP
  bloquearía rangos enteros de filas.
- Bonus, **clúster hash (Q15):** 1 lectura frente a 3 de la IOT y 4 del montículo con PK. Pero la «limpieza» por rango le
  cuesta 2 770 lecturas, porque un hash no sirve para rangos.

### Agrupamiento, equilibrio y sargabilidad (E, F)

**7. ¿Por qué el CF de IX_PED_FECHA está cerca de los bloques y el de IX_PED_CLIENTE cerca de las filas? ¿Lo arreglaría un REBUILD?**
`*_04-agrupamiento-equilibrio.script.log`:
- `IX_PED_FECHA`: CF **5 220** frente a 5 320 bloques. Los pedidos se cargaron en orden de fecha (`INSERT /*+ APPEND */ …
  ORDER BY n`), así que fechas consecutivas están en bloques consecutivos: recorrer el índice apenas cambia de bloque.
- `IX_PED_CLIENTE`: CF **999 041** frente a 1 000 000 de filas. El cliente se reparte al azar entre los pedidos, así que
  casi cada entrada del índice salta a otro bloque.

El cálculo a mano (sección 2) da exactamente los mismos números. Un REBUILD no lo arreglaría: el CF es una propiedad del
orden físico de las filas en la **tabla**, no del índice. Solo reordenar la tabla (o una IOT o un clúster) lo cambia, y eso
estropearía el CF de otro índice (el de fecha).

**8. Según tu curva, ¿a partir de qué porcentaje deja de compensar cada índice? Compáralo con la fórmula.**
Sección 3 de la evidencia 04 (b = 5 320, r = 1 000 000, bfr = 188; la tabla entera cuesta 5 232 lecturas):
- **CF malo:** al 0,5 % lee 4 875 (aún por debajo de 5 232) y al 1 % ya 9 920. Corte **entre el 0,5 % y el 1 %**, que
  cuadra con la fórmula en lecturas lógicas: k/r < 1/bfr = 1/188 = **0,53 %**. El optimizador cambia antes, al **0,2 %**,
  porque pondera que una lectura aleatoria cuesta más que una secuencial. Con c_sec/c_aleat = 1/5, la fórmula da
  **0,11 %**.
- **CF bueno:** lee unas k/bfr hojas y bloques y compensa hasta porcentajes enormes: al 50 % lee 3 938 frente a 5 232, y
  solo al 100 % pierde (7 875). Corte en torno al **65–70 %**.

Los tres puntos (0,53 % teórico, 0,2 % del optimizador y 65 % con CF bueno) no coinciden porque miden cosas distintas:
lecturas lógicas, coste estimado de E/S real y el efecto del agrupamiento.

**9. Por qué Q4b ('Gonz%') usa el índice y aun así lee más bloques que un recorrido completo.**
`*_05-sargabilidad.script.log`, regla 4: `LIKE 'Gonz%'` es sargable (un rango por el principio de la cadena) y el plan es
`INDEX RANGE SCAN IX_CLI_APELLIDOS`, pero lee **2 024** bloques, frente a los 1 486 de un recorrido completo de CLIENTE.
Devuelve 2 056 filas, el 2,1 % de la tabla, por encima del punto de equilibrio de CLIENTE (1/bfr = 1/66 ≈ 1,5 %). Además,
los apellidos no están agrupados en la tabla: cada fila cae en un bloque distinto, así que hace una lectura de tabla por
fila más las del índice. Sargable significa que **puede** usar el índice, no que le compense.

### Coste de escritura y mantenimiento (G, H)

**10. Bloques modificados por INSERT con 4, 9 y 5 índices. ¿Qué índices de la propuesta del compañero rechazaste y con qué dato?**
`*_06-indices.script.log`, por fila de INSERT (2 000 filas en cada escenario):

| Escenario | Índices en PEDIDO | Bloques por fila | Redo por fila |
|---|---|---|---|
| Hoy | 4 | 10,2 | 1 354 bytes |
| Propuesta del compañero | 9 | 20,2 | 2 553 bytes |
| V005 (la nuestra) | 5 | 12,1 | 1 610 bytes |

Cada índice añade unos 2 bloques por fila (la hoja y su undo), sobre los ~2 de la tabla. Decisiones del protocolo:
- **`IX_PED_CANAL`, rechazado:** 3 valores, el 33,3 % por valor, muy por encima del punto de equilibrio (~0,5 %), y no lo
  usó la carga (USA = NO).
- **`IX_PED_ESTADO`, rechazado:** 4 valores, el 25 % por valor. Solo `'P'` (2 %) interesa, y eso lo resuelve mejor el
  índice parcial `IX_PED_PENDIENTES` (54 hojas frente a 2 933 de `IX_PED_EST_FEC`, en la Parte D).
- **`IX_PED_FEC_CLI`, rechazado:** la carga no lo usó y duplicaría a `IX_PED_FECHA`, que es su prefijo.
- **`IX_PED_CLI_FEC`, sustituido** por el cubriente `IX_PED_CLI_FEC_CUB`: Q7 pasa de 7 a 3 lecturas.
- **`IX_PED_CP`, aceptado:** la carga lo usó (Q3: 106 lecturas frente a 5 232) y es viable (0,009 % por valor).
- **También se retiran:** `IX_PED_CLIENTE`, por redundante (prefijo del cubriente, que sigue cubriendo la clave ajena), e
  `IX_PED_IMPORTE`, que la carga no usó y que, puesto INVISIBLE, no empeoró nada (Q2 siguió en 329 lecturas).

Resultado V005: 5 índices y 12,1 bloques por fila, frente a 20,2 de la propuesta del compañero.

**11. Distingue con tus gráficos un índice con divisiones 50/50, uno con 90/10 y uno con patrón cola.**
- **50/50, `IX_AZAR`** (`*_07a-grafico-IX_AZAR`): 595 divisiones, ninguna 90/10; 596 hojas al **75,4 %** de media, con un
  histograma repartido entre el 40 % y el 99 %. El mapa es irregular (`[==-====-==#===------===…]`): cada división deja
  dos hojas a medias, que luego se van llenando. La teoría dice que se estabiliza en torno al 69 % (ln 2).
- **90/10, `IX_CRECIENTE`**: 398 divisiones, todas 90/10; 399 hojas al **99,9 %** y el mapa entero lleno
  (`[#####…###]`). Al llenarse la hoja de la derecha, Oracle abre una nueva y deja la vieja llena.
- **Patrón cola, `IX_COLA`** (`*_07b-grafico-IX_COLA-antes`): 425 hojas de las que **224 están vacías**, 70 245 entradas
  borradas y ocupación viva del 47,1 %. En el mapa, la izquierda vacía y la derecha llena
  (`[                                =#####…]`): se inserta por la derecha y se borra por la izquierda.
  «Dame el siguiente mensaje» lee 226 bloques en lugar de 2.

(`IX_INVERTIDA`, REVERSE: 511 divisiones 50/50 y 77,9 % de llenado. Reparte la hoja caliente, pero un rango ya no usa el
índice: 878 lecturas con `TABLE ACCESS FULL`, frente a 4 con el índice normal.)

**12. ¿Qué remedio elegirías para el patrón cola en producción, en horario de servicio, y por qué?**
**COALESCE.** En `*_07c-remedios.script.log` deja el índice de 425 a 201 hojas, 0 entradas borradas, y «siguiente mensaje»
pasa de 226 a **2** lecturas. Se hace en línea, sin bloquear la tabla y con poco redo: fusiona hojas vecinas dentro del
propio índice. `SHRINK SPACE` añade devolver el espacio (4 → 1,69 MB): solo si el espacio importa. `REBUILD ONLINE` da el
mismo resultado de lecturas pero necesita el doble de espacio y genera mucho redo: solo con una causa medida. La cura de
fondo es de diseño: particionar por fecha y vaciar particiones enteras.

### SCN, control files, redo y FRA (I a L)

**13. Con tu evidencia 08: ¿qué valores compara Oracle al abrir para decidir si hace falta recuperación?**
Para cada datafile compara el **SCN de checkpoint que guarda el control file** (`v$datafile.checkpoint_change#`) con el
**de la cabecera del datafile** (`v$datafile_header.checkpoint_change#`), y comprueba si se cerró limpio (SCN de fin
registrado). En `*_08-scn-checkpoint.script.log` todos están sincronizados: 3 169 821 en control file y cabeceras de
system, sysaux y academia01. Tras el `CHECKPOINT` forzado, todos pasan a **3 175 447** a la vez. PDB$SEED se queda en
2 098 101 porque es de solo lectura. Si una cabecera estuviera por detrás del control file (un archivo restaurado de una
copia), haría falta recuperación de medios. Si la base no se cerró limpia, recuperación de instancia.

**14. ¿Qué protege la multiplexación del control file en el mismo volumen y qué no? ¿Cómo se haría en producción?**
Protege de la pérdida o corrupción de **un archivo**. Lo demuestra el simulacro B: se borró `control03.ctl`, el arranque se
detuvo en NOMOUNT con ORA-00205 y bastó copiar `control01.ctl` encima. **No protege** de perder el disco o el volumen, ni de
un error que afecte a todos los archivos, porque las tres copias (`*_09-multiplexar-controlfile.script.log`:
`control01/02/03.ctl`, 18 MB cada una) están en `/opt/oracle/oradata/FREE`. En producción cada copia va en un disco y
controladora distintos (o en grupos ASM distintos, p. ej. `+DATA` y `+FRA`). Además se activa el autobackup del control
file con RMAN y se guarda la copia lógica `BACKUP CONTROLFILE TO TRACE` (aquí, `controlfile_lab5.trc`).

**15. Estados CURRENT, ACTIVE e INACTIVE con tu evidencia 10, y por qué Oracle rechaza los borrados del paso 4.**
`*_10-redo.script.log`:
- **CURRENT:** el grupo en el que LGWR escribe ahora. Al empezar, el grupo 2 (secuencia 11); tras dos `SWITCH LOGFILE`,
  el grupo 1 (secuencia 13).
- **ACTIVE:** ya no se escribe, pero contiene cambios cuyos bloques aún no ha escrito DBWn: se necesitaría para una
  recuperación de instancia. Tras los cambios, los grupos 2 y 3 quedan ACTIVE.
- **INACTIVE:** ya no hace falta para recuperar la instancia (el checkpoint lo cubre): al principio, los grupos 1 y 3.

Borrados del paso 4:
- 4a, borrar el grupo CURRENT → `ORA-01623`: LGWR está escribiendo en él.
- 4b, borrar un miembro del grupo CURRENT → `ORA-01609`.
- 4c, «dejar un solo grupo» → Oracle exige un mínimo de 2 grupos (`ORA-01567`). En mi base, con 3 grupos, el borrado
  dejaría 2 y Oracle lo **permitiría**, así que el script lo explica sin intentarlo, para no perder un grupo de verdad.

Los segundos miembros `redo0Nb.log` nacen INVALID hasta que LGWR escribe en ellos. Tras los dos cambios solo
`redo02b.log` seguía INVALID, porque el grupo 2 aún no había vuelto a ser CURRENT desde que se le añadió el miembro.

**16. Cadena de causas de la FRA llena, desde ORA-19815 hasta que la base deja de aceptar cambios.**
`*_11-fra-llena.script.log`:
1. Se reduce la FRA a 2 MB y se genera redo (UPDATE de 20 000 filas).
2. Al pedir el archivado, ARCn no cabe en la FRA: `ORA-19815: WARNING: db_recovery_file_dest_size of 2097152 bytes is
   100.00% used` (el aviso), `ORA-19809: limit exceeded for recovery files` y `ORA-16038: log 3 sequence# 15 cannot be
   archived`.
3. El grupo 3 queda `ARC = NO, ACTIVE`: no se puede reutilizar hasta que se archive.
4. LGWR sigue avanzando en círculo. Cuando el siguiente grupo que tendría que reutilizar está sin archivar, ya no puede
   cambiar de log: toda sesión que genera redo se queda esperando «log file switch (archiving needed)» y las conexiones
   nuevas reciben `ORA-00257`. La base deja de aceptar cambios.

En mi ejecución no se llegó al bloqueo porque tenía 3 grupos (el 1 CURRENT y el 2 ya archivado). Al devolver 4 GB a la
FRA, ARCn archivó solo el grupo 3 (`15 YES ACTIVE`) y la FRA quedó en 6,9 MB usados. El script deja también 4 GB en el
SPFILE, como comprueba la verificación 16 (`4294967296`).

### Undo, WAL y simulacros (M a P)

**17. «Lectores no bloquean a escritores», con los pasos 1 a 4 de tu evidencia 12.**
`*_12-lectura-consistente.script.log`: la sesión A (SID 213) cambia la fila 101 a EGRESADO sin confirmar.
- Paso 1: B lee la fila y ve **ACTIVO**, el valor confirmado, reconstruido con el undo. No espera a nadie.
- Paso 2: la transacción de A ya ocupa 1 bloque y 1 registro de undo (segmento 2).
- Paso 3: A tiene un bloqueo TM modo 3 sobre ACA_ESTUDIANTES y un TX modo 6 sobre la fila.
- Paso 4: solo cuando B intenta **bloquear** la fila (`FOR UPDATE WAIT 3`) choca: `ORA-00054`, la fila está bloqueada por
  la transacción 2.13.681.

Leer nunca espera a un escritor y escribir nunca espera a un lector; solo dos escritores sobre la misma fila se esperan.
Tras el COMMIT de A, B ve EGRESADO. La consulta de flashback (paso 6) vuelve a leer ACTIVO del undo y lo usa para reparar la
fila.

**18. ¿Por qué un DELETE genera más undo que un INSERT? ¿Por qué el ROLLBACK también genera redo?**
`*_12-undo-y-redo.script.log`, 10 000 pedidos:

| Operación | Undo | Redo total | Redo del ROLLBACK |
|---|---|---|---|
| INSERT | 140 bloques (1 120 KB) | 4 833 KB | 355 KB |
| UPDATE | 71 bloques (568 KB) | 1 258 KB | 751 KB |
| DELETE | 427 bloques (3 416 KB) | 6 628 KB | 4 701 KB |

El undo de un INSERT solo guarda «borra este ROWID» (y las entradas de índice). El de un DELETE guarda la **fila entera** y
sus entradas de índice, para poder reconstruirla. El ROLLBACK genera redo porque deshacer es aplicar cambios a los bloques
de datos (reinsertar las filas borradas, borrar las insertadas), y todo cambio de bloque se protege con redo. Por eso
deshacer el DELETE cuesta 4 701 KB. Además, el propio undo se protege con redo (1 120 / 540 / 3 266 KB del redo de cada
operación describen el undo): si la instancia cae, primero se rehace también el undo para poder deshacer después.

**19. Con tu evidencia 13: ¿dónde está la garantía de durabilidad justo después del COMMIT? ¿Y después del checkpoint?**
`*_13-lgwr-dbwn.script.log`:
- Paso 1, UPDATE de 20 000 filas + COMMIT: 7 865 KB de redo, **10 escrituras de LGWR**, **0 bloques escritos por DBWn** y
  231 bloques sucios de la tabla. Justo después del COMMIT el dato está garantizado en el **redo log online** (en sus dos
  miembros); los datafiles todavía tienen el valor antiguo.
- Paso 2, `ALTER SYSTEM CHECKPOINT`: DBWn escribe **601 bloques** y quedan 0 sucios. Ahora el dato está **también en los
  datafiles** y el redo de esos cambios ya no hace falta para una recuperación de instancia (aunque se conserva archivado
  para la recuperación de medios).

Es el *write-ahead logging*: el redo llega al disco antes que el dato, y el COMMIT solo espera a LGWR.

**20. Simulacro A: roll forward y roll back con las filas 102 y 103 y el alert log.**
`*_14a-caida-instancia.script.log`: antes del `SHUTDOWN ABORT`, la 102 pasa a EGRESADO **con COMMIT** y la 103 a INACTIVO
**sin COMMIT**. El alert log muestra lo que hizo SMON en el `STARTUP`:
- `Beginning crash recovery of 1 threads`
- `Recovery starting at checkpoint rba (logseq 17 block 54987), scn 3179354`
- `read 15 KB redo, 6 data blocks need recovery`
- `Completed crash recovery` y `Thread 1 opened at log sequence 18`

**Roll forward:** desde el último checkpoint aplica el redo (15 KB) y rehace los 6 bloques que no habían llegado al disco,
incluidos los de la 103 y los del undo. **Roll back:** con ese undo deshace lo no confirmado. Resultado: la 102 sigue
EGRESADO (durabilidad) y la 103 vuelve a ACTIVO (atomicidad). Nadie tuvo que hacer nada: un `STARTUP` normal.

**21. Simulacros C y D: RTO y RPO. ¿Por qué son tan distintos?**
- **C**, `DROP TABLE … PURGE` y restauración completa (`*_14c-simulacro-restauracion.script.log`): **RTO = 76 s**,
  **RPO = 2 s**. El RPO es artificial porque la copia `lab5-pre-simulacro` (1,3 GB) se hizo justo antes. En la vida real
  sería todo lo hecho desde la última copia en frío (horas o días) y en **todas** las tablas, no solo en la borrada.
- **D**, pérdida de `academia01.dbf` con RMAN (`*_14d-perdida-datafile.script.log`): **RTO = 14 s** (15 s desde el fallo),
  **RPO = 0**. La fila 104, cambiada después de la copia RMAN, apareció como EGRESADO tras el `RECOVER`.

Son distintos porque C restaura **toda la base**: su RTO crece con el tamaño de la base y su RPO es el tiempo desde la
copia. D restaura **un archivo de 100 MB** y le aplica encima el redo archivado y el online: su RTO es proporcional al daño
y no se pierde ningún COMMIT. Eso solo es posible con ARCHIVELOG y una copia RMAN.

**22. Clasifica cada ORA- del bloque 5 de tu runbook** (`*_15-healthcheck.spool.log`):

| Hora | Error | Clasificación | Lo explica |
|---|---|---|---|
| 19:07 | ORA-01113 (file 21 needs media recovery) ×2 | Efecto del laboratorio | Simulacro D: al reabrir FREEPDB1, Oracle comprueba las cabeceras de sus archivos |
| 19:07 | ORA-01110 (data file 16: academia01.dbf) | Efecto del laboratorio | Simulacro D: el archivo borrado a propósito |
| 19:07 | ORA-63999 (data file suffered media failure) | Efecto del laboratorio | Simulacro D: Oracle cerró la PDB al detectar el fallo de medio |
| 19:05 y 19:07 | ORA-00800 [Set Priority Failed] [VKTM]/[LGWR] | Ruido conocido del entorno | Lab 4: el contenedor no tiene `CAP_SYS_NICE`; sale en cada arranque |
| 19:01 | ORA-00202 (control03.ctl) y ORA-205 en `ALTER DATABASE MOUNT` | Efecto del laboratorio | Simulacro B |

Ningún incidente real. El resto del runbook está sano: FRA al 1,9 % (77 de 4 096 MB), 3 control files, 0 grupos de redo con
un solo miembro, una copia RMAN COMPLETED (38 MB, 4 s), 0 ORA-01555 y 100 de 200 procesos. Hubo 8 cambios de log por hora
(18 h y 19 h), pocos porque mis grupos son de 200 MB (el PDF, con 20 MB, veía 69). En producción decenas por hora
indicarían redo pequeño o una carga masiva. Si el bloque 7 (RMAN) saliera vacío en producción, hoy mismo lanzaría una copia
completa con RMAN y abriría una alerta, porque sin copia no hay recuperación de medios.

---

## Simulacros: RTO y RPO

| Simulacro | Fallo | Recuperación | RTO medido | RPO real | Qué me sorprendió | Qué cambiaría |
|---|---|---|---|---|---|---|
| A | `SHUTDOWN ABORT` (corte de luz) | Recuperación de instancia automática (SMON) | Unos 10 s (el script 14a entero) | 0 | Solo 15 KB de redo y 6 bloques: la caída llegó justo tras un checkpoint | Nada: no requiere intervención; vigilar `fast_start_mttr_target` |
| B | Se borra `control03.ctl` | Copiar `control01.ctl` y `MOUNT` + `OPEN` | Unos 12 s (de 19:01:30 a 19:01:42, con parada incluida) | 0 | Con una sola copia rota la instancia no monta, aunque haya otras dos sanas | Copias en discos distintos y autobackup del control file |
| C | `DROP TABLE … PURGE` | Restaurar la copia completa (1,3 GB) | **76 s** | 2 s (artificial) | Se restaura toda la base por una sola tabla | Usar RMAN `RECOVER TABLE` (ARCHIVELOG) en lugar de la copia completa |
| D | Se borra `academia01.dbf` | RMAN `RESTORE` + `RECOVER` del archivo | **14 s** (15 s desde el fallo) | **0** | Oracle cerró FREEPDB1 entera (ORA-63999) antes de que pudiera ponerlo OFFLINE | Seguir el runbook: comprobar `v$pdbs` antes de actuar (caminos A y B) |

En el simulacro D me tocó el camino **B**: «Estado de FREEPDB1 antes de reparar: MOUNTED». DBWn o el checkpoint detectaron
el archivo perdido y Oracle cerró solo esa PDB; la CDB siguió abierta. Se reparó con la PDB montada y después
`ALTER PLUGGABLE DATABASE FREEPDB1 OPEN`. El procedimiento está en `docs/runbooks/perdida-datafile.md`.

## Retrospectivas sin culpables

### Incidente: DML que se habría colgado por la FRA llena (Parte L, escenario controlado)
- **Impacto:** el redo de la secuencia 15 no se pudo archivar (ORA-16038); ninguna pérdida de datos. Con 3 grupos de 200 MB
  no llegó a bloquear sesiones, pero un cambio de log más lo habría hecho.
- **Detección:** `ORA-19815` (aviso, 100 % usado) y `ORA-19809` en el alert log a las 19:00:40, y en `v$log` un grupo con
  `ARC = NO`.
- **Causa raíz:** `db_recovery_file_dest_size` reducido a 2 MB, por debajo de lo que ocupa un solo archivado.
- **Mitigación:** devolver la FRA a 4 GB (`SCOPE = BOTH`); ARCn reintentó solo y archivó la secuencia 15.
- **Qué cambia:** el runbook (bloque 3) vigila la FRA y debe alertar al 80 %. Antes de repetir cargas grandes, revisar
  `v$recovery_area_usage`. Nunca liberar con `rm`, solo con RMAN.
- **Lección:** el aviso (ORA-19815) llega antes que el bloqueo; si nadie lo mira, el incidente llega de noche.

### Game day A–D
- **Qué funcionó:** los cuatro simulacros terminaron con la base abierta y la verificación 16 en TODO OK. Las filas 102 y
  104 demostraron durabilidad (RPO 0 en A, B y D).
- **Qué no:** el RTO de C (76 s) crece con el tamaño de la base y su RPO real sería el tiempo desde la última copia. Es la
  peor estrategia para un error en una sola tabla.
- **Mejora concreta:** la copia RMAN del simulacro D es la primera de la base: programar copias RMAN periódicas
  (incremental diaria y archivados), con alerta si el bloque 7 del runbook sale vacío. Así D (14 s, RPO 0) sería el caso
  normal y C la excepción.

---

## Preguntas tipo examen de cada parte

| Nº | Resp. | Justificación |
|---|---|---|
| B1 | **B** | E-Rows 25 000 frente a A-Rows 20 en una columna sesgada: sin histograma se supone el reparto uniforme (25 %); por eso V004 crea histogramas FREQUENCY en `estado` (Parte B). |
| C1 | **C** | BLEVEL 2 → altura 3 → 3 lecturas de índice + 1 de tabla = 4, como `PK_PEDIDO` (Parte C). |
| C2 | **C** | Altura = 1 + ⌈log₅₀₀(2 000 000)⌉ = 1 + 3 = 4 (Parte C, misma fórmula que para IX_PED_CLIENTE). |
| D1 | **B** | Columnas de pocos valores en un almacén cargado de noche: bitmaps combinables (Q14: 4 073 → 528 lecturas, Parte D). |
| D2 | **A, C** | Evita la tabla (Q7 cubriente: 3 lecturas) y encarece cada escritura de sus columnas; Oracle no tiene INCLUDE (Partes D y G). |
| E1 | **B** | CF ≈ filas: con el 3 % el índice leería unos 300 000 bloques frente a 80 000; mi curva cruza ya en torno al 0,5 % (Parte E). |
| F1 | **B** | Comparar VARCHAR2 con un número aplica `TO_NUMBER` a la columna (Q3: `filter(TO_NUMBER("CODIGO_POSTAL")=30001)`, Parte F). |
| F2 | **A, C** | Rangos equivalentes con la columna desnuda; B no es equivalente y D/E aplican función o aritmética (Parte F). |
| G1 | **B** | INVISIBLE: el optimizador lo ignora pero se mantiene; vuelta atrás inmediata (`IX_PED_IMPORTE`, Parte G). |
| G2 | **B** | Unos 2 bloques por índice y fila → 500 × 2 ≈ 1 000 bloques/s (Parte G: 10,2 → 12,1 → 20,2). |
| H1 | **B** | Patrón cola: COALESCE en línea y barato (226 → 2 lecturas, Parte H). |
| H2 | **A, C** | REVERSE reparte la hoja caliente pero inutiliza los rangos (878 lecturas con FULL frente a 4, Parte H). |
| I1 | **B** | SCN de checkpoint del control file frente a la cabecera (Parte I). |
| J1 | **B** | Si falla cualquier copia, la instancia se detiene; se sustituye o se quita de CONTROL_FILES (Partes J y O-B). |
| J2 | **A, C** | Nombres y rutas de datafiles y redo, y el SCN de checkpoint (Parte J); no parámetros ni contraseñas. |
| K1 | **C** | ACTIVE: aún necesario para la recuperación de instancia (Parte K). |
| L1 | **B** | ORA-19802: primero el tamaño, después la ruta (Parte L, paso 2). |
| L2 | **A, C** | Más tamaño o copiar y borrar archivados con RMAN; nunca `rm` (Parte L). |
| M1 | **C** | B ve el valor confirmado reconstruido con el undo (Parte M, paso 1: ACTIVO). |
| M2 | **C** | El DELETE guarda la fila entera: 427 bloques de undo frente a 140 y 71 (Parte M). |
| M3 | **B, D** | Más retención y espacio de undo; RETENTION GUARANTEE si es crítica (Parte M). |
| N1 | **A** | El COMMIT espera a LGWR: redo en el log online (Parte N: 10 escrituras LGWR, 0 DBWn). |
| N2 | **B, C** | DBWn escribe en el checkpoint y cuando faltan buffers libres; no en cada COMMIT (Parte N). |
| O1 | **B** | SMON hace roll forward + roll back y la base abre sola (simulacro A). |
| O2 | **B, D** | Copiar una copia sana, o quitarla de CONTROL_FILES (simulacro B). |
| O3 | **B** | OFFLINE → RESTORE → RECOVER → ONLINE (simulacro D). |
| O4 | **D** | Tras PURGE no hay papelera; RMAN RECOVER TABLE recupera solo esa tabla (simulacro C, alternativa). |

## Simulacro de examen 1Z0-182 (S1–S26)

| Nº | Resp. | Justificación | Dónde lo comprobé |
|---|---|---|---|
| S1 | **B** | CF ≈ filas: casi un bloque distinto por fila; REBUILD no lo cambia | Parte E (IX_PED_CLIENTE, 999 041) |
| S2 | **A, C** | Índice funcional o aplicar la función al dato | Partes D (Q1 funcional) y F (Q1 reescrita: 1 486 → 4) |
| S3 | **B** | Conversión implícita `TO_NUMBER` sobre la columna | Parte F (Q3) |
| S4 | **B** | Pocos valores en almacén de solo lectura | Parte D (Q14) |
| S5 | **B** | INDEX SKIP SCAN sobre (pais, ciudad) | Parte D (Q6: SKIP SCAN, 144 lecturas) |
| S6 | **B** | INVISIBLE y observar | Parte G (IX_PED_IMPORTE) |
| S7 | **A, C** | COALESCE y SHRINK SPACE, en línea | Parte H (07c-remedios) |
| S8 | **B** | Reparte inserciones, pero no sirve para rangos | Parte H (IX_INVERTIDA) |
| S9 | **C** | Un UPDATE de columna no indexada solo toca la tabla | Parte G (UPDATE estado hoy: 2 bloques por fila) |
| S10 | **B** | La altura depende del fan-out (tamaño de clave) | Parte C (fo 370 / 543) |
| S11 | **A, C** | La fila vive en el índice de la PK; sin salto a otro segmento | Parte D (Q15 IOT: 3 lecturas) |
| S12 | **B** | SCN de checkpoint del control file frente a la cabecera | Parte I |
| S13 | **C** | CKPT actualiza control file y cabeceras | Parte I |
| S14 | **B, E** | En NOMOUNT responden v$instance y v$parameter | Lab 4, Parte E (arranque por etapas) |
| S15 | **B** | SHUTDOWN IMMEDIATE → STARTUP MOUNT → ARCHIVELOG → OPEN | Parte L |
| S16 | **B** | `ALTER DATABASE CLEAR LOGFILE GROUP n` para un INACTIVE archivado | Parte K (estados) |
| S17 | **A, C** | Lectura consistente y flashback query | Parte M (pasos 1 y 6) |
| S18 | **B** | El undo se rehace antes de deshacer | Partes M y O-A |
| S19 | **A** | Redo en el log online | Parte N |
| S20 | **A** | Checkpoints incrementales más frecuentes, recuperación más corta | Parte I (MTTR estimado 40 s) |
| S21 | **B** | ARCn no puede archivar (FRA llena) | Parte L |
| S22 | **B** | Poner el datafile OFFLINE para aislarlo | Parte O, simulacro D |
| S23 | **B** | SYSTEM: ABORT → MOUNT → RESTORE → RECOVER → OPEN | Parte O (teoría del simulacro D) |
| S24 | **B** | En NOARCHIVELOG solo cabe la copia en frío, perdiendo lo posterior | Parte O, simulacro C (copia completa) |
| S25 | **B, D** | Más undo y retención; RETENTION GUARANTEE | Parte M (v$undostat) |
| S26 | **A** | V$RECOVERY_AREA_USAGE | Parte L (11-activar-archivelog) |
