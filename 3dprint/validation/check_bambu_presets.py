"""Check project preset identities against the installed official BBL catalog.

This is a local file check, not a MakerWorld cloud review result.
"""
from pathlib import Path
from zipfile import ZipFile
import hashlib
import json
import sys

R = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(R))
from source.bambu_presets import BASE, MACHINE, PROCESS, FILAMENT, PROCESS_OVERRIDES, resolve


def check(path):
    with ZipFile(path) as z:
        assert z.testzip() is None
        d = json.loads(z.read('Metadata/project_settings.config'))
        assert not any(n.endswith('.gcode') for n in z.namelist())
    filaments = d['filament_settings_id']
    assert filaments == [FILAMENT], (path, filaments)
    assert d['printer_settings_id'] == MACHINE
    assert d['print_settings_id'] == PROCESS
    names = [PROCESS, *filaments, MACHINE]
    parents = d.get('inherits_group', [''] * len(names))
    assert len(parents) == len(names)
    official = [parent or name for name, parent in zip(names, parents)]
    assert official == [PROCESS, FILAMENT, MACHINE], (path, official)
    for name in official:
        preset = resolve(name)
        assert preset['from'] == 'system'
        assert preset['instantiation'] == 'true' and preset.get('setting_id')
    machine, filament = resolve(MACHINE), resolve(FILAMENT)
    assert MACHINE in filament['compatible_printers']
    assert d['printer_model'] == machine['printer_model'] == 'Bambu Lab P1S'
    assert d['printer_variant'] == '0.4'
    assert d['nozzle_diameter'] == ['0.4']
    assert d['printable_area'] == machine['printable_area']
    assert d['printable_height'] == machine['printable_height']
    assert d['filament_ids'] == [filament['filament_id']]
    assert d['filament_type'] == ['PETG']
    assert d['curr_bed_type'] == 'Textured PEI Plate'
    for key in ('machine_start_gcode', 'machine_end_gcode', 'layer_change_gcode', 'change_filament_gcode'):
        assert d[key] == machine[key], (path, 'modified machine G-code', key)
    for key in ('filament_diameter', 'filament_density', 'nozzle_temperature', 'nozzle_temperature_initial_layer',
                'textured_plate_temp', 'textured_plate_temp_initial_layer', 'filament_max_volumetric_speed'):
        assert d[key] == filament[key], (path, 'modified filament preset', key)
    assert d['layer_height'] == '0.2'
    for key, value in PROCESS_OVERRIDES.items():
        assert d[key] == value, (path, key, d[key], value)
    differences = d['different_settings_to_system']
    assert len(differences) == 3 and differences[1:] == ['', '']
    # These changed values must survive opening the file in Bambu Studio.
    assert {'wall_loops', 'sparse_infill_density', 'sparse_infill_pattern', 'bottom_shell_layers'} <= set(differences[0].split(';'))
    return {'file': str(path.relative_to(R)), 'sha256': hashlib.sha256(path.read_bytes()).hexdigest(),
            'official_preset_names': official, 'filament_id': d['filament_ids'][0],
            'process_changes': differences[0].split(';'), 'passed': True}


paths = sorted((R / 'bambu_reference').glob('*.3mf'))
paths += sorted((R / 'makerworld_upload/print_profiles').glob('*.3mf'))
results = [check(path) for path in paths]
assert len(results) == 31, len(results)
report = {'revision': json.loads((R / 'parameters.json').read_text())['revision'],
          'official_profile_source': str(BASE), 'scope': 'Local preset identity and parameter verification; no cloud submission',
          'makerworld_cloud_acceptance_confirmed': False, 'all_passed': True, 'projects': results}
(R / 'validation/bambu-preset-report.json').write_text(json.dumps(report, ensure_ascii=False, indent=2))
print(json.dumps({'checked_projects': len(results), 'all_passed': True, 'makerworld_cloud_acceptance_confirmed': False}))
