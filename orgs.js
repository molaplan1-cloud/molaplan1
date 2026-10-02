/* Molaplan – team and business management (schema.sql section 9). Loaded by index.html after the app script.
   Talks to the app only through window.MolaplanApp (state, i18n, navigation, sheet, toast, chat) and to Supabase
   through the app's own client. Every write goes through RLS-checked tables or security-definer RPCs:
   teams: update_team, create_team_invite_link / join_team_by_link / team_link_preview, invite_to_team /
   respond_team_invite, add_team_roster_member, set_team_member, remove_team_member, save_team_series /
   delete_team_series, team_rsvp; staff writes team_events / team_places / team_docs / team_roles directly (RLS).
   businesses: create_business_invite_link / join_business_by_link / business_link_preview, remove_business_member,
   save_business_series / delete_business_series; single events use the app's own create form.
   Screens: #s-tm (team, param = team id) and #s-bm (business, param = business id). Join links: /t/<token>, /b/<token>. */
(function(){
'use strict';
const A=()=>window.MolaplanApp;
const T=(k,p)=>A().tx(k,p), TN=(k,n,p)=>A().txn(k,n,p), esc=s=>A().esc(s), ic=n=>A().icon(n);
const $=s=>document.querySelector(s), $$=s=>[...document.querySelectorAll(s)];
const LINK_KEY='molaplan.orgLink';
const KINDS=['training','game','meeting'], KIND_IC={training:'🏃',game:'🏆',meeting:'🗣️'};
const ROLE_ORD={manager:0,coach:1,member:2,parent:3};
/* Sport-specific default titles (translated when chosen; stored as plain text on the member row) */
const SPORT_TITLES={
 jalkapallo:['gk','def','mid','fwd'], salibandy:['gk','def','fwd'], jaakiekko:['gk','def','fwd'],
 koripallo:['pg','wing','center'], lentopallo:['setter','outside','middle','libero'],
 juoksu:['pacer'], uinti:['sprinter','distance'], padel:['left','right'], tennis:['singles','doubles']
};
const GENERIC_TITLES=['asstCoach','physio','equipment','treasurer','vicecaptain'];
let D=empty(), TM={id:null,seg:'sched',showPast:false,openEv:null}, BM={id:null,seg:'events'}, FORM=null;

function empty(){return {teams:[],mem:[],ev:[],rsvp:[],places:[],docs:[],series:[],roles:[],inv:[],links:[],bmem:[],bser:[],blinks:[],loadedFor:null}}
function me(){const a=A();return a&&a.me}
async function opt(p){try{const r=await p;if(r&&r.error)throw r.error;return (r&&r.data)||[]}catch(e){return []}}
function pad(n){return String(n).padStart(2,'0')}
function ymdOff(days){const d=A().today0();d.setDate(d.getDate()+days);return A().ymd(d)}
function todayYmd(){return A().ymd(A().today0())}
function dObj(ymd){const [y,m,d]=String(ymd).split('-').map(Number);return new Date(y,(m||1)-1,d||1)}
function hm5(t){return String(t||'').slice(0,5)}
function addMin(t,min){if(!t)return '';const [h,m]=hm5(t).split(':').map(Number);const x=(h*60+m+Number(min||0))%1440;return pad(Math.floor(x/60))+':'+pad(x%60)}
function fmtDay(ymd){return A().dtf({weekday:'short',day:'numeric',month:'numeric'}).format(dObj(ymd))}
function fmtLong(ymd){return A().dtf({weekday:'long',day:'numeric',month:'long'}).format(dObj(ymd))}
function wdName(n){return A().dtf({weekday:'short'}).format(new Date(2024,0,n))}   /* 2024-01-01 = Monday */
function rpcErr(e){return A().errText(e)}
async function rpc(fn,args,el){const app=A();return app.withBusy(el,()=>app.q(app.sb.rpc(fn,args)))}
function busyQ(p,el){const app=A();return app.withBusy(el,()=>app.q(p))}
function css(){if($('#orgs-css'))return;const s=document.createElement('style');s.id='orgs-css';s.textContent=`
.om-hero{margin:0 16px 14px;padding:20px 18px 16px;border-radius:26px;color:#fff;background:linear-gradient(150deg,hsl(var(--h) 72% 52%),hsl(calc(var(--h) + 40) 78% 58%))}
.om-hero .e{font-size:40px;line-height:1}.om-hero h1{font-size:24px;font-weight:800;margin:8px 0;word-break:break-word}
.om-hero .bd{display:flex;flex-wrap:wrap;gap:6px}.om-hero .bd span{font-size:12px;font-weight:700;padding:3px 9px;border-radius:999px;background:rgba(255,255,255,.22)}
.om-seg{display:flex;gap:6px;overflow-x:auto;padding:0 16px 12px;scrollbar-width:none}.om-seg::-webkit-scrollbar{display:none}
.om-seg button{flex:none;height:36px;padding:0 13px;border-radius:999px;background:#fff;font-size:13px;font-weight:700;color:var(--muted);box-shadow:var(--shadow-sm)}
.om-seg button.on{background:var(--ink);color:#fff}
.om-ev{border-top:1px solid #F0EEF6;padding:12px 0}.om-ev:first-of-type{border-top:0;padding-top:2px}
.om-ev .r1{display:flex;gap:10px;align-items:flex-start}.om-ev .k{font-size:22px;line-height:1.1}
.om-ev .m{flex:1;min-width:0}.om-ev b{display:block;font-size:15px}.om-ev small{display:block;color:var(--muted);font-size:12.5px;line-height:1.45}
.om-ev.cx b{text-decoration:line-through;color:var(--muted)}
.om-tag{display:inline-block;font-size:10.5px;font-weight:800;padding:2px 7px;border-radius:999px;background:#F1EFFA;color:#5B4BD6;margin-right:4px;vertical-align:1px}
.om-tag.bad{background:#FFF0F0;color:#C92A2A}.om-tag.ok{background:#EBFBEE;color:#2B8A3E}.om-tag.warn{background:#FFF3DC;color:#A86400}
.om-rsvp{display:flex;flex-wrap:wrap;gap:6px;margin-top:8px;align-items:center}.om-rsvp .who{font-size:12px;font-weight:700;color:var(--muted);margin-right:2px}
.om-rsvp button{height:32px;padding:0 11px;border-radius:999px;font-size:12.5px;font-weight:700;background:#F3F2F8;color:var(--ink)}
.om-rsvp button.on.going{background:#2B8A3E;color:#fff}.om-rsvp button.on.maybe{background:#E8A400;color:#fff}.om-rsvp button.on.no{background:#C92A2A;color:#fff}
.om-acts{display:flex;flex-wrap:wrap;gap:6px;margin-top:8px}
.om-day{font-size:12px;font-weight:800;color:var(--muted);text-transform:uppercase;letter-spacing:.04em;margin:14px 0 2px}.om-day:first-child{margin-top:0}
.om-wd{display:flex;gap:5px;flex-wrap:wrap}.om-wd button{width:42px;height:38px;border-radius:12px;background:#F3F2F8;font-weight:700;font-size:13px}.om-wd button.on{background:var(--pri);color:#fff}
.om-map{height:200px;border-radius:16px;overflow:hidden;background:#E8EEF3;position:relative;z-index:0;margin-bottom:10px}
.om-place{display:flex;gap:10px;align-items:flex-start;padding:10px 0;border-top:1px solid #F0EEF6}.om-place:first-of-type{border-top:0}
.om-place .m{flex:1;min-width:0}.om-place small{display:block;color:var(--muted);font-size:12.5px}
.om-doc{padding:10px 0;border-top:1px solid #F0EEF6}.om-doc:first-of-type{border-top:0}.om-doc p{white-space:pre-wrap;margin:6px 0 0;font-size:14px;line-height:1.5}
.om-link{display:flex;gap:8px;align-items:center;padding:8px 0;border-top:1px solid #F0EEF6;font-size:13px}.om-link .m{flex:1;min-width:0}
.om-ro{margin:0 16px 14px;padding:12px 14px;border-radius:14px;background:#FFF5F5;color:#C92A2A;font-size:13.5px;line-height:1.45}
.om-titles{display:flex;flex-wrap:wrap;gap:6px;margin-top:6px}.om-titles button{height:30px;padding:0 10px;border-radius:999px;background:#F3F2F8;font-size:12.5px;font-weight:600}
.om-row-btns{display:flex;gap:6px;flex-wrap:wrap}
.om-sheet .inp{width:100%}.om-sheet h3{margin-bottom:4px}
.om-mgr{display:flex;gap:8px;margin-top:10px}.om-mgr .btn{flex:1;min-width:0;white-space:normal;line-height:1.2;padding-left:10px;padding-right:10px}
#s-tm,#s-bm{overflow-x:hidden}.om-ev .m,.om-place .m{overflow-wrap:anywhere}
.om-ext{color:var(--pri);font-weight:700;font-size:13px}
.msg .msg-rep{align-self:center;flex:none;border:0;background:none;color:var(--muted);opacity:.55;font-size:13px;padding:6px;cursor:pointer}.msg .msg-rep:hover{opacity:1}
`;document.head.appendChild(s)}

/* ---------------- data ---------------- */
async function load(){
 const app=A();
 if(!app||!app.me||!app.sb||app.guest){D=empty();return}
 const sb=app.sb, uid=app.me, since=ymdOff(-45);
 const [teams,mem,ev,places,docs,ser,roles,inv,links,bmem,bser,blinks]=await Promise.all([
  opt(sb.from('teams').select('*').order('created_at',{ascending:true})),
  opt(sb.from('team_members').select('*')),
  opt(sb.from('team_events').select('*').gte('event_date',since).order('event_date',{ascending:true}).limit(3000)),
  opt(sb.from('team_places').select('*').order('sort_order',{ascending:true})),
  opt(sb.from('team_docs').select('*').order('sort_order',{ascending:true})),
  opt(sb.from('team_event_series').select('*').order('created_at',{ascending:true})),
  opt(sb.from('team_roles').select('*').order('sort_order',{ascending:true})),
  opt(sb.from('team_invites').select('*')),
  opt(sb.from('team_invite_links').select('*').order('created_at',{ascending:false})),
  opt(sb.from('business_members').select('*')),
  opt(sb.from('business_event_series').select('*').order('created_at',{ascending:true})),
  opt(sb.from('business_invite_links').select('*').order('created_at',{ascending:false}))
 ]);
 let rsvp=[];
 if(ev.length){try{rsvp=await app.selectIn('team_event_rsvps','event_id',ev.map(e=>e.id))}catch(e){rsvp=[]}}
 D={teams,mem,ev,rsvp,places,docs,series:ser,roles,inv,links,bmem,bser,blinks,loadedFor:uid};
 const names=app.state.names||(app.state.names={});
 const ids=new Set();mem.forEach(m=>{if(m.user_id)ids.add(m.user_id)});inv.forEach(i=>{ids.add(i.invitee_id);ids.add(i.inviter_id)});bmem.forEach(m=>ids.add(m.user_id));
 const miss=[...ids].filter(id=>id&&id!==uid&&names[id]==null);
 if(miss.length){try{(await app.selectIn('profiles','id',miss)).forEach(p=>{names[p.id]=p.display_name||''})}catch(e){}}
}
function team(id){return id?D.teams.find(t=>t.id===id):null}
function members(tid){return D.mem.filter(m=>m.team_id===tid)}
function memById(id){return D.mem.find(m=>m.id===id)}
function myMem(tid){return D.mem.find(m=>m.team_id===tid&&m.user_id===me())}
function myRole(tid){const t=team(tid);if(!t)return null;if(t.owner_id===me())return 'manager';const m=myMem(tid);return m?m.role:null}
const isStaff=tid=>myRole(tid)==='manager'||myRole(tid)==='coach', isMgr=tid=>myRole(tid)==='manager';
function myTeams(){return D.teams.filter(t=>myRole(t.id))}
function myInvites(){return D.inv.filter(i=>i.invitee_id===me()&&!myRole(i.team_id)&&team(i.team_id))}
function memName(m){return !m?'':m.user_id?(m.user_id===me()?A().myName():A().nameOf(m.user_id)):m.display_name}
function teamAct(t){return t&&t.activity_id?A().act(t.activity_id):null}
function teamEmoji(t){const a=teamAct(t);return a?a.emoji:'👥'}
function teamHue(t){const a=teamAct(t);return a?a.hue:A().hashHue(t?t.name:'')}
function events(tid){return D.ev.filter(e=>e.team_id===tid).sort((a,b)=>(a.event_date+hm5(a.event_time)).localeCompare(b.event_date+hm5(b.event_time)))}
function rsvpsOf(eid){return D.rsvp.filter(r=>r.event_id===eid)}
function rsvpOf(eid,mid){return D.rsvp.find(r=>r.event_id===eid&&r.member_id===mid)}
/* member rows I can answer for: myself (not as a parent) + children linked to me */
function answerable(tid){const m=myMem(tid);const out=[];if(m&&m.role!=='parent')out.push(m);D.mem.filter(x=>x.team_id===tid&&m&&m.role==='parent'&&m.linked_member===x.id).forEach(x=>out.push(x));return out}
function titleOptions(t){const keys=(SPORT_TITLES[t&&t.activity_id]||[]).map(k=>T('tt.'+k)).concat(GENERIC_TITLES.map(k=>T('tt.'+k)));
 return [...new Set(D.roles.filter(r=>r.team_id===(t&&t.id)).map(r=>r.name).concat(keys))]}
/* business */
function bizById(id){return A().bizById(id)}
function bizRole(bid){const m=D.bmem.find(x=>x.business_id===bid&&x.user_id===me());return m?m.role:null}
function bizActive(b){return !!b&&b.status==='approved'&&!!b.until&&b.until>=todayYmd()}
function myManagedBizs(){return (A().state.biz||[]).filter(b=>b.status==='approved'&&bizRole(b.id))}

/* ---------------- chats (team chat = conversations.kind 'team') ---------------- */
function chatObj(id){const t=team(id);if(!t||!myRole(id)&&!A().state.isAdmin)return null;
 return {id,kind:'team',title:t.name,emoji:teamEmoji(t),hue:teamHue(t),crazy:false,good:false,people:members(id).filter(m=>m.user_id).map(m=>m.user_id),place:t.city||'',
  src:{count:members(id).length,city:t.city||'',team:t,myRole:myRole(id)},member:!!myRole(id),host:isMgr(id),hostName:t.owner_id,created:Date.parse(t.created_at)||0,catName:T('tm.kind')+(teamAct(t)?' '+teamAct(t).name:'')}}
function chatList(){return myTeams().map(t=>chatObj(t.id)).filter(Boolean)}

/* ---------------- entry points used by index.html ---------------- */
function openTeam(id){if(!id)return;A().navTo('s-tm',id)}
function openBizManage(id){if(!id)return;A().navTo('s-bm',id)}
function teamForRequest(rid){return D.teams.find(t=>t.team_request_id===rid)}
function reqRowAction(r){const t=r&&r.status==='approved'&&teamForRequest(r.id);return t?`<button class="btn primary sm" data-o="open-team" data-id="${t.id}" id="tr-open-${r.id}">${T('tm.manage')}</button>`:''}
function bizRowAction(b){return b&&b.status==='approved'&&bizRole(b.id)?`<button class="btn ghost sm" data-o="open-bm" data-id="${b.id}" id="bm-open-${b.id}">${T('bm.manage')}</button>`:''}
function profileTeamsHTML(){const ts=myTeams(), inv=myInvites();if(!ts.length&&!inv.length)return '';
 return `<div class="card-box" id="p-teams"><h3>👥 ${T('tm.myTeams')}</h3>${inv.map(i=>{const t=team(i.team_id);return `<div class="biz-mine-row" id="p-tinv-${t.id}"><span class="bl">💌</span><span class="bm"><b>${esc(t.name)}</b><small class="muted">${esc(T('tm.invitedAs',{role:T('tm.role.'+i.role)}))}</small></span><button class="btn primary sm" data-o="open-team" data-id="${t.id}">${T('tm.open')}</button></div>`}).join('')}
 ${ts.map(t=>`<div class="biz-mine-row" id="p-team-${t.id}"><span class="bl">${teamEmoji(t)}</span><span class="bm"><b>${esc(t.name)}</b><small class="muted">${esc(T('tm.role.'+myRole(t.id)))} · ${esc(TN('tm.membersN',members(t.id).length))}</small></span><button class="btn ${isStaff(t.id)?'primary':'ghost'} sm" data-o="open-team" data-id="${t.id}" id="p-team-open-${t.id}">${isStaff(t.id)?T('tm.manage'):T('tm.open')}</button></div>`).join('')}</div>`}
function notifGo(kind,id){
 if(kind==='team'){if(team(id)){openTeam(id);return true}return false}
 if(kind==='business'){const b=bizById(id);if(b&&b.status==='approved'&&bizRole(id)){openBizManage(id);return true}return false}
 return false;
}
/* join links /t/<token> and /b/<token> (index.html stores them in sessionStorage before the app starts) */
function pendingLink(){try{return JSON.parse(sessionStorage.getItem(LINK_KEY)||'null')}catch(e){return null}}
function clearLink(){try{sessionStorage.removeItem(LINK_KEY)}catch(e){}}
async function openLink(){
 const l=pendingLink();if(!l||!l.tok)return;
 const app=A();if(!app.me){if(app.guest){setTimeout(()=>{app.toast(T('tm.loginToJoin'),4200);app.openAuthPrompt({a:'org-link'})},350)}return}
 clearLink();
 let p=null;try{p=await app.q(app.sb.rpc(l.k==='b'?'business_link_preview':'team_link_preview',{p_token:l.tok}))}catch(e){app.toast(T('tm.linkInvalid'),4200);return}
 if(!p){app.toast(T('tm.linkInvalid'),4200);return}
 if(p.already_member){l.k==='b'?openBizManage(p.business_id):openTeam(p.team_id);return}
 const role=l.k==='b'?T('bm.role.editor'):T('tm.role.'+p.role);
 app.openSheet(`<div class="om-sheet" id="org-join-sheet"><div style="font-size:40px;text-align:center">${l.k==='b'?'🏢':'👥'}</div><h3 style="text-align:center">${esc(l.k==='b'?T('bm.joinTitle',{name:p.name}):T('tm.joinTitle',{name:p.name}))}</h3>
  <p class="sub" style="text-align:center">${esc(l.k==='b'?T('bm.joinBody'):p.member_name?T('tm.joinParentBody',{name:p.member_name}):T('tm.joinBody',{role}))}</p>
  ${l.k==='t'?`<p class="muted" style="text-align:center;font-size:13px;margin:0 0 14px">${esc([p.sport,p.city,TN('tm.membersN',Number(p.members)||0)].filter(Boolean).join(' · '))}</p>`:''}
  <div class="row" style="gap:10px"><button class="btn ghost" data-a="sheet-close" style="flex:1">${T('common.cancel')}</button><button class="btn primary" data-o="join-link" data-v="${l.k}" data-id="${esc(l.tok)}" id="org-join-btn" style="flex:2">${T('tm.joinBtn')}</button></div></div>`,'org-join');
}
async function joinLink(k,tok,el){
 let id;try{id=await rpc(k==='b'?'join_business_by_link':'join_team_by_link',{p_token:tok},el)}catch(e){A().toast(rpcErr(e),4200);return}
 A().closeSheet();A().toast(T(k==='b'?'bm.joined':'tm.joined'),3000);
 await A().refreshData();k==='b'?openBizManage(id):openTeam(id);
}

/* ---------------- team screen #s-tm ---------------- */
function head(title,extra){return `<div class="push-head"><button class="icon-btn" data-a="back" aria-label="${T('common.back')}">${ic('back')}</button><span class="t">${esc(title)}</span>${extra||'<span style="width:44px"></span>'}</div>`}
function renderTeam(keepScroll){
 const s=$('#s-tm');if(!s)return;const st=s.scrollTop;const id=TM.id, t=team(id);
 if(!t){s.innerHTML=head(T('tm.kind'))+`<div class="cards"><div class="empty" id="tm-missing"><div class="e">🔍</div><h3>${T('tm.notFound')}</h3><p>${T('tm.notFoundBody')}</p></div></div>`;return}
 const role=myRole(id), inv=myInvites().find(i=>i.team_id===id);
 const a=teamAct(t), unread=role?A().unreadOf(id):0;
 let html=head(T('tm.kind'))+`<div class="om-hero" style="--h:${teamHue(t)}" id="tm-hero"><div class="e">${teamEmoji(t)}</div><h1 id="tm-name">${esc(t.name)}</h1><div class="bd">${role?`<span id="tm-myrole">${esc(T('tm.role.'+role))}</span>`:''}<span>👥 ${esc(TN('tm.membersN',members(id).length))}</span>${t.city?`<span>📍 ${esc(t.city)}</span>`:''}${a?`<span>${a.emoji} ${esc(a.name)}</span>`:t.sport?`<span>${esc(t.sport)}</span>`:''}</div></div>`;
 if(!role){
  if(inv)html+=`<div class="card-box" id="tm-invite"><p class="muted" style="margin:0 0 12px">💌 ${esc(T('tm.invitedBy',{name:inv.inviter_id?A().nameOf(inv.inviter_id):T('common.someone'),role:T('tm.role.'+inv.role)}))}</p><div class="row" style="gap:10px"><button class="btn primary" data-o="inv-accept" data-id="${id}" id="tm-inv-accept" style="flex:2">${T('tm.accept')}</button><button class="btn ghost" data-o="inv-decline" data-id="${id}" id="tm-inv-decline" style="flex:1">${T('tm.decline')}</button></div></div>`;
  s.innerHTML=html+`<div style="height:28px"></div>`;return;
 }
 html+=`<div class="card-box" id="tm-chat-box"><button class="btn primary block" data-a="open-chat" data-id="${id}" id="tm-chat">💬 ${T('tm.openChat')}${unread?` <i class="cnt">${unread}</i>`:''}</button>${t.description?`<p class="desc" id="tm-desc" style="margin:12px 0 0">${esc(t.description)}</p>`:''}</div>`;
 const segs=[['sched','📅 '+T('tm.seg.sched')],['members','👥 '+T('tm.seg.members')],['places','📍 '+T('tm.seg.places')],['info','📋 '+T('tm.seg.info')]].concat(isMgr(id)?[['settings','⚙️ '+T('tm.seg.settings')]]:[]);
 if(!segs.some(x=>x[0]===TM.seg))TM.seg='sched';
 html+=`<div class="om-seg" id="tm-seg" role="tablist">${segs.map(([k,l])=>`<button class="${TM.seg===k?'on':''}" data-o="tm-seg" data-v="${k}" id="tm-seg-${k}" role="tab" aria-selected="${TM.seg===k}">${l}</button>`).join('')}</div>`;
 html+=TM.seg==='members'?membersHTML(t):TM.seg==='places'?placesHTML(t):TM.seg==='info'?docsHTML(t):TM.seg==='settings'?settingsHTML(t):schedHTML(t);
 html+=`<div class="grp-foot">${role&&t.owner_id!==me()?`<button class="btn ghost block" data-o="tm-leave" data-id="${id}" id="tm-leave">${T('tm.leave')}</button>`:''}</div><div style="height:28px"></div>`;
 s.innerHTML=html;if(keepScroll)s.scrollTop=st;
 if(TM.seg==='places')setTimeout(()=>placesMap(t),40);
}
/* schedule */
function evWhen(e){return (e.event_time?hm5(e.event_time)+(e.duration_min?'–'+addMin(e.event_time,e.duration_min):''):T('tm.noTime'))}
function evPlace(e){const p=e.place_id&&D.places.find(x=>x.id===e.place_id);return p?p.name+(p.address?', '+p.address:''):[e.place_name,e.place_address].filter(Boolean).join(', ')}
function rsvpCounts(eid){const c={going:0,maybe:0,no:0};rsvpsOf(eid).forEach(r=>{if(c[r.status]!=null)c[r.status]++});return c}
function evHTML(t,e){
 const staff=isStaff(t.id), past=e.event_date<todayYmd(), c=rsvpCounts(e.id), cap=e.captain_member&&memById(e.captain_member);
 const ans=answerable(t.id).filter(m=>m.role!=='parent');
 const open=TM.openEv===e.id;
 let h=`<div class="om-ev ${e.cancelled?'cx':''}" id="tm-ev-${e.id}"><div class="r1"><span class="k">${KIND_IC[e.kind]||'📅'}</span><div class="m"><b>${esc(e.title)}${e.kind==='game'&&e.opponent?' – '+esc(e.opponent):''}</b>
  <small>${e.cancelled?`<span class="om-tag bad">${T('tm.cancelled')}</span>`:''}${e.modified?`<span class="om-tag warn">${T('tm.changed')}</span>`:''}${e.series_id?`<span class="om-tag">🔁 ${T('tm.recurring')}</span>`:''}🕒 ${esc(evWhen(e))}${evPlace(e)?' · 📍 '+esc(evPlace(e)):''}</small>
  ${cap?`<small>🅒 ${esc(T('tm.captainIs',{name:memName(cap)}))}</small>`:''}${e.description?`<small>${esc(e.description)}</small>`:''}
  <small><button class="txt-btn" data-o="ev-toggle" data-id="${e.id}" id="tm-ev-cnt-${e.id}" style="padding:0;font-size:12.5px">✅ ${c.going} · ❔ ${c.maybe} · ❌ ${c.no}</button></small></div></div>`;
 if(!e.cancelled&&!past)h+=ans.map(m=>{const r=rsvpOf(e.id,m.id), sv=r&&r.status;return `<div class="om-rsvp" id="tm-rsvp-${e.id}-${m.id}">${ans.length>1||m.user_id!==me()?`<span class="who">${esc(memName(m))}:</span>`:''}${['going','maybe','no'].map(v=>`<button class="${v} ${sv===v?'on':''}" data-o="rsvp" data-id="${e.id}" data-m="${m.id}" data-v="${sv===v?'':v}" id="tm-rsvp-${e.id}-${m.id}-${v}" aria-pressed="${sv===v}">${T('tm.rsvp.'+v)}</button>`).join('')}</div>`}).join('');
 if(open){const rows=rsvpsOf(e.id);h+=`<div class="om-doc" id="tm-ev-list-${e.id}">${['going','maybe','no'].map(v=>{const l=rows.filter(r=>r.status===v).map(r=>memName(memById(r.member_id))).filter(Boolean);return l.length?`<small><b style="display:inline;font-size:12.5px">${T('tm.rsvp.'+v)}:</b> ${esc(l.join(', '))}</small>`:''}).join('')||`<small>${T('tm.noAnswers')}</small>`}</div>`}
 if(staff)h+=`<div class="om-acts"><button class="btn ghost sm" data-o="ev-edit" data-id="${e.id}" id="tm-ev-edit-${e.id}">✏️ ${T('common.edit')}</button>${past?'':`<button class="btn ghost sm" data-o="ev-cancel" data-id="${e.id}" data-v="${e.cancelled?'0':'1'}" id="tm-ev-cancel-${e.id}">${e.cancelled?'↩️ '+T('tm.restore'):'🚫 '+T('tm.cancel')}</button>`}${e.series_id?'':`<button class="btn ghost sm" data-o="ev-del" data-id="${e.id}" id="tm-ev-del-${e.id}">🗑️</button>`}</div>`;
 return h+`</div>`;
}
function schedHTML(t){
 const staff=isStaff(t.id), all=events(t.id), today=todayYmd();
 const up=all.filter(e=>e.event_date>=today).slice(0,80), past=all.filter(e=>e.event_date<today).reverse().slice(0,30);
 let h='';
 if(staff)h+=`<div class="card-box om-mgr" id="tm-sched-actions" style="margin-top:0"><button class="btn primary" data-o="ev-new" data-id="${t.id}" id="tm-ev-new">＋ ${T('tm.newEvent')}</button><button class="btn ghost" data-o="ser-new" data-id="${t.id}" id="tm-ser-new">🔁 ${T('tm.newSeries')}</button></div>`;
 let last='';h+=`<div class="card-box" id="tm-events"><h3>📅 ${T('tm.upcoming')}</h3>${up.length?up.map(e=>{const d=e.event_date!==last?`<div class="om-day">${esc(e.event_date===today?T('date.today'):fmtDay(e.event_date))}</div>`:'';last=e.event_date;return d+evHTML(t,e)}).join(''):`<p class="muted" id="tm-no-events" style="margin:0;font-size:13.5px">${staff?T('tm.noEventsStaff'):T('tm.noEvents')}</p>`}</div>`;
 const ser=D.series.filter(x=>x.team_id===t.id);
 if(ser.length)h+=`<div class="card-box" id="tm-series"><h3>🔁 ${T('tm.series')}</h3>${ser.map(x=>`<div class="om-place" id="tm-ser-${x.id}"><span style="font-size:20px">${KIND_IC[x.kind]||'📅'}</span><div class="m"><b>${esc(x.title)}</b><small>${esc(x.weekdays.map(wdName).join(', '))} ${esc(hm5(x.start_time))}–${esc(addMin(x.start_time,x.duration_min))}</small><small>${esc(T('tm.seriesRange',{from:A().fmtYmd(x.starts_on),to:A().fmtYmd(x.ends_on)}))}</small></div>${staff?`<span class="om-row-btns"><button class="btn ghost sm" data-o="ser-edit" data-id="${x.id}" id="tm-ser-edit-${x.id}">✏️</button><button class="btn ghost sm" data-o="ser-del" data-id="${x.id}" id="tm-ser-del-${x.id}">🗑️</button></span>`:''}</div>`).join('')}</div>`;
 if(past.length)h+=`<div class="card-box" id="tm-past"><button class="txt-btn" data-o="tm-past" id="tm-past-toggle">${TM.showPast?'▾':'▸'} ${esc(TN('tm.pastN',past.length))}</button>${TM.showPast?past.map(e=>evHTML(t,e)).join(''):''}</div>`;
 return h;
}
/* members */
function memRowHTML(t,m){
 const mgr=isMgr(t.id), staff=isStaff(t.id), owner=m.user_id&&m.user_id===t.owner_id;
 const child=m.linked_member&&memById(m.linked_member), parents=D.mem.filter(x=>x.linked_member===m.id);
 const canEdit=staff&&(mgr||m.role==='member'||m.role==='parent');
 return `<div class="grp-mem" id="tm-mem-${m.id}">${m.user_id?A().avatar(m.user_id,'sm'):`<span class="av sm" style="background:#B8B3D6">${esc((m.display_name[0]||'?').toUpperCase())}</span>`}<div class="grow"><b>${esc(memName(m))}${m.user_id===me()?' '+T('common.youParen'):''}</b>
  <small class="muted" style="display:block;font-size:12px">${[m.title?'🏷️ '+esc(m.title):'',child?'👪 '+esc(T('tm.parentOf',{name:memName(child)})):'',parents.length?'👪 '+esc(parents.map(memName).join(', ')):'',!m.user_id?esc(T('tm.noAccount')):''].filter(Boolean).join(' · ')}</small></div>
  ${m.role!=='member'?`<span class="role-badge ${m.role==='coach'?'moderator':''}">${esc(T('tm.role.'+m.role))}${owner?' ★':''}</span>`:''}
  ${canEdit?`<button class="txt-btn" data-o="mem-edit" data-id="${m.id}" id="tm-mem-edit-${m.id}">${T('common.edit')}</button>`:''}</div>`;
}
function membersHTML(t){
 const ms=members(t.id).slice().sort((a,b)=>(ROLE_ORD[a.role]-ROLE_ORD[b.role])||memName(a).localeCompare(memName(b)));
 const staff=isStaff(t.id), mgr=isMgr(t.id);
 const grp=(r,title)=>{const l=ms.filter(m=>m.role===r);return l.length?`<h3 style="font-size:15px;margin:14px 0 4px">${title} (${l.length})</h3>${l.map(m=>memRowHTML(t,m)).join('')}`:''};
 let h=`<div class="card-box" id="tm-members">${grp('manager','⭐ '+T('tm.roles.manager'))}${grp('coach','🧢 '+T('tm.roles.coach'))}${grp('member','👟 '+T('tm.roles.member'))}${grp('parent','👪 '+T('tm.roles.parent'))}</div>`;
 if(staff){
  const links=D.links.filter(l=>l.team_id===t.id&&!l.revoked&&Date.parse(l.expires_at)>Date.now()&&l.uses<l.max_uses);
  const invs=D.inv.filter(i=>i.team_id===t.id);
  h+=`<div class="card-box" id="tm-invite-box"><h3>💌 ${T('tm.inviteTitle')}</h3><p class="muted" style="margin:0 0 10px;font-size:13px">${T('tm.inviteHint')}</p>
   <div class="om-mgr"><button class="btn primary" data-o="inv-friends" data-id="${t.id}" id="tm-inv-friends">🤝 ${T('tm.inviteFriend')}</button><button class="btn ghost" data-o="link-new" data-id="${t.id}" id="tm-link-new">🔗 ${T('tm.newLink')}</button></div>
   <button class="btn ghost block" data-o="roster-new" data-id="${t.id}" id="tm-roster-new" style="margin-top:10px">＋ ${T('tm.addRoster')}</button>
   ${links.length?`<h3 style="font-size:15px;margin:14px 0 2px">${T('tm.activeLinks')}</h3>${links.map(l=>`<div class="om-link" id="tm-link-${l.token}"><div class="m"><b>${esc(T('tm.linkFor',{role:T('tm.role.'+l.role)}))}${l.for_member&&memById(l.for_member)?' · '+esc(memName(memById(l.for_member))):''}</b><small class="muted" style="display:block">${esc(T('tm.linkMeta',{uses:l.uses,max:l.max_uses,date:A().fmtYmd(String(l.expires_at).slice(0,10))}))}</small></div><button class="btn ghost sm" data-o="link-share" data-v="t" data-id="${l.token}" id="tm-link-share-${l.token}">${ic('share')}</button><button class="txt-btn danger-txt" data-o="link-revoke" data-v="t" data-id="${l.token}" id="tm-link-revoke-${l.token}">${T('tm.revoke')}</button></div>`).join('')}`:''}
   ${invs.length?`<p class="muted" style="font-size:12.5px;margin:10px 0 0" id="tm-pending-inv">⏳ ${esc(T('tm.pendingInvites',{names:invs.map(i=>A().nameOf(i.invitee_id)).join(', ')}))}</p>`:''}</div>`;
  const custom=D.roles.filter(r=>r.team_id===t.id);
  h+=`<div class="card-box" id="tm-titles"><h3>🏷️ ${T('tm.titles')}</h3><p class="muted" style="margin:0 0 8px;font-size:13px">${T('tm.titlesHint')}</p>
   <div class="om-titles">${(SPORT_TITLES[t.activity_id]||[]).concat(GENERIC_TITLES).map(k=>`<span class="om-tag">${esc(T('tt.'+k))}</span>`).join('')}${custom.map(r=>`<span class="om-tag ok" id="tm-title-${r.id}">${esc(r.name)} <button class="txt-btn" data-o="title-del" data-id="${r.id}" aria-label="${T('common.delete')}" style="padding:0 0 0 4px;font-size:12px">✕</button></span>`).join('')}</div>
   <div class="row" style="gap:8px;margin-top:10px"><input class="inp" id="tm-title-in" maxlength="30" placeholder="${esc(T('tm.titlePh'))}" style="flex:1"><button class="btn ghost" data-o="title-add" data-id="${t.id}" id="tm-title-add">＋</button></div></div>`;
 }
 return h;
}
/* places */
let pMap=null;
function placesHTML(t){
 const ps=D.places.filter(p=>p.team_id===t.id), staff=isStaff(t.id);
 return `<div class="card-box" id="tm-places">${ps.some(p=>p.lat!=null)?`<div class="om-map" id="tm-places-map"></div>`:''}
  ${ps.length?ps.map(p=>`<div class="om-place" id="tm-place-${p.id}"><span style="font-size:20px">📍</span><div class="m"><b>${esc(p.name)}</b>${p.address?`<small>${esc(p.address)}</small>`:''}${p.notes?`<small>${esc(p.notes)}</small>`:''}
   ${p.lat!=null?`<a class="om-ext" href="https://www.openstreetmap.org/?mlat=${p.lat}&mlon=${p.lng}#map=17/${p.lat}/${p.lng}" target="_blank" rel="noopener">🗺️ ${T('tm.openMap')}</a>`:''}</div>
   ${staff?`<span class="om-row-btns"><button class="btn ghost sm" data-o="pl-edit" data-id="${p.id}" id="tm-pl-edit-${p.id}">✏️</button><button class="btn ghost sm" data-o="pl-del" data-id="${p.id}" id="tm-pl-del-${p.id}">🗑️</button></span>`:''}</div>`).join('')
  :`<p class="muted" id="tm-no-places" style="margin:0;font-size:13.5px">${staff?T('tm.noPlacesStaff'):T('tm.noPlaces')}</p>`}
  ${staff?`<button class="btn primary block" data-o="pl-new" data-id="${t.id}" id="tm-pl-new" style="margin-top:12px">＋ ${T('tm.addPlace')}</button>`:''}</div>`;
}
function placesMap(t){
 const el=$('#tm-places-map');if(pMap){try{pMap.remove()}catch(e){}pMap=null}
 if(!el||!window.L)return;const ps=D.places.filter(p=>p.team_id===t.id&&p.lat!=null);if(!ps.length)return;
 pMap=L.map(el,{zoomControl:false,attributionControl:true});A().addTiles(pMap);
 const ms=ps.map(p=>L.marker([p.lat,p.lng],{icon:A().pinIcon(t.activity_id)}).addTo(pMap).bindPopup(esc(p.name)));
 if(ms.length===1)pMap.setView(ms[0].getLatLng(),15);else pMap.fitBounds(L.featureGroup(ms).getBounds().pad(.25));
}
/* docs: instructions / programme / notes */
const DOC_KINDS=['instructions','programme','notes'], DOC_IC={instructions:'📘',programme:'🗓️',notes:'📝'};
function docsHTML(t){
 const staff=isStaff(t.id);
 return DOC_KINDS.map(k=>{const ds=D.docs.filter(d=>d.team_id===t.id&&d.kind===k);if(!ds.length&&!staff)return '';
  return `<div class="card-box" id="tm-docs-${k}"><h3>${DOC_IC[k]} ${T('tm.doc.'+k)}</h3>${ds.length?ds.map(d=>`<div class="om-doc" id="tm-doc-${d.id}"><b>${esc(d.title)}</b>${d.staff_only?` <span class="om-tag warn">🔒 ${T('tm.staffOnly')}</span>`:''}<p>${esc(d.body)}</p>
   ${staff?`<div class="om-acts"><button class="btn ghost sm" data-o="doc-edit" data-id="${d.id}" id="tm-doc-edit-${d.id}">✏️ ${T('common.edit')}</button><button class="btn ghost sm" data-o="doc-del" data-id="${d.id}" id="tm-doc-del-${d.id}">🗑️</button></div>`:''}</div>`).join('')
   :`<p class="muted" style="margin:0;font-size:13.5px">${T('tm.doc.empty.'+k)}</p>`}
   ${staff?`<button class="btn ghost block" data-o="doc-new" data-id="${t.id}" data-v="${k}" id="tm-doc-new-${k}" style="margin-top:10px">＋ ${T('tm.doc.add')}</button>`:''}</div>`}).join('')||`<div class="card-box"><p class="muted" id="tm-no-docs" style="margin:0">${T('tm.noDocs')}</p></div>`;
}
/* settings (manager) */
function actOptions(sel){return `<option value="">${esc(T('tm.noSport'))}</option>`+A().orderedActs().filter(a=>!a.crazy).map(a=>`<option value="${esc(a.id)}" ${a.id===sel?'selected':''}>${a.emoji} ${esc(a.name)}</option>`).join('')}
function settingsHTML(t){
 return `<div class="card-box" id="tm-settings"><h3>⚙️ ${T('tm.settings')}</h3>
  <label class="field"><span>${T('tm.f.name')}</span><input class="inp" id="tm-s-name" maxlength="80" value="${esc(t.name)}"></label>
  <label class="field"><span>${T('tm.f.sport')}</span><select class="inp" id="tm-s-act">${actOptions(t.activity_id)}</select></label>
  <label class="field"><span>${T('tm.f.city')}</span><input class="inp" id="tm-s-city" maxlength="60" value="${esc(t.city||'')}"></label>
  <label class="field"><span>${T('tm.f.desc')}</span><textarea class="inp" id="tm-s-desc" maxlength="800" rows="4">${esc(t.description||'')}</textarea></label>
  <button class="btn primary block" data-o="tm-save" data-id="${t.id}" id="tm-s-save">${T('common.save')}</button></div>
  ${t.owner_id===me()?`<div class="card-box" id="tm-danger"><p class="muted" style="margin:0 0 10px;font-size:13px">${T('tm.deleteHint')}</p><button class="btn danger block" data-o="tm-delete" data-id="${t.id}" id="tm-delete">${T('tm.delete')}</button></div>`:''}`;
}

/* ---------------- place picker: Photon autocomplete + draggable pin (team places, business series) ---------------- */
const PP={map:null,mk:null,lat:null,lng:null,timer:null,ctrl:null,items:[],pfx:'',act:null};
function pickerHTML(pfx,name,addr,withName){
 return `${withName?`<label class="field"><span>${T('tm.f.placeName')}</span><input class="inp" id="${pfx}-pname" maxlength="60" value="${esc(name||'')}"></label>`:''}
  <div class="field"><span>${T('tm.f.address')}</span><div class="ac-wrap"><input class="inp" id="${pfx}-addr" maxlength="120" value="${esc(addr||'')}" autocomplete="off" role="combobox" aria-autocomplete="list" aria-expanded="false" aria-controls="${pfx}-ac" placeholder="${esc(T('tm.addrPh'))}"><ul class="ac-list" id="${pfx}-ac" role="listbox" hidden></ul></div></div>
  <div class="om-map" id="${pfx}-map"></div><p class="muted" style="font-size:12px;margin:-4px 0 12px">${T('tm.pinHint')}</p>`;
}
function pickerInit(pfx,lat,lng,city,actId){
 Object.assign(PP,{pfx,lat:lat==null?null:+lat,lng:lng==null?null:+lng,items:[],act:actId||null});
 const inp=$('#'+pfx+'-addr'), l=$('#'+pfx+'-ac');
 if(inp){inp.addEventListener('input',()=>{clearTimeout(PP.timer);const v=inp.value.trim();if(v.length<3){ppClose();return}PP.timer=setTimeout(()=>ppSearch(v),300)});
  inp.addEventListener('blur',()=>setTimeout(ppClose,200));
  inp.addEventListener('keydown',e=>{if(e.key==='Escape')ppClose()})}
 if(l){l.addEventListener('mousedown',e=>{if(!e.target.closest('a'))e.preventDefault()});l.addEventListener('click',e=>{const o=e.target.closest('[data-i]');if(o)ppPick(+o.dataset.i)})}
 setTimeout(()=>{
  const el=$('#'+pfx+'-map');if(!el||!window.L)return;if(PP.map){try{PP.map.remove()}catch(e){}}
  const c=PP.lat!=null?[PP.lat,PP.lng]:A().cityInfo(city||A().viewCity()).c;
  PP.map=L.map(el,{zoomControl:false});A().addTiles(PP.map);PP.map.setView(c,PP.lat!=null?15:12);
  PP.mk=L.marker(c,{draggable:true,icon:A().pinIcon(PP.act)}).addTo(PP.map);
  if(PP.lat==null)PP.mk.setOpacity(.55);
  PP.mk.on('dragend',()=>{const p=PP.mk.getLatLng();PP.lat=p.lat;PP.lng=p.lng;PP.mk.setOpacity(1)});
  PP.map.on('click',e=>{PP.mk.setLatLng(e.latlng);PP.lat=e.latlng.lat;PP.lng=e.latlng.lng;PP.mk.setOpacity(1)});
 },120);
}
function pickerDone(){if(PP.map){try{PP.map.remove()}catch(e){}}PP.map=null;PP.mk=null}
function ppClose(){const l=$('#'+PP.pfx+'-ac'),i=$('#'+PP.pfx+'-addr');if(l)l.hidden=true;if(i)i.setAttribute('aria-expanded','false')}
function ppMsg(m){const l=$('#'+PP.pfx+'-ac');if(!l)return;l.innerHTML=`<li class="ac-msg" role="presentation">${esc(m)}</li>`;l.hidden=false}
async function ppSearch(q){
 if(PP.ctrl)PP.ctrl.abort();const ctrl=new AbortController();PP.ctrl=ctrl;
 const c=PP.map?PP.map.getCenter():{lat:60.17,lng:24.94}, lang=A().photonLang();
 let feats=[];
 try{const r=await fetch('https://photon.komoot.io/api/?q='+encodeURIComponent(q)+'&limit=8&lat='+c.lat.toFixed(4)+'&lon='+c.lng.toFixed(4)+'&location_bias_scale=0.4'+(lang?'&lang='+lang:''),{signal:ctrl.signal});
  if(!r.ok)throw new Error('photon');const j=await r.json();feats=(j&&j.features)||[]}
 catch(e){if(e&&e.name==='AbortError')return;ppMsg(T('ac.failed'));return}
 const inp=$('#'+PP.pfx+'-addr');if(!inp||inp.value.trim()!==q)return;
 const seen=new Set();PP.items=[];
 for(const f of feats){const p=f.properties||{},g=f.geometry&&f.geometry.coordinates;if(!g)continue;
  const street=p.street?(p.street+(p.housenumber?' '+p.housenumber:'')):'';const main=String(p.name||street||'').trim();if(!main)continue;
  const city=p.city||p.locality||p.county||'';const sub=[p.name&&street&&street!==p.name?street:'',city&&city!==main?city:''].filter(Boolean).join(', ');
  const k=(main+'|'+sub).toLowerCase();if(seen.has(k))continue;seen.add(k);PP.items.push({main,sub,street,city,lat:+g[1],lng:+g[0]});if(PP.items.length>=6)break}
 if(!PP.items.length){ppMsg(T('ac.none'));return}
 const l=$('#'+PP.pfx+'-ac');l.innerHTML=PP.items.map((it,i)=>`<li role="option" class="ac-opt" data-i="${i}" id="${PP.pfx}-ac-${i}">${ic('pin')}<span><b>${esc(it.main)}</b>${it.sub?`<small>${esc(it.sub)}</small>`:''}</span></li>`).join('')+`<li class="ac-attr" role="presentation">${T('ac.attrib')} <a href="https://photon.komoot.io" target="_blank" rel="noopener">Photon</a> · © <a href="https://www.openstreetmap.org/copyright" target="_blank" rel="noopener">OpenStreetMap</a></li>`;
 l.hidden=false;inp.setAttribute('aria-expanded','true');
}
function ppPick(i){
 const it=PP.items[i];if(!it)return;const inp=$('#'+PP.pfx+'-addr'), nm=$('#'+PP.pfx+'-pname');
 const addr=[it.street&&it.street!==it.main?it.street:'',it.city].filter(Boolean).join(', ');
 if(nm&&!nm.value.trim()){nm.value=it.main.slice(0,60);if(inp)inp.value=(addr||it.main).slice(0,120)}
 else if(inp)inp.value=[it.main,addr].filter(Boolean).join(', ').slice(0,120);
 PP.lat=it.lat;PP.lng=it.lng;PP.cityHint=it.city;
 if(PP.map&&PP.mk){PP.mk.setLatLng([it.lat,it.lng]);PP.mk.setOpacity(1);PP.map.setView([it.lat,it.lng],16)}
 ppClose();
}

/* ---------------- team sheets ---------------- */
function sheet(html,ctx){A().openSheet(`<div class="om-sheet" id="${ctx}-sheet">${html}</div>`,ctx)}
function sheetBtns(okAttr,okLabel,extra){return `<div class="row" style="gap:10px;margin-top:6px">${extra||''}<button class="btn ghost" data-a="sheet-close" style="flex:1">${T('common.cancel')}</button><button class="btn primary" ${okAttr} style="flex:2">${okLabel}</button></div>`}
function val(id){const e=$('#'+id);return e?String(e.value||'').trim():''}
function placeSelect(tid,sel,pfx){const ps=D.places.filter(p=>p.team_id===tid);
 return `<label class="field"><span>${T('tm.f.place')}</span><select class="inp" id="${pfx}-place" data-o-change="place-sel"><option value="">${esc(T('tm.placeOther'))}</option>${ps.map(p=>`<option value="${p.id}" ${p.id===sel?'selected':''}>${esc(p.name)}</option>`).join('')}</select></label>
  <div id="${pfx}-free" ${sel?'hidden':''}><label class="field"><span>${T('tm.f.placeName')}</span><input class="inp" id="${pfx}-pname" maxlength="60"></label><label class="field"><span>${T('tm.f.address')}</span><input class="inp" id="${pfx}-paddr" maxlength="120"></label></div>`}
function kindSelect(pfx,sel){return `<label class="field"><span>${T('tm.f.kind')}</span><select class="inp" id="${pfx}-kind">${KINDS.map(k=>`<option value="${k}" ${k===sel?'selected':''}>${KIND_IC[k]} ${esc(T('tm.kind.'+k))}</option>`).join('')}</select></label>`}
function openEventSheet(tid,eid){
 const t=team(tid), e=eid?D.ev.find(x=>x.id===eid):null;if(!t||!isStaff(tid))return;
 const caps=members(tid).filter(m=>m.role!=='parent');
 sheet(`<h3>${e?'✏️ '+T('tm.editEvent'):'＋ '+T('tm.newEvent')}</h3>${e&&e.series_id?`<p class="sub">${T('tm.occurrenceHint')}</p>`:''}
  ${kindSelect('te',e?e.kind:'training')}
  <label class="field"><span>${T('tm.f.title')}</span><input class="inp" id="te-title" maxlength="60" value="${esc(e?e.title:T('tm.kind.training'))}"></label>
  <label class="field" id="te-opp-f"><span>${T('tm.f.opponent')}</span><input class="inp" id="te-opp" maxlength="60" value="${esc(e?e.opponent:'')}"></label>
  <div class="row" style="gap:10px"><label class="field" style="flex:1"><span>${T('tm.f.date')}</span><input class="inp" type="date" id="te-date" value="${e?e.event_date:todayYmd()}"></label><label class="field" style="flex:1"><span>${T('tm.f.time')}</span><input class="inp" type="time" id="te-time" value="${e?hm5(e.event_time):'18:00'}"></label></div>
  <label class="field"><span>${T('tm.f.duration')}</span><input class="inp" type="number" min="5" max="1440" step="5" id="te-dur" value="${e?e.duration_min:90}"></label>
  ${placeSelect(tid,e&&e.place_id,'te')}
  <label class="field"><span>${T('tm.f.captain')}</span><select class="inp" id="te-cap"><option value="">${esc(T('tm.noCaptain'))}</option>${caps.map(m=>`<option value="${m.id}" ${e&&e.captain_member===m.id?'selected':''}>${esc(memName(m))}</option>`).join('')}</select></label>
  <label class="field"><span>${T('tm.f.max')}</span><input class="inp" type="number" min="1" max="500" id="te-max" value="${e&&e.max_participants||''}" placeholder="${esc(T('tm.noLimit'))}"></label>
  <label class="field"><span>${T('tm.f.desc')}</span><textarea class="inp" id="te-desc" maxlength="400" rows="3">${esc(e?e.description:'')}</textarea></label>
  ${sheetBtns(`data-o="ev-save" data-id="${tid}" data-v="${e?e.id:''}" id="te-save"`,T('common.save'))}`,'tm-ev');
 if(e&&!e.place_id){$('#te-pname').value=e.place_name||'';$('#te-paddr').value=e.place_address||''}
 const syncKind=()=>{const f=$('#te-opp-f');if(f)f.hidden=$('#te-kind').value!=='game'};$('#te-kind').onchange=()=>{const ti=$('#te-title');const old=KINDS.map(k=>T('tm.kind.'+k));if(ti&&(!ti.value.trim()||old.includes(ti.value.trim())))ti.value=T('tm.kind.'+$('#te-kind').value);syncKind()};syncKind();
 $('#te-place').onchange=()=>{$('#te-free').hidden=!!$('#te-place').value};
}
async function saveEvent(tid,eid,el){
 const pid=val('te-place')||null, max=parseInt(val('te-max'),10);
 const row={kind:val('te-kind'),title:val('te-title'),opponent:val('te-kind')==='game'?val('te-opp'):'',event_date:val('te-date'),event_time:val('te-time')||null,
  duration_min:Math.min(1440,Math.max(5,parseInt(val('te-dur'),10)||90)),place_id:pid,place_name:pid?'':val('te-pname'),place_address:pid?'':val('te-paddr'),
  captain_member:val('te-cap')||null,max_participants:max>0?max:null,description:val('te-desc')};
 if(row.title.length<2){A().toast(T('tm.err.title'));$('#te-title').classList.add('err');return}
 if(!/^\d{4}-\d{2}-\d{2}$/.test(row.event_date)){A().toast(T('tm.err.date'));return}
 const sb=A().sb;
 try{await busyQ(eid?sb.from('team_events').update(row).eq('id',eid):sb.from('team_events').insert(Object.assign({team_id:tid},row)),el)}catch(e){A().toast(rpcErr(e),4000);return}
 A().closeSheet();A().toast(T('tm.saved'),2200);await reload();
}
function openSeriesSheet(tid,sid){
 const t=team(tid), s=sid?D.series.find(x=>x.id===sid):null;if(!t||!isStaff(tid))return;
 FORM={days:new Set(s?s.weekdays:[2,4])};
 sheet(`<h3>🔁 ${s?T('tm.editSeries'):T('tm.newSeries')}</h3><p class="sub">${T('tm.seriesHint')}</p>
  ${kindSelect('ts',s?s.kind:'training')}
  <label class="field"><span>${T('tm.f.title')}</span><input class="inp" id="ts-title" maxlength="60" value="${esc(s?s.title:T('tm.kind.training'))}"></label>
  <div class="field"><span>${T('tm.f.weekdays')}</span><div class="om-wd" id="ts-wd">${[1,2,3,4,5,6,7].map(d=>`<button type="button" class="${FORM.days.has(d)?'on':''}" data-o="wd" data-v="${d}" id="ts-wd-${d}" aria-pressed="${FORM.days.has(d)}">${esc(wdName(d))}</button>`).join('')}</div></div>
  <div class="row" style="gap:10px"><label class="field" style="flex:1"><span>${T('tm.f.time')}</span><input class="inp" type="time" id="ts-time" value="${s?hm5(s.start_time):'18:00'}"></label><label class="field" style="flex:1"><span>${T('tm.f.duration')}</span><input class="inp" type="number" min="5" max="1440" step="5" id="ts-dur" value="${s?s.duration_min:90}"></label></div>
  <div class="row" style="gap:10px"><label class="field" style="flex:1"><span>${T('tm.f.from')}</span><input class="inp" type="date" id="ts-from" value="${s?s.starts_on:todayYmd()}"></label><label class="field" style="flex:1"><span>${T('tm.f.until')}</span><input class="inp" type="date" id="ts-to" value="${s?s.ends_on:ymdOff(90)}"></label></div>
  ${placeSelect(tid,s&&s.place_id,'ts')}
  <label class="field"><span>${T('tm.f.desc')}</span><textarea class="inp" id="ts-desc" maxlength="400" rows="3">${esc(s?s.description:'')}</textarea></label>
  ${sheetBtns(`data-o="ser-save" data-id="${tid}" data-v="${s?s.id:''}" id="ts-save"`,T('common.save'))}`,'tm-ser');
 if(s&&!s.place_id){$('#ts-pname').value=s.place_name||'';$('#ts-paddr').value=s.place_address||''}
 $('#ts-place').onchange=()=>{$('#ts-free').hidden=!!$('#ts-place').value};
}
function toggleWd(el){const d=+el.dataset.v;if(!FORM)return;FORM.days.has(d)?FORM.days.delete(d):FORM.days.add(d);el.classList.toggle('on',FORM.days.has(d));el.setAttribute('aria-pressed',FORM.days.has(d))}
async function saveSeries(tid,sid,el,pfx,fn,extra){
 pfx=pfx||'ts';const days=[...(FORM?FORM.days:[])].sort();
 if(!days.length){A().toast(T('tm.err.weekdays'));return}
 if(val(pfx+'-to')<val(pfx+'-from')){A().toast(T('tm.err.range'));return}
 if(val(pfx+'-title').length<2){A().toast(T('tm.err.title'));$('#'+pfx+'-title').classList.add('err');return}
 const pid=val(pfx+'-place');
 const p=Object.assign({id:sid||null,kind:val(pfx+'-kind')||'training',title:val(pfx+'-title'),weekdays:days,start_time:val(pfx+'-time'),duration_min:parseInt(val(pfx+'-dur'),10)||90,
  starts_on:val(pfx+'-from'),ends_on:val(pfx+'-to'),place_id:pid||null,place_name:pid?'':val(pfx+'-pname'),place_address:pid?'':(val(pfx+'-paddr')||val(pfx+'-addr')),description:val(pfx+'-desc')},extra||{});
 if(tid&&!extra)p.team_id=tid;
 try{await rpc(fn||'save_team_series',{p},el)}catch(e){A().toast(rpcErr(e),4200);return}
 A().closeSheet();pickerDone();A().toast(T('tm.seriesSaved'),2400);await reload();
}
/* member edit */
function openMemberSheet(mid){
 const m=memById(mid);if(!m)return;const t=team(m.team_id), mgr=isMgr(t.id), owner=m.user_id&&m.user_id===t.owner_id;
 const kids=members(t.id).filter(x=>x.role==='member'&&x.id!==m.id), opts=titleOptions(t);
 sheet(`<h3>${esc(memName(m))}</h3><p class="sub">${esc(T('tm.role.'+m.role))}${m.user_id?'':' · '+esc(T('tm.noAccount'))}</p>
  ${!m.user_id?`<label class="field"><span>${T('tm.f.name')}</span><input class="inp" id="tmm-name" maxlength="40" value="${esc(m.display_name)}"></label>`:''}
  ${mgr&&m.user_id&&!owner?`<label class="field"><span>${T('tm.f.role')}</span><select class="inp" id="tmm-role">${['member','parent','coach','manager'].map(r=>`<option value="${r}" ${r===m.role?'selected':''}>${esc(T('tm.role.'+r))}</option>`).join('')}</select></label>`:''}
  ${mgr&&m.user_id?`<label class="field" id="tmm-link-f" ${m.role==='parent'?'':'hidden'}><span>${T('tm.f.child')}</span><select class="inp" id="tmm-link"><option value="">–</option>${kids.map(k=>`<option value="${k.id}" ${m.linked_member===k.id?'selected':''}>${esc(memName(k))}</option>`).join('')}</select></label>`:''}
  <label class="field"><span>${T('tm.f.titleRole')}</span><input class="inp" id="tmm-title" maxlength="40" list="tmm-titles" value="${esc(m.title)}" placeholder="${esc(T('tm.titlePh'))}"><datalist id="tmm-titles">${opts.map(o=>`<option value="${esc(o)}">`).join('')}</datalist></label>
  <div class="om-titles" id="tmm-chips">${opts.slice(0,12).map(o=>`<button type="button" data-o="title-pick" data-v="${esc(o)}">${esc(o)}</button>`).join('')}</div>
  ${m.role==='member'&&isStaff(t.id)?`<button class="btn ghost block" data-o="link-parent" data-id="${t.id}" data-v="${m.id}" id="tmm-parent-link" style="margin-top:12px">👪 ${T('tm.parentLink')}</button>`:''}
  ${sheetBtns(`data-o="mem-save" data-id="${m.id}" id="tmm-save"`,T('common.save'))}
  ${!owner&&(mgr||!m.user_id)&&m.user_id!==me()?`<button class="txt-btn danger-txt" data-o="mem-remove" data-id="${m.id}" id="tmm-remove" style="margin:14px auto 0;display:block">${T('tm.removeMember')}</button>`:''}`,'tm-mem');
 const r=$('#tmm-role');if(r)r.onchange=()=>{const f=$('#tmm-link-f');if(f)f.hidden=r.value!=='parent'};
}
async function saveMember(mid,el){
 const m=memById(mid);if(!m)return;const p={title:val('tmm-title')};
 if($('#tmm-name'))p.display_name=val('tmm-name');
 if($('#tmm-role'))p.role=val('tmm-role');
 if($('#tmm-link'))p.linked_member=(p.role||m.role)==='parent'?val('tmm-link'):'';
 try{await rpc('set_team_member',{p_member:mid,p},el)}catch(e){A().toast(rpcErr(e),4200);return}
 A().closeSheet();A().toast(T('tm.saved'),2200);await reload();
}
async function removeMember(mid,el,leaving){
 const m=memById(mid);if(!m)return;
 if(!confirm(leaving?T('tm.leaveConfirm'):T('tm.removeConfirm',{name:memName(m)})))return;
 try{await rpc('remove_team_member',{p_member:mid},el)}catch(e){A().toast(rpcErr(e),4200);return}
 A().closeSheet();A().toast(T(leaving?'tm.left':'tm.removed'),2400);
 if(leaving){await A().refreshData();A().goBack()}else await reload();
}
/* invites */
async function openFriendInvite(tid){
 const t=team(tid);if(!t||!isStaff(tid))return;const app=A();
 const fr=(window.MolaplanFriends&&window.MolaplanFriends.friendIds)?window.MolaplanFriends.friendIds():[];
 const inTeam=new Set(members(tid).map(m=>m.user_id).filter(Boolean)), invited=new Set(D.inv.filter(i=>i.team_id===tid).map(i=>i.invitee_id));
 const list=fr.filter(u=>u&&u!==me()&&!inTeam.has(u)).sort((a,b)=>app.nameOf(a).localeCompare(app.nameOf(b)));
 const roles=['member','parent'].concat(isMgr(tid)?['coach']:[]);
 sheet(`<h3>🤝 ${T('tm.inviteFriend')}</h3><p class="sub">${T('tm.inviteFriendSub')}</p>
  <label class="field"><span>${T('tm.f.inviteAs')}</span><select class="inp" id="tmi-role">${roles.map(r=>`<option value="${r}">${esc(T('tm.role.'+r))}</option>`).join('')}</select></label>
  ${list.length?`<div class="gi-list" id="tmi-list">${list.map(u=>`<div class="grp-mem" id="tmi-${u}">${app.avatar(u,'sm')}<b class="grow">${esc(app.nameOf(u))}</b>${invited.has(u)?`<span class="muted">✓ ${T('tm.invited')}</span>`:`<button class="btn ghost sm" data-o="inv-send" data-id="${tid}" data-v="${u}" id="tmi-send-${u}">${T('tm.invite')}</button>`}</div>`).join('')}</div>`:`<p class="muted" id="tmi-none">${T('tm.noFriends')}</p>`}
  <button class="btn ghost block" data-a="sheet-close" style="margin-top:12px">${T('common.close')}</button>`,'tm-inv');
}
async function sendInvite(tid,uid,el){
 try{await rpc('invite_to_team',{p_team:tid,p_user:uid,p_role:val('tmi-role')||'member'},el)}catch(e){A().toast(rpcErr(e),4000);return}
 D.inv.push({team_id:tid,invitee_id:uid,inviter_id:me(),role:val('tmi-role')||'member',created_at:new Date().toISOString()});
 const row=$('#tmi-'+uid);if(row){const b=row.querySelector('button');if(b)b.outerHTML=`<span class="muted">✓ ${T('tm.invited')}</span>`}
 A().toast(T('tm.inviteSent'),2200);
}
function openLinkSheet(tid){
 const roles=['member','parent'].concat(isMgr(tid)?['coach']:[]);
 sheet(`<h3>🔗 ${T('tm.newLink')}</h3><p class="sub">${T('tm.linkSub')}</p>
  <label class="field"><span>${T('tm.f.inviteAs')}</span><select class="inp" id="tml-role">${roles.map(r=>`<option value="${r}">${esc(T('tm.role.'+r))}</option>`).join('')}</select></label>
  ${sheetBtns(`data-o="link-create" data-id="${tid}" id="tml-create"`,T('tm.createLink'))}`,'tm-link');
}
async function createLink(tid,role,forMember,el){
 let tok;try{tok=await rpc('create_team_invite_link',{p_team:tid,p_role:role,p_for:forMember||null},el)}catch(e){A().toast(rpcErr(e),4200);return}
 A().closeSheet();await reload();shareLink('t',tok);
}
function linkUrl(k,tok){return location.origin+'/'+k+'/'+tok}
async function shareLink(k,tok){
 const url=linkUrl(k,tok);
 sheet(`<h3>🔗 ${T('tm.linkReady')}</h3><p class="sub">${T(k==='b'?'bm.linkReadySub':'tm.linkReadySub')}</p>
  <input class="inp" id="org-link-url" readonly value="${esc(url)}" onclick="this.select()">
  <div class="row" style="gap:10px;margin-top:12px"><button class="btn ghost" data-o="link-copy" data-v="${esc(url)}" id="org-link-copy" style="flex:1">📋 ${T('tm.copy')}</button>${navigator.share?`<button class="btn primary" data-o="link-native" data-v="${esc(url)}" id="org-link-native" style="flex:1">${ic('share')} ${T('tm.share')}</button>`:''}</div>
  <button class="btn ghost block" data-a="sheet-close" style="margin-top:10px">${T('common.close')}</button>`,'org-link');
}
async function copyText(s){try{await navigator.clipboard.writeText(s);A().toast(T('tm.copied'),1800)}catch(e){const i=$('#org-link-url');if(i){i.select();try{document.execCommand('copy');A().toast(T('tm.copied'),1800)}catch(x){}}}}
async function revokeLink(k,tok,el){
 if(!confirm(T('tm.revokeConfirm')))return;
 try{await rpc(k==='b'?'revoke_business_invite_link':'revoke_team_invite_link',{p_token:tok},el)}catch(e){A().toast(rpcErr(e),4000);return}
 A().toast(T('tm.revoked'),2000);await reload();
}
function openRosterSheet(tid){
 const t=team(tid),opts=titleOptions(t);
 sheet(`<h3>＋ ${T('tm.addRoster')}</h3><p class="sub">${T('tm.rosterSub')}</p>
  <label class="field"><span>${T('tm.f.name')}</span><input class="inp" id="tmr-name" maxlength="40"></label>
  <label class="field"><span>${T('tm.f.titleRole')}</span><input class="inp" id="tmr-title" maxlength="40" list="tmr-titles" placeholder="${esc(T('tm.titlePh'))}"><datalist id="tmr-titles">${opts.map(o=>`<option value="${esc(o)}">`).join('')}</datalist></label>
  ${sheetBtns(`data-o="roster-save" data-id="${tid}" id="tmr-save"`,T('tm.add'))}`,'tm-roster');
}
async function saveRoster(tid,el){
 const n=val('tmr-name');if(n.length<2){A().toast(T('tm.err.name'));return}
 try{await rpc('add_team_roster_member',{p_team:tid,p_name:n,p_title:val('tmr-title')},el)}catch(e){A().toast(rpcErr(e),4000);return}
 A().closeSheet();A().toast(T('tm.saved'),2000);await reload();
}
/* places + docs */
function openPlaceSheet(tid,pid){
 const t=team(tid),p=pid?D.places.find(x=>x.id===pid):null;
 sheet(`<h3>📍 ${p?T('tm.editPlace'):T('tm.addPlace')}</h3>${pickerHTML('tp',p&&p.name,p&&p.address,true)}
  <label class="field"><span>${T('tm.f.notes')}</span><input class="inp" id="tp-notes" maxlength="200" value="${esc(p?p.notes:'')}" placeholder="${esc(T('tm.notesPh'))}"></label>
  ${sheetBtns(`data-o="pl-save" data-id="${tid}" data-v="${p?p.id:''}" id="tp-save"`,T('common.save'))}`,'tm-place');
 pickerInit('tp',p&&p.lat,p&&p.lng,t.city,t.activity_id);
}
async function savePlace(tid,pid,el){
 const row={name:val('tp-pname'),address:val('tp-addr'),notes:val('tp-notes'),lat:PP.lat,lng:PP.lng};
 if(row.name.length<2){A().toast(T('tm.err.name'));$('#tp-pname').classList.add('err');return}
 const sb=A().sb;
 try{await busyQ(pid?sb.from('team_places').update(row).eq('id',pid):sb.from('team_places').insert(Object.assign({team_id:tid,sort_order:D.places.filter(p=>p.team_id===tid).length},row)),el)}catch(e){A().toast(rpcErr(e),4000);return}
 A().closeSheet();pickerDone();A().toast(T('tm.saved'),2000);await reload();
}
function openDocSheet(tid,kind,did){
 const d=did?D.docs.find(x=>x.id===did):null;kind=d?d.kind:kind;
 sheet(`<h3>${DOC_IC[kind]} ${T('tm.doc.'+kind)}</h3>
  <label class="field"><span>${T('tm.f.title')}</span><input class="inp" id="td-title" maxlength="80" value="${esc(d?d.title:'')}"></label>
  <label class="field"><span>${T('tm.f.body')}</span><textarea class="inp" id="td-body" maxlength="8000" rows="8">${esc(d?d.body:'')}</textarea></label>
  <label class="row" style="gap:8px;align-items:center;margin:4px 0 12px;font-size:14px"><input type="checkbox" id="td-staff" ${d&&d.staff_only?'checked':''}> 🔒 ${T('tm.staffOnlyHint')}</label>
  ${sheetBtns(`data-o="doc-save" data-id="${tid}" data-v="${d?d.id:kind}" id="td-save"`,T('common.save'))}`,'tm-doc');
}
async function saveDoc(tid,v,el){
 const did=DOC_KINDS.includes(v)?null:v, row={title:val('td-title'),body:val('td-body'),staff_only:!!($('#td-staff')||{}).checked};
 if(!row.title){A().toast(T('tm.err.title'));return}
 const sb=A().sb;
 try{await busyQ(did?sb.from('team_docs').update(row).eq('id',did):sb.from('team_docs').insert(Object.assign({team_id:tid,kind:v,sort_order:D.docs.filter(d=>d.team_id===tid&&d.kind===v).length},row)),el)}catch(e){A().toast(rpcErr(e),4000);return}
 A().closeSheet();A().toast(T('tm.saved'),2000);await reload();
}
async function delRow(table,id,el,confirmKey){
 if(!confirm(T(confirmKey||'tm.deleteConfirm')))return;
 try{await busyQ(A().sb.from(table).delete().eq('id',id),el)}catch(e){A().toast(rpcErr(e),4000);return}
 A().toast(T('tm.deleted'),2000);await reload();
}
async function reload(){await load();rerender()}
function rerender(){if($('#s-tm')&&$('#s-tm').classList.contains('active'))renderTeam(true);if($('#s-bm')&&$('#s-bm').classList.contains('active'))renderBiz(true)}

/* ---------------- business screen #s-bm ---------------- */
function bizEvents(bid){const t=todayYmd();return (A().state.meetups||[]).filter(m=>m.bizId===bid&&(m.ends||m.date)>=t).sort((a,b)=>(a.date+a.time).localeCompare(b.date+b.time))}
function renderBiz(keepScroll){
 const s=$('#s-bm');if(!s)return;const st=s.scrollTop, b=bizById(BM.id), role=b&&bizRole(b.id);
 if(!b||!role||b.status!=='approved'){s.innerHTML=head(T('bm.kind'))+`<div class="cards"><div class="empty" id="bm-missing"><div class="e">🔍</div><h3>${T('bm.notFound')}</h3><p>${T('bm.notFoundBody')}</p></div></div>`;return}
 const active=bizActive(b), owner=role==='owner';
 let h=head(T('bm.kind'))+`<div class="om-hero" style="--h:${A().hashHue(b.name)}" id="bm-hero"><div class="e">🏢</div><h1 id="bm-name">${esc(b.name)}</h1><div class="bd"><span id="bm-myrole">${esc(T('bm.role.'+role))}</span><span id="bm-sub">${active?'✅ '+esc(T('bm.activeUntil',{date:A().fmtYmd(b.until)})):'⛔ '+esc(T('bm.expired'))}</span></div></div>`;
 if(!active)h+=`<div class="om-ro" id="bm-readonly">🔒 ${T('bm.readOnly')}</div>`;
 const segs=[['events','📅 '+T('bm.seg.events')],['series','🔁 '+T('bm.seg.series')],['team','👥 '+T('bm.seg.team')]];
 if(!segs.some(x=>x[0]===BM.seg))BM.seg='events';
 h+=`<div class="om-seg" id="bm-seg">${segs.map(([k,l])=>`<button class="${BM.seg===k?'on':''}" data-o="bm-seg" data-v="${k}" id="bm-seg-${k}">${l}</button>`).join('')}</div>`;
 if(BM.seg==='events'){
  const ev=bizEvents(b.id);
  h+=`<div class="card-box" id="bm-events">${active?`<button class="btn primary block" data-o="bm-new-ev" data-id="${b.id}" id="bm-new-ev" style="margin-bottom:12px">＋ ${T('bm.newEvent')}</button>`:''}
   ${ev.length?ev.map(m=>{const a=A().act(m.act);return `<div class="om-place" id="bm-ev-${m.id}"><span style="font-size:22px">${a.emoji}</span><div class="m"><b>${esc(m.title)}</b><small>🗓️ ${esc(fmtDay(m.date))} ${esc(A().fmtTime(m.time))} · 📍 ${esc(m.place)}${m.city?', '+esc(A().cityLabel(m.city)):''}</small>
    <small>${m.price?'💶 '+esc(m.price)+' · ':''}👥 ${m.people.length}${m.unlimited?'':'/'+m.max}${m.series?` · <span class="om-tag">🔁 ${T('tm.recurring')}</span>`:''}</small>
    <div class="om-acts"><button class="btn ghost sm" data-o="bm-open-ev" data-id="${m.id}" id="bm-open-ev-${m.id}">${T('bm.view')}</button>${active?`<button class="btn ghost sm" data-o="bm-edit-ev" data-id="${m.id}" id="bm-edit-ev-${m.id}">✏️ ${T('common.edit')}</button><button class="btn ghost sm" data-o="bm-del-ev" data-id="${m.id}" id="bm-del-ev-${m.id}" aria-label="${T('common.delete')}">🗑️</button>`:''}</div></div></div>`}).join('')
   :`<p class="muted" id="bm-no-events" style="margin:0;font-size:13.5px">${T('bm.noEvents')}</p>`}</div>`;
 }else if(BM.seg==='series'){
  const ser=D.bser.filter(x=>x.business_id===b.id);
  h+=`<div class="card-box" id="bm-series"><p class="muted" style="margin:0 0 10px;font-size:13px">${T('bm.seriesHint')}</p>${active?`<button class="btn primary block" data-o="bm-ser-new" data-id="${b.id}" id="bm-ser-new" style="margin-bottom:12px">🔁 ${T('bm.newSeries')}</button>`:''}
   ${ser.length?ser.map(x=>{const a=A().act(x.activity_id);return `<div class="om-place" id="bm-ser-${x.id}"><span style="font-size:22px">${a.emoji}</span><div class="m"><b>${esc(x.title)}</b><small>${esc(x.weekdays.map(wdName).join(', '))} ${esc(hm5(x.start_time))}${x.duration_min?'–'+esc(addMin(x.start_time,x.duration_min)):''} · 📍 ${esc(x.place)}</small><small>${esc(T('tm.seriesRange',{from:A().fmtYmd(x.starts_on),to:A().fmtYmd(x.ends_on)}))}${x.price_info?' · 💶 '+esc(x.price_info):''}</small></div>
    ${active?`<span class="om-row-btns"><button class="btn ghost sm" data-o="bm-ser-edit" data-id="${x.id}" id="bm-ser-edit-${x.id}">✏️</button><button class="btn ghost sm" data-o="bm-ser-del" data-id="${x.id}" id="bm-ser-del-${x.id}">🗑️</button></span>`:''}</div>`}).join('')
   :`<p class="muted" id="bm-no-series" style="margin:0;font-size:13.5px">${T('bm.noSeries')}</p>`}</div>`;
 }else{
  const ms=D.bmem.filter(m=>m.business_id===b.id).sort((x,y)=>(x.role==='owner'?0:1)-(y.role==='owner'?0:1));
  const links=D.blinks.filter(l=>l.business_id===b.id&&!l.revoked&&Date.parse(l.expires_at)>Date.now()&&l.uses<l.max_uses);
  h+=`<div class="card-box" id="bm-members"><h3>👥 ${T('bm.organisers')}</h3><p class="muted" style="margin:0 0 8px;font-size:13px">${T('bm.organisersHint')}</p>${ms.map(m=>`<div class="grp-mem" id="bm-mem-${m.user_id}">${A().avatar(m.user_id,'sm')}<b class="grow">${esc(m.user_id===me()?A().myName()+' '+T('common.youParen'):A().nameOf(m.user_id))}</b><span class="role-badge ${m.role==='owner'?'founder':''}">${esc(T('bm.role.'+m.role))}</span>${owner&&m.role!=='owner'?`<button class="txt-btn danger-txt" data-o="bm-remove" data-id="${b.id}" data-v="${m.user_id}" id="bm-remove-${m.user_id}">${T('tm.remove')}</button>`:''}</div>`).join('')}</div>`;
  if(owner)h+=`<div class="card-box" id="bm-invite"><h3>🔗 ${T('bm.inviteTitle')}</h3><p class="muted" style="margin:0 0 10px;font-size:13px">${T('bm.inviteHint')}</p>${active?`<button class="btn primary block" data-o="bm-link-new" data-id="${b.id}" id="bm-link-new">＋ ${T('tm.newLink')}</button>`:''}
   ${links.map(l=>`<div class="om-link" id="bm-link-${l.token}"><div class="m"><b>${esc(T('bm.linkFor'))}</b><small class="muted" style="display:block">${esc(T('tm.linkMeta',{uses:l.uses,max:l.max_uses,date:A().fmtYmd(String(l.expires_at).slice(0,10))}))}</small></div><button class="btn ghost sm" data-o="link-share" data-v="b" data-id="${l.token}" id="bm-link-share-${l.token}">${ic('share')}</button><button class="txt-btn danger-txt" data-o="link-revoke" data-v="b" data-id="${l.token}" id="bm-link-revoke-${l.token}">${T('tm.revoke')}</button></div>`).join('')}</div>`;
  else h+=`<div class="grp-foot"><button class="btn ghost block" data-o="bm-leave" data-id="${b.id}" id="bm-leave">${T('bm.leave')}</button></div>`;
 }
 s.innerHTML=h+`<div style="height:28px"></div>`;if(keepScroll)s.scrollTop=st;
}
function localTz(){try{return Intl.DateTimeFormat().resolvedOptions().timeZone||'Europe/Helsinki'}catch(e){return 'Europe/Helsinki'}}
const LEVELS_B=['all','beginner','intermediate','advanced'];
function openBizSeriesSheet(bid,sid){
 const b=bizById(bid), s=sid?D.bser.find(x=>x.id===sid):null;if(!b||!bizActive(b))return;
 FORM={days:new Set(s?s.weekdays:[1,3])};
 const city=s?s.city:A().viewCity();
 sheet(`<h3>🔁 ${s?T('bm.editSeries'):T('bm.newSeries')}</h3><p class="sub">${T('bm.seriesSub')}</p>
  <label class="field"><span>${T('bm.f.activity')}</span><select class="inp" id="bs-act">${A().orderedActs().filter(a=>!a.crazy&&!a.adult).map(a=>`<option value="${esc(a.id)}" ${s&&s.activity_id===a.id?'selected':''}>${a.emoji} ${esc(a.name)}</option>`).join('')}</select></label>
  <label class="field"><span>${T('tm.f.title')}</span><input class="inp" id="bs-title" maxlength="60" value="${esc(s?s.title:'')}"></label>
  <label class="field"><span>${T('tm.f.desc')}</span><textarea class="inp" id="bs-desc" maxlength="2000" rows="3">${esc(s?s.description:'')}</textarea></label>
  <div class="field"><span>${T('tm.f.weekdays')}</span><div class="om-wd" id="bs-wd">${[1,2,3,4,5,6,7].map(d=>`<button type="button" class="${FORM.days.has(d)?'on':''}" data-o="wd" data-v="${d}" id="bs-wd-${d}" aria-pressed="${FORM.days.has(d)}">${esc(wdName(d))}</button>`).join('')}</div></div>
  <div class="row" style="gap:10px"><label class="field" style="flex:1"><span>${T('tm.f.time')}</span><input class="inp" type="time" id="bs-time" value="${s?hm5(s.start_time):'18:00'}"></label><label class="field" style="flex:1"><span>${T('tm.f.duration')}</span><input class="inp" type="number" min="5" max="1440" step="5" id="bs-dur" value="${s&&s.duration_min||60}"></label></div>
  <div class="row" style="gap:10px"><label class="field" style="flex:1"><span>${T('tm.f.from')}</span><input class="inp" type="date" id="bs-from" value="${s?s.starts_on:todayYmd()}"></label><label class="field" style="flex:1"><span>${T('tm.f.until')}</span><input class="inp" type="date" id="bs-to" value="${s?s.ends_on:ymdOff(56)}"></label></div>
  <label class="field"><span>${T('bm.f.city')}</span><input class="inp" id="bs-city" maxlength="40" list="bs-cities" value="${esc(s?s.city:city)}"><datalist id="bs-cities">${Object.keys(A().cities).map(c=>`<option value="${esc(c)}">`).join('')}</datalist></label>
  ${pickerHTML('bs',s&&s.place,s&&s.place,true)}
  <div class="row" style="gap:10px"><label class="field" style="flex:1"><span>${T('bm.f.price')}</span><input class="inp" id="bs-price" maxlength="120" value="${esc(s?s.price_info:'')}" placeholder="${esc(T('bm.pricePh'))}"></label><label class="field" style="flex:1"><span>${T('bm.f.max')}</span><input class="inp" type="number" min="2" max="100000" id="bs-max" value="${s&&s.max_participants||''}" placeholder="${esc(T('tm.noLimit'))}"></label></div>
  <label class="field"><span>${T('bm.f.level')}</span><select class="inp" id="bs-level">${LEVELS_B.map(l=>`<option value="${l}" ${(s?s.skill_level:'all')===l?'selected':''}>${esc(A().levelName(l))}</option>`).join('')}</select></label>
  <label class="field"><span>${T('bm.f.url')}</span><input class="inp" id="bs-url" maxlength="300" type="url" value="${esc(s?s.official_url:'')}" placeholder="https://"></label>
  <label class="field"><span>${T('pub.extraInfo')}</span><textarea class="inp" id="bs-extra" maxlength="1000" rows="3" placeholder="${esc(T('pub.extraPh'))}">${esc(s?s.extra_info:'')}</textarea></label>
  ${sheetBtns(`data-o="bm-ser-save" data-id="${bid}" data-v="${s?s.id:''}" id="bs-save"`,T('common.save'))}`,'bm-ser');
 const nm=$('#bs-pname'), ad=$('#bs-addr');if(s&&nm&&ad){nm.value=s.place;ad.value=''}
 pickerInit('bs',s&&s.lat,s&&s.lng,city,s&&s.activity_id);
}
async function saveBizSeries(bid,sid,el){
 const days=[...(FORM?FORM.days:[])].sort();if(!days.length){A().toast(T('tm.err.weekdays'));return}
 const title=val('bs-title'), place=[val('bs-pname'),val('bs-addr')].filter(Boolean).join(', ').slice(0,70), url=val('bs-url');
 if(title.length<3){A().toast(T('bm.err.title'));$('#bs-title').classList.add('err');return}
 if(place.length<2){A().toast(T('bm.err.place'));return}
 if(url&&!A().safeHttps(url)){A().toast(T('bm.err.url'));return}
 if(val('bs-to')<val('bs-from')){A().toast(T('tm.err.range'));return}
 const city=A().knownCity(val('bs-city'))||val('bs-city');if(!city){A().toast(T('bm.err.city'));return}
 const max=parseInt(val('bs-max'),10);
 const p={id:sid||null,business_id:bid,activity_id:val('bs-act'),title,description:val('bs-desc'),city,place,lat:PP.lat,lng:PP.lng,weekdays:days,
  start_time:val('bs-time'),duration_min:parseInt(val('bs-dur'),10)||null,starts_on:val('bs-from'),ends_on:val('bs-to'),tz:localTz(),
  price_info:val('bs-price'),official_url:url,extra_info:val('bs-extra'),max_participants:max>1?max:null,skill_level:val('bs-level')||'all'};
 try{await rpc('save_business_series',{p},el)}catch(e){A().toast(rpcErr(e),4200);return}
 A().closeSheet();pickerDone();A().toast(T('tm.seriesSaved'),2400);await A().refreshData();await reload();
}
async function delBizSeries(id,el){
 if(!confirm(T('bm.seriesDelConfirm')))return;
 try{await rpc('delete_business_series',{p_id:id},el)}catch(e){A().toast(rpcErr(e),4000);return}
 A().toast(T('tm.deleted'),2000);await A().refreshData();await reload();
}
async function bizRemove(bid,uid,el,leaving){
 if(!confirm(leaving?T('bm.leaveConfirm'):T('bm.removeConfirm',{name:A().nameOf(uid)})))return;
 try{await rpc('remove_business_member',{p_business:bid,p_user:uid},el)}catch(e){A().toast(rpcErr(e),4000);return}
 A().toast(T(leaving?'bm.left':'tm.removed'),2200);await A().refreshData();if(leaving)A().goBack();else await reload();
}

/* ---------------- actions ---------------- */
async function rsvp(eid,mid,v,el){
 try{await rpc('team_rsvp',{p_event:eid,p_member:mid,p_status:v||null},el)}catch(e){A().toast(rpcErr(e),4000);return}
 D.rsvp=D.rsvp.filter(r=>!(r.event_id===eid&&r.member_id===mid));
 if(v)D.rsvp.push({event_id:eid,member_id:mid,user_id:(memById(mid)||{}).user_id||null,status:v,responded_by:me(),updated_at:new Date().toISOString()});
 renderTeam(true);
}
async function cancelEvent(eid,on,el){
 if(on&&!confirm(T('tm.cancelConfirm')))return;
 try{await busyQ(A().sb.from('team_events').update({cancelled:on}).eq('id',eid),el)}catch(e){A().toast(rpcErr(e),4000);return}
 A().toast(T(on?'tm.cancelledToast':'tm.restored'),2200);await reload();
}
async function respondInvite(tid,yes,el){
 try{await rpc('respond_team_invite',{p_team:tid,p_accept:yes},el)}catch(e){A().toast(rpcErr(e),4000);return}
 A().toast(T(yes?'tm.joined':'tm.declined'),2400);await A().refreshData();
 if(yes)renderTeam(false);else A().goBack();
}
async function saveTeam(tid,el){
 const p={name:val('tm-s-name'),activity_id:val('tm-s-act'),city:val('tm-s-city'),description:val('tm-s-desc')};
 const a=p.activity_id&&A().act(p.activity_id);if(a)p.sport=a.name;
 if(p.name.length<2){A().toast(T('tm.err.name'));return}
 try{await rpc('update_team',{p_id:tid,p},el)}catch(e){A().toast(rpcErr(e),4000);return}
 A().toast(T('tm.saved'),2000);await reload();
}
async function deleteTeam(tid,el){
 const t=team(tid);if(!t||!confirm(T('tm.deleteConfirm2',{name:t.name})))return;
 try{await busyQ(A().sb.from('teams').delete().eq('id',tid),el)}catch(e){A().toast(rpcErr(e),4000);return}
 A().toast(T('tm.teamDeleted'),2400);await A().refreshData();A().goBack();
}
async function addTitle(tid,el){
 const n=val('tm-title-in').replace(/\s+/g,' ');if(!n)return;
 try{await busyQ(A().sb.from('team_roles').insert({team_id:tid,name:n.slice(0,30),sort_order:D.roles.filter(r=>r.team_id===tid).length}),el)}catch(e){A().toast(rpcErr(e),4000);return}
 await reload();
}
async function bizLink(bid,el){
 let tok;try{tok=await rpc('create_business_invite_link',{p_business:bid},el)}catch(e){A().toast(rpcErr(e),4200);return}
 await reload();shareLink('b',tok);
}
function onClick(ev){
 const el=ev.target.closest('[data-o]');if(!el)return;
 const o=el.dataset.o, id=el.dataset.id, v=el.dataset.v;
 if(el.tagName==='SELECT')return;
 ev.preventDefault();
 switch(o){
  case 'open-team':openTeam(id);break;
  case 'open-bm':openBizManage(id);break;
  case 'join-link':joinLink(v,id,el);break;
  case 'tm-seg':TM.seg=v;renderTeam(false);break;
  case 'tm-past':TM.showPast=!TM.showPast;renderTeam(true);break;
  case 'ev-toggle':TM.openEv=TM.openEv===id?null:id;renderTeam(true);break;
  case 'rsvp':rsvp(id,el.dataset.m,v,el);break;
  case 'ev-new':openEventSheet(id,null);break;
  case 'ev-edit':{const e=D.ev.find(x=>x.id===id);if(e)openEventSheet(e.team_id,id);break}
  case 'ev-save':saveEvent(id,v||null,el);break;
  case 'ev-cancel':cancelEvent(id,v==='1',el);break;
  case 'ev-del':delRow('team_events',id,el,'tm.eventDelConfirm');break;
  case 'ser-new':openSeriesSheet(id,null);break;
  case 'ser-edit':{const s=D.series.find(x=>x.id===id);if(s)openSeriesSheet(s.team_id,id);break}
  case 'ser-save':saveSeries(id,v||null,el);break;
  case 'ser-del':if(confirm(T('tm.seriesDelConfirm')))rpc('delete_team_series',{p_id:id},el).then(()=>{A().toast(T('tm.deleted'),2000);return reload()},e=>A().toast(rpcErr(e),4000));break;
  case 'wd':toggleWd(el);break;
  case 'mem-edit':openMemberSheet(id);break;
  case 'mem-save':saveMember(id,el);break;
  case 'mem-remove':removeMember(id,el,false);break;
  case 'title-pick':{const i=$('#tmm-title');if(i)i.value=v;break}
  case 'title-add':addTitle(id,el);break;
  case 'title-del':delRow('team_roles',id,el,'tm.titleDelConfirm');break;
  case 'tm-leave':{const m=myMem(id);if(m)removeMember(m.id,el,true);break}
  case 'inv-friends':openFriendInvite(id);break;
  case 'inv-send':sendInvite(id,v,el);break;
  case 'inv-accept':respondInvite(id,true,el);break;
  case 'inv-decline':respondInvite(id,false,el);break;
  case 'link-new':openLinkSheet(id);break;
  case 'link-create':createLink(id,val('tml-role')||'member',null,el);break;
  case 'link-parent':createLink(id,'parent',v,el);break;
  case 'link-share':shareLink(v,id);break;
  case 'link-copy':copyText(v);break;
  case 'link-native':navigator.share({url:v,title:'Molaplan'}).catch(()=>{});break;
  case 'link-revoke':revokeLink(v,id,el);break;
  case 'roster-new':openRosterSheet(id);break;
  case 'roster-save':saveRoster(id,el);break;
  case 'pl-new':openPlaceSheet(id,null);break;
  case 'pl-edit':{const p=D.places.find(x=>x.id===id);if(p)openPlaceSheet(p.team_id,id);break}
  case 'pl-save':savePlace(id,v||null,el);break;
  case 'pl-del':delRow('team_places',id,el,'tm.placeDelConfirm');break;
  case 'doc-new':openDocSheet(id,v,null);break;
  case 'doc-edit':{const d=D.docs.find(x=>x.id===id);if(d)openDocSheet(d.team_id,d.kind,id);break}
  case 'doc-save':saveDoc(id,v,el);break;
  case 'doc-del':delRow('team_docs',id,el,'tm.docDelConfirm');break;
  case 'tm-save':saveTeam(id,el);break;
  case 'tm-delete':deleteTeam(id,el);break;
  case 'bm-seg':BM.seg=v;renderBiz(false);break;
  case 'bm-new-ev':A().startBizCreate(id);break;
  case 'bm-open-ev':A().openDetail(id);break;
  case 'bm-edit-ev':A().editEvent(id);break;
  case 'bm-del-ev':A().delMeetup(id,el);break;
  case 'bm-ser-new':openBizSeriesSheet(id,null);break;
  case 'bm-ser-edit':{const s=D.bser.find(x=>x.id===id);if(s)openBizSeriesSheet(s.business_id,id);break}
  case 'bm-ser-save':saveBizSeries(id,v||null,el);break;
  case 'bm-ser-del':delBizSeries(id,el);break;
  case 'bm-link-new':bizLink(id,el);break;
  case 'bm-remove':bizRemove(id,v,el,false);break;
  case 'bm-leave':bizRemove(id,me(),el,true);break;
 }
}
function show(screen,param){
 css();
 if(screen==='s-tm'){if(TM.id!==param){TM.seg='sched';TM.showPast=false;TM.openEv=null}TM.id=param;renderTeam(false)}
 else if(screen==='s-bm'){if(BM.id!==param)BM.seg='events';BM.id=param;renderBiz(false)}
}
function leave(){if(pMap){try{pMap.remove()}catch(e){}pMap=null}}
document.addEventListener('click',onClick);
css();
window.MolaplanOrgs={load,chatObj,chatList,openTeam,openBizManage,show,leave,rerender,reqRowAction,bizRowAction,profileTeamsHTML,notifGo,openLink,teamForRequest,
 get data(){return D},isStaff,myRole,bizActive};
/* the app may have finished its first load before this file arrived */
{const app=A();if(app&&app.me&&app.state&&app.state.loaded&&!app.guest)load().then(()=>{app.refreshViews();openLink()}).catch(e=>console.warn('Molaplan teams: load failed',e))}
})();
