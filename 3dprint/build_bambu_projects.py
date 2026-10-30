"""Create Bambu Studio reference projects. NO printer connection, NO print dispatch.
System presets are copied/flattened from the installed Bambu Studio, then exported via its CLI.
0.4/PETG is a clearly labelled reference assumption, not a claim about the user's machine.
"""
from pathlib import Path
import json, subprocess, sys, zipfile, collections
from source.set_reference_bed import set_bed
from source.bambu_presets import write_profiles
ROOT=Path(__file__).resolve().parent
BASE=Path('/Applications/BambuStudio.app/Contents/Resources/profiles/BBL')
APP='/Applications/BambuStudio.app/Contents/MacOS/BambuStudio'
OUT=ROOT/'bambu_reference';OUT.mkdir(exist_ok=True)
CFG=ROOT/'source'/'bambu_profiles';CFG.mkdir(exist_ok=True)
write_profiles(CFG)
data=json.loads((ROOT/'source'/'model-data.json').read_text())
result=[]
for part in data['parts']:
    name=part['part'];dest=OUT/f'{name}_P1S_04_PETG_REFERENCE.3mf'
    dest.unlink(missing_ok=True)
    cmd=[APP,'--debug','1','--datadir',str(ROOT/'validation'/'bambu-cli-data'),'--load-settings',str(CFG/'machine.json')+';'+str(CFG/'process.json'),'--load-filaments',str(CFG/'filament.json'),'--orient','0','--arrange','1','--export-3mf',str(dest),str(ROOT/'stl'/f'{name}.stl')]
    run=subprocess.run(cmd,cwd=ROOT/'validation',stdout=subprocess.PIPE,stderr=subprocess.STDOUT,text=True,timeout=90)
    (ROOT/'validation'/f'bambu_{name}.log').write_text(run.stdout)
    good=False;entries=[]
    if dest.exists():
        set_bed(dest)
        with zipfile.ZipFile(dest) as z:entries=z.namelist();good='Metadata/project_settings.config' in entries
    result.append({'part':name,'quantity_to_print':part['quantity'],'exit_code':run.returncode,'native_bambu_settings':good,'path':str(dest.relative_to(ROOT))})
    print('BAMBU',name,run.returncode,good,flush=True)
    if not good or run.returncode:
        print(run.stdout[-6000:]);break
(ROOT/'validation'/'bambu-export-report.json').write_text(json.dumps(result,indent=2))
if len(result)!=len(data['parts']) or not all(v['native_bambu_settings'] and v['exit_code']==0 for v in result):sys.exit(1)
