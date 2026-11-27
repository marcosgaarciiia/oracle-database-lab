#!/usr/bin/env bash
# lab7.sh · Laboratorio 7 (Oracle Performance Tuning) · alumno E025
# Ejecuta cada parte con el kit scripts/t6 y deja la evidencia en docs/bitacora/lab7/evidencia/ con tu cabecera.
# NO hace commits ni push: eso lo haces tú a mano al final de cada parte (política de IA, D2).
#
#   bash lab7.sh A <nº Issue>   kit, copia lab7-inicio, código de alumno, IA, banco T6, rama perf/<nº>-optimizacion
#   bash lab7.sh B              C01                (unos 5 min)
#   bash lab7.sh C              C03 C04            (unos 5 min)
#   bash lab7.sh D              C07 C08            (unos 5 min)
#   bash lab7.sh E              C12 C13 C14        (unos 6 min)
#   bash lab7.sh F              C17 C18            (unos 10 min: C17 lanza 2 cargas de 2 min)
#   bash lab7.sh G              INC-608 INC-610 INC-611: romper, pistas, diagnóstico, arreglo, verificar
#   bash lab7.sh H              copia respuestas e IA definitivas y lanza 09-verificacion-final.sh
#   bash lab7.sh exportar       copia la evidencia a esta carpeta de Windows (para redactar las respuestas)
set -uo pipefail
EST=E025
DL="$(cd "$(dirname "$0")" && pwd)"
ZIP="$DL/../P2_Lab7_v1.0_Estudiante.zip"
REPO="${REPO:-$HOME/oracle-database-lab}"
CONT="${CONT_NAME:-oralab-26ai}"
PARTE="${1:-}"; [ $# -gt 0 ] && shift
[ -n "$PARTE" ] || { sed -n '2,16p' "$0" | sed 's/^# \{0,1\}//'; exit 2; }
mkdir -p "$DL/logs"
LOG="$DL/logs/parte_${PARTE}_$(date +%Y%m%dT%H%M%S).log"
exec > >(tee -a "$LOG") 2>&1
cd "$REPO" 2>/dev/null || { echo "No encuentro tu repositorio en $REPO (usa REPO=/ruta bash lab7.sh ...)"; exit 2; }

CASO="bash scripts/t6/caso.sh"; T6="bash scripts/t6/t6.sh"; INC="bash scripts/t6/incidente.sh"
EVC=docs/bitacora/lab7/evidencia/casos; EVI=docs/bitacora/lab7/evidencia/incidentes
S=$((10#${EST#E}))                         # semilla de los incidentes (25)
FASES="provocar entender diagnosticar solucionar validar observar"
PENDIENTES=""

titulo() { printf '\n\033[1;36m################ %s\033[0m\n' "$*"; }
dba() { docker exec -i -e NLS_LANG=AMERICAN_AMERICA.AL32UTF8 "$CONT" sqlplus -s -L / as sysdba; }
cabecera() {   # mismas dos líneas que pone el kit, leídas de la base
  local bd
  bd=$(printf '%s\n' "SET HEADING OFF FEEDBACK OFF PAGESIZE 0 LINESIZE 300" \
    "SELECT 'hora=' || TO_CHAR(SYS_EXTRACT_UTC(SYSTIMESTAMP), 'YYYY-MM-DD\"T\"HH24:MI:SS\"Z\"') || ' contenedor=' || i.host_name || ' dbid=' || d.dbid || ' arranque=' || TO_CHAR(i.startup_time, 'YYYY-MM-DD\"T\"HH24:MI:SS') || ' scn=' || d.current_scn FROM v\$instance i, v\$database d;" \
    | dba 2>/dev/null | awk '/^hora=/ && !v {print; v=1}')
  echo "== EVIDENCIA alumno=$EST ${bd%% *} origen=t6/$1"
  echo "== EVIDENCIA ${bd#* }"
}
sqlev() {   # sqlev <nombre>  (SQL por la entrada estándar) -> se ejecuta en sqlplus y queda evidencia con órdenes y salida
  local sql out dest
  sql=$(cat); mkdir -p "$EVI"
  out=$(printf 'SET LINESIZE 220 PAGESIZE 200 FEEDBACK ON VERIFY OFF TRIMSPOOL ON\n%s\nEXIT\n' "$sql" | dba 2>&1)
  dest="$EVI/$(date -u +%Y%m%dT%H%M%SZ)_$1.txt"
  { cabecera "$1"; echo "-- Órdenes ejecutadas en sqlplus (/ as sysdba):"; echo "$sql" | sed 's/^/   /'; echo; echo "-- Salida:"; echo "$out"; } > "$dest"
  echo "$out"; echo "   evidencia: $dest"
}
ultimo() { ls -1 "$1"/*_"$2".txt 2>/dev/null | sort | tail -1; }
validar_mal() { local v; v=$(ultimo "$EVC" "${1}_validar"); [ -z "$v" ] || grep -aq '^FALLO' "$v" || ! grep -aq '^OK' "$v"; }
fra() {
  local p; p=$(printf 'SET HEADING OFF FEEDBACK OFF\nSELECT ROUND(100*space_used/space_limit) FROM v$recovery_file_dest;\nEXIT\n' | dba | tr -dc '0-9')
  echo "   FRA al ${p:-?} %"
  if [ "${p:-0}" -ge 50 ] 2>/dev/null; then $T6 fra --liberar; fi
}
fases() { local c=$1 p; for p in $FASES; do titulo "$c · $p"; $CASO "$c" "$p"; done; }
caso_completo() {
  local c=$1
  fases "$c"
  if validar_mal "$c"; then titulo "$c: validar con FALLO -> repito solucionar y validar"; $CASO "$c" solucionar; $CASO "$c" validar; fi
  if validar_mal "$c"; then
    titulo "$c: sigue con FALLO -> caso --preparar y el caso entero otra vez"
    $CASO --preparar; fases "$c"
    [ "$c" = C18 ] && { titulo "C18 necesitó --preparar: rehago C17 para recuperar la línea base"; fases C17; }
  fi
  if validar_mal "$c"; then echo "XX $c sigue con FALLO: $(ultimo "$EVC" "${c}_validar")"; PENDIENTES="$PENDIENTES $c"
  else echo "== $c: validación correcta ($(grep -ac '^OK' "$(ultimo "$EVC" "${c}_validar")") OK)"; fi
  fra
}
exportar() {
  local d="$DL/export"; mkdir -p "$d"
  cp -r docs/bitacora/lab7 "$d/" 2>/dev/null
  cp docs/bitacora/lab7-respuestas.md docs/bitacora/lab7-ia.md "$d/" 2>/dev/null
  { git branch --show-current; git status --short | head -50; git log --oneline -15; git tag -l 'lab*'; } > "$d/git.txt" 2>&1
  echo "   copia para redactar respuestas: $DL/export"
}
commit_msg() {   # lo que tienes que escribir tú
  printf '\n\033[1;33m==> Ahora haz TÚ el commit de esta parte (a mano, sin coautores):\033[0m\n'
  echo "   cd $REPO"
  echo "   git add $1"
  echo "   git commit -m \"$2\" -m \"Refs #$(git branch --show-current | sed -n 's#^perf/\([0-9]*\)-.*#\1#p')\""
}
fin_parte() { exportar; [ -n "$PENDIENTES" ] && echo "!! Revisa:$PENDIENTES (mira el log $LOG)"; commit_msg "$@"; }

case "$PARTE" in
A)
  ISSUE="${1:-}"; [[ "$ISSUE" =~ ^[0-9]+$ ]] || { echo "Uso: bash lab7.sh A <número del Issue que has creado en GitHub>"; exit 2; }
  titulo "A.0 · Prerrequisitos"
  docker ps --format '{{.Names}} {{.Status}}' | grep "^$CONT " || { echo "Arranca el contenedor: docker start $CONT (y espera 1 min)"; exit 2; }
  git tag -l lab6-final | grep -q . && echo "OK etiqueta lab6-final" || echo "AVISO: no existe la etiqueta lab6-final (la verificación revisa los commits desde ella)"
  for f in scripts/ops/backup-estado.sh scripts/ops/alumno.sh scripts/ops/cabecera.sh scripts/deployment/env/00-config.sh config/.env; do
    [ -e "$f" ] && echo "OK $f" || { echo "FALTA $f (viene del Lab 5/6)"; exit 2; }; done
  [ -f "$ZIP" ] || { echo "No encuentro $ZIP"; exit 2; }
  if [ "$(git branch --show-current)" = main ]; then
    [ -z "$(git status --porcelain --untracked-files=no)" ] || { echo "Tienes cambios sin commit en main: resuélvelos antes."; git status --short; exit 2; }
    git pull --ff-only || echo "AVISO: git pull no se pudo hacer (sigo con tu main local)"
  elif ! git branch --show-current | grep -q '^perf/'; then
    git switch main && git pull --ff-only || { echo "No puedo pasar a main"; exit 2; }
  fi
  titulo "A.1 · Zip y kit en el repositorio"
  cp "$ZIP" ~/ && unzip -o -q ~/P2_Lab7_v1.0_Estudiante.zip -d ~/lab7-entrega && cp -r ~/lab7-entrega/repo-kit/. .
  mkdir -p scripts/lab7 && cp "$0" scripts/lab7/lab7-E025.sh
  ls scripts/t6 scripts/lab7
  titulo "A.3 · Copia de seguridad lab7-inicio (para el contenedor unos minutos)"
  BK=$(ls -d backups/*_lab7-inicio 2>/dev/null | tail -1)
  if [ -n "$BK" ] && (cd "$BK" && sha256sum -c --quiet SHA256SUMS); then echo "Ya existe y está íntegra: $BK"
  else bash scripts/ops/backup-estado.sh lab7-inicio || { echo "Falló la copia lab7-inicio"; exit 2; }; fi
  ls -d backups/*_lab7-inicio
  echo "Esperando a que $CONT esté healthy..."
  for i in $(seq 1 60); do docker ps --format '{{.Names}} {{.Status}}' | grep "^$CONT " | grep -q healthy && break; sleep 5; done
  docker ps --format '{{.Names}} {{.Status}}' | grep "^$CONT "
  titulo "A.4 · Código de alumno E025"
  if grep -q '^ESTUDIANTE=' config/.env; then sed -i "s/^ESTUDIANTE=.*/ESTUDIANTE=\"$EST\"/" config/.env; else echo "ESTUDIANTE=\"$EST\"" >> config/.env; fi
  grep ESTUDIANTE config/.env
  bash scripts/ops/alumno.sh
  titulo "A.2 · instalar.sh"
  bash scripts/t6/instalar.sh
  titulo "A.4 · Archivos de agente fuera del repositorio"
  hay=0
  for a in .claude CLAUDE.md AGENTS.md .cursor .cursorrules GEMINI.md .gemini .codex .aider.conf.yml .windsurfrules .github/copilot-instructions.md; do
    if [ -e "$a" ]; then hay=1; git rm -r -q --cached "$a" 2>/dev/null; mkdir -p ~/agentes-fuera-del-repo; mv "$a" ~/agentes-fuera-del-repo/
      grep -qxF "$a" .gitignore 2>/dev/null || echo "$a" >> .gitignore; echo "retirado $a -> ~/agentes-fuera-del-repo/"; fi
  done
  [ $hay = 0 ] && echo "Sin archivos de agente"
  titulo "A.5 · Banco T6"
  $CASO --preparar; $CASO --lista; $T6 salud
  titulo "A.6 · Rama, plantillas y .gitignore"
  git switch -c "perf/${ISSUE}-optimizacion" 2>/dev/null || git switch "perf/${ISSUE}-optimizacion"
  mkdir -p docs/bitacora
  [ -f docs/bitacora/lab7-respuestas.md ] || { cp docs/plantillas/lab7-respuestas.md docs/bitacora/lab7-respuestas.md; sed -i "s/E0NN/$EST/" docs/bitacora/lab7-respuestas.md; }
  cp "$DL/lab7-ia.md" docs/bitacora/lab7-ia.md
  grep -q 'scripts/t6/salidas/' .gitignore || echo 'scripts/t6/salidas/' >> .gitignore
  grep -qx 'backups/' .gitignore || grep -q '^backups' .gitignore || echo 'backups/' >> .gitignore
  git status --short | head -30
  fin_parte "scripts/ docs/ config/.env.example .gitignore" "chore(perf): add Lab 7 kit, AI declaration and answers template"
  ;;
B) caso_completo C01
   fin_parte "docs/bitacora/lab7/evidencia/" "perf(t6): Part B - C01 baseline, AAS vs CPU_COUNT and pool sizing";;
C) caso_completo C03; caso_completo C04
   fin_parte "docs/bitacora/lab7/evidencia/" "perf(t6): Part C - C03 hard parse storm and C04 TEMP spill";;
D) caso_completo C07; caso_completo C08
   fin_parte "docs/bitacora/lab7/evidencia/" "perf(t6): Part D - C07 implicit conversion and C08 E-Rows vs A-Rows";;
E) caso_completo C12; caso_completo C13; caso_completo C14
   fin_parte "docs/bitacora/lab7/evidencia/" "perf(t6): Part E - C12 stale stats, C13 stats with a safety net, C14 invisible index";;
F) caso_completo C17; caso_completo C18
   fin_parte "docs/bitacora/lab7/evidencia/" "perf(t6): Part F - C17 INC-604 with AWR/ASH/ADDM and C18 SQL Plan Management";;
G)
  $INC --mios
  # ---------------------------------------------------------------- INC-608 (PB-3, RB-2)
  case $((S % 3)) in 0) V608=P;; 1) V608=D;; *) V608=P;; esac
  titulo "INC-608 · romper y pistas"; $INC INC-608 romper; $INC INC-608 pistas; $INC INC-608 verificar
  titulo "INC-608 · diagnóstico (PB-3: qué cambió en las estadísticas)"
  $T6 estad PEDIDO
  sqlev INC-608_diagnostico <<SQL
ALTER SESSION SET CONTAINER = FREEPDB1;
DELETE FROM plan_table;
EXPLAIN PLAN FOR SELECT COUNT(*), SUM(importe), MAX(fecha_pedido) FROM t6.pedido WHERE estado = '$V608';
SELECT * FROM TABLE(DBMS_XPLAN.DISPLAY(format => 'BASIC +ROWS +PREDICATE'));
SELECT COUNT(*) AS reales FROM t6.pedido WHERE estado = '$V608';
SELECT column_name, num_distinct, histogram FROM dba_tab_col_statistics WHERE owner = 'T6' AND table_name = 'PEDIDO' AND column_name = 'ESTADO';
SELECT DBMS_STATS.GET_PREFS('METHOD_OPT', 'T6', 'PEDIDO') AS method_opt_pedido, DBMS_STATS.GET_PREFS('METHOD_OPT') AS method_opt_global FROM dual;
SELECT TO_CHAR(stats_update_time, 'YYYY-MM-DD HH24:MI:SS') AS recogidas FROM dba_tab_stats_history WHERE owner = 'T6' AND table_name = 'PEDIDO' ORDER BY stats_update_time DESC FETCH FIRST 3 ROWS ONLY;
ROLLBACK;
SQL
  titulo "INC-608 · arreglo con red (RB-2): preferencia, pendientes, probar en sesión, publicar"
  sqlev INC-608_arreglo <<SQL
ALTER SESSION SET CONTAINER = FREEPDB1;
EXEC DBMS_STATS.SET_TABLE_PREFS('T6', 'PEDIDO', 'PUBLISH', 'FALSE')
EXEC DBMS_STATS.SET_TABLE_PREFS('T6', 'PEDIDO', 'METHOD_OPT', 'FOR ALL COLUMNS SIZE 1 FOR COLUMNS ESTADO SIZE 254')
EXEC DBMS_STATS.GATHER_TABLE_STATS('T6', 'PEDIDO')
SELECT COUNT(*) AS cubos_histograma_pendiente FROM dba_tab_histgrm_pending_stats WHERE owner = 'T6' AND table_name = 'PEDIDO' AND column_name = 'ESTADO';
ALTER SESSION SET optimizer_use_pending_statistics = TRUE;
DELETE FROM plan_table;
EXPLAIN PLAN FOR SELECT COUNT(*), SUM(importe), MAX(fecha_pedido) FROM t6.pedido WHERE estado = '$V608';
SELECT * FROM TABLE(DBMS_XPLAN.DISPLAY(format => 'BASIC +ROWS +PREDICATE'));
ALTER SESSION SET optimizer_use_pending_statistics = FALSE;
EXEC DBMS_STATS.PUBLISH_PENDING_STATS('T6', 'PEDIDO', no_invalidate => FALSE)
EXEC DBMS_STATS.SET_TABLE_PREFS('T6', 'PEDIDO', 'PUBLISH', 'TRUE')
SELECT column_name, histogram FROM dba_tab_col_statistics WHERE owner = 'T6' AND table_name = 'PEDIDO' AND column_name = 'ESTADO';
SELECT DBMS_STATS.GET_PREFS('METHOD_OPT', 'T6', 'PEDIDO') AS method_opt, DBMS_STATS.GET_PREFS('PUBLISH', 'T6', 'PEDIDO') AS publish FROM dual;
ROLLBACK;
SQL
  $T6 estad PEDIDO
  titulo "INC-608 · verificar"; $INC INC-608 verificar
  # ---------------------------------------------------------------- INC-610 (PB-3, RB-1)
  titulo "INC-610 · romper y pistas"; $INC INC-610 romper; $INC INC-610 pistas; $INC INC-610 verificar
  titulo "INC-610 · diagnóstico (PB-3: muchos planes a la vez -> causa común)"
  $T6 salud; $T6 top 5
  sqlev INC-610_diagnostico <<'SQL'
ALTER SESSION SET CONTAINER = FREEPDB1;
COLUMN name FORMAT A32
COLUMN value FORMAT A12
SELECT name, value, isdefault, ismodified, ispdb_modifiable FROM v$system_parameter WHERE isdefault = 'FALSE' AND (name LIKE 'optimizer%' OR name = 'cursor_sharing');
SELECT name, value, isspecified, con_id FROM v$spparameter WHERE isspecified = 'TRUE' AND name LIKE 'optimizer%';
BEGIN t6.app.buscar_cp_v2('30038'); ROLLBACK; END;
/
COLUMN sql_id NEW_VALUE sqlid
SELECT sql_id, plan_hash_value, executions, ROUND(buffer_gets/GREATEST(executions,1)) AS lecturas_por_ejec FROM v$sql WHERE sql_text LIKE 'SELECT /*+ t6_cp_v2 */%' AND ROWNUM = 1;
SELECT * FROM TABLE(DBMS_XPLAN.DISPLAY_CURSOR('&sqlid', NULL, 'BASIC +PREDICATE +OUTLINE'));
PROMPT -- Hipótesis probada SOLO en esta sesión: con el valor por defecto (100) el plan vuelve al índice
DELETE FROM plan_table;
EXPLAIN PLAN FOR SELECT COUNT(*), SUM(importe) FROM t6.pedido WHERE codigo_postal = :cp;
SELECT * FROM TABLE(DBMS_XPLAN.DISPLAY(format => 'BASIC +COST'));
ALTER SESSION SET optimizer_index_cost_adj = 100;
DELETE FROM plan_table;
EXPLAIN PLAN FOR SELECT COUNT(*), SUM(importe) FROM t6.pedido WHERE codigo_postal = :cp;
SELECT * FROM TABLE(DBMS_XPLAN.DISPLAY(format => 'BASIC +COST'));
ROLLBACK;
SQL
  titulo "INC-610 · arreglo: devolver el parámetro de la PDB a su valor por defecto (RESET)"
  sqlev INC-610_arreglo <<'SQL'
ALTER SESSION SET CONTAINER = FREEPDB1;
ALTER SYSTEM RESET optimizer_index_cost_adj SCOPE = BOTH;
COLUMN name FORMAT A32
COLUMN value FORMAT A12
SELECT name, value, isdefault, ismodified FROM v$system_parameter WHERE name = 'optimizer_index_cost_adj';
SELECT COUNT(*) AS en_spfile_pdb FROM v$spparameter WHERE name = 'optimizer_index_cost_adj' AND isspecified = 'TRUE' AND con_id = (SELECT con_id FROM v$pdbs WHERE name = 'FREEPDB1');
SQL
  quedan=$(printf "SET HEADING OFF FEEDBACK OFF\nALTER SESSION SET CONTAINER = FREEPDB1;\nSELECT COUNT(*) FROM v\$system_parameter WHERE name = 'optimizer_index_cost_adj' AND (value <> '100' OR (isdefault = 'FALSE' AND ismodified <> 'FALSE'));\nSELECT COUNT(*) FROM v\$spparameter WHERE name = 'optimizer_index_cost_adj' AND isspecified = 'TRUE' AND con_id = (SELECT con_id FROM v\$pdbs WHERE name = 'FREEPDB1');\nEXIT\n" | dba | awk '/^ *[0-9]+ *$/ {t+=$1} END {print t+0}')
  if [ "${quedan:-0}" != 0 ]; then
    titulo "INC-610 · el RESET en memoria no bastó: quito del SPFILE de la PDB y la reabro"
    sqlev INC-610_arreglo_reabrir <<'SQL'
ALTER SESSION SET CONTAINER = FREEPDB1;
ALTER SYSTEM RESET optimizer_index_cost_adj SCOPE = SPFILE;
ALTER SESSION SET CONTAINER = CDB$ROOT;
ALTER PLUGGABLE DATABASE freepdb1 CLOSE IMMEDIATE;
ALTER PLUGGABLE DATABASE freepdb1 OPEN;
ALTER SESSION SET CONTAINER = FREEPDB1;
SELECT name, value, isdefault, ismodified FROM v$system_parameter WHERE name = 'optimizer_index_cost_adj';
SQL
  fi
  titulo "INC-610 · verificar"; $INC INC-610 verificar
  # ---------------------------------------------------------------- INC-611 (PB-2, RB-2)
  n=$((100 + (S * 53) % 1800)); CIU=$(printf 'Ciudad%04d' "$n"); COM=$(printf 'COM%02d' $((n % 17 + 1)))
  titulo "INC-611 · romper y pistas ($CIU / $COM)"; $INC INC-611 romper; $INC INC-611 pistas; $INC INC-611 verificar
  titulo "INC-611 · diagnóstico (PB-2: E-Rows frente a A-Rows)"
  $T6 estad CLIENTE
  sqlev INC-611_diagnostico <<SQL
ALTER SESSION SET CONTAINER = FREEPDB1;
SELECT /*+ GATHER_PLAN_STATISTICS inc611_antes */ COUNT(*), SUM(p.importe)
  FROM t6.cliente c JOIN t6.pedido p ON p.id_cliente = c.id_cliente
 WHERE c.ciudad = '$CIU' AND c.comunidad = '$COM';
SELECT * FROM TABLE(DBMS_XPLAN.DISPLAY_CURSOR(format => 'ALLSTATS LAST +PREDICATE -NOTE'));
SELECT COUNT(*) AS clientes_reales FROM t6.cliente WHERE ciudad = '$CIU' AND comunidad = '$COM';
SELECT column_name, num_distinct FROM dba_tab_col_statistics WHERE owner = 'T6' AND table_name = 'CLIENTE' AND column_name IN ('CIUDAD', 'COMUNIDAD');
SELECT (SELECT num_rows FROM dba_tables WHERE owner = 'T6' AND table_name = 'CLIENTE') AS num_rows FROM dual;
SELECT COUNT(*) AS extensiones FROM dba_stat_extensions WHERE owner = 'T6' AND table_name = 'CLIENTE' AND creator = 'USER';
SQL
  titulo "INC-611 · arreglo: grupo de columnas (CIUDAD, COMUNIDAD) y recoger"
  sqlev INC-611_arreglo <<SQL
ALTER SESSION SET CONTAINER = FREEPDB1;
SELECT DBMS_STATS.CREATE_EXTENDED_STATS('T6', 'CLIENTE', '(CIUDAD, COMUNIDAD)') AS extension FROM dual;
EXEC DBMS_STATS.GATHER_TABLE_STATS('T6', 'CLIENTE', method_opt => 'FOR ALL COLUMNS SIZE 1 FOR COLUMNS SIZE 1 (CIUDAD, COMUNIDAD)', no_invalidate => FALSE)
SELECT /*+ GATHER_PLAN_STATISTICS inc611_despues */ COUNT(*), SUM(p.importe)
  FROM t6.cliente c JOIN t6.pedido p ON p.id_cliente = c.id_cliente
 WHERE c.ciudad = '$CIU' AND c.comunidad = '$COM';
SELECT * FROM TABLE(DBMS_XPLAN.DISPLAY_CURSOR(format => 'ALLSTATS LAST +PREDICATE -NOTE'));
SQL
  $T6 estad CLIENTE
  titulo "INC-611 · verificar"; $INC INC-611 verificar
  for i in INC-608 INC-610 INC-611; do v=$(ultimo "$EVI" "${i}_verificar"); grep -aq '^FALLO' "$v" && PENDIENTES="$PENDIENTES $i"; echo "$i -> $(grep -ac '^OK' "$v") OK, $(grep -ac '^FALLO' "$v") FALLO ($v)"; done
  fin_parte "docs/bitacora/lab7/evidencia/" "perf(t6): Part G - my three incidents with evidence and postmortems"
  ;;
H)
  for f in lab7-respuestas.md lab7-ia.md; do [ -f "$DL/$f" ] || { echo "Falta $DL/$f (te lo prepara Claude con tus números)"; exit 2; }; done
  cp "$DL/lab7-respuestas.md" docs/bitacora/lab7-respuestas.md
  cp "$DL/lab7-ia.md" docs/bitacora/lab7-ia.md
  sub() { local f; f=$(ultimo "$2" "$3"); sed -i "s#{{$1}}#${f:-NO_ENCONTRADO}#g" docs/bitacora/lab7-ia.md; }
  sub EV_C01 "$EVC" C01_validar; sub EV_C17 "$EVC" C17_validar
  sub EV_608 "$EVI" INC-608_arreglo; sub EV_610 "$EVI" INC-610_arreglo; sub EV_611 "$EVI" INC-611_arreglo
  grep -n 'NO_ENCONTRADO\|{{' docs/bitacora/lab7-ia.md && echo "!! revisa esas rutas en lab7-ia.md"
  titulo "H.1 · Verificación final"
  bash scripts/lab7/09-verificacion-final.sh | tee docs/bitacora/lab7/evidencia/09-verificacion-final.txt
  exportar
  printf '\n\033[1;33m==> Si dice TODO OK, haz TÚ (a mano):\033[0m\n'
  cat <<CMD
   git add docs/bitacora/lab7-respuestas.md docs/bitacora/lab7-ia.md docs/bitacora/lab7/
   git commit -m "docs(perf): Lab 7 answers and final verification" -m "Closes #$(git branch --show-current | sed -n 's#^perf/\([0-9]*\)-.*#\1#p')"
   git push -u origin $(git branch --show-current)
   (GitHub: Compare & pull request hacia main, reviewer, merge commit)
   git switch main && git pull && git tag lab7-final && git push --tags
CMD
  ;;
exportar) exportar ;;
*) echo "Parte desconocida: $PARTE"; exit 2 ;;
esac
