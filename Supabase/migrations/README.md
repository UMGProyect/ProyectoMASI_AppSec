# Fase 2 — endurecimiento de autorización de RPC (27-11-2026)

## Estado del despliegue
Las cinco RPC fueron corregidas **manualmente en Supabase** y el equipo comprobó su configuración y el alcance de las pruebas indicadas a continuación. Estos tres archivos versionan ese trabajo para evitar perderlo al reconstruir la base de datos.

**No volver a aplicar estas migraciones al proyecto vigente solo por integrarlas en GitHub.** Antes de cualquier redepliegue, comparar las funciones activas con el contenido versionado y revisar el orden de ejecución. Los SQL históricos `Supabase/schema.sql` y `Supabase/Cambios.sql` contienen definiciones antiguas que podrían sobrescribir estas protecciones si se ejecutan posteriormente.

## Secuencia de migraciones
1. `20261127_01_secure_clinical_report.sql`: `generate_clinical_report` exige rol, AAL2 y filtro efectivo por médico autenticado (AM-10/AM-12).
2. `20261127_02_secure_financial_report.sql`: `generate_financial_report` exige rol y AAL2.
3. `20261127_03_secure_billing_dispensing_receiving.sql`: `billable_items`, `dispense_prescription` y `receive_purchase_order` exigen rol y AAL2.

Todas conservan `SECURITY DEFINER`, restringen `search_path` y califican los objetos de base de datos. No se adjuntan claves, contraseñas, JWT ni datos clínicos.

## Evidencia disponible (declarada por el equipo)
- Reporte clínico: médico autorizado generó su propio reporte; intento de reporte ajeno rechazado; sesión AAL1 real rechazó la RPC por MFA; 4 de 5 registros recientes de la muestra tenían evento correlacionado, 1 registro histórico queda pendiente de clasificación.
- Reporte financiero: intento de médico rechazado por autorización; administrador AAL1 simulado rechazado por MFA; administrador AAL2 simulado superó la validación.
- `billable_items`: administrador AAL1 simulado rechazado; AAL2 simulado obtuvo resultado vacío permitido.
- `dispense_prescription` y `receive_purchase_order`: AAL1 simulado rechazado; AAL2 simulado alcanzó la comprobación de identificador inexistente. **No se efectuaron dispensaciones ni recepciones completas.**
- Las simulaciones de atributos JWT desde SQL Editor y transacciones con `ROLLBACK` **no demuestran** un desafío TOTP real ni operaciones de inventario finalizadas.

## Limitaciones y trabajo pendiente
- El frontend de `js/reports.js` aún efectúa una segunda inserción de reporte **financiero** después de la RPC, aunque la RPC ya ha escrito auditoría. No eliminar esa segunda inserción sin resolver cómo se conserva `metadata.data` para el historial administrativo de reportes. Requiere un cambio de SQL y frontend coordinado, revisión de retención y una validación funcional.
- El historial administrativo existente usa `report_exports.metadata.data` para previsualización/descarga y debe respetar controles de lectura por RLS.
- Registrar las diferencias con los SQL históricos y una futura estrategia de migraciones reproducible; no automatizar la ejecución de los archivos de línea base antiguos.
- Completar cuando sea viable pruebas end-to-end AAL2 y validación funcional de operaciones de inventario con datos sintéticos y control de concurrencia.

## Recomendaciones de despliegue
- Crear PR hacia `main`, exigir SAST, Gitleaks y SCA exitosos mediante Security Gate.
- Para una futura instalación nueva, establecer orden explícito de esquema, cambios e implantación de estas migraciones; validar `pg_get_functiondef`, concesiones de `EXECUTE` y funcionalidad.
