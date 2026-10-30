"""Six first-print types, counted within the final BOM except the coupon."""
from pathlib import Path
import json,subprocess,zipfile,xml.etree.ElementTree as E
from source.set_reference_bed import set_bed
from source.bambu_presets import write_profiles
R=Path(__file__).resolve().parent;cfg=R/'source/bambu_profiles'
write_profiles(cfg)
names=['screw_fit_coupon','pi_case_cradle','hdd_case_cradle','screen_smooth_bezel','screen_rear_retainer_bracket','waveshare_adapter_tray']
dest=R/'bambu_reference/TRIAL_6_TYPES_P1S_04_PETG_REFERENCE.3mf';dest.unlink(missing_ok=True)
cmd=['/Applications/BambuStudio.app/Contents/MacOS/BambuStudio','--debug','1','--datadir',str(R/'validation/trial-project-data'),'--load-settings',str(cfg/'machine.json')+';'+str(cfg/'process.json'),'--load-filaments',str(cfg/'filament.json'),'--arrange','1','--orient','0','--export-3mf',str(dest),*[str(R/'stl'/f'{n}.stl') for n in names]]
r=subprocess.run(cmd,cwd=R/'validation',stdout=subprocess.PIPE,stderr=subprocess.STDOUT,text=True,timeout=180)
(R/'validation/trial-export.log').write_text(r.stdout)
if r.returncode or not dest.exists():raise RuntimeError(r.stdout[-3000:])
set_bed(dest)
with zipfile.ZipFile(dest) as z:c=E.fromstring(z.read('Metadata/model_settings.config'))
report={'revision':json.loads((R/'parameters.json').read_text())['revision'],'piece_count':6,'part_names':names,'plate_count':len(c.findall('plate')),'plate_model_instances':sum(len(p.findall('model_instance')) for p in c.findall('plate')),'exported':True,'exit':r.returncode,'accepted_five_non_coupon_parts_count_toward_the_final_95':True}
assert report['plate_model_instances']==6
(R/'validation/trial-parts-report.json').write_text(json.dumps(report,indent=2));print(json.dumps(report))
