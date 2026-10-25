import assert from 'node:assert/strict';
import fs from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';
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
for (const entry of ready) {
  const asset = artwork[entry.id];
  if (!asset) continue;
  assert(asset.reviewed, `${entry.id}: artwork must be reviewed`);
  assert(asset.path.startsWith('Content/Artwork/') && !asset.path.includes('..'));
  const image = path.join(root, asset.path);
  assert(fs.existsSync(image), `${entry.id}: missing reviewed artwork`);
  const filename = `${entry.id}-r001.png`;
  const destination = path.join(root, 'Resources/BundledArtwork', filename);
  fs.mkdirSync(path.dirname(destination), { recursive: true });
  fs.copyFileSync(image, destination);
  images.push({ wordID: entry.id, assetID: `${entry.id}-r001`, filename, thumbnailFilename: filename, memoryHook: entry.memoryHook, prompt: entry.prompt });
}
write('Resources/BundledArtwork/manifest.json', images);
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
