/* Molaplan – friends: friend requests, friend list and inviting friends to events.
   Loaded by index.html after the app script. Talks to the app only through window.MolaplanApp
   (state, i18n, sheet, toast) and to Supabase through the app's own client.
   Server side (supabase/schema.sql section 7c): table friend_requests (RLS: only the two parties read,
   no direct writes), view friends, table event_invites, RPCs send_friend_request / respond_friend_request /
   remove_friend / invite_friend_to_event (they also create the notifications).
   DOM contract with index.html: participant rows `.prow[data-uid]` in #s-detail, slot #d-friends in the
   event detail, slot #p-friends in the profile. */
(function(){
'use strict';
const A=()=>window.MolaplanApp;
let rows=[], invites=[], loadedFor=null;

function me(){const a=A();return a&&a.me}
function other(r){return r.requester_id===me()?r.target_id:r.requester_id}
function friendIds(){return rows.filter(r=>r.status==='accepted').map(other)}
function incoming(){return rows.filter(r=>r.status==='pending'&&r.target_id===me())}
function outgoing(){return rows.filter(r=>r.requester_id===me()&&(r.status==='pending'||r.status==='declined'))}
function pairRow(uid){return rows.find(r=>(r.requester_id===uid&&r.target_id===me())||(r.target_id===uid&&r.requester_id===me()))}
/* friends | pending (I asked; a decline is not revealed) | requested (they asked me) | null */
function stateWith(uid){
 const r=pairRow(uid);if(!r)return null;
 if(r.status==='accepted')return 'friends';
 if(r.requester_id===me())return 'pending';
 return r.status==='pending'?'requested':null;
}

async function load(){
 const app=A();
 if(!app||!app.me||!app.sb||app.guest){rows=[];invites=[];loadedFor=null;return}
 const sb=app.sb, uid=app.me;
 const [r,i]=await Promise.all([
  sb.from('friend_requests').select('*').order('created_at',{ascending:false}),
  sb.from('event_invites').select('*').eq('inviter_id',uid)
 ]);
 if(r.error){rows=[];invites=[];throw r.error}
 rows=r.data||[];invites=(!i.error&&i.data)||[];loadedFor=uid;
 // names for people that are not otherwise in the app state (avatar()/nameOf() read state.names)
 const names=app.state.names||(app.state.names={});
 const missing=[...new Set(rows.map(other))].filter(id=>id&&id!==uid&&!names[id]);
 if(missing.length){const p=await sb.from('profiles').select('id,display_name').in('id',missing);if(!p.error)(p.data||[]).forEach(x=>{names[x.id]=x.display_name||''})}
}

function esc(s){return A().esc(s)}
function T(k,p){return A().tx(k,p)}
function nm(uid){return A().nameOf(uid)}

function btnFor(uid){
 const st=stateWith(uid);
 if(st==='friends')return `<span class="fr-btn is-friend" data-fr-state="friends">${T('fr.isFriend')}</span>`;
 if(st==='pending')return `<span class="fr-btn is-pending" data-fr-state="pending">${T('fr.pending')}</span>`;
 if(st==='requested'){const r=pairRow(uid);return `<button type="button" class="fr-btn is-requested" data-fr="accept" data-id="${esc(r.id)}" data-uid="${esc(uid)}">${T('fr.accept')}</button>`}
 return `<button type="button" class="fr-btn" data-fr="add" data-uid="${esc(uid)}">＋ ${T('fr.add')}</button>`;
}

function renderDetail(m){
 const app=A(), d=document.getElementById('s-detail');if(!d||!m)return;
 d.querySelectorAll('.prow[data-uid]').forEach(row=>{
  const uid=row.dataset.uid;row.querySelectorAll('.fr-btn').forEach(b=>b.remove());
  if(!uid||uid===me())return;
  row.insertAdjacentHTML('beforeend',btnFor(uid));
 });
 const slot=document.getElementById('d-friends');if(!slot)return;
 const fr=friendIds();
 slot.innerHTML=!app.isPast(m)&&fr.length?`<div style="padding:0 16px 12px"><button type="button" class="btn ghost block" data-fr="invite-open" data-id="${esc(m.id)}" id="fr-invite-open">💌 ${T('fr.invite')}</button></div>`:'';
}

function rowHTML(uid,actions,sub){
 return `<div class="fr-row" data-uid="${esc(uid)}">${A().avatar(uid)}<span class="nm">${esc(nm(uid))}${sub?`<small>${sub}</small>`:''}</span><span class="fr-actions">${actions}</span></div>`;
}
function renderProfile(){
 const slot=document.getElementById('p-friends');if(!slot)return;
 const inc=incoming(), fr=friendIds(), out=outgoing();
 slot.innerHTML=`<div class="card-box" id="fr-card"><h3>👫 ${T('fr.title')} <span class="muted" style="font-weight:600;font-size:14px" id="fr-count">${fr.length}</span></h3>
  ${inc.length?`<div class="fr-sec" id="fr-incoming"><div class="fr-sub">${T('fr.incoming')} · ${inc.length}</div>${inc.map(r=>rowHTML(r.requester_id,`<button type="button" class="fr-btn is-requested" data-fr="accept" data-id="${esc(r.id)}">${T('fr.accept')}</button><button type="button" class="fr-btn is-decline" data-fr="decline" data-id="${esc(r.id)}">${T('fr.decline')}</button>`)).join('')}</div>`:''}
  ${fr.length?`<div class="fr-sec" id="fr-list">${fr.map(uid=>rowHTML(uid,`<button type="button" class="fr-x" data-fr="remove" data-uid="${esc(uid)}" aria-label="${esc(T('fr.remove'))}">${T('fr.remove')}</button>`)).join('')}</div>`:`<p class="muted" style="font-size:13.5px;margin:0;line-height:1.5" id="fr-empty">${T('fr.none')}</p>`}
  ${out.length?`<div class="fr-sec" id="fr-outgoing"><div class="fr-sub">${T('fr.outgoing')}</div>${out.map(r=>rowHTML(r.target_id,`<button type="button" class="fr-x" data-fr="cancel" data-uid="${esc(r.target_id)}">${T('fr.cancel')}</button>`,T('fr.pending'))).join('')}</div>`:''}
 </div>`;
}

function inviteSheetHTML(m){
 const fr=friendIds();
 if(!fr.length)return `<h3>💌 ${T('fr.inviteTitle')}</h3><p class="muted">${T('fr.noFriendsInvite')}</p>`;
 return `<h3>💌 ${T('fr.inviteTitle')}</h3><p class="muted" style="margin:-4px 0 12px;font-size:13.5px">${esc(m.title)}</p><div class="fr-sec" id="fr-invite-list">${fr.map(uid=>{
  const going=(m.people||[]).includes(uid), inv=invites.some(x=>x.event_id===m.id&&x.invitee_id===uid);
  return rowHTML(uid,going?`<span class="fr-btn is-friend">${T('fr.going')}</span>`:inv?`<span class="fr-btn is-pending">${T('fr.invited')}</span>`:`<button type="button" class="fr-btn" data-fr="invite" data-id="${esc(m.id)}" data-uid="${esc(uid)}">${T('fr.inviteBtn')}</button>`);
 }).join('')}</div>`;
}
function openInvite(id){const app=A(), m=app.byId(id);if(!m)return;app.openSheet(inviteSheetHTML(m),'fr-invite')}

function render(view,arg){
 if(!me()||(loadedFor&&loadedFor!==me()))return;
 if(view==='profile')renderProfile();
 else if(view==='detail')renderDetail(arg);
}

async function act(el){
 const app=A();if(!app||!app.me)return;
 const a=el.dataset.fr, uid=el.dataset.uid, id=el.dataset.id, sb=app.sb;
 if(a==='invite-open'){openInvite(id);return}
 if(a==='remove'&&!confirm(T('fr.removeConfirm',{name:nm(uid)})))return;
 const call={
  add:()=>sb.rpc('send_friend_request',{p_target:uid,p_event:app.detailId||null}),
  accept:()=>sb.rpc('respond_friend_request',{p_request:id,p_accept:true}),
  decline:()=>sb.rpc('respond_friend_request',{p_request:id,p_accept:false}),
  remove:()=>sb.rpc('remove_friend',{p_other:uid}),
  cancel:()=>sb.rpc('remove_friend',{p_other:uid}),
  invite:()=>sb.rpc('invite_friend_to_event',{p_event:id,p_friend:uid})
 }[a];
 if(!call)return;
 let res;
 try{res=await app.withBusy(el,()=>app.q(call()))}catch(e){app.toast(app.errText(e));return}
 try{await load()}catch(e){console.warn('Molaplan friends: reload failed',e)}
 if(a==='add')app.toast(res==='accepted'?T('fr.acceptedToast'):T('fr.sentToast'));
 else if(a==='accept')app.toast(T('fr.acceptedToast'));
 else if(a==='decline')app.toast(T('fr.declinedToast'));
 else if(a==='remove')app.toast(T('fr.removedToast'));
 else if(a==='cancel')app.toast(T('fr.cancelledToast'));
 else if(a==='invite'){app.toast(T('fr.invitedToast',{name:nm(uid)}));const m=app.byId(id);const sh=document.getElementById('fr-invite-list');if(m&&sh)app.openSheet(inviteSheetHTML(m),'fr-invite')}
 app.rerender();
}
document.addEventListener('click',e=>{const el=e.target.closest('[data-fr]');if(!el)return;e.preventDefault();e.stopPropagation();act(el)});

(function styles(){
 if(document.getElementById('molaplan-friends-style'))return;
 const st=document.createElement('style');st.id='molaplan-friends-style';
 st.textContent=`.fr-btn{margin-left:auto;flex:none;border:0;border-radius:999px;padding:7px 11px;font-size:12px;font-weight:800;background:#EEEBFF;color:var(--pri,#5B4BFF);cursor:pointer;white-space:nowrap;font-family:inherit}
.prow .fr-btn{margin-left:auto}.prow .role+.fr-btn,.prow .role~.fr-btn{margin-left:8px}
.fr-btn:active{transform:scale(.96)}.fr-btn.is-friend{background:#E6FCF5;color:#0B8A63;cursor:default}.fr-btn.is-pending{background:#FFF3DC;color:#A86400;cursor:default}
.fr-btn.is-requested{background:linear-gradient(135deg,#5B4BFF,#9A5BFF);color:#fff}.fr-btn.is-decline{background:#F1F0F7;color:var(--muted,#6B6880);margin-left:6px}
.fr-sec{display:flex;flex-direction:column;gap:2px;margin-top:6px}.fr-sec+.fr-sec{margin-top:14px}
.fr-sub{font-size:12px;font-weight:800;color:var(--muted,#6B6880);text-transform:uppercase;letter-spacing:.4px;margin:2px 0 4px}
.fr-row{display:flex;align-items:center;gap:10px;padding:7px 0;min-width:0}.fr-row .nm{flex:1;min-width:0;font-weight:700;font-size:14.5px;overflow:hidden;text-overflow:ellipsis;white-space:nowrap}
.fr-row .nm small{display:block;font-weight:600;font-size:12px;color:var(--muted,#6B6880)}.fr-actions{display:flex;align-items:center;flex:none}
.fr-x{border:0;background:none;color:var(--muted,#6B6880);font-size:12.5px;font-weight:700;cursor:pointer;padding:6px 4px;font-family:inherit}`;
 document.head.appendChild(st);
})();

window.MolaplanFriends={load,render,stateWith,friendIds,get rows(){return rows.slice()},get invites(){return invites.slice()}};
// The app may have finished its first load before this file arrived: load now and refresh visible views.
const app=A();
if(app&&app.me&&app.state&&app.state.loaded)load().then(()=>app.rerender()).catch(e=>console.warn('Molaplan friends: load failed',e));
})();
