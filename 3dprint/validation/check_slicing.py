from pathlib import Path
import subprocess,json,zipfile
R=Path(__file__).resolve().parents[1]
app='/Applications/BambuStudio.app/Contents/MacOS/BambuStudio'
results=[]
data=json.loads((R/'source/model-data.json').read_text())
for part in data['parts']:
    name=part['part']
    src=R/'bambu_reference'/f'{name}_P1S_04_PETG_REFERENCE.3mf'
    dst=R/'validation'/f'VALIDATION_ONLY_{name}.gcode.3mf'
    dst.unlink(missing_ok=True)
    run=subprocess.run([app,'--debug','1','--datadir',str(R/'validation'/'bambu-cli-data'),'--slice','0','--export-3mf',str(dst),str(src)],cwd=R/'validation',stdout=subprocess.PIPE,stderr=subprocess.STDOUT,text=True,timeout=120)
    (R/'validation'/f'slice_{name}.log').write_text(run.stdout)
    entries=[];gcode_count=0
    if dst.exists():
        with zipfile.ZipFile(dst) as z:
            entries=z.namelist()
            gcode_count=sum(z.getinfo(x).file_size>100 for x in entries if x.endswith('.gcode'))
    ok=run.returncode==0 and gcode_count>0
    results.append({'part':name,'exit':run.returncode,'gcode_generated':ok,'revision':data['parameters']['revision'],'profile':'P1S 0.4 / Generic PETG - validation assumption only'})
    print(name,run.returncode,ok,run.stdout[-1200:] if not ok else '',flush=True)
(R/'validation/slice-report.json').write_text(json.dumps(results,indent=2))
raise SystemExit(not all(x['gcode_generated'] for x in results))
