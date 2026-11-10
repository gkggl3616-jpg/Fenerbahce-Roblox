import * as THREE from 'three';
import {EffectComposer} from 'three/addons/postprocessing/EffectComposer.js';
import {RenderPass} from 'three/addons/postprocessing/RenderPass.js';
import {UnrealBloomPass} from 'three/addons/postprocessing/UnrealBloomPass.js';
import {OutputPass} from 'three/addons/postprocessing/OutputPass.js';
import {loadAssets,makePlayer,HAIRS} from './fig.js';
import {buildStadium,makeBall,HL,HW} from './stadium.js';
import {canvas,tex,drawCrest,drawShield,COL} from './gfx.js';

const q=new URLSearchParams(location.search),shot=q.get('shot')||'tier6',W=+(q.get('w')||1600),H=+(q.get('h')||900),PR=+(q.get('pr')||1);
const renderer=new THREE.WebGLRenderer({antialias:true,preserveDrawingBuffer:true});renderer.setSize(W,H);renderer.setPixelRatio(PR);document.body.appendChild(renderer.domElement);
renderer.shadowMap.enabled=true;renderer.shadowMap.type=THREE.PCFSoftShadowMap;
const scene=new THREE.Scene(),cam=new THREE.PerspectiveCamera(40,W/H,.3,4000);
await loadAssets();
const rnd=(s=>()=>{s|=0;s=s+0x6D2B79F5|0;let t=Math.imul(s^s>>>15,1|s);t=t+Math.imul(t^t>>>7,61|t)^t;return((t^t>>>14)>>>0)/4294967296})(shot.length*131+7);
const STY=['kisa','hacimli','sifir','uzun','kisa','hacimli'];
const NAMES=['KAYA','DEMİR','YILMAZ','ARSLAN','ÇELİK','ŞAHİN','AYDIN','KOÇ','POLAT','ÖZTÜRK','KURT'];
function P(o,pose,x,z,rot,y){const p=makePlayer({skin:rnd()*4|0,hair:HAIRS[rnd()*HAIRS.length|0],hairStyle:STY[rnd()*6|0],beard:rnd()<.3,height:1+rnd()*.07,build:.97+rnd()*.08,...o});scene.add(p.root);p.at(x,z,rot,0);p.setPose(pose||'idle');if(y!==undefined)p.root.position.y+=y;return p}
const ball=makeBall();scene.add(ball);ball.position.set(0,.11,0);
// 11'e 11 diziliş (ev sahibi +X'e hücum eder)
function teams(home,away,bx=0,bz=0,skip=[]){
  const F=[[-47,0],[-30,-22],[-34,-8],[-34,8],[-30,22],[-13,-15],[-17,0],[-13,15],[7,-19],[12,1],[7,19]];
  const sh=bx*.45;
  F.forEach(([x,z],i)=>{if(skip.includes('h'+i))return;const gk=i===0;const px=gk?-47:x+sh+(rnd()-.5)*5,pz=z*.9+bz*.2+(rnd()-.5)*4;
    P({kit:gk?'gk':home,num:[1,2,4,5,3,8,6,10,7,9,11][i],name:NAMES[i],gloves:gk,longSleeve:gk,captain:i===6},gk?'idle':(rnd()<.7?(rnd()<.5?'run':'run2'):'idle'),px,pz,gk?Math.PI/2:Math.PI/2+(rnd()-.5)*1.2)});
  F.forEach(([x,z],i)=>{if(skip.includes('a'+i))return;const gk=i===0;const px=gk?47:-x+sh*1.1+(rnd()-.5)*5,pz=-z*.9+bz*.2+(rnd()-.5)*4;
    P({kit:gk?'rivalgk':away,num:[1,2,4,5,3,8,6,10,7,9,11][i],name:'RAKİP',gloves:gk,longSleeve:gk},gk?'idle':(rnd()<.7?(rnd()<.5?'run':'run2'):'idle'),px,pz,gk?-Math.PI/2:-Math.PI/2+(rnd()-.5)*1.2)});
  P({kit:'ref',num:'',name:''},'run',bx-8,bz+9,Math.PI/2);
}
const FWD=Math.PI/2; // +X yönü
let st,post={bloom:.35,exp:null};
const S={
  // --- stadyum evrimi (aynı açı) ---
  tier(n){st=buildStadium(scene,n,{sea:n===6?330:0});teams(n===6?'fb':'club','rival',6,4);const e=st.extent;
    cam.near=2;cam.fov=34;cam.position.set(-e*1.05,e*1.45+6,e*2.05+16);cam.lookAt(0,n>=5?4:0,2);st.focus(0,0,e+25);post.bloom=n>=4?.5:.12},
  hero(){st=buildStadium(scene,6,{sea:330});teams('fb','rival',10,-6);cam.fov=44;cam.position.set(-34,31,60);cam.lookAt(8,2,-14);st.focus(0,0,80);post.bloom=.55},
  exterior(){st=buildStadium(scene,6,{sea:330});teams('fb','rival',0,0);cam.near=2;cam.fov=30;cam.position.set(95,150,300);cam.lookAt(0,8,10);st.focus(0,0,150);post.bloom=.7},
  top(){st=buildStadium(scene,6,{sea:330});teams('fb','rival',0,0);cam.near=2;cam.fov=30;cam.position.set(0,250,.5);cam.lookAt(0,0,0);st.focus(0,0,110);post.bloom=.4},
  // --- saha seviyesi ---
  pitch1(){st=buildStadium(scene,1);teams('club','rival2',-6,8,['h9']);const p=P({kit:'club',num:9,name:'KADIKÖY',skin:1,hair:HAIRS[0],hairStyle:'kisa',crestTxt:'MG'},'run',-8,10,FWD+.2);ball.position.set(-6.9,.11,9.9);
    cam.fov=40;cam.position.set(-17,2.3,17.5);cam.lookAt(-2,1.1,6);st.focus(-6,10,26);post.bloom=.08},
  pitch3(){st=buildStadium(scene,3);teams('club','rival2',10,-4,['h9']);P({kit:'club',num:9,name:'KADIKÖY',skin:1,hair:HAIRS[0],hairStyle:'kisa'},'run',14,-2,FWD-.2);ball.position.set(15.2,.11,-2.3);
    cam.fov=42;cam.position.set(4,3.2,9);cam.lookAt(22,1.4,-10);st.focus(14,-2,30);post.bloom=.3},
  game(){st=buildStadium(scene,6);const p=P({kit:'fb',num:9,name:'KADIKÖY',skin:1,hair:HAIRS[0],hairStyle:'hacimli',captain:true,height:1.04},'run',28,2,FWD);ball.position.set(29.3,.11,2.25);
    P({kit:'rival',num:4,name:'RAKİP'},'run2',36.5,-3.5,-FWD+.4);P({kit:'rival',num:5,name:'RAKİP'},'run',38,7,-FWD-.5);P({kit:'rival',num:3,name:'RAKİP'},'idle',43,0,-FWD);
    P({kit:'rivalgk',num:1,name:'KALECİ',gloves:true,longSleeve:true},'idle',51,.5,-FWD);P({kit:'fb',num:10,name:'YILMAZ'},'run2',33,13,FWD-.3);P({kit:'fb',num:7,name:'ARSLAN'},'run',31,-14,FWD+.2);P({kit:'rival',num:2,name:'RAKİP'},'run',30,-11,-FWD+1);
    cam.fov=46;cam.position.set(22.6,3.3,3.5);cam.lookAt(40,1.6,-.5);st.focus(32,2,22);post.bloom=.5},
  goal(){st=buildStadium(scene,6);P({kit:'rivalgk',num:1,name:'KALECİ',gloves:true,longSleeve:true,skin:2},'dive',51.2,-1.4,-FWD);ball.position.set(52.9,1.55,2.2);
    P({kit:'fb',num:9,name:'KADIKÖY',skin:1,hair:HAIRS[0],hairStyle:'hacimli',captain:true},'shoot',41,-2.5,FWD-.25);P({kit:'rival',num:4,name:'RAKİP'},'run',44,3,-FWD+2.2);P({kit:'rival',num:5,name:'RAKİP'},'run2',46,-6,FWD+.3);P({kit:'fb',num:10,name:'YILMAZ'},'armsup',38,8,FWD);
    cam.fov=42;cam.position.set(57.8,1.9,-6.2);cam.lookAt(46,1.5,1.2);st.focus(46,0,18);post.bloom=.5},
  bicycle(){st=buildStadium(scene,6);const p=P({kit:'fb',num:9,name:'KADIKÖY',skin:1,hair:HAIRS[0],hairStyle:'hacimli',captain:true},'bicycle',40,0,-FWD);ball.position.set(40.55,1.92,.05);
    P({kit:'rival',num:4,name:'RAKİP'},'header',41.6,1.6,-FWD+.6);P({kit:'rival',num:5,name:'RAKİP'},'idle',43.5,-3,-FWD+2.6);P({kit:'rivalgk',num:1,name:'KALECİ',gloves:true,longSleeve:true},'idle',51.3,0,-FWD);P({kit:'fb',num:10,name:'YILMAZ'},'run',36,5,FWD);
    cam.fov=32;cam.position.set(36.8,1.2,-7);cam.lookAt(41,1.55,0);st.focus(40,0,16);post.bloom=.5},
  celebrate(){st=buildStadium(scene,6);P({kit:'fb',num:9,name:'KADIKÖY',skin:1,hair:HAIRS[0],hairStyle:'hacimli',captain:true},'kneeslide',47,-27,FWD+.9);
    P({kit:'fb',num:10,name:'YILMAZ'},'celebrate',43,-24,FWD+.8);P({kit:'fb',num:7,name:'ARSLAN'},'celebrate',41.5,-28,FWD+.6);P({kit:'fb',num:8,name:'ŞAHİN'},'armsup',39,-22,FWD+.7);ball.position.set(30,.11,-20);
    cam.fov=40;cam.position.set(52.5,1.5,-31.5);cam.lookAt(44,1.4,-25);st.focus(44,-25,16);post.bloom=.5},
  // --- karakter ---
  char(){st=studio();const o={kit:'fb',num:9,name:'KADIKÖY',skin:1,hair:HAIRS[0],hairStyle:'hacimli',captain:true,height:1.03,build:1};
    P(o,'idle',-1.25,0,.25);P(o,'idle',0,0,Math.PI+.25);P(o,'idle',1.25,0,-Math.PI/2+.2);ball.position.set(-.75,.11,.55);
    cam.fov=24;cam.position.set(0,1.2,5.9);cam.lookAt(0,.98,0);st.focus(0,0,5);post.bloom=.15},
  creator(){st=studio();P({kit:'fb',num:9,name:'KADIKÖY',skin:1,hair:HAIRS[0],hairStyle:'hacimli',beard:true,captain:true,height:1.03,build:1},'idle',.95,0,-.35);ball.position.set(.4,.11,.5);
    cam.fov=20;cam.position.set(-.6,1.25,5.6);cam.lookAt(-.1,1.0,0);st.focus(0,0,4);post.bloom=.15},
  face(){st=studio();P({kit:'fb',num:9,name:'KADIKÖY',skin:1,hair:HAIRS[0],hairStyle:'hacimli',beard:true,captain:true,height:1.03,build:1},'idle',0,0,-.3);ball.visible=false;
    cam.fov=16;cam.position.set(.5,1.62,2.6);cam.lookAt(0,1.5,0);st.focus(0,0,3);post.bloom=.1},
  custom(){st=studio();
    [{skin:0,hair:HAIRS[3],hairStyle:'uzun',height:.98,build:.95,boot:'#ffe600'},{skin:1,hair:HAIRS[0],hairStyle:'hacimli',beard:true,height:1.03,build:1,captain:true},{skin:2,hair:HAIRS[2],hairStyle:'sifir',height:1.08,build:1.1,boot:'#e33'},
     {skin:3,hair:HAIRS[2],hairStyle:'kisa',height:1.0,build:1.02,longSleeve:true,underColor:'#ffe600'},{skin:1,hairStyle:'kel',beard:true,height:1.05,build:1.06,boot:'#f4f4f4'},{skin:0,hair:HAIRS[4],hairStyle:'kisa',height:.95,build:.94,boot:'#2bd'}]
      .forEach((c,i)=>P({kit:'fb',num:[7,9,4,10,5,11][i],name:NAMES[i],...c},'idle',(i-2.5)*1.02,0,(2.5-i)*.07));
    ball.visible=false;cam.fov=22;cam.position.set(0,1.2,9.6);cam.lookAt(0,.98,0);st.focus(0,0,6);post.bloom=.15},
  kits(){st=studio();[['fb',9,{}],['away',9,{}],['third',9,{}],['gk',1,{gloves:true,longSleeve:true}],['club',9,{crestTxt:'MG'}]].forEach(([k,n,e],i)=>{P({kit:k,num:n,name:'KADIKÖY',skin:1,hair:HAIRS[0],hairStyle:'hacimli',height:1.03,build:1,...e},'idle',(i-2)*1.15,0,(2-i)*.08)});
    ball.visible=false;cam.fov=22;cam.position.set(0,1.2,8.8);cam.lookAt(0,.98,0);st.focus(0,0,6);post.bloom=.15},
  poses(){st=studio();const o={kit:'fb',num:9,name:'KADIKÖY',skin:1,hair:HAIRS[0],hairStyle:'hacimli',height:1.03,build:1};
    ['run','windup','shoot','bicycle','celebrate','kneeslide'].forEach((n,i)=>P(o,n,(i-2.5)*1.75,0,FWD-.5));
    ball.visible=false;cam.fov=24;cam.position.set(0,1.3,13.4);cam.lookAt(0,1.05,0);st.focus(0,0,8);post.bloom=.15},
  // --- antrenman tesisi ---
  training(){
    st=buildStadium(scene,2,{bare:true,mats:{glass:new THREE.MeshStandardMaterial({color:0x7fb4dd,roughness:.1,metalness:.6}),cone:new THREE.MeshStandardMaterial({color:0xff7a00,roughness:.6}),dummy:new THREE.MeshStandardMaterial({color:0xffe600,roughness:.7})},extra:({box,trees,city,tower,R})=>{
      box('cream',0,4,-(HW+16),70,8,12);box('navy',0,8.4,-(HW+16),72,.8,13);box('navy',0,1.2,-(HW+9.9),70,2.4,.3);
      for(let i=-4;i<=4;i++)box('glass',i*7.4,4.6,-(HW+9.95),5.6,3.4,.2);
      trees(70,62,150,(x,z)=>Math.abs(x)<HL+10&&Math.abs(z)<HW+24);city(20,150,300,10,26,.3);
      [[-1,-1],[1,-1],[-1,1],[1,1]].forEach(([a,b])=>tower(a*(HL+10),b*(HW+12),20,3.4));
      for(let i=0;i<4;i++){box('white',16+i*2.2,.5,-8,.06,.06,1.6);box('white',16+i*2.2,.25,-8.8,.06,.5,.06);box('white',16+i*2.2,.25,-7.2,.06,.5,.06)}
      for(let i=0;i<5;i++){box('dummy',34,.95,-6+i*1.5,.12,1.9,.55)}
      for(let i=0;i<8;i++){box('white',-22,.02,-14+i*.55,1.2,.03,.06)}box('white',-22.6,.02,-12,.06,.03,4.4);box('white',-21.4,.02,-12,.06,.03,4.4);
    }});
    for(let i=0;i<9;i++){const c=new THREE.Mesh(new THREE.ConeGeometry(.2,.46,16),new THREE.MeshStandardMaterial({color:0xff6a00,roughness:.6}));c.position.set(-1+i*2.4,.23,5.2+(i%2?1.3:-1.3));c.castShadow=true;scene.add(c)}
    const sg=new THREE.Mesh(new THREE.PlaneGeometry(46,3.4),new THREE.MeshStandardMaterial({map:tex(canvas(2048,150,(g)=>{g.fillStyle='#0b1747';g.fillRect(0,0,2048,150);g.fillStyle='#ffe600';g.font='900 92px "Arial Narrow",Arial';g.textAlign='center';g.textBaseline='middle';g.fillText('FENERBAHÇE ANTRENMAN TESİSLERİ  ★  AKADEMİ',1024,80)}))}));sg.position.set(0,6.3,-(HW+9.8));scene.add(sg);
    const cr=new THREE.Mesh(new THREE.CircleGeometry(2.6,40),new THREE.MeshStandardMaterial({map:tex(canvas(512,512,(g)=>{g.clearRect(0,0,512,512);drawCrest(g,256,256,250)})),transparent:true}));cr.position.set(-29,5.2,-(HW+9.7));scene.add(cr);
    const o={skin:1,hair:HAIRS[0],hairStyle:'hacimli',kit:'third',num:9,name:'KADIKÖY'};
    P(o,'run',-4,6,FWD+.35);ball.position.set(-2.9,.11,6.2);P({kit:'third',num:10,name:'YILMAZ'},'shoot',30.5,-4.6,FWD-.2);P({kit:'third',num:7,name:'ARSLAN'},'run2',15,-8,FWD);P({kit:'third',num:4,name:'DEMİR'},'idle',-23,-11,FWD);
    P({kit:'ref',num:'',name:'',hairStyle:'kisa',skin:0},'idle',6,-2,.3);
    cam.fov=46;cam.position.set(-10,2.7,15);cam.lookAt(4,2.2,-14);st.focus(4,0,40);post.bloom=.1},
  // --- lobi ---
  lobby(){
    st=buildStadium(scene,4,{bare:true,noPitch:true,mats:{glass:new THREE.MeshStandardMaterial({color:0x9fd0ff,roughness:.08,metalness:.5,emissive:0xffe9a8,emissiveIntensity:.9})},extra:({box,trees,city,R,glow})=>{
      // stadyum girişi (kuzey), akademi (batı), kulüp binası (doğu), fenerium + sıralama (güney yanları)
      box('facade',0,13,-58,120,26,10);box('navy',0,5,-52.4,26,10,1.5);box('lamp',0,10.3,-51.6,26,.5,.3);
      box('cream',-62,6,-8,16,12,40);box('navy',-62,12.4,-8,17,.8,41);for(let i=-2;i<=2;i++)box('glass',-53.9,5,-8+i*7.5,.3,6,5.4);
      box('cream',62,7,-8,16,14,40);box('navy',62,14.4,-8,17,.8,41);for(let i=-2;i<=2;i++)box('glass',53.9,6,-8+i*7.5,.3,8,5.4);
      box('navy',-34,5,44,30,10,14);box('glass',-34,4,36.9,26,6,.3);box('roofE',-34,9,36.8,30,2,.4);
      box('dark',34,7,46,24,14,3);
      for(let i=0;i<10;i++){const a=i/10*6.28;box('steel',Math.cos(a)*27,5,Math.sin(a)*27,.22,10,.22);}
      box('conc',0,.5,0,7,1,7);box('navy',0,1.6,0,4.4,1.2,4.4);
      trees(40,75,140,(x,z)=>Math.abs(x)<75&&Math.abs(z)<66);city(120,170,480,14,60,.45);
      for(let i=0;i<14;i++){const a=i/14*6.28+.2,x=Math.cos(a)*40,z=Math.sin(a)*34;box('steel',x,2.6,z,.16,5.2,.16);box('lamp',x,5.3,z,.5,.3,.5);glow(x,5.3,z,5,0xfff0c8,.9)}
    }});
    // zemin deseni + arma
    const fl=new THREE.Mesh(new THREE.CircleGeometry(48,96),new THREE.MeshStandardMaterial({map:tex(canvas(2048,2048,(g)=>{g.fillStyle='#1a2040';g.fillRect(0,0,2048,2048);for(let i=0;i<40;i++)for(let j=0;j<40;j++){g.fillStyle=(i+j)%2?'#232a52':'#1d2348';g.fillRect(i*52,j*52,50,50)}
      g.strokeStyle='#ffe600';g.lineWidth=14;g.beginPath();g.arc(1024,1024,560,0,7);g.stroke();g.lineWidth=6;g.beginPath();g.arc(1024,1024,980,0,7);g.stroke();for(let k=0;k<12;k++){const a=k/12*6.28;g.beginPath();g.moveTo(1024+Math.cos(a)*580,1024+Math.sin(a)*580);g.lineTo(1024+Math.cos(a)*970,1024+Math.sin(a)*970);g.stroke()}drawCrest(g,1024,1024,400)})),roughness:.55}));
    fl.rotation.x=-Math.PI/2;fl.position.y=.02;fl.receiveShadow=true;scene.add(fl);
    const sign=(txt,w,h,x,y,z,ry,fg='#ffe600',bg='#0b1747',em=1)=>{const m=new THREE.Mesh(new THREE.PlaneGeometry(w,h),new THREE.MeshStandardMaterial({map:tex(canvas(1024,Math.round(1024*h/w),(g,cw,ch)=>{g.fillStyle=bg;g.fillRect(0,0,cw,ch);g.fillStyle=fg;g.font=`900 ${ch*.62}px "Arial Narrow",Arial`;g.textAlign='center';g.textBaseline='middle';g.fillText(txt,cw/2,ch/2+4)})),emissive:0xffffff,emissiveIntensity:em}));m.material.emissiveMap=m.material.map;m.position.set(x,y,z);m.rotation.y=ry;scene.add(m)};
    sign('ŞÜKRÜ SARACOĞLU  ★  STADYUM GİRİŞİ',60,5,0,20,-52.9,0);sign('MAÇA ÇIK',22,3,0,11.8,-51.5,0,'#0b1747','#ffe600');
    sign('AKADEMİ · YETENEK AĞACI',30,3,-53.8,10.2,-8,Math.PI/2);sign('KULÜP BİNASI · TRANSFER',30,3,53.8,12.2,-8,-Math.PI/2);sign('FENERIUM',22,2.4,-34,9,36.5,Math.PI,'#0b1747','#ffe600');
    const cr=new THREE.Mesh(new THREE.CircleGeometry(4.2,48),new THREE.MeshStandardMaterial({map:tex(canvas(512,512,(g)=>{g.clearRect(0,0,512,512);drawCrest(g,256,256,250)})),transparent:true,emissive:0xffffff,emissiveIntensity:.5}));cr.material.emissiveMap=cr.material.map;cr.position.set(-45,19,-52.9);scene.add(cr);const cr2=cr.clone();cr2.position.x=45;scene.add(cr2);
    // sıralama ekranı
    const lb=new THREE.Mesh(new THREE.PlaneGeometry(21,12),new THREE.MeshStandardMaterial({map:tex(canvas(1024,585,(g)=>{g.fillStyle='#050b26';g.fillRect(0,0,1024,585);g.fillStyle='#ffe600';g.font='900 64px "Arial Narrow",Arial';g.fillText('DÜNYA SIRALAMASI',40,76);
      [['1','MERT YILDIRIM','92'],['2','L. SANTOS','90'],['3','K. OKAFOR','88'],['4','ARDA TUNÇ','86'],['5','J. MÜLLER','84'],['6','DENİZ AKSOY','79']].forEach((r,i)=>{g.fillStyle=i===0?'#ffe600':'#fff';g.font='900 54px "Arial Narrow",Arial';g.fillText(r[0],50,170+i*72);g.fillText(r[1],140,170+i*72);g.textAlign='right';g.fillText(r[2],980,170+i*72);g.textAlign='left';g.fillStyle='rgba(255,255,255,.15)';g.fillRect(40,190+i*72,944,2)})})),emissive:0xffffff,emissiveIntensity:1.2}));
    lb.material.emissiveMap=lb.material.map;lb.position.set(34,7.5,44.4);lb.rotation.y=Math.PI;scene.add(lb);
    // kupa
    const cup=new THREE.Mesh(new THREE.LatheGeometry([[0,0],[.5,0],[.55,.15],[.18,.3],[.14,.9],[.55,1.5],[.7,2.2],[.62,2.3],[0,2.3]].map(p=>new THREE.Vector2(p[0],p[1])),28),new THREE.MeshStandardMaterial({color:0xffd24a,metalness:1,roughness:.22,emissive:0x8a5a00,emissiveIntensity:.5}));cup.position.set(0,2.2,0);cup.castShadow=true;scene.add(cup);st.glow(0,4,0,9,0xffd070,.7);
    // bayraklar
    const ft=tex(canvas(256,160,(g)=>{for(let i=0;i<8;i++){g.fillStyle=i%2?'#0b1747':'#ffe600';g.fillRect(i*32,0,32,160)}drawCrest(g,128,80,56)}));
    for(let i=0;i<10;i++){const a=i/10*6.28;const m=new THREE.Mesh(new THREE.PlaneGeometry(4.2,2.6,8,1),new THREE.MeshStandardMaterial({map:ft,side:THREE.DoubleSide}));const pa=m.geometry.attributes.position;for(let k=0;k<pa.count;k++)pa.setZ(k,Math.sin(pa.getX(k)*1.6+i)*.3);m.geometry.computeVertexNormals();m.position.set(Math.cos(a)*27+2.1,8.6,Math.sin(a)*27);m.castShadow=true;scene.add(m)}
    const me=P({kit:'fb',num:9,name:'KADIKÖY',skin:1,hair:HAIRS[0],hairStyle:'hacimli',captain:true,height:1.03,build:1},'idle',2,22,Math.PI+.1);
    P({kit:'fb',num:10,name:'YILMAZ'},'run',-9,10,2.6);P({kit:'away',num:7,name:'ARSLAN'},'idle',9,6,-2.4);P({kit:'third',num:4,name:'DEMİR'},'idle',-14,-12,1);P({kit:'club',num:8,name:'ŞAHİN'},'run2',14,-16,-1);P({kit:'gk',num:1,name:'KAYA',gloves:true,longSleeve:true},'idle',-5,-20,.3);
    ball.position.set(1.3,.11,21.2);
    cam.fov=52;cam.position.set(7,4.6,36);cam.lookAt(-1,6.5,-10);st.focus(0,0,60);post.bloom=.6},
};
function studio(){
  scene.background=new THREE.Color(0x0a1238);scene.fog=new THREE.Fog(0x0a1238,14,40);
  scene.add(new THREE.HemisphereLight(0xffffff,0x4a548a,1.25));
  const k=new THREE.DirectionalLight(0xfff4e2,3);k.position.set(4,7,7);k.castShadow=true;k.shadow.mapSize.set(4096,4096);k.shadow.bias=-.0003;k.shadow.normalBias=.02;scene.add(k);scene.add(k.target);
  const r=new THREE.DirectionalLight(0x8fb0ff,2.2);r.position.set(-6,5,-7);scene.add(r);const r2=new THREE.DirectionalLight(0xffe600,.35);r2.position.set(7,3,-6);scene.add(r2);
  const fl=new THREE.Mesh(new THREE.CircleGeometry(30,64),new THREE.MeshStandardMaterial({map:tex(canvas(1024,1024,(g)=>{const gr=g.createRadialGradient(512,512,0,512,512,512);gr.addColorStop(0,'#1c2b80');gr.addColorStop(.25,'#122062');gr.addColorStop(1,'#070d30');g.fillStyle=gr;g.fillRect(0,0,1024,1024);g.strokeStyle='rgba(255,230,0,.5)';g.lineWidth=3;g.beginPath();g.arc(512,512,150,0,7);g.stroke()})),roughness:.45,metalness:.1}));fl.rotation.x=-Math.PI/2;fl.receiveShadow=true;scene.add(fl);
  const bw=new THREE.Mesh(new THREE.PlaneGeometry(60,20),new THREE.MeshStandardMaterial({map:tex(canvas(2048,680,(g)=>{const gr=g.createLinearGradient(0,0,0,680);gr.addColorStop(0,'#060b2a');gr.addColorStop(1,'#13247a');g.fillStyle=gr;g.fillRect(0,0,2048,680);for(let i=0;i<64;i++){g.fillStyle=i%2?'rgba(255,230,0,.07)':'rgba(255,255,255,.02)';g.fillRect(i*32,0,16,680)}})),roughness:1}));bw.position.set(0,10,-9);scene.add(bw);
  return {focus(x,z,rad){const c=k.shadow.camera;c.left=-rad;c.right=rad;c.top=rad;c.bottom=-rad;c.near=1;c.far=40;c.updateProjectionMatrix()},mood:{exp:1.05,night:0}};
}
const m=shot.match(/^tier(\d)$/);if(m)S.tier(+m[1]);else S[shot]();
cam.updateProjectionMatrix();
renderer.toneMapping=THREE.NoToneMapping;
const rt=new THREE.WebGLRenderTarget(W*PR,H*PR,{type:THREE.HalfFloatType,samples:4});
const comp=new EffectComposer(renderer,rt);comp.addPass(new RenderPass(scene,cam));
comp.addPass(new UnrealBloomPass(new THREE.Vector2(W,H),post.bloom,.7,.92));
renderer.toneMapping=THREE.ACESFilmicToneMapping;renderer.toneMappingExposure=post.exp||st.mood.exp||1;
comp.addPass(new OutputPass());
const t0=performance.now();comp.render();comp.render();
console.log('rendered',shot,'crowd',st.crowd||0,'ms',Math.round(performance.now()-t0));
window.__done=true;
