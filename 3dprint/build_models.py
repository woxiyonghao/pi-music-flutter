"""Parametric mechanical fit prototype, millimetres. CAD truth -> STL/STEP/3MF/viewer.
Run: python build_models.py. Dependencies: cadquery, trimesh, numpy.
The unmeasured black Pi case and equipment are explicit keep-out placeholders.
"""
from pathlib import Path
import json, math, zipfile, struct, html, collections
import numpy as np
import cadquery as cq
import trimesh
from xml.etree.ElementTree import Element, SubElement, tostring

ROOT=Path(__file__).resolve().parent
P=json.loads((ROOT/'parameters.json').read_text())
for d in ['stl','step','3mf','validation','calibration','source']:
    (ROOT/d).mkdir(exist_ok=True)
W,D,T=P['rack']['width'],P['rack']['depth'],P['rack']['shelf_thickness']
HEIGHTS=P['rack']['bay_heights_bottom_to_top']; F=P['fasteners']
HOLE,HEAD,NUT=F['structural_clearance'],F['head_diameter'],F['nut_across_flats']
floors=[0]
for height in HEIGHTS: floors.append(floors[-1]+T+height)
parts={}; instances=[]; refs=[]

def box(w,d,h,x=0,y=0,z=0):
    return cq.Workplane('XY').box(w,d,h,centered=(False,False,False)).translate((x,y,z))
def cyl(d,h,x=0,y=0,z=0):
    return cq.Workplane('XY').circle(d/2).extrude(h).translate((x,y,z))
def hexhole(af,h,x=0,y=0,z=0):
    return cq.Workplane('XY').polygon(6,2*af/math.sqrt(3)).extrude(h).translate((x,y,z))
def rounded(w,d,h,r,x=0,y=0,z=0):
    s=cq.Workplane('XY').box(w,d,h,centered=(True,True,False))
    if r: s=s.edges('|Z').fillet(r)
    return s.translate((x,y,z))
def cuts(s,items):
    if not items:return s
    cutters=items[0].val()
    if len(items)>1:cutters=cutters.fuse(*[v.val() for v in items[1:]]).clean()
    return s.cut(cutters)
def union(items):
    s=items[0]
    for v in items[1:]:s=s.union(v)
    return s
def axis_hole(d,h,axis,origin):
    s=cyl(d,h)
    if axis=='x':s=s.rotate((0,0,0),(0,1,0),90)
    if axis=='y':s=s.rotate((0,0,0),(1,0,0),-90)
    return s.translate(origin)
def axis_hex(af,h,axis,origin):
    s=hexhole(af,h)
    if axis=='x':s=s.rotate((0,0,0),(0,1,0),90)
    if axis=='y':s=s.rotate((0,0,0),(1,0,0),-90)
    return s.translate(origin)
def hole_z(s,x,y,thickness,cb=True,nut=False,diam=None):
    d=diam or HOLE
    holes=[cyl(d,thickness+2,x,y,-1)]
    if cb:holes.append(cyl(HEAD,F['head_recess']+0.1,x,y,thickness-F['head_recess']))
    if nut:holes.append(hexhole(NUT,F['nut_depth']+.1,x,y,-.1))
    return cuts(s,holes)
def matrix(translation=(0,0,0),rotation=(0,0,0)):
    return trimesh.transformations.compose_matrix(translate=translation,angles=np.radians(rotation))
def addpart(name,s,label,category,orientation=(0,0,0),notes=''):
    assert name not in parts
    shape=s.val()
    if not shape.isValid():raise ValueError('Invalid CAD: '+name)
    if len(shape.Solids())!=1:raise ValueError('Not one solid: '+name+' '+str(len(shape.Solids())))
    cq.exporters.export(s,str(ROOT/'step'/f'{name}.step'))
    # Geometry stored in engineering-local coordinates. Print STL is bed oriented separately.
    # OCP STL exporter re-meshes adjacent BREP faces consistently (raw per-face tessellation can duplicate seams).
    raw_path=ROOT/'validation'/'_cad_mesh.stl'
    remeshed=cq.importers.importStep(str(ROOT/'step'/f'{name}.step'))
    cq.exporters.export(remeshed,str(raw_path),tolerance=.03,angularTolerance=.08)
    mesh=trimesh.load_mesh(raw_path,process=True)
    mesh.merge_vertices(digits_vertex=6)
    mesh.update_faces(mesh.nondegenerate_faces())
    mesh.update_faces(mesh.unique_faces());mesh.remove_unreferenced_vertices();mesh.fix_normals()
    if not mesh.is_watertight or mesh.volume<=0:
        mesh.export(ROOT/'validation'/f'{name}_debug.stl')
        raise ValueError('Non-watertight STL: '+name+str({'faces':len(mesh.faces),'euler':mesh.euler_number,'broken':len(trimesh.repair.broken_faces(mesh))}))
    print_mesh=mesh.copy(); print_mesh.apply_transform(matrix(rotation=orientation))
    print_mesh.apply_translation(-print_mesh.bounds[0]);print_mesh.export(ROOT/'stl'/f'{name}.stl')
    parts[name]={'name':name,'label':label,'category':category,'mesh':mesh,'print_mesh':print_mesh,
                 'orientation':orientation,'notes':notes,'cad_volume_mm3':shape.Volume()}
    print('OK',name,flush=True)
    return name
def inst(name,t=(0,0,0),r=(0,0,0),label=None,tier=None):
    instances.append({'part':name,'matrix':matrix(t,r).round(8).tolist(),'label':label or parts[name]['label'],'tier':tier})
def refmesh(name,s,color,label,group='device'):
    vs,fs=s.val().tessellate(.3,.2)
    m=trimesh.Trimesh(vertices=[v.toTuple() for v in vs],faces=fs,process=True)
    refs.append({'name':name,'label':label,'color':color,'group':group,'mesh':m})

# 24 mm universal posts: load is carried by flat contact, side bolts brace the stack.
for h in sorted(set(HEIGHTS)):
    s=box(24,24,h).edges('|Z').chamfer(1)
    s=s.union(box(19,24,6,23,0,h-6)).union(box(24,19,6,0,23,0))
    # Open inner service channel leaves two 8-mm structural walls; short kit bolts reach nuts.
    s=s.cut(box(18,18,h-12,8,8,6))
    holes=[]
    hole_heights=[14,26,h-26,h-14]+([50,h-50] if h==HEIGHTS[2] else [])
    for z in sorted(set(hole_heights)):
        for ax in ['x','y']:
            o=(-1,12,z) if ax=='x' else (12,-1,z)
            n=(4.6,12,z) if ax=='x' else (12,4.6,z)
            holes.extend([axis_hole(HOLE,26,ax,o),axis_hex(NUT,3.5,ax,n)])
    holes += [cyl(HOLE,8,34,12,h-7),hexhole(NUT,3.5,34,12,h-6.1),
              cyl(HOLE,8,12,34,-1),hexhole(NUT,3.5,12,34,2.6)]
    addpart(f'post_{h}',cuts(s,holes),f'承重立柱 {h} mm','frame',(90,0,0),notes='8 mm L 形承重壁，M4×12 横向连接；上下承台用 M4×12，配 M4 六角螺母。')

corners=[(0,0,0),(W,0,90),(W,D,180),(0,D,270)]
for tier,h in enumerate(HEIGHTS):
    for x,y,rot in corners:inst(f'post_{h}',(x,y,floors[tier]+T),(0,0,rot),tier=tier)

# Two shelf halves, 130 x 244, fit a P1S while avoiding excessive joints.
top_tab_points=[]; bottom_tab_points=[];foot_points=[]
for x,y,rot in corners:
    c,sn=math.cos(math.radians(rot)),math.sin(math.radians(rot))
    def xy(a,b):return (x+c*a-sn*b,y+sn*a+c*b)
    top_tab_points.append(xy(34,12));bottom_tab_points.append(xy(12,34));foot_points.append(xy(12,12))
center_points=[(W/2+sx*a,D/2+sy*b) for sx in [-1,1] for sy in [-1,1] for a,b in [(20,32),(32,20)]]
seam_points=[(W/2+sx*20,yy+sy*6) for yy in [16,D-16] for sx in [-1,1] for sy in [-1,1]]
baseholes=top_tab_points+bottom_tab_points+center_points+seam_points+foot_points
controller_mounts=[(W/2-27,50),(W/2+27,50)]
floor_names={}
for cable in [False,True]:
    slab=box(W,D,T)
    for x,y in baseholes:
        bottom=any(abs(x-bx)<.01 and abs(y-by)<.01 for bx,by in bottom_tab_points)
        slab=hole_z(slab,x,y,T,cb=not bottom)
    # Bottom-of-next-post bolts are inserted upward; the recess is on the underside.
    slab=cuts(slab,[cyl(HEAD,F['head_recess']+.1,x,y,-.1) for x,y in bottom_tab_points])
    if cable:slab=slab.cut(rounded(68,38,T+2,9,W/2,D-65,-1))
    for x,y in controller_mounts:slab=slab.cut(cyl(3.4,T+2,x,y,-1))
    for ix in range(2):
        for iy in range(1):
            x0,y0=ix*W/2,0
            q=slab.intersect(box(W/2,D,T,x0,y0,0)).translate((-x0,-y0,0))
            name=f'shelf_{"cable" if cable else "plain"}_{ix}{iy}'
            addpart(name,q,f'层板 {ix}{iy}'+('（穿线型）' if cable else ''),'shelf')
            floor_names[(cable,ix,iy)]=name
for level,z in enumerate(floors):
    cable=level in [1,2]
    for ix in range(2):
        for iy in range(1):inst(floor_names[(cable,ix,iy)],(ix*W/2,0,z),tier=min(level,3))

s=box(84,84,6,-42,-42,0)
for x,y in center_points:s=hole_z(s,x-W/2,y-D/2,6,cb=False,nut=True)
addpart('shelf_center_splice',s,'层板中央连接片','joint')
s=box(60,24,6,-30,-12,0)
for x in [-20,20]:
    for y in [-6,6]:s=hole_z(s,x,y,6,cb=False,nut=True)
addpart('shelf_edge_splice',s,'层板前后连接片','joint')
for level,z in enumerate(floors):
    inst('shelf_center_splice',(W/2,D/2,z-6),tier=min(level,3))
    for y in [16,D-16]:inst('shelf_edge_splice',(W/2,y,z-6),tier=min(level,3))

# Thin front/back post joiners (not back panels). Printed flat, countersunk as cylindrical pockets.
s=rounded(20,80,5,2)
for y in [-30,30]:s=hole_z(s,0,y,5)
addpart('post_stack_joiner',s,'立柱跨层连接片','joint')
for level in [1,2,3]:
    z=floors[level]+4
    for x in [12,W-12]:
        inst('post_stack_joiner',(x,0,z),(90,0,0),tier=level)
        inst('post_stack_joiner',(x,D,z),(-90,0,0),tier=level)

# Identical chamfered shells on all four columns conceal joiners and spare holes.
# Each bay remains a separate print; the two visible M4x20 bolts also clamp the core.
FC=P['front_columns']; projection=FC['front_projection']; half_extra=(FC['face_width']-24)/2
for tier,h in enumerate(HEIGHTS):
    full_h=T+h+(T if tier==len(HEIGHTS)-1 else 0)
    gap=FC['seam_gap'];ch=FC['corner_chamfer']
    outline=[(-half_extra,0),(24+half_extra,0),(24+half_extra,-projection+ch),
             (24+half_extra-ch,-projection),(-half_extra+ch,-projection),(-half_extra,-projection+ch)]
    s=cq.Workplane('XY').polyline(outline).close().extrude(full_h-gap).edges('#Z').chamfer(.6)
    # Existing joiner is 20 wide, 5 deep; leave a real internal pocket with clearance.
    s=s.cut(box(24.8,5+FC['joint_cover_clearance']+1,full_h+2,-.4,-5-FC['joint_cover_clearance'],-1))
    zs=[T+26-gap/2,T+h-26-gap/2]
    # Local annular pads bridge the assembly clearance at EVERY fastener.
    # End stations bear on the post; other stations bear on the joiner's face.
    for j,z in enumerate(zs):
        end=(tier==0 and j==0) or (tier==len(HEIGHTS)-1 and j==1)
        pad_depth=FC['joint_cover_clearance']+(5 if end else 0)
        s=s.union(axis_hole(12,pad_depth,'y',(12,-5-FC['joint_cover_clearance'],z)))
        s=s.cut(axis_hole(HOLE,projection+2,'y',(12,-projection-1,z)))
        s=s.cut(axis_hole(HEAD,F['head_recess']+.1,'y',(12,-projection-.1,z)))
    name=f'front_column_{tier}'
    addpart(name,s,f'前后通用倒角柱壳 · 第{tier+1}层','column',(90,0,0),notes='四角同款，每层打印 4 件。32 mm 宽、4 mm 倒角；每件两颗 M4×20 配螺母，兼夹紧隐藏跨层连接片。先装内部设备与支架，最后封柱壳。')
    for x in [0,W-24]:inst(name,(x,0,floors[tier]+gap/2),tier=tier)
    if FC.get('rear_enabled'):
        for x in [24,W]:inst(name,(x,D,floors[tier]+gap/2),(0,0,180),tier=tier)

# One panel per side per tier. Screen panel has adjustable fixture slots, clear ventilation webs.
for h in sorted(set(HEIGHTS)):
    for half in [0]:
      for side in ['left','right']:
        length=D; s=box(length,h,4)
        holes=[]
        for post_y in [12,length-12]:
            for zz in [14,h-14]:
                holes.extend([cyl(HOLE,6,post_y,zz,-1),cyl(HEAD,2.1,post_y,zz,-.1)])
        mount_positions=sorted(set(P['pi_case']['lower_hook_y']+P['pi_case']['upper_hook_y'])) if side=='left' else [75,155]
        if h==HEIGHTS[2]:
            for mount_y in mount_positions:
                holes += [rounded(HOLE,112,6,HOLE/2-.1,mount_y,75,-1),
                          rounded(HEAD,112+HEAD-HOLE,2.1,HEAD/2-.1,mount_y,75,-.1)]
        for zz in np.arange(34,h-22,14):
            for yy in [38,76,114,152,190,226]:
                if h==HEIGHTS[2] and min(abs(yy-v) for v in mount_positions)<25:continue
                holes.append(rounded(27,6,6,2,yy,float(zz),-1))
        s=cuts(s,holes)
        if side=='left':addpart(f'side_{h}_{half}',s,f'左通风侧板 {h} mm','panel',(180,0,0))
        else:addpart(f'side_{h}_right',s.mirror('XY').translate((0,0,4)),f'右通风侧板 {h} mm','panel')
for tier,h in enumerate(HEIGHTS):
    for half in [0]:
        y0=0;z=floors[tier]+T
        # local X -> global Y, local Y -> global Z, local Z -> global X
        # rotate 90 about X then 90 about Z yields (Y,Z,X).
        inst(f'side_{h}_{half}',(-4,y0,z),(90,0,90),tier=tier)
        inst(f'side_{h}_right',(W,y0,z),(90,0,90),tier=tier)

# One-piece smooth rim, with NO front screw holes and NO holes in the glass.
# Local Y points DOWN and local Z points towards the open rear of the rack.
S=P['screen']; BW,BH=S['bezel_width'],S['bezel_height']; BD=S['bezel_depth']
bezel=rounded(BW,BH,BD,3).faces('<Z').edges().chamfer(.5)
bezel=bezel.cut(rounded(S['window_width'],S['window_height'],BD+2,2,0,-S['window_offset_up'],-1))
clear=S['glass_clearance_per_side']
bezel=bezel.cut(rounded(S['glass_width']+2*clear,S['glass_height']+2*clear,BD,3+clear,0,0,S['front_lip']))
AX,AY=S['rear_nut_anchor_x'],S['rear_nut_anchor_y']
for x in [-AX,AX]:
    for y in [-AY,AY]:
        # Blind pilot stops 1.8 mm short of the front. A nut loads from the SIDE,
        # below a retaining roof; all hardware is outside the glass outline.
        bezel=bezel.cut(cyl(3.4,BD-1.8+1,x,y,1.8))
        nut=hexhole(5.7,2.7).rotate((0,0,0),(0,0,1),30).translate((x,y,2.4))
        slot=box(BW/2-AX+1,5.7,2.7,x if x>0 else -BW/2-1,y-2.85,2.4)
        bezel=bezel.cut(nut).cut(slot)
screen_center_z=floors[2]+T+HEIGHTS[2]/2
bezel_matrix=matrix((W/2,0,screen_center_z),(-90,0,0))
addpart('screen_smooth_bezel',bezel,'无正面螺丝的一件式窄框','screen',notes='190×120；前口 168×98，只托玻璃黑边，保留 1.8 mm 螺丝盲孔前壁。玻璃 173×103 无孔。四只 M3 螺母从侧槽装入，后侧锁紧；无需热熔嵌件。')
inst('screen_smooth_bezel',(W/2,0,screen_center_z),(-90,0,0),tier=2)
# These four rigid rear brackets also retain the glass through small soft pads.
# The M3 axis is at world X=39/221, outside the glass X=43.5..216.5.
s=box(42.6,16,6,0,-8,0)
# The outer touch cover is only 0.7 thick. A stepped toe reaches its exposed
# side black border without touching the inset LCD body or its rear components.
toe_depth=S['assembly_max_depth']-S['cover_glass_thickness']
toe_x=W/2-S['rear_contact_x']-8.4
s=s.union(box(S['rear_contact_toe_width'],10,toe_depth,toe_x-S['rear_contact_toe_width']/2,-5,-toe_depth))
s=hole_z(s,3.6,0,6,cb=False)
s=s.cut(hexhole(NUT,F['nut_depth']+.1).rotate((0,0,0),(0,0,1),30).translate((3.6,0,6-F['nut_depth'])))
s=s.cut(cyl(3.4,8,W/2-AX-8.4,0,-1))
addpart('screen_rear_retainer_bracket',s,'玻璃边缘台阶式背面压片','screen',(180,0,0),notes='背面平面朝下打印，台阶朝上。3.5 mm 台阶仅接近 0.7 mm 外沿盖板黑边；在 X=±85.2 处贴 1×10×2 mm 软垫。外端 M4×16 配螺母锁柱芯，内端 M3×12 加约 0.5 mm M3 垫片从后面锁前框，避免盲孔顶死。禁把 4.2 总厚度当外沿玻璃厚度；禁压内缩 LCD/电路/FPC。')
for z in [screen_center_z-AY,screen_center_z+AY]:
    inst('screen_rear_retainer_bracket',(8.4,BD,z),(-90,0,0),tier=2)
    inst('screen_rear_retainer_bracket',(W-8.4,BD,z),(90,0,180),tier=2)

# Real Waveshare adapter mounting holes, M2.5 clearance; no imaginary screen PCB screws.
C=P['controller']; tray=box(62,38,3,-31,-19)
boardholes=[]
for x in [-C['hole_pitch_x']/2,C['hole_pitch_x']/2]:
    for y in [-C['hole_pitch_y']/2,C['hole_pitch_y']/2]:
        tray=tray.union(cyl(6.6,6,x,y,3));boardholes.append((x,y))
for x,y in boardholes:tray=tray.cut(cyl(2.8,11,x,y,-1)).cut(hexhole(5.3,3.0,x,y,-.1))
for x in [-27,27]:tray=tray.cut(cyl(3.4,5,x,0,-1))
addpart('waveshare_adapter_tray',tray,'微雪 HDMI 转接板托盘','screen',notes='50×25.5 PCB，孔距 44.7×20.2，原板孔 2.75；配 M2.5，开关/USB-C/HDMI/FPC 四周留空。')
inst('waveshare_adapter_tray',(W/2,50,floors[2]+T),tier=2)

# Device cradle hooks. Upper hooks are separate inverted retainers adjustable in vertical slots.
for key in ['pi_case','hdd_case']:
    Q=P[key];clear=Q['thickness']+2;span=6+clear+4
    hook=union([box(6,16,27),box(span,16,5),box(4,16,13,span-4,0,0)])
    hook=hook.cut(axis_hole(HOLE,8,'x',(-1,8,19))).cut(axis_hex(NUT,3.5,'x',(2.6,8,19)))
    name=f'{key}_cradle'
    addpart(name,hook,'树莓派带壳托钩' if key=='pi_case' else '硬盘带壳托钩','holder',(90,0,0),notes='上下钩由侧板长槽调节；内表面贴软垫。尺寸取 parameters.json 中带壳厚度。')
    base=floors[2]+T+Q['bottom_above_shelf']-5
    # Global hook X extends into bay; on right rotate 180 about Z.
    for yy in Q.get('lower_hook_y',[75,155]):
        if key=='pi_case':
            inst(name,(0,yy-8,base),tier=2)
        else:
            inst(name,(W,yy+8,base),(0,0,180),tier=2)
    for yy in Q.get('upper_hook_y',[75,155]):
        if key=='pi_case':
            inst(name,(0,yy+8,base+Q['height_when_vertical']+12),(180,0,0),tier=2)
        else:
            inst(name,(W,yy-8,base+Q['height_when_vertical']+12),(180,0,180),tier=2)

s=rounded(30,30,8,3,12,12)
s=s.cut(cyl(HOLE,10,12,12,-1)).cut(hexhole(NUT,4.5,12,12,-.1))
addpart('foot',s,'底脚（另贴防滑垫）','frame')
for x,y,rot in corners:inst('foot',(x,y,-8),(0,0,rot),tier=0)

# Screw coupon has real test diameters and large cylindrical head recesses.
coupon=box(104,46,7)
for i,d in enumerate([3.2,3.4,4.2,4.5]):coupon=coupon.cut(cyl(d,9,13+i*25,12,-1))
for i,d in enumerate([8,9,10,11]):
    coupon=coupon.cut(cyl(4.5,9,13+i*25,33,-1)).cut(cyl(d,3.6,13+i*25,33,3.5))
addpart('screw_fit_coupon',coupon,'螺丝孔试装片','calibration',notes='第一排孔径从左到右 3.2/3.4/4.2/4.5；第二排沉孔直径 8/9/10/11，深 3.5。')

# Non-printable reference envelopes use one coordinate system; rear view is never mirrored.
Q=P['pi_case'];bz=floors[2]+T+Q['bottom_above_shelf']
pi=rounded(Q['length_front_to_back'],Q['height_when_vertical'],Q['thickness'],3)
# Construct local case box directly aligned: width X=thickness, length Y, height Z.
pi=box(Q['thickness'],Q['length_front_to_back'],Q['height_when_vertical'],7,Q['front_y'],bz).edges().fillet(2)
refmesh('pi_black_abs_case',pi,'#353940','黑色 ABS 树莓派壳（待实测）')
for i in range(13):refmesh(f'pi_vent_{i}',box(.5,1.7,44,7+Q['thickness']+.1,Q['front_y']+15+i*5,bz+13),'#15191d','散热面朝内部','detail')
for i,(zz,blue) in enumerate([(8,False),(20,False),(34,True),(46,True)]):
    refmesh(f'pi_usb_{i}',box(11,2,6,16,Q['front_y']-1,bz+zz),'#278ebc' if blue else '#1a1c20','USB 接口朝屏幕（前）','detail')
refmesh('pi_ethernet',box(14,2,12,14,Q['front_y']-1,bz+56),'#858b94','网口朝屏幕（前）','detail')
refmesh('pi_power_up',box(12,Q['power_keepout_length'],22,17,Q['power_keepout_y_start'],bz+Q['height_when_vertical']),'#14191f','向上电源插头保守避让区（待实测）','detail')
refmesh('pi_button_rear',box(7,1.5,5,18,Q['front_y']+Q['length_front_to_back'],bz+55),'#c99c49','后端按键位置示意／按键帽待实测','detail')
U=P['usb_flash']
# A conservative FULL product envelope ahead of a reference port. This is
# neither a printable USB drive nor a claim about the actual inserted length.
usb_center_z=bz+[8,20,34,46][U['reference_usb_index']]+3
refmesh('usb_dtx_keepout',box(U['thickness'],U['length'],U['width'],21.5-U['thickness']/2,Q['front_y']-1-U['length'],usb_center_z-U['width']/2),'#bda257','金士顿 DTX/128GB 总尺寸保守占位；已后移 40 mm，非打印件')
Q=P['hdd_case']; refmesh('hdd_case',box(Q['thickness'],Q['length_front_to_back'],Q['height_when_vertical'],W-7-Q['thickness'],Q['front_y'],floors[2]+T+Q['bottom_above_shelf']).edges().fillet(2),'#282c32','带保护壳硬盘（待实测）')
# LCD glass (black edge), with image plane defined by actual offset.
glass_front=S['front_lip']+S['front_pad_thickness']
glass=box(S['glass_width'],S['cover_glass_thickness'],S['glass_height'],W/2-S['glass_width']/2,glass_front,screen_center_z-S['glass_height']/2)
glass=glass.edges('|Y').fillet(3)
refmesh('lcd_glass',glass,'#111c27','无孔外沿盖板玻璃 173×103×0.7')
refmesh('lcd_body',box(S['lcd_body_width'],S['lcd_body_depth_envelope'],S['lcd_body_height'],W/2+S['lcd_body_offset_x']-S['lcd_body_width']/2,glass_front+S['cover_glass_thickness'],screen_center_z-S['lcd_body_height']/2),'#1b222a','内缩 LCD 及元件保守包络；总厚度最大 4.2')
refmesh('lcd_active',box(154.2144,.2,85.92,W/2-154.2144/2,glass_front-.2,screen_center_z+S['active_offset_up']-85.92/2),'#249b9c','显示区域，横屏且向上偏移 2.35','display')
# Foam is a purchased material, shown as a reference rather than a printable part.
for side in [-1,1]:
    refmesh(f'screen_front_pad_side_{side}',box(1.5,S['front_pad_thickness'],96,W/2+side*85.25-.75,S['front_lip'],screen_center_z-48),'#55585b','前唇软垫，仅接触玻璃黑边','pad')
    refmesh(f'screen_front_pad_edge_{side}',box(168,S['front_pad_thickness'],1.5,W/2-84,S['front_lip'],screen_center_z+side*50.25-.75),'#55585b','前唇软垫，仅接触玻璃黑边','pad')
    for dz in [-AY,AY]:
        refmesh(f'screen_rear_pad_{side}_{dz}',box(S['rear_contact_pad_width'],S['rear_pad_thickness'],10,W/2+side*S['rear_contact_x']-S['rear_contact_pad_width']/2,glass_front+S['cover_glass_thickness'],screen_center_z+dz-5),'#55585b','后压片软垫，只贴外沿盖板黑边，避开内缩 LCD','pad')
pcb_z=floors[2]+T+9
pcb=box(C['width'],C['depth'],C['pcb_thickness'],W/2-C['width']/2,50-C['depth']/2,pcb_z)
for x,y in boardholes:pcb=pcb.cut(cyl(C['mount_hole'],C['pcb_thickness']+2,W/2+x,50+y,pcb_z-1))
refmesh('adapter_pcb',pcb,'#226c99','微雪 HDMI 转接板 50×25.5；四孔 2.75')
refmesh('hdmi_socket',box(15,12,6,W/2-20,50+3,floors[2]+T+10.6),'#a9aeb5','HDMI 插口（向后）','detail')
refmesh('touch_socket',box(9,10,3,W/2+5,50+3,floors[2]+T+10.6),'#a9aeb5','USB-C Touch（向后）','detail')
refmesh('onoff_switch',box(5,7,4,W/2+18,50-5,floors[2]+T+10.6),'#e0d8c4','ON/OFF 开关，保留可达空间','detail')
for key,tier in [('za3',0),('dac',1),('cd',3)]:
    if key=='cd' and not P[key].get('enabled',True):continue
    Q=P[key];ww=Q.get('width',Q.get('envelope_width'));dd=Q.get('depth',Q.get('envelope_depth'));hh=Q['height']
    if key=='dac':
        # Official 100x100x32 envelope INCLUDES protrusions: reserve the knob
        # within the 100-mm depth, rather than adding it in front of that depth.
        front=Q['front_y'];knob_depth=Q['visual_knob_depth'];bottom=floors[tier]+T+Q['bottom_above_shelf']
        refmesh(key,box(ww,dd-knob_depth,hh,W/2-ww/2,front+knob_depth,bottom).edges('|Z').fillet(2),'#242931','TOPPING DX1 II 总包络 100×100×32（含突出部分）；面板细节仅示意')
        refmesh(key+'_knob',axis_hole(26,knob_depth,'y',(W/2+ww/2-25,front,bottom+hh/2)),'#bfc5cf','DX1 II 旋钮示意，已包含在官方总深度内','detail')
        continue
    refmesh(key,box(ww,dd,hh,W/2-ww/2,28,floors[tier]+T+5).edges('|Z').fillet(2),'#242931',{'za3':'ZA3 保守占位包络','cd':'顶层 CD 占位（可选）'}[key])
    if key in ['za3','dac']:
        k=axis_hole(30 if key=='za3' else 26,12,'y',(W/2 if key=='za3' else W/2+ww/2-25,16,floors[tier]+T+5+hh/2))
        refmesh(key+'_knob',k,'#e59a4d' if key=='za3' else '#bfc5cf','旋钮与前方操作空间','detail')

# Part/instance metadata, watertightness and bed-fit checks.
counts=collections.Counter(i['part'] for i in instances)
report=[]; meshdata={}
for name,q in parts.items():
    m=q['print_mesh']; ext=m.extents
    report.append({'part':name,'label':q['label'],'quantity':counts[name] or 1,'category':q['category'],
                   'print_bbox_mm':ext.round(3).tolist(),'watertight':bool(m.is_watertight),'bodies':len(m.split()),
                   'volume_cm3':round(float(m.volume/1000),3),'cad_volume_cm3':round(q['cad_volume_mm3']/1000,3),
                   'notes':q['notes'],'fits_250mm_xy':bool(max(ext[:2])<=250)})
    original=q['mesh']
    meshdata[name]={'v':original.vertices.round(4).tolist(),'f':original.faces.tolist()}
    if not max(ext[:2])<=P['printer']['max_part_target_xy']:raise ValueError('Part exceeds target XY '+name+str(ext))
for r in refs:
    r['geometry']={'v':r['mesh'].vertices.round(3).tolist(),'f':r['mesh'].faces.tolist()}; del r['mesh']
model={'parameters':P,'floors':floors,'parts':report,'meshes':meshdata,'instances':instances,'references':refs,
       'coordinate_system':'X:左→右，Y:前屏幕→后敞口，Z:上。所有视图共享同一变换；无镜像后视图。'}
(ROOT/'source'/'model-data.json').write_text(json.dumps(model,separators=(',',':'),ensure_ascii=False))
(ROOT/'validation'/'mesh-report.json').write_text(json.dumps(report,indent=2,ensure_ascii=False))
(ROOT/'parts.csv').write_text('part,label,quantity,x_mm,y_mm,z_mm,volume_cm3\n'+'\n'.join(f'{p["part"]},{p["label"]},{p["quantity"]},'+','.join(map(str,p['print_bbox_mm']))+f',{p["volume_cm3"]}' for p in report),encoding='utf-8-sig')

# Standard 3MF manufacturing packages, geometry only: machine settings must come from the printer.
NS='http://schemas.microsoft.com/3dmanufacturing/core/2015/02'
def write3mf(path,objects):
    root=Element('model',{'unit':'millimeter','xml:lang':'en-US','xmlns':NS})
    SubElement(root,'metadata',{'name':'Title'}).text='Audio rack '+P['revision']+' - UNSLICED'
    SubElement(root,'metadata',{'name':'Designer'}).text='Parametric CAD, see parameters.json'
    resources=SubElement(root,'resources'); build=SubElement(root,'build')
    for idx,(name,mesh,trans) in enumerate(objects,1):
        ob=SubElement(resources,'object',{'id':str(idx),'type':'model','name':name}); me=SubElement(ob,'mesh')
        vs=SubElement(me,'vertices');ts=SubElement(me,'triangles')
        for v in mesh.vertices:SubElement(vs,'vertex',dict(zip(['x','y','z'],[f'{n:.5f}' for n in v])))
        for f in mesh.faces:SubElement(ts,'triangle',dict(zip(['v1','v2','v3'],map(str,f))))
        t=np.array(trans); vals=list(t[:3,:3].T.flatten())+list(t[:3,3])
        SubElement(build,'item',{'objectid':str(idx),'transform':' '.join(f'{v:.7g}' for v in vals)})
    types='<?xml version="1.0"?><Types xmlns="http://schemas.openxmlformats.org/package/2006/content-types"><Default Extension="rels" ContentType="application/vnd.openxmlformats-package.relationships+xml"/><Default Extension="model" ContentType="application/vnd.ms-package.3dmanufacturing-3dmodel+xml"/></Types>'
    rels='<?xml version="1.0"?><Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships"><Relationship Target="/3D/3dmodel.model" Id="rel0" Type="http://schemas.microsoft.com/3dmanufacturing/2013/01/3dmodel"/></Relationships>'
    with zipfile.ZipFile(path,'w',zipfile.ZIP_DEFLATED) as z:
        z.writestr('[Content_Types].xml',types);z.writestr('_rels/.rels',rels);z.writestr('3D/3dmodel.model',tostring(root,encoding='utf-8',xml_declaration=True))

write3mf(ROOT/'3mf'/'ASSEMBLY_VIEW_ONLY_DO_NOT_PRINT.3mf',[(i['part'],parts[i['part']]['mesh'],i['matrix']) for i in instances])
for name,q in parts.items():write3mf(ROOT/'3mf'/f'{name}.3mf',[(name,q['print_mesh'],np.eye(4))])
write3mf(ROOT/'calibration'/'PRINT_FIRST_screw_fit_coupon.3mf',[('screw_fit_coupon',parts['screw_fit_coupon']['print_mesh'],np.eye(4))])
print(json.dumps({'unique_parts':len(parts),'assembly_piece_count':len(instances),'floors':floors,'max_print_part_mm':max(max(q['print_mesh'].extents[:2]) for q in parts.values()),'all_watertight':True},ensure_ascii=False))
