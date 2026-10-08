// Fourth-world layouts explicitly commissioned by the user, October 2026.
// Adheres strictly to the 7 golden rules:
// 1. Material lifecycle tracking (obtain -> 1st use -> retrieve -> 2nd use -> consume/digest).
// 2. Interdependent routing (bridge dismantling, void-clearing digestion, unblocking shafts).
// 3. Going vs returning verification (empty-handed vs burdened 80% speed).
// 4. Decoupled puzzle and execution (standard 3-tile jumps, 1-tile gap headbonks, apex recoil).
// 5. Short-circuit prevention & valid alternatives.
// 6. Fail-fast design with short retry loops.
// 7. Visual readability (all upward spikes mounted on steel floor, clear sightlines <= 65px).

import {writeFileSync} from 'node:fs';

const slots = {}, solutions = {};

function room(slot, width, height) {
  const a = Array.from({length: height}, (_, r) =>
    Array.from({length: width}, (_, c) =>
      r === 0 || r === height - 1 || c === 0 || c === width - 1 ? '@' : '.'
    )
  );
  const route = [];
  const put = (r, c, ch) => { a[r][c] = ch; };
  const floor = (r, c1, c2, ch = '@') => {
    for (let c = c1; c <= c2; c++) {
      for (let y = r; y < height - 1; y++) put(y, c, ch);
    }
  };
  const ceiling = (r, c1, c2, ch = '@') => {
    for (let c = c1; c <= c2; c++) put(r, c, ch);
  };
  const walk = c => route.push({op: 'walk', x: c * 40 + 3});
  const jump = c => route.push({op: 'jump', x: c * 40 + 3});
  const recoil_jump = c => route.push({op: 'recoil_jump', x: c * 40 + 3});
  const eat = (r, c) => route.push({op: 'eat', r, c});
  const shoot = (r, c) => route.push({op: 'shoot', r, c});
  const finish = () => {
    slots[slot] = a.map(r => r.join(''));
    solutions[slot] = route;
  };
  return {a, put, floor, ceiling, walk, jump, recoil_jump, eat, shoot, finish, route, width, height};
}

// ==========================================
// 5-1 (41): 初試虛空
// ==========================================
{
  const l = room(41, 26, 15);
  l.floor(13, 1, 9);
  l.put(13, 10, 'O');
  l.put(13, 11, 'O');
  l.floor(13, 12, 24);
  l.ceiling(10, 8, 13);
  l.put(12, 2, 'P');
  l.put(12, 5, '#');
  l.put(12, 23, '$');

  l.walk(4);
  l.eat(12, 5);
  l.walk(8);
  l.shoot(13, 10);
  l.walk(23);
  l.finish();
}

// ==========================================
// 5-2 (42): 負重不渡
// ==========================================
{
  const l = room(42, 28, 16);
  // Left ledge at row 13..14
  l.floor(13, 1, 8);
  l.put(12, 2, '$');
  l.put(12, 3, 'X');
  l.put(12, 4, 'P');
  l.put(12, 6, '#');

  // Pit at c=9..13: spikes at row 14, steel base at row 15
  for (let c = 9; c <= 13; c++) {
    l.put(14, c, '~');
  }
  l.put(13, 11, 'O');

  // Right ledge at row 13..14, c=14..26
  l.floor(13, 14, 26);
  l.put(12, 19, '#');

  l.walk(5.5);
  l.eat(12, 6);
  l.walk(7.5);
  l.shoot(13, 11);
  l.walk(8);
  l.jump(11);
  l.jump(16);
  l.walk(18);
  l.eat(12, 19);
  l.walk(14.2);
  l.jump(11);
  l.jump(8);
  l.walk(5.5);
  l.shoot(12, 3);
  l.walk(2);
  l.finish();
}

// ==========================================
// 5-3 (43): 彈力接力
// ==========================================
{
  const l = room(43, 28, 16);
  // Left high platform: row 10, c=1..6
  for (let c = 1; c <= 6; c++) {
    for (let r = 10; r <= 14; r++) l.put(r, c, '@');
  }
  l.put(9, 2, 'P');
  l.put(9, 5, '*');

  // Pit at c=7..10: spikes at row 14, steel base at row 15
  for (let c = 7; c <= 10; c++) {
    l.put(14, c, '~');
  }
  l.put(13, 8, 'O');

  // Right high tower: row 8, c=11..24
  for (let c = 11; c <= 24; c++) {
    for (let r = 8; r <= 14; r++) l.put(r, c, '@');
  }
  l.put(7, 22, '$');

  l.walk(4);
  l.eat(9, 5);
  l.walk(6);
  l.shoot(13, 8);
  l.walk(6);
  l.jump(15);
  l.walk(22);
  l.finish();
}

// ==========================================
// 5-4 (44): 隔空拆遷
// ==========================================
{
  const l = room(44, 30, 16);
  // Entrance: c=1..6, row 13..14
  l.floor(13, 1, 6);
  l.put(12, 2, 'P');
  l.put(12, 4, '#');

  // Gap 1: c=7..8: spikes at row 14
  l.put(14, 7, '~');
  l.put(14, 8, '~');
  l.ceiling(10, 5, 9);

  // Central island: c=9..12, row 13..14
  l.floor(13, 9, 12);

  // Gap 2: c=13..14: void at (13, 13), spike at (14, 14)
  l.put(13, 13, 'O');
  l.put(14, 14, '~');
  l.ceiling(10, 12, 16);

  // Exit platform: c=15..28, row 13..14
  l.floor(13, 15, 28);
  l.put(12, 26, '$');

  l.walk(3);
  l.eat(12, 4);
  l.walk(6);
  l.shoot(13, 8);
  l.walk(6);
  l.jump(10);
  l.walk(9.5);
  l.eat(13, 8);
  l.walk(12);
  l.shoot(13, 13);
  l.walk(13.2);
  l.jump(16);
  l.walk(26);
  l.finish();
}

// ==========================================
// 5-5 (45): 穿與填的抉擇
// ==========================================
{
  const l = room(45, 30, 16);
  // Ground floor: c=1..12, row 13..14
  l.floor(13, 1, 12);
  l.put(12, 2, 'P');
  l.put(12, 4, '#');

  // Upper shelf at row 9, c=7..11
  for (let c = 7; c <= 11; c++) {
    for (let r = 9; r <= 10; r++) l.put(r, c, '@');
  }
  l.put(8, 9, '#');

  // Wall barrier at c=13 from row 1 to 10
  for (let r = 1; r <= 10; r++) l.put(r, 13, '@');
  // Glass wall in corridor at c=13, r=12 only
  l.put(12, 13, 'X');

  // Void pit at c=15, spike at c=16
  l.put(13, 14, '@');
  l.put(13, 15, 'O');
  l.put(14, 16, '~');

  // Exit platform: c=17..28, row 13..14
  l.floor(13, 17, 28);
  l.put(12, 26, '$');

  l.walk(3);
  l.eat(12, 4);
  l.walk(5);
  l.shoot(10, 7);
  l.walk(5.5);
  l.jump(7);
  l.jump(8.5);
  l.walk(9);
  l.eat(8, 9);
  l.walk(11);
  l.shoot(12, 13);
  l.walk(5.5);
  l.eat(11, 7);
  l.walk(14);
  l.shoot(13, 15);
  l.walk(15.2);
  l.jump(18);
  l.walk(26);
  l.finish();
}

// ==========================================
// 5-6 (46): 消化與開路
// ==========================================
{
  const l = room(46, 28, 16);
  // High entrance platform: c=1..6, row 9..14
  for (let c = 1; c <= 6; c++) {
    for (let r = 9; r <= 14; r++) l.put(r, c, '@');
  }
  l.put(8, 2, 'P');
  l.put(8, 4, '#');

  // Shaft at c=7, ceiling at (7, 7)
  l.put(7, 7, '@');
  l.put(8, 7, 'O');

  // Wall at c=8 from row 1 to 10 (leaving archway at r=11..12)
  for (let r = 1; r <= 10; r++) l.put(r, 8, '@');

  // Lower chamber: c=7..17, row 13..14
  l.floor(13, 7, 17);
  l.put(12, 14, '#');

  // Void pit at c=18, spike at c=19
  l.put(13, 18, 'O');
  l.put(14, 19, '~');

  // Exit platform: c=20..26, row 13..14
  l.floor(13, 20, 26);
  l.put(12, 24, '$');

  l.walk(3);
  l.eat(8, 4);
  l.walk(5.5);
  l.shoot(8, 7);
  l.walk(6);
  l.eat(8, 7);
  l.walk(7.2);
  l.walk(13.5);
  l.eat(12, 14);
  l.walk(17);
  l.shoot(13, 18);
  l.walk(18.2);
  l.jump(21);
  l.walk(24);
  l.finish();
}

// ==========================================
// 5-7 (47): 拆路補高
// ==========================================
{
  const l = room(47, 30, 16);
  // Central Hub: c=7..15, row 10..14
  for (let c = 7; c <= 15; c++) {
    for (let r = 10; r <= 14; r++) l.put(r, c, '@');
  }
  l.put(9, 8, 'P');
  l.put(9, 10, '#');

  // Lower branch: c=1..5, row 10..14
  for (let c = 1; c <= 5; c++) {
    for (let r = 10; r <= 14; r++) l.put(r, c, '@');
  }
  l.put(9, 2, '#');
  // 1-tile gap at c=6: spikes at row 14
  l.put(14, 6, '~');

  // Upper platform: c=16..28, row 7..14
  for (let c = 16; c <= 28; c++) {
    for (let r = 7; r <= 14; r++) l.put(r, c, '@');
  }
  // Shaft at c=16: wall above at r=1..4, Void at (8, 16)
  for (let r = 1; r <= 4; r++) l.put(r, 16, '@');
  l.put(8, 16, 'O');

  // Glass and Goal on Upper platform
  l.put(6, 23, 'X');
  l.put(6, 26, '$');

  l.walk(9.5);
  l.eat(9, 10);
  l.walk(14);
  l.shoot(8, 16);
  l.walk(15);
  l.eat(8, 16);
  l.walk(8);
  l.jump(4);
  l.walk(2);
  l.eat(9, 2);
  l.walk(4);
  l.jump(8);
  l.walk(14.5);
  l.jump(18);
  l.walk(21);
  l.shoot(6, 23);
  l.walk(26);
  l.finish();
}

// ==========================================
// 5-8 (48): 頂點借力
// ==========================================
{
  const l = room(48, 28, 16);
  // Launch ledge at row 12..14, c=1..8
  for (let c = 1; c <= 8; c++) {
    for (let r = 12; r <= 14; r++) l.put(r, c, '@');
  }
  l.put(11, 2, 'P');
  l.put(11, 5, '#');

  // Deep pit at c=9..11: spikes at row 14, steel base at row 15
  for (let c = 9; c <= 11; c++) {
    l.put(14, c, '~');
  }
  l.put(13, 10, 'O');

  // High target platform at row 7..14, c=12..26
  for (let c = 12; c <= 26; c++) {
    for (let r = 7; r <= 14; r++) l.put(r, c, '@');
  }
  l.put(6, 15, '#');
  l.put(6, 18, 'X');
  l.put(6, 22, '$');

  l.walk(4);
  l.eat(11, 5);
  l.walk(8);
  l.recoil_jump(13);
  l.walk(14);
  l.eat(6, 15);
  l.walk(17);
  l.shoot(6, 18);
  l.walk(22);
  l.finish();
}

// ==========================================
// 5-9 (49): 虛空迴廊
// ==========================================
{
  const l = room(49, 32, 16);
  // High entrance tier: row 8..14, c=1..6
  for (let c = 1; c <= 6; c++) {
    for (let r = 8; r <= 14; r++) l.put(r, c, '@');
  }
  l.put(7, 2, 'P');
  l.put(7, 4, '#');

  // Vertical shaft at c=7: ceiling at (6, 7), blocked at (7, 7) by Void
  l.put(6, 7, '@');
  l.put(7, 7, 'O');

  // Wall at c=8 from row 1 to 10 (leaving archway at r=11..12)
  for (let r = 1; r <= 10; r++) l.put(r, 8, '@');

  // Lower chamber: row 13..14, c=7..13
  l.floor(13, 7, 13);
  l.put(12, 11, '*');

  // Pit at c=14..16: void at (13, 14), spikes at (14, 15..16)
  l.put(13, 14, 'O');
  l.put(14, 15, '~');
  l.put(14, 16, '~');

  // Upper plateau at row 8..14, c=17..30
  for (let c = 17; c <= 30; c++) {
    for (let r = 8; r <= 14; r++) l.put(r, c, '@');
  }
  l.put(7, 20, '#');
  l.put(7, 24, 'X');
  l.put(7, 28, '$');

  l.walk(3);
  l.eat(7, 4);
  l.walk(5.5);
  l.shoot(7, 7);
  l.walk(6);
  l.eat(7, 7);
  l.walk(7.2);
  l.walk(10.5);
  l.eat(12, 11);
  l.walk(12.5);
  l.shoot(13, 14);
  l.walk(12.5);
  l.jump(18);
  l.walk(19);
  l.eat(7, 20);
  l.walk(22);
  l.shoot(7, 24);
  l.walk(28);
  l.finish();
}

writeFileSync(new URL('../data/levels/world5_levels.json', import.meta.url), JSON.stringify({format: 1, slots}, null, 2) + '\n');
writeFileSync(new URL('../tests/fixtures/world5_solutions.json', import.meta.url), JSON.stringify(solutions, null, 2) + '\n');
