from pathlib import Path
import json,subprocess,zipfile,xml.etree.ElementTree as ET
from source.set_reference_bed import set_bed
from source.bambu_presets import write_profiles
R=Path(__file__).resolve().parent;cfg=R/'source/bambu_profiles'
write_profiles(cfg)
d=json.loads((R/'source/model-data.json').read_text())
files=[str(R/'stl'/f'{p["part"]}.stl') for p in d['parts'] if p['category']!='calibration' for _ in range(p['quantity'])]
dest=R/'bambu_reference'/f'ALL_{len(files)}_PIECES_P1S_04_PETG_REFERENCE.3mf'
dest.unlink(missing_ok=True)
cmd=['/Applications/BambuStudio.app/Contents/MacOS/BambuStudio','--debug','1','--datadir',str(R/'validation/all-project-data'),'--load-settings',str(cfg/'machine.json')+';'+str(cfg/'process.json'),'--load-filaments',str(cfg/'filament.json'),'--arrange','1','--orient','0','--export-3mf',str(dest),*files]
run=subprocess.run(cmd,cwd=R/'validation',stdout=subprocess.PIPE,stderr=subprocess.STDOUT,text=True,timeout=180)
(R/'validation/all-parts-export.log').write_text(run.stdout)
out={'exit':run.returncode,'piece_count':len(files),'exported':dest.exists()}
if dest.exists():
    set_bed(dest)
    with zipfile.ZipFile(dest) as z:
        c=ET.fromstring(z.read('Metadata/model_settings.config'));out['plate_count']=len(c.findall('plate'));out['plate_model_instances']=sum(len(p.findall('model_instance')) for p in c.findall('plate'))
(R/'validation/all-parts-report.json').write_text(json.dumps(out,indent=2));print(json.dumps(out),flush=True)
if run.returncode:print(run.stdout[-6000:]);raise SystemExit(run.returncode)
