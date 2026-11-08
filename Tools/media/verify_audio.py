"""Check every recording's exact lesson mapping, checksum, decode and signal."""
import concurrent.futures
import hashlib
import json
from pathlib import Path
import re
import subprocess
import imageio_ffmpeg

ROOT = Path(__file__).resolve().parents[2]
work = ROOT / 'MediaDelivery/work'
index = json.loads((work / 'audio-index.json').read_text())
cards = json.loads((ROOT / 'Content/catalog.json').read_text())['entries']
expected = {}
for card in cards:
    for language, text in [('en-US', card['english']), ('sv-SE', card['swedish']), ('sv-SE', card['sentence'])]:
        key = f'audio/{language}/' + hashlib.sha256(text.encode()).hexdigest()
        expected[key] = (language, text)
assert set(index['recordings']) == set(expected)
ffmpeg = imageio_ffmpeg.get_ffmpeg_exe()

def check(item):
    key, (language, text) = item
    record = index['recordings'][key]
    path = work / 'audio' / (key.replace('/', '_') + '.mp3')
    data = path.read_bytes()
    assert record['language'] == language and record['text'] == text, key
    assert len(data) == record['bytes'] and hashlib.sha256(data).hexdigest() == record['sha256'], key
    assert .12 < record['seconds'] < 45.2, key
    result = subprocess.run([ffmpeg, '-hide_banner', '-nostats', '-i', str(path),
        '-af', 'volumedetect', '-f', 'null', '-'], capture_output=True, text=True, check=True)
    assert '22050 Hz, mono' in result.stderr, key
    match = re.search(r'mean_volume: (-?[0-9.]+) dB', result.stderr)
    assert match and float(match[1]) > -60, f'Silent or extremely quiet recording: {key}'
    return {'key': key, 'sha256': record['sha256'], 'seconds': record['seconds'], 'meanVolumeDB': float(match[1])}

rows = []
with concurrent.futures.ThreadPoolExecutor(max_workers=4) as pool:
    for row in pool.map(check, expected.items()):
        rows.append(row)
        if len(rows) % 500 == 0:
            print(f'Verified and decoded {len(rows)}/{len(expected)} recordings', flush=True)
summary = {'cards': len(cards), 'playbackPositions': len(cards) * 3, 'distinctRecordings': len(rows),
    'allHashesMatch': True, 'allDecodeAsMono22050MP3': True, 'allHaveNonSilentSignal': True,
    'pronunciationSignOff': False, 'note': 'Listening review is still required; these checks do not certify pronunciation.'}
output = ROOT / 'Verification/RecordedAudio'
output.mkdir(parents=True, exist_ok=True)
(output / 'audio-integrity.json').write_text(json.dumps({'summary': summary, 'recordings': rows}, indent=2) + '\n')
print(json.dumps(summary, indent=2), flush=True)
