import assert from 'node:assert/strict';
import fs from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';
import { createHash } from 'node:crypto';
import { execFileSync } from 'node:child_process';
const root = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '..');
const read = (name) => JSON.parse(fs.readFileSync(path.join(root, name), 'utf8'));
const write = (name, data) => {
  fs.mkdirSync(path.dirname(path.join(root, name)), { recursive: true });
  fs.writeFileSync(path.join(root, name), `${JSON.stringify(data, null, 2)}\n`);
};
const catalog = read('Content/catalog.json');
const artwork = read('Content/artwork.json');
assert.equal(catalog.entries.length, 3000);
assert.equal(new Set(catalog.entries.map((entry) => entry.id)).size, 3000);
const ready = catalog.entries.filter((entry) => entry.contentStatus !== 'pending');
for (const entry of ready) {
  entry.artworkStatus = artwork[entry.id]?.reviewed ? 'reviewed' : 'pending';
  entry.artwork = artwork[entry.id]?.path ?? null;
}
assert(ready.length > 0 && ready.length <= 3000);
for (const entry of ready) {
  assert.equal(entry.id, `sv-${String(entry.sourceID).padStart(4, '0')}`);
  for (const key of ['english', 'swedish', 'sentence', 'sentenceEnglish', 'memoryHook', 'prompt']) assert(entry[key]?.trim(), `${entry.id}: ${key}`);
  assert(!('finnish' in entry));
}
write('Resources/catalog3000.json', {
  source: catalog.source, targetCount: 3000, entryCount: ready.length,
  entries: ready.map(({ id, sourceID, english, swedish }) => ({ id, sourceID, english, swedish })),
});
write('Resources/examples3000.json', ready.map(({ id, sentence, sentenceEnglish }) => ({ id, sentence, sentenceEnglish })));
write('Resources/starter100.json', ready.slice(0, 100).map((entry, order) => ({
  id: entry.id, sourceID: entry.sourceID, order, english: entry.english, swedish: entry.swedish,
  sentence: entry.sentence, sentenceEnglish: entry.sentenceEnglish, topic: entry.topic,
  symbol: 'text.book.closed', imageName: null, imageContainsText: false,
})));
write('Resources/artworkBriefs.json', Object.fromEntries(ready.map(({ id, prompt, memoryHook }) => [id, { prompt, memoryHook }])));
const images = [];
const bundledDirectory = path.join(root, 'Resources/BundledArtwork');
fs.mkdirSync(bundledDirectory, { recursive: true });
const previousImages = new Map((fs.existsSync(path.join(bundledDirectory, 'manifest.json'))
  ? read('Resources/BundledArtwork/manifest.json') : []).map(image => [image.wordID, image]));
const sha256 = file => createHash('sha256').update(fs.readFileSync(file)).digest('hex');
for (const entry of ready) {
  const asset = artwork[entry.id];
  if (!asset) continue;
  assert(asset.reviewed, `${entry.id}: artwork must be reviewed`);
  assert(asset.path.startsWith('Content/Artwork/') && !asset.path.includes('..'));
  const image = path.join(root, asset.path);
  assert(fs.existsSync(image), `${entry.id}: missing reviewed artwork`);
  // Preserve generated PNG masters; bundle full-resolution JPEG derivatives so
  // the growing collection remains below Android's 2 GB package-reader limit.
  const filename = `${entry.id}-r002.jpg`;
  const destination = path.join(bundledDirectory, filename);
  const masterSHA256 = sha256(image);
  const previous = previousImages.get(entry.id);
  if (!(previous?.filename === filename && previous.masterSHA256 === masterSHA256 &&
        previous.encoding === 'jpeg-quality-90' && fs.existsSync(destination) &&
        previous.bundleSHA256 === sha256(destination))) {
    execFileSync('/usr/bin/sips', ['-s', 'format', 'jpeg', '-s', 'formatOptions', '90', image, '--out', destination], { stdio: 'pipe' });
  }
  images.push({ wordID: entry.id, assetID: `${entry.id}-r002`, filename, thumbnailFilename: filename,
    memoryHook: entry.memoryHook, prompt: entry.prompt,
    encoding: 'jpeg-quality-90', masterSHA256, bundleSHA256: sha256(destination) });
}
write('Resources/BundledArtwork/manifest.json', images);
const bundledFilenames = new Set(images.map(image => image.filename));
for (const filename of fs.readdirSync(bundledDirectory)) {
  if (/^sv-\d{4}-r\d+\.(png|jpg)$/.test(filename) && !bundledFilenames.has(filename))
    fs.unlinkSync(path.join(bundledDirectory, filename));
}
write('Content/catalog.json', catalog);
write('Content/status.json', {
  target: 3000, authored: ready.length, artwork: images.length,
  linguisticReview: 'Authored draft; independent Swedish review pending.',
  sets: Object.fromEntries([...new Set(catalog.entries.map((entry) => entry.english[0].toUpperCase()))].map((letter) => {
    const set = catalog.entries.filter((entry) => entry.english[0].toUpperCase() === letter);
    return [letter, { total: set.length, authored: set.filter((entry) => entry.contentStatus !== 'pending').length, artwork: images.filter((image) => set.some((entry) => entry.id === image.wordID)).length }];
  })),
});
console.log(`Native resources: ${ready.length}/3000 Swedish words, ${images.length} images. Pending words are excluded from the app.`);
