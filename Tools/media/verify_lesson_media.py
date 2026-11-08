"""Audit the finished media release independently of Android playback."""
import argparse
import hashlib
import json
from pathlib import Path
import subprocess

ROOT=Path(__file__).resolve().parents[2]

def main():
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--directory',type=Path,default=ROOT/'MediaDelivery/public/v1')
    args=parser.parse_args()
    manifest=json.loads((args.directory/'manifest.json').read_text())
    catalog=json.loads((ROOT/'Resources/catalog3000.json').read_text())['entries']
    starters={r['id']:r for r in json.loads((ROOT/'Resources/starter100.json').read_text())}
    examples={r['id']:r for r in json.loads((ROOT/'Resources/examples3000.json').read_text())}
    pictures=json.loads((ROOT/'Resources/BundledArtwork/manifest.json').read_text())
    expected=set()
    for word in catalog:
        source=starters.get(word['id'],word)
        for language,text in [('sv-SE',source['swedish']),('en-US',source['english']),('sv-SE',examples[word['id']]['sentence'])]:
            expected.add('audio/'+language+'/'+hashlib.sha256(text.encode('utf-8')).hexdigest())
    audio_count=len(expected)
    for image in pictures:
        expected.update(['image/'+image['filename'],'image/'+image['thumbnailFilename']])
    assert len(catalog)==manifest['wordCount']==3000
    assert audio_count==manifest['recordingCount']
    assert len({r['key'] for r in manifest['assets']})==len(manifest['assets'])
    assert {r['key'] for r in manifest['assets']}==expected
    image_bytes=audio_bytes=0
    decode_samples=[]
    from PIL import Image
    import io
    for pack in manifest['packs']:
        path=args.directory/pack['file']
        content=path.read_bytes()
        assert len(content)==pack['bytes'] and hashlib.sha256(content).hexdigest()==pack['sha256']
        assert pack['file']=='pack-'+pack['sha256']+'.bin' and len(content)<=8_000_000
        offset=0
        for item in sorted([r for r in manifest['assets'] if r['pack']==pack['file']],key=lambda r:r['offset']):
            assert item['offset']==offset
            data=content[offset:offset+item['bytes']]
            assert len(data)==item['bytes'] and hashlib.sha256(data).hexdigest()==item['sha256']
            offset+=len(data)
            if item['key'].startswith('image/'):
                image_bytes+=len(data)
                with Image.open(io.BytesIO(data)) as compressed:
                    assert compressed.format=='WEBP'
                    with Image.open(ROOT/'Resources/BundledArtwork'/item['key'].removeprefix('image/')) as original:
                        assert compressed.size==original.size
                    compressed.verify()
            else:
                audio_bytes+=len(data)
                if len(decode_samples)<20: decode_samples.append(data)
        assert offset==len(content)
    import imageio_ffmpeg
    for data in decode_samples:
        subprocess.run([imageio_ffmpeg.get_ffmpeg_exe(),'-v','error','-f','mp3','-i','pipe:0','-f','null','-'],input=data,capture_output=True,check=True)
    result={'words':len(catalog),'recordings':audio_count,'images':sum(k.startswith('image/') for k in expected),'packs':len(manifest['packs']),
            'imageBytes':image_bytes,'audioBytes':audio_bytes,'totalMediaBytes':image_bytes+audio_bytes,
            'starterBytes':sum(p['bytes'] for p in manifest['packs'] if p['starter']),
            'checks':['all expected words and recordings mapped','all image dimensions preserved','every pack and asset SHA-256 verified','pack boundaries checked','20 MP3 samples decoded']}
    print(json.dumps(result,indent=2))
    (ROOT/'MediaDelivery/verification.json').write_text(json.dumps(result,indent=2))

if __name__=='__main__':main()
