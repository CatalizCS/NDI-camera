let ws;
const $ = id => document.getElementById(id);
async function api(path, options={}) {
  const r = await fetch('/api/v1' + path, {headers:{'Content-Type':'application/json'}, ...options});
  if (!r.ok) throw new Error(await r.text());
  return r.json();
}
async function load() {
  try {
    const s = await api('/status');
    render(s);
    const c = await api('/cameras');
    $('camera').innerHTML = (c.cameras || []).map(x => `<option value="${x.id}">${x.name}</option>`).join('');
  } catch (e) { $('status').textContent = 'OFFLINE'; }
}
function render(s) {
  $('status').textContent = s.streaming ? 'LIVE' : 'READY';
  $('streamState').textContent = s.streaming ? 'Streaming' : 'Ready';
  $('sourceName').textContent = s.sourceName || '—';
}
function connect() {
  ws = new WebSocket(`ws://${location.host}/ws`);
  ws.onopen = () => $('status').textContent = 'CONNECTED';
  ws.onmessage = e => { try { const m=JSON.parse(e.data); if(m.type==='state') render(m.payload); } catch {} };
  ws.onclose = () => setTimeout(connect,1500);
}
document.querySelectorAll('[data-action]').forEach(b => b.onclick = async () => {
  const action = b.dataset.action;
  await api('/stream/' + (action.endsWith('start') ? 'start':'stop'), {method:'POST',body:'{}'});
  load();
});
$('camera').onchange = e => api('/camera/select',{method:'POST',body:JSON.stringify({camera:e.target.value})});
load(); connect();
