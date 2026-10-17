#!/usr/bin/env python3
"""Sign a staged app inside-out, package, re-extract and verify final signatures."""
import argparse
import importlib.util
import plistlib
import subprocess
import tempfile
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
spec = importlib.util.spec_from_file_location('verify_distribution', Path(__file__).with_name('verify_distribution.py'))
checker = importlib.util.module_from_spec(spec)
spec.loader.exec_module(checker)
parser = argparse.ArgumentParser(description=__doc__)
parser.add_argument('app', type=Path)
parser.add_argument('output', type=Path)
parser.add_argument('--identity', required=True, help='Developer ID Application identity, or - for structural validation only')
parser.add_argument('--allow-adhoc-validation', action='store_true')
parser.add_argument('--shorebird', action='store_true')
args = parser.parse_args()
if args.identity == '-' and not args.allow_adhoc_validation:
    parser.error('Ad-hoc signing requires --allow-adhoc-validation; structural validation only, not a runnable distribution')
if args.output.exists():
    parser.error('Output already exists; choose a new filename')
args.output.parent.mkdir(parents=True, exist_ok=True)
with tempfile.TemporaryDirectory(prefix='wave-package-') as scratch:
    staged = Path(scratch) / args.app.name
    subprocess.run(['ditto', str(args.app), str(staged)], check=True)
    signing = ['codesign', '--force', '--options', 'runtime', '--sign', args.identity,
               '--timestamp=none' if args.identity == '-' else '--timestamp']
    for path in sorted(checker.macho_files(staged), key=lambda p: len(p.parts), reverse=True):
        subprocess.run([*signing, str(path)], check=True, capture_output=True)
    bundles = [p for p in staged.rglob('*') if p.is_dir() and p.suffix in {'.framework', '.app', '.xpc', '.bundle'}]
    for path in sorted(bundles, key=lambda p: len(p.parts), reverse=True):
        subprocess.run([*signing, str(path)], check=True, capture_output=True)
    profile = 'ShorebirdRelease.entitlements' if args.shorebird else 'Release.entitlements'
    subprocess.run([*signing, '--entitlements', str(ROOT / 'macos/Runner' / profile), str(staged)], check=True, capture_output=True)
    checker.verify(staged, args.shorebird, args.allow_adhoc_validation)
    subprocess.run(['ditto', '-c', '-k', '--sequesterRsrc', '--keepParent', str(staged), str(args.output.resolve())], check=True)
    extracted = Path(scratch) / 'extracted'
    subprocess.run(['ditto', '-x', '-k', str(args.output.resolve()), str(extracted)], check=True)
    checker.verify(extracted / staged.name, args.shorebird, args.allow_adhoc_validation)
print(f'Packaged and verified: {args.output.name}')

if args.allow_adhoc_validation:
    print('Ad-hoc hardened bundle may fail library validation at launch. Developer ID signing is required for distribution; do not disable library validation.')
