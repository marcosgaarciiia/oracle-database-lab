# Lab 6 · Respuestas · E025

## Preguntas de comprobación

1. Hubo **4 errores ORA-** en 24 h: `ORA-00800` de VKTM y LGWR al arrancar el contenedor. No son una alarma por sí solos porque se conoce su causa. En el arranque de la Parte C hubo además `ORA-00800` ×6 y `ORA-65019` ×2; este último fue provocado al reabrir la PDB sin `FORCE`. Evidencia: `evidencia/script/20261124T172417Z_01-turno.script.log`; `evidencia/script/20261124T180138Z_02-estados-pdb.script.log`.

2. `WEDNESDAY_WINDOW` empieza el miércoles a las **22:00** y dura **4 h**. AutoTask activadas: `auto optimizer stats collection`, `auto space advisor` y `sql tuning advisor`. Evidencia: `evidencia/spool/20261124T172448Z_01-automatizacion.spool.log`.

3. Con `SCOPE=SPFILE`, `V$SPPARAMETER=250` y `V$PARAMETER=200`: el cambio se guardó para el reinicio, pero aún no estaba en memoria. Sin `RESET`, el próximo arranque usaría 250. Evidencia: `evidencia/script/20261124T180127Z_02-parametros.script.log`.

4. El PFILE no tenía valor propio para `db_files`; `RESET` lo devuelve al valor por defecto. `processes` sí tenía `*.processes=200`: resetearlo también lo devolvería al valor por defecto, no a 200. Evidencia: `evidencia/config/20261124T180129Z_02-init_desde_spfile.ora`.

5. `C##OPS_RO` recibió **ORA-01109** porque `FREEPDB1` estaba `MOUNTED`. El CDB estaba abierto, pero la PDB no. Evidencia: `evidencia/script/20261124T180138Z_02-estados-pdb.script.log`.

6. Sesión: **SID 63**, **SERIAL# 64518**, **SPID 4904**, evento `PL/SQL lock timer`. `MODULE`, `ACTION` y `CLIENT_IDENTIFIER` mostraban aplicación, tarea y cliente; `USERNAME` solo la cuenta. Evidencia: `evidencia/script/20261124T180656Z_03-sesiones.script.log`.

7. Tras `CANCEL SQL` quedó **1 transacción abierta**. Tras `KILL SESSION` el log registró **0 sesiones vivas**, pero no contó transacciones. La fila 101 quedó `ACTIVO`; aparecieron `ORA-00028` y `ORA-03114`. Evidencia: `evidencia/script/20261124T180656Z_03-sesiones.script.log`.

8. `common_user_prefix` era **`C##`**; las cuentas comunes usan ese prefijo, como `C##OPS_RO`. Evidencia: `evidencia/script/20261124T180651Z_03-cuenta-app.script.log`.

9. **Resultados:**

   | Identidad | `USER_TABLES` | `ALL_TABLES` ADMIN_ACADEMIA | `ALL_USERS` | `DBA_USERS` | `CDB_USERS` | `V$DATAFILE` |
   |---|---:|---:|---:|---:|---|---:|
   | C##OPS_RO, raíz | 0 | 0 | 37 | 37 | raíz: 37; PDB: 44 | 17 |
   | C##OPS_RO, FREEPDB1 | 0 | 0 | 44 | 44 | PDB: 44 | 10 |
   | APP_ACADEMIA | 0 | 1 | 44 | ORA-00942 | ORA-00942 | ORA-00942 |

   Desde la PDB, `CDB_USERS` solo muestra esa PDB; `CONTAINER_DATA` amplía la vista desde la raíz. APP_ACADEMIA no tiene rol de catálogo, por eso recibe `ORA-00942`. Evidencia: `evidencia/script/20261124T181759Z_04-tres-miradas.script.log`.

10. **5.377** lecturas lógicas por recorrido; `DB time=0,74 s` y `DB CPU=0,66 s`. La poca diferencia indica poca espera. Evidencia: `evidencia/script/20261124T181047Z_04-deltas.script.log`.

11. Antes de la carga: **10 MB asignados**, **3,9 MB libres**, **40 MB máximo**, **15,16 % usado**. Para alertar sirve el porcentaje del máximo. Evidencia: `evidencia/script/20261124T181936Z_05-almacenamiento.script.log`.

12. El `INSERT` lo ejecutó una sesión SYSDBA; la cuota correspondía al dueño del segmento, **CARGA_HIST**. Sin cuota salió `ORA-01950`; al superar su cuota de **2 MB**, `ORA-01536`. Más espacio en el tablespace no aumenta la cuota. Evidencia: `evidencia/script/20261124T181936Z_05-almacenamiento.script.log`.

13. La carga se suspendió **15 s**, de **18:19:45** a **18:20:00**. El alert log registró `suspended` y `resumed`. Evidencia: `evidencia/script/20261124T181944Z_05-resumable.script.log`.

14. Antes del `SHRINK`: **2.000 filas, 2.944 bloques, 23 MB de cuota usada**. Después: **2.000 filas, 304 bloques, 2,4 MB**. Antes del `DELETE` había 20.000 filas. El `DELETE` no bajó la **HWM**; `SHRINK` la bajó y liberó bloques. Evidencias: `evidencia/script/20261124T181944Z_05-resumable.script.log`; `evidencia/script/20261124T182002Z_05-hwm-shrink.script.log`.

15. `DEFAULT`: intentos 10; inactividad 365; gracia 7; vida 180; bloqueo 1; reutilización máxima y tiempo `UNLIMITED`; rollover 0; verificación `NULL`. `PRF_PERSONAS`: intentos 3; bloqueo 1 min; vida 90 días; gracia 7; inactividad 90 días; función `ora12c_verify_function`. Tres intentos frenan pruebas de contraseña; un bloqueo corto protege sin cortar el acceso mucho tiempo. Evidencia: `evidencia/script/20261124T182242Z_06-gobierno-acceso.script.log` y `scripts/lab6/06-gobierno-acceso.sql`.

16. Ana leía por `SELECT ANY TABLE ON SCHEMA admin_academia`, concedido a `ROL_LECTURA_ACADEMIA` y heredado mediante `ROL_SECRETARIA_ACADEMIA`. Recibió `ORA-41900` al cambiar el nombre porque `UPDATE` solo permitía modificar `ESTADO`. Evidencia: `evidencia/script/20261124T182244Z_06-probar-acceso.script.log`.

17. Añadir columna: ningún objeto inválido. Ampliar `EMAIL_INSTITUCIONAL`: `V_CONTACTO_LAB6` inválida. Ampliar `NOMBRES`: `V_ACTIVOS_LAB6` y `F_TOTAL_ACTIVOS_LAB6` inválidas; `V_CONTACTO_LAB6` seguía inválida del cambio anterior. Evidencia: `evidencia/script/20261124T182358Z_07-objetos.script.log`.

18. Duplicar SGA no mejoraba el resultado: `ESTD_DB_TIME_FACTOR=1,0`; con la mitad era **1,0147**. PGA: `OVERALLOC=4` con **256 MB**; sobreasignación por debajo de **384 MB**. Evidencias: `evidencia/script/20261124T182406Z_07-memoria.script.log`; `evidencia/spool/20261124T182413Z_07-memoria.spool.log`.

19. La consulta necesitó **247 lecturas lógicas**; aparece en `FETCH` como `cr=247`. Evidencia: `evidencia/script/20261124T182425Z_07-adr-trazas.script.log`.

20. **Guardia:**
   - **INC-601:** Ana (SID 218) esperaba por bloqueo de APP_ACADEMIA (SID 213). Se terminó el bloqueador con `KILL SESSION`. Sin bloqueos y fila 101 `ACTIVO`. Evidencias: logs `20261124T192540Z`, `192612Z`, `192613Z` y `192620Z` de `08-*`.
   - **INC-602:** PDB abierta, servicio `academia_app` parado. Se arrancó con `DBMS_SERVICE.START_SERVICE` y se guardó el estado. APP_ACADEMIA entró y leyó **17.600 filas**. Listener confirmó `READY` después, a las **19:18:27**. Evidencias: logs `20261125T122420Z`, `122912Z`, `122914Z`, `122925Z` y `191827Z` de `08-*`.
   - **INC-603:** `APP_ACADEMIA` estaba `LOCKED`; SYS la bloqueó a las **18:51:38**. Se desbloqueó y la aplicación volvió a entrar. Evidencias: logs `20261125T185138Z`, `185209Z`, `190256Z`, `190306Z` y `190351Z` de `08-*`.

## Simulacro S1-S22

| Pregunta | Respuesta | Parte |
|---|---|---|
| S1 | **B — MMON** | B |
| S2 | **C — Se aplica a nuevas sesiones** | C |
| S3 | **B — `CREATE PFILE FROM MEMORY`** | C |
| S4 | **B y C** | C |
| S5 | **C — `DBA_PDB_SAVED_STATES`** | C |
| S6 | **B — ORA-01035** | C |
| S7 | **A — `DBMS_SERVICE`** | D |
| S8 | **B — `PADDR = ADDR`** | D |
| S9 | **C — Se cancela la llamada; la transacción sigue abierta** | D |
| S10 | **C — PUBLIC** | D |
| S11 | **B — `V$CON_SYSMETRIC`** | E |
| S12 | **A y C — CPU y esperas no idle** | E |
| S13 | **B — HR** | F |
| S14 | **A y C — Undo y temporal** | F |
| S15 | **A y C — Se suspende y aparece en `DBA_RESUMABLE`** | F |
| S16 | **B — ASSM y `ENABLE ROW MOVEMENT`** | F |
| S17 | **B — `LOCKED(TIMED)`** | G |
| S18 | **B — B conserva `CREATE TABLE`** | G |
| S19 | **A y B — `MOVE` sin actualizar índices; marcar `UNUSABLE`** | H |
| S20 | **B — `DBMS_MONITOR.SESSION_TRACE_ENABLE`** | H |
| S21 | **C — `DIAGNOSTIC_DEST`** | H |
| S22 | **C — Identificar al bloqueador** | I |

## Otras preguntas tipo examen

| Pregunta | Respuesta | Parte |
|---|---|---|
| C1 | **B — Guardar `db_files` en el SPFILE** | C |
| C2 | **A y C — Abrir la PDB y guardar su estado** | C |
| D1 | **B — `CANCEL SQL`** | D |
| E1 | **B — Ver solo usuarios de FREEPDB1** | E |
| F1 | **C — Dar cuota a `HIST`, dueño de la tabla** | F |
| G1 | **B — Conserva `CREATE TABLE`; pierde `SELECT`** | G |
| G2 | **B — Leer tablas actuales y futuras de VENTAS** | G |
| H1 | **B — Los índices quedaron `UNUSABLE`** | H |

