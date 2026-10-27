-- ====================================================================
-- REVERSA de Supabase/mfa.sql: quita las políticas restrictivas de MFA
-- y la función auxiliar. No toca políticas ni datos anteriores.
-- ====================================================================
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
    end if;
  end loop;
end $$;

drop policy if exists mfa_aal2_upd on public.profiles;
drop policy if exists mfa_aal2_del on public.profiles;
drop policy if exists mfa_aal2_sel on public.audit_logs;

drop function if exists public.mfa_ok();
