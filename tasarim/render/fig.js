// Futbolcu modeli: animasyonlu iskelet + prosedürel atletik gövde + gerçek geometrili forma/şort/krampon + gerçekçi baş
import * as THREE from 'three';
import {GLTFLoader} from 'three/addons/loaders/GLTFLoader.js';
import * as SkeletonUtils from 'three/addons/utils/SkeletonUtils.js';
import {backTex,frontTex,COL} from './gfx.js';

let BASE=null;
const V=(x=0,y=0,z=0)=>new THREE.Vector3(x,y,z);
const short=n=>n.replace('mixamorig','');
const sstep=(a,b,v)=>{const t=Math.min(1,Math.max(0,(v-a)/(b-a)));return t*t*(3-2*t)};

export async function loadAssets(){
  const L=new GLTFLoader();
  const [x,r]=await Promise.all([L.loadAsync('models/Xbot.glb'),L.loadAsync('models/rpm.glb')]);
  BASE=prepBody(x);BASE.head=prepHead(r);return BASE;
}

/* ---------- gövde üretici ---------- */
class Builder{
  constructor(boneIndex){this.bi=boneIndex;this.P=[];this.I=[];this.SI=[];this.SW=[];this.F=[];this.A=[]}
  vert(p,w,f,arm){ // w: [[bone,weight]...]
    const i=this.P.length/3;this.P.push(p.x,p.y,p.z);
    const ws=w.filter(e=>e[1]>1e-4).sort((a,b)=>b[1]-a[1]).slice(0,4);let s=0;ws.forEach(e=>s+=e[1]);
    for(let k=0;k<4;k++){this.SI.push(ws[k]?this.bi[ws[k][0]]:0);this.SW.push(ws[k]?ws[k][1]/s:0)}
    this.F.push(f[0],f[1],f[2],f[3]);this.A.push(arm||0);return i;
  }
  // rings: [{c:Vector3, rx, rz, side:Vector3, front:Vector3, w, f, arm, n?}]
  loft(rings,segs,capA,capB,pow=2){
    const start=[];
    rings.forEach(r=>{
      const s=this.P.length/3;start.push(s);
      for(let k=0;k<segs;k++){
        const a=k/segs*Math.PI*2,ca=Math.cos(a),sa=Math.sin(a),e=2/(r.n||pow);
        const x=Math.sign(ca)*Math.pow(Math.abs(ca),e)*r.rx,z=Math.sign(sa)*Math.pow(Math.abs(sa),e)*r.rz;
        const p=r.c.clone().addScaledVector(r.side,x).addScaledVector(r.front,z);
        if(r.minY!==undefined&&p.y<r.minY)p.y=r.minY;
        this.vert(p,r.w,r.f,r.arm);
      }
    });
    for(let i=0;i<rings.length-1;i++)for(let k=0;k<segs;k++){
      const a=start[i]+k,b=start[i]+(k+1)%segs,c=start[i+1]+k,d=start[i+1]+(k+1)%segs;this.I.push(a,c,b,b,c,d);
    }
    const cap=(ri,flip)=>{const r=rings[ri],ci=this.vert(r.c.clone(),r.w,r.f,r.arm);for(let k=0;k<segs;k++){const a=start[ri]+k,b=start[ri]+(k+1)%segs;flip?this.I.push(ci,b,a):this.I.push(ci,a,b)}};
    if(capA)cap(0,false);if(capB)cap(rings.length-1,true);
  }
}

function restOf(mesh,i,p){p.fromBufferAttribute(mesh.geometry.attributes.position,i);mesh.applyBoneTransform(i,p);return p.applyMatrix4(mesh.matrixWorld)}

function prepBody(x){
  const scene=x.scene,meshes=[];
  scene.traverse(o=>{if(o.isSkinnedMesh)meshes.push(o)});
  const sk=meshes[0].skeleton;scene.updateMatrixWorld(true);
  const B={},bi={};sk.bones.forEach((b,i)=>{B[short(b.name)]=b;bi[short(b.name)]=i});
  const wp=n=>B[n].getWorldPosition(V());
  let minY=1e9;meshes.forEach(m=>{const p=V();for(let i=0;i<m.geometry.attributes.position.count;i+=7){restOf(m,i,p);minY=Math.min(minY,p.y)}});
  const J={};['Hips','Spine','Spine1','Spine2','Neck','Head'].forEach(n=>J[n]=wp(n));
  ['Left','Right'].forEach(s=>['Shoulder','Arm','ForeArm','Hand','UpLeg','Leg','Foot','ToeBase'].forEach(n=>J[s+n]=wp(s+n)));
  const hipY=J.Hips.y,neckY=J.Neck.y,chestY=J.Spine2.y,armY=J.LeftArm.y;
  console.log('J',JSON.stringify(Object.fromEntries(Object.entries(J).map(([k,v])=>[k,v.toArray().map(n=>+n.toFixed(3))]))),'minY',minY.toFixed(3));
  const b=new Builder(bi),X=V(1,0,0),Y=V(0,1,0),Z=V(0,0,1);
  const SK=[-.2,-.2,-.2,-.2];

  ['Left','Right'].forEach(S=>{
    const sx=S==='Left'?1:-1; // Mixamo: sol = +X
    /* bacak */
    const hip=J[S+'UpLeg'],knee=J[S+'Leg'],ank=J[S+'Foot'];
    const l1=hip.distanceTo(knee),l2=knee.distanceTo(ank),Lg=l1+l2,sk_=l1/Lg;
    const at=s=>s<sk_?hip.clone().lerp(knee,s/sk_):knee.clone().lerp(ank,(s-sk_)/(1-sk_));
    const legW=s=>{const u=sstep(sk_-.07,sk_+.07,s);const a=sstep(.93,1.02,s);return [[S+'UpLeg',(1-u)],[S+'Leg',u*(1-a)],[S+'Foot',u*a]]};
    const sockTop=sk_+.055;
    const legR=[[0,.05,.055,0],[.035,.088,.096,-.004],[.17,.087,.095,-.002],[.34,.071,.078,.002],[sk_-.04,.059,.063,.004],[sk_,.056,.06,.007],[sk_+.05,.052,.055,0],[sk_+.15,.059,.068,-.012],[sk_+.3,.047,.053,-.007],[.94,.038,.042,0],[1,.036,.04,0]];
    b.loft(legR.map(([s,rx,rz,oz])=>({c:at(s).add(V(0,0,oz)),rx,rz,side:X,front:Z,w:legW(s),f:[-.2,-.2,(s-sockTop)*Lg,-.2]})),20,true,true);
    /* krampon */
    const fz=[[-.07,.016,.03,.026],[-.05,.034,.056,.056],[-.005,.041,.066,.068],[.045,.046,.046,.046],[.1,.05,.033,.033],[.15,.046,.026,.026],[.185,.03,.019,.018],[.2,.01,.012,.008]];
    b.loft(fz.map(([z,w,yc,hy])=>({c:V(ank.x,yc+minY,ank.z+z),rx:w,rz:hy,side:X,front:Y,minY:minY+.002,w:z>.12?[[S+'ToeBase',1]]:z>.08?[[S+'ToeBase',.5],[S+'Foot',.5]]:[[S+'Foot',1]],f:[-.2,-.2,.2,.2],n:2.6})),16,true,true);
    /* kol */
    const sh=J[S+'Arm'],el=J[S+'ForeArm'],wr=J[S+'Hand'];
    const a1=sh.distanceTo(el),a2=el.distanceTo(wr),La=a1+a2,se=a1/La;
    const aat=s=>s<se?sh.clone().lerp(el,s/se):el.clone().lerp(wr,(s-se)/(1-se));
    const armW=s=>{const u=sstep(se-.08,se+.08,s);return [[S+'Arm',1-u],[S+'ForeArm',u]]};
    const armR=[[-.02,.03,.03],[.04,.054,.056],[.2,.051,.054],[se-.06,.043,.045],[se,.041,.043],[se+.1,.044,.047],[se+.3,.036,.039],[1.02,.029,.033]];
    b.loft(armR.map(([s,ry,rz])=>({c:aat(s),rx:ry,rz,side:Y,front:Z,w:armW(s),f:SK,arm:1})),16,true,true);
    /* forma kolu */
    const hem=se*.6;
    const slR=[[-.1,.04,.045],[-.03,.064,.068],[.06,.067,.071],[hem*.6,.064,.068],[hem,.066,.07]];
    b.loft(slR.map(([s,ry,rz])=>({c:aat(s).add(V(0,s<.05?.004:0,0)),rx:ry,rz,side:Y,front:Z,w:s<.06?[[S+'Arm',.6],['Spine2',.25],[S+'Shoulder',.15]]:[[S+'Arm',1]],f:[(hem-s)*La+.001,-.2,-.2,-.2],arm:1})),18,true,false);
    /* şort paçası */
    const sh0=.0,shHem=.3;
    const shR=[[sh0,.09,.098],[.1,.098,.106],[.2,.1,.108],[shHem,.103,.111]];
    b.loft(shR.map(([s,rx,rz])=>({c:at(s).add(V(sx*.004,0,-.002)),rx,rz,side:X,front:Z,w:s<.08?[[S+'UpLeg',.6],['Hips',.4]]:[[S+'UpLeg',1]],f:[-.2,(shHem-s)*Lg+.001,-.2,-.2]})),20,true,false);
  });
  /* gövde: forma */
  const spineW=y=>{const ys=[['Hips',hipY+.02],['Spine',J.Spine.y+.03],['Spine1',J.Spine1.y+.03],['Spine2',J.Spine2.y+.04]];
    if(y<=ys[0][1])return [['Hips',1]];if(y>=ys[3][1])return [['Spine2',1]];
    for(let i=0;i<3;i++)if(y<ys[i+1][1]){const u=(y-ys[i][1])/(ys[i+1][1]-ys[i][1]);return [[ys[i][0],1-u],[ys[i+1][0],u]]}};
  const shW=J.LeftArm.x; // omuz eklemi x
  const tor=[[hipY-.105,.186,.138,-.004],[hipY-.02,.176,.13,-.002],[hipY+.1,.156,.112,.004],[chestY-.06,.164,.118,.01],[chestY+.02,.178,.127,.014],[armY-.05,.186,.124,.008],[armY+.0,.178,.108,.0],[armY+.04,.13,.088,-.006],[neckY+.012,.08,.076,-.008],[neckY+.04,.064,.068,-.008]];
  b.loft(tor.map(([y,rx,rz,oz])=>({c:V(0,y,oz),rx,rz,side:X,front:Z,w:spineW(y),f:[.2,-.2,-.2,-.2],n:2.5})),28,false,false);
  /* şort gövdesi */
  const crotch=J.LeftUpLeg.y-.085;
  const pel=[[hipY+.08,.14,.1],[hipY,.15,.108],[hipY-.07,.158,.114],[J.LeftUpLeg.y-.03,.176,.126],[crotch+.02,.172,.122],[crotch-.01,.1,.085],[crotch-.02,.02,.02]];
  b.loft(pel.map(([y,rx,rz])=>({c:V(0,y,-.004),rx,rz,side:X,front:Z,w:[['Hips',1]],f:[-.2,.2,-.2,-.2],n:2.5})),28,false,true);

  // geometri → iskelet uzayı
  const restInv=m=>m.matrixWorld.clone().multiply(m.bindMatrixInverse).multiply(new THREE.Matrix4().multiplyMatrices(B.Hips.matrixWorld,m.skeleton.boneInverses[m.skeleton.bones.indexOf(B.Hips)])).multiply(m.bindMatrix).invert();
  const src=meshes[0],inv=restInv(src);
  const g=new THREE.BufferGeometry();
  g.setAttribute('position',new THREE.Float32BufferAttribute(b.P,3));g.setIndex(b.I);g.computeVertexNormals();
  g.setAttribute('aRest',new THREE.Float32BufferAttribute(b.P.slice(),3));
  g.setAttribute('aRestN',new THREE.BufferAttribute(g.attributes.normal.array.slice(),3));
  g.setAttribute('aF',new THREE.Float32BufferAttribute(b.F,4));g.setAttribute('aArm',new THREE.Float32BufferAttribute(b.A,1));
  g.setAttribute('skinIndex',new THREE.Uint16BufferAttribute(b.SI,4));g.setAttribute('skinWeight',new THREE.Float32BufferAttribute(b.SW,4));
  g.applyMatrix4(inv);
  const body=new THREE.SkinnedMesh(g,new THREE.MeshStandardMaterial());body.name='KitBody';
  body.position.copy(src.position);body.quaternion.copy(src.quaternion);body.scale.copy(src.scale);
  src.parent.add(body);body.bind(sk,src.bindMatrix);body.frustumCulled=false;
  // Xbot: yalnızca eller kalsın
  meshes.forEach(mesh=>{
    const gg=mesh.geometry,pos=gg.attributes.position,si=gg.attributes.skinIndex,sw=gg.attributes.skinWeight,n=pos.count;
    const aRest=new Float32Array(n*3),aRestN=new Float32Array(n*3),aF=new Float32Array(n*4).fill(-.2),aArm=new Float32Array(n).fill(2),p=V(),keepV=new Uint8Array(n);
    for(let i=0;i<n;i++){
      let hw=0;for(let k=0;k<4;k++){const nm=short(sk.bones[si.getComponent(i,k)].name);if(/Hand/.test(nm))hw+=sw.getComponent(i,k)}
      restOf(mesh,i,p);aRest.set([p.x,p.y,p.z],i*3);aRestN.set([0,1,0],i*3);
      keepV[i]=hw>=.5?1:0;
    }
    const oi=gg.index.array,ni=[];for(let i=0;i<oi.length;i+=3){if(keepV[oi[i]]&&keepV[oi[i+1]]&&keepV[oi[i+2]])ni.push(oi[i],oi[i+1],oi[i+2])}
    gg.setIndex(ni);if(!ni.length)mesh.visible=false;
    gg.setAttribute('aRest',new THREE.BufferAttribute(aRest,3));gg.setAttribute('aRestN',new THREE.BufferAttribute(aRestN,3));
    gg.setAttribute('aF',new THREE.BufferAttribute(aF,4));gg.setAttribute('aArm',new THREE.BufferAttribute(aArm,1));mesh.frustumCulled=false;
  });
  return {scene,animations:x.animations,floorY:minY,neckY,hipY,chestY,J};
}

function prepHead(r){
  const scene=r.scene;scene.updateMatrixWorld(true);
  let sk=null;const M={};
  scene.traverse(o=>{if(o.isSkinnedMesh){M[o.name]=o;sk=sk||o.skeleton}});
  const hb=sk.bones.find(b=>b.name==='Head'),hp=hb.getWorldPosition(V());
  function bake(mesh){
    const g=mesh.geometry,n=g.attributes.position.count,P=new Float32Array(n*3),N=new Float32Array(n*3),t=V(),t2=V();
    for(let i=0;i<n;i++){
      const p=restOf(mesh,i,V());
      t.fromBufferAttribute(g.attributes.position,i);t2.fromBufferAttribute(g.attributes.normal,i);
      const q=t.clone().addScaledVector(t2,.01);mesh.applyBoneTransform(i,q);q.applyMatrix4(mesh.matrixWorld);q.sub(p).normalize();
      p.sub(hp);P.set([p.x,p.y,p.z],i*3);N.set([q.x,q.y,q.z],i*3);
    }
    const ng=new THREE.BufferGeometry();ng.setAttribute('position',new THREE.BufferAttribute(P,3));ng.setAttribute('normal',new THREE.BufferAttribute(N,3));
    ng.setAttribute('uv',new THREE.BufferAttribute(Float32Array.from({length:n*2},(_,i)=>i%2?g.attributes.uv.getY(i>>1):g.attributes.uv.getX(i>>1)),2));
    ng.setIndex(Array.from(g.index.array));ng.computeBoundingBox();return ng;
  }
  const out={parts:{}};
  for(const k of ['Wolf3D_Head','EyeLeft','EyeRight','Wolf3D_Beard']){if(M[k])out.parts[k]={geo:bake(M[k]),mat:M[k].material}}
  const hg=out.parts.Wolf3D_Head.geo,bb=hg.boundingBox;
  const P=hg.attributes.position,Nn=hg.attributes.normal,top=bb.max.y,cc=V(0,top-.105,-.005);
  const edge=i=>{const d=V(P.getX(i),P.getY(i),P.getZ(i)).sub(cc).normalize();const el=Math.asin(d.y)*57.3,h=Math.hypot(d.x,d.z)||1,fz=d.z/h;
    const th=fz>=0?-8+34*Math.pow(fz,1.6):-8-34*Math.pow(-fz,1.2);return el-th};
  const idx=hg.index;
  out.hairs={};
  const STY={kisa:[.006,.016,.002],hacimli:[.006,.036,.014],sifir:[.002,.004,0],uzun:[.009,.026,0]};
  for(const st in STY){
    const [l0,l1,fw]=STY[st],lim=st==='uzun'?-14:0,keep=[];
    for(let i=0;i<idx.count;i+=3){const a=idx.getX(i),b=idx.getX(i+1),c=idx.getX(i+2);if(edge(a)>lim&&edge(b)>lim&&edge(c)>lim)keep.push(a,b,c)}
    const hairG=new THREE.BufferGeometry(),HP=new Float32Array(P.count*3);
    for(let i=0;i<P.count;i++){const e=edge(i)-lim;const k=sstep(0,14,e),t2=sstep(14,60,e);const lift=l0*k+(l1-l0)*t2;
      HP.set([P.getX(i)+Nn.getX(i)*lift,P.getY(i)+Nn.getY(i)*lift+t2*fw*.4,P.getZ(i)+Nn.getZ(i)*lift+t2*fw],i*3)}
    hairG.setAttribute('position',new THREE.BufferAttribute(HP,3));hairG.setIndex(keep);hairG.computeVertexNormals();
    out.hairs[st]=hairG;
  }

  const img=out.parts.Wolf3D_Head.mat.map.image,c=document.createElement('canvas');c.width=c.height=48;const g=c.getContext('2d');
  g.drawImage(img,0,0,48,48);const d=g.getImageData(0,0,48,48).data,px=[];for(let i=0;i<d.length;i+=4)px.push([d[i],d[i+1],d[i+2],d[i]+d[i+1]+d[i+2]]);
  px.sort((a,b)=>b[3]-a[3]);const sel=px.slice(Math.floor(px.length*.08),Math.floor(px.length*.4));let R=0,G=0,Bb=0;sel.forEach(q=>{R+=q[0];G+=q[1];Bb+=q[2]});
  out.skin=new THREE.Color().setRGB(R/sel.length/255,G/sel.length/255,Bb/sel.length/255,THREE.SRGBColorSpace);console.log('skin',out.skin.getHexString());
  return out;
}

/* ---------- formalar ---------- */
const C=h=>new THREE.Color(h);
export const KITS={
  fb:{style:0,c1:COL.yellow,c2:COL.navy,sleeve:COL.navy,trim:COL.yellow,collar:COL.navy,shorts:'#ffffff',shortsTrim:COL.navy,sock:COL.navy,sockTrim:COL.yellow,boot:'#101216',ink:'#ffffff',inkOut:COL.navy,front:'fb'},
  club:{style:0,c1:COL.yellow,c2:COL.navy,sleeve:COL.yellow,trim:COL.navy,collar:COL.navy,shorts:COL.navy,shortsTrim:COL.yellow,sock:COL.yellow,sockTrim:COL.navy,boot:'#101216',ink:'#ffffff',inkOut:COL.navy,front:'shield'},
  away:{style:2,c1:'#f4f6fb',c2:COL.navy,sleeve:'#f4f6fb',trim:COL.navy,collar:COL.navy,shorts:COL.navy,shortsTrim:COL.yellow,sock:'#f4f6fb',sockTrim:COL.navy,boot:'#101216',ink:COL.navy,inkOut:null,front:'fb'},
  third:{style:3,c1:'#14161d',c2:COL.yellow,sleeve:'#14161d',trim:COL.yellow,collar:COL.yellow,shorts:'#14161d',shortsTrim:COL.yellow,sock:'#14161d',sockTrim:COL.yellow,boot:'#e9d400',ink:COL.yellow,inkOut:null,front:'fb'},
  gk:{style:1,c1:'#19b56a',c2:'#0d7a45',sleeve:'#0d7a45',trim:'#0b1747',collar:'#0b1747',shorts:'#0d7a45',shortsTrim:'#19b56a',sock:'#19b56a',sockTrim:'#0d7a45',boot:'#101216',ink:'#ffffff',inkOut:null,front:'fb'},
  rival:{style:1,c1:'#eef3f4',c2:'#0f8f80',sleeve:'#0f8f80',trim:'#eef3f4',collar:'#0f8f80',shorts:'#0f8f80',shortsTrim:'#eef3f4',sock:'#eef3f4',sockTrim:'#0f8f80',boot:'#1a1a1a',ink:'#0c5a50',inkOut:null,front:'none'},
  rival2:{style:1,c1:'#7a1f2b',c2:'#4d0f18',sleeve:'#4d0f18',trim:'#e9c46a',collar:'#e9c46a',shorts:'#7a1f2b',shortsTrim:'#e9c46a',sock:'#7a1f2b',sockTrim:'#e9c46a',boot:'#1a1a1a',ink:'#f1e0b0',inkOut:null,front:'none'},
  rivalgk:{style:1,c1:'#f08a24',c2:'#b85f10',sleeve:'#b85f10',trim:'#222222',collar:'#222222',shorts:'#b85f10',shortsTrim:'#f08a24',sock:'#f08a24',sockTrim:'#222222',boot:'#1a1a1a',ink:'#ffffff',inkOut:null,front:'none'},
  ref:{style:1,c1:'#17191f',c2:'#17191f',sleeve:'#17191f',trim:'#ffe600',collar:'#17191f',shorts:'#17191f',shortsTrim:'#17191f',sock:'#17191f',sockTrim:'#ffe600',boot:'#111111',ink:'#17191f',inkOut:null,front:'none'},
};
const texCache={};
function kitMaterial(kit,o){
  const k=KITS[kit];
  const bk=`${kit}|${o.name}|${o.num}`,fk=`${kit}|${o.crestTxt||''}|${o.sponsor||''}`;
  const back=texCache['b'+bk]||(texCache['b'+bk]=backTex(o.name||'',String(o.num??''),k.ink,k.inkOut));
  const front=texCache['f'+fk]||(texCache['f'+fk]=frontTex(k.front,o.crestTxt,o.sponsor,k.style===0?'#ffffff':k.ink));
  const m=new THREE.MeshStandardMaterial({roughness:.82,metalness:0,side:THREE.DoubleSide});
  const U={uC1:{value:C(k.c1)},uC2:{value:C(k.c2)},uSleeve:{value:C(k.sleeve)},uTrim:{value:C(k.trim)},uCollar:{value:C(k.collar)},uShorts:{value:C(k.shorts)},uShortsTrim:{value:C(k.shortsTrim)},
    uSock:{value:C(k.sock)},uSockTrim:{value:C(k.sockTrim)},uBoot:{value:C(o.boot||k.boot)},uSkin:{value:o.skinColor.clone()},uStyle:{value:k.style},uBack:{value:back},uFront:{value:front},
    uLong:{value:o.longSleeve?1:0},uUnder:{value:C(o.underColor||k.sleeve)},uBand:{value:o.captain?1:0},uGlove:{value:o.gloves?1:0},uGloveC:{value:C(o.gloveColor||'#f2f2f2')},uChestY:{value:BASE.chestY},uNeckY:{value:BASE.neckY},uHipY:{value:BASE.hipY},uFloor:{value:BASE.floorY}};
  m.onBeforeCompile=sh=>{
    Object.assign(sh.uniforms,U);
    sh.vertexShader=sh.vertexShader.replace('#include <common>',`#include <common>
      attribute vec3 aRest;attribute vec3 aRestN;attribute vec4 aF;attribute float aArm;
      varying vec3 vRest;varying vec3 vRestN;varying vec4 vF;varying float vArm;`)
      .replace('#include <begin_vertex>',`#include <begin_vertex>
      vRest=aRest;vRestN=aRestN;vF=aF;vArm=aArm;`);
    sh.fragmentShader=sh.fragmentShader.replace('#include <common>',`#include <common>
      varying vec3 vRest;varying vec3 vRestN;varying vec4 vF;varying float vArm;
      uniform vec3 uC1,uC2,uSleeve,uTrim,uCollar,uShorts,uShortsTrim,uSock,uSockTrim,uBoot,uSkin;uniform int uStyle;uniform sampler2D uBack,uFront;uniform float uChestY,uNeckY,uHipY,uFloor,uLong,uBand,uGlove;uniform vec3 uUnder,uGloveC;
      float kRough=0.82;`)
      .replace('#include <color_fragment>',`#include <color_fragment>
      {
        vec3 r=vRest;vec3 c=uSkin;kRough=0.6;
        if(vArm>1.5){if(uGlove>0.5){c=uGloveC;kRough=0.5;}}else if(vArm>0.75&&uLong>0.5){c=uUnder;kRough=0.8;}
        if(vF.w>0.0){c=uBoot;kRough=0.32;float h=r.y-uFloor;if(h<0.016)c=vec3(0.92);else if(h<0.05&&h>0.034&&abs(r.z)<0.3)c=mix(c,uSockTrim,0.0);}
        else if(vF.z>0.0){c=uSock;kRough=0.9;if(vF.z<0.04)c=uSockTrim;}
        else if(vF.x>0.0){
          kRough=0.76;
          if(vArm>0.75){c=uSleeve;if(vF.x<0.024)c=uTrim;if(uBand>0.5&&r.x>0.0&&vF.x>0.04&&vF.x<0.085)c=vec3(1.0,0.82,0.0);}
          else{
            if(uStyle==0){float s=step(0.5,fract(r.x/0.11+0.25));c=mix(uC1,uC2,s);}
            else if(uStyle==2){c=uC1;float d=abs(r.y-(uChestY-0.01));if(d<0.045)c=uC2;else if(d<0.056)c=uTrim;}
            else if(uStyle==3){c=uC1;float d=abs(abs(r.x)-0.1);if(d<0.007&&r.y<uNeckY-0.05)c=uC2;}
            else{c=uC1;if(abs(r.x)>0.15)c=uC2;}
            float sgn=vRestN.z;
            if(sgn<-0.1){vec2 uv=vec2(0.5-r.x/0.34,(r.y-(uChestY-0.21))/0.34);if(uv.x>0.0&&uv.x<1.0&&uv.y>0.0&&uv.y<1.0){vec4 t=texture2D(uBack,uv);c=mix(c,t.rgb,t.a);}}
            if(sgn>0.1){vec2 uv=vec2(0.5+r.x/0.34,(r.y-(uChestY-0.25))/0.34);if(uv.x>0.0&&uv.x<1.0&&uv.y>0.0&&uv.y<1.0){vec4 t=texture2D(uFront,uv);c=mix(c,t.rgb,t.a);}}
            if(r.y>uNeckY-0.012)c=uCollar;
            if(r.y<uHipY-0.092)c=mix(c,uTrim,0.9);
          }
        }
        else if(vF.y>0.0){c=uShorts;kRough=0.7;if(vF.y<0.016)c=uShortsTrim;}
        diffuseColor.rgb=c;
      }`)
      .replace('#include <roughnessmap_fragment>',`#include <roughnessmap_fragment>
      roughnessFactor=kRough;`);
  };
  m.customProgramCacheKey=()=>'kit3';
  return m;
}

export const SKINS=[[1,1,1],[.92,.82,.76],[.72,.58,.5],[.5,.38,.31]];
export const HAIRS=['#1b1410','#2e2118','#0c0c0e','#5a4326','#8a6a3a'];

export function makePlayer(o={}){
  const root=new THREE.Group(),m=SkeletonUtils.clone(BASE.scene);
  m.position.y=-BASE.floorY;root.add(m);
  const tone=SKINS[o.skin??0],H=BASE.head;
  const skinColor=H.skin.clone().multiply(new THREE.Color(tone[0],tone[1],tone[2]));
  const mat=kitMaterial(o.kit||'fb',{...o,skinColor});
  const bones={};
  m.traverse(c=>{if(c.isSkinnedMesh){c.material=mat;c.castShadow=true;c.receiveShadow=true;c.frustumCulled=false}if(c.isBone)bones[short(c.name)]=c});
  root.updateMatrixWorld(true);
  const hg=new THREE.Group(),toneC=new THREE.Color(tone[0],tone[1],tone[2]);
  for(const k in H.parts){
    if(k==='Wolf3D_Beard'&&!o.beard)continue;
    const src=H.parts[k],mm=src.mat.clone();
    if(k==='Wolf3D_Head'){mm.color=toneC.clone();mm.roughness=.62}
    if(k==='Wolf3D_Beard'){mm.color=new THREE.Color(o.hair||HAIRS[0]).multiplyScalar(1.6)}
    const me=new THREE.Mesh(src.geo,mm);me.castShadow=true;hg.add(me);
  }
  if(o.hair!==null&&o.hairStyle!=='kel'){const st=o.hairStyle||'kisa';const hc=new THREE.Color(o.hair||HAIRS[0]);if(st==='sifir')hc.lerp(skinColor,.35);const hm=new THREE.Mesh(H.hairs[st],new THREE.MeshStandardMaterial({color:hc,roughness:.95}));hm.castShadow=true;hg.add(hm)}
  const hw=bones.Head.getWorldPosition(V());
  hg.position.copy(hw).add(V(0,o.headDy??-.012,o.headDz??.004));hg.scale.setScalar(o.headScale??1.02);
  root.add(hg);root.updateMatrixWorld(true);bones.Head.attach(hg);
  const mixer=new THREE.AnimationMixer(m),acts={};
  BASE.animations.forEach(a=>{acts[a.name]=mixer.clipAction(a)});
  const P={root,bones,mixer,o,
    anim(name,t){for(const k in acts)acts[k].stop();acts[name].play();mixer.setTime(t);return P},
    pose(d){for(const k in d){const e=d[k];bones[k].quaternion.multiply(new THREE.Quaternion().setFromEuler(new THREE.Euler(e[0],e[1],e[2])))}return P},
    at(x,z,rot,y){root.position.set(x,y||0,z);if(rot!==undefined)root.rotation.y=rot;return P},
    // kemiği karakter uzayındaki yöne çevir (+Z ileri, +X karakterin solu, +Y yukarı)
    aim(d){root.updateMatrixWorld(true);const rq=root.getWorldQuaternion(new THREE.Quaternion());
      for(const k in d){const b=bones[k];b.parent.updateWorldMatrix(true,false);b.updateWorldMatrix(false,false);
        const qb=b.getWorldQuaternion(new THREE.Quaternion()),ch=bones[CHILD[k.replace(/^(Left|Right)/,'')]?k.replace(/(UpLeg|Leg|Foot|Arm|ForeArm)$/,m=>CHILD[m]):CHILD[k]];ch.updateWorldMatrix(false,false);const yb=ch.getWorldPosition(V()).sub(b.getWorldPosition(V())).normalize(),dir=V(...d[k]).normalize().applyQuaternion(rq);
        const R=new THREE.Quaternion().setFromUnitVectors(yb,dir),qw=R.multiply(qb),qp=b.parent.getWorldQuaternion(new THREE.Quaternion()).invert();
        b.quaternion.copy(qp.multiply(qw));b.updateWorldMatrix(false,true)}
      return P},
    setPose(name){const Q=POSES[name];if(Q.anim)P.anim(Q.anim[0],Q.anim[1]);mixer.update(0);if(Q.rx!==undefined)root.rotation.x=Q.rx;if(Q.rz!==undefined)root.rotation.z=Q.rz;if(Q.y!==undefined)root.position.y=Q.y;if(Q.aim)P.aim(Q.aim);if(Q.rot)P.pose(Q.rot);return P}};
  const hs=o.height||1.03,bw=o.build||1;root.scale.set(hs*bw,hs,hs*bw);
  return P;
}

const CHILD={UpLeg:'Leg',Leg:'Foot',Foot:'ToeBase',Arm:'ForeArm',ForeArm:'Hand',Spine:'Spine1',Spine1:'Spine2',Spine2:'Neck',Neck:'Head',Hips:'Spine'};
export const POSES={
  idle:{anim:['idle',.4]},
  run:{anim:['run',.12]},run2:{anim:['run',.47]},
  windup:{anim:['run',.3],aim:{LeftUpLeg:[.05,-1,.28],LeftLeg:[0,-1,-.12],RightUpLeg:[-.12,-.82,-.55],RightLeg:[-.05,.25,-1],LeftArm:[.75,.25,.45],LeftForeArm:[.5,.5,.7],RightArm:[-.7,-.35,-.6],RightForeArm:[-.5,-.7,-.2],Spine1:[0,1,.12]}},
  shoot:{anim:['idle',.4],aim:{LeftUpLeg:[.05,-1,-.12],LeftLeg:[0,-1,-.2],RightUpLeg:[.12,-.5,.86],RightLeg:[.1,-.12,1],RightFoot:[.05,.2,1],LeftArm:[.85,-.1,-.45],LeftForeArm:[.8,.2,-.1],RightArm:[-.75,-.2,.5],RightForeArm:[-.3,.3,.9],Spine1:[0,1,-.18]}},
  bicycle:{anim:['idle',.4],rx:-1.32,y:1.05,aim:{RightUpLeg:[-.05,-.25,.97],RightLeg:[0,.05,1],RightFoot:[0,.5,.9],LeftUpLeg:[.1,-.8,.6],LeftLeg:[0,-.75,-.66],LeftArm:[.95,-.1,-.3],LeftForeArm:[.7,-.5,-.5],RightArm:[-.95,-.1,-.3],RightForeArm:[-.7,-.5,-.5],Neck:[0,.9,.4]}},
  dive:{anim:['idle',.4],rz:1.25,y:.75,aim:{LeftArm:[.25,1,.05],LeftForeArm:[.1,1,.1],RightArm:[-.3,1,.15],RightForeArm:[-.05,1,.15],LeftUpLeg:[.25,-1,-.1],LeftLeg:[.1,-1,-.35],RightUpLeg:[-.2,-1,.25],RightLeg:[-.1,-.8,-.6]}},
  celebrate:{anim:['run',.47],aim:{LeftArm:[.85,.5,.1],LeftForeArm:[.7,.7,.1],RightArm:[-.85,.5,.1],RightForeArm:[-.7,.7,.1],Neck:[0,1,-.15]}},
  kneeslide:{anim:['idle',.4],rx:-.3,y:-.42,aim:{LeftUpLeg:[.28,-.5,.82],LeftLeg:[.05,-.5,-.86],RightUpLeg:[-.28,-.5,.82],RightLeg:[-.05,-.5,-.86],LeftFoot:[0,-.3,-1],RightFoot:[0,-.3,-1],LeftArm:[.8,.6,-.1],LeftForeArm:[.6,.8,0],RightArm:[-.8,.6,-.1],RightForeArm:[-.6,.8,0]}},
  pass:{anim:['walk',.3],aim:{RightUpLeg:[.1,-.85,.5],RightLeg:[.15,-.8,.6],LeftArm:[.7,-.5,-.3],RightArm:[-.6,-.6,.3]}},
  header:{anim:['idle',.4],y:.45,aim:{LeftUpLeg:[.08,-1,-.2],LeftLeg:[0,-.8,-.6],RightUpLeg:[-.08,-1,.1],RightLeg:[0,-.9,-.45],LeftArm:[.8,-.2,.3],RightArm:[-.8,-.2,.3],Spine1:[0,1,.25],Neck:[0,.8,.6]}},
  armsup:{anim:['idle',.4],aim:{LeftArm:[.35,1,0],LeftForeArm:[.2,1,0],RightArm:[-.35,1,0],RightForeArm:[-.2,1,0]}},
  slide:{anim:['idle',.4],rx:-1.1,y:-.62,aim:{RightUpLeg:[-.05,-.6,.8],RightLeg:[0,-.9,.45],LeftUpLeg:[.2,-.75,.6],LeftLeg:[.1,-.2,-1],LeftArm:[.8,-.3,-.5],RightArm:[-.8,-.3,-.5]}},
};
