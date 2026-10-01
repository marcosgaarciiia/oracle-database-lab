# Respuestas de comprobación - Laboratorio 3

## 8.1.1. Docker
1. Una imagen es la plantilla inmutable de solo lectura, mientras que el contenedor es la instancia viva en ejecución creada a partir de esa plantilla.
2. En G5 escribimos en el sistema de archivos temporal del contenedor, que se destruye al borrarlo. En G6 usamos un volumen persistente (almacenamiento fuera del contenedor) que sobrevive.
3. `docker ps` muestra solo contenedores en marcha; `docker ps -a` muestra todos. `Exited (0)` significa que el proceso terminó correctamente sin errores.
4. En `-p 8181:8181`, el primero es el puerto de mi equipo anfitrión y el segundo el del contenedor. En `-p 80:8080`, fallaba porque nginx escucha en el 80 del contenedor, no en el 8080.
5. Un contenedor vive mientras su proceso principal siga vivo. Oracle mantiene su motor en ejecución constante, mientras que hello-world solo imprime un texto y termina.
6. El digest (sha256) es la huella digital exacta. Lo registramos porque la etiqueta `latest` cambia con el tiempo, y el digest garantiza saber qué versión exacta instalamos.
7. Se usaría `docker volume rm oralab-26ai-data`. El comando `docker rm` solo borra el contenedor, pero deja intacto el volumen por seguridad.

## 8.1.2. Git, organización y evidencia
8. Porque un entorno profesional se trata como código (Infrastructure as Code): se versiona, es reproducible y los cambios pasan por revisión de pares mediante PR.
9. `bash 00-config.sh` lo ejecuta en una terminal hija y las variables se pierden. `source 00-config.sh` lo ejecuta en la terminal actual, dejando las variables disponibles.
10. La marca UTC asegura orden cronológico y neutralidad horaria; el número asocia la evidencia a su paso; kebab-case evita problemas entre SO; y script.log indica que salió de la terminal.
11. Obliga a usar saltos de línea LF (estilo Linux) en todos los scripts, evitando el error `\r: command not found` al ejecutarlos desde Windows.
12. Para conservar el historial paso a paso y poder auditar exactamente cómo y cuándo se aplicó cada configuración, en lugar de aplastarlo en un solo commit ilegible.

## 8.1.3. Seguridad
13. Capas: 1) Ignorar en .gitignore, 2) Crear plantilla versionada (.env.example), 3) Crear .env local con datos reales, 4) Cargar con source. Si nos saltamos la primera, exponemos la clave en el repositorio.
14. Porque todo lo escrito en la terminal se guarda en texto plano en el historial de comandos (`~/.bash_history`), haciéndolo vulnerable.
15. No, porque queda en el historial. El secreto se da por comprometido y hay que rotarlo (cambiar la contraseña en la base de datos y en el .env) inmediatamente.

## 8.1.4. Oracle y herramientas
16. Un SPOOL normal escribiría en el disco interno del contenedor. En su lugar, redireccionamos la entrada (`< archivo.sql`) desde nuestro equipo y capturamos la salida con `tee`.
17. Activa el modo "fail-fast": si hay un error, el script se detiene al instante. Sin esto, seguiría ejecutando comandos sobre una base de datos en estado corrupto.
18. Es un script versionado que avanza el esquema de la base de datos. No se editan para garantizar la trazabilidad; si hay un error, se crea una nueva migración para corregirlo.
19. Porque FREEPDB1 es la Pluggable Database (la base de datos aislada de trabajo). FREE o el SID nos conectarían al contenedor raíz administrativo.
20. SQLcl aporta autocompletado, formato automático y formato moderno. SQL*Plus se domina porque es omnipresente y siempre estará disponible en cualquier servidor Oracle clásico.

## 8.1.5. Entorno de trabajo
21. WSL2 es Linux nativo, mientras que Git Bash es una emulación. En Ubuntu desaparecen los problemas de rutas interpretadas incorrectamente y tenemos acceso a herramientas nativas como `apt` o `free`.
22. Evitamos /mnt/c porque cruzar sistemas de archivos penaliza el rendimiento y rompe los permisos de ejecución de Linux. Recomendamos bash porque es el estándar universal en la industria de servidores.
