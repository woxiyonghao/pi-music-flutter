"""Package already validated native projects, STL files and existing CAD images."""
from pathlib import Path
import hashlib
import json
import shutil
import zipfile

R = Path(__file__).resolve().parent
U = R / 'makerworld_upload'
digest = lambda p: hashlib.sha256(p.read_bytes()).hexdigest()
parameters = json.loads((R / 'parameters.json').read_text())
revision = parameters['revision']
version = revision.split('-')[0]
presets = json.loads((R / 'validation/bambu-preset-report.json').read_text())
slices = json.loads((R / 'validation/project-slice-report.json').read_text())
assert presets['revision'] == revision and presets['all_passed']
profiles = []
for name, count, plates in [('ALL_95_PIECES', 95, 14), ('TRIAL_6_TYPES', 6, 1)]:
    filename = f'{name}_P1S_04_PETG_MAKERWORLD.3mf'
    path = U / 'print_profiles' / filename
    canonical = R / 'bambu_reference' / f'{name}_P1S_04_PETG_REFERENCE.3mf'
    assert path.is_file() and digest(path) == digest(canonical)
    preset_check = next(q for q in presets['projects'] if q['file'] == str(path.relative_to(R)))
    slice_check = next(q for q in slices if q['project'] == name)
    assert preset_check['sha256'] == slice_check['source_sha256'] == digest(path)
    assert slice_check['passed'] and slice_check['generated_nonempty_gcode_plates'] == plates
    profiles.append({'filename': filename, 'pieces': count, 'plates': plates,
                     'sha256': digest(path), 'official_preset_names': preset_check['official_preset_names'],
                     'reference_slice_passed': True})
assert {p.name for p in (U / 'print_profiles').glob('*')} == {q['filename'] for q in profiles}
fix = {'revision': revision, 'fix_date': '2026-10-23',
       'change': 'Keep installed official system preset identities and track project process overrides. Both upload projects were opened and saved in Bambu Studio 02.08.02.61.',
       'geometry_changed': False, 'makerworld_cloud_acceptance_confirmed': False,
       'profiles': profiles}
(U / 'instructions/preset-fix-report.json').write_text(json.dumps(fix, ensure_ascii=False, indent=2))
(U / '预设修复说明.txt').write_text('''2026-10-23 · MakerWorld打印配置修复

请在审核失败项点击“编辑”→“替换文件”，全套替换为：
print_profiles/ALL_95_PIECES_P1S_04_PETG_MAKERWORLD.3mf
试印配置单独使用TRIAL_6_TYPES_P1S_04_PETG_MAKERWORLD.3mf。

此次只修复打印工程的预设身份和工艺修改记录。95件/14盘、6件/1盘、模型尺寸、0.20层高、5圈墙、30%gyroid保持不变。
旧导出把修改后的工艺另起名字，却标为系统预设；现在使用已安装的官方工艺、官方P1S及Generic PETG耗材预设。
两份上传文件已由Bambu Studio图形界面打开并重存，再重新完成本地切片。原STL和图片无须因此重传。
本地检查结果见instructions/preset-fix-report.json。未提交云端校验，平台审核结果仍以重新提交后为准。
''')
files = sorted(p for p in U.rglob('*') if p.is_file() and p.name != 'upload-manifest.json')
manifest = {'revision': revision, 'preset_fix': '2026-10-23-official-system-identities',
            'source_model_data_sha256': digest(R / 'source/model-data.json'), 'stl_types': 27,
            'native_reference_profiles': 2, 'image_views': 4,
            'png_and_jpg_are_format_alternatives': True, 'all_images_cad_render_not_real_photo': True,
            'machine_or_publication_acceptance_not_confirmed': True,
            'files': [{'path': str(p.relative_to(U)), 'bytes': p.stat().st_size, 'sha256': digest(p)} for p in files]}
(U / 'upload-manifest.json').write_text(json.dumps(manifest, ensure_ascii=False, indent=2))
files.append(U / 'upload-manifest.json')
archive = R / f'makerworld-upload-{version}-preset-fix.zip'
with zipfile.ZipFile(archive, 'w', zipfile.ZIP_DEFLATED, compresslevel=7) as z:
    for path in files:
        z.write(path, 'makerworld_upload/' + str(path.relative_to(U)))
with zipfile.ZipFile(archive) as z:
    assert z.testzip() is None
    assert len([n for n in z.namelist() if n.endswith('.stl')]) == 27
    assert len([n for n in z.namelist() if n.endswith('.3mf')]) == 2
    assert not any('REFERENCE.3mf' in n or n.endswith('.gcode') for n in z.namelist())
shutil.copy2(archive, R / f'makerworld-upload-{version}.zip')
print(json.dumps({'archive': str(archive), 'files': len(files), 'megabytes': round(archive.stat().st_size / 1024**2, 2)}))
