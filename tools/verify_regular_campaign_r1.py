#!/usr/bin/env python3
"""Run the bounded R1 regression set with unique candidate-owned save paths."""
from concurrent.futures import ThreadPoolExecutor
from pathlib import Path
import datetime
import hashlib
import json
import re
import subprocess
import tempfile

ROOT = Path(__file__).resolve().parents[1]
GODOT = '/Users/m4-zhi/Documents/codex-tools/godot/4.5.1-stable-standard/Godot.app/Contents/MacOS/Godot'
NAMES = [
    'run_p0_01_national_read_model_smoke',
    'run_r2c01_national_resource_convergence_smoke',
    'run_v5_campaign_persistence_smoke', 'run_v5_army_state_smoke',
    'run_v5_training_queue_smoke',
    'run_normal_city_building_growth_r1_persistence_smoke',
    'run_city_population_pressure_r0_persistence_smoke',
    'run_city_governance_r0_persistence_smoke',
    'run_macro_march_r0_persistence_smoke',
    'run_blackstone_causal_playtest_r1_smoke',
    'run_campaign_time_consistency_r1_smoke',
    'run_regular_campaign_rules_r1_smoke', 'run_regular_campaign_r1_smoke',
    'run_regular_campaign_r1_validation', 'run_regular_campaign_r1_time',
    'run_regular_campaign_r1_services', 'run_regular_campaign_r1_training_capacity',
    'run_regular_campaign_r1_wounded_supply', 'run_regular_campaign_r1_faults',
    'run_regular_campaign_r1_recovery', 'run_regular_campaign_r1_journey',
    'run_regular_campaign_r1_journey:slow',
]

def main():
    stamp = datetime.datetime.now().strftime('%Y%m%d-%H%M%S')
    evidence = ROOT / 'docs/milestones/regular-campaign-r1/evidence' / ('verification-' + stamp)
    evidence.mkdir()
    provenance = subprocess.check_output(['/usr/bin/python3', str(ROOT / 'tools/launch_regular_campaign_r1.py'), '--inspect'], text=True)
    (evidence / 'provenance.json').write_text(provenance)
    def run(name):
        script, _, variant = name.partition(':')
        command = [GODOT, '--headless', '--path', str(ROOT), '--script', 'res://tests/' + script + '.gd']
        # Existing persistence runners manage their own directories. Old in-memory
        # runners must not acquire a shared persistence coordinator by override.
        if 'regular_campaign' in script and not script.endswith(('_recovery', '_time', 'rules_r1_smoke')):
            save = tempfile.mkdtemp(prefix='txwzs-regular-r1-verify-')
            command += ['--', '--txwzs-v5-save-dir=' + save]
        if variant:
            command += ['--' + variant]
        try:
            result = subprocess.run(command, cwd=ROOT, text=True, stdout=subprocess.PIPE, stderr=subprocess.STDOUT, timeout=420)
            code, output = result.returncode, result.stdout
        except subprocess.TimeoutExpired as error:
            code, output = 124, str(error.stdout)
        log = name.replace(':', '-') + '.log'
        (evidence / log).write_text(output)
        markers = [line for line in output.splitlines() if ('PASS' in line or 'FINAL COMPLETED' in line) and not line.startswith('PASS ')]
        passed = code == 0 and 'SCRIPT ERROR:' not in output and bool(markers)
        row = {'test': name, 'command': command, 'exit_code': code, 'passed': passed, 'markers': markers, 'log': log, 'sha256': hashlib.sha256(output.encode()).hexdigest()}
        print(('PASS ' if passed else 'FAIL ') + name, flush=True)
        return row
    with ThreadPoolExecutor(max_workers=2) as pool:
        rows = list(pool.map(run, NAMES))
    (evidence / 'results.json').write_text(json.dumps(rows, ensure_ascii=False, indent=2))
    print('EVIDENCE ' + str(evidence), flush=True)
    raise SystemExit(0 if all(row['passed'] for row in rows) else 1)

if __name__ == '__main__':
    main()
