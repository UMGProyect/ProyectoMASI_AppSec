# Índice de evidencias — Centro Médico Premier

Proyecto final de Seguridad de Aplicaciones — UMG. Evidencias clasificadas por observaciones 2.2 y 2.3.

## Criterios
- Las siete imágenes y el TXT del ZIP original se conservan como copias clasificadas; las imágenes con datos sensibles se sustituyen por copias con ocultación irreversible de píxeles.
- Se agregan cuatro capturas del chat, en carpeta separada, y un extracto textual de la salida posterior de cURL. No se incluye el XLSX con datos de pacientes.
- Los resúmenes visuales no son evidencia primaria. El TXT de línea base y el extracto posterior permiten consultar los resultados sin imágenes.
- Los SHA-256 corresponden a los archivos entregados, no a los originales antes de la anonimización.
- Los resultados no prueban cobertura completa de todas las RPC, SRI de todas las dependencias ni bloqueo de conexiones PostgreSQL externas.

## Referencias de GitHub
| PR | SHA de integración | Security Gate |
|---|---|---|
| [#13](https://github.com/UMGProyect/ProyectoMASI_AppSec/pull/13) | `89dc1c0d68c07ecc224973a71cb99573f1be79fd` | Ver PR e historial de Actions |
| [#14](https://github.com/UMGProyect/ProyectoMASI_AppSec/pull/14) | `d458d93f67a561d5e06661003195b35c085b7729` | [46087102572](https://github.com/UMGProyect/ProyectoMASI_AppSec/actions/runs/46087102572) |
| [#16](https://github.com/UMGProyect/ProyectoMASI_AppSec/pull/16) | `562aa2ce891587cb9b86c3c90afb953845200596` | [46098208506](https://github.com/UMGProyect/ProyectoMASI_AppSec/actions/runs/46098208506) |
| [#17](https://github.com/UMGProyect/ProyectoMASI_AppSec/pull/17) | `16f6d806b8a91c26cc04edf132c1b6a92a8d2654` | [46098753472](https://github.com/UMGProyect/ProyectoMASI_AppSec/actions/runs/46098753472) |

## Inventario
| Archivo | Fuente original | Qué acredita / límite | Referencia | Tipo | Redacción |
|---|---|---|---|---|---|
| [EV-F03-CLOUD-RES-002-Comparativa-Antes-Despues.png](OBS-2.3_Hardening-Cloud/Cloudflare/Resumenes/EV-F03-CLOUD-RES-002-Comparativa-Antes-Despues.png) | Controles verificados antes y despues.png | Tabla resumen de nueve controles; no constituye salida original de cURL. | PR #16 | Resumen explicativo | No |
| [EV-F03-CLOUD-RES-001-Controles-PR16.png](OBS-2.3_Hardening-Cloud/Cloudflare/Resumenes/EV-F03-CLOUD-RES-001-Controles-PR16.png) | Controles implementados.png | Resumen del PR #16 en estado abierto en el momento de la captura; el merge se referencia por separado. | PR #16 | Resumen explicativo | No |
| [EV-F03-CLOUD-001-Hardening-Antes.txt](OBS-2.3_Hardening-Cloud/Cloudflare/EV-F03-CLOUD-001-Hardening-Antes.txt) | EV-F03-CLOUD-001-Hardening-Antes.txt | Salida original PowerShell/cURL: HTTP 200 sin redirección, HSTS y CSP ausentes. SSL: 0 sobre HTTP no acredita TLS. | PR #16 (corrección posterior) | Salida de herramienta | No |
| [EV-F02-RPC-FIN-NEG-MFA-01.png](OBS-2.2_RLS-RPC/EV-F02-RPC-FIN-NEG-MFA-01.png) | RPC-FIN-NEG-MFA-01.png | Login HTTP 200 y rechazo de generate_financial_report HTTP 403 / 42501 por MFA. Se mantienen roles, respuesta y cuerpo de RPC. | PR #13 y #14 | Postman / interfaz | Sí |
| [EV-F02-RPC-MFA-SQL-001-Admin-AAL1-AAL2.png](OBS-2.2_RLS-RPC/EV-F02-RPC-MFA-SQL-001-Admin-AAL1-AAL2.png) | Admin con mfa y sin MFA.png | Dos resultados PASS: rechazo sin MFA y ejecución con MFA. La captura no identifica la RPC ni muestra los claims o el script; tratar como resultado SQL, no como autenticación HTTP real. | PR #13 | Resultado SQL | No |
| [EV-F02-RPC-FIN-NEG-ROLE-01.png](OBS-2.2_RLS-RPC/EV-F02-RPC-FIN-NEG-ROLE-01.png) | Médico intenta generar reporte financiero.png | POST generate_financial_report devuelve 403 / 42501 «No autorizado». El rol médico se atribuye al nombre original/contexto; el JWT no se muestra. | PR #13 | Postman | No |
| [EV-F02-RPC-CLI-NEG-MFA-01.png](OBS-2.2_RLS-RPC/EV-F02-RPC-CLI-NEG-MFA-01.png) | Prueba negativa de MFA_AAL1 superada.png | POST generate_clinical_report devuelve 403 / 42501 por MFA. | PR #13 | Postman | Sí |
| [EV-F02-RPC-CLI-NEG-ROLE-01-Otro-Medico.png](OBS-2.2_RLS-RPC/EV-F02-RPC-CLI-NEG-ROLE-01-Otro-Medico.png) | Control de reportes por Doctor..png | Interfaz con sesión de médico y rechazo de reporte de otro médico. Evidencia de comportamiento de UI, no prueba HTTP independiente. | PR #13 | Interfaz | Sí |
| [EV-F02-RPC-FIN-HIST-002-Descarga-XLSX.png](Capturas_adicionales_chat/OBS-2.2_RLS-RPC/EV-F02-RPC-FIN-HIST-002-Descarga-XLSX.png) | image(20261128-020300).png | Historial con reporte de cuatro filas, aviso de descarga y diálogo Guardar. No acredita por sí solo apertura del segundo XLSX. | PR #14 | Captura adicional de conversación | Sí |
| [EV-F02-RPC-FIN-HIST-001-Vista-Previa.png](Capturas_adicionales_chat/OBS-2.2_RLS-RPC/EV-F02-RPC-FIN-HIST-001-Vista-Previa.png) | image(20261128-020311).png | Vista previa de cuatro facturas y total Q250.06; nombres de pacientes ocultos. | PR #14 | Captura adicional de conversación | Sí |
| [EV-F03-SRI-002-Regresion-Inventario.png](Capturas_adicionales_chat/OBS-2.3_Hardening-Cloud/Cloudflare/EV-F03-SRI-002-Regresion-Inventario.png) | image(20261128-023757).png | Vista previa de inventario con 91 productos. El usuario reportó que probó todos los reportes; no prueba por sí sola el bloqueo SRI o el commit desplegado. | PR #17 | Captura adicional de conversación | No |
| [EV-F03-SUPABASE-003-SSL-Activo-Red-Sin-Restricciones.png](Capturas_adicionales_chat/OBS-2.3_Hardening-Cloud/Supabase/EV-F03-SUPABASE-003-SSL-Activo-Red-Sin-Restricciones.png) | image(20261128-024640).png | SSL Enforcement activo; acceso desde todas las IP en el momento de la captura. No demuestra activación posterior de Restrict all access. | Configuración Supabase; sin commit | Captura adicional de conversación | No |
| [EV-F03-CLOUD-002-Hardening-Despues.txt](OBS-2.3_Hardening-Cloud/Cloudflare/EV-F03-CLOUD-002-Hardening-Despues.txt) | Salida PowerShell del chat | Extracto de resultado real compartido: HTTP 308, HTTPS 200, TLS y cabeceras. | PR #16 | Extracto textual | No |

## Seguridad de las evidencias
La contraseña y los fragmentos de JWT visibles en las capturas originales se ocultaron en las copias. Cambiar la contraseña expuesta y revocar las sesiones/credenciales correspondientes; la anonimización no revoca secretos ya expuestos. No publicar el ZIP original.

## Verificación de integridad
`SHA256SUMS.txt` contiene los hashes de los archivos inventariados.
