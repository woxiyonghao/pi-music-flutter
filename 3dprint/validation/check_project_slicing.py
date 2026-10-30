"""Slice the full arranged project and trial plate as reference validation only."""
from pathlib import Path
import json,subprocess,zipfile,xml.etree.ElementTree as E,hashlib
R=Path(__file__).resolve().parents[1];reports=[]
P=json.loads((R/'parameters.json').read_text())
for name,expected in [('ALL_95_PIECES',14),('TRIAL_6_TYPES',1)]:
    src=R/'bambu_reference'/f'{name}_P1S_04_PETG_REFERENCE.3mf';dst=R/'validation'/f'VALIDATION_ONLY_{name}.gcode.3mf';dst.unlink(missing_ok=True)
    run=subprocess.run(['/Applications/BambuStudio.app/Contents/MacOS/BambuStudio','--debug','1','--datadir',str(R/'validation/project-slice-data'),'--slice','0','--export-3mf',str(dst),str(src)],cwd=R/'validation',stdout=subprocess.PIPE,stderr=subprocess.STDOUT,text=True,timeout=300)
    (R/'validation'/f'slice_{name}.log').write_text(run.stdout)
    gc=[];warning_metadata=[]
    if dst.exists():
        with zipfile.ZipFile(dst) as z:
            gc=[n for n in z.namelist() if n.endswith('.gcode') and z.getinfo(n).file_size>100]
            if 'Metadata/slice_info.config' in z.namelist():
                text=z.read('Metadata/slice_info.config').decode()
                (R/'validation'/f'{name}-slice-info.xml').write_text(text)
                tree=E.fromstring(text)
                warning_metadata=[E.tostring(v).decode() for v in tree.iter() if 'warn' in v.tag.lower()]
    ok=run.returncode==0 and len(gc)==expected
    reports.append({'project':name,'revision':P['revision'],'source_sha256':hashlib.sha256(src.read_bytes()).hexdigest(),'exit_code':run.returncode,'expected_sliced_plates':expected,'generated_nonempty_gcode_plates':len(gc),'passed':ok,'warning_metadata':warning_metadata,'profile':'P1S 0.4 Generic PETG; reference only, not user machine final instructions'})
    print(json.dumps(reports[-1]),flush=True)
    if not ok:print(run.stdout[-4000:],flush=True)
(R/'validation/project-slice-report.json').write_text(json.dumps(reports,indent=2));raise SystemExit(not all(q['passed'] for q in reports))
