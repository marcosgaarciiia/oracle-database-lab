# Laboratorio 7 · Respuestas · E025

<!-- Rutas relativas a docs/bitacora/lab7/evidencia/ (casos/, herramientas/, incidentes/). Contenedor 2aaaadf41294, DBID 1509902213. -->

## Parte B · C01 · Más sesiones no es más rendimiento
1. Con 1 sesión: 5,0 llamadas/s y p95 de 197 ms. Con 8: 9,8 llamadas/s y p95 de 1 170,7 ms (`casos/20261127T212611Z_C01_entender.txt`). Con 2: 9,1 llamadas/s y p95 de 305 ms (`casos/20261127T212656Z_C01_validar.txt`).
   Recomiendo un pool de **2 sesiones**, igual que CPU_COUNT = 2. Con 8 solo gano un 7 % de throughput (9,8 frente a 9,1) y la p95 se multiplica por casi 4 (1 171 frente a 305 ms). Lo que añaden las 6 sesiones de más es cola, no trabajo.
2. Con 8 sesiones domina **resmgr:cpu quantum**: 243 de 328 muestras de ASH (74,1 %), frente a 85 en CPU. El AAS es de 7,8, con CPU_COUNT = 2 (`casos/20261127T212612Z_C01_diagnosticar.txt`).
   En Oracle Free el Resource Manager limita la instancia a 2 CPU. Esa espera es el turno de CPU que impone el gestor, así que el trabajo no va más rápido: hace cola.
3. Ley de Little, N = X · R, con la latencia media (`casos/20261127T212657Z_C01_observar.txt`):
   - N1: 5,0 × 0,1929 s = 0,96 ≈ 1.
   - N2: 9,1 × 0,2172 s = 1,98 ≈ 2.
   - N8: 9,8 × 0,7886 s = 7,7 ≈ 8.

   Se cumple en las tres tandas. Como X no pasa de unas 9–10 llamadas/s, subir N solo hace subir R.

## Parte C · C03 · Literales y análisis completos
1. Las tres versiones (`casos/20261127T212803Z_C03_diagnosticar.txt`, `20261127T212806Z_C03_validar.txt` y `20261127T212808Z_C03_observar.txt`):

   | Versión | Hard parses | Tiempo total | Por ficha |
   |---|---|---|---|
   | Literales | 5 050 | 5 930 ms (el 82 % analizando) | 1,186 ms |
   | Variables de enlace | 28 | 230 ms | 0,046 ms |
   | CURSOR_SHARING = FORCE | 28 | 350 ms | 0,07 ms |

   Con literales la shared pool llegó a 1 143 cursores, frente a 1 solo con variables.
2. FORCE es un puente porque el defecto sigue en la aplicación. Oracle reescribe **todos** los literales a `:"SYS_B_0"` (el SQL_ID bba34k3qhx6j7 con 5 000 ejecuciones), también los que dan selectividad al optimizador, y aun así cuesta más que las variables de verdad (350 frente a 230 ms).
   Lo que delata el problema en V$SQL es una misma FORCE_MATCHING_SIGNATURE (14573098645096361820) con 1 114 SQL_ID distintos, cada uno ejecutado una vez. La cura es la variable de enlace en el código; FORCE se documenta y se retira cuando llega.

## Parte C · C04 · El informe que se desborda a TEMP
1. Antes del cambio, el informe escribía y leía 5 456 bloques de TEMP (42,6 MB) en **1 PASS** y tardaba 3 410 ms. La ordenación necesitaba 48 MB para ser óptima y solo usó 1 016 KB, con POLICY = MANUAL (`casos/20261127T212816Z_C04_diagnosticar.txt`).
   Después, el informe completo tarda 1 020 ms con 0 bloques de TEMP (OPTIMAL, 63,7 MB), y el TOP 100 tarda 120 ms, también con 0 bloques (`casos/20261127T212821Z_C04_validar.txt` y `20261127T212822Z_C04_observar.txt`).
   El disparador T6.C04_LEGADO (AFTER LOGON ON t6_inf.SCHEMA) ponía `workarea_size_policy = MANUAL` y `sort_area_size = 1048576`. Así anulaba la PGA automática, que podía dar hasta 100 MB (global memory bound).
2. El TOP 100 se resuelve con SORT ORDER BY STOPKEY: solo guarda las 100 mejores filas mientras recorre la tabla, así que necesita KB (MB_OPTIMO = 0,0).
   El informe completo tiene que ordenar 1 000 000 de filas antes de devolver la primera, porque la ordenación es bloqueante. Con 1 MB no cabe y va a disco. Reducir antes de ordenar vale más que dar memoria.

## Parte D · C07 · EXPLAIN PLAN frente al plan real
1. Predicado del plan real, en la línea 2 (TABLE ACCESS FULL de PEDIDO): `filter(TO_NUMBER("CODIGO_POSTAL")=:B1)`, con Peeked Binds `:B1 (NUMBER): 30038` (`casos/20261127T212847Z_C07_diagnosticar.txt`).
   Sale de que la V1 (BUSCAR_CP_V1) recibe P_CP como NUMBER y la columna es VARCHAR2. Por la precedencia de tipos, Oracle convierte la **columna** en cada fila, y con la función aplicada el índice IX_T6_PED_CP ya no sirve para acceder.
2. V1: 5 227 lecturas por búsqueda y p95 de 63,4 ms. V2: 95 lecturas y p95 de 0,7 ms (`casos/20261127T212850Z_C07_validar.txt`).
   EXPLAIN PLAN no ejecuta la sentencia ni conoce el tipo de la variable: trata `:CP` como texto. Por eso predijo `access("CODIGO_POSTAL"=:CP)` con el índice (plan 2982358210), mientras que el cursor real usa el plan 2571571058, que recorre la tabla (`casos/20261127T212845Z_C07_entender.txt`).

## Parte D · C08 · E-Rows frente a A-Rows
1. Antes del grupo de columnas, la línea 3 (TABLE ACCESS BY INDEX ROWID BATCHED de CLIENTE, con `filter("C"."COMUNIDAD"='COM09')`) estima **3** clientes y salen **56**. Es la primera línea, leyendo de dentro afuera, donde E-Rows × Starts se separa de A-Rows: la línea 4 está bien (50 frente a 56). Encima, el error se arrastra: 28 pedidos estimados frente a 599 reales (`casos/20261127T212856Z_C08_diagnosticar.txt`).
   Después, la línea 3 estima 50 frente a 56 y la línea 1, 496 frente a 599 (`casos/20261127T212858Z_C08_solucionar.txt` y `20261127T212859Z_C08_validar.txt`).
2. El optimizador supone que ciudad y comunidad son independientes y multiplica las selectividades: 100 000 × 1/2 000 × 1/17 ≈ 2,9 clientes. Pero cada ciudad pertenece a una sola comunidad (MAX_COMUNIDADES_POR_CIUDAD = 1), así que filtrar por comunidad no quita nada: son columnas correladas (`casos/20261127T212855Z_C08_entender.txt`).
   El grupo SYS_STUBJHRJ63BYYQ61EBQAQU2TM_ cuenta las combinaciones reales (2 000) y corrige la estimación.

## Parte E · C12 · Estadísticas obsoletas
1. Según las estadísticas, CARRITO tenía 100 filas y en realidad tenía 200 100. DBA_TAB_MODIFICATIONS registraba 200 000 inserciones y STALE = YES (`casos/20261127T212926Z_C12_entender.txt` y `20261127T212928Z_C12_diagnosticar.txt`).
   Antes de recoger, el plan era NESTED LOOPS: 200 000 visitas a PK_T6_PEDIDO y 212 307 lecturas lógicas. Después, es HASH JOIN, con E-Rows de 200K igual a A-Rows y 5 907 lecturas, 36 veces menos (`casos/20261127T212929Z_C12_solucionar.txt` y `20261127T212931Z_C12_validar.txt`).
2. La tarea automática («auto optimizer stats collection») solo recoge en la ventana de mantenimiento: la del viernes empieza a las 22:00 y la del sábado a las 06:00. Además, solo recoge si cambia más de un STALE_PERCENT = 10 (`casos/20261127T212932Z_C12_observar.txt`).
   Una carga nocturna que termina antes del informe de primera hora llega tarde a esa ventana. Debe recoger **el proceso que carga**, al terminar (GATHER_TABLE_STATS en el propio job, con red según el RB-2).

## Parte E · C13 · El ciclo de estadísticas con red
1. Este es el ciclo, con la vista que comprueba cada paso (`casos/20261127T212940Z`, `212946Z`, `212948Z` y `212954Z_C13_*.txt`):
   - **Diagnóstico.** DBA_TAB_STATISTICS da STALE = YES; DBA_TAB_MODIFICATIONS, 135 277 actualizaciones; DBA_TAB_COL_STATISTICS, ESTADO sin histograma (NONE); y GET_PREFS, PUBLISH = TRUE.
   - **Pendientes.** Pongo PUBLISH = FALSE y recojo con ESTADO SIZE 254. DBA_TAB_PENDING_STATS muestra las pendientes (21:29:42) junto a las publicadas (21:29:34).
   - **Probar.** Con `optimizer_use_pending_statistics = TRUE` solo en mi sesión, la estimación de estado 'E' pasa de 250 000 a 185 277, que son las filas reales.
   - **Publicar.** PUBLISH_PENDING_STATS y PUBLISH = TRUE. DBA_TAB_STATISTICS da STALE = NO y el histograma pasa a FREQUENCY.
   - **Restaurar.** DBA_TAB_STATS_HISTORY guarda el historial (31 días de retención). RESTORE_TABLE_STATS a hace 60 s deja ESTADO otra vez en NONE.
   - **Bloquear.** LOCK_TABLE_STATS, y STATTYPE_LOCKED pasa a ALL.
2. Al recoger con las estadísticas bloqueadas obtuve `ORA-20005: object statistics are locked (stattype = ALL)` (`casos/20261127T212954Z_C13_observar.txt`).
   Si de verdad hace falta recoger, es una decisión consciente: `GATHER_TABLE_STATS(..., force => TRUE)`, o bien UNLOCK_TABLE_STATS, recoger y volver a bloquear.

## Parte E · C14 · El índice invisible
1. El panel leía 5 265 bloques por apertura (23,9 ms) recorriendo un millón de filas para mostrar 2 056 (`casos/20261127T212958Z_C14_entender.txt`). Con el índice lee 118 bloques por apertura (0,72 ms), 45 veces menos (`casos/20261127T213005Z_C14_validar.txt`).
   Para probarlo sin que lo viera nadie más, creé IX_T6_C14_PEND (estado, canal, fecha_pedido) INVISIBLE ONLINE, con 3 206 bloques hoja. El plan normal siguió en FULL. En **una sola sesión** puse `optimizer_use_invisible_indexes = TRUE`, comprobé INDEX RANGE SCAN con 116 buffers y solo entonces lo pasé a VISIBLE (`casos/20261127T213004Z_C14_solucionar.txt`).
2. Redo para cambiar el canal de 20 000 pedidos (`casos/20261127T213009Z_C14_observar.txt`):
   - Sin el índice: 9 007 KB.
   - Con el índice INVISIBLE: 10 403 KB.
   - Con el índice VISIBLE: 10 402 KB.

   Demuestra que el índice invisible cuesta lo mismo al escribir que el visible (unos 1,4 MB más, un +15 %): el optimizador no lo usa, pero cada DML lo mantiene. INVISIBLE sirve para probar o retirar con marcha atrás, no para ahorrar coste de escritura.

## Parte F · C17 · INC-604 con AWR, ASH y ADDM
1. SLI: la p95 de la búsqueda por código postal. SLO: p95 < 20 ms.
   Antes, con V1, la p95 era de 77,5 ms con 3 364 búsquedas, así que **incumplía** (`casos/20261127T213250Z_C17_entender.txt`). Después, con V2 y la misma carga (3 sesiones durante 120 s), la p95 es de 1,09 ms con 31 651 búsquedas (`casos/20261127T213507Z_C17_validar.txt`).
   Usé las instantáneas AWR **18** (21:30:29) y **19** (21:32:47), que cubren la carga de V1. En la línea base, ANTES daba 82,02 ms y 5 274 lecturas por ejecución, y DESPUES 0,66 ms y 98: ×124 (`herramientas/20261127T213507Z_t6-base.txt`).
2. Qué dijo cada herramienta (`casos/20261127T213255Z_C17_diagnosticar.txt`):
   - **ASH** dijo quién y en qué: 0dbx7196jdajy (acción C17_V1), 244 muestras en CPU y 34 en resmgr:cpu quantum.
   - **AWR (18→19)** dijo qué SQL del intervalo: 272,6 s, 3 324 ejecuciones y 5 274 lecturas por ejecución.
   - **ADDM** lo cuantificó: DB time de 331 s y AAS de 2,63. Hallazgo 1, «Top SQL», el 90,91 %, recomendando el SQL Tuning Advisor. Hallazgo 2, «Resource Manager CPU Throttling», el 25,98 %.

   Ninguna podía decir **por qué**. Eso solo lo dice el plan real: `filter(TO_NUMBER("CODIGO_POSTAL")=:B1)`, una conversión implícita. ADDM proponía afinar el SQL, pero la causa era el tipo de dato.
   El **único cambio** fue que la web llama a BUSCAR_CP_V2 (P_CP VARCHAR2) en lugar de a V1 (P_CP NUMBER), según DBA_ARGUMENTS (`casos/20261127T213257Z_C17_solucionar.txt`).

## Parte F · C18 · SQL Plan Management
1. El mismo SQL_ID, 8hn59jfgw00y7, con tres planes (`casos/20261127T213530Z_C18_provocar.txt`, `20261127T213531Z_C18_entender.txt` y `20261127T213537Z_C18_solucionar.txt`):

   | Momento | PLAN_HASH_VALUE | Plan | Lecturas por ejecución | Tiempo |
   |---|---|---|---|---|
   | Lunes | 1767728868 | índice IX_T6_PED_ESTADO | 195 | 7,1 ms |
   | Martes | 2571571058 | FULL | 5 227 | 29,1 ms |
   | Con la línea base | 1767728868 | índice | 189 | 14,3 ms |

   La línea base es SQL_PLAN_0a27u7nan424ba00b9863 (MANUAL-LOAD-FROM-AWR), cargada de las instantáneas 22 a 23. Funciona aunque ESTADO siga sin histograma (`casos/20261127T213539Z_C18_validar.txt`).
2. El plan que quería el optimizador (FULL) quedó en la historia del plan como SQL_PLAN_0a27u7nan424b95a18d93, AUTO-CAPTURE y **ACCEPTED = NO**.
   La evolución (TASK_75) ejecutó los dos planes. El nuevo «failed the benefit criterion», es decir, rindió peor que el de la línea base, así que siguió sin aceptar: SPM solo acepta un plan si demuestra que es mejor (`casos/20261127T213542Z_C18_observar.txt`).
   Queda pendiente la causa: la preferencia METHOD_OPT = FOR ALL COLUMNS SIZE 1 de PEDIDO, que borra el histograma en cada recogida. Hay que corregirla con el RB-2, como hice en INC-608.

## Parte G · Incidente 1 · INC-608
- **Síntoma (con números):** el informe por estado = 'D' estima 250 000 filas y son 28 007. Por eso recorre la tabla entera (TABLE ACCESS FULL, plan 2571571058) en lugar de usar el índice (`incidentes/20261127T213647Z_INC-608_verificar.txt` y `20261127T213650Z_INC-608_diagnostico.txt`).
- **Playbook y pasos seguidos (herramientas y vistas):** PB-3 «el plan cambió». Usé `t6 estad PEDIDO` (`herramientas/20261127T213650Z_t6-estad.txt`), EXPLAIN PLAN frente a COUNT(*) real, DBA_TAB_COL_STATISTICS (ESTADO con HISTOGRAM = NONE), DBMS_STATS.GET_PREFS y DBA_TAB_STATS_HISTORY, que muestra una recogida a las 21:36:40, justo antes del síntoma.
- **Causa raíz:** la preferencia de tabla METHOD_OPT = `FOR ALL COLUMNS SIZE 1` (la global es SIZE AUTO). La recogida nocturna borró el histograma de ESTADO y, sin él, el optimizador reparte 1/4 de la tabla por estado.
- **Arreglo aplicado (órdenes exactas) y por qué ese:** con el RB-2:
  1. `SET_TABLE_PREFS('T6','PEDIDO','PUBLISH','FALSE')`.
  2. `SET_TABLE_PREFS('T6','PEDIDO','METHOD_OPT','FOR ALL COLUMNS SIZE 1 FOR COLUMNS ESTADO SIZE 254')`.
  3. `GATHER_TABLE_STATS('T6','PEDIDO')`, que deja 4 cubos de histograma pendientes.
  4. Prueba con `optimizer_use_pending_statistics = TRUE`: estima 28 007 filas y usa INDEX RANGE SCAN de IX_T6_PED_ESTADO.
  5. `PUBLISH_PENDING_STATS(..., no_invalidate => FALSE)` y `PUBLISH = TRUE`.

  Elegí este arreglo porque corrige la causa (la preferencia) y no solo las estadísticas de hoy, y porque lo pruebo antes de publicarlo (`incidentes/20261127T213659Z_INC-608_arreglo.txt`).
- **Verificación (archivo de evidencia con todo OK):** `incidentes/20261127T213702Z_INC-608_verificar.txt`: 4 OK (28 007 estimadas y 28 007 reales, histograma FREQUENCY, METHOD_OPT que conserva el histograma).
- **Prevención (qué evitaría que se repita):** tratar las preferencias de DBMS_STATS como configuración con gestión de cambios: revisar DBA_TAB_STAT_PREFS tras cada intervención y declarar explícitamente los histogramas de las columnas con datos sesgados. Para el informe crítico, una línea base de SPM (C18) que proteja el plan bueno mientras se corrige.

## Parte G · Incidente 2 · INC-610
- **Síntoma (con números):** varias pantallas lentas a la vez. La búsqueda V2 por código postal pasa a 6 847 lecturas y 44,7 ms por ejecución con TABLE ACCESS FULL (plan 2571571058), cuando antes usaba IX_T6_PED_CP con unas 98 lecturas. `t6 salud` da VERDE (AAS máximo de 1,4 con 2 CPU), así que no es capacidad: es el plan (`herramientas/20261127T213709Z_t6-salud.txt` y `20261127T213710Z_t6-top.txt`).
- **Playbook y pasos seguidos (herramientas y vistas):** PB-3: si cambian muchos planes a la vez, hay una causa común. Usé `t6 salud` y `t6 top 5`. El plan de 53mx77snb43uw con `+OUTLINE` muestra `OPT_PARAM('optimizer_index_cost_adj' 4500)`, y V$SPPARAMETER da `optimizer_index_cost_adj = 4500` con ISSPECIFIED = TRUE en CON_ID 3, la PDB. La consulta de V$SYSTEM_PARAMETER con ISDEFAULT = 'FALSE' no lo mostró; lo delataron el outline y el SPFILE de la PDB. Probé la hipótesis solo en mi sesión: con 4500, FULL con coste 1 447; con 100, el índice con coste 94 (`incidentes/20261127T213711Z_INC-610_diagnostico.txt`).
- **Causa raíz:** el «ajuste» del consultor, `optimizer_index_cost_adj = 4500` en FREEPDB1, hace que todos los accesos por índice parezcan 45 veces más caros, y el optimizador los descarta en todas las sentencias a la vez.
- **Arreglo aplicado (órdenes exactas) y por qué ese:** en FREEPDB1, `ALTER SYSTEM RESET optimizer_index_cost_adj SCOPE = BOTH;`. El resultado: valor 100, ISDEFAULT = TRUE, ISMODIFIED = FALSE y 0 entradas en el SPFILE de la PDB (`incidentes/20261127T213712Z_INC-610_arreglo.txt`).
  Elegí RESET porque devuelve el valor por defecto en memoria y en el SPFILE. `SET = 100` lo dejaría marcado como modificado, y un `ALTER SESSION` solo arreglaría mi sesión.
- **Verificación (archivo de evidencia con todo OK):** `incidentes/20261127T213715Z_INC-610_verificar.txt`: 4 OK (valor 100, sin valor en el SPFILE de la PDB, la V2 vuelve a usar IX_T6_PED_CP).
- **Prevención (qué evitaría que se repita):** no tocar parámetros del optimizador sin ticket de cambio, prueba en sesión y medida antes y después. Vigilar los parámetros no por defecto de la PDB (V$SPPARAMETER, ISMODIFIED), como hace la verificación final. Restringir ALTER SYSTEM a los DBA o usar un PDB lockdown profile que impida cambiar los `optimizer_*`.

## Parte G · Incidente 3 · INC-611
- **Síntoma (con números):** el listado de Ciudad1425 / COM15 estima 3 clientes y son 50. El error sube por el plan: 28 pedidos estimados frente a 511 reales, en un plan de bucles anidados pensado para muy pocas filas (`incidentes/20261127T213718Z_INC-611_verificar.txt` y `20261127T213721Z_INC-611_diagnostico.txt`).
- **Playbook y pasos seguidos (herramientas y vistas):** PB-2, con E-Rows frente a A-Rows. Ejecuté el listado con GATHER_PLAN_STATISTICS y DISPLAY_CURSOR en ALLSTATS LAST. La primera línea que se separa es la 4 (CLIENTE, `filter("C"."COMUNIDAD"='COM15')`): 3 frente a 50. La 5 (IX_T6_CLI_CIUDAD) está bien, 50 frente a 50. Después usé `t6 estad CLIENTE` (`herramientas/20261127T213721Z_t6-estad.txt`): CIUDAD con NDV 2 000, COMUNIDAD con NDV 18, 100 000 filas y 0 extensiones.
- **Causa raíz:** no existe el grupo de columnas (CIUDAD, COMUNIDAD). El optimizador multiplica dos selectividades que no son independientes, porque cada ciudad está en una sola comunidad: 100 000 / 2 000 / 17 ≈ 3.
- **Arreglo aplicado (órdenes exactas) y por qué ese:** `SELECT DBMS_STATS.CREATE_EXTENDED_STATS('T6','CLIENTE','(CIUDAD, COMUNIDAD)') FROM dual;` y `EXEC DBMS_STATS.GATHER_TABLE_STATS('T6','CLIENTE', method_opt => 'FOR ALL COLUMNS SIZE 1 FOR COLUMNS SIZE 1 (CIUDAD, COMUNIDAD)', no_invalidate => FALSE)`.
  Después, la línea 4 estima 50 frente a 50 reales y la línea 2, 496 frente a 511 (`incidentes/20261127T213722Z_INC-611_arreglo.txt`). Es el arreglo mínimo: da al optimizador el dato que le faltaba sin forzar ningún plan. Con 50 clientes los bucles anidados siguen siendo correctos, pero ahora los elige con la cifra buena.
- **Verificación (archivo de evidencia con todo OK):** `incidentes/20261127T213725Z_INC-611_verificar.txt`: 3 OK (50 estimados y 50 reales, la extensión existe y tiene estadísticas).
- **Prevención (qué evitaría que se repita):** detectar las columnas correladas con DBMS_STATS.SEED_COL_USAGE y REPORT_COL_USAGE y crear sus grupos. Dejar las extensiones en los scripts del esquema para que no se pierdan al recrear la tabla, y no borrarlas sin revisar los planes que dependen de ellas.

## Parte H · Reflexión
1. El cambio con más mejora por menos riesgo fue el de **C17 (el tipo de dato de la búsqueda)**: una sola línea en la aplicación, sin tocar la base, y con la misma carga. La p95 bajó de 77,5 a 1,09 ms, el throughput subió de 3 364 a 31 651 búsquedas y las lecturas por ejecución de 5 274 a 98 (×124 en la línea base). La marcha atrás es volver a llamar a V1.
   Le sigue C14: 5 265 → 118 lecturas, con un índice invisible que se puede volver a ocultar al instante, aunque cuesta un +15 % de redo en cada DML.
2. Caso no evaluable (opcional): no he hecho todavía ningún caso sin ★.
