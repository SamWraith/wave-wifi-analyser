#!/usr/bin/env python3
"""Fail closed on APK identity, package/version, manifest and backup policy."""
import argparse
import re
import subprocess
import xml.etree.ElementTree as ET
from pathlib import Path

parser = argparse.ArgumentParser(description=__doc__)
parser.add_argument('apk', type=Path)
parser.add_argument('--certificate-sha256', required=True, help='Expected public release certificate fingerprint')
parser.add_argument('--version-name', required=True)
parser.add_argument('--version-code', required=True)
parser.add_argument('--apksigner', default='apksigner')
parser.add_argument('--apkanalyzer', default='apkanalyzer')
parser.add_argument('--aapt2', default='aapt2')
args = parser.parse_args()
expected = args.certificate_sha256.replace(':', '').lower()
if not re.fullmatch('[0-9a-f]{64}', expected):
    parser.error('Expected certificate SHA-256 must contain 64 hex digits')
result = subprocess.check_output([args.apksigner, 'verify', '--verbose', '--print-certs', str(args.apk)], text=True)
digests = re.findall(r'Signer #\d+ certificate SHA-256 digest: ([0-9a-fA-F]+)', result)
if [x.lower() for x in digests] != [expected] or re.search(r'CN=Android Debug\b', result):
    raise SystemExit('APK signer does not match expected production certificate')
manifest = subprocess.check_output([args.apkanalyzer, 'manifest', 'print', str(args.apk)], text=True)
root = ET.fromstring(manifest)
ns = '{http://schemas.android.com/apk/res/android}'
app = root.find('application')
def require(condition, message):
    if not condition:
        raise SystemExit(message)
require(root.get('package') == 'com.samirpandey.wifi_analyser', 'Wrong package')
require(root.get(ns+'versionName') == args.version_name, 'Wrong version name')
require(root.get(ns+'versionCode') == args.version_code, 'Wrong version code')
require(app is not None, 'Missing application')
require(app.get(ns+'debuggable', 'false') == 'false', 'Debuggable APK')
require(app.get(ns+'testOnly', 'false') == 'false', 'Test-only APK')
require(app.get(ns+'allowBackup') == 'false', 'Backup enabled')
for attr in ('fullBackupContent', 'dataExtractionRules'):
    require(app.get(ns+attr), f'Missing {attr}')
# Tie manifest resource IDs to the policies inspected below, including resource
# filename shortening performed by Android release packaging.
resources = subprocess.check_output([args.aapt2, 'dump', 'resources', str(args.apk)], text=True)
for attr, name in [('fullBackupContent', 'backup_rules'), ('dataExtractionRules', 'data_extraction_rules')]:
    match = re.search(r'resource (0x[0-9a-f]+) xml/' + name + r'\b', resources)
    require(match is not None and app.get(ns+attr) == '@ref/' + match.group(1), f'Manifest does not reference {name}')
# Inspect compiled XML rather than trusting source resource names/IDs.
for name, sections in [('backup_rules', ['full-backup-content']),
                       ('data_extraction_rules', ['cloud-backup', 'device-transfer'])]:
    resource_path = subprocess.check_output([args.apkanalyzer, 'resources', 'value', '--config', 'default', '--name', name, '--type', 'xml', str(args.apk)], text=True).strip()
    xml = subprocess.check_output([args.apkanalyzer, 'resources', 'xml', '--file', resource_path, str(args.apk)], text=True)
    policy = ET.fromstring(xml)
    for section in sections:
        element = policy if policy.tag == section else policy.find(section)
        require(element is not None, f'Missing backup section {section}')
        excluded = {(e.get('domain'), e.get('path')) for e in element.findall('exclude')}
        require(all((domain, '.') in excluded for domain in ('root', 'file', 'database', 'sharedpref', 'external', 'device_root', 'device_file', 'device_database', 'device_sharedpref')), f'Incomplete {section} exclusion')
print('APK production certificate, package/version, non-debuggable manifest and compiled backup rules verified.')
