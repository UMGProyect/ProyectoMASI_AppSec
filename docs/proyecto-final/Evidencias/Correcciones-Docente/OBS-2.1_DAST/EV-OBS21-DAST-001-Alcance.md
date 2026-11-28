# Observación 2.1 — Alcance de las evaluaciones
Corte: 27/11/2026 (Guatemala). Fuente: observaciones del docente, sección 2.1; informe base, sección 3.1 y Tabla 17.

| Evaluación | Resultado registrado | Alcance y límites |
|---|---|---|
| OWASP ZAP Baseline | 8 URL, 60 PASS, 8 WARN, 0 FAIL | DAST pasivo; no acredita ausencia de vulnerabilidades ni explotación activa. |
| Caja negra activa | No ejecutada | Pendiente una prueba de penetración controlada y autorizada. |
| Caja gris | Perfil propio de cuenta sintética verificado | No acredita aislamiento general de objetos o pacientes. Pruebas posteriores de RPC se documentan en observación 2.2. |
| Caja blanca | 19 tablas con RLS y 66 políticas identificadas en la línea base | Inventario histórico, no prueba de eficacia integral. |

El [reporte histórico ZAP](https://github.com/UMGProyect/ProyectoMASI_AppSec/blob/3da1bcee7c9cf80a4566dfcdcd07b998d131af1a/docs/proyecto-final/Evidencias/Fase-04-Ciberdefensa/Caja-Negra/ZAP-Evidencias/reporte-zap.md) enumera 0 alertas altas, 2 medias, 5 bajas y 4 informativas. Estas son categorías de alertas de ese reporte, no el contador PASS/WARN/FAIL de Baseline. Incluye hallazgos de CSP, SRI y HSTS posteriormente tratados por PR #16 y #17. No se ejecutó un nuevo Baseline para este ajuste documental. No se extrapola el reporte a la versión desplegada actual.

Referencias: [workflow Baseline](https://github.com/UMGProyect/ProyectoMASI_AppSec/blob/3da1bcee7c9cf80a4566dfcdcd07b998d131af1a/.github/workflows/zap-baseline.yml), [evidencias históricas](https://github.com/UMGProyect/ProyectoMASI_AppSec/tree/3da1bcee7c9cf80a4566dfcdcd07b998d131af1a/docs/proyecto-final/Evidencias/Fase-04-Ciberdefensa). Los resultados numéricos de Baseline proceden del informe y las observaciones, no de una nueva ejecución.
