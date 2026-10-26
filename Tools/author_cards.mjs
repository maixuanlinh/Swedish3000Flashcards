import fs from 'node:fs';
import path from 'node:path';
import assert from 'node:assert/strict';
import { fileURLToPath } from 'node:url';

const root = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '..');
const input = path.resolve(root, process.argv[2] ?? '');
assert(input.startsWith(path.join(root, 'Content') + path.sep) && input.endsWith('-cards.txt'));
const catalogPath = path.join(root, 'Content/catalog.json');
const catalog = JSON.parse(fs.readFileSync(catalogPath, 'utf8'));
const rows = fs.readFileSync(input, 'utf8').trim().split('\n');
const seen = new Set();
for (const line of rows) {
  const fields = line.split('|');
  assert.equal(fields.length, 6, 'Expected source ID, Swedish, example, translation, memory hook, scene');
  const [source, swedish, sentence, sentenceEnglish, memoryHook, scene] = fields;
  const sourceID = Number(source);
  assert(!seen.has(sourceID)); seen.add(sourceID);
  const entry = catalog.entries.find(e => e.sourceID === sourceID);
  assert(entry && entry.contentStatus === 'pending', 'Only author pending entries');
  assert(fields.every(f => f.trim()));
  const prompt = `Use case: scientific-educational. Create ONE finished square Swedish vocabulary artwork for an adult mobile flashcard app. Use the Finnish iOS card style: vivid tactile realistic editorial illustration, memorable scale and clear action, warm light, cream header with fine gold edging, bold navy typography, integrated cream/gold memory-link caption, pale blue bottom example strip. One strong central scene occupies about two thirds. All supplied teaching text MUST be rendered INSIDE the image. Preserve Swedish å, ä, ö and every letter exactly. Generous margins, phone-legible text. No watermark, logo, app chrome, contact sheet, or unsupplied paragraphs. Sound/spelling associations are memory aids, never pronunciation or etymological claims.\nHeader text verbatim: ${JSON.stringify(swedish)}. Smaller English meaning verbatim: ${JSON.stringify(entry.english)}.\nScene: ${scene}\nMemory-link caption verbatim: ${JSON.stringify(memoryHook)}.\nSwedish example in bottom strip verbatim: ${JSON.stringify(sentence)}.\nTeach only the sense shown by this sentence. Print only the supplied heading, English meaning, memory caption and Swedish example. If the caption contains a sound/spelling association, mark it with the small exact label "Memory trick".`;
  Object.assign(entry, { order: sourceID, swedish, sentence, sentenceEnglish, topic: 'Vocabulary', memoryHook, scene, prompt, contentStatus: 'authored-draft', artworkStatus: 'pending', artwork: null, generationMode: 'built-in' });
}
fs.writeFileSync(catalogPath, JSON.stringify(catalog, null, 2) + '\n');
console.log(`Authored ${rows.length} draft cards from ${path.basename(input)}.`);
