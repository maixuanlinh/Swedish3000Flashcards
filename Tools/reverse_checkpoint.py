"""Save a visually reviewed reverse-worker output without replacing existing art."""
import json,sys,subprocess,datetime
from pathlib import Path
root=Path(__file__).resolve().parent.parent
sid=int(sys.argv[1]); source=sys.argv[2]
catalog=json.loads((root/'Content/catalog.json').read_text())
card=next(e for e in catalog['entries'] if e['sourceID']==sid)
batchpath=root/'Content/Generations/reverse-reviewed.json'
batch=json.loads(batchpath.read_text()) if batchpath.exists() else []
assert not any(e['id']==card['id'] for e in batch)
batch.append(dict(id=card['id'],source=source,reviewed=True,prompt=card['prompt']))
batchpath.write_text(json.dumps(batch,ensure_ascii=False,indent=2)+'\n')
# Import only the new item; the importer rereads the current shared manifest.
one=root/'Content/Generations/reverse-current-reviewed.json'
manifest=json.loads((root/'Content/artwork.json').read_text())
missing=[item for item in batch if item['id'] not in manifest]
one.write_text(json.dumps(missing,ensure_ascii=False,indent=2)+'\n')
subprocess.run(['node',str(root/'Tools/import_artwork.mjs'),'Content/Generations/reverse-current-reviewed.json'],check=True)
p=root/'Content/Generations/reverse-worker-status.json'
s=json.loads(p.read_text());s.update(currentID=sid-1,lastReviewedID=sid,reviewedCount=len(batch),updatedAt=datetime.datetime.now(datetime.timezone.utc).isoformat())
p.write_text(json.dumps(s,indent=2)+'\n')
