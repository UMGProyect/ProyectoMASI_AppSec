-- AM-08 / AM-09: limitar lectura de perfiles y acceso medico a pacientes.
-- Ejecutar una vez desde SQL Editor como propietario de las tablas.
-- Coordinar con el frontend del PR: los joins anteriores no muestran nombres ajenos.
-- Conserva las politicas restrictivas MFA y triggers de auditoria.
BEGIN;

-- Relacion asistencial historica: cita, consulta o alta propia de un expediente.
-- El medico no puede crear esa relacion sobre pacientes ajenos mediante una cita.
CREATE OR REPLACE FUNCTION public.doctor_has_patient(p_patient uuid)
RETURNS boolean
LANGUAGE sql STABLE SECURITY DEFINER SET search_path = ''
AS $$
  SELECT COALESCE(auth.jwt()->>'aal','aal1') = 'aal2'
    AND EXISTS (SELECT 1 FROM public.profiles u
                WHERE u.id = auth.uid() AND u.role = 'doctor')
    AND (
      EXISTS (SELECT 1 FROM public.patients p
              WHERE p.id = p_patient AND p.created_by = auth.uid())
      OR EXISTS (SELECT 1 FROM public.appointments a
                 WHERE a.patient_id = p_patient AND a.doctor_id = auth.uid())
      OR EXISTS (SELECT 1 FROM public.consultations c
                 WHERE c.patient_id = p_patient AND c.doctor_id = auth.uid())
    );
$$;

-- Directorio publico para cuentas autenticadas: solo id y nombre de medicos.
-- Personal requiere AAL2; pacientes conservan el flujo de solicitud de cita.
CREATE OR REPLACE FUNCTION public.list_doctors()
RETURNS TABLE(id uuid, full_name text)
LANGUAGE sql STABLE SECURITY DEFINER SET search_path = ''
AS $$
  SELECT p.id, p.full_name FROM public.profiles p
  WHERE p.role = 'doctor'
    AND EXISTS (SELECT 1 FROM public.profiles a WHERE a.id = auth.uid()
      AND (a.role = 'patient' OR COALESCE(auth.jwt()->>'aal','aal1') = 'aal2'))
  ORDER BY p.full_name, p.id;
$$;

-- Nombres para registros visibles, incluidos medicos historicos no activos.
-- Nunca devuelve email, rol, fecha de alta u otros atributos privados.
CREATE OR REPLACE FUNCTION public.profile_display_names(p_ids uuid[])
RETURNS TABLE(id uuid, full_name text)
LANGUAGE sql STABLE SECURITY DEFINER SET search_path = ''
AS $$
  SELECT p.id, p.full_name
  FROM public.profiles p
  JOIN public.profiles actor ON actor.id = auth.uid()
  WHERE p.id = ANY(p_ids)
    AND (actor.role = 'patient' OR COALESCE(auth.jwt()->>'aal','aal1') = 'aal2')
    AND (
      p.id = actor.id OR actor.role = 'admin' OR p.role = 'doctor'
      OR (actor.role = 'patient' AND EXISTS (
        SELECT 1 FROM public.appointments a JOIN public.patients t ON t.id = a.patient_id
        WHERE a.doctor_id = p.id AND t.user_id = actor.id
      ))
      OR (actor.role = 'nurse' AND EXISTS (
        SELECT 1 FROM public.appointments a WHERE a.doctor_id = p.id
      ))
      OR (actor.role = 'pharmacist' AND (
        EXISTS (SELECT 1 FROM public.prescriptions rx WHERE rx.doctor_id = p.id)
        OR EXISTS (SELECT 1 FROM public.inventory_movements m WHERE m.performed_by = p.id)
      ))
    );
$$;

REVOKE ALL ON FUNCTION public.doctor_has_patient(uuid) FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION public.list_doctors() FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION public.profile_display_names(uuid[]) FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.doctor_has_patient(uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION public.list_doctors() TO authenticated;
GRANT EXECUTE ON FUNCTION public.profile_display_names(uuid[]) TO authenticated;

ALTER POLICY profiles_sel ON public.profiles USING (
  id = (SELECT auth.uid())
  OR ((SELECT public.has_role(ARRAY['admin']::text[]))
      AND COALESCE(auth.jwt()->>'aal','aal1') = 'aal2')
);

-- Se conservan los accesos operativos de administracion, enfermeria y caja.
-- Farmacia necesita identificar a pacientes con recetas, no el censo completo.
ALTER POLICY pat_sel ON public.patients USING (
  ((SELECT public.has_role(ARRAY['patient']::text[])) AND user_id = (SELECT auth.uid()))
  OR (SELECT public.has_role(ARRAY['admin','nurse','cashier']::text[]))
  OR public.doctor_has_patient(id)
  OR ((SELECT public.has_role(ARRAY['pharmacist']::text[])) AND EXISTS (
    SELECT 1 FROM public.prescriptions rx WHERE rx.patient_id = patients.id
  ))
);

-- Impedir que un medico fabrique la vinculacion de un expediente existente
-- o cree un expediente a nombre de una cuenta ajena.
ALTER POLICY pat_ins ON public.patients WITH CHECK (
  (SELECT public.has_role(ARRAY['admin','nurse']::text[]))
  OR ((SELECT public.has_role(ARRAY['doctor']::text[]))
      AND created_by = (SELECT auth.uid()) AND user_id IS NULL)
  OR ((SELECT public.has_role(ARRAY['patient']::text[]))
      AND user_id = (SELECT auth.uid()) AND created_by = (SELECT auth.uid()))
);
ALTER POLICY pat_upd ON public.patients
USING ((SELECT public.has_role(ARRAY['admin','nurse']::text[])) OR public.doctor_has_patient(id))
WITH CHECK ((SELECT public.has_role(ARRAY['admin','nurse']::text[])) OR public.doctor_has_patient(id));

-- El alta de una cita a un paciente ajeno corresponde a recepcion autorizada
-- o a una solicitud del paciente para si mismo, no a la autoasignacion medica.
ALTER POLICY apt_ins ON public.appointments WITH CHECK (
  EXISTS (SELECT 1 FROM public.list_doctors() d WHERE d.id = appointments.doctor_id)
  AND (
    (SELECT public.has_role(ARRAY['admin','nurse']::text[]))
    OR (doctor_id = (SELECT auth.uid()) AND public.doctor_has_patient(patient_id))
    OR ((SELECT public.has_role(ARRAY['patient']::text[]))
        AND patient_id = (SELECT public.my_patient_id()) AND status = 'pendiente')
  )
);

-- Las politicas UPDATE no pueden comparar OLD y NEW. Un trigger impide
-- que el medico altere las claves que determinan su propio ambito de acceso.
-- SECURITY INVOKER: no eleva privilegios; los procesos administrativos quedan intactos.
CREATE OR REPLACE FUNCTION public.guard_doctor_relations()
RETURNS trigger LANGUAGE plpgsql SECURITY INVOKER SET search_path = ''
AS $$
BEGIN
  IF current_user <> 'authenticated' OR NOT public.has_role(ARRAY['doctor']::text[]) THEN
    RETURN NEW;
  END IF;

  IF TG_TABLE_NAME = 'patients' THEN
    IF NEW.id IS DISTINCT FROM OLD.id OR NEW.created_by IS DISTINCT FROM OLD.created_by
       OR NEW.user_id IS DISTINCT FROM OLD.user_id THEN
      RAISE EXCEPTION 'No autorizado: identidad del expediente' USING ERRCODE = '42501';
    END IF;
  ELSIF TG_TABLE_NAME = 'appointments' THEN
    IF NEW.id IS DISTINCT FROM OLD.id OR NEW.patient_id IS DISTINCT FROM OLD.patient_id
       OR NEW.doctor_id IS DISTINCT FROM OLD.doctor_id
       OR NEW.created_by IS DISTINCT FROM OLD.created_by THEN
      RAISE EXCEPTION 'No autorizado: asociacion de cita' USING ERRCODE = '42501';
    END IF;
  ELSIF TG_TABLE_NAME = 'consultations' THEN
    IF NEW.id IS DISTINCT FROM OLD.id OR NEW.patient_id IS DISTINCT FROM OLD.patient_id
       OR NEW.doctor_id IS DISTINCT FROM OLD.doctor_id
       OR NEW.appointment_id IS DISTINCT FROM OLD.appointment_id THEN
      RAISE EXCEPTION 'No autorizado: asociacion de consulta' USING ERRCODE = '42501';
    END IF;
  END IF;
  RETURN NEW;
END;
$$;
REVOKE ALL ON FUNCTION public.guard_doctor_relations() FROM PUBLIC, anon, authenticated;

DROP TRIGGER IF EXISTS guard_doctor_patient_relation ON public.patients;
CREATE TRIGGER guard_doctor_patient_relation BEFORE UPDATE ON public.patients
FOR EACH ROW EXECUTE FUNCTION public.guard_doctor_relations();
DROP TRIGGER IF EXISTS guard_doctor_appointment_relation ON public.appointments;
CREATE TRIGGER guard_doctor_appointment_relation BEFORE UPDATE ON public.appointments
FOR EACH ROW EXECUTE FUNCTION public.guard_doctor_relations();
DROP TRIGGER IF EXISTS guard_doctor_consultation_relation ON public.consultations;
CREATE TRIGGER guard_doctor_consultation_relation BEFORE UPDATE ON public.consultations
FOR EACH ROW EXECUTE FUNCTION public.guard_doctor_relations();

COMMIT;
