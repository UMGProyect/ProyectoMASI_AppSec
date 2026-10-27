-- ====================================================================
-- MFA (TOTP): exigir segundo factor (aal2) al personal en el servidor
-- --------------------------------------------------------------------
-- Idempotente. Para deshacer: ejecutar Supabase/mfa_rollback.sql
--
-- Qué hace:
--  1. Crea public.mfa_ok(): verdadero si la sesión es aal2 (contraseña + código)
--     o si el usuario NO es de personal (p. ej. paciente).
--  2. Añade una política RESTRICTIVA a las tablas sensibles. Una política
--     restrictiva se combina con AND con las políticas existentes, así que no
--     se toca ninguna política anterior: solo se agrega la exigencia de aal2.
--
-- Qué NO bloquea (a propósito):
--  - Leer el propio perfil (profiles SELECT) y escribir en audit_logs, para que
--    el personal sin autenticador pueda iniciar sesión y activarlo desde la app.
--  - La activación en sí misma: va por la API de Supabase Auth, no por tablas.
--
-- Efecto para el personal que aún NO activó su autenticador: la app lo lleva a
-- "Seguridad de la cuenta", y mientras no lo active las tablas responden vacías.
--
-- Limitación conocida: las funciones SECURITY DEFINER (dispensar, facturar,
-- reportes, recibir órdenes) no pasan por RLS; si se quiere exigir aal2 también
-- ahí, hay que agregar `if not public.mfa_ok() then raise exception ...` en cada una.
-- ====================================================================

-- 1) Función de decisión -------------------------------------------------
create or replace function public.mfa_ok() returns boolean
language sql stable security definer set search_path = public as
$$
  select coalesce(auth.jwt() ->> 'aal', 'aal1') = 'aal2'
      or not exists (
        select 1 from public.profiles p
        where p.id = auth.uid()
          and p.role in ('admin','doctor','nurse','pharmacist','cashier')
      );
$$;
revoke all on function public.mfa_ok() from public, anon;
grant execute on function public.mfa_ok() to authenticated;

-- 2) Política restrictiva en las tablas sensibles (todas las operaciones) -----
do $$
declare t text;
begin
  foreach t in array array[
    'patients','appointments','consultations','prescriptions','prescription_items',
    'products','product_batches','inventory_movements','suppliers','purchase_orders',
    'invoices','cash_closures','cash_closures_detail','documents','report_exports',
    'staff_invites'
  ] loop
    if to_regclass('public.' || t) is not null then
      execute format('drop policy if exists mfa_aal2 on public.%I', t);
      execute format(
        'create policy mfa_aal2 on public.%I as restrictive for all to authenticated
           using ((select public.mfa_ok())) with check ((select public.mfa_ok()))', t);
    end if;
  end loop;
end $$;

-- 3) Casos especiales ------------------------------------------------------
-- profiles: lectura libre (la app necesita el perfil para decidir el flujo de MFA);
-- cambios (p. ej. de rol) solo con aal2.
drop policy if exists mfa_aal2_upd on public.profiles;
create policy mfa_aal2_upd on public.profiles as restrictive for update to authenticated
  using ((select public.mfa_ok())) with check ((select public.mfa_ok()));
drop policy if exists mfa_aal2_del on public.profiles;
create policy mfa_aal2_del on public.profiles as restrictive for delete to authenticated
  using ((select public.mfa_ok()));

-- audit_logs: insertar sigue permitido en aal1 (login, activación); consultar exige aal2.
drop policy if exists mfa_aal2_sel on public.audit_logs;
create policy mfa_aal2_sel on public.audit_logs as restrictive for select to authenticated
  using ((select public.mfa_ok()));
