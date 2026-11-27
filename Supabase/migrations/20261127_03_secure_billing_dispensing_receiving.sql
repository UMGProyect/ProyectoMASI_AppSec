-- Centro Medico Premier | Fase 2 | Correccion conjunta de tres RPC
-- FUNCIONES: billable_items, dispense_prescription, receive_purchase_order
-- ALCANCE: MFA AAL2 obligatorio, roles existentes, search_path restringido.
-- IMPORTANTE: es una migracion de produccion. Guardar antes el rollback.
-- NO ejecutar partes aisladas: ejecutar el script completo.
-- No modifica politicas RLS, tablas, roles de aplicacion ni la logica FEFO.
-- La transaccion evita despliegues parciales si una definicion falla.
BEGIN;

CREATE OR REPLACE FUNCTION public.billable_items(p_patient uuid)
RETURNS jsonb
LANGUAGE plpgsql
STABLE SECURITY DEFINER
SET search_path = ''
AS $function$
BEGIN
  IF NOT public.has_role(ARRAY['admin','cashier']::text[]) THEN
    RAISE EXCEPTION 'No autorizado' USING ERRCODE = '42501';
  END IF;

  IF COALESCE(auth.jwt() ->> 'aal', 'aal1') <> 'aal2' THEN
    RAISE EXCEPTION 'Se requiere autenticacion multifactor (AAL2)'
      USING ERRCODE = '42501';
  END IF;

  RETURN pg_catalog.jsonb_build_object(
    'consultations', COALESCE((
      SELECT pg_catalog.jsonb_agg(pg_catalog.jsonb_build_object(
        'id', c.id, 'date', a.starts_at, 'doctor', d.full_name
      ))
      FROM public.consultations AS c
      JOIN public.appointments AS a ON a.id = c.appointment_id
      JOIN public.profiles AS d ON d.id = c.doctor_id
      WHERE c.patient_id = p_patient AND c.finalized
        AND NOT EXISTS (
          SELECT 1 FROM public.invoices AS i
          WHERE i.consultation_id = c.id
        )
    ), '[]'::jsonb),
    'prescriptions', COALESCE((
      SELECT pg_catalog.jsonb_agg(pg_catalog.jsonb_build_object(
        'id', r.id,
        'date', r.dispensed_at,
        'items', (
          SELECT pg_catalog.jsonb_agg(pg_catalog.jsonb_build_object(
            'name', pi.name,
            'qty', pi.quantity,
            'price', COALESCE(pr.price, 0)
          ))
          FROM public.prescription_items AS pi
          LEFT JOIN public.products AS pr ON pr.id = pi.product_id
          WHERE pi.prescription_id = r.id
        )
      ))
      FROM public.prescriptions AS r
      WHERE r.patient_id = p_patient
        AND r.status = 'dispensada'
        AND NOT EXISTS (
          SELECT 1 FROM public.invoices AS i
          WHERE r.id = ANY(i.prescription_ids)
        )
    ), '[]'::jsonb)
  );
END;
$function$;

CREATE OR REPLACE FUNCTION public.dispense_prescription(p_id uuid)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $function$
DECLARE
  it record;
  rx public.prescriptions;
  batch record;
  remaining integer;
BEGIN
  IF NOT public.has_role(ARRAY['admin','pharmacist']::text[]) THEN
    RAISE EXCEPTION 'No autorizado' USING ERRCODE = '42501';
  END IF;

  IF COALESCE(auth.jwt() ->> 'aal', 'aal1') <> 'aal2' THEN
    RAISE EXCEPTION 'Se requiere autenticacion multifactor (AAL2)'
      USING ERRCODE = '42501';
  END IF;

  SELECT * INTO rx
  FROM public.prescriptions
  WHERE id = p_id FOR UPDATE;
  IF NOT FOUND THEN
    RAISE EXCEPTION 'Receta no encontrada';
  END IF;
  IF rx.status = 'dispensada' THEN
    RAISE EXCEPTION 'La receta ya fue dispensada';
  END IF;

  FOR it IN
    SELECT * FROM public.prescription_items
    WHERE prescription_id = p_id AND product_id IS NOT NULL
  LOOP
    remaining := it.quantity;

    -- Preservar la logica FEFO actual (sin cambios de concurrencia).
    FOR batch IN
      SELECT * FROM public.product_batches
      WHERE product_id = it.product_id
        AND remaining_quantity > 0
        AND expiration_date >= CURRENT_DATE
      ORDER BY expiration_date ASC, received_at ASC
    LOOP
      IF remaining <= 0 THEN EXIT; END IF;

      IF batch.remaining_quantity >= remaining THEN
        UPDATE public.product_batches
        SET remaining_quantity = remaining_quantity - remaining
        WHERE id = batch.id;

        INSERT INTO public.inventory_movements(
          product_id, batch_id, movement_type, quantity,
          reason, reference_id, reference_type
        ) VALUES (
          it.product_id, batch.id, 'salida', remaining,
          'Dispensación de receta', p_id, 'prescription'
        );
        remaining := 0;
      ELSE
        UPDATE public.product_batches
        SET remaining_quantity = 0
        WHERE id = batch.id;

        INSERT INTO public.inventory_movements(
          product_id, batch_id, movement_type, quantity,
          reason, reference_id, reference_type
        ) VALUES (
          it.product_id, batch.id, 'salida', batch.remaining_quantity,
          'Dispensación de receta', p_id, 'prescription'
        );
        remaining := remaining - batch.remaining_quantity;
      END IF;
    END LOOP;

    IF remaining > 0 THEN
      RAISE EXCEPTION 'Stock insuficiente para % (faltan % unidades)',
        it.name, remaining;
    END IF;

    UPDATE public.products
    SET stock = stock - it.quantity
    WHERE id = it.product_id;
  END LOOP;

  UPDATE public.prescriptions
  SET status = 'dispensada',
      dispensed_by = auth.uid(),
      dispensed_at = NOW()
  WHERE id = p_id;

  INSERT INTO public.audit_logs(user_id, action, entity, entity_id, detail)
  VALUES (
    auth.uid(), 'dispense', 'prescription', p_id,
    pg_catalog.jsonb_build_object(
      'items', (
        SELECT pg_catalog.jsonb_agg(pg_catalog.jsonb_build_object(
          'name', name, 'qty', quantity
        ))
        FROM public.prescription_items
        WHERE prescription_id = p_id
      )
    )
  );
END;
$function$;

CREATE OR REPLACE FUNCTION public.receive_purchase_order(p_order_id uuid)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $function$
DECLARE
  ord record;
  item jsonb;
  batch_id uuid;
BEGIN
  IF NOT public.has_role(ARRAY['admin','pharmacist']::text[]) THEN
    RAISE EXCEPTION 'No autorizado' USING ERRCODE = '42501';
  END IF;

  IF COALESCE(auth.jwt() ->> 'aal', 'aal1') <> 'aal2' THEN
    RAISE EXCEPTION 'Se requiere autenticacion multifactor (AAL2)'
      USING ERRCODE = '42501';
  END IF;

  SELECT * INTO ord
  FROM public.purchase_orders
  WHERE id = p_order_id FOR UPDATE;
  IF NOT FOUND THEN
    RAISE EXCEPTION 'Orden no encontrada';
  END IF;
  IF ord.status = 'recibida' THEN
    RAISE EXCEPTION 'La orden ya fue recibida';
  END IF;

  FOR item IN SELECT * FROM pg_catalog.jsonb_array_elements(ord.items)
  LOOP
    INSERT INTO public.product_batches AS pb (
      product_id, batch_number, expiration_date, quantity,
      remaining_quantity, supplier_id, purchase_price
    ) VALUES (
      (item ->> 'product_id')::uuid,
      item ->> 'batch_number',
      (item ->> 'expiration_date')::date,
      (item ->> 'quantity')::integer,
      (item ->> 'quantity')::integer,
      ord.supplier_id,
      (item ->> 'unit_price')::numeric
    )
    ON CONFLICT (product_id, batch_number)
    DO UPDATE SET
      quantity = pb.quantity + (item ->> 'quantity')::integer,
      remaining_quantity = pb.remaining_quantity + (item ->> 'quantity')::integer
    RETURNING id INTO batch_id;

    UPDATE public.products
    SET stock = stock + (item ->> 'quantity')::integer
    WHERE id = (item ->> 'product_id')::uuid;

    INSERT INTO public.inventory_movements(
      product_id, batch_id, movement_type, quantity,
      reason, reference_id, reference_type
    ) VALUES (
      (item ->> 'product_id')::uuid, batch_id,
      'entrada', (item ->> 'quantity')::integer,
      'Recepción de orden de compra', p_order_id, 'purchase_order'
    );
  END LOOP;

  UPDATE public.purchase_orders
  SET status = 'recibida',
      received_at = NOW(),
      received_by = auth.uid()
  WHERE id = p_order_id;

  INSERT INTO public.audit_logs(user_id, action, entity, entity_id, detail)
  VALUES (
    auth.uid(), 'receive', 'purchase_order', p_order_id,
    pg_catalog.jsonb_build_object('total', ord.total)
  );
END;
$function$;

-- La sustitucion de funciones existentes debe conservar los permisos actuales.
DO $verify$
DECLARE fn regprocedure;
BEGIN
  FOREACH fn IN ARRAY ARRAY[
    'public.billable_items(uuid)'::regprocedure,
    'public.dispense_prescription(uuid)'::regprocedure,
    'public.receive_purchase_order(uuid)'::regprocedure
  ]
  LOOP
    IF NOT pg_catalog.has_function_privilege('authenticated', fn::oid, 'EXECUTE') THEN
      RAISE EXCEPTION 'Permiso authenticated perdido: %', fn;
    END IF;
    IF pg_catalog.has_function_privilege('anon', fn::oid, 'EXECUTE') THEN
      RAISE EXCEPTION 'Permiso anon inesperado: %', fn;
    END IF;
  END LOOP;
END;
$verify$;

COMMIT;

-- Verificacion de presencia de controles (no demuestra eficacia por si sola).
SELECT
  p.proname AS funcion,
  p.proconfig AS configuracion,
  pg_catalog.pg_get_functiondef(p.oid) LIKE '%auth.jwt()%' AS referencia_aal2,
  pg_catalog.pg_get_functiondef(p.oid) LIKE '%public.has_role%' AS referencia_roles,
  pg_catalog.has_function_privilege('authenticated', p.oid, 'EXECUTE') AS authenticated_execute,
  pg_catalog.has_function_privilege('anon', p.oid, 'EXECUTE') AS anon_execute
FROM pg_catalog.pg_proc AS p
JOIN pg_catalog.pg_namespace AS n ON n.oid = p.pronamespace
WHERE n.nspname = 'public'
  AND p.proname IN (
    'billable_items', 'dispense_prescription', 'receive_purchase_order'
  )
ORDER BY p.proname;