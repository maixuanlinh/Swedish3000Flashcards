import assert from 'node:assert/strict';
import fs from 'node:fs';
import path from 'node:path';
import { createHash } from 'node:crypto';
import { fileURLToPath } from 'node:url';

const root = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '..');
const input = path.resolve(root, process.argv[2] ?? '');
assert(input.startsWith(root + path.sep) && input.endsWith('.json'), 'Provide a project-local batch JSON');
const batch = JSON.parse(fs.readFileSync(input, 'utf8'));
const catalog = JSON.parse(fs.readFileSync(path.join(root, 'Content/catalog.json'), 'utf8'));
const manifestPath = path.join(root, 'Content/artwork.json');
const manifest = JSON.parse(fs.readFileSync(manifestPath, 'utf8'));
const hash = (file) => createHash('sha256').update(fs.readFileSync(file)).digest('hex');
for (const item of batch) {
  const card = catalog.entries.find((entry) => entry.id === item.id);
  assert(card && card.contentStatus !== 'pending', 'Only authored cards may be imported');
  assert(item.reviewed === true && item.prompt?.trim(), 'Visual review and exact prompt required');
  const source = path.resolve(item.source);
  assert(source.includes('/.codex/generated_images/') && source.endsWith('.png') && fs.existsSync(source));
  const relative = `Content/Artwork/${item.id}.png`;
  const target = path.join(root, relative);
  if (fs.existsSync(target)) assert.equal(hash(target), hash(source), 'Keep existing asset; save revisions under a new filename');
  else fs.copyFileSync(source, target);
  const metadata = {
    id: item.id, english: card.english, swedish: card.swedish,
    generationMode: 'built-in', prompt: item.prompt,
    referenceImage: 'Content/Artwork/sv-0001.png', sourceFile: source,
    artwork: relative, sha256: hash(target),
    review: { heading: true, englishMeaning: true, swedishExample: true, memoryCaption: true, status: 'visually-reviewed' },
  };
  fs.writeFileSync(path.join(root, `Content/Generations/${item.id}.json`), JSON.stringify(metadata, null, 2) + '\n');
  manifest[item.id] = { path: relative, reviewed: true };
}
fs.writeFileSync(manifestPath, JSON.stringify(manifest, null, 2) + '\n');
console.log(`Imported ${batch.length} reviewed cards; artwork coverage ${Object.keys(manifest).length}/211 A cards.`);
