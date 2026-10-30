"""Release only after the current revision passes geometry, slicing and UI checks."""
from pathlib import Path
import json,hashlib,zipfile,re
R=Path(__file__).resolve().parent
read=lambda n:json.loads((R/'validation'/f'{n}.json').read_text())
data=json.loads((R/'source/model-data.json').read_text());parts=data['parts'];names={p['part'] for p in parts};P=data['parameters'];revision=P['revision'];version=revision.split('-')[0];count=len(data['instances'])
assert P==json.loads((R/'parameters.json').read_text())
assert all(p['watertight'] and p['bodies']==1 and p['fits_250mm_xy'] for p in parts)
assert read('hardware-fit-report')['all_passed'] and len(read('hardware-fit-report')['checked_connections'])==202
assert read('hardware-fit-report')['revision']==revision
assert read('dtx-fit-report')['all_passed'] and read('dtx-fit-report')['revision']==revision
inter=read('interference-report');assert not inter['print_part_collisions'] and not inter['device_envelope_collisions']
slices=read('slice-report');assert len(slices)==len(parts) and all(q['gcode_generated'] and q['exit']==0 and q['revision']==revision for q in slices)
exports=read('bambu-export-report');assert len(exports)==len(parts) and all(q['native_bambu_settings'] and q['exit_code']==0 for q in exports)
a=read('all-parts-report');assert a['exit']==0 and a['piece_count']==a['plate_model_instances']==count
assert read('trial-parts-report')['exported'] and read('trial-parts-report')['piece_count']==6
assert read('native-geometry-consistency')['all_passed'] and read('native-geometry-consistency')['revision']==revision
ps=read('project-slice-report');assert len(ps)==2 and all(q['passed'] and q['revision']==revision for q in ps)
presets=read('bambu-preset-report');assert presets['all_passed'] and presets['revision']==revision
for q in presets['projects']:
    assert hashlib.sha256((R/q['file']).read_bytes()).hexdigest()==q['sha256'],q['file']
for q in ps:
    assert hashlib.sha256((R/'bambu_reference'/f'{q["project"]}_P1S_04_PETG_REFERENCE.3mf').read_bytes()).hexdigest()==q['source_sha256']
v=read('preview-check');assert not v['errors'] and not v['mobileOverflow'] and v['singlePartCorrect']
h=read('handoff-preview-check');assert not h['errors'] and h['measurementFormPassed'] and h['revision']==revision and all(not q['missingLocalLinks'] and not q['mobileOverflow'] for q in h['pages'])
assert read('parameter-audit')['revision']==revision
# Keep historical archives; remove only obsolete generated geometry filenames.
for folder,ext in [('stl','.stl'),('step','.step'),('3mf','.3mf')]:
    for p in (R/folder).glob('*'+ext):
        if p.stem not in names and p.name!='ASSEMBLY_VIEW_ONLY_DO_NOT_PRINT.3mf':p.unlink()
allname=f'ALL_{count}_PIECES_P1S_04_PETG_REFERENCE.3mf';trialname='TRIAL_6_TYPES_P1S_04_PETG_REFERENCE.3mf'
for p in (R/'bambu_reference').glob('*.3mf'):
    if p.name in [allname,trialname]:continue
    if p.name.removesuffix('_P1S_04_PETG_REFERENCE.3mf') not in names:p.unlink()
for name in ['_cad_mesh.stl','post_85_debug.stl','export_test.stl']:
    (R/'validation'/name).unlink(missing_ok=True)
(R/'START_HERE.txt').write_text(f'''桌面音频机架 {version} / 2026-10-23
先打开 print-handoff.html，或用 print-order.csv 报价和核数量。
本版树莓派及固定槽已向后移动40mm。不要混用旧版 side_150_0。
STL 每类1个文件，按数量表打印；全套原生3MF已展开95个正式件，不要重复复制。
先试6类工程只有1盘；其中5个正式件通过后计入95，续印剩90。
所有文件单位mm，100%比例，保持建议打印朝向。
原生3MF为P1S/0.4/PETG参考配置；由打印店核对真实机器/喷嘴/材料后切片。
黑壳尺寸按用户要求暂保守占位；托钩用上下槽和软垫试配。实际受力/温升未经实物测试。
验证G-code不在此交付包，不作为开打指令。
''')
manifest_names={'release-manifest.json','print-shop-manifest.json'}
files=[]
for p in sorted(R.rglob('*')):
    if not p.is_file():continue
    rel=p.relative_to(R)
    # Do not nest previously extracted release copies in a new release.
    if rel.parts[0].startswith('audio-rack-'):continue
    if p.suffix=='.zip' or '__pycache__' in str(rel) or p.name in manifest_names:continue
    if rel.parts[0]=='validation':
        if len(rel.parts)>2 or p.suffix not in ['.json','.png','.py','.mjs']:continue
        if p.name in ['bambu-last-result.json','result.json']:continue
    files.append(p)
def entry(p):return {'path':str(p.relative_to(R)),'bytes':p.stat().st_size,'sha256':hashlib.sha256(p.read_bytes()).hexdigest()}
# A small, unambiguous current-version package for a print shop.
rootnames={'START_HERE.txt','print-handoff.html','print-order.csv','hardware.csv','README.md','preview.html','parameter-audit.html','parameters.json','parts.csv'}
proof={'parameter-audit.json','hardware-fit-report.json','dtx-fit-report.json','interference-report.json','screen-mount-report.json','mesh-report.json','slice-report.json','project-slice-report.json','native-geometry-consistency.json','all-parts-report.json','trial-parts-report.json','bambu-preset-report.json'}
shop=[]
for p in files:
    rel=p.relative_to(R)
    if len(rel.parts)==1 and p.name in rootnames:shop.append(p)
    elif rel.parts[0] in ['stl','step','calibration']:shop.append(p)
    elif rel.parts[0]=='3mf' and p.stem in names:shop.append(p)
    elif rel.parts[0]=='bambu_reference' and p.name in [allname,trialname]:shop.append(p)
    elif rel.parts[0]=='reference' and len(rel.parts)==2:shop.append(p)
    elif rel.parts[0]=='validation' and p.name in proof:shop.append(p)
# Every local HTML link must resolve within the shop package itself.
shopnames={str(p.relative_to(R)) for p in shop}
for p in shop:
    if p.suffix!='.html':continue
    for link in re.findall(r'<a\s[^>]*\bhref="([^"]+)"',p.read_text()):
        if link.startswith(('http','#')):continue
        assert link in shopnames,(p.name,'missing in shop package',link)
sm={'revision':revision,'rack_piece_count':count,'extra_coupon':1,'trial_piece_count':6,'remaining_formal_pieces_if_trial_accepted':90,'machine_profile':'P1S 0.4 PETG reference only','sliced_for_user_machine':False,'physical_fit_confirmed':False,'files':[entry(p) for p in shop]}
(R/'print-shop-manifest.json').write_text(json.dumps(sm,ensure_ascii=False,indent=2));shop.append(R/'print-shop-manifest.json')
shoparchive=R/f'audio-rack-{version}-print-shop.zip'
with zipfile.ZipFile(shoparchive,'w',zipfile.ZIP_DEFLATED,compresslevel=7) as z:
    for p in shop:z.write(p,f'audio-rack-{version}-print-shop/'+str(p.relative_to(R)))
files.append(R/'print-shop-manifest.json')
manifest={'revision':revision,'unique_part_types_including_coupon':len(parts),'rack_piece_count':count,'native_project_plates':a['plate_count'],'sliced_for_user_machine':False,'physical_fit_confirmed':False,'files':[entry(p) for p in files]}
(R/'release-manifest.json').write_text(json.dumps(manifest,ensure_ascii=False,indent=2));files.append(R/'release-manifest.json')
archive=R/f'audio-rack-{version}.zip'
with zipfile.ZipFile(archive,'w',zipfile.ZIP_DEFLATED,compresslevel=7) as z:
    for p in files:z.write(p,f'audio-rack-{version}/'+str(p.relative_to(R)))
print(json.dumps({'revision':revision,'full_archive':str(archive),'full_size_mb':round(archive.stat().st_size/1024**2,2),'shop_archive':str(shoparchive),'shop_size_mb':round(shoparchive.stat().st_size/1024**2,2),'shop_files':len(shop)}))
