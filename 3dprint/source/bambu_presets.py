"""Resolve installed BBL presets without inventing new system preset names.

The CLI needs flattened values, but MakerWorld and the GUI also need the
official preset identity and the list of process changes relative to it.
An empty inherits_group is correct for system presets: the preset's own name
is the system reference (see BambuStudio.cpp and PresetBundle.cpp).
"""
import json
from pathlib import Path

BASE = Path('/Applications/BambuStudio.app/Contents/Resources/profiles/BBL')
MACHINE = 'Bambu Lab P1S 0.4 nozzle'
PROCESS = '0.20mm Standard @BBL X1C'
FILAMENT = 'Generic PETG'
PROCESS_OVERRIDES = {
    'wall_loops': '5',
    'top_shell_layers': '5',
    'bottom_shell_layers': '5',
    'sparse_infill_density': '30%',
    'sparse_infill_pattern': 'gyroid',
    'enable_support': '0',
    'brim_type': 'auto_brim',
    'brim_width': '5',
}


def resolve(name, stack=()):
    index = {p.stem: p for p in BASE.rglob('*.json')}
    if name in stack:
        raise ValueError('Preset inheritance cycle')
    data = json.loads(index[name].read_text())
    result = {}
    if data.get('inherits'):
        result.update(resolve(data['inherits'], stack + (name,)))
    for include in data.get('include', []):
        result.update(resolve(include, stack + (name,)))
    result.update({k: v for k, v in data.items() if k not in ('inherits', 'include')})
    return result


def write_profiles(destination):
    destination.mkdir(parents=True, exist_ok=True)
    machine, process, filament = map(resolve, (MACHINE, PROCESS, FILAMENT))
    for config, name in ((machine, MACHINE), (process, PROCESS), (filament, FILAMENT)):
        assert config['name'] == name
        assert config['from'] == 'system' and config['instantiation'] == 'true'
        assert config.get('setting_id'), name
    assert MACHINE in filament['compatible_printers']
    changed = sorted(k for k, v in PROCESS_OVERRIDES.items() if process.get(k) != v)
    process.update(PROCESS_OVERRIDES)
    # Keep the official process name. These are normal project overrides,
    # not a new preset falsely labelled "from: system".
    process['different_settings_to_system'] = [';'.join(changed)]
    for name, config in (('machine', machine), ('process', process), ('filament', filament)):
        (destination / f'{name}.json').write_text(json.dumps(config, ensure_ascii=False, indent=2))
    return {'machine': MACHINE, 'process': PROCESS, 'filament': FILAMENT,
            'changed_process_keys': changed}
