"""Save complete, artifact-bound REA method evidence. No APK execution."""
import argparse, json, os, subprocess
from pathlib import Path
ROOT = Path(__file__).resolve().parent
env = os.environ.copy()
parser = argparse.ArgumentParser(description=__doc__)
parser.add_argument('apk', type=Path)
parser.add_argument('--jadx-jar', type=Path, required=True)
args = parser.parse_args()
env['REA_JADX_MCP_JAR'] = str(args.jadx_jar.resolve(strict=True))
REA = ['npx', '--yes', '--package=node@24', '--package=rea-agents@6.4.0', 'rea']
APK = str(args.apk.resolve(strict=True))
for cls, method, filename in [
    ('w2','D','scanner-start'),('w2','K','scanner-trigger'),
    ('w2','F','scanner-read'),('w2','x','scanner-ingest'),
]:
    output=ROOT/(filename+'.json')
    with output.open('w') as f:
        subprocess.run([*REA,'inspect-android-method',APK,'abdelrahman.wifianalyzerpro.'+cls,method,'--format','json'],env=env,stdout=f,check=True)
    result=json.loads(output.read_text())
    (ROOT/(filename+'.java.txt')).write_text(result['normalized_result']['source']['text'])
    print(filename,result['evidence_id'],flush=True)
