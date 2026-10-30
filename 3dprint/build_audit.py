"""Generate the offline, human-readable parameter audit from current CAD metadata."""
from pathlib import Path
from datetime import datetime, timezone
import json, html
R=Path(__file__).resolve().parent
P=json.loads((R/'parameters.json').read_text())
D=json.loads((R/'source/model-data.json').read_text())
assert P==D['parameters'], 'Preview metadata must match current parameters'
reports={n:json.loads((R/'validation'/f'{n}.json').read_text()) for n in ['interference-report','screen-mount-report','hardware-fit-report','slice-report','preview-check','all-parts-report','dtx-fit-report']}
assert not reports['interference-report']['print_part_collisions']
assert not reports['interference-report']['device_envelope_collisions']
assert reports['hardware-fit-report']['all_passed']
assert reports['dtx-fit-report']['all_passed']
assert len(reports['slice-report'])==len(D['parts'])
assert all(q['revision']==P['revision'] for q in reports['slice-report'])
assert not reports['preview-check']['errors']
assert all(q['gcode_generated'] and q['exit']==0 for q in reports['slice-report'])
items=[
('已确认','微雪触控屏','173×103；总包络深4.2，四角R3','用户已确认触控版；官方图纸。IPS/QLED未指定，官方机械外形一致。'),
('已修正','外沿玻璃与压片','盖板0.70；台阶趾前伸3.5；后软垫1×10×2.0','原先把4.2总厚度用于玻璃边缘。现只夹外沿黑边，避让内缩LCD；LCD横向对齐为图纸推算。'),
('已确认','转接小板','50×25.5；孔距44.7×20.2；板孔2.75','打印托盘孔2.8；用M2.5×10。PCB厚1.6、螺母厚2.0是名义假设。'),
('已修正','TOPPING DX1 II','100×100×32，含突出部分','撤销旧180×170×50占位。85高的设备层剩余53；旋钮算入100总深，面板细节仅示意。'),
('保守留位','Fosi ZA3','184×184×51；90高设备层','厂家数值154.9×183.9×50.8，宽深方向不硬定。方形包络涵盖两种平面方向；后方32未验证插头及弯线。'),
('已核对','整套名义螺丝','屏框M3×12+0.5平垫；小板M2.5×10；底脚M4×12','202处名义螺杆穿入路径和完整螺母咬合检查通过。4片M3平垫须实测厚度；未认证真实头型、拧紧扭矩及强度。'),
('已修正','四柱外壳','32宽、4倒角；局部承压台','补上原0.6装配间隙处的紧固支撑，前后柱保持同款。'),
('保守留位','黑色ABS树莓派壳','前后100×竖高70×厚35；前端Y=105','按用户要求暂忽略壳体细微差异；保持左内壁、网口/USB朝屏幕、电源向上、散热面朝内。整套后移40，名义后方余39。托钩内净宽37，薄壳用软垫补隙；实物夹持未认证。'),
('已修改','金士顿DTX/128GB','67.3×21.04×10.14；直线拔出预留10','全长保守避让，不扣除帽盖或插入深度。4个参考USB口、2种横截面朝向及拔出通道共16项通过；相邻USB插头仍需试插。'),
('待测','带保护壳硬盘','暂用竖高125×前后80×厚20','右内壁上下钩固定；必须量保护壳最大外形及插线占用。'),
('待测','大扁头螺丝','M4通孔4.5、头孔9.4；名义头径8.5','侧板头槽仅深2.1，未知头高可能突出；先印试装片，实测螺母对边和厚度。'),
('待测','按键帽','未输出匹配按钮STL','黑壳非红白官方壳；缺按键孔、壁厚、凸缘及推杆行程。'),
('待确认','实际打印配置','P1S / 0.4 / PETG仅参考','照片不能确认机型、喷嘴、耗材。14盘原生3MF未按用户实机最终切片。'),
('待验证','USB供电与线材','不能默认屏幕+硬盘+DAC均由Pi供电','Pi5下游USB总1.6A需识别5V/5A供电，且与风扇共用；普通3A供电为600mA。硬盘启动峰值未知。')]
sources=[
('金士顿DTX官方规格','https://www.kingston.com/datasheets/dtx_en.pdf'),
('微雪产品参数','https://docs.waveshare.net/70H-1024600/'),
('微雪官方图纸','https://docs.waveshare.net/70H-1024600/Resources-And-Documents/'),
('微雪接线教程','https://docs.waveshare.net/70H-1024600/Development-Adapter-User-Guide/'),
('DX1 II 官方说明书，第26页','https://dl.topping.audio/um/DX1_II_V1.1_CN.pdf'),
('Fosi ZA3 官方产品页','https://fosiaudio.com/products/fosi-audio-za3-balanced-dual-mode-class-d-amplifier'),
('Pi5 官方供电说明','https://www.raspberrypi.com/documentation/computers/raspberry-pi.html')]
out={'revision':P['revision'],'generated_utc':datetime.now(timezone.utc).isoformat(),'unit':'mm','physical_fit_confirmed':False,'items':[dict(zip(['status','item','dimension_or_setting','evidence_or_limit'],q)) for q in items],'sources':[{'title':a,'url':b} for a,b in sources], 'checks':{'unique_types':len(D['parts']),'rack_piece_count':len(D['instances']),'all_print_parts_watertight':all(q['watertight'] and q['bodies']==1 for q in D['parts']),'printed_and_device_envelope_collisions':0,'nominal_hardware_connections':len(reports['hardware-fit-report']['checked_connections']),'unique_types_reference_sliced':len(reports['slice-report']),'all_parts_plates':reports['all-parts-report']['plate_count'],'dtx_corridors':len(reports['dtx-fit-report']['checks']),'user_case_detail_measurement_deferred_by_request':True,'user_machine_final_slice':False},'remaining_measurements':['Pi case front-to-back A, installed vertical height B, thickness C including feet','HDD maximum protected case dimensions and plugged-in cable envelope','Pi USB-C connector keep-out and button cap geometry','Actual screw head height, washer and nut thickness','Actual printer model, nozzle diameter and filament']}
(R/'validation/parameter-audit.json').write_text(json.dumps(out,ensure_ascii=False,indent=2)+'\n')
rows=''.join('<tr><td><span class="status '+('pending' if s.startswith('待') or s=='保守留位' else '')+'">'+html.escape(s)+'</span></td><th>'+html.escape(a)+'</th><td>'+html.escape(b)+'</td><td>'+html.escape(c)+'</td></tr>' for s,a,b,c in items)
links=''.join('<a href="'+b+'">'+a+' ↗</a>' for a,b in sources)
page='''<!doctype html><html lang="zh-CN"><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1"><title>机架参数核对 · v0.3.2</title><style>
*{box-sizing:border-box}body{margin:0;background:#f4f3ee;color:#202c2c;font:15px/1.75 -apple-system,BlinkMacSystemFont,"PingFang SC",sans-serif}main{max-width:1120px;margin:auto;padding:48px 28px 70px}header{border-bottom:1px solid #c9d1ca;padding-bottom:30px}.eyebrow{font-size:12px;letter-spacing:.12em;color:#647873}h1{font-size:34px;line-height:1.3;font-weight:600;margin:8px 0 16px}h2{font-size:23px;margin:38px 0 15px}p{margin:10px 0}a{color:#176d64;text-underline-offset:4px}.lead{max-width:800px;font-size:17px;color:#4d625b}.nav{display:flex;gap:22px;flex-wrap:wrap;margin-top:20px}.metrics{display:grid;grid-template-columns:repeat(4,1fr);gap:12px;margin:24px 0}.metric{background:white;border:1px solid #dde2da;border-radius:10px;padding:18px}.metric strong{display:block;color:#176d64;font-size:28px;line-height:1.4}.metric small{color:#677971}.scroll{overflow:auto;border:1px solid #d4dcd4;border-radius:10px}table{width:100%;border-collapse:collapse;background:#fff;font-size:13px;text-align:left;min-width:730px}td,th{border-bottom:1px solid #e5e9e2;vertical-align:top;padding:15px 13px}thead th{color:#5f746c;background:#eaf0e9;font-weight:500}tbody th{font-weight:600;width:15%}td:nth-child(3){width:29%}tr:last-child>*{border-bottom:0}.status{font-size:12px;white-space:nowrap;color:#146456;background:#e1f1e8;padding:4px 7px;border-radius:4px}.pending{color:#8a5b21;background:#fff0d8}.card{background:white;border:1px solid #d9e0d6;border-radius:12px;padding:24px;margin-top:20px}.note{border-left:3px solid #b47c37;background:#fff5e5;padding:16px 20px;border-radius:0 8px 8px 0;margin-top:22px}.diagram{width:100%;max-width:780px;display:block;margin:18px auto}.diagram text{font-family:-apple-system,BlinkMacSystemFont,"PingFang SC",sans-serif}.muted{color:#64766e;font-size:13px}.form{display:grid;grid-template-columns:repeat(3,1fr);gap:12px;margin:15px 0}label{font-size:13px;color:#54675e}input,textarea,button{font:inherit}input{width:100%;border:1px solid #bfcfc3;border-radius:6px;padding:9px;margin-top:5px;background:#fafcf8}textarea{width:100%;height:170px;border:1px solid #bfcfc3;border-radius:7px;padding:12px;background:#f8faf6;font-size:13px}button{background:#176d64;color:white;border:0;border-radius:6px;padding:10px 18px;cursor:pointer}.sources{display:flex;flex-wrap:wrap;gap:12px 24px;font-size:13px}footer{margin-top:35px;font-size:12px;color:#708078}@media(max-width:650px){main{padding:28px 16px 50px}h1{font-size:27px}.metrics{grid-template-columns:repeat(2,1fr)}.metric{padding:14px}.card{padding:16px}.form{grid-template-columns:1fr}.diagram text{font-size:15px}.lead{font-size:15px}}
</style><main><header><div class="eyebrow">AUDIO RACK / PARAMETER AUDIT / 2026.10.23</div><h1>送印参数核对 · 树莓派已后移 40 mm</h1><p class="lead">微雪触控屏和 DX1 II 已按官方资料核对。树莓派、托钩、侧板槽与电源避让区同步后移 40 mm，新增金士顿 DTX 的完整长度及拔出通道检查。黑壳按用户要求暂用保守占位，夹持件先试配。</p><nav class="nav"><a href="preview.html">打开三维装配预览 →</a><a href="#measure">看怎么量黑壳 ↓</a><a href="print-handoff.html">给打印店的交付单 →</a><a href="README.md">装配与螺丝清单</a></nav></header>
<div class="metrics"><div class="metric"><strong>27 类 / 95 件</strong><small>CAD 分件与装配件</small></div><div class="metric"><strong>14 盘</strong><small>拓竹原生参考工程</small></div><div class="metric"><strong>0 处</strong><small>名义包络体积干涉</small></div><div class="metric"><strong>202 处</strong><small>名义螺丝穿入检查通过</small></div></div>
<p class="muted">数字检查以当前占位与名义紧固件为基础；未做实物承重、热变形或长期温升验证，尚非用户实机一键打印配置。</p>
<h2>逐项核对</h2><div class="scroll"><table><thead><tr><th>状态</th><th>部位</th><th>本版尺寸 / 设置（mm）</th><th>依据与适配边界</th></tr></thead><tbody>__ROWS__</tbody></table></div>
<section class="card" id="measure"><div class="eyebrow">MEASURE YOUR CASE</div><h2 style="margin-top:8px">不用查型号，按这三个方向量就行</h2><p>树莓派保持最终竖装姿态：网口 / USB 朝屏幕，电源口向上，散热面朝机架内侧。量装好后的黑壳最大外形，含脚垫和突出边，不含插入的线。普通直尺即可。</p>
<svg class="diagram" viewBox="0 0 780 365" role="img" aria-label="黑色树莓派外壳三个测量方向：A为网口USB端至按键端的前后长；B为竖装上下高；C为壳厚"><defs><marker id="arrow" viewBox="0 0 10 10" refX="5" refY="5" markerWidth="6" markerHeight="6" orient="auto-start-reverse"><path d="M0 0 L10 5 L0 10 Z" fill="#176d64"/></marker></defs>
<rect x="100" y="95" width="300" height="175" rx="13" fill="#303b3c"/><rect x="108" y="101" width="284" height="162" rx="9" fill="#3e4b4b"/>
<g stroke="#81928e" stroke-width="4"> <path d="M141 125h210 M141 140h210 M141 155h210 M141 170h210 M141 185h210 M141 200h210 M141 215h210 M141 230h210"/></g>
<g stroke="#176d64" stroke-width="1.5"><path d="M100 82V49 M400 82V49"/><path d="M100 58H400" marker-start="url(#arrow)" marker-end="url(#arrow)"/><path d="M88 95H53 M88 270H53"/><path d="M63 95V270" marker-start="url(#arrow)" marker-end="url(#arrow)"/></g>
<text x="250" y="33" text-anchor="middle" fill="#176d64" font-size="17">A 前后长</text><text x="30" y="182" fill="#176d64" font-size="17" transform="rotate(-90 30 182)" text-anchor="middle">B 竖装高</text>
<path d="M100 285v12 M400 285v12" stroke="#687d73"/><text x="100" y="320" text-anchor="middle" font-size="14" fill="#54685e">网口 / USB 端</text><text x="400" y="320" text-anchor="middle" font-size="14" fill="#54685e">后方按键端</text>
<path d="M345 93V72" stroke="#b47c37" stroke-width="3"/><text x="463" y="80" font-size="14" fill="#936220">电源方向 ↑（接口位置待测）</text>
<rect x="545" y="95" width="115" height="175" rx="10" fill="#3e4b4b"/><rect x="570" y="115" width="65" height="33" rx="2" fill="#c4d0ca"/><rect x="570" y="164" width="65" height="25" rx="2" fill="#329abd"/><rect x="570" y="205" width="65" height="25" rx="2" fill="#329abd"/>
<g stroke="#176d64" stroke-width="1.5"><path d="M545 282v28 M660 282v28"/><path d="M545 298H660" marker-start="url(#arrow)" marker-end="url(#arrow)"/></g><text x="602" y="330" text-anchor="middle" fill="#176d64" font-size="17">C 壳厚（含脚垫）</text><text x="602" y="355" text-anchor="middle" fill="#7a8980" font-size="12">端面示意，接口数量 / 位置不作尺寸依据</text></svg>
<p class="muted">图只定义测量方向，不代表你的壳已测量。A/B/C 与商品页面“长宽高”名称无关。若脚垫在散热面或侧面，取含脚垫后的最大值。</p>
<p>硬盘同样连保护壳一起量：竖装高、前后长、厚。再看插上线后额外占多少空间。按键帽另需孔宽高、壳壁厚与内部按键距离，不能由这三个外形尺寸推出。</p>
<div class="form"><label>树莓派 A 前后长（mm）<input id="piA" inputmode="decimal" placeholder="实测，未填则留待测"></label><label>树莓派 B 竖装高（mm）<input id="piB" inputmode="decimal" placeholder="实测"></label><label>树莓派 C 壳厚（mm）<input id="piC" inputmode="decimal" placeholder="含脚垫"></label><label>硬盘竖装高（mm）<input id="hddB" inputmode="decimal" placeholder="含保护壳"></label><label>硬盘前后长（mm）<input id="hddA" inputmode="decimal" placeholder="含保护壳"></label><label>硬盘厚（mm）<input id="hddC" inputmode="decimal" placeholder="含保护壳"></label></div>
<button id="format" type="button">整理成可复制的测量结果</button><p class="muted">仅在本页整理文字，不修改模型、不上传数据。复制下方结果发到聊天即可。</p><textarea id="measure-result" aria-label="可复制的测量结果" readonly>树莓派：A 前后长 = 待测；B 竖装高 = 待测；C 壳厚（含脚垫）= 待测。
硬盘（带保护壳）：竖装高 = 待测；前后长 = 待测；厚 = 待测。
补充：电源弯头朝向、带线后占用空间、螺丝头高度。</textarea>
</section>
<section class="note"><strong>先接齐设备，再决定 USB 供电</strong><p>DX1 II 是 USB-C 数据及供电，额定 5V/1.0A、典型工作 2.5W。屏幕要求大于 500mA，机械硬盘启动峰值尚未知。Pi5 的 1.6A 是下游总预算且需识别 5V/5A 电源，不能视为每口额度。是否需要独立供电 / 有源 USB，还要按实际设备接线验证。</p><p>视频线应是 <strong>Micro HDMI → 标准 HDMI</strong>。屏幕 Touch 使用 USB-C；不要把 Micro HDMI 与 Micro USB 混淆。</p></section>
<h2>官方依据与验证记录</h2><div class="sources">__LINKS__</div><p class="muted">本地留存：<a href="reference/DX1_II_V1.1_CN.pdf">DX1 II 说明书</a> · <a href="reference/DX1_II-spec-page.png">第26页尺寸截图</a> · <a href="validation/parameter-audit.json">完整核对数据</a> · <a href="validation/hardware-fit-report.json">螺丝穿入记录</a></p>
<footer>v0.3.2 · 同一 CAD 数据生成三维预览及打印件。旧版 AI 成品图中的大号 DAC 已过时；请以本版预览为尺寸依据。未取得 MakerWorld 作者 STL 的可量测文件，未声称与其互换。</footer></main>
<script>document.getElementById('format').addEventListener('click',()=>{const v=id=>document.getElementById(id).value.trim()||'待测';const t=document.getElementById('measure-result');t.value=`树莓派：A 前后长 = ${v('piA')} mm；B 竖装高 = ${v('piB')} mm；C 壳厚（含脚垫）= ${v('piC')} mm。\\n硬盘（带保护壳）：竖装高 = ${v('hddB')} mm；前后长 = ${v('hddA')} mm；厚 = ${v('hddC')} mm。\\n补充：电源弯头朝向、带线后占用空间、螺丝头高度。`;t.focus();t.select();});</script></html>'''
(R/'parameter-audit.html').write_text(page.replace('__ROWS__',rows).replace('__LINKS__',links))
print(json.dumps({'audit_html':'parameter-audit.html','revision':P['revision'],'items':len(items),'physical_fit_confirmed':False},ensure_ascii=False))
