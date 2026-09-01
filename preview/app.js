// MeshSync Cognitive Minimalism Interactive Web Simulator
const state = {
  isLoggedIn: false,
  userName: '',
  userIdentifier: '',
  role: 'victim', // 'victim' or 'responder'
  authSelectedRole: 'victim',
  isSignUp: false,

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
      txt: '2nd floor stairwell collapsed, need stretchers and splints',
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
      txt: '2nd floor stairwell collapsed, need stretchers and splints',
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
  ]
};

// Init
document.addEventListener('DOMContentLoaded', () => {
  setupEvents();
  renderAuthState();
});

function setupEvents() {
  document.getElementById('openPeersBtn')?.addEventListener('click', openPeersModal);
}

// Auth Logic
function selectAuthRole(role) {
  state.authSelectedRole = role;
  document.getElementById('authRoleCitizenBtn').classList.toggle('active', role === 'victim');
  document.getElementById('authRoleSarBtn').classList.toggle('active', role === 'responder');

  document.getElementById('citizenFields').style.display = role === 'victim' ? 'block' : 'none';
  document.getElementById('responderFields').style.display = role === 'responder' ? 'block' : 'none';

  const notice = document.getElementById('authRoleNotice');
  const submitBtn = document.getElementById('authSubmitBtn');

  if (role === 'victim') {
    notice.textContent = 'Citizen portal: Broadcast emergency distress signals and confirm your safety with search teams.';
    notice.style.borderLeftColor = 'var(--terracotta)';
    submitBtn.textContent = state.isSignUp ? 'Register Citizen Profile' : 'Access Citizen Portal';
    submitBtn.style.backgroundColor = 'var(--terracotta)';
    submitBtn.style.color = '#ffffff';
  } else {
    notice.textContent = 'Responder portal: Receive inbound victim signals, casualty counts, and coordinate rescue triage.';
    notice.style.borderLeftColor = 'var(--sage)';
    submitBtn.textContent = state.isSignUp ? 'Register SAR Profile' : 'Access Responder Command';
    submitBtn.style.backgroundColor = 'var(--text-color)';
    submitBtn.style.color = 'var(--bg-color)';
  }
}

function setAuthMode(isSignUp) {
  state.isSignUp = isSignUp;
  document.getElementById('authModeSignIn').classList.toggle('active', !isSignUp);
  document.getElementById('authModeSignUp').classList.toggle('active', isSignUp);

  const role = state.authSelectedRole;
  const submitBtn = document.getElementById('authSubmitBtn');
  if (isSignUp) {
    submitBtn.textContent = role === 'victim' ? 'Register Citizen Profile' : 'Register SAR Profile';
  } else {
    submitBtn.textContent = role === 'victim' ? 'Access Citizen Portal' : 'Access Responder Command';
  }
}

function handleAuthSubmit(event) {
  event.preventDefault();
  const name = document.getElementById('authNameInput').value.trim();
  const role = state.authSelectedRole;
  const id = role === 'responder'
    ? (document.getElementById('authBadgeInput').value.trim() || 'SAR-8821')
    : (document.getElementById('authPhoneInput').value.trim() || '+91 98765 43210');

  loginUser(role, name, id);
}

function loginUser(role, name, id) {
  state.isLoggedIn = true;
  state.role = role;
  state.userName = name;
  state.userIdentifier = id;
  state.nickname = (role === 'responder' ? 'R|SAR-' : 'C|dev-') + 'K7P2';

  renderAuthState();
  showToast(`Signed in as ${role === 'responder' ? 'SAR Responder' : 'Citizen'}`);
}

function logoutUser() {
  state.isLoggedIn = false;
  state.userName = '';
  state.userIdentifier = '';
  renderAuthState();
  showToast('Signed out.');
}

function quickLoginCitizen() {
  loginUser('victim', 'Aryan Sinha', '+91 98765 43210');
}

function quickLoginResponder() {
  loginUser('responder', 'Commander Aryan', 'SAR-8821 (Alpha Squad)');
}

function renderAuthState() {
  const authScreen = document.getElementById('authScreen');
  const mainAppScreen = document.getElementById('mainAppScreen');

  if (!state.isLoggedIn) {
    authScreen.style.display = 'flex';
    mainAppScreen.style.display = 'none';
  } else {
    authScreen.style.display = 'none';
    mainAppScreen.style.display = 'flex';

    // Update Header
    const isResponder = state.role === 'responder';
    const portalTitle = document.getElementById('appPortalTitle');
    const userSubtitle = document.getElementById('appUserProfileSubtitle');

    if (portalTitle) {
      portalTitle.textContent = isResponder ? 'SAR Command Portal' : 'Citizen Emergency Portal';
      portalTitle.style.color = isResponder ? 'var(--text-color)' : 'var(--terracotta)';
    }

    if (userSubtitle) {
      userSubtitle.textContent = `${state.userName} · ${state.userIdentifier}`;
    }

    // Role-Gated View Display
    if (isResponder) {
      document.getElementById('victimView').style.display = 'none';
      document.getElementById('responderView').style.display = 'flex';
    } else {
      document.getElementById('victimView').style.display = 'flex';
      document.getElementById('responderView').style.display = 'none';
    }

    renderAll();
  }
}

function toggleTheme() {
  state.isLightMode = !state.isLightMode;
  document.body.classList.toggle('light-mode', state.isLightMode);
  document.getElementById('themeToggleBtn').textContent = state.isLightMode ? 'Obsidian Dark' : 'Linen Light';
  showToast(`Switched to ${state.isLightMode ? 'Linen Light' : 'Obsidian Dark'} Theme`);
}

function toggleRadio() {
  state.radioRunning = !state.radioRunning;
  renderRadioStatus();
  showToast(state.radioRunning ? 'Mesh radio active' : 'Mesh radio stopped');
}

function toggleGps(enable) {
  state.gpsEnabled = enable !== undefined ? enable : !state.gpsEnabled;
  document.getElementById('gpsWarningCard').style.display = state.gpsEnabled ? 'none' : 'flex';
}

function renderRadioStatus() {
  const badge = document.getElementById('radioStateBadge');
  const subtext = document.getElementById('radioSubtext');
  const toggleBtn = document.getElementById('radioToggleBtn');
  const nodeNick = document.getElementById('nodeNickname');

  if (nodeNick) nodeNick.textContent = state.nickname;

  if (state.radioRunning) {
    badge.textContent = 'ONLINE';
    badge.style.backgroundColor = 'var(--sage)';
    subtext.textContent = `Mesh radio active · ${state.peers.length} reachable peers`;
    toggleBtn.textContent = 'Stop Radio';
    toggleBtn.style.backgroundColor = 'var(--terracotta)';
    toggleBtn.style.color = '#ffffff';
  } else {
    badge.textContent = 'OFFLINE';
    badge.style.backgroundColor = 'var(--text-muted)';
    subtext.textContent = 'Radio idle';
    toggleBtn.textContent = 'Start Radio';
    toggleBtn.style.backgroundColor = 'var(--text-color)';
    toggleBtn.style.color = 'var(--bg-color)';
  }

  const peersBtn = document.getElementById('openPeersBtn');
  if (peersBtn) peersBtn.textContent = `${state.peers.length} Peer${state.peers.length === 1 ? '' : 's'}`;
}

// Modal (Citizen only)
function openSosModal(preselectCat = 'medical') {
  if (state.role === 'responder') {
    showToast('Search & Rescue responders cannot broadcast personal SOS signals.');
    return;
  }

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
  showToast('Distress Signal Dispatched!');
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
  showToast('Incident resolved and closed.');
  renderAll();
}

function openPeersModal() {
  const container = document.getElementById('peersListContainer');
  container.innerHTML = state.peers.map(p => `
    <div style="display:flex; justify-content:space-between; align-items:center; padding:12px; border:1px solid var(--border-color); border-radius:8px; background-color:var(--surface-color);">
      <div>
        <div style="font-weight:600; font-size:13px;">${p.name}</div>
        <div style="font-size:11px; color:var(--text-muted); font-style:italic;">Endpoint: ${p.endpointId}</div>
      </div>
      <span style="font-size:10px; font-weight:600; padding:2px 6px; border-radius:4px; background-color:var(--card-color); border:1px solid var(--border-color);">${p.isResponder ? 'RESPONDER' : 'CITIZEN'}</span>
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
  if (state.role === 'victim') {
    renderMyMessages();
  } else {
    renderResponderView();
  }
}

function renderMyMessages() {
  const list = document.getElementById('myMessagesList');
  const countBadge = document.getElementById('myActiveCount');
  if (!list || !countBadge) return;

  countBadge.textContent = `${state.myMessages.length} active`;

  if (state.myMessages.length === 0) {
    list.innerHTML = `
      <div style="background-color:var(--card-color); border:1px solid var(--border-color); border-radius:10px; padding:24px; text-align:center; font-size:13px; color:var(--text-muted); font-style:italic;">
        No distress signals active. Your phone relays messages for others in the background.
      </div>
    `;
    return;
  }

  list.innerHTML = state.myMessages.map(m => `
    <div class="incident-card ${m.acked ? 'acked' : ''}">
      <div class="card-status-header ${m.acked ? 'acked' : ''}">
        <span>${m.acked ? '● Responder Confirmed Receipt' : `○ Relayed across ${state.peers.length} peers`}</span>
        <span style="font-weight:normal; font-size:11px; color:var(--text-muted);">${formatElapsed(m.ts)}</span>
      </div>
      <div class="card-body">
        <div class="card-title-row">
          <span>${m.cat.toUpperCase()}</span>
          <span style="font-weight:normal; font-size:12px; color:var(--text-muted);">${m.n} ${m.n === 1 ? 'Person' : 'People'}</span>
        </div>
        ${m.txt ? `<div class="card-details-box">${escapeHtml(m.txt)}</div>` : ''}
        <button class="card-action-btn" onclick="markSafe('${m.id}')">I Am Safe (Resolve)</button>
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
  const list = document.getElementById('responderIncidentsList');
  if (!list) return;

  const filtered = state.responderFilter === 'ALL'
    ? state.incidents
    : state.incidents.filter(i => i.cat.toUpperCase() === state.responderFilter);

  const totalPeople = state.incidents.reduce((sum, i) => sum + (i.n || 1), 0);
  const ackedCount = state.incidents.filter(i => i.acked).length;

  const mActive = document.getElementById('metricActiveSos');
  const mPeople = document.getElementById('metricPeopleAtRisk');
  const mAck = document.getElementById('metricAckConfirmed');

  if (mActive) mActive.textContent = state.incidents.length;
  if (mPeople) mPeople.textContent = totalPeople;
  if (mAck) mAck.textContent = ackedCount;

  if (filtered.length === 0) {
    list.innerHTML = `
      <div style="background-color:var(--card-color); border:1px solid var(--border-color); border-radius:10px; padding:28px; text-align:center; font-size:13px; color:var(--text-muted); font-style:italic;">
        No distress signals in range.
      </div>
    `;
    return;
  }

  list.innerHTML = filtered.map(i => `
    <div class="incident-card">
      <div class="card-status-header">
        <span>${i.cat.toUpperCase()}</span>
        <span style="font-weight:normal; font-size:11px; color:var(--text-muted);">#${i.origin} · ${formatElapsed(i.ts)} · ${i.hops === 0 ? 'Direct link' : `${i.hops} hops away`}</span>
      </div>
      <div class="card-body">
        <div class="card-title-row">
          <span>${i.n} ${i.n === 1 ? 'Survivor' : 'Survivors'}</span>
          ${i.acked ? '<span style="color:var(--sage); font-size:11px; font-weight:600;">Auto-ACK</span>' : ''}
        </div>
        ${i.txt ? `<div class="card-details-box">${escapeHtml(i.txt)}</div>` : ''}
        <button class="card-action-btn" onclick="closeIncident('${i.id}')">Mark Rescued & Close Incident</button>
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
    txt: `Emergency beacon from survivor #${origin}`,
    ts: Date.now(),
    hops: Math.floor(Math.random() * 2),
    acked: false
  });

  showToast(`Inbound SOS packet received from #${origin}`);
  renderAll();
}

function simReceiveResponderAck() {
  if (state.myMessages.length === 0) return;
  state.myMessages[0].acked = true;
  showToast('Search & Rescue responder confirmed your SOS!');
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
