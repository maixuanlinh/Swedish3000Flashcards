#!/usr/bin/env python3
"""Evidence-based inventory and OCR triage, not a linguistic sign-off."""
import collections
import difflib
import hashlib
import json
import re
import unicodedata
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
AUDIT = ROOT / 'Verification/QualityAudit'
catalog = json.loads((AUDIT / 'catalog-before.json').read_text())['entries']
artwork = json.loads((AUDIT / 'artwork-before.json').read_text())
bundled = {r['wordID']: r for r in json.loads((AUDIT / 'bundle-before.json').read_text())}
ocr = {r['id']: r for r in map(json.loads, (AUDIT / 'ocr-verified.jsonl').read_text().splitlines())}

def normal(text):
    return ''.join(c for c in unicodedata.normalize('NFC', text).casefold() if c.isalnum())

def closest(expected, lines):
    target = normal(expected)
    candidates = []
    for start in range(len(lines)):
        for count in range(1, 5):
            text = ' '.join(lines[start:start+count])
            candidates.append((difflib.SequenceMatcher(None, target, normal(text)).ratio(), text))
    return max(candidates, default=(0, ''))

rows = []
flags = []
for card in catalog:
    word_id = card['id']
    provenance = AUDIT / 'original-generations' / (word_id + '.json')
    if not provenance.exists():
        provenance = ROOT / 'Content/Generations' / (word_id + '.json')
    p = json.loads(provenance.read_text())
    review = p.get('review', {})
    checks = {
        'productionVisualReviewRecorded': all(review.get(k) is True for k in ['heading', 'englishMeaning', 'swedishExample', 'memoryCaption']) and review.get('status') == 'visually-reviewed',
        'reviewedArtworkRecord': artwork.get(word_id, {}).get('reviewed') is True,
        'nonemptyLessonFields': all(isinstance(card.get(k), str) and card[k].strip() for k in ['english','swedish','sentence','sentenceEnglish','memoryHook','scene']),
        'stableID': word_id == f"sv-{card['sourceID']:04d}",
        'originalMasterHashMatches': hashlib.sha256((ROOT / artwork[word_id]['path']).read_bytes()).hexdigest() == bundled[word_id]['masterSHA256'],
    }
    observation = ocr.get(word_id, {})
    lines = [r['text'] for r in observation.get('observations', [])]
    text = normal(' '.join(lines).replace('Memory trick', ''))
    expected = {'heading':card['swedish'], 'englishMeaning':card['english'], 'swedishExample':card['sentence'], 'memoryCaption':card['memoryHook']}
    matches = {key: normal(value) in text for key, value in expected.items()}
    row = {'id':word_id, 'english':card['english'], 'checks':checks, 'ocrSucceeded':bool(lines), 'ocrMatches':matches}
    rows.append(row)
    if not all(checks.values()) or not all(matches.values()) or not lines:
        flags.append({'id':word_id,'english':card['english'],'failedChecks':[k for k,v in checks.items() if not v], 'ocrError':observation.get('error'), 'unmatched':{key:{'expected':expected[key], 'closest':closest(expected[key], lines)} for key,v in matches.items() if not v}, 'recognizedText':lines})

summary = {
    'scope':'All 3000 production records and a fresh OCR pass over the bundled images captured before corrections.',
    'cards':len(rows), 'productionVisualReviewRecords':sum(r['checks']['productionVisualReviewRecorded'] for r in rows),
    'inventoryChecksPassed':sum(all(r['checks'].values()) for r in rows),
    'ocrImagesRead':sum(r['ocrSucceeded'] for r in rows),
    'allFourFieldsOCRMatched':sum(all(r['ocrMatches'].values()) for r in rows),
    'ocrMatchCounts':{key:sum(r['ocrMatches'][key] for r in rows) for key in ['heading','englishMeaning','swedishExample','memoryCaption']},
    'flaggedForTriage':len(flags),
    'independentSwedishReviewComplete':False,
    'all3000ExamplesManuallyRecheckedThisPass':False,
    'automatedChecksCertifyMeaningOrScene':False,
    'releaseSignOff':'Not granted. See visual-triage.json for OCR triage; independent language and scene review remains required.',
    'note':'A mismatch may be an OCR error or a real image/text defect. A match does not certify grammar, translation, object counts, anatomy or scene accuracy.'
}
(AUDIT / 'inventory-and-ocr.json').write_text(json.dumps({'summary':summary,'cards':rows},ensure_ascii=False,indent=2)+'\n')
(AUDIT / 'ocr-flags.json').write_text(json.dumps(flags,ensure_ascii=False,indent=2)+'\n')
print(json.dumps(summary,ensure_ascii=False,indent=2))
