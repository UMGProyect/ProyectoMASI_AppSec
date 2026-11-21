# Registro académico de hallazgos de seguridad

Proyecto: `UMGProyect/ProyectoMASI_AppSec`  
Línea base analizada: commit `15e0936`  
Fecha de revisión: 2026-11-21  
Entorno: académico; la clasificación de un hallazgo depende de su evidencia, no solamente del tipo de entorno.

## APPSEC-001 — Gitleaks: probable falso positivo de clave pública reCAPTCHA

- **Herramienta:** Gitleaks v8.18.4.
- **Regla:** `generic-api-key`.
- **Archivo:** `js/login.js`, línea 3.
- **Commit señalado:** `32732831b5a8419c199e3516d570303697a3b640`.
- **Evidencia:** artefacto `secretos-gitleaks` de la ejecución [44955130841](https://github.com/UMGProyect/ProyectoMASI_AppSec/actions/runs/44955130841).
- **Descripción:** la constante `RECAPTCHA_SITE_KEY` del frontend coincidió con un patrón genérico para claves API.
- **Evaluación:** probable falso positivo. Una *site key* de reCAPTCHA v3 se distribuye públicamente en el cliente y es diferente de la *secret key*, que debe permanecer en un componente servidor.
- **Riesgo residual:** pendiente verificar que la configuración de reCAPTCHA restrinja los dominios autorizados y que su clave privada no aparezca en el repositorio ni en otros archivos accesibles al cliente.
- **Tratamiento propuesto:** documentar como falso positivo tras verificar el uso y la configuración; no desactivar el escáner. Si el ruido se vuelve recurrente, estudiar una excepción estrictamente acotada al patrón público, sin excluir el archivo completo.
- **Estado:** evaluado; validación final de configuración pendiente.

## APPSEC-002 — Semgrep: error de invocación del escáner SAST

- **Herramienta:** Semgrep.
- **Archivo:** `.github/workflows/security.yml`.
- **Evidencia:** ejecución [44955130841](https://github.com/UMGProyect/ProyectoMASI_AppSec/actions/runs/44955130841), mensaje `Mutually exclusive options --json/--emacs/--vim/--sarif/...` y salida 2.
- **Descripción:** se mezclaron indicadores de formato primario `--json`, `--sarif` y `--text` en una sola ejecución.
- **Impacto:** el job no completa el análisis SAST ni entrega los tres reportes previstos.
- **Tratamiento propuesto:** utilizar únicamente `--json-output`, `--sarif-output` y `--text-output` para generar los tres formatos en una ejecución, conservando reglas y exclusiones originales.
- **Prueba de aceptación:** en un nuevo run, el paso Semgrep no debe fallar por argumentos incompatibles y el artefacto `sast-semgrep` debe incluir los tres archivos. Documentar por separado cualquier hallazgo de reglas de seguridad.
- **Estado:** parche preparado, pendiente de revisión y ejecución en GitHub Actions.

## APPSEC-003 — SCA: dependencias con vulnerabilidades

- **Herramienta:** consulta OSV mediante `.github/scripts/sca_cdn.py`.
- **Evidencia:** ejecución [44955130841](https://github.com/UMGProyect/ProyectoMASI_AppSec/actions/runs/44955130841) y artefacto `sca-cdn`.
- **Resumen observado:** jsPDF 2.5.1 (12 hallazgos); SheetJS 0.18.5 (2); SheetJS 0.20.1 (2); Supabase JS 2.45.4 (0); jsPDF-AutoTable 3.8.2 (0). Se reportaron ocho scripts externos sin SRI.
- **Tratamiento:** identificar los identificadores CVE/GHSA y las rutas de uso efectivas; evaluar actualizaciones y documentar la aceptación temporal de riesgos en el entorno académico.
- **Estado:** detectado; clasificación detallada pendiente. No es parte del presente parche.

## Procedimiento y controles de cambio

1. Realizar cada corrección en una rama independiente a partir del commit objetivo.
2. Limitar los cambios a los archivos estrictamente vinculados al hallazgo.
3. Ejecutar pruebas específicas por módulo y conservar las evidencias.
4. Revisar el diff completo antes de publicar cambios.
5. No hacer push sin autorización explícita.
6. Mantener diferenciados fallos del escáner, hallazgos detectados y decisiones de aceptación de riesgo.
