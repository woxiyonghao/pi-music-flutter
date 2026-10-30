from pathlib import Path
import json,zipfile
def set_bed(path):
    path=Path(path)
    with zipfile.ZipFile(path) as z:
        entries=[(info,z.read(info.filename)) for info in z.infolist()]
    settings=json.loads(next(b for i,b in entries if i.filename=='Metadata/project_settings.config'))
    settings['curr_bed_type']='Textured PEI Plate'
    temp=path.with_suffix('.bedfix.tmp')
    with zipfile.ZipFile(temp,'w',zipfile.ZIP_DEFLATED) as z:
        for info,body in entries:
            if info.filename=='Metadata/project_settings.config':body=json.dumps(settings,ensure_ascii=False,indent=2).encode()
            z.writestr(info,body)
    temp.replace(path)
if __name__=='__main__':
    for p in (Path(__file__).resolve().parents[1]/'bambu_reference').glob('*.3mf'):set_bed(p)
