export interface BossType {
    x: number;
    y: number;
    prevX?: number;
    prevY?: number;
    vx: number;
    vy: number;
    w: number;
    h: number;
    active: boolean;
    triggered: boolean;
    grid: number[][]; // 3x3 containing tile ID (0 = empty, 1 = dirt, 5 = bouncy)
    cooldown: number; // 3 secs = 180 frames key loop
    maxCooldown: number;
    state: 'suspended' | 'intro' | 'falling' | 'active' | 'jumping' | 'charging' | 'pre_jump';
    scaleX: number;
    scaleY: number;
    grounded: boolean;
    eatingProgress: number;
    dead: boolean;
    won: boolean;
    damageFlash: number;
    introTimer: number;
    comboCount: number;
    jumpType: 'normal' | 'big' | 'small' | 'precision' | 'combo' | 'mega';
    actionCount: number;
    chargeTimer: number;
    maxChargeTimer?: number;
    targetVx?: number;
    targetVy?: number;
    preJumpTimer?: number;
    maxPreJumpTimer?: number;
    minR?: number;
    minC?: number;
    maxR?: number;
    maxC?: number;
    centerR?: number;
    centerC?: number;
    rotationAngle?: number;
    jumpCount?: number;
    reorgTimer?: number;
    reorgAnimCells?: { fromR: number; fromC: number; toR: number; toC: number; val: number; startFrame?: number; endFrame?: number }[];
    hasInitialReorg?: boolean;
    hasInitializedReorgGrid?: boolean;
    durability?: number;
    maxDurability?: number;
    bouncesRemaining?: number;
    shields?: any[];
    dirtShotsFired?: number;
}

export interface Particle {
    x: number;
    y: number;
    prevX?: number;
    prevY?: number;
    vx: number;
    vy: number;
    life: number;
    maxLife: number;
    color: string;
    w: number;
}

export interface Projectile {
    x: number;
    y: number;
    prevX?: number;
    prevY?: number;
    vx: number;
    vy: number;
    w: number;
    h: number;
    dead: boolean;
    type: number;
    eatenCount: number; // For extra bounciness/impact
    bounceCount: number; // limit bounces
    isEnemy?: boolean; // Flag for enemy projectiles
}

export interface FallingBlock {
    x: number;
    y: number;
    prevX?: number;
    prevY?: number;
    vy: number;
    type: number;
    delay?: number;
    warningColor?: string;
}

export interface BgStar {
    x: number;
    y: number;
    size: number;
    speed: number;
    color: string;
}
