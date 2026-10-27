// Seguridad de la cuenta: verificación en dos pasos (MFA) con aplicación autenticadora (TOTP).
// Usa la API nativa de Supabase Auth: mfa.enroll / challengeAndVerify / unenroll.
import { sb, S, $, esc, toast, fail, audit } from './core.js';
import { ico } from './icons.js';

const STAFF = ['admin', 'doctor', 'nurse', 'pharmacist', 'cashier']; // roles con MFA obligatorio
const clean = v => String(v || '').replace(/\s/g, '');
const changed = () => window.dispatchEvent(new Event('cmp:mfa-changed')); // app.js recarga el estado
// El QR llega como "data:image/svg+xml;utf-8,<svg ...>" sin codificar: un '#' (colores) corta la imagen.
// Se codifica el SVG; si ya viene codificado se deja igual. Cualquier otro formato se descarta (queda la clave manual).
const qrSrc = q => {
  const m = /^data:image\/svg\+xml;(?:charset=)?utf-8,([\s\S]*)$/i.exec(q || '');
  if (!m) return '';
  return 'data:image/svg+xml;charset=utf-8,' + (m[1].trimStart().startsWith('<') ? encodeURIComponent(m[1]) : m[1]);
};
const codeMsg = e => /rate|too many/i.test(e?.message || '')
  ? 'Demasiados intentos. Espere unos minutos e intente de nuevo.'
  : 'Código incorrecto o vencido. Intente de nuevo.';

export async function render(el) {
  const { data, error } = await sb.auth.mfa.listFactors();
  if (error) { el.innerHTML = `<p class="err">${esc(error.message)}</p>`; return; }
  const active = data.totp?.[0] || null; // factor TOTP verificado
  const required = STAFF.includes(S.profile.role);

  el.innerHTML = `<div class="bar"><h2>Seguridad de la cuenta</h2></div>
  ${S.mfaRequired ? `<div class="alert warn">${ico('alert', 20)}<div><b>Verificación en dos pasos obligatoria</b>
    <div>Por su rol, debe activar una aplicación autenticadora antes de usar el sistema.</div></div></div>` : ''}
  <div class="card">
    <div class="bar">
      <div><h3>Aplicación autenticadora (TOTP)</h3>
        <p class="muted">Además de la contraseña, se pedirá un código de 6 dígitos que cambia cada 30 segundos.</p></div>
      <span class="badge ${active ? 'on' : 'off'}">${active ? 'Activa' : 'No activada'}</span>
    </div>
    <div id="sec-body"></div>
  </div>`;

  const body = $('#sec-body', el);
  if (active) showActive(el, body, active, required);
  else showInactive(el, body);
}

function showInactive(el, body) {
  body.innerHTML = `<button class="btn" id="mfa-start" type="button">${ico('lock', 18)} Activar autenticador</button>`;
  $('#mfa-start', body).onclick = () => startEnroll(el, body);
}

function showActive(el, body, active, required) {
  body.innerHTML = `<p>${ico('check', 18)} Su cuenta pide un código al iniciar sesión.
    <span class="muted">Activado el ${esc(new Date(active.created_at).toLocaleDateString('es-GT'))}.</span></p>
    ${required
      ? '<p class="muted">Es obligatorio para su rol y no puede desactivarse desde la aplicación.</p>'
      : '<button class="btn ghost" id="mfa-off" type="button">Desactivar</button><div id="mfa-off-box"></div>'}`;
  const off = $('#mfa-off', body);
  if (!off) return;
  off.onclick = () => {
    $('#mfa-off-box', body).innerHTML = `<form id="mfa-off-form" class="row mt">
      <input id="mfa-off-code" class="code-in" inputmode="numeric" autocomplete="one-time-code" maxlength="6" placeholder="000000" required aria-label="Código actual de 6 dígitos">
      <button class="btn danger">Confirmar desactivación</button></form>
      <p class="muted">Ingrese el código actual de su aplicación para confirmar.</p>`;
    $('#mfa-off-code', body).focus();
    $('#mfa-off-form', body).onsubmit = async e => {
      e.preventDefault();
      const code = clean($('#mfa-off-code', body).value);
      if (!/^\d{6}$/.test(code)) return toast('Ingrese los 6 dígitos del código.', true);
      const v = await sb.auth.mfa.challengeAndVerify({ factorId: active.id, code });
      if (v.error) return toast(codeMsg(v.error), true);
      const u = await sb.auth.mfa.unenroll({ factorId: active.id });
      if (u.error) return fail(u.error);
      await audit('mfa_disabled', 'auth_mfa', null, { type: 'totp' });
      toast('Autenticador desactivado'); changed();
    };
  };
}

async function startEnroll(el, body) {
  body.innerHTML = '<p class="muted">Generando código…</p>';
  // Elimina intentos abandonados (factores sin verificar) para no acumularlos
  const { data: all } = await sb.auth.mfa.listFactors();
  for (const f of (all?.all || []).filter(f => f.factor_type === 'totp' && f.status === 'unverified')) {
    await sb.auth.mfa.unenroll({ factorId: f.id });
  }
  const { data, error } = await sb.auth.mfa.enroll({ factorType: 'totp', friendlyName: 'Autenticador' });
  if (error) { fail(error); return showInactive(el, body); }

  body.innerHTML = `<ol class="steps">
      <li>Instale una aplicación autenticadora (Google Authenticator, Microsoft Authenticator o Authy).</li>
      <li>Escanee este código QR, o escriba la clave manualmente.</li>
      <li>Ingrese el código de 6 dígitos que muestra la aplicación.</li></ol>
    <div class="qr-row">
      ${qrSrc(data.totp.qr_code) ? `<img class="qr" alt="Código QR para la aplicación autenticadora" width="200" height="200" src="${esc(qrSrc(data.totp.qr_code))}">` : ''}
      <div><small class="muted">Clave manual</small>
        <div class="secret">${esc(data.totp.secret)}</div>
        <button type="button" class="btn ghost sm" id="mfa-copy">Copiar clave</button></div>
    </div>
    <form id="mfa-form" class="row">
      <input id="mfa-code" class="code-in" inputmode="numeric" autocomplete="one-time-code" maxlength="6" placeholder="000000" required aria-label="Código de 6 dígitos">
      <button class="btn">Verificar y activar</button>
      <button type="button" class="btn ghost" id="mfa-cancel">Cancelar</button>
    </form>`;
  $('#mfa-code', body).focus();

  $('#mfa-copy', body).onclick = () => {
    (navigator.clipboard?.writeText(data.totp.secret) || Promise.reject()).then(() => toast('Clave copiada'), () => toast('No se pudo copiar. Selecciónela manualmente.', true));
  };
  $('#mfa-cancel', body).onclick = async () => {
    await sb.auth.mfa.unenroll({ factorId: data.id });
    render(el);
  };
  $('#mfa-form', body).onsubmit = async e => {
    e.preventDefault();
    const code = clean($('#mfa-code', body).value);
    if (!/^\d{6}$/.test(code)) return toast('Ingrese los 6 dígitos del código.', true);
    const { error: ve } = await sb.auth.mfa.challengeAndVerify({ factorId: data.id, code });
    if (ve) return toast(codeMsg(ve), true);
    await audit('mfa_enabled', 'auth_mfa', null, { type: 'totp' });
    toast('Autenticador activado'); changed();
  };
}
