-- Centro Médico Premier | Fase 2 | Corrección de una sola escritura financiera
-- IMPORTANTE: aplicar esta migración y verificarla en Supabase ANTES de fusionar
-- el cambio de js/reports.js que elimina la segunda inserción. La función conserva
-- validaciones de rol/AAL2, no modifica permisos ni RLS y archiva datos sensibles
-- en metadata.data; revisar retención y acceso administrativo a report_exports.
-- Ejecutar solo después de guardar el respaldo original.
-- SQL de migración, no de pruebas funcionales. Una falla revierte la transacción.
BEGIN;

CREATE OR REPLACE FUNCTION public.generate_financial_report(
    p_from date,
    p_to date,
    p_format text DEFAULT 'csv'
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $function$
DECLARE
    v_report_id uuid;
    v_data jsonb;
    v_row_count integer;
BEGIN
    -- Roles autorizados: administrador o cajero.
    IF NOT public.has_role(ARRAY['admin', 'cashier']::text[]) THEN
        RAISE EXCEPTION 'No autorizado'
            USING ERRCODE = '42501';
    END IF;

    -- Las operaciones financieras sensibles exigen segundo factor.
    IF COALESCE(auth.jwt() ->> 'aal', 'aal1') <> 'aal2' THEN
        RAISE EXCEPTION 'Se requiere autenticacion multifactor (AAL2)'
            USING ERRCODE = '42501';
    END IF;

    -- Conservar los campos y cálculos del reporte original.
    SELECT pg_catalog.jsonb_build_object(
        'period', pg_catalog.jsonb_build_object('from', p_from, 'to', p_to),
        'invoices', COALESCE((
            SELECT pg_catalog.jsonb_agg(pg_catalog.jsonb_build_object(
                'id', i.id,
                'number', i.number,
                'date', i.created_at,
                'patient', (
                    SELECT pa.first_name || ' ' || pa.last_name
                    FROM public.patients AS pa
                    WHERE pa.id = i.patient_id
                ),
                'total', i.total,
                'method', i.method,
                'status', i.status
            ))
            FROM public.invoices AS i
            WHERE i.created_at::date BETWEEN p_from AND p_to
        ), '[]'::jsonb),
        'totals', pg_catalog.jsonb_build_object(
            'total_invoices', (
                SELECT count(*) FROM public.invoices AS i
                WHERE i.created_at::date BETWEEN p_from AND p_to
            ),
            'total_amount', (
                SELECT COALESCE(sum(i.total), 0) FROM public.invoices AS i
                WHERE i.created_at::date BETWEEN p_from AND p_to
                  AND i.status = 'pagada'
            ),
            'cash_total', (
                SELECT COALESCE(sum(i.total), 0) FROM public.invoices AS i
                WHERE i.created_at::date BETWEEN p_from AND p_to
                  AND i.status = 'pagada' AND i.method = 'efectivo'
            ),
            'card_total', (
                SELECT COALESCE(sum(i.total), 0) FROM public.invoices AS i
                WHERE i.created_at::date BETWEEN p_from AND p_to
                  AND i.status = 'pagada' AND i.method = 'tarjeta'
            )
        )
    ) INTO v_data;

    SELECT count(*) INTO v_row_count
    FROM pg_catalog.jsonb_array_elements(v_data -> 'invoices');

    -- La RPC genera el registro del reporte y su auditoría.
    INSERT INTO public.report_exports(
        report_type, filters, row_count, file_format, metadata
    )
    VALUES (
        'financial',
        pg_catalog.jsonb_build_object('from', p_from, 'to', p_to),
        v_row_count,
        p_format,
        pg_catalog.jsonb_build_object(
            'generated_by', auth.uid(),
            'generated_at', now(),
            'watermark', 'Centro Médico Premier - Documento Confidencial',
            'checksum', md5(v_data::text),
            -- Persistir la instantánea ya auditada en la misma fila; el historial
            -- administrativo requiere metadata.data para visualizar y descargar.
            'data', v_data
        )
    ) RETURNING id INTO v_report_id;

    INSERT INTO public.audit_logs(user_id, action, entity, entity_id, detail)
    VALUES (
        auth.uid(),
        'generate_report',
        'report_exports',
        v_report_id,
        pg_catalog.jsonb_build_object('type', 'financial', 'rows', v_row_count)
    );

    RETURN pg_catalog.jsonb_build_object('report_id', v_report_id, 'data', v_data);
END;
$function$;

-- Comprobar que los privilegios existentes no cambian al sustituir la función.
DO $verify$
BEGIN
    IF NOT pg_catalog.has_function_privilege(
        'authenticated', 'public.generate_financial_report(date,date,text)', 'EXECUTE'
    ) THEN
        RAISE EXCEPTION 'Se perdio el permiso EXECUTE de authenticated';
    END IF;
    IF pg_catalog.has_function_privilege(
        'anon', 'public.generate_financial_report(date,date,text)', 'EXECUTE'
    ) THEN
        RAISE EXCEPTION 'La funcion no debe estar habilitada para anon';
    END IF;
END;
$verify$;

COMMIT;

-- Inspección posterior (no es una prueba funcional):
SELECT
    pg_catalog.pg_get_userbyid(p.proowner) AS propietario,
    p.prosecdef AS security_definer,
    p.proconfig AS configuracion,
    pg_catalog.pg_get_functiondef(p.oid) LIKE '%auth.jwt()%' AS control_aal_presente,
    pg_catalog.pg_get_functiondef(p.oid) LIKE '%public.has_role%' AS control_rol_presente,
    pg_catalog.has_function_privilege('authenticated', p.oid, 'EXECUTE') AS authenticated_execute,
    pg_catalog.has_function_privilege('anon', p.oid, 'EXECUTE') AS anon_execute
FROM pg_catalog.pg_proc AS p
WHERE p.oid = 'public.generate_financial_report(date,date,text)'::regprocedure;