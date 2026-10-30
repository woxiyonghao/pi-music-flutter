from pathlib import Path
import json
R=Path(__file__).resolve().parent
model=json.loads((R/'source/model-data.json').read_text())
template=(R/'source/preview.template.html').read_text()
template=template.replace('最大单件平面尺寸小于 170 mm','最大单件平面尺寸 244 mm，按 P1S 分件')
template=template.replace('3MF 单件包为未切片几何模型。','3MF 单件包为未切片几何模型；bambu_reference 目录含拓竹原生工程。')
template=template.replace('__CAD_DATA__',json.dumps(model,ensure_ascii=False,separators=(',',':')).replace('</','<\\/'))
template=template.replace('__VIEWER_JS__',(R/'source/viewer.bundle.js').read_text().replace('</script','<\\/script'))
(R/'preview.html').write_text(template)
print('Preview',round((R/'preview.html').stat().st_size/1024/1024,2),'MiB')
