"""One-off release upload via the existing repository credential helper.

Credentials stay in memory and are never printed or written to a file.
"""
import argparse
import json
import os
from pathlib import Path
import subprocess
import urllib.request

HERE = Path(__file__).resolve().parent
BASE = 'https://api.github.com/repos/Ranko-sama/HybridLumenGI'
TAG = 'release94-demo'
SOURCE = 'e296750444a835c1346e073c7b6f73100dc64688'
parser = argparse.ArgumentParser()
parser.add_argument('action', choices=['inspect', 'draft', 'upload', 'publish'])
action = parser.parse_args().action
env = dict(os.environ, GCM_INTERACTIVE='Never', GIT_TERMINAL_PROMPT='0')
credential = subprocess.run(['git', '-c', 'credential.interactive=never', 'credential', 'fill'],
    input='protocol=https\nhost=github.com\npath=Ranko-sama/HybridLumenGI.git\n\n',
    text=True, capture_output=True, env=env, timeout=30)
if credential.returncode:
    raise RuntimeError('Existing Git credential helper could not authorize this repository')
secret = dict(line.split('=', 1) for line in credential.stdout.splitlines() if '=' in line).get('password')
if not secret:
    raise RuntimeError('Credential helper returned no usable credential')

def request(url, method='GET', payload=None, binary=None):
    if not (url.startswith(BASE) or url.startswith('https://uploads.github.com/repos/Ranko-sama/HybridLumenGI/')):
        raise RuntimeError('Unexpected release API destination')
    headers = {'Accept': 'application/vnd.github+json', 'Authorization': 'Bearer ' + secret,
               'User-Agent': 'HybridLumenGI-local-delivery', 'X-GitHub-Api-Version': '2026-03-10'}
    data = None
    if payload is not None:
        data = json.dumps(payload).encode('utf-8'); headers['Content-Type'] = 'application/json'
    if binary is not None:
        data = binary; headers['Content-Type'] = 'application/zip'
    req = urllib.request.Request(url, data=data, headers=headers, method=method)
    with urllib.request.urlopen(req, timeout=180) as response:
        return json.load(response)

def save(name, value):
    (HERE / name).write_text(json.dumps(value, indent=2, ensure_ascii=False), encoding='utf-8')

repo = request(BASE)
if repo['full_name'] != 'Ranko-sama/HybridLumenGI' or not repo['private']:
    raise RuntimeError('Expected the authorized private repository; visibility was not changed')
if action == 'inspect':
    releases = request(BASE + '/releases?per_page=100')
    result = dict(repository=repo['full_name'], private=repo['private'], defaultBranch=repo['default_branch'],
                  releases=[dict(id=r['id'], tag=r['tag_name'], draft=r['draft']) for r in releases])
    save('repository-state.json', result); print(json.dumps(result))
elif action == 'draft':
    if (HERE / 'release-state.json').exists():
        raise RuntimeError('Preserve existing draft; inspect it before further action')
    if any(r['tag_name'] == TAG for r in request(BASE + '/releases?per_page=100')):
        raise RuntimeError('Release tag already exists; do not replace it')
    package = json.loads((HERE / 'package-result.json').read_text(encoding='utf-8'))
    if not Path(package['path']).is_file():
        raise RuntimeError('Package must be completed before creating a release')
    result = request(BASE + '/releases', 'POST', dict(tag_name=TAG, target_commitish=SOURCE,
        name='Release94 — Windows x64 实验性演示', body=(HERE / 'release-notes.md').read_text(encoding='utf-8'),
        draft=True, prerelease=True, make_latest='false'))
    save('release-state.json', result)
    print(json.dumps({k: result[k] for k in ['id', 'html_url', 'draft', 'prerelease', 'tag_name']}))
elif action == 'upload':
    prior = json.loads((HERE / 'release-state.json').read_text(encoding='utf-8'))
    release = request(BASE + '/releases/' + str(prior['id']))
    if not release['draft'] or release['tag_name'] != TAG or release['assets']:
        raise RuntimeError('Expected our empty draft; do not overwrite assets')
    package = json.loads((HERE / 'package-result.json').read_text(encoding='utf-8'))
    path = Path(package['path'])
    url = release['upload_url'].split('{', 1)[0] + '?name=' + path.name
    result = request(url, 'POST', binary=path.read_bytes())
    save('asset-state.json', result)
    if result['state'] != 'uploaded' or result['size'] != path.stat().st_size:
        raise RuntimeError('Release asset upload is incomplete')
    print(json.dumps({k: result[k] for k in ['id', 'name', 'size', 'state', 'browser_download_url']}))
else:
    prior = json.loads((HERE / 'release-state.json').read_text(encoding='utf-8'))
    release = request(BASE + '/releases/' + str(prior['id']))
    package = json.loads((HERE / 'package-result.json').read_text(encoding='utf-8'))
    if not release['draft'] or not release['prerelease'] or release['tag_name'] != TAG:
        raise RuntimeError('Expected our prepared experimental draft')
    assets = release['assets']
    if len(assets) != 1 or assets[0]['name'] != Path(package['path']).name or assets[0]['size'] != package['bytes'] or assets[0]['state'] != 'uploaded':
        raise RuntimeError('The prepared download is incomplete')
    request(BASE + '/releases/' + str(prior['id']), 'PATCH', dict(draft=False, prerelease=True, make_latest='false'))
    result = request(BASE + '/releases/tags/' + TAG)
    save('published-release.json', result)
    if result['draft'] or not result['prerelease'] or len(result['assets']) != 1:
        raise RuntimeError('Published release state differs from the intended delivery')
    print(json.dumps(dict(url=result['html_url'], prerelease=result['prerelease'],
        asset=result['assets'][0]['browser_download_url'], bytes=result['assets'][0]['size'])))
