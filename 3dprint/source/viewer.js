import * as THREE from 'three';
import {OrbitControls} from 'three/addons/controls/OrbitControls.js';

const data=JSON.parse(document.querySelector('#cad-data').textContent);
const canvas=document.querySelector('#view');
const renderer=new THREE.WebGLRenderer({canvas,antialias:true,alpha:false});
renderer.setPixelRatio(Math.min(devicePixelRatio,2));renderer.setClearColor('#11161d');
renderer.outputColorSpace=THREE.SRGBColorSpace;renderer.toneMapping=THREE.ACESFilmicToneMapping;renderer.toneMappingExposure=1.35;
const scene=new THREE.Scene(), camera=new THREE.PerspectiveCamera(36,1,.5,7000);camera.up.set(0,0,1);
const controls=new OrbitControls(camera,canvas);controls.enableDamping=true;controls.dampingFactor=.09;
scene.add(new THREE.AmbientLight('#dce6fa',1.5));
for(const [pos,intensity] of [[[200,-500,800],4],[[-500,-100,350],2],[[400,600,600],3]]){
 const l=new THREE.DirectionalLight('#ffffff',intensity);l.position.set(...pos);scene.add(l);
}
const grid=new THREE.GridHelper(1100,22,'#34404d','#202a35');grid.rotation.x=Math.PI/2;grid.position.set(130,140,-9);scene.add(grid);
const root=new THREE.Group();scene.add(root);
const geom=(g)=>{const b=new THREE.BufferGeometry();b.setAttribute('position',new THREE.Float32BufferAttribute(g.v.flat(),3));b.setIndex(g.f.flat());const n=b.toNonIndexed();n.computeVertexNormals();return n;};
const geometries=Object.fromEntries(Object.entries(data.meshes).map(([k,v])=>[k,geom(v)]));
const meta=Object.fromEntries(data.parts.map(x=>[x.part,x]));
const colors={frame:'#59616a',panel:'#424d59',shelf:'#68727f',joint:'#8a939e',holder:'#79818a',screen:'#394550',column:'#505862'};
const printMeshes=[],refMeshes=[];
for(const [index,inst] of data.instances.entries()){
 const m=new THREE.Mesh(geometries[inst.part],new THREE.MeshStandardMaterial({color:colors[meta[inst.part].category]||'#677280',metalness:.14,roughness:.52}));
 const a=new THREE.Matrix4().set(...inst.matrix.flat());a.decompose(m.position,m.quaternion,m.scale);
 m.userData={...inst,index,base:m.position.clone(),originalColor:m.material.color.clone(),meta:meta[inst.part]};root.add(m);printMeshes.push(m);
}
for(const r of data.references){const m=new THREE.Mesh(geom(r.geometry),new THREE.MeshStandardMaterial({color:r.color,metalness:.28,roughness:.46}));m.userData={ref:r};root.add(m);refMeshes.push(m);}
let mode='front',selection=null;
const e=document.querySelector('#explode'),devices=document.querySelector('#devices'),panels=document.querySelector('#panels'),solo=document.querySelector('#part');
const partList=document.querySelector('#part-list');
for(const p of data.parts.filter(x=>x.category!=='calibration')){
 const o=document.createElement('option');o.value=p.part;o.textContent=p.label;solo.append(o);
 const row=document.createElement('button');row.className='part-row';row.dataset.part=p.part;
 const l=document.createElement('span');l.textContent=p.label;const q=document.createElement('small');q.textContent='× '+p.quantity;row.append(l,q);row.onclick=()=>selectPart(p.part,false);partList.append(row);
}
function fitInternal(){return mode==='inside';}
function update(){
 const ex=Number(e.value)/100;document.querySelector('#explode-value').textContent=Math.round(ex*100)+'%';
 for(const m of printMeshes){
  const d=m.userData,cat=d.meta.category;
  m.visible=(!solo.value||d.part===solo.value)&& (panels.checked||cat!=='panel');
  if(fitInternal())m.visible=m.visible&&d.tier===2&&cat!=='panel';
  m.position.copy(d.base);
  if(ex){m.position.z+=d.tier*ex*70;if(cat==='panel')m.position.x+=(d.base.x<130?-1:1)*ex*70;if(cat==='shelf'){m.position.x+=(d.base.x<130?-1:1)*ex*15;m.position.y+=(d.base.y<140?-1:1)*ex*15;}}
 }
 for(const m of refMeshes){
  const n=m.userData.ref.name;
  m.visible=devices.checked&&!solo.value;
  if(fitInternal())m.visible=m.visible&&!/^(za3|dac|cd)/.test(n);
 }
 document.querySelector('#mode-label').textContent=solo.value?'单件 · '+meta[solo.value].label:mode==='inside'?'屏幕层内部 · 移除侧板便于观察':mode==='rear'?'后视 · 背部开放':'正面 · 完整装配';
}
function view(v){mode=v;solo.value='';const c=v==='inside'?[390,560,670]:v==='rear'?[-500,800,590]:[570,-740,580];const t=v==='inside'?[130,122,274]:[130,122,220];camera.position.set(...c);controls.target.set(...t);controls.update();document.querySelectorAll('[data-view]').forEach(b=>b.classList.toggle('active',b.dataset.view===v));update();}
function selectPart(name,isolate=false){
 selection=name;
 for(const m of printMeshes)m.material.color.copy(m.userData.part===name?new THREE.Color('#e8a666'):m.userData.originalColor);
 document.querySelectorAll('.part-row').forEach(b=>b.classList.toggle('selected',b.dataset.part===name));
 const p=meta[name];if(!p)return;
 document.querySelector('#selected-name').textContent=p.label;
 document.querySelector('#selected-detail').textContent=`${p.print_bbox_mm.map(x=>x.toFixed(1)).join(' × ')} mm · ${p.quantity} 件 · ${p.watertight?'封闭实体':'待修复'}\n${p.notes||'独立分件，平放在打印平台后导入切片。'}`;
 const a=document.querySelector('#download-stl');a.href='stl/'+name+'.stl';a.download=name+'.stl';a.hidden=false;
 const b=document.querySelector('#download-3mf');b.href='3mf/'+name+'.3mf';b.download=name+'.3mf';b.hidden=false;
 if(isolate){solo.value=name;const ms=printMeshes.filter(m=>m.userData.part===name);if(ms.length){const center=new THREE.Box3().setFromObject(ms[0]).getCenter(new THREE.Vector3());controls.target.copy(center);camera.position.copy(center).add(new THREE.Vector3(240,-300,240));}update();}
}
for(const b of document.querySelectorAll('[data-view]'))b.onclick=()=>view(b.dataset.view);
e.oninput=update;devices.onchange=update;panels.onchange=update;solo.onchange=()=>{if(solo.value)selectPart(solo.value,true);else view('front');};
const ray=new THREE.Raycaster(),pointer=new THREE.Vector2();let start;
canvas.addEventListener('pointerdown',ev=>start=[ev.clientX,ev.clientY]);
canvas.addEventListener('pointerup',ev=>{if(!start||Math.hypot(ev.clientX-start[0],ev.clientY-start[1])>5)return;const r=canvas.getBoundingClientRect();pointer.set((ev.clientX-r.left)/r.width*2-1,-(ev.clientY-r.top)/r.height*2+1);ray.setFromCamera(pointer,camera);const hits=ray.intersectObjects(printMeshes.filter(m=>m.visible));if(hits.length)selectPart(hits[0].object.userData.part);});
new ResizeObserver(()=>{const r=canvas.parentElement.getBoundingClientRect();renderer.setSize(r.width,r.height,false);camera.aspect=r.width/r.height;camera.updateProjectionMatrix();}).observe(canvas.parentElement);
document.querySelector('#piece-count').textContent=data.instances.length;
document.querySelector('#kind-count').textContent=data.parts.length;
const actualBounds=new THREE.Box3().setFromObject(root).getSize(new THREE.Vector3());
document.querySelector('#rack-size').textContent=actualBounds.toArray().map(v=>Math.round(v)).join(' × ')+' mm';
window.rackViewer={data,scene,camera,controls,view,update,printMeshes,refMeshes};
view('front');
function animate(){requestAnimationFrame(animate);controls.update();renderer.render(scene,camera);}animate();
