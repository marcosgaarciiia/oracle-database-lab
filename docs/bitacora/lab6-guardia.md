## INC-601 · Ficha del alumno 101 bloqueada por el cierre de periodo
- Detección: ticket de Ana García (secretaría): la pantalla se colgaba al guardar la ficha del alumno 101. Ninguna alerta lo detectó.
- Impacto: una persona y una ficha. Sin intervenir, unos 15 min de espera (18:31–18:46 UTC); interviniendo, unos 39 s (19:25:33–19:26:12). Sin pérdida de datos confirmados.
- Diagnóstico: Ana (SID 218) esperaba en `enq: TX - row lock contention`, bloqueada por la SID 213 (APP_ACADEMIA, `cierre-periodo`), que estaba en `PL/SQL lock timer` (Idle) con una fila de ACA_ESTUDIANTES sin confirmar. Reiniciar el ordenador no servía: Ana era la víctima.
- Causa raíz: el cierre de periodo modifica la fila y luego espera sin confirmar, así que retiene el bloqueo todo ese tiempo.
- Intervención: `ALTER SYSTEM KILL SESSION '213,18680' IMMEDIATE;` tras comprobar SID y SERIAL#. KILL y no CANCEL SQL, porque CANCEL deja la transacción abierta.
- Validación: diagnóstico sin esperas ni bloqueos, y la espera de Ana termina en ASH a las 19:26:12, el segundo del KILL.
- Acción preventiva: que el cierre de periodo confirme antes de esperar, y un umbral en `turno.sql` que avise si una sesión lleva más de 30 s bloqueada.

## INC-602 · El servicio academia_app se paró y la aplicación dejó de conectar
- Detección: ticket crítico del equipo de matrículas a las 12:24 UTC: ninguna instancia de la aplicación conectaba y daba ORA-12514. Ninguna alerta lo detectó.
- Impacto: toda la aplicación de matrículas sin poder conectar unos 5 min, de 12:24:20 a 12:29:13 UTC. La base siguió abierta y no hubo pérdida de datos.
- Diagnóstico: la base no estaba caída: FREEPDB1 estaba abierta y su servicio anunciado. El servicio academia_app existía pero salía ARRANCADO = NO y el listener no lo anunciaba, de ahí el ORA-12514. Sin esperas, bloqueos ni cuentas bloqueadas.
- Causa raíz: un reinicio no lo explica, porque el estado guardado en la D.1 ya incluía academia_app; lo confirma el arranque de las 17:18:33, que lo trajo de vuelta solo. Por tanto, el servicio se paró después del arranque de las 12:21:48, con la PDB abierta: fue una parada manual o de algún proceso, no una caída de la base. Lo confirmé revisando el script de simulación después de resolverlo.
- Intervención: a las 12:29:13, en FREEPDB1, DBMS_SERVICE.START_SERVICE('academia_app'), que es lo que resolvió el incidente. Como refuerzo ejecuté ALTER PLUGGABLE DATABASE freepdb1 SAVE STATE, aunque el estado guardado ya incluía el servicio.
- Validación: el listener anuncia academia_app como READY, el diagnóstico lo muestra ARRANCADO = SI y APP_ACADEMIA vuelve a conectar y a leer y modificar datos por ese servicio.
- Acción preventiva: añadir a `turno.sql` la comprobación de servicios existentes no arrancados (la sección 6 del diagnóstico) para detectarlo antes que el usuario, y que parar un servicio de producción requiera un cambio planificado y avisado.

## INC-603 · La cuenta de la aplicación quedó bloqueada por el script de bajas
- Detección: ticket de prioridad alta del equipo de matrículas a las 18:51 UTC: tras el despliegue la aplicación no entraba y daba ORA-28000, sin haber cambiado la contraseña. Ninguna alerta lo detectó.
- Impacto: toda la aplicación de matrículas sin poder conectar unos 11 min, de 18:51:38 a 19:02:57 UTC. La base, los servicios y los datos estaban bien.
- Diagnóstico: servicios arrancados y sin esperas ni bloqueos. La sección 7 mostraba APP_ACADEMIA en LOCKED desde las 18:51, y no en LOCKED(TIMED): era un bloqueo manual, no por contraseñas fallidas, que es lo que cuadra con no haber cambiado la contraseña. La conexión por academia_app daba ORA-28000.
- Causa raíz: la auditoría unificada registra `ALTER USER app_academia ACCOUNT LOCK` a las 18:51:38, ejecutado como SYS, que coincide con el script trimestral de bajas de la nota del turno. El script bloqueó la cuenta de aplicación como si fuera la de una persona que se ha ido, porque no distingue cuentas nominales de cuentas de aplicación y APP_ACADEMIA usa el perfil DEFAULT como cualquier otra.
- Intervención: a las 19:02:57, en FREEPDB1, `ALTER USER app_academia ACCOUNT UNLOCK`, sin tocar la contraseña, porque la cuenta no estaba comprometida.
- Validación: APP_ACADEMIA aparece OPEN, la sección 7 del diagnóstico sale vacía, la auditoría registra el desbloqueo y la aplicación vuelve a conectar por academia_app y a leer y modificar datos.
- Acción preventiva: dar a las cuentas de aplicación un perfil propio y hacer que el script de bajas excluya ese perfil, para que solo actúe sobre cuentas nominales; ejecutar ese script con una cuenta nominal y no como SYS, para que la auditoría diga quién lo lanzó; y añadir a `turno.sql` la sección 7 para detectar cuentas bloqueadas antes que el usuario.
