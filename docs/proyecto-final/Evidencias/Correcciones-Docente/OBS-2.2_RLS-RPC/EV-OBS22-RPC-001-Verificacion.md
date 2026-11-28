# Observación 2.2 — Autorización, MFA y persistencia
Corte 27/11/2026, Guatemala. Fuente: paquete de continuidad y resultados aportados por el responsable durante las pruebas; no son ejecuciones nuevas de este documento.

## Controles y cobertura
PR [#13](https://github.com/UMGProyect/ProyectoMASI_AppSec/pull/13), integración 89dc1c0d68c07ecc224973a71cb99573f1be79fd: migraciones 01–03; cinco RPC SECURITY DEFINER con search_path vacío, roles y AAL2; EXECUTE authenticated=true, anon=false según inspecciones aportadas.
PR [#14](https://github.com/UMGProyect/ProyectoMASI_AppSec/pull/14), integración d458d93f67a561d5e06661003195b35c085b7729: migración 04 y frontend financiero. Definición desplegada recuperada mediante pg_get_functiondef: guarda data dentro de metadata, una inserción explícita en report_exports y una en audit_logs; conserva rol admin/cashier y AAL2. El indicador textual aislado no acredita aplicación; la definición completa y la prueba posterior sí corroboran la lógica.

| RPC | Prueba positiva | Prueba negativa | Estado en alcance |
|---|---|---|---|
| generate_clinical_report | Médico consulta reporte propio en aplicación | Otro médico rechazado en UI; JWT AAL1 real HTTP 403 | Funcional verificada en casos evaluados |
| generate_financial_report | Admin genera XLSX y recupera historial | Médico HTTP 403; admin AAL1 HTTP 403/42501 | Funcional verificada en casos evaluados |
| billable_items | Admin AAL2 simulado, argumento NULL, resultado vacío | Admin AAL1 simulado, rechazado | Parcial: datos válidos, exclusión facturados y HTTP pendientes |
| dispense_prescription | Admin AAL2 simulado alcanza validación de receta inexistente | AAL1 simulado, rechazado | Parcial: dispensación, FEFO, stock, auditoría y repetición pendientes |
| receive_purchase_order | Admin AAL2 simulado alcanza validación de orden inexistente | AAL1 simulado, rechazado | Parcial: recepción, lotes, stock, auditoría y repetición pendientes |

La simulación SQL de request.jwt.claims (sub, role y aal) no equivale a un JWT real con TOTP. Las pruebas de inventario se revirtieron; no se ejecutaron casos válidos completos. Se identificaron 91 productos, 81 lotes vigentes con existencias, 4 órdenes candidatas, 2 recetas candidatas y 3 consultas pendientes de facturación; ello no acredita ejecución. No se verificó aislamiento de pacientes por relación asistencial ni se corrigieron integralmente profiles_sel o pat_sel. La revisión de cinco RPC no sustituye una auditoría general de RLS y ACL.

## Prueba financiera controlada
Archivo: reporte_financial_2026-10-01_a_2026-11-27.xlsx (no publicado por privacidad). ID de reporte: 04bf94e9-245d-43af-ac01-eaadf24ce079. Cuatro filas, período 2026-10-01 a 2026-11-27. En vista previa, total Q250.06. Checksum MD5 consistente; no es garantía contra manipulación deliberada. Un evento generate_report asociado y actor coincidente. Historial recuperado y descarga iniciada; apertura del segundo XLSX no comprobada independientemente.

| Fecha UTC 28/11/2026 | Operación | Reportes | Eventos generate_report financieros |
|---|---|---:|---:|
| 01:56:11.467755 | Línea base | 13 | 7 |
| 01:59:54.824958 | Una generación autorizada | 14 | 8 |
| 02:03:39.681870 | Vista previa y descarga | 14 | 8 |
| 02:15:18.464742 | Rechazo AAL1 en Postman | 14 | 8 |

Generación a 01:58:29.501105 UTC. Prueba negativa RPC-FIN-NEG-MFA-01: login HTTP 200 con contraseña; RPC HTTP 403, SQLSTATE 42501, "Se requiere autenticacion multifactor (AAL2)". No hubo escrituras de generación adicionales observadas. No se evaluó concurrencia, idempotencia o duplicaciones históricas. Los seis reportes históricos de diferencia no se atribuyen automáticamente a duplicación.

## Consultas reproducibles (solo lectura)
```sql
SELECT count(*) FROM public.report_exports WHERE report_type='financial';
SELECT count(*) FROM public.audit_logs WHERE action='generate_report' AND entity='report_exports' AND detail->>'type'='financial';
SELECT pg_get_functiondef('public.generate_financial_report(date,date,text)'::regprocedure);
SELECT r.id, r.generated_at, r.row_count, r.file_format, r.filters,
       jsonb_typeof(r.metadata->'data')='object' AS datos_historial_presentes,
       r.metadata->>'checksum'=md5((r.metadata->'data')::text) AS checksum_valido,
       (SELECT count(*) FROM public.audit_logs a WHERE a.entity_id=r.id AND a.action='generate_report' AND a.entity='report_exports' AND a.detail->>'type'='financial') AS eventos,
       EXISTS (SELECT 1 FROM public.audit_logs a WHERE a.entity_id=r.id AND a.action='generate_report' AND a.entity='report_exports' AND a.detail->>'type'='financial' AND a.user_id::text=r.metadata->>'generated_by') AS actor_coincide
FROM public.report_exports r WHERE r.id='04bf94e9-245d-43af-ac01-eaadf24ce079'::uuid;
```
Los contadores son históricos y pueden cambiar. Referencias: [migraciones](https://github.com/UMGProyect/ProyectoMASI_AppSec/tree/d458d93f67a561d5e06661003195b35c085b7729/Supabase/migrations), [CI #14](https://github.com/UMGProyect/ProyectoMASI_AppSec/actions/runs/46087102572), [índice de capturas](../00_INDICE_EVIDENCIAS.md). No se publican tokens ni datos de pacientes.
