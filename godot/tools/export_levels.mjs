// Generates godot/data/levels/official_levels.json from the web version's
// level constants. The layouts are copied character for character; this
// script never edits, repairs or invents level data.
//
// Usage (from the repository root):  node godot/tools/export_levels.mjs

import { mkdirSync, readFileSync, writeFileSync } from 'node:fs';
import { stripTypeScriptTypes } from 'node:module';
import { dirname } from 'node:path';
import { fileURLToPath } from 'node:url';

const repoRoot = new URL('../../', import.meta.url);
const outPath = fileURLToPath(new URL('godot/data/levels/official_levels.json', repoRoot));

function loadTsModule(relPath, exportNames) {
  const source = readFileSync(new URL(relPath, repoRoot), 'utf8')
    .replace(/^import[\s\S]*?from\s+['"][^'"]+['"];?[ \t]*$/gm, '')
    .replace(/^export\s+/gm, '');
  const js = stripTypeScriptTypes(source);
  return new Function(`${js}\nreturn { ${exportNames.join(', ')} };`)();
}

const { DEFAULT_LEVEL_DATA, BIG_WORLD_DEFAULT, BOSS_LEVEL_DATA } = loadTsModule(
  'src/game/constants.ts',
  ['DEFAULT_LEVEL_DATA', 'BIG_WORLD_DEFAULT', 'BOSS_LEVEL_DATA'],
);
const { OFFICIAL_LEVEL_FALLBACKS } = loadTsModule('src/game/default_levels.ts', [
  'OFFICIAL_LEVEL_FALLBACKS',
]);

const KNOWN_CHARS = new Set('.@#~^>v<$*XOP');

// Reports oddities for the designer's attention. Nothing is changed.
function inspect(label, rows) {
  const notes = [];
  const width = rows[0].length;
  rows.forEach((row, r) => {
    if (row.length !== width) notes.push(`row ${r} is ${row.length} wide, expected ${width}`);
    for (const ch of row) if (!KNOWN_CHARS.has(ch)) notes.push(`row ${r} has unknown char "${ch}"`);
  });
  const starts = rows.join('').split('P').length - 1;
  if (starts !== 1) notes.push(`${starts} player start markers`);
  const goals = rows.join('').split('$').length - 1;
  console.log(
    `${label.padEnd(18)} ${String(width).padStart(3)} x ${String(rows.length).padEnd(3)} goals=${goals}` +
      (notes.length ? `   NOTE: ${notes.join('; ')}` : ''),
  );
}

const slots = {};
for (const key of Object.keys(OFFICIAL_LEVEL_FALLBACKS).sort((a, b) => Number(a) - Number(b))) {
  slots[key] = OFFICIAL_LEVEL_FALLBACKS[key];
  inspect(`slot ${key}`, slots[key]);
}
inspect('default_level', DEFAULT_LEVEL_DATA);
inspect('boss_level', BOSS_LEVEL_DATA);
inspect('big_world_default', BIG_WORLD_DEFAULT);

const output = {
  format: 1,
  generated_by: 'godot/tools/export_levels.mjs',
  source: ['src/game/constants.ts', 'src/game/default_levels.ts'],
  notice: 'Generated file. Level layouts are copied verbatim from the web version; do not edit by hand.',
  default_level: DEFAULT_LEVEL_DATA,
  boss_level: BOSS_LEVEL_DATA,
  big_world_default: BIG_WORLD_DEFAULT,
  slots,
};

mkdirSync(dirname(outPath), { recursive: true });
writeFileSync(outPath, `${JSON.stringify(output, null, 2)}\n`);
console.log(`\nWrote ${outPath} (${Object.keys(slots).length} authored slots)`);
