"""Save complete, artifact-bound REA method evidence. No APK execution."""
import json, os, subprocess
from pathlib import Path
ROOT = Path(__file__).resolve().parent
env = os.environ.copy()
env['REA_JADX_MCP_JAR'] = '/Users/samirpandey/Developer/personal/rea-tools/jadx-headless-mcp-0.7.1-all.jar'
REA = ['npx', '--yes', '--package=node@24', '--package=rea-agents@6.4.0', 'rea']
APK = '/Users/samirpandey/Downloads/WiFi_Analyzer_(9.4).apk'
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
