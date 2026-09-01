// MeshSync Minimalist Interactive Web Simulator State
const state = {
  role: 'victim', // 'victim' or 'responder'
  radioRunning: true,
  gpsEnabled: true,
  isLightMode: false,
  nickname: 'C|dev-K7P2',
  selectedModalCat: 'medical',
  modalHeadcount: 1,
  responderFilter: 'ALL',

  peers: [
    { endpointId: 'N9X2', name: 'C|dev-F4W9', isResponder: false },
    { endpointId: 'K3L8', name: 'R|SAR-ALPHA', isResponder: true }
  ],

  myMessages: [
    {
      id: 'e4a8b29c11f09d31',
      cat: 'medical',
      n: 2,
      txt: '2nd floor collapse near stairwell B, need splints',
      ts: Date.now() - 140000,
      acked: true
    }
  ],

  incidents: [
    {
      id: 'e4a8b29c11f09d31',
      origin: '8b7f12',
      cat: 'medical',
      n: 2,
      txt: '2nd floor collapse near stairwell B, need splints',
      ts: Date.now() - 140000,
      hops: 0,
      acked: true
    },
    {
      id: '71c9df03a89e4521',
      origin: '3a59d8',
      cat: 'trapped',
      n: 3,
      txt: 'Elevator stalled between floors 3 & 4.',
      ts: Date.now() - 320000,
      hops: 2,
      acked: false
    }
  ]
};

// Init
document.addEventListener('DOMContentLoaded', () => {
  setupEvents();
  renderAll();
});

function setupEvents() {
  document.getElementById('openPeersBtn')?.addEventListener('click', openPeersModal);
}

function toggleTheme() {
  state.isLightMode = !state.isLightMode;
  document.body.classList.toggle('light-mode', state.isLightMode);
  document.getElementById('themeToggleBtn').textContent = state.isLightMode ? 'Dark' : 'Light';
  showToast(`Switched to ${state.isLightMode ? 'Light' : 'Dark'} Mode`);
}

function setRole(role) {
  state.role = role;
  state.nickname = (role === 'responder' ? 'R|SAR-' : 'C|dev-') + 'K7P2';
  document.getElementById('roleVictimBtn').classList.toggle('active', role === 'victim');
  document.getElementById('roleResponderBtn').classList.toggle('active', role === 'responder');
  document.getElementById('nodeNickname').textContent = state.nickname;

  if (role === 'victim') {
    document.getElementById('victimView').style.display = 'flex';
    document.getElementById('responderView').style.display = 'none';
  } else {
    document.getElementById('victimView').style.display = 'none';
    document.getElementById('responderView').style.display = 'flex';
  }

  showToast(`Role: ${role === 'responder' ? 'Search & Rescue' : 'Victim / Citizen'}`);
  renderAll();
}

function toggleRadio() {
  state.radioRunning = !state.radioRunning;
  renderRadioStatus();
  showToast(state.radioRunning ? 'Mesh radio started' : 'Mesh radio stopped');
}

function toggleGps(enable) {
  state.gpsEnabled = enable !== undefined ? enable : !state.gpsEnabled;
  document.getElementById('gpsWarningCard').style.display = state.gpsEnabled ? 'none' : 'flex';
}

function renderRadioStatus() {
  const badge = document.getElementById('radioStateBadge');
  const subtext = document.getElementById('radioSubtext');
  const toggleBtn = document.getElementById('radioToggleBtn');
  const dot = document.getElementById('radioDot');

  if (state.radioRunning) {
    badge.textContent = 'ONLINE';
    badge.style.backgroundColor = 'var(--safe-green)';
    subtext.textContent = `Advertising & Discovering · ${state.peers.length} in range`;
    toggleBtn.textContent = 'Stop';
    toggleBtn.style.backgroundColor = 'var(--sos-red)';
    dot.style.backgroundColor = 'var(--safe-green)';
  } else {
    badge.textContent = 'OFFLINE';
    badge.style.backgroundColor = 'var(--text-muted)';
    subtext.textContent = 'Radio idle';
    toggleBtn.textContent = 'Start';
    toggleBtn.style.backgroundColor = 'var(--text-color)';
    toggleBtn.style.color = 'var(--bg-color)';
    dot.style.backgroundColor = 'var(--text-muted)';
  }

  const peersBtn = document.getElementById('openPeersBtn');
  if (peersBtn) peersBtn.textContent = `${state.peers.length} Peer${state.peers.length === 1 ? '' : 's'}`;
}

// Modal
function openSosModal(preselectCat = 'medical') {
  state.selectedModalCat = preselectCat;
  state.modalHeadcount = 1;
  document.getElementById('modalHeadcount').textContent = '1';
  document.getElementById('modalDetailsText').value = '';

  const chips = document.querySelectorAll('.category-chip-group .cat-chip');
  chips.forEach(chip => {
    chip.classList.toggle('active', chip.textContent.toLowerCase() === preselectCat);
  });

  document.getElementById('sosModal').style.display = 'flex';
}

function closeSosModal() {
  document.getElementById('sosModal').style.display = 'none';
}

function selectModalCategory(cat, btn) {
  state.selectedModalCat = cat;
  document.querySelectorAll('.category-chip-group .cat-chip').forEach(b => b.classList.remove('active'));
  btn.classList.add('active');
}

function adjustHeadcount(delta) {
  state.modalHeadcount = Math.max(1, state.modalHeadcount + delta);
  document.getElementById('modalHeadcount').textContent = String(state.modalHeadcount);
}

function submitSos() {
  const details = document.getElementById('modalDetailsText').value.trim();
  const newId = Math.random().toString(16).substring(2, 18);

  const newMsg = {
    id: newId,
    cat: state.selectedModalCat,
    n: state.modalHeadcount,
    txt: details || null,
    ts: Date.now(),
    acked: false
  };

  state.myMessages.unshift(newMsg);
  state.incidents.unshift({
    ...newMsg,
    origin: '8b7f12',
    hops: 0
  });

  closeSosModal();
  renderAll();
  showToast('Distress Signal Broadcasted!');
}

function markSafe(id) {
  state.myMessages = state.myMessages.filter(m => m.id !== id);
  state.incidents = state.incidents.filter(m => m.id !== id);
  showToast('Marked as safe.');
  renderAll();
}

function closeIncident(id) {
  state.incidents = state.incidents.filter(m => m.id !== id);
  state.myMessages = state.myMessages.filter(m => m.id !== id);
  showToast('Incident closed.');
  renderAll();
}

function openPeersModal() {
  const container = document.getElementById('peersListContainer');
  container.innerHTML = state.peers.map(p => `
    <div style="display:flex; justify-content:space-between; align-items:center; padding:10px; border:1px solid var(--border-color); border-radius:6px; background-color:var(--surface-color);">
      <div>
        <div style="font-weight:bold; font-size:12px;">${p.name}</div>
        <div style="font-size:10px; color:var(--text-muted);">Endpoint: ${p.endpointId}</div>
      </div>
      <span style="font-size:9px; font-weight:bold; padding:2px 6px; border-radius:4px; background-color:var(--card-color); border:1px solid var(--border-color);">${p.isResponder ? 'RESPONDER' : 'CITIZEN'}</span>
    </div>
  `).join('');
  document.getElementById('peersModal').style.display = 'flex';
}

function closePeersModal() {
  document.getElementById('peersModal').style.display = 'none';
}

// Render
function renderAll() {
  renderRadioStatus();
  renderMyMessages();
  renderResponderView();
}

function renderMyMessages() {
  const list = document.getElementById('myMessagesList');
  const countBadge = document.getElementById('myActiveCount');
  countBadge.textContent = `${state.myMessages.length} active`;

  if (state.myMessages.length === 0) {
    list.innerHTML = `
      <div style="background-color:var(--card-color); border:1px solid var(--border-color); border-radius:8px; padding:16px; text-align:center; font-size:12px; color:var(--text-muted);">
        No active signals. Your phone relays messages for others in the mesh.
      </div>
    `;
    return;
  }

  list.innerHTML = state.myMessages.map(m => `
    <div class="incident-card ${m.acked ? 'acked' : ''}">
      <div class="card-status-header ${m.acked ? 'acked' : ''}">
        <span>${m.acked ? '● Responder Acknowledged' : `○ Relayed to ${state.peers.length} peers`}</span>
        <span style="font-weight:normal; font-size:10px; color:var(--text-muted);">${formatElapsed(m.ts)}</span>
      </div>
      <div class="card-body">
        <div class="card-title-row">
          <span>${m.cat.toUpperCase()}</span>
          <span style="font-weight:normal; font-size:11px;">${m.n} ${m.n === 1 ? 'Person' : 'People'}</span>
        </div>
        ${m.txt ? `<div class="card-details-box">${escapeHtml(m.txt)}</div>` : ''}
        <button class="card-action-btn" onclick="markSafe('${m.id}')">I Am Safe</button>
      </div>
    </div>
  `).join('');
}

function setResponderFilter(cat) {
  state.responderFilter = cat;
  document.querySelectorAll('#responderFilterBar .filter-pill').forEach(btn => {
    btn.classList.toggle('active', btn.textContent.startsWith(cat) || (cat === 'ALL' && btn.textContent.startsWith('All')));
  });
  renderResponderView();
}

function renderResponderView() {
  const filtered = state.responderFilter === 'ALL'
    ? state.incidents
    : state.incidents.filter(i => i.cat.toUpperCase() === state.responderFilter);

  const totalPeople = state.incidents.reduce((sum, i) => sum + (i.n || 1), 0);
  const ackedCount = state.incidents.filter(i => i.acked).length;

  document.getElementById('metricActiveSos').textContent = state.incidents.length;
  document.getElementById('metricPeopleAtRisk').textContent = totalPeople;
  document.getElementById('metricAckConfirmed').textContent = ackedCount;

  const list = document.getElementById('responderIncidentsList');

  if (filtered.length === 0) {
    list.innerHTML = `
      <div style="background-color:var(--card-color); border:1px solid var(--border-color); border-radius:8px; padding:20px; text-align:center; font-size:12px; color:var(--text-muted);">
        No distress signals in range.
      </div>
    `;
    return;
  }

  list.innerHTML = filtered.map(i => `
    <div class="incident-card">
      <div class="card-status-header">
        <span>${i.cat.toUpperCase()}</span>
        <span style="font-weight:normal; font-size:10px; color:var(--text-muted);">#${i.origin} · ${formatElapsed(i.ts)} · ${i.hops === 0 ? 'Direct' : `${i.hops} hops`}</span>
      </div>
      <div class="card-body">
        <div class="card-title-row">
          <span>${i.n} ${i.n === 1 ? 'Person' : 'People'}</span>
          ${i.acked ? '<span style="color:var(--safe-green); font-size:10px;">Auto-ACK</span>' : ''}
        </div>
        ${i.txt ? `<div class="card-details-box">${escapeHtml(i.txt)}</div>` : ''}
        <button class="card-action-btn" onclick="closeIncident('${i.id}')">Mark Rescued & Close</button>
      </div>
    </div>
  `).join('');
}

function simReceiveInboundSos() {
  const cats = ['medical', 'trapped', 'fire', 'supplies'];
  const cat = cats[Math.floor(Math.random() * cats.length)];
  const n = Math.floor(Math.random() * 3) + 1;
  const newId = Math.random().toString(16).substring(2, 18);
  const origin = Math.random().toString(16).substring(2, 8);

  state.incidents.unshift({
    id: newId,
    origin,
    cat,
    n,
    txt: `Distress signal from #${origin}`,
    ts: Date.now(),
    hops: Math.floor(Math.random() * 2),
    acked: false
  });

  showToast(`Inbound SOS from #${origin}`);
  renderAll();
}

function simReceiveResponderAck() {
  if (state.myMessages.length === 0) return;
  state.myMessages[0].acked = true;
  showToast('Responder confirmed your SOS!');
  renderAll();
}

function simTogglePeer() {
  if (state.peers.length > 1) {
    const p = state.peers.pop();
    showToast(`Disconnected from ${p.name}`);
  } else {
    const p = { endpointId: 'M2K1', name: 'C|dev-R9Q8', isResponder: false };
    state.peers.push(p);
    showToast(`Paired with ${p.name}`);
  }
  renderAll();
}

function simToggleGpsState() {
  toggleGps();
  showToast(`GPS: ${state.gpsEnabled ? 'ON' : 'OFF'}`);
}

function showToast(msg) {
  const container = document.getElementById('toastContainer');
  const toast = document.createElement('div');
  toast.className = 'toast';
  toast.textContent = msg;
  container.appendChild(toast);
  setTimeout(() => toast.remove(), 2500);
}

function formatElapsed(ts) {
  const s = Math.floor((Date.now() - ts) / 1000);
  if (s < 60) return `${s}s ago`;
  if (s < 3600) return `${Math.floor(s / 60)}m ago`;
  return `${Math.floor(s / 3600)}h ago`;
}

function escapeHtml(str) {
  return String(str).replace(/&/g, '&amp;').replace(/</g, '&lt;').replace(/>/g, '&gt;').replace(/"/g, '&quot;');
}
