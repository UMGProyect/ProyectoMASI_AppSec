# Seguridad de aplicaciones — registro académico

Este directorio conserva la trazabilidad de incidentes de integración y de hallazgos de seguridad del proyecto. No forma parte del frontend publicado en `dist/` por `build.js`.

## Directorios

- [`integracion/`](integracion/README.md): errores de ejecución/configuración de herramientas, causa raíz, corrección, pruebas y commits.
- [`hallazgos/`](hallazgos/README.md): resultados de Semgrep, Gitleaks, OSV/SCA y ZAP, evaluación, prioridad, tratamiento y evidencias.

## Normas

1. Separar fallos de integración de hallazgos reales de seguridad.
2. Registrar fecha, commit, herramienta, regla/ID, archivo, severidad, impacto, estado, acción tomada y URL de la ejecución.
3. No incluir valores de secretos ni datos privados en documentos o reportes versionados.
4. Conservar los reportes JSON/SARIF originales como artefactos de GitHub Actions; incorporar en Git únicamente análisis consolidados o instantáneas aprobadas.
5. Evitar commits automáticos de resultados en `main`: Cloudflare detecta cambios en esa rama y puede iniciar despliegues nuevos.
6. Trabajar en rama independiente; revisar diff y pruebas del módulo antes de publicar o fusionar.

## Situación de los informes automáticos

La creación de estas carpetas no cambia los workflows ni hace que los artefactos se sincronicen automáticamente con Git. Cualquier mecanismo futuro de sincronización requiere una tarea específica, una política de retención y criterios de sanitización/deduplicación.
