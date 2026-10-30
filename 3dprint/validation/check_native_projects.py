"""Match current bed-oriented STL geometry to every native Bambu project."""
from pathlib import Path
from zipfile import ZipFile
from xml.etree import ElementTree as E
import json,numpy as np,trimesh,hashlib
R=Path(__file__).resolve().parents[1];ns={'m':'http://schemas.microsoft.com/3dmanufacturing/core/2015/02'};pn='{http://schemas.microsoft.com/3dmanufacturing/production/2015/06}path'
d=json.loads((R/'source/model-data.json').read_text());cache={};results=[]
for path in sorted((R/'bambu_reference').glob('*.3mf')):
    with ZipFile(path) as z:
        meta=E.fromstring(z.read('Metadata/model_settings.config'))
        names={o.get('id'):next((m.get('value') for m in o.findall('metadata') if m.get('key')=='name'),None) for o in meta.findall('object')}
        main=E.fromstring(z.read('3D/3dmodel.model'));num=0
        for o in main.findall('m:resources/m:object',ns):
            name=names[o.get('id')];stem=Path(name).stem
            if stem not in cache:cache[stem]=trimesh.load_mesh(R/'stl'/name)
            orig=cache[stem];co=o.find('m:components/m:component',ns)
            f=E.fromstring(z.read(co.get(pn).lstrip('/')))
            part=next(v for v in f.findall('m:resources/m:object',ns) if v.get('id')==co.get('objectid'))
            vs=np.array([[float(v.get(k)) for k in ['x','y','z']] for v in part.findall('m:mesh/m:vertices/m:vertex',ns)])
            fs=np.array([[int(v.get(k)) for k in ['v1','v2','v3']] for v in part.findall('m:mesh/m:triangles/m:triangle',ns)])
            native=trimesh.Trimesh(vertices=vs,faces=fs,process=False)
            assert np.allclose(native.extents,orig.extents,atol=.001),(path,stem,'bounds')
            assert abs(native.volume-orig.volume)<max(.1,abs(orig.volume)*1e-5),(path,stem,'volume')
            assert len(native.faces)==len(orig.faces),(path,stem,'faces')
            num+=1
        results.append({'file':path.name,'verified_meshes':num,'matches_current_stl_bounds_volume_face_count':True})
assert len(results)==len(d['parts'])+2
assert next(q for q in results if q['file'].startswith('ALL_'))['verified_meshes']==len(d['instances'])
assert next(q for q in results if q['file'].startswith('TRIAL_'))['verified_meshes']==6
out={'revision':d['parameters']['revision'],'method':'Per-object native XML mesh vs current STL: extents tolerance 0.001mm, volume 0.001% or 0.1mm3, equal face count. Not a printer-profile certification.','projects':results,'all_passed':True,'current_stl_sha256':{k:hashlib.sha256((R/'stl'/f'{k}.stl').read_bytes()).hexdigest() for k in cache}}
(R/'validation/native-geometry-consistency.json').write_text(json.dumps(out,indent=2));print(json.dumps({'native_projects':len(results),'mesh_instances_checked':sum(v['verified_meshes'] for v in results),'all_passed':True}))
