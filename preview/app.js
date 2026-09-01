// MeshSync Interactive Web Simulator State
const state = {
  role: 'victim', // 'victim' or 'responder'
  radioRunning: true,
  gpsEnabled: true,
  nickname: 'C|dev-K7P2',
  selectedModalCat: 'medical',
  modalHeadcount: 1,
  activeTab: 'mesh',
  responderFilter: 'ALL',
  logFilter: 'ALL',

  peers: [
    { endpointId: 'N9X2', name: 'C|dev-F4W9', isResponder: false },
    { endpointId: 'K3L8', name: 'R|SAR-ALPHA', isResponder: true }
  ],

  myMessages: [
    {
      id: 'e4a8b29c11f09d31',
      cat: 'medical',
      n: 2,
      txt: '2nd floor collapse near stairwell B, need splints and stretcher',
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
      txt: '2nd floor collapse near stairwell B, need splints and stretcher',
      ts: Date.now() - 140000,
      hops: 0,
      acked: true
    },
    {
      id: '71c9df03a89e4521',
      origin: '3a59d8',
      cat: 'trapped',
      n: 3,
      txt: 'Elevator stalled between floors 3 & 4. Smoke rising.',
      ts: Date.now() - 320000,
      hops: 2,
      acked: false
    }
  ],

  logs: [
    { stamp: '20:45:02', tag: 'INFO', text: 'I am C|dev-K7P2 (origin: 8b7f12)' },
    { stamp: '20:45:05', tag: 'PERM', text: 'perm location: GRANTED, bluetoothScan: GRANTED' },
    { stamp: '20:45:08', tag: 'INFO', text: 'started — advertising=true discovering=true' },
    { stamp: '20:45:15', tag: 'PEER', text: 'found C|dev-F4W9 (N9X2) — deferring to dial' },
    { stamp: '20:45:18', tag: 'PEER', text: 'CONNECTED to C|dev-F4W9' },
    { stamp: '20:45:22', tag: 'PEER', text: 'CONNECTED to R|SAR-ALPHA' },
    { stamp: '20:46:01', tag: 'RECV', text: '<-- {"t":"MSG","core":{"id":"71c9df03a89e4521","cat":"TRAPPED","n":3}}' },
    { stamp: '20:47:10', tag: 'RECV', text: '<-- {"t":"MSG","core":{"type":"ACK","ref":"e4a8b29c11f09d31"}}' }
  ]
};

// Initialization
document.addEventListener('DOMContentLoaded', () => {
  updateClock();
  setInterval(updateClock, 1000);
  setupEvents();
  renderAll();
});

function updateClock() {
  const now = new Date();
  const timeStr = `${String(now.getHours()).padStart(2, '0')}:${String(now.getMinutes()).padStart(2, '0')}`;
  const el = document.getElementById('deviceClock');
  if (el) el.textContent = timeStr;
}

function setupEvents() {
  const charCounter = document.getElementById('charCount');
  const detailsInput = document.getElementById('modalDetailsText');
  if (detailsInput && charCounter) {
    detailsInput.addEventListener('input', (e) => {
      charCounter.textContent = e.target.value.length;
    });
  }

  document.getElementById('openPeersBtn')?.addEventListener('click', openPeersModal);
}

function switchTab(tab) {
  state.activeTab = tab;
  document.getElementById('tabMeshBtn').classList.toggle('active', tab === 'mesh');
  document.getElementById('tabLogBtn').classList.toggle('active', tab === 'log');

  if (tab === 'log') {
    document.getElementById('victimView').style.display = 'none';
    document.getElementById('responderView').style.display = 'none';
    document.getElementById('logView').style.display = 'flex';
    renderLogs();
  } else {
    document.getElementById('logView').style.display = 'none';
    if (state.role === 'victim') {
      document.getElementById('victimView').style.display = 'flex';
      document.getElementById('responderView').style.display = 'none';
    } else {
      document.getElementById('victimView').style.display = 'none';
      document.getElementById('responderView').style.display = 'flex';
    }
  }
}

function setRole(role) {
  state.role = role;
  state.nickname = (role === 'responder' ? 'R|SAR-' : 'C|dev-') + 'K7P2';
  document.getElementById('roleVictimBtn').classList.toggle('active', role === 'victim');
  document.getElementById('roleResponderBtn').classList.toggle('active', role === 'responder');
  document.getElementById('nodeNickname').textContent = state.nickname;

  addLog('ROLE', `role → ${role === 'responder' ? 'Search & Rescue' : 'Victim'}, now advertising as ${state.nickname}`);
  showToast(`Switched role to ${role === 'responder' ? 'Search & Rescue' : 'Victim / Citizen'}`);

  if (state.activeTab === 'mesh') {
    switchTab('mesh');
  }
  renderAll();
}

function toggleRadio() {
  state.radioRunning = !state.radioRunning;
  addLog('INFO', state.radioRunning ? 'started — advertising=true discovering=true' : 'stopped');
  renderRadioStatus();
  showToast(state.radioRunning ? 'Mesh radio started' : 'Mesh radio stopped');
}

function toggleGps(enable) {
  state.gpsEnabled = enable !== undefined ? enable : !state.gpsEnabled;
  document.getElementById('gpsWarningCard').style.display = state.gpsEnabled ? 'none' : 'flex';
  if (!state.gpsEnabled) {
    addLog('WARN', 'WARNING: location services are OFF — turn GPS on');
  } else {
    addLog('PERM', 'GPS enabled: Location services healthy');
  }
}

function renderRadioStatus() {
  const glow = document.getElementById('radioGlowDot');
  const badge = document.getElementById('radioStateBadge');
  const subtext = document.getElementById('radioSubtext');
  const toggleBtn = document.getElementById('radioToggleBtn');
  const toggleIcon = document.getElementById('radioToggleIcon');
  const toggleLabel = document.getElementById('radioToggleLabel');

  if (state.radioRunning) {
    glow.className = 'status-glow-dot active';
    badge.className = 'status-badge active';
    badge.textContent = 'ONLINE';
    subtext.textContent = `Advertising & Discovering · ${state.peers.length} in direct range`;
    toggleBtn.className = 'radio-toggle-btn active';
    toggleIcon.textContent = 'stop';
    toggleLabel.textContent = 'Stop Radio';
  } else {
    glow.className = 'status-glow-dot';
    badge.className = 'status-badge';
    badge.textContent = 'STANDBY';
    subtext.textContent = 'Mesh radio stopped';
    toggleBtn.className = 'radio-toggle-btn';
    toggleIcon.textContent = 'play_arrow';
    toggleLabel.textContent = 'Start Mesh';
  }

  const peersLabel = document.getElementById('peersCountLabel');
  if (peersLabel) peersLabel.textContent = `${state.peers.length} Peer${state.peers.length === 1 ? '' : 's'}`;
}

// Modal logic
function openSosModal(preselectCat = 'medical') {
  state.selectedModalCat = preselectCat;
  state.modalHeadcount = 1;
  document.getElementById('modalHeadcount').textContent = '1';
  document.getElementById('modalDetailsText').value = '';
  document.getElementById('charCount').textContent = '0';

  const chips = document.querySelectorAll('.category-chip-group .cat-chip');
  chips.forEach(chip => {
    chip.classList.toggle('active', chip.classList.contains(preselectCat));
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
  const current = state.modalHeadcount;
  const next = Math.max(1, current + delta);
  state.modalHeadcount = next;
  document.getElementById('modalHeadcount').textContent = String(next);
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

  addLog('INFO', `created SOS ${newId.substring(0, 8)} (${newMsg.cat.toUpperCase()}, ${newMsg.n} people)`);
  addLog('RADIO', `broadcast SOS packet to ${state.peers.length} directly reachable peers`);

  closeSosModal();
  renderAll();
  showToast(`Distress Signal Broadcasted! ID: #${newId.substring(0, 6)}`);
}

function markSafe(id) {
  if (confirm('Mark yourself safe? This floods a CANCEL packet across all connected mesh nodes.')) {
    state.myMessages = state.myMessages.filter(m => m.id !== id);
    state.incidents = state.incidents.filter(m => m.id !== id);
    addLog('INFO', `sent CANCEL for ${id.substring(0, 8)} (reason: SELF_RESOLVED)`);
    showToast('Distress signal cancelled and marked safe.');
    renderAll();
  }
}

function closeIncident(id) {
  if (confirm('Close and resolve incident? This floods a RESCUED cancel packet across the mesh.')) {
    state.incidents = state.incidents.filter(m => m.id !== id);
    state.myMessages = state.myMessages.filter(m => m.id !== id);
    addLog('INFO', `responder closed incident ${id.substring(0, 8)} (reason: RESCUED)`);
    showToast('Incident closed and broadcasted as RESCUED.');
    renderAll();
  }
}

function openPeersModal() {
  const container = document.getElementById('peersListContainer');
  const sub = document.getElementById('modalPeersSubtitle');
  sub.textContent = `${state.peers.length} directly reachable peer${state.peers.length === 1 ? '' : 's'} via P2P Cluster`;

  container.innerHTML = state.peers.map(p => `
    <div class="peer-row-item">
      <div class="peer-avatar ${p.isResponder ? 'responder' : ''}">
        <span class="material-symbols-rounded">${p.isResponder ? 'medical_services' : 'phone_android'}</span>
      </div>
      <div class="peer-info">
        <div class="peer-name-row">
          <span class="peer-name">${p.name}</span>
          <span class="peer-badge ${p.isResponder ? 'responder' : ''}">${p.isResponder ? 'RESPONDER' : 'CITIZEN'}</span>
        </div>
        <div class="peer-endpoint">Endpoint: ${p.endpointId} · Direct radio active</div>
      </div>
      <div class="peer-live-dot"></div>
    </div>
  `).join('');

  document.getElementById('peersModal').style.display = 'flex';
}

function closePeersModal() {
  document.getElementById('peersModal').style.display = 'none';
}

// Rendering
function renderAll() {
  renderRadioStatus();
  renderMyMessages();
  renderResponderView();
  renderLogs();
}

function renderMyMessages() {
  const list = document.getElementById('myMessagesList');
  const countBadge = document.getElementById('myActiveCount');
  countBadge.textContent = `${state.myMessages.length} Active`;

  if (state.myMessages.length === 0) {
    list.innerHTML = `
      <div style="background-color: var(--surface-dark); border: 1px solid var(--card-border); border-radius: 16px; padding: 20px; text-align: center;">
        <span class="material-symbols-rounded" style="font-size: 36px; color: var(--mesh-teal-glow);">shield</span>
        <div style="font-weight: bold; margin: 8px 0 4px;">No Active Distress Signals</div>
        <p style="font-size: 12px; color: var(--text-dim);">When you trigger an SOS, it automatically propagates across peer-to-peer devices even without cell service.</p>
      </div>
    `;
    return;
  }

  list.innerHTML = state.myMessages.map(m => {
    const elapsed = formatElapsed(m.ts);
    return `
      <div class="incident-card ${m.acked ? 'acked' : ''}">
        <div class="card-status-header ${m.acked ? 'acked' : ''}">
          <span class="material-symbols-rounded">${m.acked ? 'verified' : 'wifi_tethering'}</span>
          <span>${m.acked ? 'RESPONDER ACKNOWLEDGED — Help incoming!' : `Relayed across ${state.peers.length} nearby devices`}</span>
          <span class="status-time">${elapsed}</span>
        </div>
        <div class="card-body">
          <div class="card-main-info">
            <div class="cat-icon-container ${m.cat}">
              <span class="material-symbols-rounded">${getCatIcon(m.cat)}</span>
            </div>
            <div class="card-title-group">
              <div class="card-title">${getCatTitle(m.cat)}</div>
              <div class="card-meta-row">
                <span class="meta-pill">${m.n} ${m.n === 1 ? 'Person' : 'People'}</span>
                <span class="meta-pill font-mono">ID: #${m.id.substring(0, 6)}</span>
              </div>
            </div>
          </div>
          ${m.txt ? `<div class="card-details-box">${escapeHtml(m.txt)}</div>` : ''}
          <button class="card-action-btn" onclick="markSafe('${m.id}')">
            <span class="material-symbols-rounded">health_and_safety</span>
            <span>I Am Safe (Cancel Distress)</span>
          </button>
        </div>
      </div>
    `;
  }).join('');
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
      <div style="background-color: var(--surface-dark); border: 1px solid var(--card-border); border-radius: 18px; padding: 32px 20px; text-align: center;">
        <span class="material-symbols-rounded" style="font-size: 40px; color: var(--mesh-cyan);">radar</span>
        <div style="font-weight: bold; margin: 12px 0 4px;">Mesh Frequencies Clear</div>
        <p style="font-size: 12px; color: var(--text-dim);">Listening for offline distress packets in peer hop radius...</p>
      </div>
    `;
    return;
  }

  list.innerHTML = filtered.map(i => {
    const elapsed = formatElapsed(i.ts);
    return `
      <div class="incident-card">
        <div class="card-status-header">
          <span class="material-symbols-rounded">${getCatIcon(i.cat)}</span>
          <span>${getCatTitle(i.cat)}</span>
          <span class="status-time">#${i.origin} · ${elapsed}</span>
        </div>
        <div class="card-body">
          <div class="card-main-info">
            <div class="cat-icon-container ${i.cat}">
              <span class="material-symbols-rounded">${getCatIcon(i.cat)}</span>
            </div>
            <div class="card-title-group">
              <div class="card-title">${getCatTitle(i.cat)}</div>
              <div class="card-meta-row">
                <span class="meta-pill">${i.n} ${i.n === 1 ? 'Person' : 'People'}</span>
                <span class="meta-pill cyan">${i.hops === 0 ? 'Direct link' : `${i.hops} hops`}</span>
                ${i.acked ? '<span class="meta-pill green">Auto-ACK</span>' : ''}
              </div>
            </div>
          </div>
          ${i.txt ? `<div class="card-details-box">${escapeHtml(i.txt)}</div>` : ''}
          <button class="card-action-btn" onclick="closeIncident('${i.id}')">
            <span class="material-symbols-rounded">verified_user</span>
            <span>Mark Rescued & Close Incident</span>
          </button>
        </div>
      </div>
    `;
  }).join('');
}

function setLogFilter(tag) {
  state.logFilter = tag;
  document.querySelectorAll('.log-filter-chips .log-chip').forEach(c => {
    c.classList.toggle('active', c.textContent.toUpperCase().includes(tag) || (tag === 'ALL' && c.textContent === 'All'));
  });
  renderLogs();
}

function renderLogs() {
  const query = (document.getElementById('logSearchInput')?.value || '').toLowerCase();
  const terminal = document.getElementById('logTerminal');
  if (!terminal) return;

  const filtered = state.logs.filter(l => {
    if (state.logFilter !== 'ALL' && l.tag !== state.logFilter) return false;
    if (query && !l.text.toLowerCase().includes(query)) return false;
    return true;
  });

  terminal.innerHTML = filtered.map(l => `
    <div class="log-row">
      <span class="log-stamp">${l.stamp}</span>
      <span class="log-tag ${l.tag.toLowerCase()}">${l.tag}</span>
      <span class="log-text">${escapeHtml(l.text)}</span>
    </div>
  `).join('');
}

function addLog(tag, text) {
  const now = new Date();
  const stamp = `${String(now.getHours()).padStart(2, '0')}:${String(now.getMinutes()).padStart(2, '0')}:${String(now.getSeconds()).padStart(2, '0')}`;
  state.logs.unshift({ stamp, tag, text });
  if (state.logs.length > 200) state.logs.pop();
  renderLogs();
}

function copyAllLogs() {
  const text = state.logs.map(l => `${l.stamp} [${l.tag}] ${l.text}`).join('\n');
  navigator.clipboard.writeText(text);
  showToast('Logs copied to clipboard');
}

// Interactive Simulation Handlers
function simReceiveInboundSos() {
  const randomCats = ['medical', 'trapped', 'fire', 'supplies'];
  const cat = randomCats[Math.floor(Math.random() * randomCats.length)];
  const n = Math.floor(Math.random() * 4) + 1;
  const newId = Math.random().toString(16).substring(2, 18);
  const origin = Math.random().toString(16).substring(2, 8);

  const incident = {
    id: newId,
    origin,
    cat,
    n,
    txt: `Emergency simulation from Node #${origin} — immediate triage needed`,
    ts: Date.now(),
    hops: Math.floor(Math.random() * 3),
    acked: false
  };

  state.incidents.unshift(incident);
  addLog('RECV', `<-- {"t":"MSG","core":{"id":"${newId.substring(0, 8)}","origin":"${origin}","cat":"${cat.toUpperCase()}","n":${n}}}`);
  showToast(`Inbound SOS Packet received from Node #${origin}!`);
  renderAll();
}

function simReceiveResponderAck() {
  if (state.myMessages.length === 0) {
    showToast('Send an SOS first to receive an ACK confirmation.');
    return;
  }
  const msg = state.myMessages[0];
  msg.acked = true;
  addLog('RECV', `<-- {"t":"MSG","core":{"type":"ACK","ref":"${msg.id.substring(0, 8)}"}}`);
  showToast('Verified: Search & Rescue Responder confirmed your SOS!');
  renderAll();
}

function simTogglePeer() {
  if (state.peers.length > 1) {
    const dropped = state.peers.pop();
    addLog('DISC', `disconnected from ${dropped.name}`);
    showToast(`Peer ${dropped.name} went out of radio range.`);
  } else {
    const newPeer = { endpointId: 'M2K1', name: 'C|dev-R9Q8', isResponder: false };
    state.peers.push(newPeer);
    addLog('PEER', `CONNECTED to ${newPeer.name}`);
    showToast(`Discovered and paired with ${newPeer.name}!`);
  }
  renderAll();
}

function simToggleGpsState() {
  toggleGps();
  showToast(`GPS is now ${state.gpsEnabled ? 'ENABLED' : 'DISABLED'}`);
}

function showToast(msg) {
  const container = document.getElementById('toastContainer');
  const toast = document.createElement('div');
  toast.className = 'toast';
  toast.innerHTML = `<span class="material-symbols-rounded">info</span><span>${escapeHtml(msg)}</span>`;
  container.appendChild(toast);
  setTimeout(() => toast.remove(), 3500);
}

// Helpers
function getCatIcon(cat) {
  switch (cat) {
    case 'medical': return 'medical_services';
    case 'trapped': return 'person_pin_circle';
    case 'fire': return 'local_fire_department';
    case 'supplies': return 'inventory_2';
    default: return 'emergency';
  }
}

function getCatTitle(cat) {
  switch (cat) {
    case 'medical': return 'Medical Emergency';
    case 'trapped': return 'Trapped / Stranded';
    case 'fire': return 'Fire Hazard';
    case 'supplies': return 'Needs Food / Water';
    default: return 'Emergency SOS';
  }
}

function formatElapsed(ts) {
  const s = Math.floor((Date.now() - ts) / 1000);
  if (s < 10) return 'Just now';
  if (s < 60) return `${s}s ago`;
  if (s < 3600) return `${Math.floor(s / 60)}m ago`;
  return `${Math.floor(s / 3600)}h ago`;
}

function escapeHtml(str) {
  return String(str).replace(/&/g, '&amp;').replace(/</g, '&lt;').replace(/>/g, '&gt;').replace(/"/g, '&quot;');
}
