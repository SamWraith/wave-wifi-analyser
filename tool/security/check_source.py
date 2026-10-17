#!/usr/bin/env python3
"""Narrow tracked-source privacy and workflow policy gate. No secret output."""
import re
import subprocess
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
errors = []
for name in subprocess.check_output(['git', 'ls-files', '--cached', '--others', '--exclude-standard', '-z'], cwd=ROOT).decode().split('\0'):
    if not name:
        continue
    path = ROOT / name
    if not path.is_file():
        continue
    data = path.read_bytes()
    if b'\0' in data:
        continue
    text = data.decode('utf-8', errors='replace')
    # Home directory paths with real account names; placeholders/env vars permitted.
    if re.search(r'/(?:Users|home)/[A-Za-z0-9_.-]+/', text) or re.search(r'[A-Za-z]:\\Users\\[A-Za-z0-9_.-]+\\', text):
        errors.append(f'{name}: private home path')
    if name.startswith('.github/workflows/'):
        for action in re.findall(r'uses:\s*([^\s#]+)', text):
            if not action.startswith('./') and not re.fullmatch(r'[^@]+@[0-9a-f]{40}', action):
                errors.append(f'{name}: action must use full commit SHA')
        if 'actions/checkout@' in text and 'persist-credentials: false' not in text:
            errors.append(f'{name}: checkout credentials must not persist')
if errors:
    raise SystemExit('\n'.join(errors))
print('Tracked-source privacy and workflow checks passed.')
