from pathlib import Path
import json,numpy as np,trimesh,warnings
warnings.filterwarnings('ignore',category=RuntimeWarning)
R=Path(__file__).resolve().parents[1]
d=json.loads((R/'source/model-data.json').read_text())
meshes={k:trimesh.Trimesh(vertices=v['v'],faces=v['f'],process=True) for k,v in d['meshes'].items()}
world=[]
for idx,i in enumerate(d['instances']):
    m=meshes[i['part']].copy();m.apply_transform(np.array(i['matrix']));world.append((i['part']+'#'+str(idx),m))
checks=0;collisions=[]
for a,(an,am) in enumerate(world):
    for bn,bm in world[a+1:]:
        overlap=np.minimum(am.bounds[1],bm.bounds[1])-np.maximum(am.bounds[0],bm.bounds[0])
        if min(overlap)<.001:continue
        checks+=1
        m=trimesh.boolean.intersection([am,bm],engine='manifold')
        if m.volume>1:collisions.append({'a':an,'b':bn,'volume_mm3':round(float(m.volume),3)})
device_collisions=[]
for r in d['references']:
    if r['name'] not in ['pi_black_abs_case','pi_power_up','pi_button_rear','usb_dtx_keepout','hdd_case','lcd_glass','lcd_body','adapter_pcb','za3','dac']:continue
    vv=np.array(r['geometry']['v']);lo=vv.min(axis=0);hi=vv.max(axis=0)
    actual=trimesh.Trimesh(vertices=vv,faces=r['geometry']['f'],process=True)
    am=actual if actual.is_volume else trimesh.creation.box(extents=hi-lo,transform=trimesh.transformations.translation_matrix((hi+lo)/2))
    for bn,bm in world:
        overlap=np.minimum(am.bounds[1],bm.bounds[1])-np.maximum(am.bounds[0],bm.bounds[0])
        if min(overlap)<.001:continue
        m=trimesh.boolean.intersection([am,bm],engine='manifold')
        if m.volume>1:device_collisions.append({'device':r['name'],'part':bn,'volume_mm3':round(float(m.volume),3)})
out={'method':'triangle-mesh volumetric intersection, manifold; >1mm3 threshold; does not validate unmeasured device dimensions or strength','candidate_print_part_pairs':checks,'print_part_collisions':collisions,'device_envelope_collisions':device_collisions}
(R/'validation/interference-report.json').write_text(json.dumps(out,indent=2))
print(json.dumps(out));raise SystemExit(bool(collisions or device_collisions))
