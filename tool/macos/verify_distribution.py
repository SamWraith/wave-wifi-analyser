#!/usr/bin/env python3
"""Verify every packaged Mach-O slice; never trusts entitlement source alone."""
import argparse
import plistlib
import re
import subprocess
from pathlib import Path


def run(*args):
    return subprocess.check_output(args, stderr=subprocess.STDOUT)


def macho_files(app):
    seen = set()
    for path in app.rglob('*'):
        if not path.is_file() or path.resolve() in seen:
            continue
        seen.add(path.resolve())
        if 'Mach-O' in run('file', '-b', str(path)).decode():
            yield path


def verify(app, shorebird=False, allow_adhoc=False):
    run('codesign', '--verify', '--deep', '--strict', str(app))
    info = plistlib.loads((app / 'Contents/Info.plist').read_bytes())
    host = (app / 'Contents/MacOS' / info['CFBundleExecutable']).resolve()
    host_arches = set(run('lipo', '-archs', str(host)).decode().split())
    if host_arches != {'arm64', 'x86_64'}:
        raise ValueError('Distribution requires arm64 and x86_64 host slices')
    host_details = run('codesign', '-d', '--verbose=4', str(host)).decode()
    host_team_match = re.search(r'^TeamIdentifier=(.+)$', host_details, re.M)
    host_team = host_team_match.group(1) if host_team_match else None
    if not allow_adhoc and (not host_team or host_team == 'not set'):
        raise ValueError('Developer ID signing with a nonempty TeamIdentifier required')
    count = 0
    forbidden = {'com.apple.security.get-task-allow', 'com.apple.security.cs.allow-jit',
                 'com.apple.security.cs.disable-library-validation',
                 'com.apple.security.cs.allow-dyld-environment-variables',
                 'com.apple.security.cs.disable-executable-page-protection'}
    for path in macho_files(app):
        run('codesign', '--verify', '--strict', str(path))
        for arch in run('lipo', '-archs', str(path)).decode().split():
            details = run('codesign', '-d', '--verbose=4', '--arch', arch, str(path)).decode()
            if not re.search(r'flags=.*\bruntime\b', details):
                raise ValueError(f'Missing hardened runtime: {path.name} ({arch})')
            if not allow_adhoc and ('Signature=adhoc' in details or 'Authority=Developer ID Application:' not in details):
                raise ValueError(f'Developer ID signature required: {path.name} ({arch})')
            team = re.search(r'^TeamIdentifier=(.+)$', details, re.M)
            if not allow_adhoc and (not team or team.group(1) != host_team):
                raise ValueError(f'Nested signing TeamIdentifier differs from host: {path.name} ({arch})')
            result = subprocess.run(['codesign', '-d', '--arch', arch, '--entitlements', ':-', str(path)], capture_output=True, check=True)
            ent = plistlib.loads(result.stdout) if result.stdout.strip() else {}
            if any(ent.get(key) for key in forbidden):
                raise ValueError(f'Forbidden entitlement: {path.name} ({arch})')
            unsigned = bool(ent.get('com.apple.security.cs.allow-unsigned-executable-memory'))
            if unsigned != (shorebird and path.resolve() == host):
                raise ValueError(f'Wrong engine entitlement profile: {path.name} ({arch})')
            if path.resolve() == host and not all(ent.get(key) for key in (
                'com.apple.security.app-sandbox', 'com.apple.security.network.client',
                'com.apple.security.personal-information.location')):
                raise ValueError('Missing host sandbox/network/location entitlements')
            count += 1
    print(f'Verified {count} Mach-O slices, nested signatures, runtime and entitlements' + (' (ad-hoc structural validation only; launch/distribution not certified).' if allow_adhoc else '.'))


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('app', type=Path)
    parser.add_argument('--shorebird', action='store_true')
    parser.add_argument('--allow-adhoc-validation', action='store_true')
    args = parser.parse_args()
    verify(args.app.resolve(), args.shorebird, args.allow_adhoc_validation)
