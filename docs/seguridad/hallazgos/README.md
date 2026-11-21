# Análisis de hallazgos de seguridad

Los resultados consolidados se documentan aquí. Los reportes originales permanecen en los artefactos de cada ejecución de GitHub Actions (`sast-semgrep`, `secretos-gitleaks`, `sca-cdn`). Los hallazgos no se excluyen únicamente para obtener un pipeline verde.

## APPSEC-001 — Gitleaks: clave pública de reCAPTCHA

- **Regla:** `generic-api-key`; archivo `js/login.js`, línea 3; commit señalado `32732831b5a8419c199e3516d570303697a3b640`.
- **Evidencia:** [run 44955130841](https://github.com/UMGProyect/ProyectoMASI_AppSec/actions/runs/44955130841) y [run 44961043661](https://github.com/UMGProyect/ProyectoMASI_AppSec/actions/runs/44961043661), artefacto `secretos-gitleaks`.
- **Resultado:** un hallazgo; Gitleaks escaneó 25 commits en la ejecución más reciente.
- **Evaluación:** probable falso positivo: `RECAPTCHA_SITE_KEY` está diseñada para uso público en navegador, a diferencia de la clave privada de verificación.
- **Pendiente:** verificar las restricciones de dominio y que no exista una clave privada en el repositorio; considerar excepción únicamente específica y documentada.
- **Estado:** en evaluación.

## APPSEC-002 — SCA/OSV: dependencias por CDN

- **Evidencia:** [run 44961043661](https://github.com/UMGProyect/ProyectoMASI_AppSec/actions/runs/44961043661), artefacto `sca-cdn`.
- **Resultados:** jsPDF 2.5.1 (12 registros), SheetJS/xlsx 0.18.5 (2), SheetJS/xlsx 0.20.1 (2), Supabase JS 2.45.4 (0), jsPDF-AutoTable 3.8.2 (0).
- **Nota:** los 18 registros no representan necesariamente 18 vulnerabilidades independientes. Los resultados deben correlacionarse con el contexto de uso en navegador y el esquema de versiones de SheetJS.
- **Otras observaciones:** ocho referencias externas sin SRI; evaluar cuáles admiten integridad estática y cuáles son dinámicas.
- **Tratamiento:** clasificar identificadores GHSA/CVE, verificar las rutas ejecutadas y plantear actualizaciones sin romper reportes PDF/XLSX.
- **Estado:** pendiente de clasificación por impacto y remediación.

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
