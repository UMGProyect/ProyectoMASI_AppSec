# Análisis de hallazgos de seguridad

Los resultados consolidados se documentan aquí. Los reportes originales permanecen en los artefactos de cada ejecución de GitHub Actions (`sast-semgrep`, `secretos-gitleaks`, `sca-cdn`). Los hallazgos no se excluyen únicamente para obtener un pipeline verde.

## APPSEC-001 — Gitleaks: clave pública de reCAPTCHA

- **Regla:** `generic-api-key`; archivo `js/login.js`, línea 3; commit señalado `32732831b5a8419c199e3516d570303697a3b640`.
- **Evidencia:** [run 44955130841](https://github.com/UMGProyect/ProyectoMASI_AppSec/actions/runs/44955130841) y [run 44961043661](https://github.com/UMGProyect/ProyectoMASI_AppSec/actions/runs/44961043661), artefacto `secretos-gitleaks`.
- **Resultado:** un hallazgo; Gitleaks escaneó 25 commits en la ejecución más reciente.
- **Evaluación:** falso positivo confirmado para la detección documentada: `RECAPTCHA_SITE_KEY` es una clave pública de reCAPTCHA v3 y coincide con la clave registrada en Google reCAPTCHA; no es la clave privada de verificación.
- **Verificación manual (2026-11-21):** dominio autorizado `proyectomasi-appsec.finterianoz.workers.dev`; opción «Verificar el origen de las soluciones de reCAPTCHA» habilitada, según consola revisada por el responsable del proyecto.
- **Tratamiento:** excepción exacta por huella en `.gitleaksignore` (`generic-api-key`, `js/login.js`, commit `32732831b5a8419c199e3516d570303697a3b640`, línea 3). Otras coincidencias, ubicaciones, commits y reglas seguirán siendo analizadas.
- **Riesgo residual:** esta revisión no comprueba por sí sola la lógica de verificación de tokens del lado servidor ni demuestra ausencia de otras claves privadas; mantener ambos controles bajo revisión.
- **Prueba de cierre:** ejecutar Gitleaks en GitHub Actions y confirmar que termina sin detecciones no exceptuadas, conservando el escaneo completo del historial.
- **Estado:** falso positivo validado; excepción pendiente de prueba en pipeline.

## APPSEC-002 — SCA/OSV: dependencias por CDN

- **Evidencia:** [run 44961043661](https://github.com/UMGProyect/ProyectoMASI_AppSec/actions/runs/44961043661), artefacto `sca-cdn`.
- **Resultados:** jsPDF 2.5.1 (12 registros), SheetJS/xlsx 0.18.5 (2), SheetJS/xlsx 0.20.1 (2), Supabase JS 2.45.4 (0), jsPDF-AutoTable 3.8.2 (0).
- **Nota:** los 18 registros no representan necesariamente 18 vulnerabilidades independientes. Los resultados deben correlacionarse con el contexto de uso en navegador y el esquema de versiones de SheetJS.
- **Otras observaciones:** ocho referencias externas sin SRI; evaluar cuáles admiten integridad estática y cuáles son dinámicas.
- **Tratamiento:** clasificar identificadores GHSA/CVE, verificar las rutas ejecutadas y plantear actualizaciones sin romper reportes PDF/XLSX.
- **Actualización propuesta (2026-11-21):** jsPDF 2.5.1 → 4.2.1 y jsPDF-AutoTable 3.8.2 → 5.0.9, tanto en `index.html` como en el fallback de `js/reports.js`. La actualización del complemento acompaña el cambio de versión mayor de jsPDF; la lógica de los reportes no se modificó.
- **Pruebas de aceptación:** validar descarga de PDF financiero, clínico, inventario y pacientes; tablas, paginación y ausencia de errores de consola. Contrastar nuevamente el artefacto SCA/OSV. No afirmar que todo SCA queda resuelto, ya que SheetJS continúa pendiente.
- **Validación funcional (2026-11-21):** responsable confirmó descargas correctas de los cuatro reportes PDF (financiero, clínico, inventario y pacientes), tablas, paginación y ausencia de errores de consola.
- **Actualización SheetJS:** 0.18.5 / 0.20.1 → 0.20.3 desde el CDN oficial en `index.html` y `js/reports.js`; el responsable confirmó los cuatro reportes XLSX, hojas y datos esperados, y ausencia de errores de consola.
- **Resultados del SCA en [run 44964656315](https://github.com/UMGProyect/ProyectoMASI_AppSec/actions/runs/44964656315):** jsPDF 4.2.1 y AutoTable 5.0.9 sin avisos; SheetJS 0.20.3 con dos avisos GHSA heredados de los rangos de npm.
- **Evaluación de SheetJS 0.20.3:** los avisos `GHSA-4r6h-8v6p-xvw6` (corregido en 0.19.3) y `GHSA-5pgg-2g8v-p4x9` (corregido en 0.20.2) no aplican a la distribución oficial 0.20.3. Los resultados originales de OSV deben permanecer en el reporte y distinguirse de vulnerabilidades aplicables.
- **Control implementado:** clasificación limitada por ID, versión exacta y CDN oficial en `.github/scripts/sca_cdn.py`; los errores de consulta OSV producen fallo explícito de análisis (código 2). La clasificación requiere corroboración en GitHub Actions.
- **Estado:** actualizaciones PDF/XLSX validadas funcionalmente; clasificación OSV publicada en rama de prueba, pendiente de verificar en CI; ocho referencias sin SRI pendientes de revisión.

## APPSEC-003 — Semgrep (SAST)

- **Evidencia:** [run 44961043661](https://github.com/UMGProyect/ProyectoMASI_AppSec/actions/runs/44961043661), artefacto `sast-semgrep`.
- **Resultado de integración:** el job pasó. Esto no significa necesariamente que no existan hallazgos; consultar el reporte JSON/SARIF.
- **Estado:** pendiente de analizar y clasificar hallazgos individuales.

## APPSEC-004 — ZAP (DAST)

- **Modo:** workflow manual (`workflow_dispatch`) de análisis pasivo; requiere `SITE_URL`.
- **Estado:** sin análisis documentado en esta fase. No afirmar ausencia de vulnerabilidades.

## Plantilla para nuevos hallazgos

| Campo | Valor |
|---|---|
| ID / herramienta / regla | |
| Fecha / commit / run | |
| Activo, archivo, ruta o dependencia | |
| Severidad y fuente | |
| Evidencia (enlace al artefacto) | |
| Evaluación de impacto / explotación | |
| Estado / responsable | |
| Tratamiento / justificación | |
| Prueba de cierre | |
