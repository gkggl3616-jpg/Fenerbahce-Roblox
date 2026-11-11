// Maç kaydı üretir:  node tests/replay.mjs <tohum> <saniye> <çıktı.json>
import { LuauState } from 'luau-web';
import { readFileSync, writeFileSync } from 'node:fs';
import { dirname, join } from 'node:path';
import { fileURLToPath } from 'node:url';
const root = process.env.FK_ROOT || join(dirname(fileURLToPath(import.meta.url)), '..');
const [seed = '1', seconds = '16', outFile = ''] = process.argv.slice(2);
let st, summary = '';
const env = {
  print: () => {},
  __seed: Number(seed), __seconds: Number(seconds),
  __readFile: (p) => readFileSync(join(root, p), 'utf8'),
  __compile: (src, name) => { const fn = st.loadstring(src, name, false); if (typeof fn === 'string') throw new Error(name + ': ' + fn); return fn; },
  __fail: (msg) => { console.log('HATA: ' + String(msg).slice(0, 300)); },
  __emit: (sum, frames) => { summary = sum; if (outFile) writeFileSync(outFile, frames); },
};
st = await LuauState.createAsync(env);
for (const f of ['tests/prelude.luau', 'tests/replay.luau']) {
  const fn = st.loadstring(readFileSync(join(root, f), 'utf8'), f, false);
  if (typeof fn === 'string') { console.log('Derleme hatası ' + f + ': ' + fn); process.exit(1); }
  await fn();
}
console.log(summary);
process.exit(0);
