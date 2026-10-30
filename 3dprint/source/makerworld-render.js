import * as THREE from 'three';
import {toCreasedNormals} from 'three/addons/utils/BufferGeometryUtils.js';
const data=JSON.parse(document.querySelector('#cad-data').textContent);
const canvas=document.querySelector('canvas');
const renderer=new THREE.WebGLRenderer({canvas,antialias:true,preserveDrawingBuffer:true});
renderer.setPixelRatio(1);renderer.setSize(1600,1200);renderer.setClearColor('#e8e9e4');
renderer.outputColorSpace=THREE.SRGBColorSpace;renderer.toneMapping=THREE.ACESFilmicToneMapping;renderer.toneMappingExposure=1.45;
renderer.shadowMap.enabled=true;renderer.shadowMap.type=THREE.PCFSoftShadowMap;
const scene=new THREE.Scene();scene.background=new THREE.Color('#e8e9e4');
const camera=new THREE.OrthographicCamera(-490,490,367.5,-367.5,1,5000);camera.up.set(0,0,1);
scene.add(new THREE.HemisphereLight('#fff9ef','#697b8a',2.0));
const key=new THREE.DirectionalLight('#fff3de',3.2);key.position.set(-380,-500,950);key.castShadow=true;
key.shadow.mapSize.set(2048,2048);Object.assign(key.shadow.camera,{left:-560,right:560,top:560,bottom:-560,near:20,far:2000});key.shadow.bias=-.0001;key.shadow.normalBias=.2;key.shadow.radius=5;key.target.position.set(130,122,200);scene.add(key,key.target);
for(const [pos,intensity,col] of [[[550,350,800],2.2,'#f3f8ff'],[[100,-700,200],.9,'#dae4f0']]){const l=new THREE.DirectionalLight(col,intensity);l.position.set(...pos);scene.add(l);}
const floor=new THREE.Mesh(new THREE.PlaneGeometry(5000,5000),new THREE.MeshStandardMaterial({color:'#e5e7e1',roughness:1,metalness:0}));floor.position.set(130,122,-8.2);floor.receiveShadow=true;scene.add(floor);
const root=new THREE.Group();scene.add(root);
function geom(g){const b=new THREE.BufferGeometry();b.setAttribute('position',new THREE.Float32BufferAttribute(g.v.flat(),3));b.setIndex(g.f.flat());return toCreasedNormals(b,Math.PI/5);}
const geoms=Object.fromEntries(Object.entries(data.meshes).map(([k,v])=>[k,geom(v)]));const meta=Object.fromEntries(data.parts.map(p=>[p.part,p]));
const colors={frame:'#42484e',panel:'#383f46',shelf:'#50565d',joint:'#5a626b',holder:'#657078',screen:'#272f35',column:'#323a42'};
const prints=[],refs=[];
for(const i of data.instances){const m=new THREE.Mesh(geoms[i.part],new THREE.MeshStandardMaterial({color:colors[meta[i.part].category],metalness:.05,roughness:.72}));new THREE.Matrix4().set(...i.matrix.flat()).decompose(m.position,m.quaternion,m.scale);m.userData={...i,category:meta[i.part].category};m.castShadow=true;m.receiveShadow=true;root.add(m);prints.push(m);}
// A neutral, vector-drawn demonstration UI, not an actual device screenshot.
function displayTexture(){const c=document.createElement('canvas');c.width=1024;c.height=600;const g=c.getContext('2d');const grad=g.createLinearGradient(0,0,1024,600);grad.addColorStop(0,'#17353c');grad.addColorStop(1,'#071c25');g.fillStyle=grad;g.fillRect(0,0,1024,600);g.fillStyle='#e3f5f0';g.font='22px sans-serif';g.fillText('LOCAL MUSIC',48,56);g.fillStyle='#6aada9';g.font='18px sans-serif';g.fillText('LIBRARY  /  NOW PLAYING',48,91);g.lineWidth=3;g.strokeStyle='#8ee0d2';g.beginPath();for(let x=50;x<975;x+=4){const h=(Math.sin(x*.037)*Math.cos(x*.011)+Math.sin(x*.093)*.3)*58;g.moveTo(x,290-h);g.lineTo(x,290+h);}g.stroke();g.strokeStyle='#3d6268';g.lineWidth=3;g.beginPath();g.moveTo(48,409);g.lineTo(975,409);g.stroke();g.strokeStyle='#9ae2d3';g.beginPath();g.moveTo(48,409);g.lineTo(455,409);g.stroke();g.fillStyle='#e1f4ef';g.font='18px sans-serif';g.fillText('01:42',48,444);g.fillText('04:12',927,444);g.beginPath();g.arc(512,519,35,0,Math.PI*2);g.fillStyle='#9ae2d3';g.fill();g.fillStyle='#113b43';g.fillRect(500,506,7,26);g.fillRect(517,506,7,26);g.fillStyle='#c6dfdc';g.beginPath();g.moveTo(410,503);g.lineTo(388,519);g.lineTo(410,535);g.fill();g.beginPath();g.moveTo(615,503);g.lineTo(637,519);g.lineTo(615,535);g.fill();const t=new THREE.CanvasTexture(c);t.colorSpace=THREE.SRGBColorSpace;return t;}
for(const r of data.references){let m;if(r.name==='lcd_active'){m=new THREE.Mesh(new THREE.PlaneGeometry(154.2144,85.92),new THREE.MeshBasicMaterial({map:displayTexture()}));m.rotation.x=Math.PI/2;m.position.set(130,1.5,274+data.parameters.screen.active_offset_up);}else{m=new THREE.Mesh(geom(r.geometry),new THREE.MeshStandardMaterial({color:r.color,roughness:.64,metalness:.14}));}m.userData={ref:r};m.castShadow=r.group==='device';m.receiveShadow=true;root.add(m);refs.push(m);}
let current='front-structure';
const configs={
 'front-structure':{title:'模块化桌面音频机架',sub:'四角同款倒角柱壳 · 窄边无孔屏框 · 分层打印',badge:'仅打印结构',note:'CAD 结构渲染 · 非实拍 · v0.3.2',metrics:['27 类分件','95 个装配件','外形约 268 × 266 × 463 mm'],pos:[760,-980,700],target:[130,122,220],span:770,devices:false},
 'front-equipped':{title:'装配布局示意',sub:'顶层留空 / 屏幕与树莓派 / DX1 II / ZA3',badge:'设备为尺寸占位',note:'CAD 渲染 · 非实拍 · 图中电子设备不属于打印件',metrics:['173 × 103 mm 触控屏','DX1 II 独立层','ZA3 独立层'],pos:[760,-980,700],target:[130,122,220],span:770,devices:true},
 'rear':{title:'背部开放，方便接线',sub:'各层无后挡板 · 中间两层设置穿线孔',badge:'真实 CAD 后视',note:'CAD 渲染 · 非实拍 · 设备仅作尺寸示意',metrics:['背部敞开','两处 68 × 38 mm 穿线孔','前后同款柱壳'],pos:[-620,1100,710],target:[130,122,220],span:770,devices:true},
 'inside':{title:'树莓派整套后移 40 mm',sub:'左内壁树莓派，右内壁硬盘；侧板及上层隐藏以展示内部',badge:'黄色为 U 盘占位',note:'CAD 剖视示意 · 非实拍 · U 盘及电子设备不打印',metrics:['电源向上 · 散热面朝内','网口 / USB 朝前屏幕','DTX 整长 + 10 mm 拔出避让'],pos:[610,790,760],target:[130,122,274],span:545,devices:true}
};
function setView(mode){current=mode;const c=configs[mode];for(const m of prints)m.visible=mode==='inside'?m.userData.tier===2&&m.userData.category!=='panel':true;for(const m of refs)m.visible=c.devices&&(mode!=='inside'||!/^(za3|dac|cd)/.test(m.userData.ref.name));floor.visible=mode!=='inside';camera.position.set(...c.pos);camera.lookAt(new THREE.Vector3(...c.target));const v=c.span;camera.left=-v*2/3;camera.right=v*2/3;camera.top=v/2;camera.bottom=-v/2;camera.updateProjectionMatrix();document.querySelector('h1').textContent=c.title;document.querySelector('.subtitle').textContent=c.sub;document.querySelector('.badge').textContent=c.badge;document.querySelector('.note').textContent=c.note;document.querySelector('.metrics').innerHTML=c.metrics.map(s=>'<span>'+s+'</span>').join('');renderer.render(scene,camera);return {mode,revision:data.parameters.revision,visiblePrintedPieces:prints.filter(m=>m.visible).length};}
window.makerworldRender={renderer,scene,camera,setView,data};setView('front-structure');document.fonts.ready.then(()=>{renderer.render(scene,camera);window.previewReady=true;});
