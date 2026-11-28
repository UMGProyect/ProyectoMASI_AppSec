# Observación 2.3 — Hardening por perímetro
Corte 27/11/2026 (Guatemala). Fuentes: cURL y SQL aportados por el responsable, capturas indexadas y commits.

| Componente | Antes | Después / evidencia | Límite |
|---|---|---|---|
| Frontend Cloudflare | HTTP 200 sin redirección; HSTS/CSP ausentes | HTTP 308 → HTTPS 200, TLS verificado (ssl_verify_result=0), HSTS max-age=31536000 y CSP en GET/HEAD. | No equivale a WAF de API Supabase; primera solicitud HTTP sigue expuesta antes de redirección/HSTS. |
| Cabeceras | XFO DENY, nosniff, referrer-policy, permissions-policy presentes | Conservadas por Worker | CSP permite estilos inline y comodines Supabase, no unsafe-inline ni unsafe-eval en script-src. |
| Recursos externos | Sin SRI en librerías de reportes | PR #17, 5 rutas con SHA-384 y crossorigin=anonymous; usuario reportó todos los reportes operativos. | Sin prueba negativa SRI, sin cobertura del grafo ESM Supabase ni reCAPTCHA dinámico; commit activo Cloudflare #17 no comprobado independientemente. |
| Auth/API y RPC | Acceso directo HTTPS a Supabase | MFA y controles RPC de observación 2.2 | No todos los escenarios verificados. |
| PostgreSQL | SSL on, enforcement desactivado | Captura muestra enforcement activado; sesión SQL TLS 1.3/AES-256-GCM | No se realizó prueba directa de rechazo no-SSL. |
| Restricción de red | Todas las IP permitidas | SQL Editor continúa operativo | Activación de Restrict all access no confirmada expresamente; no se probó rechazo externo. |
| Repositorio | Ruleset y CI existentes | PR #16 y #17 fusionados; Security Gate success | Pruebas unitarias Worker añadidas, ejecución no acreditada por gate. |

## Resultados SQL aportados (UTC)
- 2026-11-28 02:44:49.899109: PostgreSQL 17.11; ssl=on; ssl_min_protocol_version=TLSv1.2; enforcement desactivado según responsable.
- 2026-11-28 02:45:59.068570: PostgreSQL 17.11; ssl=on; TLS mínimo 1.2; sesion_cifrada=true; protocolo TLSv1.3; TLS_AES_256_GCM_SHA384; 256 bits.
- 2026-11-28 02:52:27.565173: base postgres; ssl=on; disponibilidad_administrativa=OK. No acredita una restricción de red.

```sql
SELECT now(), current_setting('server_version'), current_setting('ssl'),
       current_setting('ssl_min_protocol_version'), s.ssl, s.version, s.cipher, s.bits
FROM pg_catalog.pg_stat_ssl s WHERE s.pid=pg_backend_pid();
```
## Referencias
[PR #16](https://github.com/UMGProyect/ProyectoMASI_AppSec/pull/16), [Worker](https://github.com/UMGProyect/ProyectoMASI_AppSec/blob/562aa2ce891587cb9b86c3c90afb953845200596/worker.mjs), [CI](https://github.com/UMGProyect/ProyectoMASI_AppSec/actions/runs/46098208506); [PR #17](https://github.com/UMGProyect/ProyectoMASI_AppSec/pull/17), [HTML](https://github.com/UMGProyect/ProyectoMASI_AppSec/blob/16f6d806b8a91c26cc04edf132c1b6a92a8d2654/index.html), [cargadores](https://github.com/UMGProyect/ProyectoMASI_AppSec/blob/16f6d806b8a91c26cc04edf132c1b6a92a8d2654/js/reports.js), [CI](https://github.com/UMGProyect/ProyectoMASI_AppSec/actions/runs/46098753472). [Antes](Cloudflare/EV-F03-CLOUD-001-Hardening-Antes.txt), [después](Cloudflare/EV-F03-CLOUD-002-Hardening-Despues.txt), [capturas](../00_INDICE_EVIDENCIAS.md). Configuración administrada Supabase sin commit SQL.
