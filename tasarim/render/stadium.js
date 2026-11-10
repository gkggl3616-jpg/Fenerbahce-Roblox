// 6 kademeli stadyum: mahalle sahasından Kadıköy'e
import * as THREE from 'three';
import {canvas,tex,drawCrest,drawShield,stars,COL} from './gfx.js';

export const HL=52.5,HW=34;
const rng=s=>()=>{s|=0;s=s+0x6D2B79F5|0;let t=Math.imul(s^s>>>15,1|s);t=t+Math.imul(t^t>>>7,61|t)^t;return((t^t>>>14)>>>0)/4294967296};
const hex=h=>new THREE.Color(h);

export const TIERS={
  1:{name:'Mahalle Sahası',lig:'Amatör Lig',cap:150},
  2:{name:'İlçe Stadı',lig:'3. Lig',cap:1800},
  3:{name:'Şehir Stadı',lig:'2. Lig',cap:8500},
  4:{name:'Modern Stadyum',lig:'1. Lig',cap:21000},
  5:{name:'Arena',lig:'Süper Lig',cap:34000},
  6:{name:'Şükrü Saracoğlu',lig:'Fenerbahçe',cap:47800},
};
const MOODS={
  1:{top:'#7f97b3',hor:'#cfd6d8',sun:[.45,.8,.35],sunC:'#fff6e8',sunI:2.3,hs:'#d5deea',hg:'#5a6650',hi:1.15,fog:[320,1100],exp:1.0,night:0},
  2:{top:'#2f74cf',hor:'#c4def5',sun:[.5,.72,.42],sunC:'#fff0d0',sunI:3.1,hs:'#cfe2ff',hg:'#4d6b3c',hi:.95,fog:[380,1300],exp:1.0,night:0},
  3:{top:'#3a5fae',hor:'#ffb873',sun:[-.78,.36,.42],sunC:'#ffc084',sunI:3.8,hs:'#c9d6ff',hg:'#6a5a48',hi:1.15,fog:[300,1200],exp:1.25,night:.15,glow:1},
  4:{top:'#10183f',hor:'#a0607a',sun:[-.7,.6,.4],sunC:'#c9d3ff',sunI:1.5,hs:'#8f9fe0',hg:'#2a3040',hi:.7,fog:[320,1200],exp:1.15,night:.7},
  5:{top:'#040817',hor:'#121b45',sun:[.35,.85,.5],sunC:'#f4f7ff',sunI:2.3,hs:'#8b9be0',hg:'#1c2a22',hi:.6,fog:[340,1300],exp:1.2,night:1},
  6:{top:'#02051a',hor:'#172060',sun:[.35,.85,.5],sunC:'#f6f8ff',sunI:2.5,hs:'#93a3ea',hg:'#1c2a22',hi:.62,fog:[360,1400],exp:1.22,night:1},
};

function glowTex(){return tex(canvas(128,128,(g)=>{const r=g.createRadialGradient(64,64,0,64,64,64);r.addColorStop(0,'rgba(255,255,255,1)');r.addColorStop(.25,'rgba(255,250,230,.55)');r.addColorStop(1,'rgba(255,240,200,0)');g.fillStyle=r;g.fillRect(0,0,128,128)}))}

function pitchTexture(tier,R){
  const S=32,W=128,H=88;
  return tex(canvas(W*S,H*S,(g,w,h)=>{
    const X=m=>(m+W/2)*S,Z=m=>(m+H/2)*S;
    const base=tier===1?'#5f8a3c':tier===2?'#3f8f3e':'#2f8f43';
    g.fillStyle=tier===1?'#7b6a4c':tier<4?'#3b7a39':'#27703a';g.fillRect(0,0,w,h);
    g.fillStyle=base;g.fillRect(X(-HL-3),Z(-HW-3),(105+6)*S,(68+6)*S);
    if(tier>=2){const n=18,sw=105/n;for(let i=0;i<n;i++){if(i%2)continue;g.fillStyle=tier===2?'rgba(255,255,255,.035)':'rgba(255,255,255,.075)';g.fillRect(X(-HL+i*sw),Z(-HW-3),sw*S,(68+6)*S)}}
    if(tier>=5){const n=12,sw=68/n;for(let i=0;i<n;i++){if(i%2)continue;g.fillStyle='rgba(0,0,0,.07)';g.fillRect(X(-HL-3),Z(-HW+i*sw),(105+6)*S,sw*S)}}
    // çim dokusu
    for(let i=0;i<70000;i++){const x=R()*w,y=R()*h;g.fillStyle=R()<.5?'rgba(255,255,220,.035)':'rgba(0,30,0,.05)';g.fillRect(x,y,2+R()*3,6+R()*10)}
    if(tier<=2){ // yıpranma
      const spots=tier===1?[[-47,0,9,12],[47,0,9,12],[0,0,7,7],[-20,10,10,6],[22,-14,12,7],[-30,-20,8,5],[35,20,7,6]]:[[-48,0,5,8],[48,0,5,8],[0,0,4,4]];
      spots.forEach(([x,z,rx,rz])=>{for(let k=0;k<260;k++){const a=R()*6.28,d=Math.sqrt(R());g.fillStyle=`rgba(${120+R()*30|0},${98+R()*20|0},${62+R()*20|0},${tier===1?.16:.09})`;g.beginPath();g.ellipse(X(x+Math.cos(a)*rx*d),Z(z+Math.sin(a)*rz*d),S*(1+R()*2.2),S*(.8+R()*1.6),0,0,7);g.fill()}});
    }
    // çizgiler
    g.strokeStyle=tier===1?'rgba(255,255,255,.72)':'rgba(255,255,255,.96)';g.lineWidth=tier===1?3.2:4;g.lineCap='square';
    const rect=(x1,z1,x2,z2)=>g.strokeRect(X(x1),Z(z1),(x2-x1)*S,(z2-z1)*S);
    rect(-HL,-HW,HL,HW);g.beginPath();g.moveTo(X(0),Z(-HW));g.lineTo(X(0),Z(HW));g.stroke();
    g.beginPath();g.arc(X(0),Z(0),9.15*S,0,7);g.stroke();
    g.fillStyle='#fff';g.beginPath();g.arc(X(0),Z(0),.22*S,0,7);g.fill();
    [-1,1].forEach(s=>{
      const gx=s*HL;rect(Math.min(gx,gx-s*16.5),-20.16,Math.max(gx,gx-s*16.5),20.16);rect(Math.min(gx,gx-s*5.5),-9.16,Math.max(gx,gx-s*5.5),9.16);
      g.beginPath();g.arc(X(gx-s*11),Z(0),.2*S,0,7);g.fill();
      g.beginPath();const a0=Math.acos(5.5/9.15);if(s>0)g.arc(X(gx-11),Z(0),9.15*S,Math.PI-a0,Math.PI+a0);else g.arc(X(gx+11),Z(0),9.15*S,-a0,a0);g.stroke();
      [-1,1].forEach(t=>{g.beginPath();const cx=X(gx),cz=Z(t*HW);const st=s>0?(t>0?Math.PI:Math.PI/2):(t>0?-Math.PI/2:0);g.arc(cx,cz,S,st,st+Math.PI/2);g.stroke()});
    });
  }),{anisotropy:16});
}

function windowTex(lit,R,night){
  return tex(canvas(128,256,(g,w,h)=>{g.fillStyle=night?'#151a2c':'#b9b4a8';g.fillRect(0,0,w,h);
    for(let y=0;y<16;y++)for(let x=0;x<6;x++){const on=R()<lit;g.fillStyle=night?(on?`rgba(255,${200+R()*40|0},${120+R()*60|0},1)`:'#0a0e1c'):(R()<.5?'#5d6b78':'#6f7f8c');g.fillRect(8+x*20,6+y*16,12,9)}}),{wrapS:THREE.RepeatWrapping,wrapT:THREE.RepeatWrapping});
}
function textTex(str,w,h,bg,fg,font,stroke){return tex(canvas(w,h,(g)=>{if(bg){g.fillStyle=bg;g.fillRect(0,0,w,h)}g.font=font;g.textAlign='center';g.textBaseline='middle';g.fillStyle=fg;if(stroke){g.strokeStyle=stroke;g.lineWidth=8;g.lineJoin='round';g.strokeText(str,w/2,h/2)}g.fillText(str,w/2,h/2)}))}
function ledTex(R){
  const items=['FENERBAHÇE','★ 1907 ★','KADIKÖY','SARI LACİVERT','FENERIUM','FENER KARİYER','ÇUBUKLU','★★★★★'];
  return tex(canvas(4096,64,(g,w,h)=>{g.fillStyle='#06103a';g.fillRect(0,0,w,h);let x=20;let i=0;g.textBaseline='middle';g.font='900 44px "Arial Narrow",Arial';
    while(x<w-200){const s=items[i++%items.length];const m=g.measureText(s).width;const inv=i%3===0;if(inv){g.fillStyle='#ffe600';g.fillRect(x-14,0,m+28,h)}g.fillStyle=inv?'#0b1747':'#ffe600';g.fillText(s,x,h/2+2);x+=m+60}}),{wrapS:THREE.RepeatWrapping});
}
function scoreTex(home,away,score,min,fb){
  return tex(canvas(1024,384,(g,w,h)=>{g.fillStyle='#050b26';g.fillRect(0,0,w,h);g.fillStyle='#0b1747';g.fillRect(12,12,w-24,h-24);
    g.textAlign='center';g.textBaseline='middle';
    if(fb)drawCrest(g,150,150,95);else drawShield(g,150,140,80,'MG');
    g.beginPath();g.arc(w-150,150,88,0,7);g.fillStyle='#0f8f80';g.fill();g.fillStyle='#fff';g.font='900 70px Arial';g.fillText('R',w-150,154);
    g.fillStyle='#ffe600';g.font='900 150px "Arial Narrow",Arial';g.fillText(score,w/2,150);
    g.fillStyle='#fff';g.font='900 46px "Arial Narrow",Arial';g.fillText(home,230,300);g.fillText(away,w-230,300);
    g.fillStyle='#ffe600';g.font='900 56px "Arial Narrow",Arial';g.fillText(min,w/2,300);}));
}

export function buildStadium(scene,tier,opt={}){
  const R=rng(tier*7919+13),M=MOODS[tier],night=M.night,club=opt.club||'MODA GENÇLİK';
  const out={tier,mood:M,info:TIERS[tier]};const T=opt.bare?0:tier;
  /* gökyüzü + ışık */
  scene.fog=new THREE.Fog(hex(M.hor).lerp(hex(M.top),.35),M.fog[0],M.fog[1]);
  const sunDir=new THREE.Vector3(...M.sun).normalize();
  const sky=new THREE.Mesh(new THREE.SphereGeometry(1500,32,16),new THREE.ShaderMaterial({side:THREE.BackSide,depthWrite:false,fog:false,
    uniforms:{top:{value:hex(M.top)},hor:{value:hex(M.hor)},sd:{value:sunDir},glow:{value:M.glow||0}},
    vertexShader:'varying vec3 d;void main(){d=normalize(position);gl_Position=projectionMatrix*modelViewMatrix*vec4(position,1.);}',
    fragmentShader:'varying vec3 d;uniform vec3 top,hor,sd;uniform float glow;void main(){float t=pow(clamp(d.y,0.,1.),.45);vec3 c=mix(hor,top,t);float s=max(dot(normalize(d),sd),0.);c+=glow*vec3(1.,.55,.2)*(pow(s,6.)*.5+pow(s,90.)*1.5);if(d.y<0.)c=mix(hor,hor*.6,clamp(-d.y*4.,0.,1.));gl_FragColor=vec4(c,1.);}'}));
  scene.add(sky);
  scene.add(new THREE.HemisphereLight(hex(M.hs),hex(M.hg),M.hi));
  const sun=new THREE.DirectionalLight(hex(M.sunC),M.sunI);sun.position.copy(sunDir).multiplyScalar(260);sun.castShadow=true;sun.shadow.mapSize.set(4096,4096);sun.shadow.bias=-.0004;sun.shadow.normalBias=.03;
  scene.add(sun);scene.add(sun.target);
  out.focus=(x,z,r)=>{sun.target.position.set(x,0,z);sun.position.set(x,0,z).addScaledVector(sunDir,260);const c=sun.shadow.camera;c.left=-r;c.right=r;c.top=r;c.bottom=-r;c.near=20;c.far=600;c.updateProjectionMatrix();sun.shadow.radius=r>60?2:3;sun.shadow.bias=r>70?-.0012:-.0004;sun.shadow.normalBias=r>70?.25:.03};
  out.focus(0,0,95);
  if(night>.5){const f2=new THREE.DirectionalLight(0xeaf0ff,M.sunI*.75);f2.position.set(-120,220,-150);scene.add(f2);const f3=new THREE.DirectionalLight(0xeaf0ff,M.sunI*.4);f3.position.set(-150,160,160);scene.add(f3)}
  if(night>.5){ // yıldızlar + şehir ışıkları
    const sp=[];for(let i=0;i<900;i++){const a=R()*6.28,e=.08+R()*1.4;sp.push(Math.cos(a)*Math.cos(e)*1400,Math.sin(e)*1400,Math.sin(a)*Math.cos(e)*1400)}
    const sg=new THREE.BufferGeometry();sg.setAttribute('position',new THREE.Float32BufferAttribute(sp,3));scene.add(new THREE.Points(sg,new THREE.PointsMaterial({color:0xffffff,size:2.2,sizeAttenuation:false,fog:false,transparent:true,opacity:.8})));
  }
  const glowT=glowTex();
  const glow=(x,y,z,s,c=0xfff3d0,o=1)=>{const sp=new THREE.Sprite(new THREE.SpriteMaterial({map:glowT,color:c,blending:THREE.AdditiveBlending,depthWrite:false,transparent:true,opacity:o,fog:false}));sp.position.set(x,y,z);sp.scale.setScalar(s);scene.add(sp);return sp};

  /* zemin + saha */
  const groundC=tier===1?'#6f6a55':tier<=3?'#4e6a3f':'#2a2d36';
  const ground=new THREE.Mesh(new THREE.PlaneGeometry(4000,4000),new THREE.MeshStandardMaterial({color:groundC,roughness:1}));ground.rotation.x=-Math.PI/2;ground.position.y=-.6;ground.receiveShadow=true;scene.add(ground);
  const pitch=new THREE.Mesh(new THREE.PlaneGeometry(128,88),new THREE.MeshStandardMaterial({map:pitchTexture(tier,R),roughness:.95}));pitch.rotation.x=-Math.PI/2;pitch.receiveShadow=true;if(!opt.noPitch)scene.add(pitch);

  if(!opt.noPitch){const rd=new THREE.MeshStandardMaterial({color:tier===1?0x55524a:0x33363f,roughness:.95});const ln=new THREE.MeshBasicMaterial({color:0xd8d8d0});
    const zr=tier===1?HW+24:tier===2?HW+34:tier===3?HW+48:tier===4?HW+62:HW+118,xr=tier===1?HL+22:tier===2?HL+30:tier===3?HL+44:tier===4?HL+58:HL+86;
    [[0,zr,2400,11,0],[-xr,0,11,2400,1]].forEach(([x,z,w,d,v])=>{const m=new THREE.Mesh(new THREE.PlaneGeometry(w,d),rd);m.rotation.x=-Math.PI/2;m.position.set(x,-.2,z);m.receiveShadow=true;scene.add(m);
      for(let k=-300;k<300;k+=9){const l=new THREE.Mesh(new THREE.PlaneGeometry(v?.25:4,v?4:.25),ln);l.rotation.x=-Math.PI/2;l.position.set(v?x:k,-.12,v?k:z);scene.add(l)}});
    if(tier>=2){const ap=new THREE.Mesh(new THREE.PlaneGeometry((xr-6)*2,(zr-6)*2),new THREE.MeshStandardMaterial({color:tier<=3?0x7c7768:0x3f434d,roughness:1}));ap.rotation.x=-Math.PI/2;ap.position.y=-.3;ap.receiveShadow=true;scene.add(ap)}}
  /* geometri toplayıcı */
  const G={};const quad=(k,a,b,c,d)=>{(G[k]=G[k]||[]).push(...a,...b,...c,...a,...c,...d)};
  const box=(k,x,y,z,sx,sy,sz)=>{const x0=x-sx/2,x1=x+sx/2,y0=y-sy/2,y1=y+sy/2,z0=z-sz/2,z1=z+sz/2;
    quad(k,[x0,y0,z1],[x1,y0,z1],[x1,y1,z1],[x0,y1,z1]);quad(k,[x1,y0,z0],[x0,y0,z0],[x0,y1,z0],[x1,y1,z0]);quad(k,[x1,y0,z1],[x1,y0,z0],[x1,y1,z0],[x1,y1,z1]);
    quad(k,[x0,y0,z0],[x0,y0,z1],[x0,y1,z1],[x0,y1,z0]);quad(k,[x0,y1,z1],[x1,y1,z1],[x1,y1,z0],[x0,y1,z0]);quad(k,[x0,y0,z0],[x1,y0,z0],[x1,y0,z1],[x0,y0,z1])};
  const seats=[],torsos=[],heads=[];
  const TH={N:0,S:Math.PI,E:-Math.PI/2,W:Math.PI/2};
  const frame=side=>{const th=TH[side],base=(side==='N'||side==='S')?HW:HL,other=(side==='N'||side==='S')?HL:HW;
    const u=[Math.cos(th),0,-Math.sin(th)],o=[-Math.sin(th),0,-Math.cos(th)];
    return {th,base,other,P:(uu,d,y)=>[u[0]*uu+o[0]*(base+d),y,u[2]*uu+o[2]*(base+d)]}};
  const casual=[0x8a8f98,0x3b5b8c,0xb23b3b,0xe6e6e6,0x2f2f35,0x4f7a4a,0xc9a24a,0x6b4f3a,0x7a6fb0];
  const skinT=[0xf1c9a5,0xd9a57c,0xa9744f,0x6e4a34];
  const fanColor=(share)=>{const r=R();if(r<share*.55)return 0xffe600;if(r<share)return 0x0b1747;if(r<share+.06)return 0xffffff;return casual[R()*casual.length|0]};

  function stand(o){
    const f=frame(o.side),rowD=o.rowD||.82,rise=o.rise||.42,y0=o.y0??1.1,gap=o.gap,rows=o.rows,D=rows*rowD,H=rows*rise;
    const hl=d=>o.miter?f.other+gap+d:o.len/2;
    const k=o.mat||'conc';
    const a=f.P(-hl(0),gap,o.yb||0),b=f.P(hl(0),gap,o.yb||0),c=f.P(hl(0),gap,y0),d=f.P(-hl(0),gap,y0),e=f.P(hl(D),gap+D,y0+H),g=f.P(-hl(D),gap+D,y0+H),h=f.P(hl(D),gap+D,o.yb||0),i=f.P(-hl(D),gap+D,o.yb||0);
    quad(o.fascia||'navy',a,b,c,d);quad(k,d,c,e,g);quad('dark',h,i,g,e);
    if(!o.miter){quad('dark',b,h,e,c);quad('dark',i,a,d,g)}
    // basamak çizgileri için koltuk + seyirci
    for(let r=0;r<rows;r++){
      const dd=(r+.55)*rowD,yy=y0+(r+.5)*rise,L=hl(dd);
      for(let u=-L+.4;u<L-.3;u+=.56){
        const am=((u+500)%(o.aisle||13));if(am<1.0)continue;
        const p=f.P(u,gap+dd,yy);
        const occ=typeof o.occ==='function'?o.occ(u,r,L):o.occ;
        if(R()<occ){const col=o.color?o.color(u,r,L,rows):fanColor(o.share??.3);const up=R()<(o.standing||.12)?.22:0;
          torsos.push([p[0],p[1]+.32+up,p[2],f.th+(R()-.5)*.5,col,.9+R()*.25]);heads.push([p[0],p[1]+.74+up+R()*.05,p[2],skinT[R()*4|0]])}
        else{seats.push([p[0],p[1]+.22,p[2],f.th,o.seat?o.seat(u,r,L):0x2a3a8c])}
      }
    }
    return {D,H,top:y0+H,back:gap+D,f,hl};
  }
  function roof(side,dFront,dBack,yF,yB,miter,len,o={}){
    const f=frame(side),hl=d=>miter?f.other+d:len/2,t=.6;
    const a=f.P(-hl(dFront),dFront,yF),b=f.P(hl(dFront),dFront,yF),c=f.P(hl(dBack),dBack,yB),d=f.P(-hl(dBack),dBack,yB);
    const up=p=>[p[0],p[1]+t,p[2]];
    quad('roofU',a,d,c,b);quad('roof',up(a),up(b),up(c),up(d));quad('roofE',a,b,up(b),up(a));
    // kafes kirişler + arka kolonlar
    const L=hl(dFront);for(let u=-L+3;u<L-2;u+=o.step||9){
      const p1=f.P(u,dFront+.5,yF-.5),p2=f.P(u,dBack-.5,yB-.5);const mx=(p1[0]+p2[0])/2,my=(p1[1]+p2[1])/2,mz=(p1[2]+p2[2])/2;
      const horiz=side==='N'||side==='S';box('steel',mx,my,mz,horiz?.35:Math.abs(p1[0]-p2[0]),.9,horiz?Math.abs(p1[2]-p2[2]):.35);
      const pc=f.P(u,dBack-.6,yB/2);box('steel',pc[0],pc[1],pc[2],.5,yB,.5);
      if(night>.4){const pl=f.P(u,dFront+.8,yF-.25);box('lamp',pl[0],pl[1],pl[2],horiz?3.2:.5,.35,horiz?.5:3.2);if(o.glow!==false)glow(pl[0],pl[1]-.2,pl[2],o.gs||9,0xfff6dd,.9)}
    }
  }
  function tower(x,z,h,head){
    box('steel',x,h/2,z,.9,h,.9);const dir=new THREE.Vector3(-x,0,-z).normalize();
    const m=new THREE.Mesh(new THREE.BoxGeometry(head,head*.6,.6),new THREE.MeshStandardMaterial({color:night>.3?0xfffbe8:0x9aa0a8,emissive:night>.3?0xfff2cc:0x000000,emissiveIntensity:night>.3?3.5:0,roughness:.5}));
    m.position.set(x,h+head*.2,z);m.lookAt(0,h*.2,0);scene.add(m);
    if(night>.3)glow(x+dir.x*1,h+head*.2,z+dir.z*1,head*3,0xfff2d0,.9);
  }
  function fence(dist,hh){
    const ft=tex(canvas(64,64,(g)=>{g.clearRect(0,0,64,64);g.strokeStyle='rgba(150,155,160,.95)';g.lineWidth=2.4;for(let i=-64;i<128;i+=16){g.beginPath();g.moveTo(i,0);g.lineTo(i+64,64);g.stroke();g.beginPath();g.moveTo(i+64,0);g.lineTo(i,64);g.stroke()}}),{wrapS:THREE.RepeatWrapping,wrapT:THREE.RepeatWrapping});
    const mat=new THREE.MeshBasicMaterial({map:ft,transparent:true,side:THREE.DoubleSide,alphaTest:.3,color:0xc8ccd0});
    [['x',HW+dist,HL+dist],['z',HL+dist,HW+dist]].forEach(([ax,off,half])=>[-1,1].forEach(s=>{
      const t=ft.clone();t.repeat.set(half*2/1.2,hh/1.2);const m=new THREE.Mesh(new THREE.PlaneGeometry(half*2,hh),mat.clone());m.material.map=t;m.position.y=hh/2;
      if(ax==='x')m.position.z=s*off;else{m.position.x=s*off;m.rotation.y=Math.PI/2}scene.add(m);
      for(let u=-half;u<=half;u+=4)ax==='x'?box('steel',u,hh/2,s*off,.09,hh,.09):box('steel',s*off,hh/2,u,.09,hh,.09);
    }));
  }
  function trees(n,rmin,rmax,avoid){
    const tg=new THREE.CylinderGeometry(.25,.35,3,6),fg=new THREE.IcosahedronGeometry(2.4,1);
    const tm=new THREE.InstancedMesh(tg,new THREE.MeshStandardMaterial({color:0x5a4330,roughness:1}),n),fm=new THREE.InstancedMesh(fg,new THREE.MeshStandardMaterial({color:0xffffff,roughness:1,flatShading:true}),n);
    const o=new THREE.Object3D(),c=new THREE.Color();let i=0,guard=0;
    while(i<n&&guard++<n*40){const a=R()*6.28,r=rmin+R()*(rmax-rmin),x=Math.cos(a)*r*1.25,z=Math.sin(a)*r;if(avoid&&avoid(x,z))continue;const s=.8+R()*.9;
      o.position.set(x,1.5*s,z);o.scale.setScalar(s);o.rotation.set(0,0,0);o.updateMatrix();tm.setMatrixAt(i,o.matrix);
      o.position.set(x,(3+1.6)*s,z);o.scale.set(s*(.9+R()*.4),s*(1+R()*.5),s*(.9+R()*.4));o.rotation.y=R()*6;o.updateMatrix();fm.setMatrixAt(i,o.matrix);
      fm.setColorAt(i,c.setHSL(.27+R()*.08,.45+R()*.2,(night>.5?.1:.26)+R()*.1));i++}
    tm.count=fm.count=i;tm.castShadow=fm.castShadow=true;fm.receiveShadow=true;scene.add(tm,fm);
  }
  function city(n,rmin,rmax,hmin,hmax,lit){
    const wt=windowTex(lit,R,night>.5);
    const mat=new THREE.MeshStandardMaterial({map:wt,roughness:.9,emissiveMap:night>.5?wt:null,emissive:night>.5?0xffffff:0x000000,emissiveIntensity:night>.5?.9:0});
    const im=new THREE.InstancedMesh(new THREE.BoxGeometry(1,1,1),mat,n),o=new THREE.Object3D(),c=new THREE.Color();let i=0,guard=0;
    while(i<n&&guard++<n*30){const a=R()*6.28,r=rmin+R()*(rmax-rmin),x=Math.cos(a)*r*1.2,z=Math.sin(a)*r;if(opt.sea&&z<-opt.sea)continue;
      const w=10+R()*16,d=10+R()*14,h=hmin+R()*(hmax-hmin);o.position.set(x,h/2,z);o.scale.set(w,h,d);o.rotation.y=(R()*4|0)*Math.PI/2+(R()-.5)*.2;o.updateMatrix();im.setMatrixAt(i,o.matrix);
      im.setColorAt(i,night>.5?c.setRGB(.9,.9,1):c.setHSL(.08+R()*.06,.12+R()*.1,.62+R()*.2));i++}
    im.count=i;im.castShadow=tier<4;im.receiveShadow=true;scene.add(im);
  }

  if(!opt.noPitch){
  /* kale + bayrak + panolar */
  const netT=tex(canvas(64,64,(g)=>{g.clearRect(0,0,64,64);g.strokeStyle='rgba(255,255,255,.85)';g.lineWidth=3;g.strokeRect(0,0,64,64)}),{wrapS:THREE.RepeatWrapping,wrapT:THREE.RepeatWrapping});
  const postM=new THREE.MeshStandardMaterial({color:0xffffff,roughness:.35});
  [-1,1].forEach(s=>{const x=s*HL,W=7.32,Hh=2.44,Dp=2.2;
    [-W/2,W/2].forEach(z=>{const p=new THREE.Mesh(new THREE.CylinderGeometry(.06,.06,Hh,12),postM);p.position.set(x,Hh/2,z);p.castShadow=true;scene.add(p);
      const b=new THREE.Mesh(new THREE.CylinderGeometry(.03,.03,Math.hypot(Dp,Hh),8),postM);b.position.set(x+s*Dp/2,Hh/2,z);b.rotation.z=s*Math.atan2(Dp,Hh);scene.add(b)});
    const cb=new THREE.Mesh(new THREE.CylinderGeometry(.06,.06,W+.12,12),postM);cb.rotation.x=Math.PI/2;cb.position.set(x,Hh,0);cb.castShadow=true;scene.add(cb);
    const nm=(w,h)=>{const t=netT.clone();t.repeat.set(w/.14,h/.14);return new THREE.MeshBasicMaterial({map:t,transparent:true,side:THREE.DoubleSide,depthWrite:false,opacity:.75})};
    const sl=Math.hypot(Dp,Hh),back=new THREE.Mesh(new THREE.PlaneGeometry(W,sl),nm(W,sl));back.position.set(x+s*Dp/2,Hh/2,0);back.rotation.y=Math.PI/2;back.rotation.order='YXZ';back.rotation.x=-s*Math.atan2(Dp,Hh)*(1);scene.add(back);
    [-1,1].forEach(t=>{const sh=new THREE.Shape();sh.moveTo(0,0);sh.lineTo(s*Dp,0);sh.lineTo(0,Hh);const m=new THREE.Mesh(new THREE.ShapeGeometry(sh),nm(Dp,Hh));m.position.set(x,0,t*W/2);scene.add(m)});
  });
  [[-1,-1],[1,-1],[-1,1],[1,1]].forEach(([a,b])=>{box('white',a*HL,.75,b*HW,.04,1.5,.04);const fl=new THREE.Mesh(new THREE.PlaneGeometry(.45,.3),new THREE.MeshStandardMaterial({color:0xffe600,side:THREE.DoubleSide}));fl.position.set(a*HL+.22,1.35,b*HW);scene.add(fl)});
  if(tier>=3){const lt=ledTex(R);const lm=l=>{const t=lt.clone();t.repeat.set(l/128,1);return new THREE.MeshStandardMaterial({map:t,emissiveMap:t,emissive:0xffffff,emissiveIntensity:night>.5?1.25:.45,roughness:.6})};
    const add=(x,z,l,ry)=>{const m=new THREE.Mesh(new THREE.BoxGeometry(l,.95,.18),lm(l));m.position.set(x,.5,z);m.rotation.y=ry;scene.add(m)};
    add(0,-(HW+4.2),100,0);add(-(HL+5),0,60,Math.PI/2);add(HL+5,0,60,-Math.PI/2);if(tier>=5)add(0,HW+4.6,100,Math.PI);
  }else if(tier===2){for(let i=-3;i<=3;i++){const m=new THREE.Mesh(new THREE.BoxGeometry(9,.9,.1),new THREE.MeshStandardMaterial({color:[0xffe600,0x0b1747,0xffffff,0xb23b3b][(i+4)%4],roughness:.8}));m.position.set(i*11,.5,-(HW+3.6));scene.add(m)}}
  // yedek kulübeleri
  if(tier>=2){[-14,14].forEach(x=>{box('navy',x,.45,-(HW+3)+(tier>=3?1.4:0),9,.5,1.2);const gl=new THREE.Mesh(new THREE.CylinderGeometry(1.5,1.5,9.4,12,1,true,0,Math.PI*.6),new THREE.MeshStandardMaterial({color:0x9fc4e8,transparent:true,opacity:.35,side:THREE.DoubleSide,roughness:.1}));gl.rotation.z=Math.PI/2;gl.rotation.y=0;gl.position.set(x,.9,-(HW+3.4)+(tier>=3?1.4:0));gl.rotation.x=-.2;scene.add(gl)})}

  }
  /* kademeye göre yapı */
  const fbSeat=(u,r)=>((Math.floor((u+400)/7))%2?0xffe600:0x10238a);
  const stripes=w=>(u)=>((Math.floor((u+400)/w))%2?0xffe600:0x0b1747);
  const maskFn=(str,pad=.1)=>{const cw=420,chh=48,c=canvas(cw,chh,(g)=>{g.fillStyle='#000';g.fillRect(0,0,cw,chh);g.fillStyle='#fff';g.font=`900 ${chh*.98}px "Arial Black",Arial`;g.textAlign='center';g.textBaseline='middle';const m=g.measureText(str).width;g.save();g.translate(cw/2,chh/2+2);g.scale(Math.min(3,cw*(1-pad)/m),1);g.fillText(str,0,0);g.restore()});
    const d=c.getContext('2d').getImageData(0,0,cw,chh).data;return (u,r,L,rows)=>{const x=Math.min(cw-1,Math.max(0,((u+L)/(2*L))*cw|0)),y=Math.min(chh-1,Math.max(0,((1-(r+.5)/rows))*chh|0));return d[(y*cw+x)*4]>128?0xffe600:0x0b1747}};
  let extent=60;
  extent=55;
  if(T===1){
    fence(4.5,2.6);
    const s=stand({side:'N',len:16,rows:3,gap:7.5,y0:.5,occ:.55,share:.25,mat:'wood',fascia:'wood',seat:()=>0x8a6a44,aisle:99});
    // kulüp binası (konteyner) + tabela
    box('cream',-30,1.5,-(HW+11),10,3,3.2);box('navy',-30,3.15,-(HW+11),10.4,.3,3.6);
    const sg=new THREE.Mesh(new THREE.PlaneGeometry(7,1.1),new THREE.MeshStandardMaterial({map:textTex(club+' SK','1024','160','#0b1747','#ffe600','900 96px "Arial Narrow",Arial')}));sg.position.set(-30,2.3,-(HW+11)+1.62);scene.add(sg);
    [[-12,HW+6.5],[12,HW+6.5]].forEach(([x,z])=>{box('wood',x,.45,z,5,.12,.5);box('steel',x-2,.22,z,.1,.45,.4);box('steel',x+2,.22,z,.1,.45,.4)});
    [[-HL-8,-HW-8],[HL+8,-HW-8],[-HL-8,HW+8],[HL+8,HW+8]].forEach(([x,z])=>{box('steel',x,5,z,.25,10,.25);box('lampOff',x,10,z,1.4,.5,.6)});
    for(let i=0;i<9;i++){box(['carR','carW','carB','carG'][i%4],22+i*5.2,.7,HW+16+(i%2)*.4,4.2,1.3,1.9)}
    trees(46,58,120,(x,z)=>Math.abs(x)<HL+12&&Math.abs(z)<HW+12);city(40,95,260,8,20,.3);
    extent=58;
  }
  if(T===2){
    fence(5.5,2.2);
    const n=stand({side:'N',len:56,rows:9,gap:7.5,y0:1.2,occ:.5,share:.45,seat:(u)=>Math.abs(u)<9?0xffe600:0x2a3a8c});
    roof('N',n.back-n.D-1,n.back+1,n.top+4.2,n.top+3,false,58,{step:9.5});
    stand({side:'S',len:42,rows:4,gap:7.5,y0:.8,occ:.3,share:.35,seat:()=>0x7a7f88});
    box('cream',38,2.2,-(HW+12),12,4.4,6);
    const sb=new THREE.Mesh(new THREE.PlaneGeometry(9,3.4),new THREE.MeshStandardMaterial({map:scoreTex(club,'RAKİP','1 - 0',"34'",false),emissive:0xffffff,emissiveIntensity:.25,emissiveMap:null}));sb.position.set(HL+11,5,0);sb.rotation.y=-Math.PI/2;scene.add(sb);box('steel',HL+11.3,2.5,-3,.3,5,.3);box('steel',HL+11.3,2.5,3,.3,5,.3);
    [[-1,-1],[1,-1],[-1,1],[1,1]].forEach(([a,b])=>tower(a*(HL+13),b*(HW+17),19,3.2));
    trees(60,70,150,(x,z)=>Math.abs(x)<HL+20&&Math.abs(z)<HW+24);city(50,120,320,8,24,.3);extent=66;
  }
  if(T===3){
    const n=stand({side:'N',len:92,rows:15,gap:7,occ:.72,share:.62,seat:fbSeat});roof('N',n.back-n.D-2,n.back+1,n.top+5.5,n.top+3.5,false,96);
    const s=stand({side:'S',len:92,rows:11,gap:7,occ:.6,share:.55,seat:fbSeat});roof('S',s.back-s.D-1,s.back+1,s.top+5,s.top+3.2,false,96);
    stand({side:'E',len:54,rows:9,gap:8,occ:.7,share:.8,seat:()=>0xffe600,color:stripes(4)});
    const sb=new THREE.Mesh(new THREE.PlaneGeometry(14,5.2),new THREE.MeshStandardMaterial({map:scoreTex(club,'RAKİP','2 - 1',"58'",false),emissive:0xffffff,emissiveIntensity:.5}));sb.material.emissiveMap=sb.material.map;sb.position.set(-(HL+13),8,0);sb.rotation.y=Math.PI/2;scene.add(sb);box('steel',-(HL+13.4),4,-5,.5,8,.5);box('steel',-(HL+13.4),4,5,.5,8,.5);
    [[-1,-1],[1,-1],[-1,1],[1,1]].forEach(([a,b])=>tower(a*(HL+17),b*(HW+24),31,5.5));
    trees(70,85,190,(x,z)=>Math.abs(x)<HL+26&&Math.abs(z)<HW+30);city(80,140,400,10,30,.35);extent=80;
  }
  if(T===4){
    const ring={};
    [['N',104,21],['S',104,21],['E',66,18],['W',66,18]].forEach(([sd,len,rows])=>{const s=stand({side:sd,len,rows,gap:7,occ:.86,share:.78,seat:fbSeat,color:sd==='E'?stripes(5):null,rise:.45});ring[sd]=s;
      roof(sd,s.back-s.D-3,s.back+1.5,s.top+6.5,s.top+4,false,len+4);
      const f=s.f,a=f.P(0,s.back+1.2,(s.top+3.6)/2);const horiz=sd==='N'||sd==='S';box('facade',a[0],a[1],a[2],horiz?len+3:1,s.top+3.6,horiz?1:len+3)});
    [[-1,-1],[1,-1],[-1,1],[1,1]].forEach(([a,b])=>tower(a*(HL+20),b*(HW+22),40,7));
    const sb=new THREE.Mesh(new THREE.PlaneGeometry(22,8.2),new THREE.MeshStandardMaterial({map:scoreTex(club,'RAKİP','1 - 0',"71'",false),emissive:0xffffff,emissiveIntensity:1}));sb.material.emissiveMap=sb.material.map;sb.position.set(-(HL+7+ring.W.D+1),ring.W.top+7.5,0);sb.rotation.y=Math.PI/2;scene.add(sb);
    trees(60,110,230,(x,z)=>Math.abs(x)<HL+40&&Math.abs(z)<HW+42);city(130,170,480,12,45,.4);extent=98;
  }
  if(T>=5){
    const big=tier===6,gap=big?6.5:7,r1=big?24:17,r2=big?22:14,rise1=big?.44:.42,rise2=big?.6:.54;
    let top=0,back=0;
    ['N','S','E','W'].forEach(sd=>{
      const share=big?.97:.86,occ=big?.985:.93;
      const colL=big?(sd==='N'?maskFn('FENERBAHÇE'):sd==='S'?maskFn('★ 1907 ★',.25):stripes(3.4)):(sd==='E'?stripes(5):null);
      const lo=stand({side:sd,miter:true,rows:r1,gap,occ,share,seat:fbSeat,color:colL,rise:rise1,standing:big?.3:.15});
      const y1=lo.top+3.2,g2=lo.back-2.2;
      const colU=big?(sd==='N'?stripes(6.8):sd==='S'?maskFn('SARI LACİVERT'):sd==='E'?maskFn('1907',.3):maskFn('KADIKÖY',.2)):null;
      const up=stand({side:sd,miter:true,rows:r2,gap:g2,y0:y1,yb:lo.top-.4,occ,share,seat:fbSeat,color:colU,rise:rise2,fascia:'led',standing:big?.2:.1});
      top=up.top;back=up.back;
      roof(sd,big?lo.back-3:lo.back-4,back+2.5,top+(big?9:7.5),top+(big?5.5:4.5),true,0,{step:big?8:10,gs:big?11:9});
      const f=lo.f,L=f.other+back+2.6,hh=top+5;const a=f.P(0,back+2.6,hh/2);const horiz=sd==='N'||sd==='S';box('facade',a[0],a[1],a[2],horiz?2*L:1.2,hh,horiz?1.2:2*L);
    });
    // dev ekranlar
    [[1,0,-Math.PI/2],[-1,0,Math.PI/2]].forEach(([sx,_,ry])=>{const sb=new THREE.Mesh(new THREE.PlaneGeometry(big?30:24,big?11:9),new THREE.MeshStandardMaterial({map:scoreTex(big?'FENERBAHÇE':club,'RAKİP','2 - 0',"67'",big),emissive:0xffffff,emissiveIntensity:1.3}));sb.material.emissiveMap=sb.material.map;sb.position.set(sx*(HL+back-3),top+(big?1.5:1),0);sb.rotation.y=ry;scene.add(sb)});
    // dış cephe arması + yazı
    if(big){
      const cr=new THREE.Mesh(new THREE.CircleGeometry(11,48),new THREE.MeshStandardMaterial({map:tex(canvas(512,512,(g)=>{g.clearRect(0,0,512,512);drawCrest(g,256,256,250)})),transparent:true,emissive:0xffffff,emissiveIntensity:.55}));cr.material.emissiveMap=cr.material.map;cr.position.set(0,top-6,HW+back+4.3);scene.add(cr);
      const nm=new THREE.Mesh(new THREE.PlaneGeometry(92,7),new THREE.MeshStandardMaterial({map:textTex('FENERBAHÇE ŞÜKRÜ SARACOĞLU STADYUMU',2048,160,null,'#ffe600','900 78px "Arial Narrow",Arial'),transparent:true,emissive:0xffe600,emissiveIntensity:.9}));nm.material.emissiveMap=nm.material.map;
      nm.material.depthWrite=false;nm.position.set(0,top-21,HW+back+4.3);scene.add(nm);
      // dev bayraklar
      const ft=tex(canvas(256,160,(g)=>{for(let i=0;i<8;i++){g.fillStyle=i%2?'#0b1747':'#ffe600';g.fillRect(i*32,0,32,160)}drawCrest(g,128,80,56)}));
      for(let i=0;i<46;i++){const sd=['E','W','N','S'][i%4],f=frame(sd),d=gap+2+R()*14,u=(R()-.5)*(sd==='E'||sd==='W'?70:110),y=1.1+((d-gap)/.82)*.44+2.4;const p=f.P(u,d,y);
        const m=new THREE.Mesh(new THREE.PlaneGeometry(3.6,2.3,6,1),new THREE.MeshStandardMaterial({map:ft,side:THREE.DoubleSide,roughness:.9}));const pa=m.geometry.attributes.position;for(let k=0;k<pa.count;k++)pa.setZ(k,Math.sin(pa.getX(k)*2+i)*.22);m.geometry.computeVertexNormals();
        m.position.set(p[0],p[1],p[2]);m.rotation.set((R()-.5)*.5,f.th+(R()-.5)*1.2,(R()-.5)*.6);scene.add(m)}
    }
    city(big?260:170,220,640,14,big?70:60,.42);trees(50,150,260,(x,z)=>Math.abs(x)<HL+back+14&&Math.abs(z)<HW+back+14);
    // otopark
    const cars=new THREE.InstancedMesh(new THREE.BoxGeometry(4.2,1.4,1.9),new THREE.MeshStandardMaterial({roughness:.4,metalness:.3}),400),o=new THREE.Object3D(),c=new THREE.Color();
    for(let i=0;i<400;i++){const col=i%40,row=i/40|0;o.position.set(-80+col*4.2+(col>19?10:0),.7,HW+back+26+row*6.2+(row%2?0:1.2));o.rotation.y=Math.PI/2;o.updateMatrix();cars.setMatrixAt(i,o.matrix);cars.setColorAt(i,c.setHSL(R(),R()<.4?.5:.02,.2+R()*.5))}scene.add(cars);
    if(opt.sea){const sea=new THREE.Mesh(new THREE.PlaneGeometry(4000,1600),new THREE.MeshStandardMaterial({color:0x061a3a,roughness:.25,metalness:.5}));sea.rotation.x=-Math.PI/2;sea.position.set(0,.05,-opt.sea-800);scene.add(sea)}
    extent=HL+back+10;out.bowl={top,back};
  }
  if(night>.5){const lp=[],lc=[],cc=new THREE.Color();for(let i=0;i<2600;i++){const a=R()*6.28,r=300+R()*900;if(opt.sea&&Math.sin(a)*r<-opt.sea&&R()<.8)continue;lp.push(Math.cos(a)*r,2+R()*R()*40,Math.sin(a)*r);cc.setHSL(.09+R()*.06,.8,.6+R()*.3);lc.push(cc.r,cc.g,cc.b)}
    const lg=new THREE.BufferGeometry();lg.setAttribute('position',new THREE.Float32BufferAttribute(lp,3));lg.setAttribute('color',new THREE.Float32BufferAttribute(lc,3));scene.add(new THREE.Points(lg,new THREE.PointsMaterial({size:2.4,sizeAttenuation:false,vertexColors:true,fog:false})))}

  if(opt.extra)opt.extra({box,glow,trees,city,tower,quad,R,stand,roof,fence});
  /* malzemeler */
  const facT=tex(canvas(256,256,(g)=>{g.fillStyle='#0b1747';g.fillRect(0,0,256,256);for(let i=0;i<8;i++){g.fillStyle=i%4===0?'#ffe600':i%2?'#10206a':'#0d1b58';g.fillRect(i*32,0,30,256)}g.fillStyle='rgba(150,200,255,.5)';g.fillRect(0,96,256,26);g.fillRect(0,170,256,18)}),{wrapS:THREE.RepeatWrapping,wrapT:THREE.RepeatWrapping});
  const MAT={conc:new THREE.MeshStandardMaterial({color:tier===6?0x232b55:0x8f939b,roughness:.95}),dark:new THREE.MeshStandardMaterial({color:0x3c4150,roughness:.9}),navy:new THREE.MeshStandardMaterial({color:0x0b1747,roughness:.7}),
    led:new THREE.MeshStandardMaterial({color:0x0b1747,emissive:0x2238b8,emissiveIntensity:.8,roughness:.5}),
    roof:new THREE.MeshStandardMaterial({color:tier>=5?0xaab2c6:0x8a919c,roughness:.55,metalness:.25}),roofU:new THREE.MeshStandardMaterial({color:night>.5?0x5d6788:0x9aa0aa,roughness:.8,side:THREE.DoubleSide}),roofE:new THREE.MeshStandardMaterial({color:0xffe600,roughness:.6,emissive:0xffe600,emissiveIntensity:night>.5?.35:0}),
    steel:new THREE.MeshStandardMaterial({color:0x8d939e,roughness:.5,metalness:.6}),lamp:new THREE.MeshStandardMaterial({color:0xffffff,emissive:0xfff4d6,emissiveIntensity:4}),lampOff:new THREE.MeshStandardMaterial({color:0x9aa0a8}),
    wood:new THREE.MeshStandardMaterial({color:0x8a6a44,roughness:.9}),cream:new THREE.MeshStandardMaterial({color:0xd9d2bf,roughness:.9}),white:new THREE.MeshStandardMaterial({color:0xffffff}),
    facade:new THREE.MeshStandardMaterial({map:facT,roughness:.7,emissive:0x1a2a7a,emissiveIntensity:night>.5?.5:0}),
    ...(opt.mats||{}),carR:new THREE.MeshStandardMaterial({color:0x9c2f2f,metalness:.3,roughness:.4}),carW:new THREE.MeshStandardMaterial({color:0xdedede,metalness:.3,roughness:.4}),carB:new THREE.MeshStandardMaterial({color:0x2d3a5e,metalness:.3,roughness:.4}),carG:new THREE.MeshStandardMaterial({color:0x55585e,metalness:.3,roughness:.4})};
  for(const k in G){const g=new THREE.BufferGeometry();g.setAttribute('position',new THREE.Float32BufferAttribute(G[k],3));g.computeVertexNormals();
    if(k==='facade'){const p=g.attributes.position,uv=[];const n=g.attributes.normal;for(let i=0;i<p.count;i++){const hz=Math.abs(n.getZ(i))>.5;uv.push((hz?p.getX(i):p.getZ(i))/14,p.getY(i)/16)}g.setAttribute('uv',new THREE.Float32BufferAttribute(uv,2))}
    const m=new THREE.Mesh(g,MAT[k]||MAT.conc);m.castShadow=!(k==='roofU'||k==='lamp');m.receiveShadow=true;scene.add(m)}
  /* koltuk + seyirci örnekleri */
  const o=new THREE.Object3D(),c=new THREE.Color();
  if(seats.length){const im=new THREE.InstancedMesh(new THREE.BoxGeometry(.46,.42,.1),new THREE.MeshStandardMaterial({roughness:.6}),seats.length);seats.forEach((s,i)=>{o.position.set(s[0],s[1],s[2]);o.rotation.set(0,s[3],0);o.scale.setScalar(1);o.updateMatrix();im.setMatrixAt(i,o.matrix);im.setColorAt(i,c.setHex(s[4]))});im.receiveShadow=true;scene.add(im)}
  if(torsos.length){
    const tg=new THREE.BoxGeometry(.44,.62,.26);const im=new THREE.InstancedMesh(tg,new THREE.MeshStandardMaterial({roughness:.9}),torsos.length);
    torsos.forEach((s,i)=>{o.position.set(s[0],s[1],s[2]);o.rotation.set(0,s[3],0);o.scale.set(s[5],1,1);o.updateMatrix();im.setMatrixAt(i,o.matrix);im.setColorAt(i,c.setHex(s[4]))});im.castShadow=tier<=3;im.receiveShadow=true;scene.add(im);
    const hm=new THREE.InstancedMesh(new THREE.SphereGeometry(.115,7,5),new THREE.MeshStandardMaterial({roughness:.8}),heads.length);
    heads.forEach((s,i)=>{o.position.set(s[0],s[1],s[2]);o.rotation.set(0,0,0);o.scale.setScalar(1);o.updateMatrix();hm.setMatrixAt(i,o.matrix);hm.setColorAt(i,c.setHex(s[3]))});scene.add(hm);
  }
  out.crowd=torsos.length;out.extent=extent;out.box=box;out.glow=glow;out.trees=trees;out.city=city;out.tower=tower;out.MAT=MAT;out.flush=null;
  return out;
}

/* top */
export function makeBall(){
  const g=new THREE.IcosahedronGeometry(.11,5),p=g.attributes.position,col=[];
  const t=(1+Math.sqrt(5))/2,vs=[[-1,t,0],[1,t,0],[-1,-t,0],[1,-t,0],[0,-1,t],[0,1,t],[0,-1,-t],[0,1,-t],[t,0,-1],[t,0,1],[-t,0,-1],[-t,0,1]].map(v=>new THREE.Vector3(...v).normalize());
  const v=new THREE.Vector3();
  for(let i=0;i<p.count;i++){v.fromBufferAttribute(p,i).normalize();let m=0,m2=0;vs.forEach(q=>{const d=v.dot(q);if(d>m){m2=m;m=d}else if(d>m2)m2=d});
    let c=m>.936?[.05,.05,.07]:[.96,.96,.96];if(m<=.936&&m-m2<.012)c=[.25,.25,.28];col.push(...c)}
  g.setAttribute('color',new THREE.Float32BufferAttribute(col,3));
  const m=new THREE.Mesh(g,new THREE.MeshStandardMaterial({vertexColors:true,roughness:.35}));m.castShadow=true;return m;
}
