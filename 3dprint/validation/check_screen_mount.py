"""Check the real glass/fastener/active-area geometry, not a rendered mockup."""
from pathlib import Path
import json,warnings
import numpy as np
import trimesh
warnings.filterwarnings('ignore',category=RuntimeWarning)

R=Path(__file__).resolve().parents[1]
d=json.loads((R/'source/model-data.json').read_text())
S=d['parameters']['screen'];W=d['parameters']['rack']['width']
refs={r['name']:r for r in d['references']}
def mesh(r):
    g=r['geometry'];return trimesh.Trimesh(vertices=g['v'],faces=g['f'],process=True)
glass=mesh(refs['lcd_glass']);lcd=mesh(refs['lcd_body']);active=mesh(refs['lcd_active'])
raw=d['meshes']['screen_smooth_bezel']
frame=trimesh.Trimesh(vertices=raw['v'],faces=raw['f'],process=True)
pose=next(i['matrix'] for i in d['instances'] if i['part']=='screen_smooth_bezel')
frame.apply_transform(pose)
center=(glass.bounds[0]+glass.bounds[1])/2
zs=[center[2]-S['rear_nut_anchor_y'],center[2]+S['rear_nut_anchor_y']]
checks=[]
for x in [W/2-S['rear_nut_anchor_x'],W/2+S['rear_nut_anchor_x']]:
    for z in zs:
        # Conservatively sweep the whole 3.4-mm clearance bore through the assembly.
        bolt=trimesh.creation.cylinder(radius=1.7,height=18,sections=48)
        turn=trimesh.transformations.rotation_matrix(np.pi/2,[1,0,0])
        bolt.apply_transform(turn);bolt.apply_translation([x,8,z])
        overlap=trimesh.boolean.intersection([bolt,glass],engine='manifold').volume
        lcd_overlap=trimesh.boolean.intersection([bolt,lcd],engine='manifold').volume
        # A full-diameter 1-mm front-skin probe must be completely filled by plastic.
        skin=trimesh.creation.cylinder(radius=1.7,height=1,sections=48)
        skin.apply_transform(turn);skin.apply_translation([x,.5,z])
        fraction=trimesh.boolean.intersection([skin,frame],engine='manifold').volume/skin.volume
        checks.append({'x':x,'z':float(z),'shaft_glass_overlap_mm3':float(overlap),'shaft_lcd_overlap_mm3':float(lcd_overlap),'front_face_solid_fraction':round(float(fraction),6)})
        assert overlap<.01 and lcd_overlap<.01 and fraction>.999
aperture=np.array([[W/2-S['window_width']/2,center[2]-S['window_height']/2],
                   [W/2+S['window_width']/2,center[2]+S['window_height']/2]])
ab=active.bounds[:,[0,2]]
assert (ab[0]>=aperture[0]).all() and (ab[1]<=aperture[1]).all()
rear=[i for i in d['instances'] if i['part'].startswith('front_column_') and i['matrix'][1][3]>200]
assert len(rear)==8
assert len([i for i in d['instances'] if i['part']=='screen_smooth_bezel'])==1
toe_front=S['bezel_depth']-(S['assembly_max_depth']-S['cover_glass_thickness'])
cover_back=S['front_lip']+S['front_pad_thickness']+S['cover_glass_thickness']
assert abs(toe_front-cover_back-S['rear_pad_thickness'])<1e-6
contact_checks=[]
for name,r in refs.items():
    if not name.startswith('screen_rear_pad_'):continue
    pad=mesh(r)
    overlap=trimesh.boolean.intersection([pad,lcd],engine='manifold').volume
    bounds=pad.bounds
    assert overlap<.01
    assert bounds[0,0]>=glass.bounds[0,0] and bounds[1,0]<=glass.bounds[1,0]
    assert abs(bounds[0,1]-cover_back)<.001 and abs(bounds[1,1]-toe_front)<.001
    contact_checks.append({'pad':name,'lcd_overlap_mm3':float(overlap),'gap_filled_mm':float(bounds[1,1]-bounds[0,1])})
out={'source':'Waveshare CT glass outline; generated CAD geometry',
     'glass_has_no_mounting_holes':True,'screen_bolt_checks':checks,
     'active_area_unobscured':True,'front_bezel_fasteners_hidden':True,
     'rear_column_shell_count':len(rear),'front_bezel_piece_count':1,
     'cover_glass_thickness_mm':S['cover_glass_thickness'],'total_assembly_depth_mm':S['assembly_max_depth'],
     'stepped_toe_rear_pad_checks':contact_checks,
     'not_checked':'Physical glass tolerance, foam compression, actual FPC bending radius and long-term strength require trial assembly.'}
(R/'validation/screen-mount-report.json').write_text(json.dumps(out,indent=2))
print(json.dumps(out))
