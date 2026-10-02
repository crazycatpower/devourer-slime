// Generates the golden-master traces used by godot/tests/parity.
//
// The web version's engine (src/components/GameCanvas.tsx) is loaded as-is,
// with its React component cut off and its browser dependencies stubbed, and
// driven tick by tick by a seeded bot. The recorded inputs and the state after
// every tick are written to godot/tests/parity/reference/*.json.gz; the Godot
// test replays the inputs through its own simulation and compares the states.
//
// The Godot port deliberately fixes a number of defects of the web version.
// Each fix that changes the simulation is mirrored here as a named entry in
// REFERENCE_PATCHES or HARNESS_FIXES, so the reference is "the web engine plus
// exactly these documented fixes" and nothing else.
//
// Usage (from the repository root):  node godot/tools/parity/make_reference.mjs

import { mkdirSync, readFileSync, readdirSync, rmSync, writeFileSync } from 'node:fs';
import { stripTypeScriptTypes } from 'node:module';
import { fileURLToPath } from 'node:url';
import { gzipSync } from 'node:zlib';

const repoRoot = new URL('../../../', import.meta.url);
const outDir = fileURLToPath(new URL('godot/tests/parity/reference/', repoRoot));

// --- Defect fixes applied to the web engine source ---------------------------

const REFERENCE_PATCHES = [
  {
    name: 'projectile-stops-at-boss',
    why: 'A block that hit a boss cell kept being processed against the level in the same tick, so one block could both feed the boss and land as a new tile.',
    find: /(if \(hitBossCell\) break;\s*\}\s*\}\s*\}\s*)(if \(r >= 0 && r < level\.length && c >= 0 && c < level\[0\]\.length\) \{\s*let cellType = level\[r\]\[c\];\s*if \(isSpike\(cellType\)\))/g,
    replace: '$1if (hit || p.deflected) break;\n            $2',
    count: 1,
  },
  {
    name: 'blocks-deflect-off-boss',
    why: 'A block that struck an occupied boss cell was given a bounce ("bounce off it!") and then removed anyway, while the World 4 boss really did bounce blocks it walked into. Both now bounce: the block stays in play. It is only lifted on top of the cell when the boss moved onto it, and a hit from underneath bounces back down instead of popping up through the body.',
    edits: [
      {
        find: /\/\/ Occupied cell: bounce off it!\s*p\.vx = -p\.vx \* 0\.8 \+ \(Math\.random\(\) - 0\.5\) \* 2;\s*p\.vy = -Math\.abs\(p\.vy\) \* 0\.8 - 1\.5;\s*p\.y = cellY - p\.h - 1;([\s\S]*?)hit = true;(\s*hitBossCell = true;)/g,
        replace:
          'p.vx = -p.vx * 0.8 + (Math.random() - 0.5) * 2;\n' +
          'if (p.y >= cellYB) p.vy = Math.abs(p.vy) * 0.8; else p.vy = -Math.abs(p.vy) * 0.8 - 1.5;\n' +
          'if (!(p.x + p.w <= cellX || p.x >= cellXR || p.y + p.h <= cellY || p.y >= cellYB)) p.y = cellY - p.h - 1;' +
          '$1p.deflected = true;$2',
        count: 1,
      },
      {
        find: /(let p = projectiles\[i\];\s*)(p\.vy \+= GRAVITY \* 0\.15;)/g,
        replace: '$1p.deflected = false;\n        $2',
        count: 1,
      },
    ],
  },
  {
    name: 'spit-block-never-pushes-into-walls',
    why: 'A block that settled on top of the player moved the player aside without checking the destination. In a one-tile tunnel or shaft that put the player inside the wall, and the collision code then carried them straight through it. When there is no room, the block now crumbles and the player stays put.',
    find: /(if \(playerOverlap\) \{)([\s\S]*?player\.y = cellB \+ 0\.1;\s*\}\s*\})(\s*\})/g,
    replace:
      '$1 const keepX = player.x, keepY = player.y;$2\n' +
      'if (getSolidAABBs(player.x, player.y, player.w, player.h).length > 0) { player.x = keepX; player.y = keepY; level[prevR][prevC] = 0; }$3',
    count: 1,
  },
  {
    name: 'jump-never-weakens-bounce',
    why: 'Pressing jump while landing on a bouncy block replaced the bounce with an ordinary jump: being within 24 units above a bouncy surface allowed a jump even while falling onto it, and a jump set the vertical speed outright even when the bounce was stronger. A jump now waits, buffered, until after the bounce and only fires if it adds speed.',
    edits: [
      {
        find: /if \(player\.jumpBuffer > 0 && player\.coyoteTimer > 0\) \{/g,
        replace: 'if (player.jumpBuffer > 0 && player.coyoteTimer > 0 && player.vy > -JUMP_FORCE) {',
        count: 1,
      },
      {
        find: /if \(player\.grounded \|\| nearBouncy\) \{/g,
        replace: 'if (player.grounded || (player.vy <= 0 && nearBouncy)) {',
        count: 1,
      },
    ],
  },
  {
    name: 'jump-timers-full-window',
    why: 'The jump buffer ("12 frames") and coyote time ("4 frames") were counted down before being read, so they really lasted 10 and 3 ticks. They now last what the comments say.',
    edits: [
      { find: /player\.jumpBuffer = 12;/g, replace: 'player.jumpBuffer = 13;', count: 1 },
      { find: /player\.coyoteTimer = 4;/g, replace: 'player.coyoteTimer = 5;', count: 1 },
    ],
  },
  {
    name: 'boss-leaps-account-for-ceiling',
    why: 'Bosses aimed their leaps with the free-flight time, but they stop rising at the arena ceiling, so high leaps came down early and covered only about half the intended distance. The flight time is now the one the leap will really have.',
    edits: [
      {
        find: /let flightTime = \(2 \* Math\.abs\(boss\.vy\)\) \/ 0\.25;/g,
        replace: 'let flightTime = leapFlightTicks(boss.y, Math.abs(boss.vy), 0.25);',
        count: 1,
      },
      {
        find: /let flightTime = \(2 \* Math\.abs\(boss\.targetVy \|\| 0\)\) \/ 0\.2;/g,
        replace: 'let flightTime = Math.max(1, leapFlightTicks(boss.y, Math.abs(boss.targetVy || 0), 0.2) - 1);',
        count: 1,
      },
    ],
  },
  {
    name: 'airborne-recoil-carries',
    why: 'The sideways kick of a spit ("strengthen horizontal recoil force!") lasted a single tick, because walking overwrites the horizontal speed every tick: 18 units sideways against 100 upward. In the air the kick now fades over several ticks; on the ground it is unchanged.',
    edits: [
      {
        find: /player\.vx -= nAimX \* RECOIL_FORCE \* 1\.8;/g,
        replace:
          '{ const kickX = -nAimX * RECOIL_FORCE * 1.8; player.vx += kickX; player.recoilVx = player.wallBounceTimer <= 0 ? kickX : 0; }',
        count: 1,
      },
      {
        find: /(\/\/ Gravity\s*player\.vy \+= GRAVITY;)/g,
        replace:
          'if (player.recoilVx !== 0) {\n' +
          '  if (player.wallBounceTimer > 0 || player.grounded) player.recoilVx = 0;\n' +
          '  else {\n' +
          '    player.recoilVx *= 0.85;\n' +
          '    if (Math.abs(player.recoilVx) < 0.1) player.recoilVx = 0;\n' +
          '    player.vx += player.recoilVx;\n' +
          '  }\n' +
          '}\n$1',
        count: 1,
      },
      {
        find: /(let isBouncyCollision = hitBouncy \|\| isPlayerBouncy;\s*let didBounce = false;\s*)(if \(p\.vx > 0\) \{)/g,
        replace: '$1p.recoilVx = 0;\n        $2',
        count: 1,
      },
      {
        find: /(player\.vx = 0;\s*)(player\.vy \+= 0\.4;)/g,
        replace: '$1player.recoilVx = 0;\n        $2',
        count: 1,
      },
    ],
  },
  {
    name: 'retry-shortens-boss-intro',
    why: 'Every retry of a boss fight replayed the whole entrance (up to three seconds) with the player frozen. After the first time it is cut to half a second.',
    find: /boss\.introTimer = (75|120|180);([^\n]*\n\s*boss\.triggered = true;)/g,
    replace: 'boss.introTimer = introTicks($1);$2',
    count: 4,
  },
  {
    name: 'boss-reentry-keeps-player-control',
    why: 'When the World 2 boss fell out and floated back in, the player was frozen for two seconds as during the opening entrance, in an arena that by then has holes in the floor. The player now keeps control.',
    edits: [
      {
        find: /(boss\.introTimer = 120;[^\n]*\n)(\s*camera\.shake = 30;)/g,
        replace: '$1                boss.reentered = true;\n$2',
        count: 1,
      },
      {
        find: /if \(boss\.active && boss\.state === 'intro'\) \{(\s*player\.vx = 0;)/g,
        replace: "if (boss.active && boss.state === 'intro' && !boss.reentered) {$1",
        count: 1,
      },
    ],
  },
  {
    name: 'drops-use-view-width',
    why: 'Boss block drops still used the pre-zoom canvas width (960) instead of the visible world width, so the right edge of the screen never received drops.',
    find: /camera\.x \+ 960/g,
    replace: 'camera.x + VIEW_WIDTH',
    count: 2,
  },
  {
    name: 'boss-right-edge-column',
    why: 'Bosses tested one column too many on their right side. Pressed against the right wall they "landed" on the wall itself and hung in mid-air.',
    find: /Math\.floor\(\(boss\.x \+ boss\.w\) \/ TILE_SIZE\)/g,
    replace: 'Math.floor((boss.x + boss.w - 0.001) / TILE_SIZE)',
    count: 11,
  },
  {
    name: 'slime-relaxes-during-boss-intro',
    why: 'While a boss made its entrance the player was frozen in whatever squashed shape it had at that moment; the squash now keeps easing out.',
    find: /(player\.inBulletTime = false;\s*solveY\(player\);\s*)(return;)/g,
    replace: '$1player.scaleX += (1 - player.scaleX) * 0.15; player.scaleY += (1 - player.scaleY) * 0.15;\n        $2',
    count: 1,
  },
  {
    name: 'no-win-while-dying',
    why: 'Touching a hazard and the goal in the same tick showed "level cleared" and then restarted the level.',
    find: /if \(goals\.length > 0 && !player\.won\) \{/g,
    replace: 'if (goals.length > 0 && !player.won && !player.dead) {',
    count: 1,
  },
];

// Fixes that live in the tick loop, which this harness re-implements because
// the original is inside the React component.
const HARNESS_FIXES = [
  {
    name: 'full-player-reset',
    why: 'Restarting a level kept grounded/coyote/wall-bounce/facing from the previous attempt.',
  },
  {
    name: 'absorbed-projectiles-removed',
    why: 'A block absorbed by the World 4 boss was flagged dead but kept flying.',
  },
  {
    name: 'camera-centres-small-levels',
    why: 'Levels narrower than the view were drawn flush left; the camera now centres them. It also follows the player centre from the first frame.',
  },
  {
    name: 'gameplay-clock',
    why: 'Date.now() drove gameplay (boss sway, shield orbit, pulses), ignoring pause and bullet time. It is replaced by the simulation clock.',
  },
  {
    name: 'fixed-tick',
    why: 'The web loop advanced once per display refresh, so game speed depended on the monitor. The harness runs exactly one tick per step.',
  },
];

// A patch is one edit ({ find, replace, count }) or several ({ edits: [...] }).
function applyPatches(source) {
  for (const patch of REFERENCE_PATCHES) {
    for (const edit of patch.edits ?? [patch]) {
      const matches = source.match(edit.find);
      const found = matches ? matches.length : 0;
      if (found !== edit.count) {
        throw new Error(`patch "${patch.name}": expected ${edit.count} match(es) of ${edit.find}, found ${found}`);
      }
      source = source.replace(edit.find, edit.replace);
    }
  }
  return source;
}

// --- Loading the web engine ---------------------------------------------------

function readSource(relPath) {
  return readFileSync(new URL(relPath, repoRoot), 'utf8').replace(/\r\n/g, '\n');
}

function stripModuleSyntax(source) {
  return source
    .replace(/^import[\s\S]*?from\s+['"][^'"]+['"];?[ \t]*$/gm, '')
    .replace(/^export\s+(default\s+)?/gm, '');
}

// Browser and audio dependencies of the engine, replaced by inert stand-ins.
// Math.hypot is replaced by the plain formula so both implementations perform
// bit-identical arithmetic; the two differ by at most one unit in the last place.
const PRELUDE = `
const Math = {};
for (const key of Object.getOwnPropertyNames(globalThis.Math)) Math[key] = globalThis.Math[key];
Math.random = env.random;
Math.hypot = (x, y) => globalThis.Math.sqrt(x * x + y * y);
const Date = { now: () => env.clock() };
const setTimeout = (fn) => fn();
const localStorage = { getItem: () => null, setItem: () => {} };
const sfxLog = [];
const SoundEffects = {
  init() {}, tickBgm() {}, stopBgm() {},
  playJump() { sfxLog.push(0); }, playEat() { sfxLog.push(1); }, playShoot() { sfxLog.push(2); },
  playBounce() { sfxLog.push(3); }, playHurt() { sfxLog.push(4); }, playWin() { sfxLog.push(5); },
  playLand() { sfxLog.push(6); }, playDevourPulse() { sfxLog.push(7); },
};
const SoundAPI = { isMuted: () => true };
const audioState = { isBoss: false, bossFilledCount: 0 };
`;

// Appended inside the engine's scope, so it can reach the engine's internals.
const HARNESS = `
const STATE_INDEX = { suspended: 0, intro: 1, falling: 2, active: 3, jumping: 4, charging: 5, pre_jump: 6 };
const BOSS_SLOTS = [10, 20, 30, 40];

function limitCamera(value, levelExtent, viewExtent) {
  if (levelExtent <= viewExtent) return (levelExtent - viewExtent) / 2;
  return Math.max(0, Math.min(value, levelExtent - viewExtent));
}

function cameraSnap() {
  const levelW = level[0].length * TILE_SIZE;
  const levelH = level.length * TILE_SIZE;
  camera.x = limitCamera(player.x + player.w / 2 - VIEW_WIDTH / 2, levelW, VIEW_WIDTH);
  camera.y = limitCamera(player.y + player.h / 2 - VIEW_HEIGHT / 2, levelH, VIEW_HEIGHT);
}

function cameraFollow() {
  const levelW = level[0].length * TILE_SIZE;
  const levelH = level.length * TILE_SIZE;
  camera.x += (player.x + player.w / 2 - VIEW_WIDTH / 2 - camera.x) * 0.1;
  camera.y += (player.y + player.h / 2 - VIEW_HEIGHT / 2 - camera.y) * 0.1;
  camera.x = limitCamera(camera.x, levelW, VIEW_WIDTH);
  camera.y = limitCamera(camera.y, levelH, VIEW_HEIGHT);
  if (camera.shake > 0.5) camera.shake *= 0.9; else camera.shake = 0;
}

function afterReset() {
  player.facing = 1;
  player.grounded = false;
  player.coyoteTimer = 0;
  player.wallBounceTimer = 0;
  player.recoilVx = 0;
  cameraSnap();
}

// Helpers called by the patched engine source (see REFERENCE_PATCHES).

// Mirrors BossSystem.leap_flight_ticks.
function leapFlightTicks(bossY, speed, gravity) {
  let y = bossY;
  let vy = -speed;
  let ticks = 0;
  while (ticks < 600) {
    ticks += 1;
    vy += gravity;
    y += vy;
    if (y < TILE_SIZE) {
      y = TILE_SIZE;
      if (vy < 0) vy = 0;
    }
    if (y >= bossY) break;
  }
  return ticks;
}

// Mirrors BossSystem.begin_intro.
let bossIntroSeen = false;
function introTicks(full) {
  const ticks = bossIntroSeen ? Math.min(full, 30) : full;
  bossIntroSeen = true;
  return ticks;
}

function setButton(code, down, wasDown) {
  if (down && !wasDown) physicsActionTriggers[code] = true;
  if (!down && wasDown) physicsActionReleaseTriggers[code] = true;
}

function hashCells(rows, width) {
  let h = 7;
  for (let r = 0; r < rows.length; r++) {
    for (let c = 0; c < width; c++) h = (h * 31 + (rows[r][c] ?? 0)) % 1000000007;
  }
  return h;
}

return {
  get player() { return player; },
  get boss() { return boss; },
  get level() { return level; },
  get camera() { return camera; },

  get projectiles() { return projectiles; },
  get fallingBlocks() { return fallingBlocks; },
  filledCount() { return boss.active ? getBossFilledCount() : 0; },
  isBossFilled() { return isBossFilled(); },

  start(slot) {
    bossIntroSeen = false;
    resetLevel(slot);
    afterReset();
  },

  // Test-only state edits that steer a run into code a clumsy bot would never
  // reach. The Godot test applies the same edits at the same ticks.
  intervene(op, value) {
    if (op === 'give_block') {
      if (!player.hasBlock) {
        player.hasBlock = true;
        player.carriedBlockType = value;
        player.carriedBlockEatenCount = 1;
        player.waitingForShootRelease = false;
      }
    } else if (op === 'boss_durability') {
      boss.durability = value;
    } else if (op === 'boss_eating_progress') {
      boss.eatingProgress = value / 100;
    } else if (op === 'boss_fill') {
      // Fill empty cells of a 3x3 boss until "value" cells are occupied.
      for (let r = 0; r < 3; r++) {
        for (let c = 0; c < 3; c++) {
          if (r === 1 && c === 1) continue;
          if (getBossFilledCount() >= value) return;
          if (boss.grid[r][c] === 0) boss.grid[r][c] = 12;
        }
      }
    } else if (op === 'boss_strip') {
      // Strip the World 1 boss down to its core.
      for (let r = 0; r < boss.grid.length; r++) {
        for (let c = 0; c < boss.grid.length; c++) {
          if (boss.grid[r][c] !== 3) boss.grid[r][c] = 0;
        }
      }
      updateWorld1BossBounds();
    } else {
      throw new Error('unknown intervention ' + op);
    }
  },

  // Undoes a death so a run can keep going ("immortal" scenarios). A player
  // who dropped out of the map is put back near the top-left corner.
  revive() {
    if (player.dead) {
      player.dead = false;
      deathTimer = 0;
    }
    if (player.y > level.length * TILE_SIZE) {
      player.x = TILE_SIZE * 2 + 3;
      player.y = TILE_SIZE * 2 + 3;
      player.vx = 0;
      player.vy = 0;
      player.recoilVx = 0;
      player.fallStartY = player.y;
    }
  },

  tick(inp) {
    setButton('KeyA', inp.left, keys.KeyA); keys.KeyA = inp.left;
    setButton('KeyD', inp.right, keys.KeyD); keys.KeyD = inp.right;
    setButton('KeyW', inp.jump, keys.KeyW); keys.KeyW = inp.jump;
    setButton('MouseLeft', inp.eat, mouse.leftDown); mouse.leftDown = inp.eat;
    setButton('MouseRight', inp.shoot, mouse.rightDown); mouse.rightDown = inp.shoot;
    mouse.x = inp.mx;
    mouse.y = inp.my;

    audioState.bossFilledCount = boss.active ? getBossFilledCount() : 0;
    player.prevX = player.x;
    player.prevY = player.y;

    if (!player.dead && !player.won) {
      updatePhysics();
      updateBossAndFallingBlocks();
    }
    projectiles = projectiles.filter((p) => !p.dead);
    updateProjectilesAndParticles();

    if (player.dead) {
      player.inBulletTime = false;
      deathTimer++;
      if (deathTimer > 75) {
        resetLevel();
        afterReset();
      }
    }
    if (player.won) player.inBulletTime = false;
    for (const k in physicsActionTriggers) physicsActionTriggers[k] = false;
    for (const k in physicsActionReleaseTriggers) physicsActionReleaseTriggers[k] = false;

    cameraFollow();
  },

  takeSfx() {
    const out = sfxLog.join('');
    sfxLog.length = 0;
    return out;
  },

  // Full detail of the moving parts, for diagnosing a parity failure.
  debugDump() {
    return {
      particles: particles.map((q) => [q.x, q.y, q.vx, q.vy, q.life, q.maxLife]),
      projectiles: projectiles.map((q) => [q.x, q.y, q.vx, q.vy, q.type, q.isEnemy ? 1 : 0]),
      fallingBlocks: fallingBlocks.map((q) => [q.x, q.y, q.vy, q.type, q.delay ?? 0]),
      boss: { x: boss.x, y: boss.y, vx: boss.vx, vy: boss.vy, state: boss.state, cooldown: boss.cooldown },
      player: { x: player.x, y: player.y, vx: player.vx, vy: player.vy, dead: player.dead },
    };
  },

  snapshot() {
    const p = player;
    const hasBoss = BOSS_SLOTS.includes(currentPlayingSlot);
    const b = boss;
    let projSum = 0;
    for (const q of projectiles) projSum += q.x + q.y + q.vx + q.vy;
    let partSum = 0;
    for (const q of particles) partSum += q.x + q.y;
    let fallSum = 0;
    for (const q of fallingBlocks) fallSum += q.x + q.y + (q.delay ?? 0);
    return [
      p.x, p.y, p.vx, p.vy,
      (p.grounded ? 1 : 0) | (p.dead ? 2 : 0) | (p.won ? 4 : 0) | (p.hasBlock ? 8 : 0)
        | (p.inBulletTime ? 16 : 0) | (p.isJumping ? 32 : 0) | (p.waitingForShootRelease ? 64 : 0)
        | (p.facing > 0 ? 128 : 0),
      p.carriedBlockType * 10 + p.carriedBlockEatenCount,
      p.eatingProgress, p.fallStartY,
      p.coyoteTimer + 100 * p.jumpBuffer + 10000 * p.wallBounceTimer,
      p.scaleX, p.scaleY,
      hasBoss ? (b.active ? 1 : 0) | (b.dead ? 2 : 0) | (b.grounded ? 4 : 0) : 0,
      hasBoss ? b.x : 0, hasBoss ? b.y : 0, hasBoss ? b.vx : 0, hasBoss ? b.vy : 0,
      hasBoss ? b.w : 0, hasBoss ? b.h : 0,
      hasBoss ? STATE_INDEX[b.state] : 0,
      hasBoss ? b.cooldown : 0,
      hasBoss ? hashCells(b.grid, b.grid.length) : 0,
      hasBoss ? b.eatingProgress : 0,
      hasBoss ? (b.durability ?? 3) : 0,
      hasBoss ? b.scaleX : 0, hasBoss ? b.scaleY : 0, hasBoss ? b.damageFlash : 0,
      hashCells(level, level[0].length),
      projectiles.length, projSum,
      particles.length, partSum,
      fallingBlocks.length, fallSum,
      camera.x, camera.y, camera.shake,
      deathTimer,
    ];
  },
};
`;

const FIELDS = [
  'player.x', 'player.y', 'player.vx', 'player.vy', 'player.flags', 'player.carried',
  'player.eating_progress', 'player.fall_start_y', 'player.timers', 'player.scale_x', 'player.scale_y',
  'boss.flags', 'boss.x', 'boss.y', 'boss.vx', 'boss.vy', 'boss.w', 'boss.h', 'boss.state',
  'boss.cooldown', 'boss.grid_hash', 'boss.eating_progress', 'boss.durability',
  'boss.scale_x', 'boss.scale_y', 'boss.damage_flash',
  'level.hash', 'projectiles.count', 'projectiles.sum', 'particles.count', 'particles.sum',
  'falling_blocks.count', 'falling_blocks.sum', 'camera.x', 'camera.y', 'camera.shake', 'death_timer',
];

function buildEngineFactory() {
  let canvas = readSource('src/components/GameCanvas.tsx');
  const cut = canvas.indexOf('// --- REACT COMPONENT ---');
  if (cut < 0) throw new Error('cannot find the React component marker in GameCanvas.tsx');
  canvas = canvas.slice(0, cut);
  const combined = [
    readSource('src/game/constants.ts'),
    readSource('src/game/default_levels.ts'),
    readSource('src/game/physicsUtils.ts'),
    canvas,
  ]
    .map(stripModuleSyntax)
    .join('\n');
  const js = stripTypeScriptTypes(applyPatches(combined));
  return new Function('env', `${PRELUDE}\n${js}\n${HARNESS}`);
}

// --- Random sources -----------------------------------------------------------

// Lehmer / MINSTD: identical to godot/src/core/sim/sim_random.gd.
function minstd(seed) {
  let state = seed % 2147483647;
  if (state <= 0) state += 2147483646;
  return () => {
    state = (state * 48271) % 2147483647;
    return state / 2147483647;
  };
}

// Only drives the bot, which exists on this side alone.
function mulberry32(seed) {
  let a = seed >>> 0;
  return () => {
    a = (a + 0x6d2b79f5) | 0;
    let t = Math.imul(a ^ (a >>> 15), 1 | a);
    t = (t + Math.imul(t ^ (t >>> 7), 61 | t)) ^ t;
    return ((t ^ (t >>> 14)) >>> 0) / 4294967296;
  };
}

// --- The bot -------------------------------------------------------------------

const TILE = 40;
const VIEW_W = 1040;
const VIEW_H = 585;
const EATABLE = new Set([1, 5, 11, 12, 15, 25]);

// Plays badly but busily: wanders toward the boss or the far side, jumps,
// swallows nearby blocks and spits them at things. Its only purpose is to push
// the engine through as many code paths as possible.
function makeBot(engine, seed, slot) {
  const rand = mulberry32(seed);
  const between = (lo, hi) => lo + Math.floor(rand() * (hi - lo + 1));
  let moveDir = 1;
  let moveTimer = 0;
  let jumpHold = 0;
  let eatHold = 0;
  let shootHold = 0;
  let aimTimer = 0;
  let mx = VIEW_W / 2;
  let my = VIEW_H / 2;

  function aimAtWorld(wx, wy) {
    const { camera } = engine;
    mx = Math.max(0, Math.min(VIEW_W, Math.round(wx - camera.x)));
    my = Math.max(0, Math.min(VIEW_H, Math.round(wy - camera.y)));
  }

  function nearestEatable() {
    const { player, level } = engine;
    const pc = Math.floor((player.x + 17) / TILE);
    const pr = Math.floor((player.y + 17) / TILE);
    let best = null;
    let bestDist = Infinity;
    for (let r = pr - 2; r <= pr + 2; r++) {
      for (let c = pc - 2; c <= pc + 2; c++) {
        if (r < 0 || r >= level.length || c < 0 || c >= level[0].length) continue;
        if (!EATABLE.has(level[r][c])) continue;
        const dist = Math.abs(r - pr) + Math.abs(c - pc);
        if (dist < bestDist) {
          bestDist = dist;
          best = [c * TILE + 20, r * TILE + 20];
        }
      }
    }
    return best;
  }

  function pickAim() {
    const { player, boss } = engine;
    const bossVisible = boss.active && !boss.dead && boss.state !== 'suspended';
    const roll = rand();
    if (!player.hasBlock) {
      const tile = nearestEatable();
      if (tile && roll < 0.6) return aimAtWorld(tile[0], tile[1]);
      if (bossVisible && roll < 0.8) return aimAtWorld(boss.x + boss.w / 2, boss.y + boss.h / 2);
    } else {
      if (bossVisible && roll < 0.55) {
        return aimAtWorld(boss.x + rand() * boss.w, boss.y + rand() * boss.h);
      }
      if (roll < 0.8) return aimAtWorld(player.x + between(-200, 200), player.y + between(20, 160));
    }
    mx = between(0, VIEW_W);
    my = between(0, VIEW_H);
    return undefined;
  }

  return function next() {
    const { player, boss, level } = engine;

    // A fully fed World 4 boss can be devoured: walk up to it and hold eat.
    if (slot === 40 && (engine.isBossFilled() || boss.eatingProgress > 0) && !player.hasBlock) {
      const bossX = boss.x + boss.w / 2;
      const bossY = boss.y + boss.h / 2;
      aimAtWorld(bossX, bossY);
      const dx = bossX - (player.x + 17);
      return {
        left: dx < -110, right: dx > 110, jump: bossY < player.y - 130 && rand() < 0.2,
        eat: true, shoot: false, mx, my,
      };
    }

    if (--moveTimer <= 0) {
      const targetX = boss.active ? boss.x + boss.w / 2 : level[0].length * TILE;
      const toward = targetX > player.x ? 1 : -1;
      const roll = rand();
      moveDir = roll < 0.55 ? toward : roll < 0.75 ? -toward : 0;
      moveTimer = between(8, 60);
    }
    if (jumpHold > 0) jumpHold--;
    else if (rand() < 0.04) jumpHold = between(2, 22);

    if (--aimTimer <= 0) {
      pickAim();
      aimTimer = between(12, 50);
    }

    let eat = false;
    let shoot = false;
    if (!player.hasBlock) {
      shootHold = 0;
      if (eatHold > 0) {
        eatHold--;
        eat = true;
      } else if (rand() < 0.1) eatHold = between(9, 40);
    } else {
      eatHold = 0;
      if (shootHold > 0) {
        shootHold--;
        shoot = true;
      } else if (rand() < 0.12) shootHold = between(2, 20);
    }
    return { left: moveDir < 0, right: moveDir > 0, jump: jumpHold > 0, eat, shoot, mx, my };
  };
}

// --- Scenarios ------------------------------------------------------------------

// Interventions at regular intervals, e.g. every(150, 4000, 'give_block', 1).
const every = (step, until, op, value) =>
  Array.from({ length: Math.floor(until / step) }, (_, i) => ({ tick: (i + 1) * step, op, value }));

const SCENARIOS = [
  // Every authored level and the placeholder room, played straight.
  ...[1, 2, 3, 4, 5, 6, 7, 8, 9, 11, 12, 13, 14, 15, 16, 17, 18, 19, 21, 22, 23].map((slot) => ({
    slot, seed: 1000 + slot, ticks: 600,
  })),
  // Hazard-heavy levels with an immortal player, to dwell on deaths and bounces.
  ...[14, 15, 16, 18, 19].map((slot) => ({ slot, seed: 1500 + slot, ticks: 1500, immortal: true })),
  // Boss fights as a mortal player: triggers, intros, deaths and restarts.
  ...[10, 20, 30, 40].flatMap((slot) => [
    { slot, seed: 2000 + slot, ticks: 1800 },
    { slot, seed: 3000 + slot, ticks: 1800 },
  ]),
  // Long immortal boss fights, steered into the late phases and the kills.
  {
    slot: 10, seed: 4010, ticks: 5000, immortal: true,
    interventions: [...every(300, 5000, 'give_block', 1), { tick: 4300, op: 'boss_strip', value: 0 }],
  },
  { slot: 10, seed: 5010, ticks: 4000, immortal: true, interventions: every(250, 4000, 'give_block', 5) },
  {
    slot: 20, seed: 4020, ticks: 6000, immortal: true,
    interventions: [...every(400, 6000, 'give_block', 1), { tick: 3000, op: 'boss_durability', value: 1 }],
  },
  { slot: 20, seed: 5020, ticks: 4000, immortal: true },
  { slot: 30, seed: 4030, ticks: 6000, immortal: true, interventions: every(120, 6000, 'give_block', 1) },
  { slot: 30, seed: 5030, ticks: 4000, immortal: true, interventions: every(90, 4000, 'give_block', 5) },
  {
    slot: 40, seed: 4040, ticks: 6000, immortal: true,
    interventions: [
      // No more blocks once the boss is full: the bot must be empty-mouthed to devour it.
      ...every(150, 4700, 'give_block', 1),
      { tick: 1500, op: 'boss_fill', value: 4 },
      { tick: 3000, op: 'boss_fill', value: 7 },
      { tick: 4800, op: 'boss_fill', value: 8 },
      // Keep the devouring going long enough for the bot to finish the boss.
      ...Array.from({ length: 24 }, (_, i) => ({ tick: 5000 + i * 30, op: 'boss_eating_progress', value: 60 })),
    ],
  },
  {
    slot: 40, seed: 5040, ticks: 5000, immortal: true,
    interventions: [...every(200, 5000, 'give_block', 5), { tick: 2500, op: 'boss_fill', value: 7 }],
  },
];

const round = (v) => (Number.isInteger(v) ? v : Math.round(v * 1e6) / 1e6);

// What a run exercised, so weak coverage is visible when traces are regenerated.
function makeCoverage() {
  return {
    bossStates: new Set(), jumpTypes: new Set(), deaths: 0, resets: 0, carried: 0, shots: 0,
    enemyShots: 0, fallingBlocks: 0, maxFilled: 0, minDurability: 3, reorgs: 0, devour: 0, bossDefeated: false,
  };
}

function observe(cov, engine, before) {
  const { player, boss } = engine;
  if (boss.active) {
    cov.bossStates.add(boss.state);
    if (boss.state === 'jumping' || boss.state === 'pre_jump') cov.jumpTypes.add(boss.jumpType);
    cov.maxFilled = Math.max(cov.maxFilled, engine.filledCount());
    cov.minDurability = Math.min(cov.minDurability, boss.durability ?? 3);
    cov.devour = Math.max(cov.devour, boss.eatingProgress);
    if ((boss.reorgTimer ?? 0) > 0 && !(before.reorgTimer > 0)) cov.reorgs += 1;
  }
  if (!boss.active && boss.dead && before.bossActive) cov.bossDefeated = true;
  if (player.dead && !before.dead) cov.deaths += 1;
  if (player.hasBlock && !before.hasBlock) cov.carried += 1;
  if (engine.projectiles.some((p) => p.isEnemy)) cov.enemyShots += 1;
  if (engine.projectiles.some((p) => !p.isEnemy)) cov.shots += 1;
  cov.fallingBlocks = Math.max(cov.fallingBlocks, engine.fallingBlocks.length);
}

function runScenario(factory, scenario, dumpTick = 0) {
  let tickIndex = 0;
  let random = minstd(1);
  let drawCount = 0;
  const recentDraws = [];
  const env = {
    random: () => {
      drawCount += 1;
      return random();
    },
    clock: () => (tickIndex * 1000) / 60,
  };
  const engine = factory(env);
  random = minstd(scenario.seed);
  drawCount = 0;
  engine.start(scenario.slot);
  engine.takeSfx();

  const bot = makeBot(engine, scenario.seed * 7 + 13, scenario.slot);
  const inputs = [];
  const states = [];
  const sfx = [];
  const coverage = makeCoverage();
  const interventions = scenario.interventions ?? [];
  for (let i = 0; i < scenario.ticks; i++) {
    for (const item of interventions) {
      if (item.tick === i + 1) engine.intervene(item.op, item.value);
    }
    const before = {
      dead: engine.player.dead, hasBlock: engine.player.hasBlock,
      bossActive: engine.boss.active, reorgTimer: engine.boss.reorgTimer ?? 0,
    };
    const inp = bot();
    tickIndex += 1;
    engine.tick(inp);
    observe(coverage, engine, before);
    if (scenario.immortal) engine.revive();
    inputs.push([
      (inp.left ? 1 : 0) | (inp.right ? 2 : 0) | (inp.jump ? 4 : 0) | (inp.eat ? 8 : 0) | (inp.shoot ? 16 : 0),
      inp.mx,
      inp.my,
    ]);
    states.push(engine.snapshot().map(round));
    sfx.push(engine.takeSfx());
    if (process.argv.includes('--probe') && tickIndex % 100 === 0) {
      const { player: p, boss: b } = engine;
      console.log(
        `t=${tickIndex} filled=${engine.filledCount()} full=${engine.isBossFilled()} boss=${b.state}` +
          ` devour=${b.eatingProgress.toFixed(2)} dx=${Math.round(b.x + b.w / 2 - p.x - 17)} dy=${Math.round(b.y + b.h / 2 - p.y - 17)}` +
          ` block=${p.hasBlock} eat=${inp.eat} dead=${p.dead}`,
      );
    }
    if (dumpTick > 0 && tickIndex > dumpTick - 12) recentDraws.push(drawCount);
    if (tickIndex === dumpTick) {
      // "draws": cumulative random draws after each of the last 12 ticks.
      console.log(JSON.stringify({ draws: recentDraws, ...engine.debugDump() }));
      break;
    }
  }
  return { inputs, states, sfx, engine, coverage };
}

const scenarioName = (scenario) => `slot${String(scenario.slot).padStart(2, '0')}_seed${scenario.seed}`;

function main() {
  const factory = buildEngineFactory();

  // node make_reference.mjs --dump <scenario name> <tick>: print one tick's detail.
  const dumpAt = process.argv.indexOf('--dump');
  if (dumpAt >= 0) {
    const scenario = SCENARIOS.find((s) => scenarioName(s) === process.argv[dumpAt + 1]);
    if (!scenario) throw new Error(`unknown scenario ${process.argv[dumpAt + 1]}`);
    runScenario(factory, scenario, Number(process.argv[dumpAt + 2]));
    return;
  }

  rmSync(outDir, { recursive: true, force: true });
  mkdirSync(outDir, { recursive: true });

  let totalBytes = 0;
  for (const scenario of SCENARIOS) {
    const name = scenarioName(scenario);
    const { inputs, states, sfx, engine, coverage: cov } = runScenario(factory, scenario);
    const sounds = sfx.join('').length;
    const payload = {
      format: 1,
      name,
      slot: scenario.slot,
      seed: scenario.seed,
      ticks: scenario.ticks,
      immortal: Boolean(scenario.immortal),
      interventions: scenario.interventions ?? [],
      fields: FIELDS,
      patches: [...REFERENCE_PATCHES, ...HARNESS_FIXES].map((p) => p.name),
      inputs,
      states,
      sfx,
    };
    const bytes = gzipSync(Buffer.from(JSON.stringify(payload)), { level: 9 });
    writeFileSync(`${outDir}${name}.json.gz`, bytes);
    totalBytes += bytes.length;
    const isBoss = [10, 20, 30, 40].includes(scenario.slot);
    console.log(
      `${name.padEnd(20)} ${String(scenario.ticks).padStart(4)}t ${String(Math.round(bytes.length / 1024)).padStart(4)}KB` +
        ` sfx=${String(sounds).padEnd(4)} deaths=${String(cov.deaths).padEnd(4)} eaten=${String(cov.carried).padEnd(3)}` +
        ` won=${engine.player.won ? 'y' : 'n'}` +
        (isBoss
          ? ` | boss ${cov.bossDefeated ? 'DEFEATED' : 'alive'} states=[${[...cov.bossStates].join(',')}]` +
            ` jumps=[${[...cov.jumpTypes].join(',')}] filled<=${cov.maxFilled} dur>=${cov.minDurability}` +
            ` reorgs=${cov.reorgs} devour=${cov.devour.toFixed(2)} enemyShotTicks=${cov.enemyShots} falling<=${cov.fallingBlocks}`
          : ''),
    );
  }
  console.log(`\nWrote ${readdirSync(outDir).length} traces to ${outDir} (${(totalBytes / 1024 / 1024).toFixed(2)} MB)`);
}

main();
