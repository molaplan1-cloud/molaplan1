/* Molaplan – in-memory Supabase mock for automated UI tests ONLY.
   index.html loads this file only when the URL has ?mock=1 AND the page runs on
   localhost / 127.0.0.1. It is NOT part of the deployed site (not copied to molaplan-deploy).
   It emulates the parts of schema.sql the UI relies on (triggers, RLS visibility, realtime). */
(function(){
'use strict';
const DB_KEY='molaplan.mock.db', SES_KEY='molaplan.mock.session';
const CONFIRM=new URLSearchParams(location.search).get('confirm')==='1';
const uuid=()=>(crypto.randomUUID?crypto.randomUUID():'xxxxxxxx-xxxx-4xxx-8xxx-xxxxxxxxxxxx'.replace(/x/g,()=>(Math.random()*16|0).toString(16)));
let lastTs=0;const now=()=>{let t=Date.now();if(t<=lastTs)t=lastTs+1;lastTs=t;return new Date(t).toISOString()};
const ADULT=/naku|alasti|alaston|konjak|viini|olut|oluen|kalja|bisse|shamp|kuohu|cocktail|drinkk|viski|siideri|lonkero|känn|kossu|vodka|rommi|punssi|pubi|baari|wine|beer|naked|nude|nudis|whisk|brandy|cognac|cerveza|desnud|sangr[ií]a|tequila|naken|nakna|nakenbad|(^|[^a-z])vino/i;
const SEED=[['padel','Padel','🏓',155],['sulkapallo','Sulkapallo','🏸',190],['tennis','Tennis','🎾',75],['juoksu','Juoksu','🏃',12],['kavely','Kävely','🚶',100],['vaellus','Vaellus','🥾',125],['pyoraily','Pyöräily','🚴',30],['kuntosali','Kuntosali','🏋️',350],['jooga','Jooga','🧘',280],['uinti','Uinti','🏊',205],['frisbeegolf','Frisbeegolf','🥏',45],['jalkapallo','Jalkapallo','⚽',140],['salibandy','Salibandy','🏑',222],['lautapelit','Lautapelit','🎲',258],['kahvi','Kahvi & juttelu','☕',24],['valokuvaus','Valokuvaus','📷',300],['kalastus','Kalastus','🎣',195],['neulonta','Neulonta','🧶',330],['kieltenvaihto','Kieltenvaihto','🗣️',170],['konsertit','Konsertit','🎵',312],['festivaali','Festivaalit','🎪',330],['markkinat','Markkinat','🛍️',36],['juoksutapahtuma','Juoksutapahtumat','🏅',8],['kulttuuri','Kulttuuri','🎭',275]].map((a,i)=>({id:a[0],name:a[1],emoji:a[2],hue:a[3],is_crazy:false,crazy_level:0,is_adult:false,is_custom:false,sort_order:10+i*10,created_by:null}))
 .concat([['nakuuinti','Nakuuinti','🌊',200,3,true],['pelle','Pellekokoontuminen','🤡',350,2,false],['konjakkipiknik','Konjakkipiknik','🥃',30,1,true],['pyjamabrunssi','Pyjamabrunssi','🥞',40,1,false],['karaokepuisto','Karaoke puistossa','🎤',290,2,false],['vesisota','Vesipyssytaistelu','💦',195,2,false],['flashmob','Tanssia bussipysäkillä','🕺',320,3,false],['avanto','Avantouinti auringonnousussa','🌅',20,3,false],['huonorunous','Vuoden huonoin runo -ilta','📜',260,1,false],['kasari','Pukeudu 80-luvuksi','📼',300,2,false]].map((a,i)=>({id:a[0],name:a[1],emoji:a[2],hue:a[3],is_crazy:true,crazy_level:a[4],is_adult:a[5],is_custom:false,sort_order:500+i*10,created_by:null})));
const TABLES=['users','profiles','profile_private','activities','events','event_participants','help_requests','help_request_contacts','help_offers','conversations','messages','conversation_reads','notifications','businesses','business_private','business_members','reports','friend_requests','event_invites','teams','team_members','team_roles','team_places','team_events','team_event_rsvps','team_messages'];
function fresh(){const d={calls:[]};TABLES.forEach(t=>d[t]=[]);d.activities=SEED.map(a=>Object.assign({created_at:now()},a));return d}
let db;try{db=JSON.parse(localStorage.getItem(DB_KEY))}catch(e){}if(!db||!db.users)db=fresh();TABLES.forEach(t=>{if(!db[t])db[t]=[]});
const persist=()=>localStorage.setItem(DB_KEY,JSON.stringify(db));persist();
const clone=o=>JSON.parse(JSON.stringify(o));
function E(message,code){const e=new Error(message);e.message=message;e.code=code||'P0001';return e}
const RLS=t=>E('new row violates row-level security policy for table "'+t+'"','42501');
// ---------- helpers mirroring SQL functions
const prof=u=>db.profiles.find(p=>p.id===u);
const isAdmin=u=>!!(prof(u)&&prof(u).is_admin);
const canHelp=u=>{const p=prof(u),pp=db.profile_private.find(x=>x.id===u);return !!(p&&p.email_verified&&pp&&pp.phone)};
const reqOf=id=>db.help_requests.find(h=>h.id===id);
const isHelper=(rid,u)=>db.help_offers.some(o=>o.request_id===rid&&o.helper_id===u);
function isMember(cid,u){const c=db.conversations.find(x=>x.id===cid);if(!c||!u)return false;
 if(c.event_id)return db.event_participants.some(p=>p.event_id===c.event_id&&p.user_id===u);
 const h=reqOf(c.help_request_id);return !!h&&['approved','closed'].includes(h.status)&&(h.requester_id===u||isHelper(h.id,u))}
const nameOf=u=>(prof(u)&&prof(u).display_name)||'Joku';
// ---- friends (mirrors schema.sql 7c) and teams (7b)
const pairOf=(a,b)=>db.friend_requests.find(r=>(r.requester_id===a&&r.target_id===b)||(r.requester_id===b&&r.target_id===a));
const areFriends=(a,b)=>{const r=pairOf(a,b);return !!r&&r.status==='accepted'};
const teamOf=id=>db.teams.find(t=>t.id===id);
const teamRole=(tid,u)=>{const m=db.team_members.find(x=>x.team_id===tid&&x.user_id===u);return m?m.role:null};
const isTeamMember=(tid,u)=>{const t=teamOf(tid);return !!t&&(t.owner_id===u||!!teamRole(tid,u))};
const isTeamAdmin=(tid,u)=>{const t=teamOf(tid);return !!t&&(t.owner_id===u||teamRole(tid,u)==='admin')};
const isTeamCoach=(tid,u)=>isTeamAdmin(tid,u)||teamRole(tid,u)==='coach';
const teamOfEvent=eid=>{const e=db.team_events.find(x=>x.id===eid);return e&&e.team_id};
// ---- public / business events, moderation (mirrors schema.sql 1b / 1c)
const todayFi=()=>new Intl.DateTimeFormat('en-CA',{timeZone:'Europe/Helsinki',year:'numeric',month:'2-digit',day:'2-digit'}).format(new Date());
const addDays=(ymd,n)=>{const d=new Date(ymd+'T12:00:00Z');d.setUTCDate(d.getUTCDate()+n);return d.toISOString().slice(0,10)};
const isBanned=u=>!!(prof(u)&&prof(u).banned);
const bizOf=id=>db.businesses.find(b=>b.id===id);
const isBizMember=(bid,u)=>db.business_members.some(m=>m.business_id===bid&&m.user_id===u);
const bizActive=bid=>{const b=bizOf(bid);return !!b&&b.status==='approved'&&!!b.subscription_active_until&&b.subscription_active_until>=todayFi()};
const bizCanPost=(bid,u)=>bizActive(bid)&&(isBizMember(bid,u)||isAdmin(u));
function validYTunnus(t){if(!/^\d{7}-\d$/.test(t||''))return false;const w=[7,9,10,5,8,4,2];let s=0;for(let i=0;i<7;i++)s+=Number(t[i])*w[i];const r=s%11;if(r===1)return false;return (r===0?0:11-r)===Number(t[8])}
const AD_WORDS='eur|euro|euroa|euron|euroja|euros|hinta[a-z]*|hinnat|hinnoit[a-z]*|alennus[a-z]*|alennuk[a-z]*|tarjous[a-z]*|tarjoukse[a-z]*|varaa|varaus[a-z]*|varauks[a-z]*|osta|ostaa|myynti[a-z]*|myynnissä|myydään|kampanj[a-z]*|price|prices|pricing|discount[a-z]*|buy|book now|promo[a-z]*|coupon[a-z]*|precio|precios|oferta|ofertas|descuento|descuentos|rebaja|rebajas|cupón|cupon|pris|priser|rabatt[a-z]*|erbjudande[a-z]*|köp|köpa|boka|rea';
const AD_RES=[/https?:\/\/|www\./,/[a-z0-9-]\.(com|fi|se|es|net|org|io|eu|uk|info|biz|shop|store|online|app)([^a-z0-9]|$)/,/[a-z0-9._%+-]+@[a-z0-9.-]+\.[a-z]{2,}/,/(^|[^0-9])(\+|00)?[0-9]([ ()-]?[0-9]){6,}/,/€/,/(^|[^0-9])-[0-9]{1,2} ?%/,/(alennus|alennuk|rabatt|descuento|discount)/,new RegExp('(^|[^a-z0-9åäöéáíóúñüç])('+AD_WORDS+')($|[^a-z0-9åäöéáíóúñüç])')];
const looksCommercial=t=>{const l=String(t||'').toLowerCase();return AD_RES.some(re=>re.test(l))};
const URL_OK=u=>!u||(/^https:\/\/[^\s<>"']+$/.test(u)&&u.length<=300);
function eventRules(row,a,isNew,old){
 if(isBanned(a))throw E('account_banned');
 const kind=row.kind||'community';row.kind=kind;
 if(kind==='community'&&!isAdmin(a)&&(looksCommercial(row.title)||looksCommercial(row.description)))throw E('commercial_content');
 if(kind==='public'&&!isAdmin(a))throw E('public_event_admin_only');
 if(kind==='business'&&(isNew||!isAdmin(a))&&!bizCanPost(row.business_id,a))throw E('business_subscription_required');
 if(kind!=='community')row.host_id=null;
 ['organizer_name','official_url','price_info'].forEach(k=>row[k]=String(row[k]||'').trim());
 const chk=m=>{throw E('new row for relation "events" violates check constraint "'+m+'"','23514')};
 if(kind==='community'&&(!row.host_id||row.business_id||row.organizer_name||row.official_url||row.price_info))chk('events_kind_fields');
 if(kind==='public'&&(row.business_id||row.organizer_name.length<2))chk('events_kind_fields');
 if(kind==='business'&&!row.business_id)chk('events_kind_fields');
 if(!URL_OK(row.official_url))chk('events_official_url_check');
 if(row.ends_at&&(Date.parse(row.ends_at)<Date.parse(row.starts_at)||Date.parse(row.ends_at)>Date.parse(row.starts_at)+62*864e5))chk('events_ends_check');
 if(row.max_participants===null&&kind==='community')chk('events_max_participants_check');
 if(row.max_participants!=null&&!(row.max_participants>=2&&row.max_participants<=100000&&(kind!=='community'||row.max_participants<=50)))chk('events_max_participants_check');
 row.ends_at=row.ends_at||null;row.business_id=row.business_id||null;row.last_at=row.ends_at||row.starts_at;
}
function notifyMembers(bid,icon,body,code,params){db.business_members.filter(m=>m.business_id===bid).forEach(m=>notify(m.user_id,icon,body,'business',bid,code,params))}
function visible(t,r,u){if(!u)return false;switch(t){
 case 'profile_private':return r.id===u||isAdmin(u);
 case 'help_requests':return r.status==='approved'||r.requester_id===u||isAdmin(u)||isHelper(r.id,u);
 case 'help_request_contacts':{const h=reqOf(r.request_id);return isAdmin(u)||isHelper(r.request_id,u)||(!!h&&h.requester_id===u)}
 case 'help_offers':{const h=reqOf(r.request_id);return r.helper_id===u||(!!h&&visible('help_requests',h,u))}
 case 'conversations':return isMember(r.id,u);
 case 'messages':return isMember(r.conversation_id,u);
 case 'conversation_reads':return r.user_id===u;
 case 'notifications':return r.user_id===u;
 case 'users':return false;
 case 'businesses':return r.status==='approved'||r.created_by===u||isBizMember(r.id,u)||isAdmin(u);
 case 'business_private':return isBizMember(r.business_id,u)||isAdmin(u);
 case 'business_members':return r.user_id===u||isBizMember(r.business_id,u)||isAdmin(u);
 case 'reports':return r.reporter_id===u||isAdmin(u);
 case 'friend_requests':return r.requester_id===u||r.target_id===u||isAdmin(u);
 case 'event_invites':return r.inviter_id===u||r.invitee_id===u;
 case 'teams':return true;
 case 'team_members':return r.user_id===u||isTeamMember(r.team_id,u);
 case 'team_roles':case 'team_places':case 'team_events':case 'team_messages':return isTeamMember(r.team_id,u);
 case 'team_event_rsvps':return isTeamMember(teamOfEvent(r.event_id),u);
 default:return true}}
function notify(uid,icon,body,kind,id,code,params){if(!uid)return;ins('notifications',{id:uuid(),user_id:uid,icon,code:code||null,params:params||{},body:String(body).slice(0,500),link_kind:kind,link_id:id,read_at:null,created_at:now()})}
function notifyAdmins(icon,body,kind,id,code,params){db.profiles.filter(p=>p.is_admin).forEach(p=>notify(p.id,icon,body,kind,id,code,params))}
function sysMsg(cid,body,code,params){if(cid)ins('messages',{id:uuid(),conversation_id:cid,sender_id:null,kind:'system',body,code:code||null,params:params||{},created_at:now()})}
function ins(t,row){db[t].push(row);emit(t,row);return row}
// ---------- realtime
let channels=[];
function emit(t,row){channels.forEach(ch=>ch.subs.forEach(s=>{if(s.f.table!==t||(s.f.event!=='INSERT'&&s.f.event!=='*'))return;
 if(s.f.filter){const m=/^(\w+)=eq\.(.+)$/.exec(s.f.filter);if(m&&String(row[m[1]])!==m[2])return}
 const u=sessionUid();if(!visible(t,row,u))return;
 const copy=clone(row);setTimeout(()=>s.cb({eventType:'INSERT',new:copy}),15)}))}
// ---------- write emulation (actor = user id)
function doInsert(t,row,a){
 row=Object.assign({},row);
 if(!a)throw E('permission denied for table '+t,'42501');
 switch(t){
  case 'profiles':if(row.id!==a)throw RLS(t);row.is_admin=false;row.email_verified=false;break;
  case 'profile_private':if(row.id!==a)throw RLS(t);if(row.phone&&!/^\+?[0-9][0-9 ()-]{5,19}$/.test(row.phone))throw E('violates check constraint "profile_private_phone_check"','23514');if(db.profile_private.some(x=>x.id===a))throw E('duplicate key value violates unique constraint "profile_private_pkey"','23505');break;
  case 'activities':
   if(!isAdmin(a)){row.is_custom=true;row.created_by=a;row.sort_order=1000}
   if(row.created_by!==a||!row.is_custom)throw RLS(t);
   row.name=String(row.name||'').trim().replace(/\s+/g,' ');
   if(row.name.length<2||row.name.length>28)throw E('violates check constraint "activities_name_check"','23514');
   if(/[<>&"'\\]/.test(row.emoji||''))throw E('violates check constraint "activities_emoji_check"','23514');
   if(db.activities.some(x=>x.name.toLowerCase()===row.name.toLowerCase()))throw E('duplicate key value violates unique constraint "activities_name_lower_key"','23505');
   if(ADULT.test(row.name))row.is_adult=true;
   if(row.is_crazy&&!row.crazy_level)row.crazy_level=2;if(!row.is_crazy)row.crazy_level=0;
   row.created_at=now();break;
  case 'events':{
   row.kind=row.kind||'community';
   if(row.kind==='community'){if(!isAdmin(a)||!row.host_id)row.host_id=a;if(row.host_id!==a)throw RLS(t)}
   eventRules(row,a,true);
   if(Date.parse(row.starts_at)<Date.now()-600000)throw E('event_in_past');
   const ac=db.activities.find(x=>x.id===row.activity_id);if(!ac)throw E('violates foreign key constraint "events_activity_id_fkey"','23503');
   row.is_crazy=!!(row.is_crazy||ac.is_crazy);row.is_adult=!!(row.is_adult||ac.is_adult||ADULT.test(row.title||''));
   if(row.is_crazy&&!row.crazy_level)row.crazy_level=ac.crazy_level||2;if(!row.is_crazy)row.crazy_level=0;
   row.id=row.id||uuid();row.created_at=now();row.updated_at=row.created_at;
   row.description=row.description||'';row.district=row.district||'';
   db.events.push(row);
   const cid=uuid();db.conversations.push({id:cid,kind:'event',event_id:row.id,help_request_id:null,created_at:now()});
   if(row.host_id)db.event_participants.push({event_id:row.id,user_id:row.host_id,joined_at:now()});
   if(row.kind==='community')sysMsg(cid,'Tapahtuma luotu – toivota osallistujat tervetulleiksi! 👋','event_created');
   else sysMsg(cid,'Etsi seuraa: kerro täällä, milloin ja mistä lähdet – sovitaan yhteinen lähtö! 👋','find_company');
   return row}
  case 'event_participants':{
   if(row.user_id!==a)throw RLS(t);
   const e=db.events.find(x=>x.id===row.event_id);if(!e)throw E('event_not_found');
   if(db.event_participants.some(p=>p.event_id===e.id&&p.user_id===a))throw E('duplicate key value violates unique constraint "event_participants_pkey"','23505');
   if(a!==e.host_id){if(Date.parse(e.ends_at||e.starts_at)<Date.now()-3600000)throw E('event_in_past');if(e.max_participants!=null&&db.event_participants.filter(p=>p.event_id===e.id).length>=e.max_participants)throw E('event_full')}
   row.joined_at=now();db.event_participants.push(row);
   if(a!==e.host_id){const c=db.conversations.find(x=>x.event_id===e.id);sysMsg(c&&c.id,nameOf(a)+' liittyi mukaan 🎉','joined',{name:nameOf(a)});notify(e.host_id,'🙌',nameOf(a)+' liittyi tapahtumaasi “'+e.title+'”','event',e.id,'joined_your_event',{name:nameOf(a),title:e.title})}
   return row}
  case 'messages':
   if(isBanned(a))throw E('account_banned');
   if(!isMember(row.conversation_id,a)||(row.sender_id&&row.sender_id!==a))throw RLS(t);
   row.sender_id=a;row.kind='user';row.body=String(row.body||'').trim();if(!row.body||row.body.length>1000)throw E('violates check constraint "messages_body_check"','23514');
   row.id=uuid();row.created_at=now();return ins(t,row);
  case 'conversation_reads':if(row.user_id!==a||!isMember(row.conversation_id,a))throw RLS(t);break;
  case 'help_offers':{
   if(row.helper_id&&row.helper_id!==a)throw RLS(t);row.helper_id=a;
   if(!canHelp(a))throw E('verification_required');
   const h=reqOf(row.request_id);if(!h||h.status!=='approved')throw E('request_not_open');
   if(h.requester_id===a)throw E('own_request');
   if(db.help_offers.filter(o=>o.request_id===h.id).length>=h.helpers_needed)throw E('request_full');
   row.created_at=now();db.help_offers.push(row);
   const c=db.conversations.find(x=>x.help_request_id===h.id);sysMsg(c&&c.id,nameOf(a)+' tarjoutui auttamaan 💚','offered',{name:nameOf(a)});
   notify(h.requester_id,'🙋',nameOf(a)+' tarjoutui auttamaan pyyntöösi “'+h.title+'”','chat',h.id,'offered_your_request',{name:nameOf(a),title:h.title});
   return row}
  case 'reports':{
   row.reporter_id=a;row.status='open';row.resolved_by=null;row.resolved_at=null;row.target_type=row.target_type||'event';row.note=String(row.note||'').trim();
   if(!['business_ad','inappropriate','spam','other'].includes(row.reason))throw E('violates check constraint "reports_reason_check"','23514');
   const e=db.events.find(x=>x.id===row.target_id);if(!e)throw E('report_target_missing');
   if(db.reports.some(r=>r.reporter_id===a&&r.target_type===row.target_type&&r.target_id===row.target_id))throw E('duplicate key value violates unique constraint "reports_once_key"','23505');
   row.id=uuid();row.created_at=now();db.reports.push(row);
   notifyAdmins('🚩','Uusi ilmoitus tapahtumasta “'+e.title+'”','admin',e.id,'admin_new_report',{title:e.title});
   return row}
  case 'notifications':case 'conversations':case 'help_requests':case 'help_request_contacts':case 'businesses':case 'business_private':case 'business_members':throw RLS(t);
  case 'friend_requests':case 'event_invites':throw RLS(t); // only via RPCs
  case 'teams':if(isBanned(a))throw E('account_banned');row.owner_id=row.owner_id||a;if(row.owner_id!==a)throw RLS(t);row.name=String(row.name||'').trim();if(row.name.length<2||row.name.length>50)throw E('violates check constraint "teams_name_check"','23514');row.id=uuid();row.created_at=now();row.updated_at=row.created_at;row.sport=row.sport||'';row.description=row.description||'';row.logo_url=row.logo_url||'';break;
  case 'team_members':if(!((row.user_id===a&&(row.role||'member')==='member')||isTeamAdmin(row.team_id,a)))throw RLS(t);if(db.team_members.some(x=>x.team_id===row.team_id&&x.user_id===row.user_id))throw E('duplicate key value violates unique constraint "team_members_team_id_user_id_key"','23505');row.role=row.role||'member';row.id=uuid();row.joined_at=now();break;
  case 'team_roles':case 'team_places':if(!isTeamAdmin(row.team_id,a))throw RLS(t);row.id=uuid();break;
  case 'team_events':if(!isTeamCoach(row.team_id,a))throw RLS(t);row.id=uuid();row.created_by=a;row.created_at=now();row.updated_at=row.created_at;break;
  case 'team_event_rsvps':if(row.user_id!==a||!isTeamMember(teamOfEvent(row.event_id),a))throw RLS(t);if(!['going','maybe'].includes(row.status))throw E('violates check constraint "team_event_rsvps_status_check"','23514');row.id=uuid();row.created_at=now();break;
  case 'team_messages':if(!isTeamMember(row.team_id,a))throw RLS(t);row.sender_id=a;row.id=uuid();row.created_at=now();break;
 }
 db[t].push(row);return row;
}
function doUpdate(t,old,patch,a){
 const row=Object.assign({},old,patch);
 switch(t){
  case 'profiles':if(old.id!==a)return null;row.id=old.id;row.is_admin=old.is_admin;row.email_verified=old.email_verified;row.banned=!!old.banned;row.updated_at=now();break;
  case 'profile_private':if(old.id!==a)return null;if(row.phone&&!/^\+?[0-9][0-9 ()-]{5,19}$/.test(row.phone))throw E('violates check constraint "profile_private_phone_check"','23514');break;
  case 'notifications':if(old.user_id!==a)return null;{const r2=Object.assign({},old);r2.read_at=old.read_at||now();Object.assign(old,r2);return old}
  case 'conversation_reads':if(old.user_id!==a)return null;break;
  case 'events':{
   const k=old.kind||'community';
   if(!(old.host_id===a||isAdmin(a)||(old.business_id&&isBizMember(old.business_id,a))))return null;
   row.kind=k;row.business_id=old.business_id||null;if(!isAdmin(a))row.host_id=old.host_id;
   eventRules(row,a,false,old);row.updated_at=now();break}
  case 'businesses':{
   if(!(isBizMember(old.id,a)||isAdmin(a)))return null;
   if(!isAdmin(a)){['id','created_by','created_at','subscription_active_until','expiring_notified_for','expired_notified_for','reviewed_by','reviewed_at','admin_reason'].forEach(k=>row[k]=old[k]);
    if(old.status==='approved'){row.business_code=old.business_code;row.country=old.country}
    if(row.status!==old.status){if(!(old.status==='rejected'&&row.status==='pending'))throw E('status_change_not_allowed');row.admin_reason=''}}
   else if(row.status!==old.status){row.reviewed_by=a;row.reviewed_at=now()}
   if(row.subscription_active_until!==old.subscription_active_until&&row.subscription_active_until&&row.subscription_active_until<todayFi())row.expired_notified_for=row.subscription_active_until;
   row.updated_at=now();const prev=Object.assign({},old);Object.assign(old,row);afterBizUpdate(prev,old);return old}
  case 'business_private':if(!(isBizMember(old.business_id,a)||isAdmin(a)))return null;row.business_id=old.business_id;row.updated_at=now();break;
  case 'reports':if(!isAdmin(a))return null;if(row.status!==old.status){row.resolved_by=a;row.resolved_at=row.status==='open'?null:now()}break;
  case 'help_requests':{
   if(old.requester_id!==a&&!isAdmin(a))return null;
   if(!isAdmin(a)){
    if(['approved','rejected','closed'].includes(old.status)){const w=row.status;Object.keys(row).forEach(k=>row[k]=old[k]);if(w==='closed'&&old.status==='approved')row.status='closed';else if(w!==old.status)throw E('status_change_not_allowed')}
    else{['requester_id','email_verified','reviewed_by','reviewed_at','created_at','history','admin_reason'].forEach(k=>row[k]=old[k]);if(row.status!==old.status&&!((row.status==='pending'&&old.status==='info')||row.status==='closed'))throw E('status_change_not_allowed')}
    if(row.status==='pending'&&old.status==='info')row.admin_reason='';
   }else if(row.status!==old.status){row.reviewed_by=a;row.reviewed_at=now()}
   if(/€/.test(row.title+row.description+row.needs))throw E('violates check constraint "help_requests_no_prices"','23514');
   if(row.status!==old.status)row.history=(old.history||[]).concat([{s:old.status==='info'&&row.status==='pending'?'resub':row.status,t:now()}]);
   row.updated_at=now();
   Object.assign(old,row);
   if(row.status!==(patch.__prev||'')){/* no-op */}
   return old}
  case 'teams':if(!isTeamAdmin(old.id,a))return null;row.id=old.id;row.owner_id=old.owner_id;row.updated_at=now();break;
  case 'team_members':if(!isTeamAdmin(old.team_id,a))return null;row.team_id=old.team_id;row.user_id=old.user_id;break;
  case 'team_events':if(!isTeamCoach(old.team_id,a))return null;row.team_id=old.team_id;row.updated_at=now();break;
  case 'team_event_rsvps':if(old.user_id!==a)return null;row.user_id=old.user_id;row.event_id=old.event_id;if(!['going','maybe'].includes(row.status))throw E('violates check constraint "team_event_rsvps_status_check"','23514');break;
  default:return null;
 }
 Object.assign(old,row);return old;
}
function afterBizUpdate(prev,b){
 if(prev.status!==b.status){
  if(b.status==='approved')notifyMembers(b.id,'✅','Yritystilisi “'+b.name+'” on hyväksytty 🎉 Tilaus aktivoidaan laskutuksen yhteydessä.','business_approved',{name:b.name});
  else if(b.status==='rejected')notifyMembers(b.id,'❌','Yritystilihakemusta “'+b.name+'” ei hyväksytty. Syy: '+b.admin_reason,'business_rejected',{name:b.name,reason:b.admin_reason});
  else if(b.status==='pending'&&prev.status==='rejected')notifyAdmins('🏢','Uusi yritystilihakemus: “'+b.name+'”','admin',b.id,'admin_new_business',{name:b.name});
 }
 if(prev.subscription_active_until!==b.subscription_active_until&&b.status==='approved'){
  if(b.subscription_active_until&&b.subscription_active_until>=todayFi())notifyMembers(b.id,'📅','Yritystilin “'+b.name+'” tilaus on voimassa '+b.subscription_active_until+' asti.','business_extended',{name:b.name,date:b.subscription_active_until});
  else notifyMembers(b.id,'⏹️','Yritystilin “'+b.name+'” tilaus on päätetty. Uusia yritystapahtumia ei voi julkaista.','business_ended',{name:b.name});
 }
}
function afterHelpUpdate(prev,h){
 if(prev===h.status)return;
 if(h.status==='approved')notify(h.requester_id,'✅','Pyyntösi on hyväksytty ja julkaistu 💚 “'+h.title+'”','help',h.id,'request_approved',{title:h.title});
 else if(h.status==='rejected')notify(h.requester_id,'❌','Pyyntöäsi “'+h.title+'” ei julkaistu. Syy: '+h.admin_reason,'request',h.id,'request_rejected',{title:h.title,reason:h.admin_reason});
 else if(h.status==='info')notify(h.requester_id,'❓','Ylläpito pyytää lisätietoja pyyntöösi “'+h.title+'”: '+h.admin_reason,'request',h.id,'request_info',{title:h.title,reason:h.admin_reason});
 else if(h.status==='pending'&&prev==='info')notifyAdmins('🔁','Avunpyyntöä täydennettiin: “'+h.title+'”','admin',h.id,'admin_resubmitted',{title:h.title});
 else if(h.status==='closed'){const c=db.conversations.find(x=>x.help_request_id===h.id);sysMsg(c&&c.id,'Pyyntö on suljettu – kiitos kaikille avusta! 💚','request_closed');db.help_offers.filter(o=>o.request_id===h.id).forEach(o=>notify(o.helper_id,'💚','Pyyntö “'+h.title+'” on suljettu. Kiitos avusta!','chat',h.id,'request_closed_thanks',{title:h.title}))}
}
function cascade(t,row){
 if(t==='businesses'){db.events.filter(e=>e.business_id===row.id).forEach(e=>cascade('events',e));db.events=db.events.filter(e=>e.business_id!==row.id);db.business_private=db.business_private.filter(x=>x.business_id!==row.id);db.business_members=db.business_members.filter(x=>x.business_id!==row.id)}
 if(t==='teams'){['team_members','team_roles','team_places','team_messages'].forEach(k=>db[k]=db[k].filter(x=>x.team_id!==row.id));const ev=db.team_events.filter(x=>x.team_id===row.id).map(x=>x.id);db.team_event_rsvps=db.team_event_rsvps.filter(x=>!ev.includes(x.event_id));db.team_events=db.team_events.filter(x=>x.team_id!==row.id)}
 if(t==='team_events')db.team_event_rsvps=db.team_event_rsvps.filter(x=>x.event_id!==row.id);
 if(t==='events'){db.event_invites=db.event_invites.filter(x=>x.event_id!==row.id);db.friend_requests.forEach(x=>{if(x.event_id===row.id)x.event_id=null});db.event_participants=db.event_participants.filter(p=>p.event_id!==row.id);const cs=db.conversations.filter(c=>c.event_id===row.id).map(c=>c.id);dropConvs(cs)}
 if(t==='help_requests'){db.help_request_contacts=db.help_request_contacts.filter(c=>c.request_id!==row.id);db.help_offers=db.help_offers.filter(o=>o.request_id!==row.id);dropConvs(db.conversations.filter(c=>c.help_request_id===row.id).map(c=>c.id))}
}
function dropConvs(ids){db.conversations=db.conversations.filter(c=>!ids.includes(c.id));db.messages=db.messages.filter(m=>!ids.includes(m.conversation_id));db.conversation_reads=db.conversation_reads.filter(r=>!ids.includes(r.conversation_id))}
function canDelete(t,r,a){switch(t){
 case 'events':return r.host_id===a||isAdmin(a)||(!!r.business_id&&isBizMember(r.business_id,a));
 case 'businesses':case 'reports':case 'business_members':return isAdmin(a);
 case 'event_participants':{const e=db.events.find(x=>x.id===r.event_id);return (r.user_id===a&&!(e&&e.host_id===a))||isAdmin(a)}
 case 'help_offers':return r.helper_id===a||isAdmin(a);
 case 'help_requests':return r.requester_id===a||isAdmin(a);
 case 'notifications':case 'conversation_reads':return r.user_id===a;
 case 'messages':return r.sender_id===a||isAdmin(a);
 case 'activities':return isAdmin(a);
 case 'teams':return isTeamAdmin(r.id,a);
 case 'team_members':return r.user_id===a||isTeamAdmin(r.team_id,a);
 case 'team_roles':case 'team_places':return isTeamAdmin(r.team_id,a);
 case 'team_events':return isTeamCoach(r.team_id,a);
 case 'team_event_rsvps':return r.user_id===a;
 default:return false}}
function afterDelete(t,r){
 if(t==='event_participants'){const e=db.events.find(x=>x.id===r.event_id);if(e){const c=db.conversations.find(x=>x.event_id===e.id);sysMsg(c&&c.id,nameOf(r.user_id)+' perui osallistumisen','left',{name:nameOf(r.user_id)})}}
 if(t==='help_offers'){const h=reqOf(r.request_id);if(h){const c=db.conversations.find(x=>x.help_request_id===h.id);sysMsg(c&&c.id,nameOf(r.helper_id)+' perui avuntarjouksen','withdrew',{name:nameOf(r.helper_id)});notify(h.requester_id,'ℹ️',nameOf(r.helper_id)+' perui avuntarjouksensa pyyntöösi “'+h.title+'”','request',h.id,'withdrew_your_request',{name:nameOf(r.helper_id),title:h.title})}}
}
// ---------- guest (anon) access, mirrors schema.sql section 5b:
// anon may read activities (not created_by), guest_events (upcoming, not 18+, no host) and
// guest_help_requests (approved only, no requester/contact/address, location rounded ~1 km)
function guestView(t,a,cols){
 const recent=r=>Date.parse(r.starts_at)>Date.now()-864e5;
 if(t==='activities'){if(!cols||cols==='*'||/created_by/.test(cols))throw E('permission denied for table activities','42501');return db.activities.map(r=>{const o=Object.assign({},r);delete o.created_by;return o})}
 if(t==='businesses'){if(!cols||cols==='*'||/business_code|subscription|admin|created_by|consent|notified|review/.test(cols))throw E('permission denied for table businesses','42501');return db.businesses.filter(b=>b.status==='approved').map(b=>({id:b.id,name:b.name,logo_url:b.logo_url,website:b.website,description:b.description,country:b.country,status:b.status}))}
 if(t==='guest_events')return db.events.filter(e=>a||(!e.is_adult&&Date.parse(e.last_at||e.starts_at)>Date.now()-864e5)).map(e=>({kind:e.kind||'community',ends_at:e.ends_at||null,last_at:e.last_at||e.starts_at,organizer_name:e.organizer_name||'',official_url:e.official_url||'',price_info:e.price_info||'',business_id:e.business_id||null,business_name:(bizOf(e.business_id)&&bizOf(e.business_id).status==='approved')?bizOf(e.business_id).name:null,business_logo:(bizOf(e.business_id)&&bizOf(e.business_id).status==='approved')?bizOf(e.business_id).logo_url:null,id:e.id,activity_id:e.activity_id,title:e.title,description:e.description,starts_at:e.starts_at,city:e.city,district:e.district,place:e.place,lat:e.lat,lng:e.lng,max_participants:e.max_participants,skill_level:e.skill_level,is_crazy:e.is_crazy,crazy_level:e.crazy_level,is_adult:e.is_adult,created_at:e.created_at,participant_count:db.event_participants.filter(p=>p.event_id===e.id).length}));
 return db.help_requests.filter(h=>h.status==='approved'&&(a||recent(h))).map(h=>({id:h.id,category:h.category,title:h.title,description:h.description,needs:h.needs,city:h.city,district:h.district,lat:Math.round(h.lat*100)/100,lng:Math.round(h.lng*100)/100,starts_at:h.starts_at,duration:h.duration,helpers_needed:h.helpers_needed,status:h.status,email_verified:h.email_verified,created_at:h.created_at,helpers_count:db.help_offers.filter(o=>o.request_id===h.id).length}));
}
// ---------- query builder
class Q{
 constructor(t,actor){this.t=t;this.a=actor;this.op='select';this.f=[];this.ord=[];this.lim=null;this.one=0;this.ret=false;this.p=null;this.opt={}}
 select(c){if(this.op!=='select')this.ret=true;else this.cols=c||'*';return this}
 insert(p){this.op='insert';this.p=p;return this}
 upsert(p,o){this.op='upsert';this.p=p;this.opt=o||{};return this}
 update(p){this.op='update';this.p=p;return this}
 delete(){this.op='delete';return this}
 eq(c,v){this.f.push(r=>r[c]===v);return this}
 neq(c,v){this.f.push(r=>r[c]!==v);return this}
 in(c,arr){this.f.push(r=>arr.includes(r[c]));return this}
 gte(c,v){this.f.push(r=>String(r[c])>=String(v));return this}
 lte(c,v){this.f.push(r=>String(r[c])<=String(v));return this}
 is(c,v){this.f.push(r=>v===null?r[c]==null:r[c]===v);return this}
 order(c,o){this.ord.push([c,!(o&&o.ascending===false)]);return this}
 limit(n){this.lim=n;return this}
 maybeSingle(){this.one=1;return this}
 single(){this.one=2;return this}
 then(res,rej){return new Promise(r=>setTimeout(r,8)).then(()=>this.exec()).then(res,rej)}
 match(r){return this.f.every(fn=>fn(r))}
 exec(){
  try{
   const a=this.a(), t=this.t;let out;
   if(this.op==='select'){
    let src;
    if(t==='guest_events'||t==='guest_help_requests'||(!a&&(t==='activities'||t==='businesses')))src=guestView(t,a,this.cols);
    else{if(!a||!db[t])throw E('permission denied for table '+t,'42501');src=db[t].filter(r=>visible(t,r,a))}
    out=src.filter(r=>this.match(r));
    this.ord.slice().reverse().forEach(([c,asc])=>out.sort((x,y)=>{const A=x[c],B=y[c];return (A<B?-1:A>B?1:0)*(asc?1:-1)}));
    if(this.lim!=null)out=out.slice(0,this.lim);
   }else if(this.op==='insert'){
    out=[].concat(this.p).map(r=>doInsert(t,r,a));
   }else if(this.op==='upsert'){
    const keys=(this.opt.onConflict||'id').split(',').map(s=>s.trim());
    out=[].concat(this.p).map(r=>{const ex=db[t].find(x=>keys.every(k=>x[k]===r[k]));if(ex){if(!visible(t,ex,a))throw RLS(t);const u=doUpdate(t,ex,r,a);if(!u)throw RLS(t);return u}return doInsert(t,r,a)});
   }else if(this.op==='update'){
    out=[];db[t].filter(r=>visible(t,r,a)&&this.match(r)).forEach(r=>{const prev=r.status;const u=doUpdate(t,r,this.p,a);if(u){out.push(u);if(t==='help_requests')afterHelpUpdate(prev,u)}});
   }else if(this.op==='delete'){
    const del=db[t].filter(r=>visible(t,r,a)&&this.match(r)&&canDelete(t,r,a));
    db[t]=db[t].filter(r=>!del.includes(r));del.forEach(r=>{cascade(t,r);afterDelete(t,r)});out=del;
   }
   persist();
   if(this.op!=='select'&&!this.ret)return {data:null,error:null};
   out=clone(out);
   if(this.one){if(out.length>1||(this.one===2&&out.length===0))return {data:null,error:E('JSON object requested, multiple (or no) rows returned','PGRST116')};return {data:out[0]||null,error:null}}
   return {data:out,error:null};
  }catch(e){persist();return {data:null,error:{message:e.message,code:e.code}}}
 }
}
function rpc(name,args,actor){
 return new Promise(r=>setTimeout(r,8)).then(()=>{try{const a=actor();if(!a)throw E('not_authenticated');
  if(name==='submit_help_request'){
   const q=args.req||{},c=args.contact||{};
   if(!(prof(a)&&prof(a).email_verified))throw E('email_not_verified');
   if(!(q.consent_voluntary&&q.consent_terms&&q.consent_review))throw E('new row for relation "help_requests" violates check constraint "help_requests_consents"','23514');
   if(/€/.test((q.title||'')+(q.description||'')+(q.needs||'')))throw E('new row for relation "help_requests" violates check constraint "help_requests_no_prices"','23514');
   if(q.category==='kuljetus'&&(q.dest_lat==null||!q.dest_label))throw E('violates check constraint "help_requests_dest"','23514');
   if(!/^\+?[0-9][0-9 ()-]{5,19}$/.test(c.phone||''))throw E('violates check constraint "help_request_contacts_phone_check"','23514');
   const id=uuid(),ts=now();
   const h={id,requester_id:a,category:q.category,title:q.title,description:q.description,needs:q.needs||'',city:q.city,district:q.district,place:q.place||'',lat:q.lat,lng:q.lng,dest_lat:q.dest_lat??null,dest_lng:q.dest_lng??null,dest_label:q.dest_label||null,starts_at:q.starts_at,duration:q.duration||'',helpers_needed:q.helpers_needed||1,status:'pending',admin_reason:'',consent_voluntary:true,consent_terms:true,consent_review:true,email_verified:true,history:[{s:'sent',t:ts}],reviewed_by:null,reviewed_at:null,created_at:ts,updated_at:ts};
   db.help_requests.push(h);
   const u=db.users.find(x=>x.id===a);
   db.help_request_contacts.push({request_id:id,contact_name:c.name,phone:c.phone,email:(u&&u.email)||c.email,created_at:ts});
   db.conversations.push({id:uuid(),kind:'help',event_id:null,help_request_id:id,created_at:ts});
   notify(a,'📨','Pyyntösi “'+h.title+'” on lähetetty ja odottaa hyväksyntää.','request',id,'request_sent',{title:h.title});
   notifyAdmins('🛡️','Uusi avunpyyntö odottaa tarkistusta: “'+h.title+'”','admin',id,'admin_new_request',{title:h.title});
   persist();return {data:id,error:null};
  }
  if(name==='delete_my_account'){deleteUser(a);persist();return {data:null,error:null}}
  if(name==='apply_business'){
   const b=args.biz||{},c=args.contact||{};const chk=m=>{throw E('new row violates check constraint "'+m+'"','23514')};
   if(!(prof(a)&&prof(a).email_verified))throw E('email_not_verified');
   if(db.businesses.filter(x=>x.created_by===a&&x.status!=='rejected').length>=3)throw E('too_many_businesses');
   const row={id:uuid(),name:String(b.name||'').trim().replace(/\s+/g,' '),business_code:String(b.business_code||'').trim().toUpperCase(),country:String(b.country||'FI').toUpperCase(),logo_url:String(b.logo_url||'').trim(),website:String(b.website||'').trim(),description:String(b.description||'').trim(),status:'pending',admin_reason:'',subscription_active_until:null,expiring_notified_for:null,expired_notified_for:null,consent_terms:!!b.consent_terms,created_by:a,reviewed_by:null,reviewed_at:null,created_at:now(),updated_at:now()};
   if(row.name.length<2||row.name.length>80)chk('businesses_name_check');
   if(row.business_code.length<2)chk('businesses_business_code_check');
   if(row.country==='FI'&&!validYTunnus(row.business_code))chk('businesses_fi_code');
   if(!row.consent_terms)chk('businesses_terms');
   if(row.logo_url&&!URL_OK(row.logo_url))chk('businesses_logo_url_check');if(row.website&&!URL_OK(row.website))chk('businesses_website_check');
   if(db.businesses.some(x=>x.country===row.country&&x.business_code===row.business_code&&x.status!=='rejected'))throw E('duplicate key value violates unique constraint "businesses_code_active_key"','23505');
   const pv={business_id:row.id,contact_email:String(c.contact_email||'').trim(),phone:String(c.phone||'').trim(),billing_address:String(c.billing_address||'').trim(),e_invoice:String(c.e_invoice||'').trim(),updated_at:now()};
   if(!(pv.contact_email.length>=3&&pv.contact_email.indexOf('@')>0))chk('business_private_contact_email_check');
   if(!/^\+?[0-9][0-9 ()-]{5,19}$/.test(pv.phone))chk('business_private_phone_check');
   if(pv.billing_address.length<5&&pv.e_invoice.length<5)chk('business_private_billing');
   db.businesses.push(row);db.business_members.push({business_id:row.id,user_id:a,role:'owner',created_at:now()});db.business_private.push(pv);
   notifyAdmins('🏢','Uusi yritystilihakemus: “'+row.name+'”','admin',row.id,'admin_new_business',{name:row.name});
   persist();return {data:row.id,error:null};
  }
  if(name==='business_expiry_sweep'){
   if(!isAdmin(a))throw E('admin_only');let n=0;const t=todayFi();
   db.businesses.filter(b=>b.status==='approved'&&b.subscription_active_until).forEach(b=>{
    if(b.subscription_active_until<t&&b.expired_notified_for!==b.subscription_active_until){notifyMembers(b.id,'⏰','Yritystilin “'+b.name+'” tilaus on päättynyt.','business_expired',{name:b.name});b.expired_notified_for=b.subscription_active_until;n++}
    else if(b.subscription_active_until>=t&&b.subscription_active_until<=addDays(t,7)&&b.expiring_notified_for!==b.subscription_active_until){notifyMembers(b.id,'⏳','Yritystilin “'+b.name+'” tilaus päättyy '+b.subscription_active_until+'.','business_expiring',{name:b.name,date:b.subscription_active_until});b.expiring_notified_for=b.subscription_active_until;n++}
   });persist();return {data:n,error:null};
  }
  if(name==='admin_moderate'){
   if(!isAdmin(a))throw E('admin_only');const u=args.uid,act=args.action;if(!u||u===a)throw E('moderation_target_invalid');
   if(act==='warn')notify(u,'⚠️','Ylläpidon varoitus: tavallisissa tapahtumissa ei saa mainostaa yritystä tai maksullista palvelua.',null,null,'moderation_warning',{});
   else if(act==='ban'){const p=prof(u);if(p&&!p.is_admin)p.banned=true;notify(u,'⛔','Tilisi on estetty yhteisöohjeiden rikkomisen vuoksi.',null,null,'moderation_banned',{})}
   else if(act==='unban'){const p=prof(u);if(p)p.banned=false}
   else throw E('moderation_action_invalid');
   persist();return {data:null,error:null};
  }
  if(name==='send_friend_request'){
   const tg=args.p_target,ev=args.p_event||null;
   if(isBanned(a))throw E('account_banned');
   if(!tg||tg===a)throw E('friend_self');if(!prof(tg))throw E('friend_target_missing');
   if(db.friend_requests.filter(r=>r.requester_id===a&&Date.parse(r.created_at)>Date.now()-864e5).length>=50)throw E('friend_rate_limited');
   if(ev&&!db.events.some(e=>e.id===ev))throw E('violates foreign key constraint "friend_requests_event_id_fkey"','23503');
   let r=pairOf(a,tg);const ts=now();
   if(r){
    if(r.status==='accepted'){persist();return {data:'accepted',error:null}}
    if(r.requester_id===tg&&r.status==='pending'){Object.assign(r,{status:'accepted',responded_at:ts,updated_at:ts});notify(tg,'🤝',nameOf(a)+' hyväksyi kaveripyyntösi','friend',r.id,'friend_accepted',{name:nameOf(a)});persist();return {data:'accepted',error:null}}
    if(r.requester_id===a){if(r.status==='pending'){persist();return {data:'pending',error:null}}throw E('friend_request_declined')}
    Object.assign(r,{requester_id:a,target_id:tg,status:'pending',event_id:ev,created_at:ts,updated_at:ts,responded_at:null});
   }else{r={id:uuid(),requester_id:a,target_id:tg,event_id:ev,status:'pending',created_at:ts,updated_at:ts,responded_at:null};db.friend_requests.push(r)}
   if(!db.notifications.some(n=>n.user_id===tg&&n.code==='friend_request'&&n.params&&n.params.from===a&&Date.parse(n.created_at)>Date.now()-864e5))notify(tg,'👋',nameOf(a)+' lähetti sinulle kaveripyynnön','friend',r.id,'friend_request',{name:nameOf(a),from:a});
   persist();return {data:'pending',error:null};
  }
  if(name==='respond_friend_request'){
   const r=db.friend_requests.find(x=>x.id===args.p_request&&x.target_id===a&&x.status==='pending');if(!r)throw E('friend_request_not_found');
   const ts=now();Object.assign(r,{status:args.p_accept?'accepted':'declined',responded_at:ts,updated_at:ts});
   if(args.p_accept)notify(r.requester_id,'🤝',nameOf(a)+' hyväksyi kaveripyyntösi','friend',r.id,'friend_accepted',{name:nameOf(a)});
   persist();return {data:null,error:null};
  }
  if(name==='remove_friend'){
   const o=args.p_other;db.friend_requests=db.friend_requests.filter(r=>!(((r.requester_id===a&&r.target_id===o)||(r.requester_id===o&&r.target_id===a))&&(r.status==='accepted'||(r.status==='pending'&&r.requester_id===a))));
   persist();return {data:null,error:null};
  }
  if(name==='invite_friend_to_event'){
   const e=db.events.find(x=>x.id===args.p_event),f=args.p_friend;
   if(isBanned(a))throw E('account_banned');if(!e)throw E('event_not_found');
   if(Date.parse(e.ends_at||e.starts_at)<Date.now())throw E('event_in_past');
   if(!areFriends(a,f))throw E('not_friends');
   if(db.event_invites.filter(x=>x.inviter_id===a&&Date.parse(x.created_at)>Date.now()-864e5).length>=100)throw E('friend_rate_limited');
   if(!db.event_invites.some(x=>x.event_id===e.id&&x.inviter_id===a&&x.invitee_id===f)){db.event_invites.push({event_id:e.id,inviter_id:a,invitee_id:f,created_at:now()});
    notify(f,'💌',nameOf(a)+' kutsui sinut tapahtumaan “'+e.title+'”','event',e.id,'event_invite',{name:nameOf(a),title:e.title})}
   persist();return {data:null,error:null};
  }
  throw E('function '+name+' not found');
 }catch(e){persist();return {data:null,error:{message:e.message,code:e.code}}}});
}
function deleteUser(a){
 db.events.filter(e=>e.host_id===a).forEach(e=>cascade('events',e));db.events=db.events.filter(e=>e.host_id!==a);
 db.help_requests.filter(h=>h.requester_id===a).forEach(h=>cascade('help_requests',h));db.help_requests=db.help_requests.filter(h=>h.requester_id!==a);
 ['event_participants','conversation_reads','notifications','business_members'].forEach(t=>db[t]=db[t].filter(r=>r.user_id!==a));
 db.reports.forEach(r=>{if(r.reporter_id===a)r.reporter_id=null});db.businesses.forEach(b=>{if(b.created_by===a)b.created_by=null});
 db.help_offers=db.help_offers.filter(o=>o.helper_id!==a);db.messages.forEach(m=>{if(m.sender_id===a)m.sender_id=null});
 db.profile_private=db.profile_private.filter(p=>p.id!==a);db.profiles=db.profiles.filter(p=>p.id!==a);db.users=db.users.filter(u=>u.id!==a);
 db.activities.forEach(x=>{if(x.created_by===a)x.created_by=null});
 db.friend_requests=db.friend_requests.filter(r=>r.requester_id!==a&&r.target_id!==a);db.event_invites=db.event_invites.filter(r=>r.inviter_id!==a&&r.invitee_id!==a);
 db.teams.filter(x=>x.owner_id===a).forEach(x=>cascade('teams',x));db.teams=db.teams.filter(x=>x.owner_id!==a);db.team_members=db.team_members.filter(x=>x.user_id!==a);db.team_event_rsvps=db.team_event_rsvps.filter(x=>x.user_id!==a);
}
// ---------- auth
function sessionUid(){const id=localStorage.getItem(SES_KEY);return id&&db.users.some(u=>u.id===id)?id:null}
function sessionObj(){const id=sessionUid();if(!id)return null;const u=db.users.find(x=>x.id===id);return {access_token:'mock-token',token_type:'bearer',user:{id:u.id,email:u.email,email_confirmed_at:u.email_confirmed_at}}}
const listeners=[];
function emitAuth(ev){const s=sessionObj();listeners.forEach(cb=>setTimeout(()=>cb(ev,s),0))}
function createUserRow(email,password,confirmed){
 const u={id:uuid(),email:email.toLowerCase(),password,email_confirmed_at:confirmed?now():null,created_at:now()};db.users.push(u);
 db.profiles.push({id:u.id,display_name:'',city:'Helsinki',custom_city:'',district:'',favs:[],bio:'',language:null,onboarded:false,is_admin:false,banned:false,email_verified:!!confirmed,created_at:now(),updated_at:now()});
 db.profile_private.push({id:u.id,phone:null,updated_at:now()});
 return u;
}
const auth={
 async getSession(){return {data:{session:sessionObj()},error:null}},
 onAuthStateChange(cb){listeners.push(cb);setTimeout(()=>cb('INITIAL_SESSION',sessionObj()),0);return {data:{subscription:{unsubscribe(){const i=listeners.indexOf(cb);if(i>=0)listeners.splice(i,1)}}}}},
 async signUp({email,password}){await new Promise(r=>setTimeout(r,20));email=String(email).toLowerCase();
  if(String(password).length<8)return {data:{user:null,session:null},error:{message:'Password should be at least 8 characters.',code:'weak_password'}};
  if(db.users.some(u=>u.email===email))return {data:{user:null,session:null},error:{message:'User already registered',code:'user_already_exists'}};
  const u=createUserRow(email,password,!CONFIRM);db.calls.push({fn:'signUp',email});persist();
  if(CONFIRM)return {data:{user:{id:u.id,email},session:null},error:null};
  localStorage.setItem(SES_KEY,u.id);emitAuth('SIGNED_IN');return {data:{user:{id:u.id,email},session:sessionObj()},error:null}},
 async signInWithPassword({email,password}){await new Promise(r=>setTimeout(r,20));const u=db.users.find(x=>x.email===String(email).toLowerCase());
  if(!u||u.password!==password)return {data:{},error:{message:'Invalid login credentials',status:400}};
  if(CONFIRM&&!u.email_confirmed_at)return {data:{},error:{message:'Email not confirmed',status:400}};
  localStorage.setItem(SES_KEY,u.id);emitAuth('SIGNED_IN');return {data:{session:sessionObj(),user:sessionObj().user},error:null}},
 async signOut(){localStorage.removeItem(SES_KEY);emitAuth('SIGNED_OUT');return {error:null}},
 async resetPasswordForEmail(email,opts){db.calls.push({fn:'resetPasswordForEmail',email,redirectTo:opts&&opts.redirectTo});persist();return {data:{},error:null}},
 async resend(o){db.calls.push({fn:'resend',email:o.email,type:o.type});persist();return {data:{},error:null}},
 async updateUser(p){const id=sessionUid();if(!id)return {data:{},error:{message:'session_not_found'}};const u=db.users.find(x=>x.id===id);if(p.password){if(String(p.password).length<8)return {data:{},error:{message:'Password should be at least 8 characters.'}};u.password=p.password}db.calls.push({fn:'updateUser'});persist();emitAuth('USER_UPDATED');return {data:{user:sessionObj().user},error:null}},
 async refreshSession(){return {data:{session:sessionObj()},error:null}}
};
function createClient(){
 const actor=()=>sessionUid();
 return {auth,from:t=>new Q(t,actor),rpc:(n,a)=>rpc(n,a,actor),
  channel(name){const ch={name,subs:[],on(type,f,cb){this.subs.push({f,cb});return this},subscribe(cb){channels.push(this);if(cb)setTimeout(()=>cb('SUBSCRIBED'),0);return this},unsubscribe(){channels=channels.filter(c=>c!==this)}};return ch},
  removeChannel(ch){channels=channels.filter(c=>c!==ch);return Promise.resolve('ok')}};
}
window.MolaplanMock={createClient};
// ---------- test hooks (simulate other users / SQL editor actions)
const byEmail=e=>db.users.find(u=>u.email===String(e).toLowerCase());
window.__mockSupa={
 db:()=>db,
 reset(){db=fresh();persist();localStorage.removeItem(SES_KEY)},
 createUser(email,name,o={}){const u=createUserRow(email,o.password||'salasana123',o.confirmed!==false);const p=prof(u.id);Object.assign(p,{display_name:name||'',city:o.city||'Helsinki',district:o.district||'Kallio',favs:o.favs||[],onboarded:true});if(o.phone)db.profile_private.find(x=>x.id===u.id).phone=o.phone;if(o.admin)p.is_admin=true;persist();return u.id},
 as(email){const u=byEmail(email);const actor=()=>u&&u.id;return {id:u&&u.id,from:t=>new Q(t,actor),rpc:(n,a)=>rpc(n,a,actor)}},
 setBusiness(id,patch){const b=bizOf(id);if(b){Object.assign(b,patch);persist()}return !!b},
 today:()=>todayFi(),
 makeAdmin(email){const u=byEmail(email);if(u){prof(u.id).is_admin=true;persist()}return !!u},
 confirmEmail(email){const u=byEmail(email);if(u){u.email_confirmed_at=now();prof(u.id).email_verified=true;persist()}return !!u},
 triggerRecovery(){listeners.forEach(cb=>setTimeout(()=>cb('PASSWORD_RECOVERY',sessionObj()),0))},
 calls:()=>db.calls,
 userId:e=>{const u=byEmail(e);return u&&u.id}
};
})();
