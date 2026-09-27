(function(){
'use strict';

const FRIENDS_KEY = 'molaplan.friends';
const REQUESTS_KEY = 'molaplan.friendRequests';

function readJSON(key, fallback){
  try {
    const raw = localStorage.getItem(key);
    if (!raw) return fallback;
    const parsed = JSON.parse(raw);
    return parsed ?? fallback;
  } catch (e) {
    return fallback;
  }
}

function writeJSON(key, value){
  try {
    localStorage.setItem(key, JSON.stringify(value));
  } catch (e) {}
}

function getCurrentUserId(){
  const candidates = [
    window.__molaplan && window.__molaplan.state && window.__molaplan.state.user && window.__molaplan.state.user.id,
    window.__molaplan && window.__molaplan.state && window.__molaplan.state.me && window.__molaplan.state.me.id,
    window.__molaplan && window.__molaplan.state && window.__molaplan.state.userId,
    JSON.parse(localStorage.getItem('molaplan.state') || '{}').user && JSON.parse(localStorage.getItem('molaplan.state') || '{}').user.id,
    JSON.parse(localStorage.getItem('molaplan.state') || '{}').me && JSON.parse(localStorage.getItem('molaplan.state') || '{}').me.id,
    JSON.parse(localStorage.getItem('molaplan') || '{}').user && JSON.parse(localStorage.getItem('molaplan') || '{}').user.id,
    JSON.parse(localStorage.getItem('molaplan') || '{}').me && JSON.parse(localStorage.getItem('molaplan') || '{}').me.id,
    JSON.parse(localStorage.getItem('S') || '{}').id
  ];
  for (const value of candidates) {
    if (value) return String(value);
  }
  return null;
}

function getFriends(){
  return Array.isArray(readJSON(FRIENDS_KEY, [])) ? readJSON(FRIENDS_KEY, []) : [];
}

function getRequests(){
  return Array.isArray(readJSON(REQUESTS_KEY, [])) ? readJSON(REQUESTS_KEY, []) : [];
}

function saveFriends(friends){
  writeJSON(FRIENDS_KEY, friends);
}

function saveRequests(requests){
  writeJSON(REQUESTS_KEY, requests);
}

function isFriend(a, b){
  if (!a || !b || String(a) === String(b)) return true;
  const friends = getFriends();
  return friends.some(item => {
    const left = String(item.user_id || item.a || item.left || item.from || '');
    const right = String(item.friend_id || item.b || item.right || item.to || '');
    return (left === String(a) && right === String(b)) || (left === String(b) && right === String(a));
  });
}

function requestState(a, b){
  if (!a || !b || String(a) === String(b)) return 'self';
  if (isFriend(a, b)) return 'friends';
  const requests = getRequests();
  const sent = requests.some(r => String(r.requester_id) === String(a) && String(r.target_id) === String(b) && r.status !== 'declined');
  const received = requests.some(r => String(r.requester_id) === String(b) && String(r.target_id) === String(a) && r.status !== 'declined');
  if (sent) return 'pending';
  if (received) return 'requested';
  return null;
}

function addFriend(a, b){
  if (!a || !b || String(a) === String(b)) return false;
  const list = getFriends();
  const existing = list.some(item => {
    const left = String(item.user_id || item.a || item.left || item.from || '');
    const right = String(item.friend_id || item.b || item.right || item.to || '');
    return (left === String(a) && right === String(b)) || (left === String(b) && right === String(a));
  });
  if (existing) return true;
  list.push({ user_id: String(a), friend_id: String(b), created_at: Date.now() });
  saveFriends(list);
  return true;
}

function addRequest(requesterId, targetId){
  const requests = getRequests();
  const existing = requests.find(r => String(r.requester_id) === String(requesterId) && String(r.target_id) === String(targetId));
  if (existing) {
    if (existing.status === 'accepted') {
      addFriend(requesterId, targetId);
      return true;
    }
    existing.status = 'accepted';
    existing.updated_at = Date.now();
    saveRequests(requests);
    addFriend(requesterId, targetId);
    return true;
  }
  requests.push({
    id: (window.crypto && crypto.randomUUID ? crypto.randomUUID() : 'friend-' + Date.now() + '-' + Math.random().toString(16).slice(2)),
    requester_id: String(requesterId),
    target_id: String(targetId),
    status: 'accepted',
    created_at: Date.now(),
    updated_at: Date.now()
  });
  saveRequests(requests);
  addFriend(requesterId, targetId);
  return true;
}

function toast(msg){
  if (!window.showToast && window.toast) {
    try { window.toast(msg); return; } catch (e) {}
  }
  if (window.showToast) {
    try { window.showToast(msg); return; } catch (e) {}
  }
  const el = document.getElementById('toast');
  if (el) {
    el.textContent = msg;
    el.classList.add('show');
    clearTimeout(el.__timer);
    el.__timer = setTimeout(() => el.classList.remove('show'), 1800);
  }
}

function buildButtonLabel(state){
  if (state === 'friends') return 'Kaverit';
  if (state === 'pending') return 'Pyyntö lähetetty';
  if (state === 'requested') return 'Hyväksy';
  return 'Kaveripyyntö';
}

function decorateRow(row, targetId, myId){
  if (!row || !targetId || !myId || String(targetId) === String(myId)) return;
  if (row.querySelector('[data-friend-target]')) return;

  const state = requestState(myId, targetId);
  const button = document.createElement('button');
  button.type = 'button';
  button.className = 'friend-request-btn';
  button.dataset.friendTarget = String(targetId);
  button.textContent = buildButtonLabel(state);
  if (state === 'friends') button.classList.add('is-friend');
  if (state === 'pending') button.classList.add('is-pending');
  if (state === 'requested') button.classList.add('is-requested');
  row.appendChild(button);
}

function refreshFriendButtons(){
  const detail = document.getElementById('s-detail');
  if (!detail || !detail.classList.contains('active')) return;
  const myId = getCurrentUserId();
  if (!myId) return;

  const detailEvent = window.__molaplan && window.__molaplan.state && window.__molaplan.state.meetups &&
    window.__molaplan.state.meetups.find(m => m.id === (window.__molaplan.state.detailId || window.__molaplan.state.currentId));

  const people = detailEvent && Array.isArray(detailEvent.people) ? detailEvent.people : [];
  const rows = Array.from(detail.querySelectorAll('.prow'));

  rows.forEach((row, index) => {
    const targetId = people[index];
    if (!targetId) return;
    decorateRow(row, targetId, myId);
  });
}

function ensureStyles(){
  if (document.getElementById('molaplan-friend-requests-style')) return;
  const style = document.createElement('style');
  style.id = 'molaplan-friend-requests-style';
  style.textContent = `
    .friend-request-btn {
      margin-left: auto;
      border: 0;
      border-radius: 999px;
      padding: 7px 10px;
      font-size: 11.5px;
      font-weight: 800;
      background: #EEEBFF;
      color: var(--pri, #5B4BFF);
      cursor: pointer;
      min-width: 95px;
    }
    .friend-request-btn.is-friend {
      background: #E6FCF5;
      color: #0B8A63;
    }
    .friend-request-btn.is-pending {
      background: #FFF3DC;
      color: #A86400;
    }
    .friend-request-btn.is-requested {
      background: linear-gradient(135deg, #5B4BFF, #9A5BFF);
      color: #fff;
    }
  `;
  document.head.appendChild(style);
}

document.addEventListener('click', function(event){
  const button = event.target.closest('[data-friend-target]');
  if (!button) return;
  const myId = getCurrentUserId();
  const targetId = button.dataset.friendTarget;
  if (!myId || !targetId) return;

  const state = requestState(myId, targetId);
  if (state === 'friends') {
    toast('Olette jo kavereita');
    return;
  }
  if (state === 'pending') {
    toast('Kaveripyyntö on jo lähetetty');
    return;
  }
  if (state === 'requested') {
    addRequest(targetId, myId);
    toast('Kaveripyyntö hyväksytty');
    refreshFriendButtons();
    return;
  }

  addRequest(myId, targetId);
  toast('Kaveripyyntö lähetetty');
  refreshFriendButtons();
});

ensureStyles();
setTimeout(refreshFriendButtons, 250);
setInterval(refreshFriendButtons, 1500);
const observer = new MutationObserver(function(){ refreshFriendButtons(); });
observer.observe(document.body, { childList: true, subtree: true });
})();
