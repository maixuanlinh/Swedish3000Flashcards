#!/usr/bin/env python3
"""Apply explicitly reviewed QA candidates, retaining original image masters."""
import hashlib
import json
import shutil
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
AUDIT = ROOT / 'Verification/QualityAudit'
def read(path):
    return json.loads(path.read_text())
def write(path, value):
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(json.dumps(value, ensure_ascii=False, indent=2) + '\n')

catalog = read(ROOT / 'Content/catalog.json')
artwork = read(ROOT / 'Content/artwork.json')
plans = read(AUDIT / 'correction-plans.json')
for plan in plans:
    word_id = plan['id']
    candidate = read(AUDIT / f'candidate-{word_id}.json')
    assert candidate['reviewed'] is True
    card = next(c for c in catalog['entries'] if c['id'] == word_id)
    assert card == plan['before'], f'{word_id}: catalog changed since review'
    source = Path(candidate['source'])
    assert '/.codex/generated_images/' in str(source) and source.is_file()
    relative = f'Content/Artwork/Revisions/{word_id}-qa01.png'
    destination = ROOT / relative
    assert not destination.exists(), 'Never overwrite an existing revision'
    destination.parent.mkdir(parents=True, exist_ok=True)
    shutil.copy2(source, destination)
    provenance_path = ROOT / f'Content/Generations/{word_id}.json'
    archived = AUDIT / f'original-generations/{word_id}.json'
    assert not archived.exists()
    archived.parent.mkdir(parents=True, exist_ok=True)
    shutil.copy2(provenance_path, archived)
    after = dict(plan['after'], artwork=relative)
    card.clear(); card.update(after)
    artwork[word_id] = {'path': relative, 'reviewed': True}
    write(provenance_path, {
        'id': word_id, 'english': card['english'], 'swedish': card['swedish'],
        'generationMode': 'built-in', 'prompt': candidate['prompt'],
        'referenceImage': plan['before']['artwork'], 'sourceFile': str(source),
        'artwork': relative, 'sha256': hashlib.sha256(destination.read_bytes()).hexdigest(),
        'review': {'heading': True, 'englishMeaning': True, 'swedishExample': True,
                   'memoryCaption': True, 'scene': True, 'status': 'visually-reviewed'},
        'correctionReason': plan['reason'],
        'originalProvenance': str(archived.relative_to(ROOT)),
        'reviewScope': 'AI visual review; independent Swedish proofreader sign-off pending.'
    })
    # Keep the original authoring rows consistent with the active lesson.
    for text_file in (ROOT / 'Content').glob('*-cards.txt'):
        lines = text_file.read_text().splitlines()
        matched = False
        for index, line in enumerate(lines):
            if line.startswith(str(card['sourceID']) + '|'):
                lines[index] = '|'.join([str(card['sourceID'])] + [card[k] for k in
                    ['swedish', 'sentence', 'sentenceEnglish', 'memoryHook', 'scene']])
                matched = True
        if matched:
            text_file.write_text('\n'.join(lines) + '\n')
write(ROOT / 'Content/catalog.json', catalog)
write(ROOT / 'Content/artwork.json', artwork)
write(AUDIT / 'applied-corrections.json', {
    'count': len(plans), 'themeRelated': False,
    'originalMastersPreserved': True,
    'corrections': [{'id': p['id'], 'reason': p['reason']} for p in plans]
})
print(f'Applied {len(plans)} reviewed corrections; original masters preserved.')
