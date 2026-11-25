He leído la política de uso de IA de la asignatura.

# Declaración de uso de IA · Lab 6 · E025

## Entrada 1
- **Herramienta:** Claude
- **Prompt (literal, copiado tal cual):**
```text
puedes guiarme en la realización del siguiente laboratorio de la asignatura?
el código de alumno es E025
(además pegué las salidas de la terminal para que me ayudara a interpretarlas)
```
- **Código recibido (el fragmento, o la ruta del archivo donde está):** No aplica.
- **Dónde lo usé (parte, script o pregunta):** Durante la realización de todo el laboratorio.
- **Propósito (para qué lo necesitaba):** Para hacerme de guía sobre el pdf y verificar que mis acciones eran correctas y ayudarme a solucionar errores si es que los tenía.
- **Qué hace (con mis palabras; línea a línea si es SQL corto):** Me guía a través del pdf para la realización, verifica respuestas y me ayuda a solucionar posibles errores.
- **Evidencia de ejecución (archivo de docs/bitacora/lab6/evidencia con mi cabecera):** No aplica

## Entrada 2
- **Herramienta:** Claude
- **Prompt:** Pegué la salida de 04-tres-miradas.sh con el ORA-01017 en la Mirada 3, y después las salidas de cada comprobación
- **Código recibido:** 
```SQL
printf '%s' "$APP_ACADEMIA_PWD" | grep -q '[&"\\@/!$]' && echo "TIENE símbolo problemático" || echo "símbolos OK"
printf '%s' "$APP_ACADEMIA_PWD" | LC_ALL=C grep -q '[^ -~]' && echo "TIENE carácter no ASCII" || echo "ASCII OK"
grep -c '^APP_ACADEMIA_PWD=' config/.env
grep -c $'\r' config/.env
printf '%s' "$APP_ACADEMIA_PWD" | grep -oP '[^\x20-\x7E]'
git show --stat --oneline e30c3ea
```
- **Dónde lo usé:** Parte E.1
- **Propósito:** Averiguar por qué no conectaba
- **Qué hace:** Detectar los carácteres no ASCII que no permitian la conexión
- **Evidencia de ejecución:** Los logs 20261124T181353Z_03-cuenta-app, 181354Z_04-tres-miradas (el fallido), 181758Z_03-cuenta-app y 181759Z_04-tres-miradas (el correcto), en el commit e30c3ea
