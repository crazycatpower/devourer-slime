import { describe, it } from 'node:test';
import assert from 'node:assert/strict';

import { getBossPhaseInfo, getBossPattern } from './bossAi';

describe('bossAi', () => {
  it('starts in early pressure phase with slow attack cadence', () => {
    const phase = getBossPhaseInfo(3);
    assert.equal(phase.phase, 'pressure');
    assert.ok(phase.cooldownFrames > 90);
    assert.ok(phase.fallPattern.length >= 2);
  });

  it('raises into frenzy phase and increases burst intensity', () => {
    const phase = getBossPhaseInfo(9);
    assert.equal(phase.phase, 'frenzy');
    assert.ok(phase.jumpVelocity < -8.5);
    assert.ok(phase.fallingBlockBurst >= 4);
    assert.ok(phase.voidChance >= 0.2);
  });

  it('uses a consistent attack pattern for the same filled count', () => {
    const patternA = getBossPattern(6);
    const patternB = getBossPattern(6);
    assert.deepEqual(patternA, patternB);
  });
});
