// Autenticación compartida por PIN para las pantallas Admin de Maryeli Lash Studio
(function () {
  const DEFAULT_PIN = '2026';

  window.getAdminPin = function () {
    return sessionStorage.getItem('maryeli_admin_pin') || '';
  };

  window.lockMaryeliAdmin = function () {
    sessionStorage.removeItem('maryeli_admin_pin');
    window.location.href = 'contacto.html';
  };

  function showPinGate() {
    if (document.getElementById('maryeli-pin-overlay')) return;
    const overlay = document.createElement('div');
    overlay.id = 'maryeli-pin-overlay';
    overlay.className = 'fixed inset-0 z-[100] bg-[#faf7f2]/95 backdrop-blur-xl flex items-center justify-center p-5';
    overlay.innerHTML = `
      <div class="w-full max-w-sm bg-white rounded-2xl p-6 shadow-xl border border-[#d2c4bc]/40 text-center flex flex-col gap-4">
        <div class="w-12 h-12 mx-auto rounded-full bg-[#d6e8d1] text-[#3b4b3a] flex items-center justify-center">
          <span class="material-symbols-outlined text-[26px]">lock</span>
        </div>
        <div>
          <h2 class="font-serif text-2xl text-[#46362b] font-medium">Panel del Estudio</h2>
          <p class="text-xs text-[#4e453f] mt-1">Ingresa tu PIN de administración para acceder.</p>
        </div>
        <input id="maryeli-pin-field" type="password" inputmode="numeric" maxlength="10" placeholder="PIN (por defecto: 2026)"
          class="w-full h-11 px-4 rounded-xl bg-[#f6f3ee] text-center text-base font-semibold tracking-widest text-[#2f2117] focus:outline-none focus:ring-2 focus:ring-[#536351]"/>
        <p id="maryeli-pin-err" class="hidden text-xs text-red-700 font-medium">PIN incorrecto. Intenta de nuevo.</p>
        <button id="maryeli-pin-submit" type="button" class="w-full h-11 rounded-full bg-[#2f2117] text-white text-xs font-semibold uppercase tracking-wider">
          Entrar al Panel
        </button>
        <a href="index.html" class="text-[11px] uppercase tracking-wider text-[#4e453f] underline">Volver al sitio público</a>
      </div>
    `;
    document.body.appendChild(overlay);

    const input = document.getElementById('maryeli-pin-field');
    const err = document.getElementById('maryeli-pin-err');
    const submitBtn = document.getElementById('maryeli-pin-submit');

    async function verify() {
      const val = input.value.trim();
      if (!val) return;
      submitBtn.disabled = true;
      submitBtn.textContent = 'Verificando...';
      const cfg = window.getMaryeliConfig ? window.getMaryeliConfig() : {};
      let ok = false;
      if (cfg.supabaseUrl && cfg.supabaseKey) {
        try {
          await window.supabaseFetch(cfg, 'rpc/admin_get_appointments', {
            method: 'POST',
            body: JSON.stringify({ p_pin: val })
          });
          ok = true;
        } catch (e) {
          ok = val === DEFAULT_PIN && !String(e.message || '').includes('PIN incorrecto');
        }
      } else {
        ok = (val === DEFAULT_PIN);
      }

      if (ok) {
        sessionStorage.setItem('maryeli_admin_pin', val);
        overlay.remove();
        window.dispatchEvent(new CustomEvent('maryeli:admin-unlocked', { detail: { pin: val } }));
      } else {
        err.classList.remove('hidden');
        submitBtn.disabled = false;
        submitBtn.textContent = 'Entrar al Panel';
      }
    }

    submitBtn.addEventListener('click', verify);
    input.addEventListener('keydown', function (e) {
      if (e.key === 'Enter') verify();
    });
    setTimeout(() => input.focus(), 80);
  }

  document.addEventListener('DOMContentLoaded', function () {
    if (!window.getAdminPin()) {
      showPinGate();
    } else {
      window.dispatchEvent(new CustomEvent('maryeli:admin-unlocked', { detail: { pin: window.getAdminPin() } }));
    }
  });
})();
