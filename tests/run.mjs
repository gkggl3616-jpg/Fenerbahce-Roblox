// Sınamaları çalıştırır:  node tests/run.mjs   (önce: npm i luau-web)
import { LuauState } from 'luau-web';
import { readFileSync } from 'node:fs';
import { dirname, join } from 'node:path';
import { fileURLToPath } from 'node:url';

const root = join(dirname(fileURLToPath(import.meta.url)), '..');
let failed = false;
let st;
const env = {
  print: (...a) => console.log(...a),
  __readFile: (p) => readFileSync(join(root, p), 'utf8'),
  __compile: (src, name) => {
    const fn = st.loadstring(src, name, false);
    if (typeof fn === 'string') throw new Error('Derleme hatası ' + name + ': ' + fn);
    return fn;
  },
  __fail: (msg) => { failed = true; console.log('HATA: ' + msg); },
};
st = await LuauState.createAsync(env);
for (const f of ['tests/prelude.luau', 'tests/spec.luau']) {
  const fn = st.loadstring(readFileSync(join(root, f), 'utf8'), f, false);
  if (typeof fn === 'string') { console.log('Derleme hatası ' + f + ': ' + fn); process.exit(1); }
  try { await fn(); } catch (e) { failed = true; console.log('ÇÖKME ' + f + ': ' + (e && e.message || e)); }
}
process.exit(failed ? 1 : 0);
