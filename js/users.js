import { sb, $, esc, isRole, toast, fail, tbl, audit, openModal, S } from './core.js';

const STAFF_ROLES = ['admin', 'doctor', 'nurse', 'pharmacist', 'cashier'];

export async function render(el) {
  if (!isRole('admin')) {
    el.innerHTML = '<div class="bar"><h2>Acceso Denegado</h2></div><p class="muted">Solo los administradores pueden gestionar usuarios y auditoría.</p>';
    return;
  }

  // Cargar datos en paralelo para optimizar rendimiento
  const [{ data: users, error: errUsers }, { data: invites, error: errInvites }, { data: logs }] = await Promise.all([
    sb.from('profiles').select('*').order('created_at', { ascending: false }),
    sb.from('staff_invites').select('*').order('created_at', { ascending: false }),
    sb.from('audit_logs').select('user_id, action, entity, entity_id, detail, created_at').order('created_at', { ascending: false }).limit(50)
  ]);

  if (errUsers || errInvites) return fail(errUsers || errInvites);

  el.innerHTML = `
    <div class="bar"><h2>Usuarios y Auditoría</h2></div>
    
    <!-- Sección 1: Invitar Personal -->
    <div class="card">
      <h3>Invitar nuevo personal</h3>
      <p class="muted">El usuario deberá registrarse con este correo. El sistema le asignará automáticamente el rol de personal.</p>
      <form id="invite-form" class="invite-form">
        <div>
          <label>Correo electrónico</label>
          <input type="email" name="email" required placeholder="ejemplo@clinica.com">
        </div>
        <div>
          <label>Nombre completo</label>
          <input type="text" name="full_name" required placeholder="Dr. Juan Pérez">
        </div>
        <div>
          <label>Rol</label>
          <select name="role" required>
            ${STAFF_ROLES.map(r => `<option value="${r}">${r}</option>`).join('')}
          </select>
        </div>
        <button type="submit" class="btn">Invitar</button>
      </form>
    </div>

    <!-- Sección 2: Invitaciones Pendientes -->
    ${invites && invites.length > 0 ? `
    <div class="card">
      <h3>Invitaciones pendientes</h3>
      ${tbl(['Correo', 'Nombre', 'Rol', 'Fecha', 'Acción'], invites.map(inv => [
        esc(inv.email),
        esc(inv.full_name),
        `<span class="badge">${esc(inv.role)}</span>`,
        esc(new Date(inv.created_at).toLocaleDateString('es-GT')),
        `<button class="btn sm danger" data-cancel-invite="${inv.id}">Cancelar</button>`
      ]))}
    </div>` : ''}

    <!-- Sección 3: Usuarios Registrados -->
    <div class="card">
      <h3>Usuarios registrados</h3>
      <p class="muted">Los pacientes se registran por sí mismos. El personal debe ser invitado desde el formulario superior.</p>
      ${tbl(['Nombre', 'Correo', 'Rol', 'Acción'], (users || []).map(u => [
        esc(u.full_name || 'Sin nombre'),
        esc(u.email),
        `<select data-role="${u.id}" ${u.id === S.user.id ? 'disabled' : ''}>
          ${['patient', ...STAFF_ROLES].map(r => `<option value="${r}" ${r === u.role ? 'selected' : ''}>${r}</option>`).join('')}
        </select>`,
        u.id === S.user.id ? '<span class="muted">(Usted)</span>' : `<button type="button" class="btn sm ghost" data-edit-name="${u.id}">Editar nombre</button> <button class="btn sm" data-save-role="${u.id}">Guardar rol</button>`
      ]))}
    </div>

    <!-- Sección 4: Auditoría Reciente -->
    <div class="card">
      <h3>Auditoría reciente</h3>
      ${(logs || []).length ? `<div class="audit-list">${(logs || []).map(l => {
        const userName = users?.find(u => u.id === l.user_id)?.full_name || 'Sistema';
        const json = l.detail ? JSON.stringify(l.detail) : '';
        const detailStr = json ? json.substring(0, 60) + (json.length > 60 ? '...' : '') : '-';
        return `<div class="audit-item">
          <div class="audit-main"><b>${esc(userName)}</b> <span class="badge">${esc(l.action)}</span> <span class="muted">${esc(l.entity)}</span></div>
          <div class="audit-meta muted"><span title="${esc(json || l.entity_id || '')}">${esc(l.entity_id || detailStr)}</span><span>${esc(new Date(l.created_at).toLocaleString('es-GT'))}</span></div>
        </div>`;
      }).join('')}</div>` : '<p class="muted">Sin registros.</p>'}
    </div>
  `;

  // --- Event Listeners ---
  
  // 1. Enviar invitación
  const inviteForm = $('#invite-form', el);
  if (inviteForm) {
    inviteForm.onsubmit = async (e) => {
      e.preventDefault();
      const formData = new FormData(e.target);
      const payload = {
        email: formData.get('email').trim().toLowerCase(),
        full_name: formData.get('full_name').trim(),
        role: formData.get('role'),
        invited_by: S.user.id
      };

      const { error } = await sb.from('staff_invites').insert(payload);
      if (error) {
        fail(error);
      } else {
        toast('Invitación creada. El usuario debe registrarse con este correo.');
        await audit('invite_created', 'staff_invites', null, { email: payload.email, role: payload.role });
        render(el); // Recargar vista
      }
    };
  }

  // 2. Vincular los botones de esta vista, sin acumular listeners al recargarla.
  const buttons = el.querySelectorAll('[data-edit-name], [data-save-role], [data-cancel-invite]');
  buttons.forEach(button => {
    button.onclick = async () => {
      if (!isRole('admin') || !S.user) return;

      if (button.hasAttribute('data-edit-name')) {
        const user = users?.find(u => u.id === button.dataset.editName);
        if (!user || user.id === S.user.id) return;
        const actor = S.user.id;
        const modal = openModal('Editar nombre de usuario', `
          <form id="edit-user-name-form">
            <p class="muted">${esc(user.email)}</p>
            <label for="edit-user-name">Nombre completo</label>
            <input id="edit-user-name" name="full_name" type="text" value="${esc(user.full_name || '')}" required maxlength="150">
            <div class="row end">
              <button type="button" class="btn ghost" data-cancel-name>Cancelar</button>
              <button type="submit" class="btn">Guardar nombre</button>
            </div>
          </form>
        `);
        const form = $('#edit-user-name-form', modal.el);
        const input = $('#edit-user-name', modal.el);
        const submit = $('button[type="submit"]', form);
        $('[data-cancel-name]', form).onclick = () => modal.close();
        input.focus();
        form.onsubmit = async (e) => {
          e.preventDefault();
          if (submit.disabled) return;
          if (!isRole('admin') || S.user?.id !== actor) {
            modal.close();
            return toast('La sesión administrativa ya no está disponible.', true);
          }
          const full_name = input.value.trim();
          if (!full_name || full_name.length > 150) {
            return toast('Ingrese un nombre de 1 a 150 caracteres.', true);
          }
          if (full_name === user.full_name) return modal.close();
          submit.disabled = true;
          try {
            // RLS de profiles conserva la autorización de administrador y MFA.
            const { data, error } = await sb.from('profiles')
              .update({ full_name }).eq('id', user.id).neq('id', actor)
              .select('id, full_name').single();
            if (error || !data) return fail(error || 'No se actualizó el perfil.');
            // Registro complementario, siguiendo la auditoría de cambios de rol.
            // Un fallo de auditoría no debe aparentar que el nombre no se guardó.
            try {
              const { error: auditError } = await sb.from('audit_logs').insert({
                user_id: actor, action: 'profile_name_updated', entity: 'profiles',
                entity_id: user.id, detail: { field: 'full_name' }
              });
              if (auditError) toast('Nombre actualizado; no se pudo registrar la auditoría.', true);
              else toast('Nombre actualizado');
            } catch {
              toast('Nombre actualizado; no se pudo registrar la auditoría.', true);
            }
            modal.close();
            if (el.contains(button) && isRole('admin') && S.user?.id === actor) render(el);
          } catch (error) {
            fail(error);
          } finally {
            submit.disabled = false;
          }
        };
        return;
      }

      // Guardar cambio de rol manual (corrección)
      const saveBtn = button.hasAttribute('data-save-role') ? button : null;
      if (saveBtn) {
        const id = saveBtn.dataset.saveRole;
        const role = $(`select[data-role="${id}"]`, el).value;
        const { error } = await sb.from('profiles').update({ role }).eq('id', id);
        if (error) fail(error);
        else {
          toast('Rol actualizado');
          await audit('role_updated', 'profiles', id, { new_role: role });
        }
        return;
      }

      // Cancelar invitación pendiente
      const cancelBtn = button.hasAttribute('data-cancel-invite') ? button : null;
      if (cancelBtn) {
        const id = cancelBtn.dataset.cancelInvite;
        const { error } = await sb.from('staff_invites').delete().eq('id', id);
        if (error) fail(error);
        else {
          toast('Invitación cancelada');
          await audit('invite_cancelled', 'staff_invites', id);
          render(el);
        }
      }
    };
  });
}
