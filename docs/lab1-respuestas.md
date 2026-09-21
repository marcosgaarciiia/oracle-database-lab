# Respuestas del Laboratorio 1 - Git Fundamentals
**Autor:** Marcos García Arroyo

**1. ¿Cuál es la diferencia entre Working Directory, Staging Area y Local Repository? Da un ejemplo de un archivo pasando por las tres.**
El Working Directory es la carpeta visible donde editamos el código; la Staging Area es la zona intermedia donde preparamos los cambios confirmados (`git add`); y el Local Repository es la base de datos interna (`.git`) que guarda el historial permanente de versiones (`git commit`). Por ejemplo, al programar un servidor de sockets en Java, primero edito `Servidor.java` en el Working Directory, luego ejecuto `git add Servidor.java` para pasarlo a la Staging Area y, por último, hago `git commit -m "feat: implementar hilos para múltiples clientes"` para guardarlo permanentemente en el Local Repository.

**2. Si modificas un archivo pero no haces git add, ¿aparece ese cambio en tu próximo commit? Explica por qué.**
No, el cambio no aparecerá en el commit[cite: 1]. Esto ocurre porque `git commit` únicamente empaqueta y confirma los archivos que han sido previamente preparados y movidos a la Staging Area mediante `git add`[cite: 1]. Cualquier modificación que se quede en el Working Directory es ignorada en ese guardado[cite: 1].

**3. ¿Por qué git status no mostraba las carpetas vacías que creaste en la Parte C? ¿Qué truco usamos para solucionarlo?**
Git está diseñado para versionar y rastrear archivos, no directorios, por lo que una carpeta sin contenido es invisible para el sistema de control de versiones[cite: 1]. El truco profesional que usamos en la Parte C fue crear un archivo oculto vacío llamado `.gitkeep` dentro de cada carpeta, obligando así a Git a registrar la existencia de la ruta del directorio en el repositorio[cite: 1].

**4. Explica con tus palabras qué es HEAD.**
HEAD es un puntero o indicador interno de Git que señala en qué punto exacto del historial y en qué rama estamos posicionados en un momento dado[cite: 1]. Si cambiamos a una rama distinta o volvemos a un commit antiguo para revisar una configuración de redes en Packet Tracer, el puntero HEAD se mueve hacia ese commit específico y el código del Working Directory se reescribe para reflejar ese estado[cite: 1]. 

**5. ¿Qué diferencia hay entre crear una branch con git switch -c y crear una carpeta nueva con mkdir? ¿Cómo lo comprobamos en la Parte G?**
El comando `mkdir` crea una carpeta física real en el disco duro, mientras que `git switch -c` crea una línea de evolución paralela o puntero en el historial sin duplicar archivos en el sistema[cite: 1]. En la Parte G lo comprobamos al crear la rama `feature/customer-search`, ejecutar el comando `ls -la` y observar que el sistema de archivos permanecía intacto sin ninguna carpeta nueva[cite: 1]. Al volver a `main`, comprobamos cómo el archivo exclusivo de esa rama desaparecía del explorador porque Git modifica el entorno de trabajo según la rama activa[cite: 1].

**6. Durante el conflicto de la Parte H, ¿qué representaba el contenido entre <<<<<<< HEAD y =======? ¿Y entre ======= y >>>>>>>?**
El código delimitado entre `<<<<<<< HEAD` y `=======` representaba la versión que ya teníamos en nuestra rama receptora actual (en este escenario, `main`)[cite: 1]. El texto situado entre `=======` y `>>>>>>> fix/readme-subtitle` mostraba la versión entrante que queríamos fusionar desde la otra rama y que estaba generando el conflicto[cite: 1].

**7. ¿Por qué NO se debe hacer git commit --amend sobre un commit que ya se subió con git push?**
Porque el comando `--amend` no edita el commit original, sino que lo destruye y crea uno totalmente nuevo con un código hash diferente, reescribiendo el historial[cite: 1]. Si ese commit ya era público en GitHub mediante un `push` y otros compañeros del equipo de la universidad lo habían descargado, alterarlo generará historiales divergentes incompatibles que causarán graves problemas de sincronización al intentar fusionar trabajos posteriores[cite: 1].

**8. Si borras por accidente la carpeta .git de tu proyecto, ¿qué se pierde exactamente? ¿Se pierde también el código fuente que está en el disco?**
Si se elimina la carpeta `.git`, se destruye toda la infraestructura interna: el historial completo de commits, las ramas y la configuración del repositorio local[cite: 1]. Sin embargo, el código fuente actual y, por ejemplo, los diagramas de clases PlantUML que estén en el Working Directory (el disco duro) se conservan intactos; simplemente el proyecto dejará de estar bajo el control de versiones de Git[cite: 1].

**9. Explica con tus propias palabras la diferencia entre Git y GitHub, sin usar la palabra "nube".**
Git es el programa o motor de control de versiones que se instala en la máquina local para registrar el historial de un proyecto de forma privada y sin necesidad de conexión a internet[cite: 1]. GitHub es una plataforma web externa o servidor centralizado que aloja repositorios Git de forma remota, añadiendo herramientas colaborativas como la revisión de código y la resolución de *issues*[cite: 1].

**10. ¿Por qué no se debe subir un archivo .env con contraseñas reales a un repositorio, aunque el repositorio sea privado?**
No se debe subir porque, una vez hecho el commit, la contraseña queda grabada para siempre en el historial de todas las copias locales del repositorio[cite: 1]. En el ámbito de la ciberseguridad y en auditorías CTF, extraer credenciales de repositorios privados comprometidos es un vector de ataque recurrente, por lo que subir secretos supone un fallo crítico de seguridad que requiere rotar las claves inmediatamente[cite: 1].

**11. Un compañero te dice: "hice push y ahora GitHub me rechaza el segundo push con 'non-fast-forward'". ¿Qué ha ocurrido probablemente y qué comando ejecutarías primero?**
Lo más probable es que el repositorio remoto albergue nuevos commits que mi compañero no posee en su historial local (por ejemplo, porque un compañero fusionó una rama o se editó un archivo desde la interfaz web)[cite: 1]. El comando que debe ejecutar primero es `git pull` para descargar y fusionar esos cambios externos con su código local antes de poder realizar un nuevo `push`[cite: 1].

**12. ¿Qué tipo de Conventional Commit (feat, fix, docs, test...) usarías para: añadir un índice de rendimiento a una tabla, corregir una restricción mal definida, y actualizar el README?**
*   Añadir un índice de rendimiento a una tabla: `perf:` (mejora de rendimiento)[cite: 1].
*   Corregir una restricción mal definida: `fix:` (corrige un error)[cite: 1].
*   Actualizar el README: `docs:` (cambios exclusivos de documentación)[cite: 1].