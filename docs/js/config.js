// Configuración compartida de Maryeli Lash Studio
// Proyecto Supabase: uzmzafnjlunrfnptpuzw

window.MARYELI_DEFAULT_CONFIG = {
  studioName: 'Maryeli Lash Studio',
  whatsapp: '50664730344',
  sinpe: '6473-0344',
  anticipo: '₡5,000',
  mapsUrl: 'https://maps.app.goo.gl/jLE2VRxH5RAAuLeVA',
  instagramUrl: 'https://www.instagram.com/maryeli_lash_studio/',
  hoursWeekday: '9:00 AM – 7:00 PM',
  hoursSaturday: '9:00 AM – 4:00 PM',
  supabaseUrl: 'https://uzmzafnjlunrfnptpuzw.supabase.co',
  supabaseKey: '', // Pega aquí tu Publishable / anon key (o en admin.html > Ajustes)
  services: [
    { id: 'fibras-c', name: 'Fibras Tecnológicas C', shortName: 'Fibras C', subtitle: 'Efecto Natural • 90 min', price: '₡20,000' },
    { id: 'fibras-cc', name: 'Fibras Tecnológicas CC', shortName: 'Fibras CC', subtitle: 'Mirada Abierta • 105 min', price: '₡22,000' },
    { id: 'fibras-yy', name: 'Fibras Tecnológicas YY', shortName: 'Fibras YY', subtitle: 'Volumen Suave • 120 min', price: '₡25,000' },
    { id: 'fibras-4dw', name: 'Fibras Tecnológicas 4DW', shortName: 'Fibras 4DW', subtitle: 'Volumen & Densidad • 130 min', price: '₡28,000' }
  ]
};

window.getMaryeliConfig = function () {
  try {
    const saved = localStorage.getItem('maryeli_studio_config');
    if (saved) {
      return Object.assign({}, window.MARYELI_DEFAULT_CONFIG, JSON.parse(saved));
    }
  } catch (e) {}
  return Object.assign({}, window.MARYELI_DEFAULT_CONFIG);
};

window.saveMaryeliConfigLocal = function (cfg) {
  localStorage.setItem('maryeli_studio_config', JSON.stringify(cfg));
};

window.supabaseFetch = async function (cfg, path, options = {}) {
  const url = `${cfg.supabaseUrl.replace(/\/$/, '')}/rest/v1/${path}`;
  const headers = Object.assign({
    'apikey': cfg.supabaseKey,
    'Authorization': `Bearer ${cfg.supabaseKey}`,
    'Content-Type': 'application/json'
  }, options.headers || {});
  const res = await fetch(url, Object.assign({}, options, { headers }));
  const text = await res.text();
  let data = null;
  try { data = text ? JSON.parse(text) : null; } catch (e) { data = text; }
  if (!res.ok) {
    const msg = (data && (data.message || data.error || data.hint)) || `Error HTTP ${res.status}`;
    throw new Error(msg);
  }
  return data;
};
