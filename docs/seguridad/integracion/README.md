# Incidentes de integración de controles de seguridad

Documentar aquí los errores en la instalación, invocación y funcionamiento de herramientas de GitHub Actions. Un escáner que termina con código 1 debido a vulnerabilidades detectadas no necesariamente tiene un fallo de integración.

## INT-001 — Semgrep: opciones de formato incompatibles

- **Fecha:** 2026-11-21.
- **Línea base:** `15e0936`.
- **Componente:** `.github/workflows/security.yml`, job `sast-semgrep`.
- **Síntoma:** error `Mutually exclusive options --json/--emacs/--vim/--sarif/...`; código de salida 2.
- **Causa raíz:** combinación de `--json`, `--sarif` y `--text` como formatos primarios en una invocación.
- **Corrección:** conservar una invocación y utilizar `--json-output`, `--sarif-output` y `--text-output`.
- **Commit de corrección:** `a4e622420bc0227c382119b8ae38cc90f15a8e80`.
- **Validación:** job Semgrep exitoso en [run 44961043661](https://github.com/UMGProyect/ProyectoMASI_AppSec/actions/runs/44961043661). Artefacto `sast-semgrep` presente; inspección del contenido de cada reporte todavía pendiente de registro.
- **Estado:** corregido en rama `fix/semgrep-reportes-appsec-002`; pendiente de integración a la rama de destino.

## Comportamiento esperado de otros jobs

- **Gitleaks:** una detección puede provocar código de salida 1 sin que falle el escáner.
- **OSV/SCA:** el script usa `--fail-on-vuln` y retorna código 1 si reporta vulnerabilidades.
- **Línea base:** el workflow utiliza `continue-on-error: true` para dejar registro sin bloquear el pipeline global.

Para el detalle de riesgos detectados, consultar [`../hallazgos/README.md`](../hallazgos/README.md).
