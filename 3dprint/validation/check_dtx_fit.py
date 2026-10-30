"""DTX full-size and 10-mm withdrawal corridor vs final printed geometry.
Both transverse orientations, all four REFERENCE USB port centres. These
unmeasured port locations cannot certify the real case or adjacent cable plugs.
"""
from pathlib import Path
import json,numpy as np,trimesh,warnings
warnings.filterwarnings('ignore',category=RuntimeWarning)
R=Path(__file__).resolve().parents[1];d=json.loads((R/'source/model-data.json').read_text());P=d['parameters'];U=P['usb_flash']
world=[]
for i in d['instances']:
    g=d['meshes'][i['part']];m=trimesh.Trimesh(vertices=g['v'],faces=g['f'],process=True);m.apply_transform(i['matrix']);world.append((i['part'],m))
checks=[]
for r in d['references']:
    if not r['name'].startswith('pi_usb_'):continue
    v=np.array(r['geometry']['v']);lo=v.min(0);hi=v.max(0);c=(lo+hi)/2;y=lo[1]
    for w,h in [(U['width'],U['thickness']),(U['thickness'],U['width'])]:
        for travel in [0,U['unplug_travel']]:
            tool=trimesh.creation.box(extents=[w,U['length']+travel,h],transform=trimesh.transformations.translation_matrix([c[0],y-(U['length']+travel)/2,c[2]]))
            hits=[]
            for name,m in world:
                if min(np.minimum(tool.bounds[1],m.bounds[1])-np.maximum(tool.bounds[0],m.bounds[0]))<.001:continue
                vol=trimesh.boolean.intersection([tool,m],engine='manifold').volume
                if vol>1:hits.append({'part':name,'volume_mm3':round(float(vol),3)})
            checks.append({'port':r['name'],'cross_section_mm':[w,h],'withdrawal_mm':travel,'corridor_front_y_mm':round(float(tool.bounds[0,1]),3),'collisions':hits})
bad=[c for c in checks if c['collisions']]
q=P['pi_case'];assert q['front_y']==105 and q['lower_hook_y']==[115,195] and q['upper_hook_y']==[115,165] and q['power_keepout_y_start']==180
out={'revision':P['revision'],'source':U['source'],'manufacturer_envelope_mm':[U['length'],U['width'],U['thickness']],'method':'Full product length retained; no deduction for cap removal or connector insertion. Additional 10-mm straight withdrawal corridor. Printed structure only, actual port/adjacent-plug compatibility unverified.','pi_case_front_y_mm':q['front_y'],'nominal_case_rear_margin_mm':P['rack']['depth']-q['front_y']-q['length_front_to_back'],'checks':checks,'all_passed':not bad,'physical_fit_confirmed':False}
(R/'validation/dtx-fit-report.json').write_text(json.dumps(out,indent=2));print(json.dumps({'checked_corridors':len(checks),'all_passed':not bad,'failed':bad}));raise SystemExit(bool(bad))
