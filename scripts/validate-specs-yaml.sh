#!/usr/bin/env bash
# story: e10s01
# Validate all YAML files in specs/
set -euo pipefail

python3 -c "
import glob, yaml, sys
errs = []
files = glob.glob('specs/**/*.yaml', recursive=True)
for p in files:
    try:
        with open(p) as f:
            yaml.safe_load(f)
    except Exception as e:
        errs.append(f'{p}: {e}')
if errs:
    print('\n'.join(errs), file=sys.stderr)
    sys.exit(1)
print(f'All {len(files)} specs YAML files parsed successfully.')
"
