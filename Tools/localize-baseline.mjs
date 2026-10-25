// One-time mechanical localization of the copied native baseline.
import fs from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';
const root = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '..');
const replacements = [
  ['com.linapps.ykiflashcards', 'com.linapps.swedish3000'],
  ['com.finnishcards.SisuCards', 'com.linapps.swedish3000.personal'],
  ['fi-FI', 'sv-SE'], ['en-US', 'en-GB'],
  ['Finnish', 'Swedish'], ['finnish', 'swedish'], ['FINNISH', 'SWEDISH'],
  ['fi-', 'sv-'], ['SISUCARDS', 'SWEDISHCARDS'], ['SisuCards', 'SwedishCards'],
  ['SisuApplication', 'SwedishApplication'], ['Sisu Cards', 'Swedish Cards'],
  ['sisu-cards', 'swedish-cards'], ['sisu-progress', 'swedish-progress'],
  ['HYLÄTÄ', 'ÖVERGE'], ['hylätä', 'överge'], ['kyky', 'förmåga'], ['omena', 'ett äpple'],
  ['Omena on punainen.', 'Jag äter ett äpple.'],
];
function walk(dir) {
  for (const name of fs.readdirSync(dir)) {
    const file = path.join(dir, name);
    if (file === fileURLToPath(import.meta.url)) continue;
    if (fs.statSync(file).isDirectory()) walk(file);
    else if (/\.(swift|kt|kts|xml|yml|md|py|storekit|properties)$/.test(name)) {
      let text = fs.readFileSync(file, 'utf8');
      for (const [from, to] of replacements) text = text.replaceAll(from, to);
      fs.writeFileSync(file, text);
    }
  }
}
walk(root);
for (const sourceSet of ['main', 'test', 'androidTest']) {
  const from = path.join(root, 'Android/app/src', sourceSet, 'java/com/linapps/ykiflashcards');
  if (fs.existsSync(from)) fs.renameSync(from, path.join(path.dirname(from), 'swedish3000'));
}
for (const [from, to] of [['Sources/SisuCardsApp.swift', 'Sources/SwedishCardsApp.swift'], ['Android/app/src/main/java/com/linapps/swedish3000/SisuApplication.kt', 'Android/app/src/main/java/com/linapps/swedish3000/SwedishApplication.kt'], ['StoreKit/SisuCards.storekit', 'StoreKit/SwedishCards.storekit']]) {
  fs.renameSync(path.join(root, from), path.join(root, to));
}
