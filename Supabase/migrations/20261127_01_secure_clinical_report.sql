-- CENTRO MEDICO PREMIER - FASE 2 / CONTROL DE AUTORIZACION RPC
-- Objetivo: corregir AM-10 (acceso cruzado a reportes clinicos) y
--           AM-12 (RPC privilegiada sin verificacion AAL2).
-- IMPORTANTE: validar primero en un entorno aislado con datos sinteticos.
-- NO ejecuta pruebas ni prueba eficacia por si mismo.
-- La firma y el tipo de retorno se conservan; CREATE OR REPLACE conserva
-- las concesiones EXECUTE existentes para esta firma.

CREATE OR REPLACE FUNCTION public.generate_clinical_report(
  p_from date,
  p_to date,
  p_doctor_id uuid DEFAULT NULL::uuid
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $function$
DECLARE
  v_user_id uuid := auth.uid();
  v_is_admin boolean;
  v_is_doctor boolean;
  v_effective_doctor_id uuid;
  v_report_id uuid;
  v_data jsonb;
  v_row_count integer;
BEGIN
  -- 1) Sesion e identidad: no confiar en UUID proporcionados por el cliente.
  IF v_user_id IS NULL THEN
    RAISE EXCEPTION 'Autenticacion requerida' USING ERRCODE = '28000';
  END IF;

  -- 2) Autorizacion de rol.
  v_is_admin := public.has_role(ARRAY['admin']);
  v_is_doctor := public.has_role(ARRAY['doctor']);
  IF NOT (v_is_admin OR v_is_doctor) THEN
    RAISE EXCEPTION 'No autorizado' USING ERRCODE = '42501';
  END IF;

  -- 3) AAL2 obligatorio para AMBOS roles, comprobado dentro de la RPC.
  IF COALESCE(auth.jwt() ->> 'aal', 'aal1') <> 'aal2' THEN
    RAISE EXCEPTION 'Se requiere autenticacion multifactor (AAL2)'
      USING ERRCODE = '42501';
  END IF;

  -- 4) Validacion simple de entrada para evitar rangos inesperados.
  IF p_from IS NULL OR p_to IS NULL OR p_from > p_to THEN
    RAISE EXCEPTION 'Rango de fechas invalido' USING ERRCODE = '22023';
  END IF;

  -- 5) Administrador: conserva el filtro opcional original.
  --    Medico: solo sus consultas. Se RECHAZA un UUID ajeno en lugar de
  --    aceptar silenciosamente el filtro indicado por el cliente.
  IF v_is_admin THEN
    v_effective_doctor_id := p_doctor_id;
  ELSE
    IF p_doctor_id IS NOT NULL AND p_doctor_id <> v_user_id THEN
      RAISE EXCEPTION 'No autorizado para consultar reportes de otro medico'
        USING ERRCODE = '42501';
    END IF;
    v_effective_doctor_id := v_user_id;
  END IF;

  -- 6) Reporte: mismo formato de respuesta; filtro efectivo en ambos SELECT.
  SELECT pg_catalog.jsonb_build_object(
    'period', pg_catalog.jsonb_build_object('from', p_from, 'to', p_to),
    'consultations', COALESCE((
      SELECT pg_catalog.jsonb_agg(pg_catalog.jsonb_build_object(
        'id', c.id,
        'date', a.starts_at,
        'patient', (
          SELECT p.first_name || ' ' || p.last_name
          FROM public.patients AS p WHERE p.id = c.patient_id
        ),
        'doctor', (
          SELECT pr.full_name FROM public.profiles AS pr
          WHERE pr.id = c.doctor_id
        ),
        'diagnosis', c.diagnosis,
        'finalized', c.finalized
      ))
      FROM public.consultations AS c
      JOIN public.appointments AS a ON a.id = c.appointment_id
      WHERE a.starts_at::date BETWEEN p_from AND p_to
        AND (v_effective_doctor_id IS NULL OR c.doctor_id = v_effective_doctor_id)
    ), '[]'::jsonb),
    'totals', pg_catalog.jsonb_build_object(
      'total_consultations', (
        SELECT count(*)
        FROM public.consultations AS c
        JOIN public.appointments AS a ON a.id = c.appointment_id
        WHERE a.starts_at::date BETWEEN p_from AND p_to
          AND (v_effective_doctor_id IS NULL OR c.doctor_id = v_effective_doctor_id)
      )
    )
  ) INTO v_data;

  SELECT count(*) INTO v_row_count
  FROM pg_catalog.jsonb_array_elements(v_data -> 'consultations');

  -- 7) Auditoria conservada; se registra el filtro EFECTIVAMENTE aplicado.
  INSERT INTO public.report_exports (
    report_type, filters, row_count, file_format, metadata
  ) VALUES (
    'clinical',
    pg_catalog.jsonb_build_object(
      'from', p_from, 'to', p_to, 'doctor_id', v_effective_doctor_id
    ),
    v_row_count,
    'pdf',
    pg_catalog.jsonb_build_object(
      'generated_by', v_user_id,
      'generated_at', now(),
      'watermark', 'Centro Médico Premier - Historia Clínica Confidencial',
      'checksum', pg_catalog.md5(v_data::text)
    )
  ) RETURNING id INTO v_report_id;

  INSERT INTO public.audit_logs (user_id, action, entity, entity_id, detail)
  VALUES (
    v_user_id, 'generate_report', 'report_exports', v_report_id,
    pg_catalog.jsonb_build_object('type', 'clinical', 'rows', v_row_count)
  );

  RETURN pg_catalog.jsonb_build_object('report_id', v_report_id, 'data', v_data);
END;
$function$;

-- Inspeccion no destructiva tras la migracion (NO sustituye pruebas autenticadas):
SELECT
  pg_get_userbyid(p.proowner) AS owner,
  p.prosecdef AS security_definer,
  p.proconfig AS configuracion,
  has_function_privilege('authenticated', p.oid, 'EXECUTE') AS authenticated_execute,
  has_function_privilege('anon', p.oid, 'EXECUTE') AS anon_execute
FROM pg_proc AS p
WHERE p.oid = 'public.generate_clinical_report(date,date,uuid)'::regprocedure;