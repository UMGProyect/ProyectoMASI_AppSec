import { createClient } from 'https://cdn.jsdelivr.net/npm/@supabase/supabase-js@2.45.4/+esm';
import { ico } from './icons.js';

export const CFG = window.APP_CONFIG || {};
// Sin configuración no se crea el cliente (createClient lanza error con URL vacía)
export const sb = CFG.SUPABASE_URL ? createClient(CFG.SUPABASE_URL, CFG.SUPABASE_ANON_KEY) : null;
export const S = { user: null, profile: null };

export const $ = (s, r = document) => r.querySelector(s);
export const $$ = (s, r = document) => [...r.querySelectorAll(s)];
export const esc = v => String(v ?? '').replace(/[&<>"']/g, m => ({ '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;' }[m]));
export const isRole = (...r) => r.includes(S.profile?.role);
export const money = v => 'Q' + Number(v || 0).toFixed(2);
export const fmtDT = d => d ? new Date(d).toLocaleString('es-GT', { dateStyle: 'short', timeStyle: 'short' }) : '';
export const fmtD = d => d ? new Date(d.length === 10 ? d + 'T00:00:00' : d).toLocaleDateString('es-GT') : '';
export const today = () => new Date().toLocaleDateString('en-CA');
export const dayBounds = (d = today()) => {
  const s = new Date(d + 'T00:00:00'), e = new Date(s); e.setDate(e.getDate() + 1);
  return [s.toISOString(), e.toISOString()];
};
export const fullName = p => p ? `${p.first_name} ${p.last_name}` : '';
export const STATUSES = ['pendiente', 'programada', 'confirmada', 'en_espera', 'atendida', 'cancelada', 'ausente'];
export const badge = s => `<span class="badge ${esc(s)}">${esc(String(s).replace('_', ' '))}</span>`;
// Tabla estándar. Cada celda lleva data-label (texto del encabezado) para mostrarse como tarjeta en móvil.
const plain = h => String(h ?? '').replace(/<[^>]*>/g, '').trim();
export const tbl = (heads, rows) => rows.length
  ? `<div class="scroll"><table class="rt"><thead><tr>${heads.map(h => `<th>${h}</th>`).join('')}</tr></thead><tbody>${rows.map(r => `<tr>${r.map((c, i) => `<td data-label="${esc(plain(heads[i]))}">${c}</td>`).join('')}</tr>`).join('')}</tbody></table></div>`
  : `<div class="empty">${ico('inbox', 28)}<span>Sin resultados.</span></div>`;

export function toast(m, err) {
  const t = $('#toast'); t.textContent = m; t.className = 'show' + (err ? ' bad' : '');
  clearTimeout(toast.t); toast.t = setTimeout(() => (t.className = ''), 4500);
}
export const fail = e => toast(e?.message || String(e), true);

// Registro de accesos (lecturas). Las escrituras se auditan con triggers en la BD.
export async function audit(action, entity, entity_id = null, detail = {}) {
  await sb.from('audit_logs').insert({ user_id: S.user.id, action, entity, entity_id, detail });
}

// ---- Modales: pila de ventanas abiertas, Esc para cerrar, foco atrapado y restaurado ----
const MODALS = [];
const FOCUSABLE = 'a[href],button:not([disabled]),input:not([disabled]):not([type=hidden]),select:not([disabled]),textarea:not([disabled]),[tabindex]:not([tabindex="-1"])';
let modalSeq = 0;

function mountOverlay(o, onEsc) {
  const prev = document.activeElement;
  document.body.appendChild(o);
  document.body.classList.add('modal-open');
  const entry = { o, modal: o.querySelector('.modal'), onEsc };
  MODALS.push(entry);
  entry.modal.focus();
  let done = false;
  return () => { // desmontar (idempotente)
    if (done) return; done = true;
    const i = MODALS.indexOf(entry); if (i >= 0) MODALS.splice(i, 1);
    o.remove();
    if (!MODALS.length) document.body.classList.remove('modal-open');
    if (prev && document.contains(prev)) prev.focus?.();
  };
}

document.addEventListener('keydown', e => {
  const top = MODALS[MODALS.length - 1];
  if (!top) return;
  if (e.key === 'Escape') { e.preventDefault(); top.onEsc(); return; }
  if (e.key !== 'Tab') return;
  const f = [...top.o.querySelectorAll(FOCUSABLE)].filter(x => x.offsetParent !== null);
  if (!f.length) { e.preventDefault(); return; }
  const first = f[0], last = f[f.length - 1], act = document.activeElement;
  if (e.shiftKey && (act === first || act === top.modal || !top.o.contains(act))) { e.preventDefault(); last.focus(); }
  else if (!e.shiftKey && (act === last || !top.o.contains(act))) { e.preventDefault(); first.focus(); }
});

export function openModal(title, html) {
  const o = document.createElement('div');
  o.className = 'overlay';
  const id = 'mt' + (++modalSeq);
  o.innerHTML = `<div class="modal" role="dialog" aria-modal="true" aria-labelledby="${id}" tabindex="-1"><div class="bar"><h3 id="${id}">${esc(title)}</h3><button class="x" type="button" aria-label="Cerrar">${ico('close', 18)}</button></div>${html}</div>`;
  let close;
  close = mountOverlay(o, () => close());
  $('.x', o).onclick = () => close();
  return { el: o, close: () => close() };
}

// Reemplazo de confirm() nativo. Devuelve una promesa: true si confirma, false si cancela o pulsa Esc.
export function confirmDialog(message, { title = 'Confirmar', ok = 'Confirmar', cancel = 'Cancelar', danger = false } = {}) {
  return new Promise(resolve => {
    const o = document.createElement('div');
    o.className = 'overlay top';
    const id = 'mt' + (++modalSeq);
    o.innerHTML = `<div class="modal confirm" role="alertdialog" aria-modal="true" aria-labelledby="${id}" aria-describedby="${id}d" tabindex="-1">
      <h3 id="${id}">${esc(title)}</h3><p id="${id}d" class="muted"></p>
      <div class="row end"><button type="button" class="btn ghost" data-c>${esc(cancel)}</button><button type="button" class="btn${danger ? ' danger' : ''}" data-ok>${esc(ok)}</button></div></div>`;
    $('p', o).textContent = message;
    let unmount;
    const finish = v => { unmount(); resolve(v); };
    unmount = mountOverlay(o, () => finish(false));
    $('[data-c]', o).onclick = () => finish(false);
    $('[data-ok]', o).onclick = () => finish(true);
    $(danger ? '[data-c]' : '[data-ok]', o).focus(); // en acciones destructivas el foco inicia en Cancelar
  });
}

// =====================================================================
// GESTIÓN DE SESIÓN: Timeout de inactividad + Heartbeat
// =====================================================================

const SESSION_CONFIG = {
  INACTIVITY_TIMEOUT: 60 * 1000,      // 1 minuto sin actividad (ajustable)
  WARNING_BEFORE_EXPIRE: 30 * 1000,   // Advertencia 30s antes
  HEARTBEAT_INTERVAL: 20 * 1000,      // Heartbeat cada 20s
  ACTIVITY_EVENTS: ['mousedown', 'mousemove', 'keypress', 'scroll', 'touchstart', 'click']
};

export const SessionManager = {
  lastActivity: Date.now(),
  warningTimer: null,
  expireTimer: null,
  heartbeatTimer: null,
  checkInterval: null,
  warningModal: null,
  isActive: false,

  start() {
    if (this.isActive || !sb) return;
    this.isActive = true;
    this.lastActivity = Date.now();

    this._boundOnActivity = () => this.onActivity();
    SESSION_CONFIG.ACTIVITY_EVENTS.forEach(event => {
      document.addEventListener(event, this._boundOnActivity, { passive: true });
    });

    this.heartbeatTimer = setInterval(() => this.sendHeartbeat(), SESSION_CONFIG.HEARTBEAT_INTERVAL);
    this.checkInterval = setInterval(() => this.checkInactivity(), 1000);
  },

  stop() {
    if (!this.isActive) return;
    this.isActive = false;
    clearInterval(this.heartbeatTimer);
    clearInterval(this.checkInterval);
    clearTimeout(this.warningTimer);
    clearTimeout(this.expireTimer);
    if (this.warningModal) {
      this.warningModal.close();
      this.warningModal = null;
    }
    if (this._boundOnActivity) {
      SESSION_CONFIG.ACTIVITY_EVENTS.forEach(event => {
        document.removeEventListener(event, this._boundOnActivity);
      });
    }
  },

  onActivity() {
    this.lastActivity = Date.now();
    if (this.warningModal) {
      this.warningModal.close();
      this.warningModal = null;
      clearTimeout(this.expireTimer);
    }
  },

  checkInactivity() {
    if (!this.isActive || !S.user) return;

    const elapsed = Date.now() - this.lastActivity;
    const timeToWarning = SESSION_CONFIG.INACTIVITY_TIMEOUT - SESSION_CONFIG.WARNING_BEFORE_EXPIRE;
    const timeToExpire = SESSION_CONFIG.INACTIVITY_TIMEOUT;

    if (elapsed >= timeToWarning && elapsed < timeToExpire && !this.warningModal) {
      this.showWarning();
    }

    if (elapsed >= timeToExpire) {
      this.expireSession();
    }
  },

  showWarning() {
    const remaining = Math.ceil((SESSION_CONFIG.INACTIVITY_TIMEOUT - (Date.now() - this.lastActivity)) / 1000);
    
    this.warningModal = openModal('⚠️ Sesión por expirar', `
      <div style="text-align:center; padding:1rem;">
        <p style="font-size:1.1rem; margin-bottom:1rem;">Tu sesión se cerrará automáticamente por inactividad en:</p>
        <div id="countdown" style="font-size:3rem; font-weight:bold; color:#c62828; margin:1rem 0;">${remaining}s</div>
        <p class="muted">Presiona el botón para mantener tu sesión activa.</p>
        <button class="lg-btn" id="btn-stay" style="margin-top:1rem; width:100%;">✓ Seguir conectado</button>
      </div>
    `);

    const countdownEl = $('#countdown', this.warningModal.el);
    const updateCountdown = () => {
      const rem = Math.ceil((SESSION_CONFIG.INACTIVITY_TIMEOUT - (Date.now() - this.lastActivity)) / 1000);
      if (countdownEl && rem > 0) countdownEl.textContent = `${rem}s`;
    };
    const countdownInterval = setInterval(updateCountdown, 1000);

    $('#btn-stay', this.warningModal.el).onclick = () => {
      this.onActivity();
      clearInterval(countdownInterval);
    };

    this.expireTimer = setTimeout(() => clearInterval(countdownInterval), SESSION_CONFIG.WARNING_BEFORE_EXPIRE);
  },

  async expireSession() {
    this.stop();
    try { await sb.rpc('close_session'); } catch (err) { console.warn('close_session:', err); }
    try { await sb.auth.signOut({ scope: 'local' }); } catch (err) { console.warn('Expire error:', err); }
    S.user = null; S.profile = null;
    setTimeout(() => { location.hash = ''; location.reload(); }, 2000);
  },

  async sendHeartbeat() {
    if (!S.user) return;
    try {
      const { data, error } = await sb.rpc('heartbeat_session');
      // false => la sesión fue cerrada/expirada en la BD: cerrar también en el navegador
      if (!error && data === false) {
        this.stop();
        try { await sb.auth.signOut({ scope: 'local' }); } catch {}
        S.user = null; S.profile = null;
        toast('Su sesión fue cerrada.', true);
        setTimeout(() => { location.hash = ''; location.reload(); }, 1500);
      }
    } catch (err) { /* Ignorar errores de red del heartbeat */ }
  }
};