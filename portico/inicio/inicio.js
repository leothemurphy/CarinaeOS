const ENG={ddg:['DuckDuckGo','https://duckduckgo.com/?q='],google:['Google','https://www.google.com/search?q='],bing:['Bing','https://www.bing.com/search?q='],ecosia:['Ecosia','https://www.ecosia.org/search?q='],brave:['Brave Search','https://search.brave.com/search?q='],startpage:['Startpage','https://www.startpage.com/do/search?q=']};
const COLORS=['#2563eb','#16a34a','#dc2626','#9333ea','#ea580c','#0891b2','#db2777','#4f46e5','#65a30d','#0f766e'];
const DEF=[{n:'YouTube',u:'https://www.youtube.com'},{n:'Wikipédia',u:'https://pt.wikipedia.org'},{n:'GitHub',u:'https://github.com'},{n:'Gmail',u:'https://mail.google.com'},{n:'WhatsApp',u:'https://web.whatsapp.com'},{n:'Notícias',u:'https://news.google.com'}];
const store={get(k,d){try{const v=localStorage.getItem('portico-'+k);return v?JSON.parse(v):d}catch(e){return d}},set(k,v){try{localStorage.setItem('portico-'+k,JSON.stringify(v))}catch(e){}}};
let favs=store.get('favs',DEF),eng=store.get('eng','ddg');
const $=s=>document.querySelector(s),esc=s=>String(s).replace(/[&<>"]/g,c=>({'&':'&amp;','<':'&lt;','>':'&gt;','"':'&quot;'}[c]));
function greet(){const h=new Date().getHours();$('#hello').textContent=h<6?'Boa madrugada':h<12?'Bom dia':h<19?'Boa tarde':'Boa noite';const d=new Date();$('#time').textContent=d.toLocaleDateString('pt-PT',{weekday:'long',day:'numeric',month:'long'})+' · '+d.toLocaleTimeString('pt-PT',{hour:'2-digit',minute:'2-digit'})}
function color(s){let h=0;for(const c of s)h=(h*31+c.charCodeAt(0))>>>0;return COLORS[h%COLORS.length]}
function drawFavs(){$('#favs').innerHTML=favs.map((f,i)=>`<a class="fav" href="${esc(f.u)}" target="_top"><b data-rm="${i}" title="Remover">×</b><i style="background:${color(f.n)}">${esc(f.n.slice(0,2))}</i>${esc(f.n)}</a>`).join('')+'<a class="fav add" href="#" id="add"><i>＋</i>Adicionar</a>'}
$('#eng').innerHTML=Object.entries(ENG).map(([k,v])=>`<option value="${k}"${k===eng?' selected':''}>${v[0]}</option>`).join('');
$('#eng').onchange=e=>{eng=e.target.value;store.set('eng',eng);$('#q').focus()};
$('#f').onsubmit=e=>{e.preventDefault();const q=$('#q').value.trim();if(!q)return;const isUrl=/^(https?:\/\/)?[\w-]+(\.[\w-]+)+(\/\S*)?$/i.test(q)&&!/\s/.test(q);top.location.href=isUrl?(/^https?:/i.test(q)?q:'https://'+q):ENG[eng][1]+encodeURIComponent(q)};
$('#favs').onclick=e=>{const rm=e.target.closest('[data-rm]');if(rm){e.preventDefault();favs.splice(+rm.dataset.rm,1);store.set('favs',favs);return drawFavs()}if(e.target.closest('#add')){e.preventDefault();$('#df').reset();$('#dlg').showModal()}};
$('#dlg').addEventListener('close',()=>{if($('#dlg').returnValue!=='ok')return;let u=$('#du').value.trim();if(!/^https?:/i.test(u))u='https://'+u;favs.push({n:$('#dn').value.trim(),u});store.set('favs',favs);drawFavs()});
greet();setInterval(greet,30000);drawFavs();
