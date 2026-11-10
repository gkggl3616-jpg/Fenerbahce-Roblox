const {chromium}=require('playwright');
(async()=>{
 const shots=process.argv.slice(2);
 const b=await chromium.launch({args:['--use-gl=angle','--use-angle=swiftshader','--enable-unsafe-swiftshader','--ignore-gpu-blocklist']});
 for(const s of shots){
  const p=await b.newPage({viewport:{width:1600,height:900}});
  p.on('pageerror',e=>console.log('[err]',s,e.message));p.on('console',m=>{const t=m.text();if(t.startsWith('rendered'))console.log(t)});
  try{await p.goto('http://localhost:8765/render.html?shot='+s+'&w=1600&h=900');await p.waitForFunction('window.__done===true',null,{timeout:240000});
  await p.screenshot({path:'out/'+s+'.jpg',type:'jpeg',quality:88});}catch(e){console.log('FAIL',s,e.message.slice(0,200))}
  await p.close();
 }
 await b.close();
})();
