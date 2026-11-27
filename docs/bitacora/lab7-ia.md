He leído la política de uso de IA de la asignatura.

# Declaración de uso de IA · Lab 7 · E025

<!-- Antes de entregar: relee cada «Qué hace» y reescríbelo con tus palabras si hace falta. El control de autoría pregunta por esto. -->

## Entrada 1
- **Herramienta:** Claude (app de escritorio de Claude, modelo Claude Opus 5.5)
- **Prompt (literal, copiado tal cual):**
```text
realiza la práctica
ten en cuenta la rubrica de evaluacion y las cosas que se pidan para entregar
```
- **Código recibido (el fragmento, o la ruta del archivo donde está):**
```text
scripts/lab7/lab7-E025.sh
```
- **Dónde lo usé (parte, script o pregunta):** Partes A a H: lanzar el kit (caso, t6 e incidente) en orden y dejar la evidencia de cada fase
- **Propósito (para qué lo necesitaba):** ejecutar las seis fases de los diez casos ★ y el ciclo de mis tres incidentes sin olvidarme de ninguna fase, y repetir solucionar y validar si una validación sale en FALLO
- **Qué hace (con mis palabras; línea a línea si es SQL corto):** cada parte llama a `bash scripts/t6/caso.sh Cnn <fase>` para las seis fases de sus casos. Después mira la última evidencia de `validar`: si tiene alguna línea FALLO, repite `solucionar` y `validar`. Si sigue fallando, rehace el banco con `caso --preparar` y repite el caso. Entre casos mira la FRA y, si pasa del 50 %, la libera con `t6 fra --liberar`. La Parte A copia el kit, hace la copia lab7-inicio, pone ESTUDIANTE=E025 y crea el banco T6 y la rama. La Parte G rompe cada incidente, lanza las herramientas t6 del playbook, aplica el arreglo con sqlplus guardando las órdenes y la salida con mi cabecera, y verifica. El script no hace commits: los hago yo.
- **Evidencia de ejecución (archivo de docs/bitacora/lab7/evidencia con mi cabecera):** docs/bitacora/lab7/evidencia/casos/20261127T212656Z_C01_validar.txt (y el resto de docs/bitacora/lab7/evidencia/casos/)

## Entrada 2
- **Herramienta:** Claude (app de escritorio de Claude, modelo Claude Opus 5.5)
- **Prompt (literal, copiado tal cual):**
```text
realiza la práctica
```
- **Código recibido (el fragmento, o la ruta del archivo donde está):**
```sql
EXEC DBMS_STATS.SET_TABLE_PREFS('T6', 'PEDIDO', 'PUBLISH', 'FALSE')
EXEC DBMS_STATS.SET_TABLE_PREFS('T6', 'PEDIDO', 'METHOD_OPT', 'FOR ALL COLUMNS SIZE 1 FOR COLUMNS ESTADO SIZE 254')
EXEC DBMS_STATS.GATHER_TABLE_STATS('T6', 'PEDIDO')
ALTER SESSION SET optimizer_use_pending_statistics = TRUE;
EXPLAIN PLAN FOR SELECT COUNT(*), SUM(importe), MAX(fecha_pedido) FROM t6.pedido WHERE estado = 'D';
ALTER SESSION SET optimizer_use_pending_statistics = FALSE;
EXEC DBMS_STATS.PUBLISH_PENDING_STATS('T6', 'PEDIDO', no_invalidate => FALSE)
EXEC DBMS_STATS.SET_TABLE_PREFS('T6', 'PEDIDO', 'PUBLISH', 'TRUE')
```
- **Dónde lo usé (parte, script o pregunta):** Parte G, incidente INC-608
- **Propósito (para qué lo necesitaba):** recuperar el histograma de ESTADO de forma que la recogida nocturna no lo vuelva a borrar, con el runbook RB-2 (estadísticas con red)
- **Qué hace (con mis palabras; línea a línea si es SQL corto):** (1) las recogidas de PEDIDO quedan pendientes y no se publican. (2) Cambia la preferencia de la tabla: SIZE 1 en todas las columnas menos ESTADO, que pide histograma (hasta 254 cubos). Esa preferencia era la causa raíz. (3) Recoge las estadísticas, que quedan pendientes. (4) Solo en mi sesión, el optimizador usa las pendientes. (5) Con EXPLAIN PLAN compruebo que la estimación para 'D' ya se parece a las filas reales. (6) Vuelvo a las publicadas. (7) Publico las pendientes e invalido los cursores. (8) Dejo PUBLISH otra vez en TRUE para que las próximas recogidas se publiquen.
- **Evidencia de ejecución (archivo de docs/bitacora/lab7/evidencia con mi cabecera):** docs/bitacora/lab7/evidencia/incidentes/20261127T213659Z_INC-608_arreglo.txt

## Entrada 3
- **Herramienta:** Claude (app de escritorio de Claude, modelo Claude Opus 5.5)
- **Prompt (literal, copiado tal cual):**
```text
realiza la práctica
```
- **Código recibido (el fragmento, o la ruta del archivo donde está):**
```sql
ALTER SESSION SET CONTAINER = FREEPDB1;
ALTER SYSTEM RESET optimizer_index_cost_adj SCOPE = BOTH;
SELECT name, value, isdefault, ismodified FROM v$system_parameter WHERE name = 'optimizer_index_cost_adj';
```
- **Dónde lo usé (parte, script o pregunta):** Parte G, incidente INC-610
- **Propósito (para qué lo necesitaba):** devolver al valor por defecto (100) el parámetro que el «consultor» había subido en la PDB y que hacía caros todos los accesos por índice
- **Qué hace (con mis palabras; línea a línea si es SQL corto):** entra en la PDB. RESET quita el valor del parámetro en memoria y en el SPFILE de la PDB (SCOPE = BOTH), y así vuelve a heredar el valor por defecto, 100. No basta con un ALTER SESSION, porque solo arregla mi sesión, ni con un SET = 100, porque el parámetro seguiría marcado como modificado. La consulta a V$SYSTEM_PARAMETER confirma que el valor es 100 e ISDEFAULT = TRUE.
- **Evidencia de ejecución (archivo de docs/bitacora/lab7/evidencia con mi cabecera):** docs/bitacora/lab7/evidencia/incidentes/20261127T213712Z_INC-610_arreglo.txt

## Entrada 4
- **Herramienta:** Claude (app de escritorio de Claude, modelo Claude Opus 5.5)
- **Prompt (literal, copiado tal cual):**
```text
realiza la práctica
```
- **Código recibido (el fragmento, o la ruta del archivo donde está):**
```sql
SELECT DBMS_STATS.CREATE_EXTENDED_STATS('T6', 'CLIENTE', '(CIUDAD, COMUNIDAD)') AS extension FROM dual;
EXEC DBMS_STATS.GATHER_TABLE_STATS('T6', 'CLIENTE', method_opt => 'FOR ALL COLUMNS SIZE 1 FOR COLUMNS SIZE 1 (CIUDAD, COMUNIDAD)', no_invalidate => FALSE)
```
- **Dónde lo usé (parte, script o pregunta):** Parte G, incidente INC-611
- **Propósito (para qué lo necesitaba):** que el optimizador estime bien los clientes de una ciudad y su comunidad, que son columnas correladas
- **Qué hace (con mis palabras; línea a línea si es SQL corto):** (1) crea un grupo de columnas (una columna virtual SYS_STU...) que representa la pareja (CIUDAD, COMUNIDAD). (2) Recoge estadísticas incluyendo ese grupo. Así el optimizador conoce cuántas combinaciones distintas hay y ya no multiplica la selectividad de la ciudad por la de la comunidad, como si fueran independientes. No_invalidate => FALSE invalida los cursores para que el listado se vuelva a optimizar.
- **Evidencia de ejecución (archivo de docs/bitacora/lab7/evidencia con mi cabecera):** docs/bitacora/lab7/evidencia/incidentes/20261127T213722Z_INC-611_arreglo.txt

## Entrada 5
- **Herramienta:** Claude (app de escritorio de Claude, modelo Claude Opus 5.5)
- **Prompt (literal, copiado tal cual):**
```text
ten en cuenta la rubrica de evaluacion y las cosas que se pidan para entregar
```
- **Código recibido (el fragmento, o la ruta del archivo donde está):** no aplica
- **Dónde lo usé (parte, script o pregunta):** docs/bitacora/lab7-respuestas.md (todas las preguntas y los tres postmortems)
- **Propósito (para qué lo necesitaba):** estructurar las respuestas y los postmortems a partir de las cifras de mis propias evidencias
- **Qué hace (con mis palabras; línea a línea si es SQL corto):** organiza en 3 a 6 líneas por pregunta los números que salen de mis evidencias, citando el archivo de cada cifra, y explica qué significan con el vocabulario del Tema 6. Las he revisado con mis salidas.
- **Evidencia de ejecución (archivo de docs/bitacora/lab7/evidencia con mi cabecera):** no aplica
