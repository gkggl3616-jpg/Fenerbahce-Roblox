// Ortak 2D çizimler: arma, forma sırt/göğüs dokuları
import * as THREE from 'three';

export const COL={yellow:'#ffe600',navy:'#0b1747',navy2:'#13247a',red:'#d81e2c',green:'#1f8a3c',white:'#ffffff'};

export function canvas(w,h,draw){const c=document.createElement('canvas');c.width=w;c.height=h;draw(c.getContext('2d'),w,h);return c}
export function tex(c,opts={}){const t=new THREE.CanvasTexture(c);t.colorSpace=THREE.SRGBColorSpace;t.anisotropy=8;Object.assign(t,opts);return t}

function arcText(g,str,cx,cy,r,startA,endA,font,color,inside){
  g.save();g.font=font;g.fillStyle=color;g.textAlign='center';g.textBaseline='middle';
  const n=str.length;
  for(let i=0;i<n;i++){
    const a=startA+(endA-startA)*(n===1?.5:i/(n-1));
    g.save();g.translate(cx+Math.cos(a)*r,cy+Math.sin(a)*r);g.rotate(a+(inside?-Math.PI/2:Math.PI/2));g.fillText(str[i],0,0);g.restore();
  }
  g.restore();
}

// Fenerbahçe armasından esinlenen temsili arma (beyaz halka, kırmızı halka, sarı-lacivert çubuk, meşe yaprağı)
export function drawCrest(g,cx,cy,R){
  g.save();
  g.beginPath();g.arc(cx,cy,R,0,7);g.fillStyle=COL.navy;g.fill();
  g.beginPath();g.arc(cx,cy,R*.965,0,7);g.fillStyle='#fff';g.fill();
  g.beginPath();g.arc(cx,cy,R*.745,0,7);g.fillStyle=COL.navy;g.fill();
  g.beginPath();g.arc(cx,cy,R*.725,0,7);g.fillStyle=COL.red;g.fill();
  g.beginPath();g.arc(cx,cy,R*.615,0,7);g.fillStyle=COL.navy;g.fill();
  // çubuklu iç daire
  g.save();g.beginPath();g.arc(cx,cy,R*.595,0,7);g.clip();
  const sw=R*1.19/5;for(let i=0;i<5;i++){g.fillStyle=i%2?COL.navy:COL.yellow;g.fillRect(cx-R*.595+i*sw,cy-R,sw+1,2*R)}
  g.restore();
  // yazılar
  const f=`900 ${R*.17}px "Arial Black",Arial,sans-serif`;
  arcText(g,'FENERBAHÇE SPOR KULÜBÜ',cx,cy,R*.855,Math.PI*1.07,Math.PI*1.93,f,COL.navy,false);
  arcText(g,'★ 1907 ★',cx,cy,R*.855,Math.PI*.66,Math.PI*.34,f,COL.navy,true);
  // meşe yaprağı
  g.translate(cx,cy+R*.02);g.rotate(-.5);
  const leaf=(s,fill)=>{g.beginPath();
    const lobes=[[0,-.62,.13],[-.13,-.42,.15],[.13,-.42,.15],[-.17,-.18,.17],[.17,-.18,.17],[-.17,.08,.17],[.17,.08,.17],[-.11,.3,.14],[.11,.3,.14],[0,.42,.12],[0,-.2,.2],[0,.1,.2]];
    lobes.forEach(l=>{g.moveTo(l[0]*R+l[2]*R*s,l[1]*R);g.arc(l[0]*R,l[1]*R,l[2]*R*s,0,7)});g.fillStyle=fill;g.fill()};
  leaf(1.16,'#fff');leaf(1,COL.green);
  g.strokeStyle=COL.yellow;g.lineWidth=R*.035;g.lineCap='round';
  g.beginPath();g.moveTo(0,-R*.6);g.lineTo(0,R*.62);g.stroke();
  [[-.42],[-.18],[.08],[.3]].forEach(([y])=>{g.beginPath();g.moveTo(-R*.2,y*R-R*.06);g.lineTo(0,y*R+R*.05);g.lineTo(R*.2,y*R-R*.06);g.stroke()});
  g.restore();
}

// Oyuncunun kendi kulübü için kalkan arma
export function drawShield(g,cx,cy,R,txt){
  g.save();g.translate(cx,cy);
  const path=()=>{g.beginPath();g.moveTo(-R*.8,-R);g.lineTo(R*.8,-R);g.lineTo(R*.8,R*.2);g.quadraticCurveTo(R*.8,R*.8,0,R*1.1);g.quadraticCurveTo(-R*.8,R*.8,-R*.8,R*.2);g.closePath()};
  path();g.fillStyle=COL.navy;g.fill();
  g.save();g.scale(.9,.9);path();g.clip();
  for(let i=0;i<4;i++){g.fillStyle=i%2?COL.navy:COL.yellow;g.fillRect(-R*.8+i*R*.4,-R,R*.4+1,R*2.2)}
  g.fillStyle=COL.navy;g.fillRect(-R,-R,2*R,R*.55);g.restore();
  g.fillStyle=COL.yellow;g.font=`900 ${R*.42}px "Arial Black",Arial`;g.textAlign='center';g.textBaseline='middle';g.fillText(txt,0,-R*.66);
  g.restore();
}

export function stars(g,cx,cy,size,n,color){g.save();g.fillStyle=color;g.font=`${size}px Arial`;g.textAlign='center';g.textBaseline='middle';g.fillText('★'.repeat(n),cx,cy);g.restore()}

export function backTex(name,num,color,outline){
  return tex(canvas(512,512,(g,w,h)=>{
    g.clearRect(0,0,w,h);g.textAlign='center';g.textBaseline='middle';g.lineJoin='round';
    g.font='900 62px "Arial Narrow",Arial,sans-serif';
    if(outline){g.strokeStyle=outline;g.lineWidth=12;g.strokeText(name,w/2,70)}
    g.fillStyle=color;g.fillText(name,w/2,70);
    g.font='900 330px "Arial Narrow",Arial,sans-serif';
    if(outline){g.strokeStyle=outline;g.lineWidth=26;g.strokeText(num,w/2,310)}
    g.fillStyle=color;g.fillText(num,w/2,310);
  }));
}
export function frontTex(kind,txt,sponsor,sponsorColor){
  return tex(canvas(512,512,(g,w,h)=>{
    g.clearRect(0,0,w,h);
    if(kind==='fb'){drawCrest(g,372,150,62);stars(g,372,62,26,5,'#ffd400')}
    else if(kind==='shield'){drawShield(g,372,150,52,txt||'MG')}
    if(sponsor){g.font='900 58px "Arial Narrow",Arial';g.textAlign='center';g.textBaseline='middle';g.lineJoin='round';
      g.strokeStyle='rgba(0,0,0,.35)';g.lineWidth=8;g.strokeText(sponsor,w/2,330);g.fillStyle=sponsorColor||'#fff';g.fillText(sponsor,w/2,330)}
  }));
}
