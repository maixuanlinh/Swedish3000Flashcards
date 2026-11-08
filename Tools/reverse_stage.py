"""Record a generated candidate for later visual review; never marks it ready."""
import json,sys
from pathlib import Path
root=Path(__file__).resolve().parent.parent
sid=int(sys.argv[1]);source=Path(sys.argv[2]).resolve()
assert '/.codex/generated_images/' in str(source) and source.suffix=='.png' and source.is_file()
c=json.loads((root/'Content/catalog.json').read_text());e=next(x for x in c['entries'] if x['sourceID']==sid)
p=root/f'Content/Generations/reverse-candidates/{e["id"]}.json';p.parent.mkdir(exist_ok=True)
assert not p.exists(),'Keep existing candidate records'
p.write_text(json.dumps(dict(id=e['id'],source=str(source),reviewed=False,prompt=e['prompt']),ensure_ascii=False,indent=2)+'\n')
