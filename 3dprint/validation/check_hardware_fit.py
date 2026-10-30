"""Check all 202 nominal screw shafts against final assembly geometry.
This verifies alignment and nominal full nut engagement, not threads/torque,
actual pan-head height, installation access, or structural strength.
"""
from pathlib import Path
import json, warnings, math
import numpy as np
import trimesh
warnings.filterwarnings('ignore',category=RuntimeWarning)
R=Path(__file__).resolve().parents[1]
d=json.loads((R/'source/model-data.json').read_text());P=d['parameters'];S=P['screen'];W=P['rack']['width'];D=P['rack']['depth'];T=P['rack']['shelf_thickness'];F=d['floors']
local={k:trimesh.Trimesh(vertices=v['v'],faces=v['f'],process=True) for k,v in d['meshes'].items()}
world=[]
for i in d['instances']:
    m=local[i['part']].copy();m.apply_transform(i['matrix']);world.append((i['part'],m))
refs=[]
for r in d['references']:
    if r['name'] not in ['pi_black_abs_case','pi_power_up','hdd_case','lcd_glass','lcd_body','adapter_pcb','za3','dac','usb_dtx_keepout']:continue
    g=r['geometry'];m=trimesh.Trimesh(vertices=g['v'],faces=g['f'],process=True)
    if not m.is_volume:m=trimesh.creation.box(extents=m.extents,transform=trimesh.transformations.translation_matrix(m.bounds.mean(0)))
    refs.append((r['name'],m))
def collisions(tool,items):
    out=[]
    for name,m in items:
        if min(np.minimum(tool.bounds[1],m.bounds[1])-np.maximum(tool.bounds[0],m.bounds[0]))<.001:continue
        v=trimesh.boolean.intersection([tool,m],engine='manifold').volume
        if v>.05:out.append({'part':name,'volume_mm3':round(float(v),5)})
    return out
results=[]
def check(name,a,b,diam,nut_interval,axis,tip_clearance=None):
    tool=trimesh.creation.cylinder(radius=diam/2,segment=np.array([a,b]),sections=40)
    hits=collisions(tool,world);device_hits=collisions(tool,refs)
    lo,hi=sorted([a[axis],b[axis]]);nlo,nhi=nut_interval
    engaged=max(0,min(hi,nhi)-max(lo,nlo));full=engaged>=nhi-nlo-1e-6
    results.append({'name':name,'start':list(a),'end':list(b),'nominal_diameter_mm':diam,'length_mm':round(float(np.linalg.norm(np.array(b)-a)),3),'shaft_hits':hits,'device_envelope_hits':device_hits,'nut_height_mm':round(nhi-nlo,3),'engagement_mm':round(engaged,3),'full_nominal_nut_engagement':full,'tip_clearance_mm':tip_clearance})
# 80 shelf/splice screws. They seat 3 mm down into an 8-mm shelf.
for z in F:
    points=[(W/2+sx*a,D/2+sy*b) for sx in [-1,1] for sy in [-1,1] for a,b in [(20,32),(32,20)]]
    points += [(W/2+sx*20,yy+sy*6) for yy in [16,D-16] for sx in [-1,1] for sy in [-1,1]]
    for x,y in points:check('shelf_splice_M4x12',[x,y,z-7],[x,y,z+5],4,(z-5.8,z-2.6),2)
# Each of 16 post cores has two shelf tabs.
corners=[(0,0,0),(W,0,90),(W,D,180),(0,D,270)]
for tier,h in enumerate(P['rack']['bay_heights_bottom_to_top']):
    for x,y,rot in corners:
        c,s=math.cos(math.radians(rot)),math.sin(math.radians(rot))
        px=lambda a,b:(x+c*a-s*b,y+s*a+c*b)
        xx,yy=px(34,12);z=F[tier+1]
        check('post_top_tab_M4x12',[xx,yy,z-7],[xx,yy,z+5],4,(z-5.8,z-2.6),2)
        xx,yy=px(12,34);z=F[tier]
        check('post_bottom_tab_M4x12',[xx,yy,z+3],[xx,yy,z+15],4,(z+10.6,z+13.8),2)
    # Four side-panel bolts per side per bay, seating 2.1 mm in 4-mm panel.
    for yy in [12,D-12]:
        for zz in [14,h-14]:
            z=F[tier]+T+zz
            check('side_left_M4x12',[-1.9,yy,z],[10.1,yy,z],4,(4.6,7.8),0)
            check('side_right_M4x12',[W-10.1,yy,z],[W+1.9,yy,z],4,(W-7.8,W-4.6),0)
    # Two screws per column shell; intermediate ones also clamp stack joiners.
    for xx in [12,W-12]:
        for zz in [26,h-26]:
            z=F[tier]+T+zz
            check('column_front_M4x20',[xx,-8,z],[xx,12,z],4,(4.6,7.8),1)
            check('column_rear_M4x20',[xx,D-12,z],[xx,D+8,z],4,(D-7.8,D-4.6),1)
# Four bottom feet.
for x in [12,W-12]:
    for y in [12,D-12]:check('foot_M4x12',[x,y,-7],[x,y,5],4,(-6.8,-3.6),2,1)
# Screen rear brackets: M4 from FRONT of core into bracket's nut; M3 from rear.
cz=F[2]+T+P['rack']['bay_heights_bottom_to_top'][2]/2
for z in [cz-25,cz+25]:
    for x in [12,W-12]:check('screen_bracket_to_core_M4x16',[x,0,z],[x,16,z],4,(10.6,13.8),1)
    for x in [W/2-S['rear_nut_anchor_x'],W/2+S['rear_nut_anchor_x']]:
        check('screen_M3x12_with_0.5_washer',[x,2.5,z],[x,14.5,z],3,(2.7,5.1),1,.7)
# The two small M3 tray bolts use free nuts UNDER the shelf, no printed pockets.
base=F[2]+T
for x in [W/2-27,W/2+27]:check('adapter_tray_M3x16',[x,50,base-13],[x,50,base+3],3,(F[2]-2.4,F[2]),2)
for dx in [-P['controller']['hole_pitch_x']/2,P['controller']['hole_pitch_x']/2]:
    for dy in [-P['controller']['hole_pitch_y']/2,P['controller']['hole_pitch_y']/2]:
        x,y=W/2+dx,50+dy
        check('adapter_M2.5x10_no_extra_washer',[x,y,base+.6],[x,y,base+10.6],2.5,(base+.9,base+2.9),2,.6)
# Eight cradle screws; slots vary in Y, retaining nuts lie in hook's back wall.
for key in ['pi_case','hdd_case']:
    q=P[key];bottom=F[2]+T+q['bottom_above_shelf']-5
    for kind in ['lower','upper']:
        z=bottom+19 if kind=='lower' else bottom+q['height_when_vertical']+12-19
        for y in q.get(kind+'_hook_y',[75,155]):
            if key=='pi_case':check('pi_cradle_M4x8',[-1.9,y,z],[6.1,y,z],4,(2.6,5.8),0,.9)
            else:check('hdd_cradle_M4x8',[W-6.1,y,z],[W+1.9,y,z],4,(W-5.8,W-2.6),0,.9)
bad=[r for r in results if r['shaft_hits'] or r['device_envelope_hits'] or not r['full_nominal_nut_engagement'] or (r['tip_clearance_mm'] is not None and r['tip_clearance_mm']<.19)]
assert len(results)==202,len(results)
out={'revision':P['revision'],'nominal_hardware_assumptions':'M3 nut 2.4; M2.5 nut 2.0; M4 nut 3.2; screen washer 0.5. Actual dimensions, screw heads, threads/torque and installation access not certified. A null tip clearance means an open through connection checked for geometric collision only.','checked_connections':results,'all_passed':not bad,'not_a_strength_or_actual_printer_validation':True}
(R/'validation/hardware-fit-report.json').write_text(json.dumps(out,indent=2))
print(json.dumps({'checked':len(results),'all_passed':not bad,'failed_connections':bad}));raise SystemExit(bool(bad))
