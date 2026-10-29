"""Frozen seven-stage integration audit. Read-only native inputs; no GI-quality or performance verdict."""
import argparse
import hashlib
import importlib.util
import json
import math
from pathlib import Path
import re
import stat
import struct
import sys
import traceback
import zlib

P = Path(__file__).resolve().parent
ROOT = P.parents[2]
PROJECT = Path('I:/Unity test/Project')
NATIVE = Path('I:/Unity test/Comparison/UnifiedSample01')
OWNED = ('Assets/UnifiedSampleV201', 'Assets/StreamingAssets/UnifiedSampleV201')
STAGES = ('cold-near-details', 'far-aggregate-software', 'far-aggregate-dxr-reported',
          'far-aggregate-software-return', 'controller-disabled-release', 'reenabled-near-details', 'leave-release')
WIDTH, HEIGHT, MAX_REQUESTS = 640, 360, 1200


def require(value, message):
    if not value:
        raise ValueError(message)


def digest(data):
    return hashlib.sha256(data).hexdigest()


def parse(data):
    def pairs(values):
        result = {}
        for key, value in values:
            require(key not in result, 'Duplicate JSON field: ' + key)
            result[key] = value
        return result
    def invalid(value):
        raise ValueError('Nonfinite JSON literal: ' + value)
    result = json.loads(data.decode('utf-8-sig'), object_pairs_hook=pairs, parse_constant=invalid)
    def finite(value):
        if isinstance(value, float): require(math.isfinite(value), 'Nonfinite JSON numeric input')
        elif isinstance(value, dict):
            for child in value.values(): finite(child)
        elif isinstance(value, list):
            for child in value: finite(child)
    finite(result)
    return result


def no_reparse(path):
    for item in (path, *path.parents):
        try: info = item.lstat()
        except FileNotFoundError: continue
        require(not (getattr(info, 'st_file_attributes', 0) & stat.FILE_ATTRIBUTE_REPARSE_POINT) and not item.is_symlink(),
                'Redirected input path: ' + str(item))


def child(base, name):
    require(isinstance(name, str) and name and not name.startswith('/') and '\\' not in name and ':' not in name and
            all(part not in ('', '.', '..') for part in name.split('/')), 'Unsafe relative path: ' + repr(name))
    path = base / name
    no_reparse(path)
    require(path.resolve().is_relative_to(base.resolve()), 'Input escaped its package: ' + name)
    return path


def exr_header(data):
    require(len(data) > 8 and data[:4] == b'\x76\x2f\x31\x01', 'EXR magic differs')
    version = struct.unpack_from('<I', data, 4)[0]
    require(version & 255 == 2 and version & (0x200 | 0x800 | 0x1000) == 0, 'Unsupported tiled/deep/multipart EXR')
    cursor, attrs = 8, {}
    def string():
        nonlocal cursor
        end = data.find(b'\0', cursor, min(len(data), cursor + 256))
        require(end >= cursor, 'Invalid EXR header string')
        value = data[cursor:end].decode('ascii'); cursor = end + 1
        return value
    while True:
        name = string()
        if not name: break
        kind = string()
        require(cursor + 4 <= len(data), 'Truncated EXR attribute size')
        size = struct.unpack_from('<I', data, cursor)[0]; cursor += 4
        require(cursor + size <= len(data) and cursor + size < 65536 and name not in attrs, 'Invalid EXR attribute')
        attrs[name] = (kind, data[cursor:cursor + size]); cursor += size
    require(attrs.get('dataWindow', ('',))[0] == 'box2i' and len(attrs['dataWindow'][1]) == 16, 'Missing EXR dataWindow')
    box = struct.unpack('<4i', attrs['dataWindow'][1])
    require(box == (0, 0, WIDTH - 1, HEIGHT - 1), 'EXR dimensions differ')
    require(attrs.get('channels', ('',))[0] == 'chlist', 'Missing EXR channel list')
    channels, position, payload = {}, 0, attrs['channels'][1]
    while position < len(payload) and payload[position] != 0:
        end = payload.find(b'\0', position)
        require(end > position and end + 17 <= len(payload), 'Truncated EXR channel')
        name = payload[position:end].decode('ascii'); position = end + 1
        pixel_type, linear, reserved, x_sample, y_sample = struct.unpack_from('<iB3sii', payload, position); position += 16
        require(name not in channels and pixel_type == 2 and linear in (0, 1) and reserved == b'\0\0\0' and x_sample == y_sample == 1,
                'EXR channel is not full-resolution FLOAT')
        channels[name] = pixel_type
    require(position == len(payload) - 1 and payload[position] == 0 and {'R', 'G', 'B'} <= channels.keys() <= {'R', 'G', 'B', 'A'}, 'Unexpected EXR channels')
    return dict(dataWindow=list(box), channels=sorted(channels), pixelType='FLOAT', validation='header only; numeric evidence is the RGBA32F file')


def png_header(data):
    require(len(data) >= 45 and data[:8] == b'\x89PNG\r\n\x1a\n' and data[8:16] == b'\0\0\0\rIHDR', 'PNG signature/IHDR differs')
    fields = struct.unpack('>IIBBBBB', data[16:29])
    require(fields == (WIDTH, HEIGHT, 8, 6, 0, 0, 0), 'PNG is not the declared 640x360 RGBA8 preview')
    require(zlib.crc32(data[12:29]) == struct.unpack('>I', data[29:33])[0], 'PNG IHDR CRC differs')
    require(data[-12:] == b'\0\0\0\0IEND\xaeB`\x82', 'PNG IEND missing')
    return dict(width=WIDTH, height=HEIGHT, bitDepth=8, colorType='RGBA', validation='header only; display preview has no quality threshold')


class Audit:
    def __init__(self):
        self.pins, self.context = {}, 'source closure'
        self.identities, self.root_index, self.names, self.page_ids = None, None, None, None

    def read(self, path):
        no_reparse(path)
        data = path.read_bytes(); name = str(path.resolve()); value = digest(data)
        require(name not in self.pins or self.pins[name] == value, 'Input changed during audit: ' + name)
        self.pins[name] = value
        return data

    def load(self, path):
        return parse(self.read(path))

    def hashed(self, path, expected):
        require(isinstance(expected, str) and re.fullmatch('[0-9a-f]{64}', expected), 'Invalid SHA-256 declaration')
        data = self.read(path); require(digest(data) == expected, 'SHA-256 differs: ' + str(path)); return data

    def source(self):
        frozen = self.load(P / 'source-freeze.json')
        require(frozen['schema'] == 'unified-sample-native-v1' and Path(frozen['nativeOutput']).resolve() == NATIVE.resolve(), 'Source/native identity differs')
        for section in ('sources', 'evidence'):
            for name, value in frozen[section].items(): self.hashed(child(ROOT, name), value)
        def evidence(suffix):
            matches = [child(ROOT, name) for name in frozen['evidence'] if name.endswith(suffix)]
            require(len(matches) == 1, 'Missing/ambiguous final frozen evidence: ' + suffix)
            return matches[0]
        manifest_path = evidence('/manifest.json'); stage = manifest_path.parent
        require((P / 'verify_run.py').relative_to(ROOT).as_posix() in frozen['sources'], 'This verifier is not frozen')
        products = frozen['productSourceSha256']; require(len(products) == 120, 'Product file set differs')
        deployment = self.load(P / 'deployment.json'); require(deployment['passed'] and deployment['productSourceSha256'] == products, 'Deployment differs')
        for name, value in products.items():
            self.hashed(child(ROOT, name), value); self.hashed(child(PROJECT / 'Assets/HybridLumenGI', name), value)
        for row in deployment['files']:
            if row['path'].endswith('.meta'):
                self.hashed(child(ROOT, row['path']), row['afterSha256'])
                self.hashed(child(PROJECT / 'Assets/HybridLumenGI', row['path']), row['afterSha256'])
        preflight = self.load(evidence('/preflight/exit.json'))
        require(preflight['exitCode'] == 0 and len(preflight['assemblies']) == 2 and
                all(r['exitCode'] == 0 for r in preflight['assemblies']), 'Managed preflight not complete')
        identity = self.load(evidence('/preflight/identity.json'))
        require(identity['exitCode'] == 0 and identity['stagedManifestSha256'] == digest(self.read(manifest_path)), 'Managed source identity failed')
        manifest = self.load(manifest_path)
        require(manifest['productSourceSha256'] == products, 'Staged product set differs')
        for row in manifest['files']: self.hashed(child(stage, row['prepared']), row['sha256'])
        freeze_sha = digest(self.read(P / 'source-freeze.json'))
        attempt = self.load(P / 'attempt.json'); installed = self.load(stage / 'installed.json')
        require(attempt['sourceFreezeSha256'] == installed['sourceFreezeSha256'] == freeze_sha and
                Path(attempt['nativeOutput']).resolve() == NATIVE.resolve(), 'Attempt source identity differs')
        require(self.load(P / 'native-exit.json')['exitCode'] == 0, 'Native process did not exit successfully')
        require(attempt['performanceComparisonAllowed'] is False, 'Run incorrectly permits performance comparison')
        environment = self.load(P / 'run-environment.json')
        require(attempt['userGaming'] is False and attempt['userReportedGameExit'] is True and
                environment['userReportedConcurrentGameplay'] is False and environment['userReportedGameExitBeforeRun'] is True and
                environment['performanceComparisonPermitted'] is False, 'Final game-exit environment differs')
        restoration = self.load(P / 'restoration.json')
        require(restoration['productFiles'] == 120 and restoration['productMatches'] and restoration['ownedRootsRemoved'], 'Restoration receipt failed')
        archive = NATIVE / 'project-archive'
        require(Path(restoration['archiveDirectory']).resolve() == archive.resolve(), 'Archive identity differs')
        archived = {}
        for row in restoration['archivedFiles']:
            require(row['path'] not in archived, 'Duplicate archive entry')
            data = self.hashed(child(archive, row['path']), row['sha256']); require(len(data) == row['bytes'], 'Archive size differs')
            archived[row['path']] = row['sha256']
        actual_archive = {p.relative_to(archive).as_posix() for p in archive.rglob('*') if p.is_file()}
        require(actual_archive == set(archived), 'Archive contains missing or unlisted files')
        for name in OWNED:
            for path in (PROJECT / name, PROJECT / (name + '.meta')):
                no_reparse(path); require(not path.exists(), 'Owned project path remains: ' + str(path))
        protected = self.load(evidence('/protected.json'))
        restored = {row['path']: row for row in restoration['protected']}
        require(set(restored) == {row['path'] for row in protected}, 'Protected restoration set differs')
        for row in protected:
            self.hashed(child(PROJECT, row['path']), row['sha256'])
            self.hashed(child(stage, row['backup']), row['sha256'])
            require(restored[row['path']]['restored'], 'Protected path not restored')
        drivers = self.load(evidence('/native-drivers.json')); require(len(drivers) == 2, 'Native driver set differs')
        for row in drivers: require(archived.get(row['path']) == row['sha256'], 'Archived driver differs from compiled input')
        author = self.load(NATIVE / 'authoring-result.json')
        require(author['sourceUnchanged'] and author['emptyDestinations'] and author['detailMembers'] == 3 and author['aggregateMembers'] == 1,
                'Authoring/empty binding receipt failed')
        require(author['sourceScene'] != author['variantScene'] and author['bundleDirectory'] == OWNED[1], 'Authoring/variant/bundle paths differ')
        for key in ('sourceScene', 'variantScene'):
            require(author[key].startswith(OWNED[0] + '/Generated/'), 'Scene escaped the owned generated root')
            require(author[key] in archived, 'Scene was not archived')
        require(author['sourceBeforeSha256'] == author['sourceAfterSha256'] == archived[author['sourceScene']], 'Authoring scene bytes changed')
        require(any(name.startswith(OWNED[1] + '/') and not name.endswith(('.meta', '.manifest')) for name in archived), 'No built bundle bytes archived')
        editor = self.load(NATIVE / 'editor-result.json')
        require(editor['status'] == 'collected' and editor['restored'] and not editor.get('error') and editor['scene'] == author['variantScene'], 'Editor completion/restoration failed')
        return dict(sourceFreezeSha256=freeze_sha, products=120, protectedFiles=len(protected), archivedFiles=len(archived), authoring=author,
                    finalManifest=manifest_path.relative_to(ROOT).as_posix(), finalPreflight=evidence('/preflight/exit.json').relative_to(ROOT).as_posix(),
                    userReportedGameExit=True, gpuLoadMeasured=False)

    def bindings(self, rows, visible_check=True):
        require(isinstance(rows, list) and len(rows) == 4, 'Binding row count differs')
        require([r['name'] for r in rows] == self.names, 'Binding order/name changed')
        visible = set()
        for index, row in enumerate(rows):
            require(not row.get('error'), 'Representation reported an error')
            require(row['stableId'] in (0, self.identities[index]), 'Binding stable identity changed')
            expected_parent = 0 if index == self.root_index else self.identities[self.root_index]
            require(row['parentStableId'] in (0, expected_parent), 'Binding parent identity differs')
            require(row['materialSlots'] >= 0 and row['generation'] >= 0, 'Invalid binding count/generation')
            if row['bound']:
                require(row['stableId'] == self.identities[index] and row['meshBound'] and row['sdfBound'] and row['chartsBound'] and row['materialSlots'] > 0,
                        'Bound representation is incomplete')
            if row['visible']:
                require(row['rendererEnabled'] and not row['forceRenderingOff'] and row['bound'] and row['proxyEnabled'], 'Visible representation lacks a complete live binding')
                visible.add(index)
        if visible_check:
            require(visible in (set(), {self.root_index}, set(range(4)) - {self.root_index}), 'Partial or mixed visible HLOD group')
        return visible

    @staticmethod
    def empty_bindings(rows):
        return all(not any(row[k] for k in ('bound', 'visible', 'meshBound', 'sdfBound', 'chartsBound')) and row['materialSlots'] == 0 for row in rows)

    def pages(self, row):
        pages, ledger = row['pages'], row['ledger']
        require(len(pages) == len(self.page_ids) and {p['id'] for p in pages} == self.page_ids, 'Page identity set changed')
        counts = dict(Ready=0, LoadingBundle=0, BundleReady=0, LoadingAsset=0, Releasing=0, Failed=0, ReleaseFailed=0, Unloaded=0)
        for page in pages:
            require(page['phase'] in counts and page['consumerReferences'] >= 0, 'Invalid page state')
            counts[page['phase']] += 1
        require(ledger['pagesReady'] == counts['Ready'] and ledger['pagesLoading'] == counts['LoadingBundle'] + counts['BundleReady'] + counts['LoadingAsset'] and
                ledger['pagesReleasing'] == counts['Releasing'] and ledger['pagesFailed'] == counts['Failed'] + counts['ReleaseFailed'], 'Page ledger does not match page rows')
        require(ledger['pageConsumerReferences'] == sum(p['consumerReferences'] for p in pages), 'Page reference ledger differs')
        require(ledger['pagesFailed'] == 0 and ledger['retirementFailed'] == 0 and not ledger['retirementSubmissionUncertain'], 'Page/retirement failure')

    @staticmethod
    def released(row):
        ledger = row['ledger']
        return all(ledger[key] == 0 for key in ('pageBundleBytes', 'pageResidentBytes', 'pageIoBytesInFlight', 'pageActiveOperations', 'pageRetiringLeases', 'pageConsumerReferences')) and all(
            p['phase'] == 'Unloaded' and not p['wanted'] and p['consumerReferences'] == 0 for p in row['pages'])

    def phase_condition(self, row, index):
        before = {i for i, r in enumerate(row['beforeDraw']) if r['visible']}
        after = {i for i, r in enumerate(row['afterCamera']) if r['visible']}
        if index in (4, 6):
            return row['controllerEnabled'] == (index == 6) and self.empty_bindings(row['afterCamera']) and not before and self.released(row)
        detail, hardware = index in (0, 5), index == 2
        if not row['controllerEnabled'] or row['requestedHardware'] != hardware or row['ledger']['cameraGi']['hardwareBackend'] != hardware: return False
        publication = row['publication']
        if not publication['current'] or publication['phase'] != 'Published' or publication['transitioning'] or publication['capacityFallback'] or publication['targetUnknownCount'] or publication['targetWarmingCount']: return False
        if row['ledger']['cameraGi']['frame'] != publication['preparedWorkFrame'] + 1: return False
        expected = set(range(4)) - {self.root_index} if detail else {self.root_index}
        if before != expected or after != expected: return False
        if not detail and any(row['afterCamera'][i]['bound'] for i in range(4) if i != self.root_index): return False
        ids = sorted(self.identities[i] for i in expected)
        return publication['publishedIds'] == publication['targetIds'] == ids

    def image(self, receipt, index):
        prefix = 'stage-%02d-%s' % (index, STAGES[index])
        require(receipt['width'] == WIDTH and receipt['height'] == HEIGHT and receipt['format'] == 'rgba32f-le' and
                receipt['rowOrder'] == 'native-texture-memory-order; not orientation-normalized for comparison', 'Stage HDR descriptor differs')
        data = {}
        for key, suffix in (('raw', '.rgba32f'), ('exr', '.exr'), ('preview', '.png')):
            require(receipt[key + 'File'] == prefix + suffix, 'Stage artifact identity differs')
            data[key] = self.hashed(child(NATIVE, receipt[key + 'File']), receipt[key + 'Sha256'])
        raw = data['raw']; require(len(raw) == WIDTH * HEIGHT * 16, 'HDR byte count differs')
        minimum, maximum, positive = math.inf, -math.inf, 0
        for pixel in struct.iter_unpack('<4f', raw):
            require(all(math.isfinite(v) for v in pixel), 'Nonfinite native HDR component')
            minimum = min(minimum, *pixel); maximum = max(maximum, *pixel)
            positive += any(v > 0 for v in pixel[:3])
        f32 = lambda value: struct.unpack('<f', struct.pack('<f', value))[0]
        require(receipt['finiteValues'] == WIDTH * HEIGHT * 4 and receipt['positiveRgbPixels'] == positive and
                f32(receipt['minimum']) == minimum and f32(receipt['maximum']) == maximum, 'HDR numeric receipt differs from raw bytes')
        return dict(stage=STAGES[index], request=receipt['request'], rawSha256=digest(raw), finiteComponents=WIDTH * HEIGHT * 4,
                    minimum=minimum, maximum=maximum, positiveRgbPixels=positive,
                    exr=exr_header(data['exr']), preview=png_header(data['preview']))

    def run(self):
        source = self.source(); self.context = 'native receipts'
        host = self.load(NATIVE / 'host-result.json')
        require(host['status'] == 'collected' and not host.get('error') and host['completedStages'] == 7 and host['readbacksDrained'] and host['coldBindingsObserved'] and host['targetRetirementQueued'], 'Host did not complete all seven stages')
        count = host['requests']; require(type(count) is int and 21 <= count <= MAX_REQUESTS, 'Invalid request count')
        require(all(host[key] == count for key in ('renderedFrames', 'cameraBegins', 'cameraEnds', 'contextBegins', 'contextEnds')), 'Camera/context/request counters differ')
        require(host['api'] == 'Direct3D12' and 0 <= host['elapsedSeconds'] <= 1800 and Path(host['outputDirectory']).resolve() == NATIVE.resolve() and host['scene'] == source['authoring']['variantScene'], 'Host identity/deadline differs')
        receipts = host['stages']; require([r['stage'] for r in receipts] == list(STAGES), 'Stage receipts differ')
        baseline = receipts[0]['frame']['afterCamera']
        require(len(baseline) == 4 and len({r['stableId'] for r in baseline}) == 4 and all(r['stableId'] > 0 for r in baseline), 'No complete stable binding identity')
        roots = [i for i, r in enumerate(baseline) if r['parentStableId'] == 0]; require(len(roots) == 1, 'Expected one root identity')
        self.root_index = roots[0]; self.identities = [r['stableId'] for r in baseline]; self.names = [r['name'] for r in baseline]
        require(all(r['parentStableId'] == self.identities[self.root_index] for i, r in enumerate(baseline) if i != self.root_index), 'Detail parent graph differs')
        events = [parse(line.encode('utf-8')) for line in self.read(NATIVE / 'events.jsonl').decode('utf-8-sig').splitlines() if line.strip()]
        require(events and events[0]['eventType'] == 'cold-start' and sum(r['eventType'] == 'cold-start' for r in events) == 1, 'Missing/duplicate cold observation')
        self.page_ids = {r['id'] for r in events[0]['pages']}; require(self.page_ids and len(self.page_ids) == len(events[0]['pages']), 'No unique page definitions')
        cold = events[0]; self.bindings(cold['afterCamera']); self.pages(cold)
        require(cold['request'] == 0 and self.empty_bindings(cold['afterCamera']) and self.released(cold), 'Cold state owns bound assets/pages')
        require(all(not r['proxyEnabled'] and not r['rendererEnabled'] and r['forceRenderingOff'] for r in cold['afterCamera']), 'Cold destinations are enabled/visible')
        camera_rows, entries, pipelines, last_engine, current_stage, streak = [], [], set(), -1, -1, 0
        allocated = [0] * 4
        for event in events:
            kind = event['eventType']; self.context = dict(event=kind, stage=event['stage'], request=event['request'], engineFrame=event['engineFrame'])
            require(kind in ('cold-start', 'pipeline-ready-candidate', 'stage-enter', 'camera-complete'), 'Unexpected native event')
            self.bindings(event['afterCamera']); self.pages(event)
            for i, binding in enumerate(event['afterCamera']):
                if allocated[i]: require(binding['stableId'] == allocated[i], 'Allocated proxy identity reset')
                elif binding['stableId']: allocated[i] = binding['stableId']
            if kind == 'stage-enter':
                current_stage += 1; streak = 0; entries.append(event)
                require(current_stage < 7 and event['stage'] == STAGES[current_stage] and event['request'] == len(camera_rows), 'Stage transition order differs')
            elif kind == 'camera-complete':
                require(current_stage >= 0 and event['stage'] == STAGES[current_stage] and event['request'] == len(camera_rows) + 1, 'Camera request sequence differs')
                require(event['engineFrame'] > last_engine, 'Duplicate/out-of-order engine request'); last_engine = event['engineFrame']
                require(event['pipelineIdentity'] != 0, 'Missing live pipeline identity'); pipelines.add(event['pipelineIdentity'])
                self.bindings(event['beforeDraw'])
                require(event['ledger']['cameraGi'] is not None and event['ledger']['cameraGi']['frame'] == event['request'], 'GI did not record exactly once per request')
                require(event['requestedHardware'] == (current_stage == 2) and event['controllerEnabled'] == (current_stage != 4), 'Requested mode differs from the frozen stage')
                publication = event['publication']
                require(publication['current'] == (publication['available'] and publication['preparedEngineFrame'] == event['engineFrame']), 'Current publication flag differs from its inputs')
                condition = self.phase_condition(event, current_stage); streak = streak + 1 if condition else 0
                require(event['phaseCondition'] == condition and event['consecutiveConditions'] == streak, 'Stage qualification/streak differs from independent recomputation')
                camera_rows.append(event)
            else: require(current_stage == -1 and event['request'] == 0, 'Startup event after camera admission')
        require(len(camera_rows) == count and len(entries) == 7 and len(pipelines) == 1, 'Incomplete sequence or pipeline replacement')
        images, last_selected = [], 0
        for index, receipt in enumerate(receipts):
            self.context = dict(stage=STAGES[index], selectedRequest=receipt['request'])
            request = receipt['request']; require(last_selected < request <= count, 'Stage selection order differs'); last_selected = request
            frame = camera_rows[request - 1]
            require(receipt['frame'] == frame and receipt['engineFrame'] == frame['engineFrame'] and receipt['minimumConsecutiveConditions'] == 3 and frame['consecutiveConditions'] >= 3, 'Image is not bound to its qualified camera event')
            triple = camera_rows[request - 3:request]
            require(len(triple) == 3 and all(r['stage'] == STAGES[index] and self.phase_condition(r, index) for r in triple), 'Stage lacks three consecutive matching camera renders')
            require(all(not r['requestedHardware'] and not r['ledger']['cameraGi']['hardwareBackend'] for r in triple) if index != 2 else
                    all(r['requestedHardware'] and r['ledger']['cameraGi']['hardwareBackend'] for r in triple), 'Requested/reported stage backend differs')
            if index in (4, 6):
                require(self.empty_bindings(frame['beforeDraw']) and self.empty_bindings(frame['afterCamera']) and self.released(frame), 'Selected release image still owns bindings/pages')
                require(all(not r['proxyEnabled'] and not r['rendererEnabled'] and r['forceRenderingOff'] for r in frame['afterCamera']), 'Released representation remains enabled')
            stage_file = NATIVE / ('stage-%02d-%s.json' % (index, STAGES[index]))
            require(self.load(stage_file) == receipt, 'Stage sidecar differs from host receipt')
            if index + 1 < 7: require(entries[index + 1]['request'] == request, 'Requests continued after selecting a stage image')
            images.append(self.image(receipt, index))
        require(last_selected == count, 'Unaccounted renders after final stage')
        for suffix in ('.json', '.rgba32f', '.exr', '.png'):
            expected = {'stage-%02d-%s%s' % (i, name, suffix) for i, name in enumerate(STAGES)}
            require({p.name for p in NATIVE.glob('stage-*' + suffix)} == expected, 'Stage artifact set differs: ' + suffix)
        self.context = 'native log'
        log_path = P / 'unity.log'; text = self.read(log_path).decode('utf-8-sig')
        helper = ROOT / 'LocalComparison/Harness/native_log_check.py'
        spec = importlib.util.spec_from_file_location('unified_sample_native_log', helper); module = importlib.util.module_from_spec(spec); spec.loader.exec_module(module)
        hits, structured = [], []
        marker = 'UNIFIED_SAMPLE_HOST_RESULT '
        for number, line in enumerate(text.splitlines(), 1):
            if marker in line:
                structured.append(parse(line.split(marker, 1)[1].encode('utf-8')))
                continue  # Parse this complete JSON record; never match a regex across unrelated JSON fields.
            for category, pattern in module.PATTERNS.items():
                if re.search(pattern, line, re.I): hits.append(dict(line=number, category=category, text=line))
        require(structured == [host], 'Missing/duplicate/mismatched structured Host log receipt')
        require(not hits, 'Native Unity error signatures: ' + json.dumps(hits[:4]))
        self.context = 'input immutability'
        for name, value in list(self.pins.items()): require(digest(Path(name).read_bytes()) == value, 'Input changed after reading: ' + name)
        return dict(passed=True, integrationComplete=True, source=source, cameraRequests=count, completeStages=7,
                    atomicCameraBeforeAfterChecks=count * 2, threeConsecutiveQualifiedRendersPerStage=True,
                    coldUnboundAndReleased=True, disabledAndLeavePagesReleased=True, pipelineIdentities=sorted(pipelines),
                    images=images, nativeLogSha256=digest(self.read(log_path)), nativeLogHits=[],
                    backendScope='Requested and CPU-reported backend only', perRayHardwareVerified=False,
                    physicalQualityPassed=None, performanceCompared=False,
                    accountingScope='Page-owned leases/references/accounted bytes are zero at release. Remaining scene GI/RTAS is not required to be zero; no total VRAM sum.',
                    scope='Same-scene bounded integration, HDR finite-data integrity and source/restoration closure; not physical correctness or throughput',
                    inputSha256=self.pins)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--output', type=Path, default=P / 'run-verification-first.json')
    args = parser.parse_args(); require(not args.output.exists(), 'Preserve the first verification result')
    audit = Audit()
    try:
        result = audit.run()
    except Exception as error:
        result = dict(passed=False, integrationComplete=False, context=audit.context, error=str(error), traceback=traceback.format_exc(),
                      inputSha256=audit.pins, physicalQualityPassed=None, perRayHardwareVerified=False, performanceCompared=False)
    args.output.parent.mkdir(parents=True, exist_ok=True)
    with args.output.open('x', encoding='utf-8') as stream:
        json.dump(result, stream, indent=2); stream.write('\n')
    print(json.dumps(dict(passed=result['passed'], output=str(args.output), context=result.get('context'))))
    return 0 if result['passed'] else 1


if __name__ == '__main__':
    sys.exit(main())
