# Observación 2.5 — Riesgo residual estimado
Fuente: informe base sección 5.6 y tablas 37–39, observación 2.5, evidencia posterior. Se conserva DREAD histórico (tabla 13), separado de P×I. Escala P/I 1–5; bajo 1–4, medio 5–9, alto 10–16, crítico 17–25. Juicio experto propuesto, no frecuencias medidas ni aceptación formal. Impacto actual se conserva; AM-15/16 mantienen estimaciones previas, AM-03/10/12 se reducen conservadoramente; AM-08/09 se reevaluaron tras la migración 05, AM-14 conserva puntuación.

| ID | Escenario | Inicial P/I/R | Actual P/I/R | Objetivo P/I/R | Estado y criterio de cierre |
|---|---|---|---|---|---|
| AM-01 | Apropiación de identidades | 3/5/15 | 3/5/15 | 2/5/10 | Pendiente: alta y vinculación sintéticas, confirmación correo. |
| AM-02 | Uso concurrente de sesiones | 4/4/16 | 4/4/16 | 2/4/8 | Pendiente: dos sesiones, revocación y expiración. |
| AM-03 | Manipulación del frontend HTTP | 4/5/20 | 3/5/15 | 1/5/5 | Parcial: PR #16, HTTP 308, HSTS/CSP, sesión TLS 1.3, SSL enforcement. Falta rechazo no-TLS y restricciones de red. |
| AM-04 | Alteración de importes | 3/4/12 | 3/4/12 | 1/4/4 | Pendiente: manipulación importes; PR #14 no acredita este control. |
| AM-05 | Asociación indebida de documentos | 4/4/16 | 4/4/16 | 2/4/8 | Pendiente: pertenencia y acceso cruzado. |
| AM-06 | Eventos de auditoría engañosos | 4/4/16 | 4/4/16 | 2/4/8 | Parcial: PR #14 correlación de un evento, no inmutabilidad; probar origen y permisos. |
| AM-07 | Reconstrucción insuficiente de incidentes | 4/4/16 | 4/4/16 | 2/4/8 | Pendiente: correlación, SIEM y retención. |
| AM-08 | Lectura global de perfiles | 5/4/20 | 2/4/8 | 1/4/4 | Verificado en alcance: PR #20/21, bloqueo perfil ajeno, propio permitido y directorio mínimo; ampliar pruebas HTTP y roles. |
| AM-09 | Acceso excesivo a pacientes | 4/5/20 | 2/5/10 | 2/5/10 | Parcial: PR #20/21, acceso médico contextual, bloqueo cruzado y de autoasignación; permisos amplios de enfermería/caja y vigencia de relación pendientes. |
| AM-10 | Acceso cruzado a reportes clínicos | 4/5/20 | 3/5/15 | 1/5/5 | Verificado en alcance PR #12/13: reporte propio permitido, otro médico rechazado. Extender a parámetros y tablas. |
| AM-11 | Metadatos de sesiones ajenas | 4/3/12 | 4/3/12 | 1/3/3 | Pendiente: check_can_login con UUID ajeno sintético. |
| AM-12 | Elusión de MFA en RPC | 4/5/20 | 3/5/15 | 1/5/5 | Parcial PR #13/14: cinco RPC endurecidas, dos pruebas HTTP reales, tres simuladas. Falta HTTP y casos válidos de tres. |
| AM-13 | Abuso de privilegios SQL/RPC | 3/5/15 | 3/5/15 | 2/5/10 | Parcial: search_path y EXECUTE de cinco RPC; revisar grants y bypass RLS restantes. |
| AM-14 | Código externo alterado o XSS | 3/5/15 | 3/5/15 | 2/5/10 | Parcial: PR #16 CSP, #17 SRI cinco rutas; falta prueba negativa, despliegue y cobertura restante. |
| AM-15 | Despliegue sin controles integrados | 4/5/20 | 2/5/10 | 2/5/10 | Verificado en alcance: PR #5 rechazado según línea base, gates PR #13/14/16/17; revisar permisos, workflow y rollback. |
| AM-16 | Preview expuesto/backend compartido | 3/5/15 | 2/5/10 | 1/5/5 | Parcial previo: Preview deshabilitado; URLs históricas y aislamiento pendientes. |
| AM-17 | Agotamiento de cuotas | 3/4/12 | 3/4/12 | 2/4/8 | Pendiente: cuotas y alertas. |
| AM-18 | Abuso automatizado de autenticación | 4/4/16 | 4/4/16 | 2/4/8 | Pendiente: CAPTCHA servidor, rate limits y pruebas específicas. |
| AM-19 | Exposición local de tokens/reportes | 3/5/15 | 3/5/15 | 2/4/8 | Pendiente: revocación, almacenamiento; rotación de credenciales expuestas no confirmada. |
| AM-20 | Concurrencia en dispensación | 3/5/15 | 3/5/15 | 1/5/5 | Pendiente: FEFO concurrente y bloqueos de lotes. |
| AM-21 | Interrupción externa o pérdida de datos | 3/5/15 | 3/5/15 | 2/4/8 | Pendiente: restauración y RPO/RTO. |

| Nivel | Inicial | Actual estimado | Objetivo histórico |
|---|---:|---:|---:|
| Bajo | 0 | 0 | 3 |
| Medio | 0 | 1 | 13 |
| Alto | 15 | 20 | 5 |
| Crítico | 6 | 0 | 0 |

Cinco escenarios pasan de crítico a alto y AM-08 pasa de crítico a medio. La estimación actual contiene veinte altos, un medio y cero críticos; no acredita eliminación de vulnerabilidades. La reducción objetivo 21→5 (76.2%) es proyección, no logro demostrado. Ningún riesgo cuenta con aceptación formal acreditada. [RPC](../OBS-2.2_RLS-RPC/EV-OBS22-RPC-001-Verificacion.md), [Cloud](../OBS-2.3_Hardening-Cloud/EV-OBS23-CLOUD-001-Validacion.md), [matriz central](../00_MATRIZ_TRAZABILIDAD_CORRECCIONES.md). Se incorporaron las pruebas SQL RLS del 27-11-2026 y la regresión de interfaz confirmada por el responsable. Véanse EV-OBS22-RLS-002, 003 y 005.
