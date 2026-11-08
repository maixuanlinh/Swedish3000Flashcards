"""Explicitly accept only candidate IDs that the operator has visually reviewed."""
import json,sys,subprocess
from pathlib import Path
root=Path(__file__).resolve().parent.parent
for raw in sys.argv[1:]:
 sid=int(raw);p=root/f'Content/Generations/reverse-candidates/sv-{sid:04d}.json'
 candidate=json.loads(p.read_text());c=json.loads((root/'Content/catalog.json').read_text());card=next(x for x in c['entries'] if x['sourceID']==sid)
 assert candidate['prompt']==card['prompt'],'Candidate no longer matches current card; inspect before accepting'
 subprocess.run([sys.executable,str(root/'Tools/reverse_checkpoint.py'),str(sid),candidate['source']],check=True)
 candidate['reviewed']=True;p.write_text(json.dumps(candidate,ensure_ascii=False,indent=2)+'\n')
