import { useEffect, useRef } from 'react';
import { 
    TILE_SIZE, CAMERA_ZOOM, VIEW_WIDTH, VIEW_HEIGHT, 
    GRAVITY, JUMP_FORCE, MOVE_ACCEL, MAX_SPEED, RECOIL_FORCE, BULLET_SPEED,
    DEFAULT_LEVEL_DATA, BIG_WORLD_DEFAULT, BOSS_LEVEL_DATA 
} from '../game/constants';
import { OFFICIAL_LEVEL_FALLBACKS } from '../game/default_levels';

// --- GAME CONSTANTS ---


export type ControlBindings = {
    up: string;
    down: string;
    left: string;
    right: string;
    jump: string;
    restart: string;
    eat: string;
    shoot: string;
};

let customControls: ControlBindings = {
    up: 'KeyW',
    down: 'KeyS',
    left: 'KeyA',
    right: 'KeyD',
    jump: 'KeyW',
    restart: 'KeyR',
    eat: 'MouseLeft',
    shoot: 'MouseRight'
};

try {
    const saved = localStorage.getItem('slime_controls');
    if (saved) customControls = { ...customControls, ...JSON.parse(saved) };
} catch(e) {}

export const GameAPI = {
    setEditMode: (v: boolean) => { editState.active = v; },
    setBrush: (b: string) => { mouse.brush = b; },
    saveLevel: () => saveLevel(),
    clearLevel: () => clearLevel(),
    getMapSize: () => ({ cols: (level && level[0]) ? level[0].length : 40, rows: level ? level.length : 15 }),
    resizeLevel: (cols: number, rows: number) => resizeLevel(cols, rows),
    setGameSpeed: (speed: number) => { gameSpeed = Math.max(0.1, Math.min(speed, 5)); },
    getGameSpeed: () => gameSpeed,
    setPaused: (paused: boolean) => { isPaused = paused; },
    isPaused: () => isPaused,
    getControls: () => customControls,
    setControls: (controls: ControlBindings) => {
        customControls = { ...controls };
        localStorage.setItem('slime_controls', JSON.stringify(customControls));
    },
    setBulletTimeEnabled: (enabled: boolean) => {
        bulletTimeFeatureEnabled = enabled;
        localStorage.setItem('slime_bullet_time', JSON.stringify(enabled));
    },
    getBulletTimeEnabled: () => bulletTimeFeatureEnabled
};

let gameSpeed = 1.0;
let tickAccumulator = 0;
let smoothBulletTimeSpeed = 1.0;
let isPaused = false;
let bulletTimeFeatureEnabled = true;

try {
    const savedBulletTime = localStorage.getItem('slime_bullet_time');
    if (savedBulletTime !== null) bulletTimeFeatureEnabled = JSON.parse(savedBulletTime);
} catch(e) {}


let mouse = { x: 0, y: 0, leftDown: false, rightDown: false, rightClicked: false, brush: 'Dirt', leftDownFrames: 0, prevLeftDown: false, prevRightDown: false, leftClicked: false };
const editState = { active: false };
let previousBrushBeforeRightClick: string | null = null;
let currentPlayingSlot = 1;
let editorClipboard: number[][] | null = null;
let editorSelectionStart: {c: number, r: number} | null = null;
let editorSelectionCurrent: {c: number, r: number} | null = null;

// --- LEVEL DATA ---
// . = Air
// # = Dirt (Eatable)
// @ = Steel (Indestructible)
// ~ = Spikes
// $ = Goal
// P = Player Start


import { SoundAPI, SoundEffects, audioState } from '../game/audio';

// --- PARALLAX BACKGROUND SPAWNS ---
const bgStars: BgStar[] = [];
for (let i = 0; i < 60; i++) {
    bgStars.push({
        x: Math.random() * 5000,
        y: Math.random() * 2000,
        size: Math.random() * 3 + 1.2,
        speed: Math.random() * 0.15 + 0.05,
        color: ['#1e293b', '#334155', '#475569', '#38bdf8', '#34d399'][Math.floor(Math.random() * 5)] + '77'
    });
}

// --- GAME STATE ---
let level: number[][] = [];
let camera = { x: 0, y: 0, shake: 0 };
let projectiles: Projectile[] = [];
let particles: Particle[] = [];
let deathTimer = 0;

let player = {
    x: 0, y: 0, vx: 0, vy: 0,
    w: 34, h: 34,
    facing: 1, // 1 or -1
    hasBlock: false,
    carriedBlockType: 0,
    carriedBlockEatenCount: 0,
    eatingProgress: 0,
    eatingTarget: null as { r: number, c: number, isBossCell?: boolean } | null,
    inBulletTime: false,
    waitingForShootRelease: false,
    dead: false,
    won: false,
    grounded: false,
    jumpBuffer: 0,
    coyoteTimer: 0,
    scaleX: 1, scaleY: 1,
    isJumping: false,
    fallStartY: 0,
    wallBounceTimer: 0
};

import { BossType, FallingBlock, BgStar, Particle, Projectile } from '../game/types';

import { isSolid, isEatable, isSpike, isBouncy, checkSpikeCollision } from '../game/physicsUtils';

let boss: BossType = {
    x: 0, y: 0, vx: 0, vy: 0, w: 120, h: 120,
    active: false, triggered: false,
    grid: [
        [0, 0, 0],
        [0, 3, 0], // Center is 3 (Goal Core)
        [0, 0, 0]
    ],
    cooldown: 120,
    maxCooldown: 120,
    state: 'suspended',
    scaleX: 1, scaleY: 1,
    grounded: false,
    eatingProgress: 0,
    dead: false,
    won: false,
    damageFlash: 0,
    introTimer: 0,
    comboCount: 0,
    jumpType: 'normal',
    actionCount: 0,
    chargeTimer: 0
};

let fallingBlocks: FallingBlock[] = [];

// Visual interpolation variables for Boss animation smoothing
let bossVisualScaleX = 1;
let bossVisualScaleY = 1;
let bossVisualEyeX = 0;
let bossVisualEyeY = -10;
let bossVisualTilt = 0;

function damageCellAt(row: number, col: number) {
    if (row < 0 || row >= level.length || col < 0 || col >= level[0].length) return;
    let blockType = level[row][col];
    if (blockType <= 0 || blockType === 2) return; // empty, out of bounds, or indestructible

    let nextType = blockType;
    let shouldBreak = false;

    if (blockType === 6) {
        // Breakable Glass shatters instantly
        shouldBreak = true;
    } else if (blockType === 1) {
        nextType = 11; // Dirt eaten 1 time
    } else if (blockType === 11) {
        nextType = 12; // Dirt eaten 2 times
    } else if (blockType === 12) {
        shouldBreak = true;
    } else if (blockType === 5) {
        nextType = 15; // Bouncy eaten 1 time
    } else if (blockType === 15) {
        nextType = 25; // Bouncy eaten 2 times
    } else if (blockType === 25) {
        shouldBreak = true;
    }

    let cx = col * TILE_SIZE + TILE_SIZE / 2;
    let cy = row * TILE_SIZE + TILE_SIZE / 2;

    if (shouldBreak) {
        level[row][col] = 0;
        let color = '#d97706';
        if (blockType === 5 || blockType === 25 || blockType === 15) color = '#ec4899';
        else if (blockType === 6) color = '#06b6d4';
        
        spawnParticles(cx, cy, color, 25, 6);
        camera.shake = Math.max(camera.shake, 14);
        SoundEffects.playBounce(); // Play shattering-like sound impact
    } else {
        level[row][col] = nextType;
        let color = '#d97706';
        if (blockType === 5 || blockType === 25 || blockType === 15) color = '#ec4899';
        else if (blockType === 6) color = '#06b6d4';
        
        spawnParticles(cx, cy, color, 12, 3);
        camera.shake = Math.max(camera.shake, 6);
    }
}

function damageTileUnderBoss(rFloor: number) {
    if (!boss || boss.state === 'suspended') return;
    
    let startCol = Math.floor((boss.x - TILE_SIZE / 2) / TILE_SIZE);
    let endCol = Math.floor((boss.x + boss.w + TILE_SIZE / 2 - 1) / TILE_SIZE);
    
    let checkCols = [];
    for (let c = startCol; c <= endCol; c++) {
        checkCols.push(c);
    }
    
    let uniqueCols = Array.from(new Set(checkCols));

    for (let col of uniqueCols) {
        if (rFloor >= 0 && rFloor < level.length && col >= 0 && col < level[0].length) {
            let blockType = level[rFloor][col];
            if (blockType > 0 && blockType !== 2 && isSolid(blockType)) {
                damageCellAt(rFloor, col);
            }
        }
    }
}

function isSolidOrBoundary(r: number, c: number): boolean {
    if (r < 0 || c < 0 || c >= level[0].length) return true;
    if (r >= level.length) return false;
    return isSolid(level[r][c]);
}

const keys: Record<string, boolean> = {
    KeyW: false, KeyA: false, KeyS: false, KeyD: false,
    ArrowUp: false, ArrowDown: false, ArrowLeft: false, ArrowRight: false,
    Space: false, KeyR: false
};
const prevKeys: Record<string, boolean> = { ...keys };
const physicsActionTriggers: Record<string, boolean> = {};
const visualActionTriggers: Record<string, boolean> = {};
const physicsActionReleaseTriggers: Record<string, boolean> = {};
const visualActionReleaseTriggers: Record<string, boolean> = {};

const isActionDown = (action: keyof ControlBindings) => {
    const code = customControls[action];
    if (code === 'MouseLeft') return mouse.leftDown;
    if (code === 'MouseRight') return mouse.rightDown;
    return keys[code] === true;
};
const isActionJustPressed = (action: keyof ControlBindings) => {
    const code = customControls[action];
    if (!code) return false;
    return !!physicsActionTriggers[code];
};
const isActionJustPressedVisual = (action: keyof ControlBindings) => {
    const code = customControls[action];
    if (!code) return false;
    return !!visualActionTriggers[code];
};
const isActionJustReleased = (action: keyof ControlBindings) => {
    const code = customControls[action];
    if (!code) return false;
    return !!physicsActionReleaseTriggers[code];
};
const isActionJustReleasedVisual = (action: keyof ControlBindings) => {
    const code = customControls[action];
    if (!code) return false;
    return !!visualActionReleaseTriggers[code];
};

// --- HELPERS ---
function encodeLevel() {
    let rows = [];
    let pxC = Math.floor((player.x + player.w/2) / TILE_SIZE);
    let pxR = Math.floor((player.y + player.h/2) / TILE_SIZE);
    for(let r=0; r<level.length; r++) {
        let rowStr = '';
        for(let c=0; c<level[0].length; c++) {
            if (r === pxR && c === pxC) rowStr += 'P';
            else {
                let t = level[r][c];
                if (t === 0) rowStr += '.';
                else if (t === 1 || t === 11 || t === 12) rowStr += '#';
                else if (t === 2) rowStr += '@';
                else if (t === 3) rowStr += '$';
                else if (t === 4) rowStr += '~';
                else if (t === 41) rowStr += '>';
                else if (t === 42) rowStr += 'v';
                else if (t === 43) rowStr += '<';
                else if (t === 5 || t === 15 || t === 25) rowStr += '*';
                else if (t === 6) rowStr += 'X';
                else if (t === 7) rowStr += 'O';
            }
        }
        rows.push(rowStr);
    }
    return rows;
}

function saveLevel() {
    let rows = encodeLevel();
    localStorage.setItem(`slime_maker_level_${currentPlayingSlot}`, JSON.stringify(rows));
}

function clearLevel() {
    for(let r=0; r<level.length; r++) {
        for(let c=0; c<level[0].length; c++) {
            if (r===0 || r===level.length-1 || c===0 || c===level[0].length-1) level[r][c] = 2;
            else level[r][c] = 0;
        }
    }
}

function resizeLevel(newCols: number, newRows: number) {
    if (newCols < 10 || newRows < 10 || newCols > 200 || newRows > 120) return;
    let oldRows = level.length;
    let oldCols = level[0] ? level[0].length : 0;
    
    let newLevel: number[][] = [];
    for (let r = 0; r < newRows; r++) {
        let row = [];
        for (let c = 0; c < newCols; c++) {
            let isBorder = r === 0 || r === newRows - 1 || c === 0 || c === newCols - 1;
            
            if (isBorder) {
                row.push(2); // Steel border (@)
            } else if (r < oldRows - 1 && c < oldCols - 1 && r > 0 && c > 0) {
                row.push(level[r][c]); // Copy old
            } else {
                row.push(0); // Empty air
            }
        }
        newLevel.push(row);
    }
    
    level = newLevel;
    
    // Maintain players within valid indoor region
    let px = Math.floor((player.x + player.w / 2) / TILE_SIZE);
    let py = Math.floor((player.y + player.h / 2) / TILE_SIZE);
    
    if (px <= 0 || px >= newCols - 1 || py <= 0 || py >= newRows - 1) {
        let found = false;
        for (let r = 1; r < newRows - 1; r++) {
            for (let c = 1; c < newCols - 1; c++) {
                if (level[r][c] === 0) {
                    player.x = c * TILE_SIZE + 3;
                    player.y = r * TILE_SIZE + 3;
                    player.fallStartY = player.y;
                    player.vx = 0;
                    player.vy = 0;
                    found = true;
                    break;
                }
            }
            if (found) break;
        }
        if (!found) {
            player.x = TILE_SIZE + 3;
            player.y = TILE_SIZE + 3;
            player.fallStartY = player.y;
            player.vx = 0;
            player.vy = 0;
        }
    }
}



function parseLevel(slot: number) {
    let saved = localStorage.getItem(`slime_maker_level_${slot}`);
    let mapData;
    if (saved) {
        mapData = JSON.parse(saved);
    } else if (OFFICIAL_LEVEL_FALLBACKS[slot]) {
        mapData = OFFICIAL_LEVEL_FALLBACKS[slot];
    } else {
        mapData = (slot === 10 || slot === 40 || slot === 20 || slot === 30) ? BOSS_LEVEL_DATA : DEFAULT_LEVEL_DATA;
    }
    let lvl = [];
    let startX = 0; let startY = 0;
    for (let r = 0; r < mapData.length; r++) {
        let row = [];
        for (let c = 0; c < mapData[r].length; c++) {
            let ch = mapData[r][c];
            if (ch === '@') row.push(2);
            else if (ch === '#') row.push(1);
            else if (ch === '~' || ch === '^') row.push(4);
            else if (ch === '>') row.push(41);
            else if (ch === 'v') row.push(42);
            else if (ch === '<') row.push(43);
            else if (ch === '$') row.push(3);
            else if (ch === '*') row.push(5);
            else if (ch === 'X') row.push(6);
            else if (ch === 'O') row.push(7);
            else if (ch === 'P') { row.push(0); startX = c * TILE_SIZE + 3; startY = r * TILE_SIZE + 3; }
            else row.push(0);
        }
        lvl.push(row);
    }
    if (slot === 10) {
        // Place exactly 24 dirt blocks (8 columns * 3 rows) centered at column 24
        for (let r = 11; r <= 13; r++) {
            for (let c = 21; c <= 28; c++) {
                if (lvl[r]) {
                    lvl[r][c] = 1; // Dirt block
                }
            }
        }
    }
    return { lvl, startX, startY };
}

function resetLevel(slot: number = currentPlayingSlot) {
    currentPlayingSlot = slot;
    audioState.isBoss = (currentPlayingSlot === 10 || currentPlayingSlot === 40 || currentPlayingSlot === 20 || currentPlayingSlot === 30);
    let { lvl, startX, startY } = parseLevel(slot);
    level = lvl;
    player.x = startX;
    player.y = startY;
    (player as any).prevX = startX;
    (player as any).prevY = startY;
    player.vx = 0;
    player.vy = 0;
    player.hasBlock = false;
    player.inBulletTime = false;
    smoothBulletTimeSpeed = 1.0;
    player.waitingForShootRelease = false;
    player.carriedBlockType = 0;
    player.carriedBlockEatenCount = 0;
    player.eatingProgress = 0;
    player.eatingTarget = null;
    player.dead = false;
    player.won = false;
    player.jumpBuffer = 0;
    player.scaleX = 1;
    player.scaleY = 1;
    player.isJumping = false;
    player.fallStartY = startY;
    
    projectiles = [];
    particles = [];
    camera.shake = 0;
    camera.x = Math.max(0, Math.min(startX - VIEW_WIDTH / 2, level[0].length * TILE_SIZE - VIEW_WIDTH));
    if (level.length * TILE_SIZE > VIEW_HEIGHT) {
        camera.y = Math.max(0, Math.min(startY - VIEW_HEIGHT / 2, level.length * TILE_SIZE - VIEW_HEIGHT));
    } else {
        camera.y = 0;
    }
    deathTimer = 0;

    // Boss initialization context
    if (slot === 10 || slot === 40 || slot === 20 || slot === 30) {
        let isW1 = slot === 10;
        let isW2 = slot === 20;
        let isW3 = slot === 30;
        let wGrid: number[][] = [];
        if (isW1) {
            let gridSize = 21;
            let center = 10;
            for (let r = 0; r < gridSize; r++) {
                let rowArray = [];
                for (let c = 0; c < gridSize; c++) {
                    if (r === center && c === center) {
                        rowArray.push(3); // Goal Core
                    } else {
                        rowArray.push(0); // Empty initially (1x1 size)
                    }
                }
                wGrid.push(rowArray);
            }
        }

        boss = {
            x: 24 * TILE_SIZE, // Spawns near top middle (col 24)
            y: -150, // Starts suspended high above screen
            prevX: 24 * TILE_SIZE,
            prevY: -150,
            vx: 0,
            vy: 0,
            w: isW1 ? TILE_SIZE : 120, // 3x3 size for W2/52, 120px for W3, 1x1 initial for W1
            h: isW1 ? TILE_SIZE : 120,
            active: true,
            triggered: false,
            grid: isW2 ? [
                [5, 5, 5],
                [5, 3, 5],
                [5, 5, 5]
            ] : (isW1 ? wGrid : [
                [0, 0, 0],
                [0, 3, 0], // Center is 3 (Goal Core)
                [0, 0, 0]
            ]),
            cooldown: 120,
            maxCooldown: 120,
            state: 'suspended',
            scaleX: 1,
            scaleY: 1,
            grounded: false,
            eatingProgress: 0,
            dead: false,
            won: false,
            damageFlash: 0,
            introTimer: 0,
            comboCount: 0,
            jumpType: 'normal',
            actionCount: 0,
            chargeTimer: 0,
            durability: (isW2 || isW3) ? 3 : undefined,
            maxDurability: (isW2 || isW3) ? 3 : undefined,
            bouncesRemaining: isW2 ? 0 : undefined,
            shields: isW3 ? Array(4).fill(null).map((_, idx) => ({
                active: true,
                state: 'orbit',
                angleOffset: (idx * 2 * Math.PI) / 4,
                radius: 85,
                detachingTimer: 0,
                cx: 0,
                cy: 0
            })) : undefined
        };
        if (isW1) {
            boss.minR = 10;
            boss.minC = 10;
            boss.maxR = 10;
            boss.maxC = 10;
            boss.centerR = 10;
            boss.centerC = 10;
            boss.rotationAngle = 0;
            boss.hasInitialReorg = false;
            boss.hasInitializedReorgGrid = false;
        }
        bossVisualScaleX = 1;
        bossVisualScaleY = 1;
        bossVisualEyeX = 0;
        bossVisualEyeY = -10;
        bossVisualTilt = 0;
        fallingBlocks = [];
    } else {
        boss.active = false;
        boss.dead = true;
        fallingBlocks = [];
    }
}

function spawnParticles(x: number, y: number, color: string, count: number, speed: number) {
    for (let i = 0; i < count; i++) {
        particles.push({
            x, y,
            vx: (Math.random() - 0.5) * speed * 2,
            vy: (Math.random() - 0.5) * speed * 2,
            life: 1, maxLife: Math.random() * 20 + 10,
            color, w: Math.random() * 4 + 4
        });
    }
}

function isBossFilled(): boolean {
    if (!boss.active || boss.dead) return false;
    for (let r = 0; r < 3; r++) {
        for (let c = 0; c < 3; c++) {
            if (r === 1 && c === 1) continue; // Skip center Goal core
            if (boss.grid[r][c] === 0) return false;
        }
    }
    return true;
}

function getBossFilledCount(): number {
    if (!boss.active) return 0;
    let count = 0;
    let isLevel10 = currentPlayingSlot === 10;
    let size = isLevel10 ? boss.grid.length : 3;
    let centerR = isLevel10 ? (boss.centerR ?? 10) : 1;
    let centerC = isLevel10 ? (boss.centerC ?? 10) : 1;
    for (let r = 0; r < size; r++) {
        for (let c = 0; c < size; c++) {
            if (r === centerR && c === centerC) continue; // Skip center Goal core
            if (boss.grid[r] && boss.grid[r][c] !== 0) count++;
        }
    }
    return count;
}

function getEatTargetOfBoss(): boolean {
    if (currentPlayingSlot === 20) return false; // Shield blocks eating
    if (!boss.active || boss.dead) return false;
    if (boss.reorgTimer && boss.reorgTimer > 0) return false;
    let px = player.x + player.w / 2;
    let py = player.y + player.h / 2;
    let mx = mouse.x + camera.x;
    let my = mouse.y + camera.y;
    
    let aimX = mx - px;
    let aimY = my - py;
    let mag = Math.hypot(aimX, aimY);
    if (mag === 0) return false;
    
    let nAimX = aimX / mag;
    let nAimY = aimY / mag;
    
    for (let i = 1; i <= 30; i++) {
        let f = i / 30;
        let tx = px + nAimX * (150 * f);
        let ty = py + nAimY * (150 * f);
        
        if (tx >= boss.x && tx <= boss.x + boss.w && ty >= boss.y && ty <= boss.y + boss.h) {
            return true;
        }
    }
    return false;
}

function triggerMegaPatternedDrop() {
    let cols = level[0]?.length || 40;
    let playerCol = Math.floor((player.x + player.w/2) / TILE_SIZE);
    
    // Choose one of the 4 patterns:
    // 0: Dirt (1), 1: Bouncy (5), 2: Glass (6), 3: Void (7)
    let patternIndex = Math.floor(Math.random() * 4);
    
    // Sizing/cols based on screen visible area, with a bit of padding to look epic
    let minCol = Math.max(1, Math.floor((camera.x - 60) / TILE_SIZE));
    let maxCol = Math.min(cols - 2, Math.ceil((camera.x + 960 + 60) / TILE_SIZE));
    
    for (let c = minCol; c <= maxCol; c++) {
        let bType = 1;
        let warningColor = '#d97706';
        let shouldDrop = false;
        
        switch (patternIndex) {
            case 0: // 泥土 1格有一格空 (type 1, alternate columns)
                bType = 1;
                warningColor = '#d97706';
                if (c % 2 === 0) {
                    shouldDrop = true;
                }
                break;
            case 1: // 彈力 4格有4格空 (type 5, alternating groups of 4)
                bType = 5;
                warningColor = '#ec4899';
                if (Math.floor(c / 4) % 2 === 0) {
                    shouldDrop = true;
                }
                break;
            case 2: // 玻璃 玩家頭頂五格外全部 (type 6)
                bType = 6;
                warningColor = '#38bdf8';
                if (c < playerCol - 2 || c > playerCol + 2) {
                    shouldDrop = true;
                }
                break;
            case 3: // 虛空 玩家頭頂五格 (type 7)
                bType = 7;
                warningColor = '#a855f7';
                if (c >= playerCol - 2 && c <= playerCol + 2) {
                    shouldDrop = true;
                }
                break;
        }
        
        if (shouldDrop) {
            fallingBlocks.push({
                x: c * TILE_SIZE + TILE_SIZE / 2,
                y: -40,
                vy: 2,
                type: bType,
                delay: 45, // 45 frames delay brings extreme anticipation
                warningColor: warningColor
            });
            // Spawn warning dust particles dropping from the ceiling
            spawnParticles(c * TILE_SIZE + TILE_SIZE / 2, 20, warningColor, 10, 3.0);
        }
    }
}

function killWorld1BossAndRevealGoal() {
    boss.dead = true;
    boss.active = false;
    camera.shake = 30;
    SoundEffects.playHurt();
    setTimeout(() => {
        try { SoundEffects.playWin(); } catch(e){}
    }, 100);
    
    spawnParticles(boss.x + boss.w/2, boss.y + boss.h/2, '#d97706', 40, 8); // amber orange colors
    spawnParticles(boss.x + boss.w/2, boss.y + boss.h/2, '#fbbf24', 40, 8);
    spawnParticles(boss.x + boss.w/2, boss.y + boss.h/2, '#34d399', 40, 8);
    
    let goalCol = Math.floor((boss.x + boss.w/2) / TILE_SIZE);
    let goalRow = Math.floor((boss.y + boss.h/2) / TILE_SIZE);
    goalCol = Math.max(1, Math.min(level[0].length - 2, goalCol));
    goalRow = Math.max(1, Math.min(level.length - 2, goalRow));
    
    level[goalRow][goalCol] = 3; // Goal tile
    
    // Clean surroundings of goal so they aren't trapped
    for (let r = -1; r <= 1; r++) {
        for (let c = -1; c <= 1; c++) {
            let row = goalRow + r;
            let col = goalCol + c;
            if (row >= 1 && row < level.length - 1 && col >= 1 && col < level[0].length - 1) {
                if (level[row][col] !== 3) {
                    level[row][col] = 0;
                }
            }
        }
    }
}

function updateWorld1BossBounds() {
    if (currentPlayingSlot !== 10) return;
    let gridSize = boss.grid.length;
    let minR = gridSize, maxR = -1, minC = gridSize, maxC = -1;
    let anyActive = false;
    for (let r = 0; r < gridSize; r++) {
        for (let c = 0; c < gridSize; c++) {
            if (boss.grid[r] && boss.grid[r][c] > 0) {
                anyActive = true;
                if (r < minR) minR = r;
                if (r > maxR) maxR = r;
                if (c < minC) minC = c;
                if (c > maxC) maxC = c;
            }
        }
    }
    if (!anyActive) {
        killWorld1BossAndRevealGoal();
        return;
    }
    
    let oldMinR = boss.minR !== undefined ? boss.minR : 0;
    let oldMinC = boss.minC !== undefined ? boss.minC : 0;
    
    let dr = minR - oldMinR;
    let dc = minC - oldMinC;
    
    boss.x += dc * TILE_SIZE;
    boss.y += dr * TILE_SIZE;
    
    boss.w = (maxC - minC + 1) * TILE_SIZE;
    boss.h = (maxR - minR + 1) * TILE_SIZE;
    
    boss.minR = minR;
    boss.minC = minC;
    boss.maxR = maxR;
    boss.maxC = maxC;
}

function arrangeBossGridToSquare() {
    if (currentPlayingSlot !== 10) return;
    
    let isInitial = !boss.hasInitializedReorgGrid;
    if (isInitial) {
        boss.hasInitializedReorgGrid = true;
        
        // Clean up remaining start dirt blocks in the mound (cols 21 to 28, rows 11 to 13)
        for (let r = 11; r <= 13; r++) {
            for (let c = 21; c <= 28; c++) {
                if (level[r] && (level[r][c] === 1 || isEatable(level[r][c]))) {
                    level[r][c] = 0;
                }
            }
        }
    }
    
    let gridSize = boss.grid.length;
    let bricks: { val: number; fromR: number; fromC: number }[] = [];
    
    // 1. Gather all blocks except the center Goal slot (r=10, c=10 which is type 3)
    for (let r = 0; r < gridSize; r++) {
        for (let c = 0; c < gridSize; c++) {
            let val = boss.grid[r] ? boss.grid[r][c] : 0;
            if (val > 0 && val !== 3) {
                // Restore durability of eatable block types back to full health
                if (val === 1 || val === 11 || val === 12) {
                    val = 1;
                } else if (val === 5 || val === 15 || val === 25) {
                    val = 5;
                }
                bricks.push({ val, fromR: r, fromC: c });
            }
        }
    }
    
    if (isInitial) {
        // Enforce exactly 24 bricks for a perfect 5x5 square (excluding center Core)
        if (bricks.length < 24) {
            while (bricks.length < 24) {
                bricks.push({ val: 1, fromR: 10, fromC: 10 });
            }
        } else if (bricks.length > 24) {
            bricks = bricks.slice(0, 24);
        }
    }
    
    // 2. Clear all grid except center Goal core
    for (let r = 0; r < gridSize; r++) {
        for (let c = 0; c < gridSize; c++) {
            if (boss.grid[r] && boss.grid[r][c] !== 3) {
                boss.grid[r][c] = 0;
            }
        }
    }
    
    // Determine dynamic target square size based on block count
    // gHalf: 1 = 3x3, 2 = 5x5, 3 = 7x7
    let gHalf = 2; // Default 5x5
    if (bricks.length <= 8) {
        gHalf = 1; // 3x3 (total blocks <= 9)
    } else if (bricks.length <= 24) {
        gHalf = 2; // 5x5 (9 < total blocks <= 25)
    } else {
        gHalf = 3; // 7x7 (total blocks > 25)
    }
    
    // 3. Replump/gravity-pack the bricks from bottom to top back into the target square area centered at 10,10
    let index = 0;
    let reorgAnimCells: { fromR: number; fromC: number; toR: number; toC: number; val: number; startFrame?: number; endFrame?: number }[] = [];
    let rMinTarget = 10 - gHalf;
    let rMaxTarget = 10 + gHalf;
    let cMinTarget = 10 - gHalf;
    let cMaxTarget = 10 + gHalf;
    
    let delayGap = 1;
    let cellDuration = 5;
    
    for (let r = rMaxTarget; r >= rMinTarget; r--) {
        for (let c = cMinTarget; c <= cMaxTarget; c++) {
            if (r === 10 && c === 10) {
                continue; // Skip the Goal core (already 3)
            }
            if (index < bricks.length) {
                let brick = bricks[index];
                boss.grid[r][c] = brick.val;
                
                reorgAnimCells.push({
                    fromR: brick.fromR,
                    fromC: brick.fromC,
                    toR: r,
                    toC: c,
                    val: brick.val,
                    startFrame: index * delayGap,
                    endFrame: index * delayGap + cellDuration
                });
                index++;
            } else {
                boss.grid[r][c] = 0;
            }
        }
    }
    
    boss.reorgAnimCells = reorgAnimCells;
    
    let totalCells = reorgAnimCells.length;
    let maxDur = totalCells > 0 ? (totalCells - 1) * delayGap + cellDuration : 35;
    
    boss.reorgTimer = maxDur; // Sequential stagger animation duration
    
    // 4. Recalculate boss size, bounds, and placement offset
    updateWorld1BossBounds();
    
    // Add satisfying sound & visual particle explosion for the gravity packing rearrangement
    camera.shake = Math.max(camera.shake, 20);
    SoundEffects.playBounce();
    spawnParticles(boss.x + boss.w / 2, boss.y + boss.h / 2, '#fbbf24', 25, 5.5);
    spawnParticles(boss.x + boss.w / 2, boss.y + boss.h / 2, '#4ade80', 15, 4.5);
}

function rotateBossGridClockwise() {
    // No rotation for World 1 Boss - pure mud and a face
}

function absorbDirtAroundBoss() {
    if (currentPlayingSlot !== 10 || !boss.active || boss.dead || boss.state === 'suspended') return;
    
    let gridSize = boss.grid.length;
    let minR = boss.minR ?? 0;
    let minC = boss.minC ?? 0;
    
    let absorbedAny = false;
    
    for (let r = 0; r < gridSize; r++) {
        for (let c = 0; c < gridSize; c++) {
            if (boss.grid[r][c] === 0) {
                // Check if adjacent to an active part of the boss
                let hasActiveNeighbor = false;
                if (r > 0 && boss.grid[r-1][c] > 0) hasActiveNeighbor = true;
                if (r < gridSize - 1 && boss.grid[r+1][c] > 0) hasActiveNeighbor = true;
                if (c > 0 && boss.grid[r][c-1] > 0) hasActiveNeighbor = true;
                if (c < gridSize - 1 && boss.grid[r][c+1] > 0) hasActiveNeighbor = true;
                
                if (!hasActiveNeighbor) continue;
                
                let levelC = Math.floor((boss.x + (c - minC) * TILE_SIZE + TILE_SIZE / 2) / TILE_SIZE);
                let levelR = Math.floor((boss.y + (r - minR) * TILE_SIZE + TILE_SIZE / 2) / TILE_SIZE);
                
                if (levelR >= 1 && levelR < level.length - 1 && levelC >= 1 && levelC < level[0].length - 1) {
                    let tile = level[levelR][levelC];
                    // Any solid/eatable tile that isn't the boundaries (type 2) or a goal core (type 3)
                    if (isEatable(tile) && tile !== 3 && tile !== 2) {
                        level[levelR][levelC] = 0;
                        boss.grid[r][c] = tile; 
                        
                        spawnParticles(levelC * TILE_SIZE + TILE_SIZE / 2, levelR * TILE_SIZE + TILE_SIZE / 2, tile === 5 ? '#ec4899' : '#d97706', 12, 3.5);
                        
                        absorbedAny = true;
                    }
                }
            }
        }
    }
    
    if (absorbedAny) {
        SoundEffects.playEat();
        boss.damageFlash = 0.8;
        boss.scaleX = 1.3;
        boss.scaleY = 0.7;
        camera.shake = Math.max(camera.shake, 8);
        updateWorld1BossBounds();
    }
}

function shakeDownDirtBlocks(count: number = 2) {
    let cols = level[0]?.length || 40;
    let bLeftCol = Math.floor(boss.x / TILE_SIZE) - 1;
    let bRightCol = Math.floor((boss.x + boss.w) / TILE_SIZE) + 1;
    
    // Constraint to screenspace visible columns
    let minCol = Math.max(1, Math.floor(camera.x / TILE_SIZE));
    let maxCol = Math.min(cols - 2, Math.ceil((camera.x + 960) / TILE_SIZE));
    
    let eligibleCols: number[] = [];
    for (let c = minCol; c <= maxCol; c++) {
        if (c < bLeftCol || c > bRightCol) {
            if (level[1][c] === 0 || level[2][c] === 0) {
                eligibleCols.push(c);
            }
        }
    }
    
    if (eligibleCols.length > 0) {
        let chosen: number[] = [];
        for (let i = 0; i < count; i++) {
            if (eligibleCols.length === 0) break;
            const rIdx = Math.floor(Math.random() * eligibleCols.length);
            chosen.push(eligibleCols[rIdx]);
            eligibleCols.splice(rIdx, 1);
        }
        
        let filledCount = getBossFilledCount();
        for (const col of chosen) {
            let bType = 1; // Dirt
            let warningColor = '#d97706';
            
            // 初始虛空0，每填一個BOSS格子增加4% (type 7 is Fillable Void)
            let voidChance = filledCount * 0.04;
            let rng = Math.random();
            
            if (rng < voidChance) {
                bType = 7;
                warningColor = '#a855f7';
            } else {
                // Of the remaining chance, we maintain a 15% rate of Bouncy blocks (type 5)
                if (Math.random() < 0.15) {
                    bType = 5;
                    warningColor = '#ec4899';
                } else {
                    bType = 1;
                    warningColor = '#d97706';
                }
            }

            fallingBlocks.push({
                x: col * TILE_SIZE + TILE_SIZE / 2,
                y: -40,
                vy: 2,
                type: bType,
                delay: 30, // 30 frames is exactly 0.5s at 60fps
                warningColor: warningColor
            });
            // Visual precursor: spawn warning dust particles dropping from the ceiling
            spawnParticles(col * TILE_SIZE + TILE_SIZE / 2, 20, '#ef4444', 20, 3.5);
        }
    }
}

function updateBossAndFallingBlocks() {
    // 1. Update falling blocks
    for (let i = fallingBlocks.length - 1; i >= 0; i--) {
        let fb = fallingBlocks[i];
        if (fb.delay !== undefined && fb.delay > 0) {
            fb.delay--;
            continue; // Keep suspended and wait for delay to run out
        }
        fb.vy += 0.3;
        fb.y += fb.vy;
        
        let col = Math.floor(fb.x / TILE_SIZE);
        let row = Math.floor(fb.y / TILE_SIZE);
        
        // Touch-to-die instant crushing collision with player (Uniform black block rule!)
        let fbLeft = fb.x - 20;
        let fbRight = fb.x + 20;
        let fbTop = fb.y - 20;
        let fbBottom = fb.y + 20;
        
        let pLeft = player.x;
        let pRight = player.x + player.w;
        let pTop = player.y;
        let pBottom = player.y + player.h;
        
        if (!(pRight <= fbLeft || pLeft >= fbRight || pBottom <= fbTop || pTop >= fbBottom)) {
            if (!player.dead && !player.won) {
                player.dead = true;
                deathTimer = 0;
                spawnParticles(player.x + player.w / 2, player.y + player.h / 2, '#000000', 40, 8);
                spawnParticles(player.x + player.w / 2, player.y + player.h / 2, '#ef4444', 20, 6);
                SoundEffects.playHurt();
            }
        }
        
        if (row >= 1 && row < level.length && col >= 0 && col < level[0].length) {
            let currentCell = level[row][col];
            
            // Random block transmutation upon landing (落地時變成隨機方塊)
            let randType = 1; // Default: Dirt
            let roll = Math.random();
            let filledVal = getBossFilledCount();
            if (filledVal >= 7) {
                if (roll < 0.60) randType = 7;      // Phase 3: high chance of Void blocks
                else if (roll < 0.75) randType = 5; // Bouncy
                else if (roll < 0.80) randType = 6; // Glass (decreased by 10%: 15% -> 5%)
                else randType = 1;                  // Dirt (increased by 10%: 10% -> 20%)
            } else if (filledVal >= 4) {
                if (roll < 0.25) randType = 7;      // Phase 2: moderate chance of Void
                else if (roll < 0.50) randType = 5; // Bouncy
                else if (roll < 0.65) randType = 6; // Glass (decreased by 10%: 25% -> 15%)
                else randType = 1;                  // Dirt (increased by 10%: 25% -> 35%)
            } else {
                if (roll < 0.15) randType = 5;      // Phase 1: some bouncy
                else if (roll < 0.20) randType = 6; // Glass (decreased by 10%: 15% -> 5%)
                else if (roll < 0.28) randType = 7; // tiny chance of void
                else randType = 1;                  // Dirt (increased by 10%: 62% -> 72%)
            }
            
            // If block falls directly onto a Void trap, it fills it
            if (currentCell === 7) {
                let tVal = randType === 5 ? 25 : (randType === 6 ? 6 : 12); // Glass lands as normal glass (6)
                level[row][col] = tVal;
                let color = randType === 5 ? '#ec4899' : (randType === 6 ? '#06b6d4' : '#d97706');
                spawnParticles(col * TILE_SIZE + TILE_SIZE / 2, row * TILE_SIZE + TILE_SIZE / 2, color, 25, 5.5);
                SoundEffects.playBounce();
                fallingBlocks.splice(i, 1);
                continue;
            }
            
            if (isSolid(currentCell)) {
                let landRow = row - 1;
                if (landRow >= 1 && level[landRow][col] === 0) {
                    level[landRow][col] = randType;
                    let color = randType === 7 ? '#a855f7' : (randType === 5 ? '#ec4899' : (randType === 6 ? '#06b6d4' : '#d97706'));
                    spawnParticles(col * TILE_SIZE + 20, landRow * TILE_SIZE + 20, color, 20, 5);
                    SoundEffects.playLand();
                }
                fallingBlocks.splice(i, 1);
            }
        } else if (row >= level.length) {
            fallingBlocks.splice(i, 1);
        }
    }

    if (!boss.active || boss.dead) return;

    if (currentPlayingSlot === 10) {
        // World 1 Boss AI
        if (boss.damageFlash > 0) boss.damageFlash -= 0.05;
        if (boss.reorgTimer && boss.reorgTimer > 0) {
            boss.reorgTimer--;
        }
        
        // Count remaining start dirt blocks in the mound (cols 21 to 28, rows 11 to 13)
        let moundDirtCount = 0;
        for (let r = 11; r <= 13; r++) {
            for (let c = 21; c <= 28; c++) {
                if (level[r] && level[r][c] === 1) {
                    moundDirtCount++;
                }
            }
        }
        
        // Initial fall and swallow 24-dirt heap: automatically reorganize back to 5x5 when fully eaten or landed
        let totalBlocks = boss.grid.flat().filter(val => val > 0).length;
        let shouldTriggerInitialReorg = false;
        if (!boss.hasInitialReorg) {
            if (totalBlocks >= 25) {
                shouldTriggerInitialReorg = true;
            } else if (moundDirtCount === 0) {
                shouldTriggerInitialReorg = true;
            } else if (boss.state === 'active' && boss.grounded) {
                shouldTriggerInitialReorg = true;
            }
        }
        
        if (shouldTriggerInitialReorg) {
            boss.hasInitialReorg = true;
            boss.jumpCount = 0;
            arrangeBossGridToSquare();
        }
        
        boss.scaleX += (1 - boss.scaleX) * 0.1;
        boss.scaleY += (1 - boss.scaleY) * 0.1;
        
        if (boss.state === 'suspended') {
            let distH = Math.abs((player.x + player.w/2) - (boss.x + boss.w/2));
            if (distH < 350) {
                boss.state = 'intro';
                boss.introTimer = 75;
                boss.triggered = true;
                camera.shake = 12;
                SoundEffects.playBounce();
            }
        } else if (boss.state === 'intro') {
            boss.introTimer--;
            if (boss.y < 80) boss.y += 1.3;
            
            if (boss.introTimer % 2 === 0) {
                let angle = Math.random() * Math.PI * 2;
                let radius = 120 + Math.random() * 80;
                let px = boss.x + boss.w / 2 + Math.cos(angle) * radius;
                let py = boss.y + boss.h / 2 + Math.sin(angle) * radius;
                particles.push({
                    x: px, y: py,
                    vx: -Math.cos(angle) * (radius / 15),
                    vy: -Math.sin(angle) * (radius / 15),
                    life: 1, maxLife: 25,
                    color: '#d97706', w: Math.random() * 3 + 4
                });
            }
            if (boss.introTimer <= 0) {
                boss.state = 'falling';
                boss.vy = 2;
                camera.shake = 30;
                SoundEffects.playBounce();
                spawnParticles(boss.x + boss.w/2, boss.y + boss.h/2, '#d97706', 40, 7);
            }
        } else if (boss.state === 'falling') {
            boss.vy += 0.25;
            boss.y += boss.vy;
            
            let rFloor = Math.floor((boss.y + boss.h) / TILE_SIZE);
            let cL = Math.floor(boss.x / TILE_SIZE);
            let cR = Math.floor((boss.x + boss.w) / TILE_SIZE);
            let landed = false;
            if (rFloor >= 1) {
                for (let col = cL; col <= cR; col++) {
                    let tile = (rFloor >= 0 && rFloor < level.length && col >= 0 && col < level[0].length) ? level[rFloor][col] : 2;
                    // Land on solid, non-eatable blocks only (like bedrock/boundaries) during initial descent
                    if (tile === 2 || (isSolid(tile) && !isEatable(tile))) {
                        landed = true;
                        break;
                    }
                }
            }
            if (landed) {
                boss.y = rFloor * TILE_SIZE - boss.h;
                boss.vy = 0;
                boss.state = 'active';
                boss.grounded = true;
                boss.scaleY = 0.5;
                boss.scaleX = 1.6;
                camera.shake = 28;
                SoundEffects.playLand();
                spawnParticles(boss.x + boss.w / 2, boss.y + boss.h, '#d97706', 35, 6);
            }
        } else {
            boss.vy += 0.25;
            boss.y += boss.vy;
            boss.x += boss.vx;
            
            // Ceiling boundary clamping (讓BOSS不跳出上界)
            if (boss.y < TILE_SIZE) {
                boss.y = TILE_SIZE;
                if (boss.vy < 0) boss.vy = 0;
            }
            
            if (boss.x < TILE_SIZE) {
                boss.x = TILE_SIZE;
                boss.vx = 0;
            } else if (boss.x + boss.w > level[0].length * TILE_SIZE - TILE_SIZE) {
                boss.x = level[0].length * TILE_SIZE - TILE_SIZE - boss.w;
                boss.vx = 0;
            }
            
            let rFloor = Math.floor((boss.y + boss.h) / TILE_SIZE);
            let cL = Math.floor(boss.x / TILE_SIZE);
            let cR = Math.floor((boss.x + boss.w) / TILE_SIZE);
            let landed = false;
            if (rFloor >= 1) {
                for (let col = cL; col <= cR; col++) {
                    if (isSolidOrBoundary(rFloor, col)) {
                        landed = true;
                        break;
                    }
                }
            }
            if (landed && boss.vy >= 0) {
                boss.y = rFloor * TILE_SIZE - boss.h;
                boss.vy = 0;
                boss.vx = 0;
                if (!boss.grounded) {
                    boss.grounded = true;
                    
                    if (boss.state === 'jumping') {
                        boss.jumpCount = (boss.jumpCount || 0) + 1;
                        if (boss.jumpCount % 5 === 0) {
                            arrangeBossGridToSquare();
                        }
                    }
                    
                    boss.state = 'active';
                    boss.scaleY = 0.5;
                    boss.scaleX = 1.6;
                    camera.shake = Math.max(camera.shake, 12);
                    SoundEffects.playLand();
                    spawnParticles(boss.x + boss.w / 2, boss.y + boss.h, '#fbbf24', 20, 5);
                }
            } else {
                boss.grounded = false;
            }
            
            if (boss.grounded) {
                boss.cooldown--;
                if (boss.cooldown <= 0) {
                    boss.cooldown = 120;
                    
                    let dx = (player.x + player.w/2) - (boss.x + boss.w/2);
                    boss.vy = -7.5 * 1.732; // Jump height 3x (vy scaled by sqrt(3))
                    
                    // Dynamically calculate accurate horizontal speed vx based on exact gravity equations
                    // Gravity = 0.25 per frame, flight time is 2 * |Vy| / Gravity
                    let flightTime = (2 * Math.abs(boss.vy)) / 0.25;
                    let idealVx = dx / flightTime;
                    
                    // Cap horizontal speed for perfect playability
                    boss.vx = Math.max(-6.5, Math.min(6.5, idealVx));
                    
                    rotateBossGridClockwise();
                    
                    boss.state = 'jumping';
                    boss.grounded = false;
                    boss.scaleY = 1.6;
                    boss.scaleX = 0.6;
                    camera.shake = Math.max(camera.shake, 8);
                    SoundEffects.playJump();
                }
            }
        }
        absorbDirtAroundBoss();
        resolvePlayerBossCollision();
        return;
    }

    // 2. Damage flash decay
    if (boss.damageFlash > 0) boss.damageFlash -= 0.05;

    // Decay scale
    boss.scaleX += (1 - boss.scaleX) * 0.15;
    boss.scaleY += (1 - boss.scaleY) * 0.15;

    if (currentPlayingSlot === 20) {
        // World 2 Boss custom state updates
        if (boss.state === 'suspended') {
            // Wake up when player is closer!
            let distH = Math.abs((player.x + player.w/2) - (boss.x + boss.w/2));
            if (distH < 350) {
                boss.state = 'intro';
                boss.introTimer = 120; // 2 seconds dramatic float down
                boss.triggered = true;
                camera.shake = 15;
                spawnParticles(boss.x + boss.w/2, boss.y + boss.h/2, '#db2777', 30, 5);
                SoundEffects.playBounce();
            }
        } else if (boss.state === 'intro') {
            boss.introTimer--;
            
            // Float down from high suspension
            if (boss.y < 80) {
                boss.y += 1.5;
            }
            
            // Converging pinkish-purple visual sparks!
            if (boss.introTimer % 2 === 0) {
                let angle = Math.random() * Math.PI * 2;
                let radius = 100 + Math.random() * 80;
                let px = boss.x + boss.w / 2 + Math.cos(angle) * radius;
                let py = boss.y + boss.h / 2 + Math.sin(angle) * radius;
                particles.push({
                    x: px, y: py,
                    vx: -Math.cos(angle) * (radius / 15),
                    vy: -Math.sin(angle) * (radius / 15),
                    life: 1, maxLife: 20,
                    color: '#e879f9', w: Math.random() * 3 + 3
                });
            }
            
            if (boss.introTimer <= 0) {
                boss.state = 'falling';
                boss.vy = 2; // quick drop Y acceleration
                camera.shake = 18;
                SoundEffects.playBounce();
                spawnParticles(boss.x + boss.w/2, boss.y + boss.h/2, '#db2777', 30, 6);
            }
        } else if (boss.state === 'falling') {
            // Standard falling drop
            boss.vy += 0.25;
            boss.y += boss.vy;
            
            let rFloor = Math.floor((boss.y + boss.h) / TILE_SIZE);
            let cL = Math.floor(boss.x / TILE_SIZE);
            let cR = Math.floor((boss.x + boss.w) / TILE_SIZE);
            let landed = false;
            if (rFloor >= 1) {
                for (let col = cL; col <= cR; col++) {
                    if (isSolidOrBoundary(rFloor, col)) {
                        landed = true;
                        break;
                    }
                }
            }
            if (landed) {
                boss.y = rFloor * TILE_SIZE - boss.h;
                boss.vy = 0;
                boss.state = 'active';
                boss.grounded = true;
                boss.cooldown = 120; // 2 seconds rest upon landing
                boss.scaleY = 0.5;
                boss.scaleX = 1.6;
                camera.shake = 24;
                SoundEffects.playLand();
                spawnParticles(boss.x + boss.w/2, boss.y + boss.h, '#db2777', 30, 5.5);
                damageTileUnderBoss(rFloor);
            }
        } else if (boss.state === 'active') {
            // Rest and prepare next charging attack
            boss.vx = 0;
            boss.vy += 0.25;
            boss.y += boss.vy;
            
            let rFloor = Math.floor((boss.y + boss.h) / TILE_SIZE);
            let cL = Math.floor(boss.x / TILE_SIZE);
            let cR = Math.floor((boss.x + boss.w) / TILE_SIZE);
            let hitFloor = false;
            if (rFloor >= 1) {
                for (let col = cL; col <= cR; col++) {
                    if (isSolidOrBoundary(rFloor, col)) {
                        hitFloor = true;
                        break;
                    }
                }
            }
            if (hitFloor && boss.vy >= 0) {
                boss.y = rFloor * TILE_SIZE - boss.h;
                boss.vy = 0;
                boss.grounded = true;
            } else {
                boss.grounded = false;
            }
            
            if (boss.grounded) {
                boss.cooldown--;
                if (boss.cooldown <= 0) {
                    // Transition to charging state!
                    boss.state = 'charging';
                    boss.chargeTimer = 180; // 3 seconds charging telegraph
                    boss.maxChargeTimer = 180;
                    boss.vx = 0;
                }
            }
        } else if (boss.state === 'charging') {
            boss.vx = 0;
            boss.vy += 0.25;
            boss.y += boss.vy;
            
            let rFloor = Math.floor((boss.y + boss.h) / TILE_SIZE);
            let cL = Math.floor(boss.x / TILE_SIZE);
            let cR = Math.floor((boss.x + boss.w) / TILE_SIZE);
            let hitFloor = false;
            if (rFloor >= 1) {
                for (let col = cL; col <= cR; col++) {
                    if (isSolidOrBoundary(rFloor, col)) {
                        hitFloor = true;
                        break;
                    }
                }
            }
            if (hitFloor && boss.vy >= 0) {
                boss.y = rFloor * TILE_SIZE - boss.h;
                boss.vy = 0;
                boss.grounded = true;
            } else {
                boss.grounded = false;
            }
            
            // Charging visuals: intense pink/purple sparks and wiggle scale!
            boss.scaleX = 1 + (Math.random() - 0.5) * 0.18;
            boss.scaleY = 1 + (Math.random() - 0.5) * 0.18;
            boss.damageFlash = 0.4 + Math.sin(Date.now() / 40) * 0.4;
            
            if (boss.chargeTimer % 3 === 0) {
                let angle = Math.random() * Math.PI * 2;
                let radius = 110 + Math.random() * 80;
                let px = boss.x + boss.w/2 + Math.cos(angle) * radius;
                let py = boss.y + boss.h/2 + Math.sin(angle) * radius;
                particles.push({
                    x: px, y: py,
                    vx: -Math.cos(angle) * (radius / 15),
                    vy: -Math.sin(angle) * (radius / 15),
                    life: 1, maxLife: 20,
                    color: '#e879f9', w: Math.random() * 4 + 3
                });
            }
            
            boss.chargeTimer--;
            if (boss.chargeTimer <= 0) {
                // Execute Boss Jump targeting player's head!
                let dx = (player.x + player.w/2) - (boss.x + boss.w/2);
                boss.state = 'jumping';
                boss.vy = -18; // Greatly increased powerful launch upward!
                // Dynamically resolve launch angle based on the horizontal distance to the player (根據玩家距離改變跳躍角度)
                let computedVx = dx * 0.035;
                boss.vx = (dx >= 0 ? 1 : -1) * Math.max(2.5, Math.min(14, Math.abs(computedVx)));
                
                boss.grounded = false;
                boss.scaleY = 1.9;
                boss.scaleX = 0.4;
                camera.shake = 22;
                SoundEffects.playJump();
                spawnParticles(boss.x + boss.w/2, boss.y + boss.h, '#db2777', 45, 8);
                
                // Set total bounces based on lost durability
                let lostD = 3 - (boss.durability ?? 3);
                boss.bouncesRemaining = 3 + 2 * lostD;
            }
        } else if (boss.state === 'jumping') {
            // Apply air physics and gravity
            boss.vy += 0.2; // gravity of 0.2
            boss.x += boss.vx;
            
            // Horizontal tile/block collision check for the Level 26 Boss
            let colStart = Math.max(0, Math.floor(boss.x / TILE_SIZE));
            let colEnd = Math.min(level[0].length - 1, Math.floor((boss.x + boss.w - 1) / TILE_SIZE));
            let rowStart = Math.max(0, Math.floor(boss.y / TILE_SIZE));
            let rowEnd = Math.min(level.length - 1, Math.floor((boss.y + boss.h - 1) / TILE_SIZE));
            
            let hitSolidBlock = false;
            let targetCol = -1;
            let hitRows: number[] = [];
            
            for (let r = rowStart; r <= rowEnd; r++) {
                for (let c = colStart; c <= colEnd; c++) {
                    let type = level[r][c];
                    if (isSolid(type)) {
                        hitSolidBlock = true;
                        targetCol = c;
                        if (!hitRows.includes(r)) {
                            hitRows.push(r);
                        }
                    }
                }
            }
            
            if (hitSolidBlock) {
                if (boss.vx > 0) {
                    boss.x = targetCol * TILE_SIZE - boss.w - 0.1;
                    spawnParticles(boss.x + boss.w, boss.y + boss.h/2, '#db2777', 15, 4);
                } else if (boss.vx < 0) {
                    boss.x = (targetCol + 1) * TILE_SIZE + 0.1;
                    spawnParticles(boss.x, boss.y + boss.h/2, '#db2777', 15, 4);
                }
                
                for (let r of hitRows) {
                    damageCellAt(r, targetCol);
                }
                
                boss.vx = -boss.vx * 1.05;
                camera.shake = Math.max(camera.shake, 18);
                SoundEffects.playBounce();
            }
            
            boss.y += boss.vy;
            
            // Wall bounce constraints - elastic and fun! (does NOT reduce remaining count)
            if (boss.x < TILE_SIZE) {
                boss.x = TILE_SIZE;
                boss.vx = -boss.vx * 1.05;
                camera.shake = Math.max(camera.shake, 15);
                SoundEffects.playBounce();
                spawnParticles(boss.x, boss.y + boss.h/2, '#db2777', 15, 4);
            } else if (boss.x + boss.w > level[0].length * TILE_SIZE - TILE_SIZE) {
                boss.x = level[0].length * TILE_SIZE - TILE_SIZE - boss.w;
                boss.vx = -boss.vx * 1.05;
                camera.shake = Math.max(camera.shake, 15);
                SoundEffects.playBounce();
                spawnParticles(boss.x + boss.w, boss.y + boss.h/2, '#db2777', 15, 4);
            }
            
            // Ceiling constraint - now bounces DOWN naturally! (does NOT reduce remaining count)
            if (boss.y < TILE_SIZE) {
                boss.y = TILE_SIZE;
                boss.vy = -boss.vy * 1.05;
                camera.shake = Math.max(camera.shake, 15);
                SoundEffects.playBounce();
                spawnParticles(boss.x + boss.w/2, boss.y, '#db2777', 15, 4);
            }
            
            // Ground bounce or landing resolution
            let rFloor = Math.floor((boss.y + boss.h) / TILE_SIZE);
            let cL = Math.floor(boss.x / TILE_SIZE);
            let cR = Math.floor((boss.x + boss.w) / TILE_SIZE);
            let landed = false;
            if (rFloor >= 1) {
                for (let col = cL; col <= cR; col++) {
                    if (isSolidOrBoundary(rFloor, col)) {
                        landed = true;
                        break;
                    }
                }
            }
            if (landed && boss.vy >= 0) {
                boss.y = rFloor * TILE_SIZE - boss.h;
                
                if ((boss.bouncesRemaining ?? 0) > 0) {
                    // Ground bounce - bounce back high! Greatly increased power!
                    boss.vy = -18;
                    // Slanted bounce angle redirection!
                    if (Math.abs(boss.vx) < 5) {
                        boss.vx = (boss.vx >= 0 ? 1 : -1) * 6;
                    } else {
                        boss.vx = boss.vx * 1.05;
                    }
                    boss.bouncesRemaining = (boss.bouncesRemaining ?? 1) - 1; // Only reduces when stepping on the ground!
                    camera.shake = Math.max(camera.shake, 22);
                    SoundEffects.playBounce();
                    spawnParticles(boss.x + boss.w/2, boss.y + boss.h, '#db2777', 30, 6);
                    damageTileUnderBoss(rFloor);
                } else {
                    // Bounces finished: land
                    boss.vy = 0;
                    boss.vx = 0;
                    boss.grounded = true;
                    boss.state = 'active';
                    boss.cooldown = 120; // 2 seconds rest/recovery before charging again
                    boss.scaleY = 0.5;
                    boss.scaleX = 1.6;
                    camera.shake = 26;
                    SoundEffects.playLand();
                    spawnParticles(boss.x + boss.w/2, boss.y + boss.h, '#db2777', 40, 7);
                    damageTileUnderBoss(rFloor);
                }
            }
        }
        
        // Out of map bottom bounds checking: "comes back Y but durability minus 1"
        if (boss.y > level.length * TILE_SIZE) {
            boss.durability = (boss.durability ?? 3) - 1;
            if (boss.durability <= 0) {
                // Defeated!
                boss.dead = true;
                boss.active = false;
                camera.shake = 40;
                SoundEffects.playHurt();
                
                // Explosive splash of colors
                spawnParticles(boss.x + boss.w/2, boss.y - boss.h, '#db2777', 60, 9);
                spawnParticles(boss.x + boss.w/2, boss.y - boss.h, '#a855f7', 40, 8);
                spawnParticles(boss.x + boss.w/2, boss.y - boss.h, '#34d399', 40, 8);
                
                // Spawn 8 bouncy blocks surrounding a center Goal Core in the middle of the arena
                level[8][23] = 5;
                level[8][24] = 5;
                level[8][25] = 5;
                
                level[9][23] = 5;
                level[9][24] = 3; // Center Goal block ($)
                level[9][25] = 5;
                
                level[10][23] = 5;
                level[10][24] = 5;
                level[10][25] = 5;
                
                // Clear any nearby elements for elegance (no steel support platform)
                for (let r = 7; r <= 12; r++) {
                    for (let c = 20; c <= 28; c++) {
                        if (level[r] && level[r][c] !== undefined) {
                            let isGoalPart = (r >= 8 && r <= 10 && c >= 23 && c <= 25);
                            if (!isGoalPart) {
                                level[r][c] = 0;
                            }
                        }
                    }
                }
            } else {
                // Return/Teleport back to top
                boss.x = 24 * TILE_SIZE;
                boss.y = -150;
                boss.prevX = 24 * TILE_SIZE;
                boss.prevY = -150;
                boss.vx = 0;
                boss.vy = 0;
                boss.state = 'intro';
                boss.introTimer = 120; // 2 seconds float down intro
                camera.shake = 30;
                SoundEffects.playHurt();
                // Splash portal/teleport aura at the landing zone
                spawnParticles(24 * TILE_SIZE + boss.w/2, 100, '#e879f9', 55, 7.5);
            }
        }
        
        resolvePlayerBossCollision();
        return;
    }

    if (currentPlayingSlot === 30) {
        // World 3 Boss custom state updates (Flying slime boss with rotating shields)
        if (boss.state === 'suspended') {
            // Wake up when player is closer!
            let distH = Math.abs((player.x + player.w/2) - (boss.x + boss.w/2));
            if (distH < 350) {
                boss.state = 'intro';
                boss.introTimer = 120; // 2 seconds float down intro
                boss.triggered = true;
                camera.shake = 15;
                spawnParticles(boss.x + boss.w/2, boss.y + boss.h/2, '#06b6d4', 30, 5);
                SoundEffects.playBounce();
            }
        } else if (boss.state === 'intro') {
            boss.introTimer--;
            
            // Float down to hovering height (around Y = 130)
            if (boss.y < 130) {
                boss.y += 1.8;
            }
            
            // Converging cyan/blue stars/sparks!
            if (boss.introTimer % 2 === 0) {
                let angle = Math.random() * Math.PI * 2;
                let radius = 100 + Math.random() * 80;
                let px = boss.x + boss.w/2 + Math.cos(angle) * radius;
                let py = boss.y + boss.h/2 + Math.sin(angle) * radius;
                particles.push({
                    x: px, y: py,
                    vx: -Math.cos(angle) * (radius / 15),
                    vy: -Math.sin(angle) * (radius / 15),
                    life: 1, maxLife: 20,
                    color: '#22d3ee', w: Math.random() * 3 + 3
                });
            }
            
            if (boss.introTimer <= 0) {
                boss.state = 'active';
                boss.cooldown = 110; // Reset cooldown
                boss.maxCooldown = 110;
                camera.shake = 18;
                SoundEffects.playBounce();
                spawnParticles(boss.x + boss.w/2, boss.y + boss.h/2, '#06b6d4', 35, 6.5);
            }
        } else {
            // ACTIVE FLIGHT HOVERING PATROL AI ("在玩家上方鏡頭內左右遊蕩")
            let targetY = player.y - 320;
            // Limit targetY so it stays within a reasonable bound
            targetY = Math.max(50, Math.min(level.length * TILE_SIZE - 380, targetY));
            
            // Swaying target X: wanders left and right smoothly
            let swayOffset = Math.sin(Date.now() / 1300) * 190;
            let targetX = player.x + swayOffset;
            
            // Keep targetX inside map walls with 2.5-tile safety margins
            targetX = Math.max(TILE_SIZE * 2.5, Math.min(level[0].length * TILE_SIZE - TILE_SIZE * 2.5 - boss.w, targetX));
            
            // Smooth velocity-based movement interpolation
            boss.vx = (targetX - boss.x) * 0.035;
            boss.vy = (targetY - boss.y) * 0.045;
            
            boss.x += boss.vx;
            boss.y += boss.vy;
            
            // Update Orbiting/Detaching glass shield coordinates & actions
            if (boss.shields) {
                let bossCenterX = boss.x + boss.w / 2;
                let bossCenterY = boss.y + boss.h / 2;
                
                for (let idx = 0; idx < boss.shields.length; idx++) {
                    let s = boss.shields[idx];
                    if (!s || !s.active) continue;
                    
                    if (s.state === 'orbit') {
                        // Normal orbit around boss
                        let count = boss.shields.length;
                        let angle = (Date.now() / 1500) + s.angleOffset;
                        s.radius = 85;
                        s.cx = bossCenterX + Math.cos(angle) * s.radius;
                        s.cy = bossCenterY + Math.sin(angle) * s.radius;
                    } else if (s.state === 'detaching') {
                        // "單獨出列": move outward from orbit, prepare to shoot
                        s.detachingTimer--;
                        
                        let targetRadius = 140;
                        let progress = 1.0 - (s.detachingTimer / 35);
                        s.radius = 85 + (targetRadius - 85) * Math.min(1.0, progress);
                        
                        let angle = (Date.now() / 1500) + s.angleOffset;
                        s.cx = bossCenterX + Math.cos(angle) * s.radius;
                        s.cy = bossCenterY + Math.sin(angle) * s.radius;
                        
                        // Warning cyan sparkles
                        if (s.detachingTimer % 3 === 0) {
                            particles.push({
                                x: s.cx + (Math.random() - 0.5) * 16,
                                y: s.cy + (Math.random() - 0.5) * 16,
                                vx: (Math.random() - 0.5) * 2.5,
                                vy: (Math.random() - 0.5) * 2.5,
                                life: 1, maxLife: 12,
                                color: '#22d3ee', w: Math.random() * 2.5 + 2.5
                            });
                        }
                        
                        if (s.detachingTimer <= 0) {
                            // "射擊" -> Launches itself as a glass projectile towards the player!
                            s.active = false; // remove from shield list
                            
                            let px = player.x + player.w / 2;
                            let py = player.y + player.h / 2;
                            let dx = px - s.cx;
                            let dy = py - s.cy;
                            let dist = Math.hypot(dx, dy);
                            if (dist > 0) {
                                let speed = 7.0; // fast glass block bullet
                                projectiles.push({
                                    x: s.cx - 20,
                                    y: s.cy - 20,
                                    vx: (dx / dist) * speed,
                                    vy: (dy / dist) * speed,
                                    w: 40,
                                    h: 40,
                                    dead: false,
                                    type: 6, // Breakable glass block
                                    eatenCount: 0,
                                    bounceCount: 0,
                                    isEnemy: true
                                });
                                
                                SoundEffects.playJump();
                                spawnParticles(s.cx, s.cy, '#06b6d4', 22, 5.5);
                            }
                        }
                    }
                }
            }
            
            // Attack sequence: "周圍的玻璃方塊會單獨出列射擊"
            boss.cooldown--;
            if (boss.cooldown <= 0) {
                boss.cooldown = 110; // Reset attack frequency (approx. 1.8 seconds)
                
                if (boss.shields) {
                    // Find active shields that are currently in orbit
                    let orbitShields = boss.shields.filter((s: any) => s && s.active && s.state === 'orbit');
                    let activeShields = boss.shields.filter((s: any) => s && s.active);
                    
                    if (activeShields.length > 0) {
                        if (orbitShields.length > 0) {
                            // Choose shield(s) to step out of line and prepare to fire based on HP (durability)
                            // 3 HP: 1 block
                            // 2 HP: 1 to 3 blocks
                            // 1 HP: 1 to 5 blocks
                            let hp = boss.durability ?? 3;
                            let numToShoot = 1;
                            if (hp === 2) {
                                numToShoot = Math.min(orbitShields.length, Math.floor(Math.random() * 3) + 1);
                            } else if (hp <= 1) {
                                numToShoot = Math.min(orbitShields.length, Math.floor(Math.random() * 5) + 1);
                            }
                            
                            let chosenShields: any[] = [];
                            let tempOrbit = [...orbitShields];
                            for (let k = 0; k < numToShoot; k++) {
                                if (tempOrbit.length === 0) break;
                                let rIdx = Math.floor(Math.random() * tempOrbit.length);
                                chosenShields.push(tempOrbit.splice(rIdx, 1)[0]);
                            }
                            
                            for (let chosen of chosenShields) {
                                chosen.state = 'detaching';
                                chosen.detachingTimer = 35; // 35 frames of warning/pulsing before launch
                            }
                            
                            SoundEffects.playBounce();
                        }
                    } else {
                        // All glass shields are fired/broken! Boss enters Dirt-Shooting phase
                        // "本體會發射泥土三次"
                        boss.dirtShotsFired = (boss.dirtShotsFired ?? 0) + 1;
                        
                        let bx = boss.x + boss.w / 2;
                        let by = boss.y + boss.h / 2;
                        let px = player.x + player.w / 2;
                        let py = player.y + player.h / 2;
                        let dx = px - bx;
                        let dy = py - by;
                        let dist = Math.hypot(dx, dy);
                        
                        let hp = boss.durability ?? 3;
                        let numDirt = 1;
                        if (hp === 2) {
                            // 2 HP: shoots 1~3 blocks
                            numDirt = Math.floor(Math.random() * 3) + 1;
                        } else if (hp <= 1) {
                            // 1 HP: shoots 1~5 blocks
                            numDirt = Math.floor(Math.random() * 5) + 1;
                        }
                        
                        if (dist > 0) {
                            let baseAngle = Math.atan2(dy, dx);
                            let angleStep = 0.22; // approx 12 degrees
                            let startAngle = baseAngle - ((numDirt - 1) / 2) * angleStep;
                            
                            for (let i = 0; i < numDirt; i++) {
                                let curAngle = startAngle + i * angleStep;
                                let speed = 5.5;
                                let vx = Math.cos(curAngle) * speed;
                                let vy = Math.sin(curAngle) * speed;
                                
                                projectiles.push({
                                    x: bx - 20,
                                    y: by - 20,
                                    vx: vx,
                                    vy: vy,
                                    w: 40,
                                    h: 40,
                                    dead: false,
                                    type: 1, // Dirt block projectile
                                    eatenCount: 0,
                                    bounceCount: 0,
                                    isEnemy: true
                                });
                            }
                            
                            spawnParticles(bx, by, '#d97706', 20, 5.5);
                            SoundEffects.playJump();
                        }
                        
                        // "然後復原環繞的"
                        if (boss.dirtShotsFired >= 3) {
                            boss.dirtShotsFired = 0;
                            let nextCount = hp === 3 ? 4 : (hp === 2 ? 8 : 12);
                            boss.shields = Array(nextCount).fill(null).map((_, idx) => ({
                                active: true,
                                state: 'orbit',
                                angleOffset: (idx * 2 * Math.PI) / nextCount,
                                radius: 85,
                                detachingTimer: 0,
                                cx: 0,
                                cy: 0
                            }));
                            
                            spawnParticles(bx, by, '#06b6d4', 25, 6.5);
                            SoundEffects.playBounce();
                        }
                    }
                }
            }
        }
        
        resolvePlayerBossCollision();
        return;
    }

    // 3. Update Boss action state
    if (boss.eatingProgress > 0) {
        boss.vx = 0;
        boss.vy = 0;
        if (boss.state !== 'active') {
            boss.state = 'active';
            boss.grounded = true;
        }
    } else if (boss.state === 'suspended') {
        let distH = Math.abs((player.x + player.w/2) - (boss.x + boss.w/2));
        if (distH < 350) {
            boss.state = 'intro';
            boss.introTimer = 180; // 3 seconds @ 60fps
            boss.triggered = true;
            camera.shake = 12;
            SoundEffects.playBounce();
        }
    } else if (boss.state === 'intro') {
        boss.introTimer--;
        
        // Slow dramatic entry/float down
        if (boss.y < 80) {
            boss.y += 1.3;
        }
        
        // Golden/red neon energy vortex charging
        if (boss.introTimer % 2 === 0) {
            let angle = Math.random() * Math.PI * 2;
            let radius = 120 + Math.random() * 80;
            let px = boss.x + boss.w / 2 + Math.cos(angle) * radius;
            let py = boss.y + boss.h / 2 + Math.sin(angle) * radius;
            particles.push({
                x: px, y: py,
                vx: -Math.cos(angle) * (radius / 15),
                vy: -Math.sin(angle) * (radius / 15),
                life: 1, maxLife: 25,
                color: '#fbbf24', w: Math.random() * 3 + 4 // golden sparks
            });
            particles.push({
                x: boss.x + boss.w/2 + (Math.random() - 0.5) * 120,
                y: boss.y + boss.h/2 + (Math.random() - 0.5) * 120,
                vx: (Math.random() - 0.5) * 3,
                vy: (Math.random() - 0.5) * 3,
                life: 1, maxLife: 15,
                color: '#ef4444', w: Math.random() * 2 + 1 // alert red sparks
            });
        }
        
        if (boss.introTimer <= 0) {
            boss.state = 'falling';
            boss.vy = 2; // quick drop
            camera.shake = 30;
            SoundEffects.playBounce();
            spawnParticles(boss.x + boss.w/2, boss.y + boss.h/2, '#ef4444', 40, 7);
        }
    } else if (boss.state === 'falling') {
        boss.vy += 0.2;
        boss.y += boss.vy;
        
        let rFloor = Math.floor((boss.y + boss.h) / TILE_SIZE);
        let cL = Math.floor(boss.x / TILE_SIZE);
        let cR = Math.floor((boss.x + boss.w) / TILE_SIZE);
        let landed = false;
        if (rFloor >= 1) {
            for (let col = cL; col <= cR; col++) {
                if (isSolidOrBoundary(rFloor, col)) {
                    landed = true;
                    break;
                }
            }
        }
        if (landed) {
            boss.y = rFloor * TILE_SIZE - boss.h;
            boss.vy = 0;
            boss.state = 'active';
            boss.grounded = true;
            boss.scaleY = 0.5;
            boss.scaleX = 1.6;
            camera.shake = 28;
            SoundEffects.playLand();
            spawnParticles(boss.x + boss.w / 2, boss.y + boss.h, '#4ade80', 35, 6);
            damageTileUnderBoss(rFloor);
        }
    } else if (boss.state === 'charging') {
        boss.vx *= 0.8;
        boss.vy += 0.2;
        boss.y += boss.vy;
        
        // Ceiling clamping
        if (boss.y < TILE_SIZE) {
            boss.y = TILE_SIZE;
            if (boss.vy < 0) boss.vy = 0;
        }
        
        let rFloor = Math.floor((boss.y + boss.h) / TILE_SIZE);
        let cL = Math.floor(boss.x / TILE_SIZE);
        let cR = Math.floor((boss.x + boss.w) / TILE_SIZE);
        let hitFloor = false;
        if (rFloor >= 1) {
            for (let col = cL; col <= cR; col++) {
                if (isSolidOrBoundary(rFloor, col)) {
                    hitFloor = true;
                    break;
                }
            }
        }
        if (hitFloor && boss.vy >= 0) {
            boss.y = rFloor * TILE_SIZE - boss.h;
            boss.vy = 0;
            boss.grounded = true;
        } else {
            boss.grounded = false;
        }

        // Shaking & Visual charging effects
        boss.scaleX = 1 + (Math.random() - 0.5) * 0.15;
        boss.scaleY = 1 + (Math.random() - 0.5) * 0.15;
        
        // Purple & Pink energy particles converging onto Boss center
        if (boss.chargeTimer % 2 === 0) {
            let angle = Math.random() * Math.PI * 2;
            let radius = 100 + Math.random() * 80;
            let px = boss.x + boss.w/2 + Math.cos(angle) * radius;
            let py = boss.y + boss.h/2 + Math.sin(angle) * radius;
            particles.push({
                x: px, y: py,
                vx: -Math.cos(angle) * (radius / 15),
                vy: -Math.sin(angle) * (radius / 15),
                life: 1, maxLife: 20,
                color: (boss.chargeTimer % 4 === 0) ? '#a855f7' : '#ec4899',
                w: Math.random() * 4 + 3
            });
        }
        
        // Visual warning neon glow
        boss.damageFlash = 0.5 + Math.sin(Date.now() / 30) * 0.5;

        boss.chargeTimer--;
        if (boss.chargeTimer <= 0) {
            let dx = (player.x + player.w/2) - (boss.x + boss.w/2);
            boss.jumpType = 'mega';
            boss.vy = -14.0 * 1.732; // Jump height 3x (vy scaled by sqrt(3))
            // Dynamically resolve launch angle based on the horizontal distance to the player (根據玩家距離改變跳躍角度)
            let computedVx = dx * 0.03;
            boss.vx = (dx >= 0 ? 1 : -1) * Math.max(2.0, Math.min(12, Math.abs(computedVx)));
            boss.state = 'jumping';
            boss.grounded = false;
            boss.scaleY = 1.8;
            boss.scaleX = 0.5;
            boss.cooldown = 10; // tiny landing recovery
            boss.maxCooldown = 10;
            camera.shake = 15;
            SoundEffects.playJump();
            spawnParticles(boss.x + boss.w / 2, boss.y + boss.h, '#a855f7', 45, 8); // massive purple energy blast on jump
        }
    } else if (boss.state === 'active' || boss.state === 'jumping' || boss.state === 'pre_jump') {
        boss.vy += 0.2;
        boss.y += boss.vy;
        
        // Ceiling clamping to prevent jumping out of the map height
        if (boss.y < TILE_SIZE) {
            boss.y = TILE_SIZE;
            if (boss.vy < 0) boss.vy = 0;
        }
        
        let rFloor = Math.floor((boss.y + boss.h) / TILE_SIZE);
        let cL = Math.floor(boss.x / TILE_SIZE);
        let cR = Math.floor((boss.x + boss.w) / TILE_SIZE);
        let hitFloor = false;
        if (rFloor >= 1) {
            for (let col = cL; col <= cR; col++) {
                if (isSolidOrBoundary(rFloor, col)) {
                    if (boss.state === 'jumping' && boss.jumpType === 'mega') {
                        let blockType = level[rFloor] ? level[rFloor][col] : 0;
                        if (blockType !== 2 && isSolid(blockType)) {
                            continue; // Break through non-boundary blocks!
                        }
                    }
                    hitFloor = true;
                    break;
                }
            }
        }
        if (hitFloor && boss.vy >= 0) {
            boss.y = rFloor * TILE_SIZE - boss.h;
            boss.vy = 0;
            boss.grounded = true;
            if (boss.state === 'jumping') {
                boss.state = 'active';
                boss.vx = 0;
                boss.scaleY = 0.5;
                boss.scaleX = 1.6;
                damageTileUnderBoss(rFloor);
                
                if (currentPlayingSlot === 10) {
                    boss.jumpCount = (boss.jumpCount || 0) + 1;
                    if (boss.jumpCount % 5 === 0) {
                        arrangeBossGridToSquare();
                    }
                }
                
                let isPhase3 = getBossFilledCount() >= 7;
                if (boss.comboCount > 0) {
                    boss.cooldown = 15;
                    boss.maxCooldown = 15;
                } else if (boss.jumpType === 'mega') {
                    boss.cooldown = 0; // Ultimate has 0 aftermath!
                    boss.maxCooldown = 0;
                } else {
                    boss.cooldown = isPhase3 ? 30 : 60;
                    boss.maxCooldown = isPhase3 ? 30 : 60;
                }

                // Custom landing dynamics depending on jump type
                if (boss.jumpType === 'big') {
                    camera.shake = 26;
                    SoundEffects.playLand();
                    spawnParticles(boss.x + boss.w / 2, boss.y + boss.h, '#4ade80', 40, 8);
                    shakeDownDirtBlocks(5); // Big jump drops 5 blocks!
                } else if (boss.jumpType === 'small') {
                    camera.shake = 10;
                    SoundEffects.playLand();
                    spawnParticles(boss.x + boss.w / 2, boss.y + boss.h, '#3b82f6', 15, 4);
                    shakeDownDirtBlocks(1); // Small jump drops 1 block!
                } else if (boss.jumpType === 'precision') {
                    camera.shake = 18;
                    SoundEffects.playLand();
                    spawnParticles(boss.x + boss.w / 2, boss.y + boss.h, '#ef4444', 30, 6);
                    shakeDownDirtBlocks(3); // Precision jump drops 3 blocks!
                } else if (boss.jumpType === 'mega') {
                    camera.shake = 45; // Earthquake!
                    SoundEffects.playLand();
                    spawnParticles(boss.x + boss.w / 2, boss.y + boss.h, '#a855f7', 60, 9);
                    spawnParticles(boss.x + boss.w / 2, boss.y + boss.h, '#f43f5e', 40, 7);
                    triggerMegaPatternedDrop(); // Custom regular drop!
                    // Ground left/right shockwaves
                    for (let i = 0; i < 20; i++) {
                        particles.push({
                            x: boss.x + boss.w,
                            y: boss.y + boss.h - 10,
                            vx: 5 + Math.random() * 5,
                            vy: -1 - Math.random() * 3,
                            life: 1, maxLife: 30,
                            color: '#a855f7',
                            w: 8
                        });
                        particles.push({
                            x: boss.x,
                            y: boss.y + boss.h - 10,
                            vx: -5 - Math.random() * 5,
                            vy: -1 - Math.random() * 3,
                            life: 1, maxLife: 30,
                            color: '#a855f7',
                            w: 8
                        });
                    }
                } else { // Combo hops or standard
                    camera.shake = 14;
                    SoundEffects.playLand();
                    spawnParticles(boss.x + boss.w / 2, boss.y + boss.h, '#eab308', 20, 5);
                    shakeDownDirtBlocks(2); // Combo/normal/others drops 2 blocks!
                }
            }
        } else {
            boss.grounded = false;
        }

        if (boss.state === 'jumping') {
            boss.x += boss.vx;
            let leftCol = Math.floor(boss.x / TILE_SIZE);
            let rightCol = Math.floor((boss.x + boss.w) / TILE_SIZE);
            if (leftCol <= 0) {
                boss.x = TILE_SIZE + 1;
                boss.vx = 0;
            }
            if (rightCol >= level[0].length - 1) {
                boss.x = (level[0].length - 1) * TILE_SIZE - boss.w - 1;
                boss.vx = 0;
            }

            if (boss.jumpType === 'mega') {
                let r1 = Math.floor(boss.y / TILE_SIZE);
                let r2 = Math.floor((boss.y + boss.h) / TILE_SIZE);
                for (let r = r1; r <= r2; r++) {
                    for (let c = leftCol; c <= rightCol; c++) {
                        if (r >= 1 && r < level.length - 1 && c >= 1 && c < level[0].length - 1) {
                            let blockType = level[r][c];
                            if (blockType > 0 && blockType !== 2 && isSolid(blockType)) {
                                level[r][c] = 0;
                                let cx = c * TILE_SIZE + TILE_SIZE / 2;
                                let cy = r * TILE_SIZE + TILE_SIZE / 2;
                                let color = '#d97706';
                                if (blockType === 5 || blockType === 25 || blockType === 15) color = '#ec4899';
                                else if (blockType === 6) color = '#06b6d4';
                                spawnParticles(cx, cy, color, 15, 5);
                                spawnParticles(cx, cy, '#a855f7', 10, 4); // Purple energy trail
                                SoundEffects.playBounce();
                                camera.shake = Math.max(camera.shake, 8);
                            }
                        }
                    }
                }
            }
        }

        if (boss.state === 'active' && boss.grounded) {
            let filledCount = getBossFilledCount();
            
            boss.cooldown -= 1;
            if (boss.cooldown <= 0) {
                // Increment actionCount
                boss.actionCount++;
                
                if (boss.actionCount > 0 && boss.actionCount % 8 === 0) {
                    // Enter charging state (蓄力放個大招)!
                    boss.state = 'charging';
                    let cTime = 300; // 5 seconds at 60 FPS
                    boss.chargeTimer = cTime;
                    boss.maxChargeTimer = cTime;
                    boss.cooldown = 0; // reset
                    boss.scaleX = 1.5;
                    boss.scaleY = 0.6;
                    boss.vx = 0;
                    spawnParticles(boss.x + boss.w / 2, boss.y + boss.h / 2, '#a855f7', 30, 4);
                } else {
                    let dx = (player.x + player.w/2) - (boss.x + boss.w/2);
                    let randRoll = Math.random();
                    
                    let isPhase3 = filledCount >= 7;
                    if (boss.comboCount > 0 && isPhase3) {
                        boss.jumpType = 'combo';
                    } else {
                        boss.comboCount = 0;
                        if (isPhase3) {
                            if (randRoll < 0.25) {
                                boss.jumpType = 'big';
                            } else if (randRoll < 0.50) {
                                boss.jumpType = 'small';
                            } else if (randRoll < 0.75) {
                                boss.jumpType = 'precision';
                            } else {
                                boss.jumpType = 'combo';
                                boss.comboCount = 3; // 3 hops combo in a row!
                            }
                        } else {
                            // Phase 1 and 2: No combos! Only big, small, and precision jumps.
                            if (randRoll < 0.33) {
                                boss.jumpType = 'big';
                            } else if (randRoll < 0.66) {
                                boss.jumpType = 'small';
                            } else {
                                boss.jumpType = 'precision';
                            }
                        }
                    }
                    
                    // Enter Telegraph (前搖)
                    boss.state = 'pre_jump';
                    boss.vx = 0;

                    let unifiedPreJump = isPhase3 ? 90 : 180;

                    // Configure target trajectory and telegraph delay
                    if (boss.jumpType === 'big') {
                        boss.targetVy = -11.5 * 1.732;
                        boss.maxPreJumpTimer = unifiedPreJump; 
                    } else if (boss.jumpType === 'small') {
                        boss.targetVy = -7.0 * 1.732;
                        boss.maxPreJumpTimer = unifiedPreJump; 
                    } else if (boss.jumpType === 'precision') {
                        boss.targetVy = -9.5 * 1.732;
                        boss.maxPreJumpTimer = unifiedPreJump; 
                    } else if (boss.jumpType === 'combo') {
                        boss.targetVy = -7.5 * 1.732;
                        if (boss.comboCount === 3) {
                            boss.maxPreJumpTimer = unifiedPreJump; // First hop long telegraph
                        } else {
                            boss.maxPreJumpTimer = 30; // subsequent hops very rapid
                        }
                        boss.comboCount--;
                    }

                    // Dynamically calculate high-accuracy horizontal speed vx based on exact gravity equations
                    // Gravity = 0.2 per frame, flight time is 2 * |Vy| / Gravity
                    let flightTime = (2 * Math.abs(boss.targetVy || 0)) / 0.2;
                    let idealVx = dx / flightTime;
                    
                    // Cap horizontal speed strictly based on character limits for high playability
                    let maxVxWidth = 8.5;
                    if (boss.jumpType === 'small') maxVxWidth = 4.5;
                    if (boss.jumpType === 'combo') maxVxWidth = 6.0;
                    if (boss.jumpType === 'precision') maxVxWidth = 7.5;
                    if (boss.jumpType === 'big') maxVxWidth = 9.0;
                    
                    boss.targetVx = Math.max(-maxVxWidth, Math.min(maxVxWidth, idealVx));
                    
                    boss.preJumpTimer = boss.maxPreJumpTimer;
                    boss.scaleY = 0.75;
                    boss.scaleX = 1.3;
                    // SoundEffects.playDamage(); // gentle telegraph sound? Or omit?
                }
            }
        }
        
        if (boss.state === 'pre_jump') {
            // Vibratory charge-up visual
            boss.x += (Math.random() - 0.5) * 2; // subtle shaking
            boss.scaleY = 0.75 + Math.sin(Date.now() / 50) * 0.05;

            boss.preJumpTimer = (boss.preJumpTimer || 0) - 1;
            if (boss.preJumpTimer <= 0) {
                // Execute Jump!
                boss.vy = boss.targetVy || -17.32;
                boss.vx = boss.targetVx || 0;
                
                // Color FX based on jumpType
                if (boss.jumpType === 'big') {
                    spawnParticles(boss.x + boss.w / 2, boss.y + boss.h, '#4ade80', 25, 5);
                } else if (boss.jumpType === 'small') {
                    spawnParticles(boss.x + boss.w / 2, boss.y + boss.h, '#3b82f6', 12, 3);
                } else if (boss.jumpType === 'precision') {
                    spawnParticles(boss.x + boss.w / 2, boss.y + boss.h, '#ef4444', 20, 4.5);
                } else if (boss.jumpType === 'combo') {
                    spawnParticles(boss.x + boss.w / 2, boss.y + boss.h, '#eab308', 15, 4);
                }

                // Damage tiles under feet before liftoff
                let underRow = Math.floor((boss.y + boss.h + 5) / TILE_SIZE);
                damageTileUnderBoss(underRow);
                
                boss.state = 'jumping';
                boss.grounded = false;
                boss.scaleY = 1.5;
                boss.scaleX = 0.6;
                boss.cooldown = 0; // Start with 0 so landing executes immediately
                boss.maxCooldown = 120; // It will be set upon landing
                SoundEffects.playJump();
            }
        }
    }

    // 4. Handle block collisions with Projectiles
    for (let p of projectiles) {
        if (p.dead) continue;
        let isLevel10 = currentPlayingSlot === 10;
        let size = isLevel10 ? boss.grid.length : 3;
        let centerR = isLevel10 ? (boss.centerR ?? 10) : 1;
        let centerC = isLevel10 ? (boss.centerC ?? 10) : 1;
        let minR = isLevel10 ? (boss.minR ?? 0) : 0;
        let minC = isLevel10 ? (boss.minC ?? 0) : 0;
        
        for (let r = 0; r < size; r++) {
            for (let c = 0; c < size; c++) {
                if (r === centerR && c === centerC) continue; // Skip center Goal core
                let cellX = isLevel10 ? (boss.x + (c - minC) * TILE_SIZE) : (boss.x + c * TILE_SIZE);
                let cellY = isLevel10 ? (boss.y + (r - minR) * TILE_SIZE) : (boss.y + r * TILE_SIZE);
                
                let pxR = p.x + p.w;
                let pyB = p.y + p.h;
                let cxR = cellX + TILE_SIZE;
                let cyB = cellY + TILE_SIZE;
                
                if (!(pxR <= cellX || p.x >= cxR || pyB <= cellY || p.y >= cyB)) {
                    let targetR = r;
                    let targetC = c;

                    let val = boss.grid[targetR] ? boss.grid[targetR][targetC] : 0;
                    if (val === 0) {
                        // Check if adjacent to an active part of the boss to prevent floating disjoint blocks ("no 隔空沾")
                        let isAdjacent = false;
                        if (targetR > 0 && boss.grid[targetR - 1] && boss.grid[targetR - 1][targetC] > 0) isAdjacent = true;
                        if (targetR < size - 1 && boss.grid[targetR + 1] && boss.grid[targetR + 1][targetC] > 0) isAdjacent = true;
                        if (targetC > 0 && boss.grid[targetR][targetC - 1] > 0) isAdjacent = true;
                        if (targetC < size - 1 && boss.grid[targetR][targetC + 1] > 0) isAdjacent = true;

                        if (!isAdjacent) {
                            continue;
                        }

                        let placeType = p.type;
                        if (p.type === 1) placeType = 12;      // Dirt block with 1 durability left
                        else if (p.type === 5) placeType = 25; // Bouncy block with 1 durability left
                        boss.grid[targetR][targetC] = placeType;
                        p.dead = true;
                        boss.damageFlash = 1;
                        boss.scaleX = 1.35;
                        boss.scaleY = 0.7; // squish deformation on absorption
                        camera.shake = 12;
                        SoundEffects.playEat();
                        spawnParticles(cellX + TILE_SIZE / 2, cellY + TILE_SIZE / 2, p.type === 5 ? '#ec4899' : '#d97706', 15, 4);
                        spawnParticles(cellX + TILE_SIZE / 2, cellY + TILE_SIZE / 2, '#a855f7', 15, 5); // purple void fusion blast
                        if (isLevel10) {
                            updateWorld1BossBounds();
                        }
                        break;
                    } else {
                        // Occupied core reacts as a solid block - bounces blocks away!
                        p.vx = -p.vx * 0.8 + (Math.random() - 0.5) * 2;
                        p.vy = -Math.abs(p.vy) * 0.8 - 1.5; 
                        p.y = cellY - p.h - 1; // offset upwards to prevent sticking
                        camera.shake = Math.max(camera.shake, 3);
                        SoundEffects.playBounce();
                        spawnParticles(p.x, p.y, val === 5 ? '#ec4899' : '#d97706', 8, 3);
                        break;
                    }
                }
            }
            if (p.dead) break;
        }
    }

    // 5. Suction ray processing
    if (isBossFilled() || boss.eatingProgress > 0) {
        let drawingT = getEatTargetOfBoss();
        if (drawingT && isActionDown('eat') && !player.hasBlock) {
            boss.eatingProgress += 1 / 100;
            boss.damageFlash = 0.6 + Math.sin(Date.now() / 50) * 0.4;
            boss.scaleX = 1 + (Math.random() - 0.5) * 0.2;
            boss.scaleY = 1 + (Math.random() - 0.5) * 0.2;
            
            // Synthesize responsive rising tone sweep
            if (Date.now() % 250 < 35) {
                SoundEffects.playDevourPulse(boss.eatingProgress);
            }

            // Spawn swirling vacuum vortex flow lines
            if (Math.random() < 0.8) {
                let bx = boss.x + boss.w / 2;
                let by = boss.y + boss.h / 2;
                let px = player.x + player.w / 2;
                let py = player.y + player.h / 2;
                let tRatio = Math.random();
                let sx = bx + (px - bx) * tRatio + (Math.random() - 0.5) * 40;
                let sy = by + (py - by) * tRatio + (Math.random() - 0.5) * 40;
                particles.push({
                    x: sx,
                    y: sy,
                    vx: (px - bx) / 25 + (Math.random() - 0.5) * 3,
                    vy: (py - by) / 25 + (Math.random() - 0.5) * 3,
                    life: 1,
                    maxLife: Math.random() * 15 + 15,
                    color: Math.random() < 0.5 ? '#c084fc' : '#e0f2fe',
                    w: Math.random() * 4 + 2
                });
            }
            
            // Destroy cells sequentially as progress increases (讓玩家吞噬BOSS已被填滿方塊時能破記對應部位)
            if (currentPlayingSlot === 40) {
                let currentFilledCount = getBossFilledCount();
                let targetFilledCount = Math.max(0, 8 - Math.floor(boss.eatingProgress * 10)); // keep 8, then 7... down to 0
                if (currentFilledCount > targetFilledCount) {
                    let destroyed = false;
                    for (let r = 0; r < 3 && !destroyed; r++) {
                        for (let c = 0; c < 3 && !destroyed; c++) {
                            if (r === 1 && c === 1) continue; // skip center portal core!
                            if (boss.grid[r][c] > 0) {
                                let cellVal = boss.grid[r][c];
                                boss.grid[r][c] = 0;
                                // Spawn explosions at this cell
                                let tx = boss.x + c * TILE_SIZE + TILE_SIZE / 2;
                                let ty = boss.y + r * TILE_SIZE + TILE_SIZE / 2;
                                let color = (cellVal === 5 || cellVal === 15 || cellVal === 25) ? '#ec4899' : '#d97706';
                                spawnParticles(tx, ty, color, 25, 6);
                                spawnParticles(tx, ty, '#a855f7', 15, 5); // void color
                                camera.shake = Math.max(camera.shake, 12);
                                SoundEffects.playEat();
                                destroyed = true;
                            }
                        }
                    }
                }
            }
            
            if (Math.random() < 0.45) {
                let bx = boss.x + boss.w / 2;
                let by = boss.y + boss.h / 2;
                let px = player.x + player.w / 2;
                let py = player.y + player.h / 2;
                particles.push({
                    x: bx + (Math.random() - 0.5) * 80,
                    y: by + (Math.random() - 0.5) * 80,
                    vx: (px - bx) / 20 + (Math.random() - 0.5) * 2,
                    vy: (py - by) / 20 + (Math.random() - 0.5) * 2,
                    life: 1, maxLife: 20,
                    color: '#a855f7', w: 4
                });
            }
            
            if (boss.eatingProgress >= 1) {
                boss.dead = true;
                boss.active = false;
                camera.shake = 30;
                SoundEffects.playHurt();
                setTimeout(() => SoundEffects.playWin(), 100);
                
                spawnParticles(boss.x + boss.w/2, boss.y + boss.h/2, '#ec4899', 40, 8);
                spawnParticles(boss.x + boss.w/2, boss.y + boss.h/2, '#a855f7', 40, 8);
                spawnParticles(boss.x + boss.w/2, boss.y + boss.h/2, '#34d399', 40, 8);
                
                let goalCol = Math.floor((boss.x + boss.w/2) / TILE_SIZE);
                let goalRow = Math.floor((boss.y + boss.h/2) / TILE_SIZE);
                goalCol = Math.max(1, Math.min(level[0].length - 2, goalCol));
                goalRow = Math.max(1, Math.min(level.length - 2, goalRow));
                
                level[goalRow][goalCol] = 3; 
                
                for (let r = -1; r <= 1; r++) {
                    for (let c = -1; c <= 1; c++) {
                        let row = goalRow + r;
                        let col = goalCol + c;
                        if (row >= 1 && row < level.length - 1 && col >= 1 && col < level[0].length - 1) {
                            if (level[row][col] !== 3) {
                                level[row][col] = 0;
                            }
                        }
                    }
                }
            }
        } else {
            boss.eatingProgress = Math.max(0, boss.eatingProgress - 0.025);
        }
    }

    // 6. Revamped Player and Boss Collision Logic
    resolvePlayerBossCollision();
}

function resolvePlayerBossCollision() {
    if (!boss.active || boss.dead || boss.state === 'suspended' || boss.state === 'intro') return;

    let isLevel10 = currentPlayingSlot === 10;
    let pxR = player.x + player.w;
    let pyB = player.y + player.h;

    if (currentPlayingSlot === 20 || currentPlayingSlot === 30) {
        // World 2 & 3 Boss Collision logic (Bouncy shield!)
        // Player NEVER dies upon contact with this boss, only bounces off exactly like a bouncy trampoline block with magnified momentum!
        let bxR = boss.x + boss.w;
        let byB = boss.y + boss.h;
        let overlapX = Math.min(pxR, bxR) - Math.max(player.x, boss.x);
        let overlapY = Math.min(pyB, byB) - Math.max(player.y, boss.y);
        let bounceColor = (currentPlayingSlot === 30) ? '#06b6d4' : '#ec4899';
        let subBounceColor = (currentPlayingSlot === 30) ? '#22d3ee' : '#f472b6';
        
        if (overlapX > 0 && overlapY > 0) {
            let originalVx = player.vx;
            let originalVy = player.vy;
            
            if (overlapX < overlapY) {
                // Lateral/Horizontal bouncy collision - AMPLIFIED!
                if (player.x + player.w / 2 < boss.x + boss.w / 2) {
                    player.x -= overlapX;
                    player.vx = -Math.max(Math.abs(originalVx) * 1.5, 20);
                } else {
                    player.x += overlapX;
                    player.vx = Math.max(Math.abs(originalVx) * 1.5, 20);
                }
                player.vy = -10.5; // robust diagonal kick upward
                player.wallBounceTimer = 18; // Wall bounce control lock matching bouncy block dynamics
                player.scaleX = 0.5; player.scaleY = 1.5;
                camera.shake = Math.max(camera.shake, Math.abs(originalVx) * 0.8 + 8);
                spawnParticles(player.x + player.w/2, player.y + player.h/2, bounceColor, 20, 5.5);
                SoundEffects.playBounce();
            } else {
                // Vertical bouncy collision - AMPLIFIED!
                if (player.y + player.h / 2 < boss.y + boss.h / 2) {
                    // Land on TOP of boss -> super trampoline bounce!
                    player.y -= overlapY;
                    let fallHeight = player.y - player.fallStartY;
                    let bounceSpeed = Math.max(Math.sqrt(Math.max(32, fallHeight)) * 2.2, 19);
                    player.vy = -bounceSpeed;
                    if (player.vy < -25) player.vy = -25;
                    
                    player.grounded = false;
                    player.isJumping = false;
                    player.coyoteTimer = 30;
                    player.scaleX = 0.4; player.scaleY = 1.6;
                    camera.shake = Math.max(camera.shake, bounceSpeed * 0.8 + 6);
                    spawnParticles(player.x + player.w/2, player.y + player.h, bounceColor, 30, 7.5);
                    SoundEffects.playBounce();
                } else {
                    // Bump head underneath boss -> bounce down hard!
                    player.y += overlapY;
                    let bounceSpeed = Math.max(Math.abs(originalVy) * 1.2, 14);
                    player.vy = bounceSpeed;
                    if (player.vy > 18) player.vy = 18;
                    
                    player.isJumping = false;
                    player.scaleY = 0.6; player.scaleX = 1.4;
                    camera.shake = Math.max(camera.shake, bounceSpeed * 0.6 + 4);
                    spawnParticles(player.x + player.w/2, player.y, subBounceColor, 20, 5.5);
                    SoundEffects.playBounce();
                }
            }
        }
        return;
    }

    if (!isLevel10) {
        // -------------------------
        // LEVEL 40 DEFAULT BEHAVIOR
        // -------------------------
        // Push out of the entire boundary of the Boss body
        let bxR = boss.x + boss.w;
        let byB = boss.y + boss.h;
        let overlapX = Math.min(pxR, bxR) - Math.max(player.x, boss.x);
        let overlapY = Math.min(pyB, byB) - Math.max(player.y, boss.y);

        // Check player collision with empty void cells in Boss body
        let size = 3;
        let centerR = 1;
        let centerC = 1;
        for (let r = 0; r < size; r++) {
            for (let c = 0; c < size; c++) {
                if (r === centerR && c === centerC) continue;
                
                if (boss.grid[r] && boss.grid[r][c] === 0) {
                    let cellX = boss.x + c * TILE_SIZE;
                    let cellY = boss.y + r * TILE_SIZE;
                    let centerLeft = cellX + 12;
                    let centerRight = cellX + 28;
                    let centerTop = cellY + 12;
                    let centerBottom = cellY + 28;
                    
                    if (!(pxR <= centerLeft || player.x >= centerRight || pyB <= centerTop || player.y >= centerBottom)) {
                        if (!player.dead && !player.won) {
                            player.dead = true;
                            deathTimer = 0;
                            spawnParticles(player.x + player.w / 2, player.y + player.h / 2, '#a855f7', 40, 8); // purple particles
                            SoundEffects.playHurt();
                        }
                    }
                }
            }
        }

        if (overlapX > 0 && overlapY > 0) {
            if (overlapX < overlapY) {
                if (player.x + player.w / 2 < boss.x + boss.w / 2) {
                    player.x -= overlapX;
                    player.vx = -Math.max(4, Math.abs(player.vx)) * 0.8;
                } else {
                    player.x += overlapX;
                    player.vx = Math.max(4, Math.abs(player.vx)) * 0.8;
                }
            } else {
                if (player.y + player.h / 2 < boss.y + boss.h / 2) {
                    player.y -= overlapY;
                    player.vy = 0;
                    player.grounded = true;
                    player.isJumping = false;
                } else {
                    player.y += overlapY;
                    player.vy = Math.max(0, player.vy);
                }
            }
        }
    } else {
        // -------------------------
        // LEVEL 10 DETAILED LOGIC
        // -------------------------
        let size = boss.grid.length;
        let centerR = boss.centerR ?? 10;
        let centerC = boss.centerC ?? 10;
        let minR = boss.minR ?? 0;
        let minC = boss.minC ?? 0;

        // 0. If the boss is jumping (using its jumping attack state), any contact with its solid tiles immediately kills the player
        if (boss.state === 'jumping') {
            for (let r = 0; r < size; r++) {
                for (let c = 0; c < size; c++) {
                    let val = boss.grid[r] ? boss.grid[r][c] : 0;
                    if (val > 0) {
                        let cellX = boss.x + (c - minC) * TILE_SIZE;
                        let cellY = boss.y + (r - minR) * TILE_SIZE;

                        let pxL = player.x;
                        let pxR = player.x + player.w;
                        let pyT = player.y;
                        let pyB = player.y + player.h;

                        // Check simple bounding box overlap between player and the boss cell
                        if (!(pxR <= cellX || pxL >= cellX + TILE_SIZE || pyB <= cellY || pyT >= cellY + TILE_SIZE)) {
                            if (!player.dead && !player.won) {
                                player.dead = true;
                                deathTimer = 0;
                                spawnParticles(player.x + player.w / 2, player.y + player.h / 2, '#ef4444', 40, 8); // red juicy impact splash
                                spawnParticles(player.x + player.w / 2, player.y + player.h / 2, '#eab308', 25, 6);
                                SoundEffects.playHurt();
                            }
                            return;
                        }
                    }
                }
            }
        }

        // 1. Check player engulfment inside any empty void slot of the boss (REMOVED: no longer kills player)

        // 2. Resolve pushing & crushing on solid blocks of the boss
        let overlappingSolidCells: { r: number, c: number, x: number, y: number }[] = [];
        for (let r = 0; r < size; r++) {
            for (let c = 0; c < size; c++) {
                let val = boss.grid[r] ? boss.grid[r][c] : 0;
                if (val > 0) {
                    let cellX = boss.x + (c - minC) * TILE_SIZE;
                    let cellY = boss.y + (r - minR) * TILE_SIZE;
                    
                    if (!(pxR <= cellX || player.x >= cellX + TILE_SIZE || pyB <= cellY || player.y >= cellY + TILE_SIZE)) {
                        overlappingSolidCells.push({ r, c, x: cellX, y: cellY });
                    }
                }
            }
        }

        if (overlappingSolidCells.length === 0) return;

        // Resolve overlaps cell-by-cell
        for (let cell of overlappingSolidCells) {
            pxR = player.x + player.w;
            pyB = player.y + player.h;
            let cxR = cell.x + TILE_SIZE;
            let cyB = cell.y + TILE_SIZE;

            let overlapX = Math.min(pxR, cxR) - Math.max(player.x, cell.x);
            let overlapY = Math.min(pyB, cyB) - Math.max(player.y, cell.y);

            if (overlapX > 0 && overlapY > 0) {
                if (overlapX < overlapY) {
                    if (player.x + player.w / 2 < cell.x + TILE_SIZE / 2) {
                        player.x -= overlapX;
                        player.vx = -Math.max(4, Math.abs(player.vx)) * 0.8;
                    } else {
                        player.x += overlapX;
                        player.vx = Math.max(4, Math.abs(player.vx)) * 0.8;
                    }
                } else {
                    if (player.y + player.h / 2 < cell.y + TILE_SIZE / 2) {
                        player.y -= overlapY;
                        player.vy = Math.min(player.vy, boss.vy); 
                        player.grounded = true;
                        player.isJumping = false;
                    } else {
                        player.y += overlapY;
                        player.vy = Math.max(player.vy, boss.vy) + 0.5;
                    }
                }
            }
        }
    }
}

function getBoxTiles(x: number, y: number, w: number, h: number) {
    let tiles = [];
    let left = Math.floor((x + 0.001) / TILE_SIZE);
    let right = Math.floor((x + w - 0.001) / TILE_SIZE);
    let top = Math.floor((y + 0.001) / TILE_SIZE);
    let bottom = Math.floor((y + h - 0.001) / TILE_SIZE);
    for (let r = top; r <= bottom; r++) {
        for (let c = left; c <= right; c++) {
            if (r >= 0 && r < level.length && c >= 0 && c < level[0].length) {
                tiles.push({ r, c, type: level[r][c] });
            }
        }
    }
    return tiles;
}

// DDA trace to find nearest block for eating
function getEatTarget(cx: number, cy: number, nx: number, ny: number) {
    if (currentPlayingSlot === 10 && boss.reorgTimer && boss.reorgTimer > 0) {
        return null;
    }
    for (let i = 1; i <= 20; i++) { // scan up to 65px
        let f = i / 20;
        let ptx = cx + nx * (65 * f);
        let pty = cy + ny * (65 * f);
        
        if (currentPlayingSlot === 10 && boss.active && !boss.dead && boss.state !== 'suspended') {
            let minR = boss.minR ?? 0;
            let minC = boss.minC ?? 0;
            let size = boss.grid.length;
            for (let r = 0; r < size; r++) {
                for (let c = 0; c < size; c++) {
                    let val = boss.grid[r] ? boss.grid[r][c] : 0;
                    if (val > 0) {
                        let cellX = boss.x + (c - minC) * TILE_SIZE;
                        let cellY = boss.y + (r - minR) * TILE_SIZE;
                        if (ptx >= cellX && ptx <= cellX + TILE_SIZE && pty >= cellY && pty <= cellY + TILE_SIZE) {
                            return { c, r, type: val, isBossCell: true };
                        }
                    }
                }
            }
        }
        
        let c = Math.floor(ptx / TILE_SIZE);
        let r = Math.floor(pty / TILE_SIZE);
        if (r >= 0 && r < level.length && c >= 0 && c < level[0].length && isEatable(level[r][c])) {
            return { c, r, type: level[r][c], isBossCell: false };
        }
    }
    return null;
}

function getSolidAABBs(rectX: number, rectY: number, rectW: number, rectH: number) {
    let list: { x: number, y: number, w: number, h: number, type: number, isBoss?: boolean }[] = [];
    
    // 1. Get solid from static level
    let left = Math.floor((rectX + 0.001) / TILE_SIZE);
    let right = Math.floor((rectX + rectW - 0.001) / TILE_SIZE);
    let top = Math.floor((rectY + 0.001) / TILE_SIZE);
    let bottom = Math.floor((rectY + rectH - 0.001) / TILE_SIZE);
    
    for (let r = top; r <= bottom; r++) {
        for (let c = left; c <= right; c++) {
            if (r >= 0 && r < level.length && c >= 0 && c < level[0].length) {
                let t = level[r][c];
                if (isSolid(t)) {
                    list.push({
                        x: c * TILE_SIZE,
                        y: r * TILE_SIZE,
                        w: TILE_SIZE,
                        h: TILE_SIZE,
                        type: t
                    });
                }
            }
        }
    }
    
    // 2. Get active blocks from World 1 Boss as collidable AABB elements!
    if (currentPlayingSlot === 10 && boss.active && !boss.dead && boss.state !== 'suspended') {
        let size = boss.grid.length;
        let minR = boss.minR ?? 0;
        let minC = boss.minC ?? 0;
        for (let r = 0; r < size; r++) {
            for (let c = 0; c < size; c++) {
                let val = boss.grid[r] ? boss.grid[r][c] : 0;
                if (val > 0) { // Solid tile in World 1 Boss block
                    let cellX = boss.x + (c - minC) * TILE_SIZE;
                    let cellY = boss.y + (r - minR) * TILE_SIZE;
                    
                    // Check intersection with bounding box
                    if (!(rectX + rectW <= cellX || rectX >= cellX + TILE_SIZE ||
                          rectY + rectH <= cellY || rectY >= cellY + TILE_SIZE)) {
                        list.push({
                            x: cellX,
                            y: cellY,
                            w: TILE_SIZE,
                            h: TILE_SIZE,
                            type: val,
                            isBoss: true
                        });
                    }
                }
            }
        }
    }
    
    return list;
}

function solveX(p: typeof player) {
    let isPlayerBouncy = p.hasBlock && p.carriedBlockType === 5;
    let originalVx = p.vx;
    p.x += p.vx;
    
    let blocks = getSolidAABBs(p.x, p.y, p.w, p.h);
    if (blocks.length > 0) {
        let hitBouncy = blocks.some(b => isBouncy(b.type));
        let isBouncyCollision = hitBouncy || isPlayerBouncy;
        let didBounce = false;

        if (p.vx > 0) {
            let hitX = Math.min(...blocks.map(b => b.x));
            p.x = hitX - p.w - 0.001;
            if (isBouncyCollision) {
                // Boost horizontal bounce restitution to 100% (1.0 multiplier)
                p.vx = -Math.max(Math.abs(originalVx) * 1.0, 5.5); // Minimum satisfying bounce speed
                didBounce = true;
            } else {
                p.vx = 0;
            }
            if (p.vy > 0 && isActionDown('right') && Math.random() < 0.3) spawnParticles(p.x + p.w, p.y + p.h/2, '#94a3b8', 1, 1);
        } else if (p.vx < 0) {
            let hitX = Math.max(...blocks.map(b => b.x + b.w));
            p.x = hitX + 0.001;
            if (isBouncyCollision) {
                // Boost horizontal bounce restitution to 100% (1.0 multiplier)
                p.vx = Math.max(Math.abs(originalVx) * 1.0, 5.5);
                didBounce = true;
            } else {
                p.vx = 0;
            }
            if (p.vy > 0 && isActionDown('left') && Math.random() < 0.3) spawnParticles(p.x, p.y + p.h/2, '#94a3b8', 1, 1);
        }
        
        if (didBounce) {
            p.scaleX = 0.6; p.scaleY = 1.4;
            p.wallBounceTimer = 12; // 12 frames of lock
            camera.shake = Math.max(camera.shake, Math.abs(originalVx) * 0.4 + 2);
            spawnParticles(p.x + p.w / 2, p.y + p.h / 2, isPlayerBouncy ? '#a855f7' : '#ec4899', 8, 3);
            SoundEffects.playBounce();
        } else if (Math.abs(p.vx) > MAX_SPEED * 0.7) {
            p.scaleX = 0.7; p.scaleY = 1.3;
            camera.shake = Math.max(camera.shake, Math.abs(p.vx) * 0.3);
        }

        if (!didBounce) {
            p.vx = 0;
        }
    }
}

function solveY(p: typeof player) {
    let isPlayerBouncy = p.hasBlock && p.carriedBlockType === 5;
    let originalVy = p.vy;
    p.y += p.vy;
    let wasGrounded = p.grounded;
    p.grounded = false;
    
    let blocks = getSolidAABBs(p.x, p.y, p.w, p.h);
    if (blocks.length > 0) {
        let hitBouncy = blocks.some(b => isBouncy(b.type));
        let isBouncyCollision = hitBouncy || isPlayerBouncy;
        let didBounce = false;

        if (p.vy > 0) {
            let hitY = Math.min(...blocks.map(b => b.y));
            p.y = hitY - p.h - 0.001;
            
            let fallHeight = p.y - p.fallStartY;
            if (isBouncyCollision && fallHeight >= 32) {
                // 100% perfect physical bounce based on fall height (conserves gravity potential energy perfectly)
                let bounceSpeed = Math.sqrt(fallHeight) * 1.0;
                if (bounceSpeed < 5) bounceSpeed = 5;
                p.vy = -bounceSpeed;
                if (p.vy < -25) p.vy = -25; // Raised speed cap to support higher leaps
                p.grounded = false;
                p.coyoteTimer = 24; // Gain coyote eligibility
                p.isJumping = false;
                p.scaleX = 0.6; p.scaleY = 1.4;
                camera.shake = Math.max(camera.shake, bounceSpeed * 0.5 + 2);
                spawnParticles(p.x + p.w / 2, p.y + p.h, isPlayerBouncy ? '#a855f7' : '#ec4899', 12, 4);
                didBounce = true;
                SoundEffects.playBounce();
            } else {
                p.grounded = true;
                p.isJumping = false;
                if (!wasGrounded) {
                    p.scaleX = 1.4; p.scaleY = 0.6;
                    spawnParticles(p.x + p.w / 2, p.y + p.h, '#4ade80', 8, 2.5); // splash
                    SoundEffects.playLand();
                    
                    // Fall death checks removed as requested
                }
                p.vy = 0;
            }
        } else if (p.vy < 0) {
            let hitY = Math.max(...blocks.map(b => b.y + b.h));
            p.y = hitY + 0.001;

            if (isBouncyCollision && originalVy <= -3.5) {
                // Ceilings also bounce at 100% velocity preservation
                p.vy = Math.abs(originalVy) * 1.0;
                if (p.vy > 20) p.vy = 20;
                p.isJumping = false;
                p.coyoteTimer = 24;
                p.scaleY = 0.8; p.scaleX = 1.2;
                camera.shake = Math.max(camera.shake, Math.abs(originalVy) * 0.3 + 1);
                spawnParticles(p.x + p.w / 2, p.y, isPlayerBouncy ? '#a855f7' : '#ec4899', 8, 3);
                didBounce = true;
                SoundEffects.playBounce();
            } else {
                p.scaleY = 0.8; p.scaleX = 1.2;
                p.vy = 0;
            }
        }
    }
}

// --- ENGINE LOGIC ---
function updatePhysics() {
    if (isActionJustPressed('restart')) {
        resetLevel();
        return;
    }
    
    // Freeze player input during boss entrance animation
    if (boss.active && boss.state === 'intro') {
        player.vx = 0;
        player.vy += 0.4; // apply standard gravity
        player.inBulletTime = false;
        solveY(player);
        return;
    }
    
    let px = player.x + player.w / 2;
    let py = player.y + player.h / 2;
    let mx = mouse.x + camera.x;
    let my = mouse.y + camera.y;

    let aimX = mx - px;
    let aimY = my - py;
    let mag = Math.hypot(aimX, aimY);

    let nAimX = player.facing; 
    let nAimY = 0;
    let aiming = false;

    if (mag > 0) {
        nAimX = aimX / mag;
        nAimY = aimY / mag;
        aiming = true;
    }

    let moveLeft = isActionDown('left');
    let moveRight = isActionDown('right');

    if (player.wallBounceTimer > 0) {
        player.wallBounceTimer--;
        moveLeft = false;
        moveRight = false;
    }

    let movX = 0;
    if (moveLeft) movX -= 1;
    if (moveRight) movX += 1;

    if (aiming) {
        player.facing = aimX > 0 ? 1 : -1;
    } else if (movX !== 0) {
        player.facing = movX;
    }

    let currentMaxSpeed = player.hasBlock ? MAX_SPEED * 0.8 : MAX_SPEED;

    if (player.wallBounceTimer > 0) {
        // preserve wall bounce velocity
    } else {
        if (moveLeft) {
            player.vx = -currentMaxSpeed;
        } else if (moveRight) {
            player.vx = currentMaxSpeed;
        } else {
            // User stopped pressing keys
            if (player.grounded) {
                let cx = player.x + player.w / 2;
                let tileCenter = Math.floor(cx / TILE_SIZE) * TILE_SIZE + TILE_SIZE / 2;
                let diffX = tileCenter - cx;
                
                // Subtle magnetic pull toward the nearest tile center to help alignment,
                // but we eliminate all sliding inertia instantly!
                // We weakened the pull range from 16 to 6, and pull speed from 0.4 to 0.25 to make it smoother and less aggressive.
                if (Math.abs(diffX) < 6) {
                    player.x += diffX * 0.25; // Smoother and weaker pull into place
                }
                player.vx = 0;
            } else {
                // Perfect pixel-perfect control in air
                player.vx = 0;
            }
        }
    }

    // Gravity
    player.vy += GRAVITY;
    if (player.vy > 12) {
        player.vy -= (player.vy - 12) * 0.15;
    }

    // Jump Buffering & Coyote (Supports W, Space, ArrowUp for perfect platformer feel)
    let jumpJustPressed = isActionJustPressed('jump');
    if (jumpJustPressed) player.jumpBuffer = 12; // Snappy jump buffer window (12 frames)
    if (player.jumpBuffer > 0) player.jumpBuffer--;
    
    let isPlayerBouncy = player.hasBlock && player.carriedBlockType === 5;
    let checkTiles = getBoxTiles(player.x, player.y, player.w, player.h + 24);
    let nearBouncy = checkTiles.some(t => isBouncy(t.type)) || (isPlayerBouncy && checkTiles.some(t => isSolid(t.type) && !isBouncy(t.type)));

    if (player.grounded || nearBouncy) {
        player.coyoteTimer = 4; // Snappy coyote time (4 frames)
    } else if (player.coyoteTimer > 0) {
        player.coyoteTimer--;
    }

    if (player.jumpBuffer > 0 && player.coyoteTimer > 0) {
        player.vy = -JUMP_FORCE;
        player.grounded = false;
        player.jumpBuffer = 0;
        player.coyoteTimer = 0;
        player.scaleX = 0.6;
        player.scaleY = 1.4;
        player.isJumping = true;
        spawnParticles(player.x + player.w / 2, player.y + player.h, '#fff', 12, 2.5);
        SoundEffects.playJump();
    }

    // Short hop - allow releasing any of the jump keys
    let jumpKeyHeld = isActionDown('jump');
    if (!jumpKeyHeld && player.vy < -4 && player.isJumping) player.vy = -4;

    // Eating Mechanism
    let target = getEatTarget(player.x + player.w / 2, player.y + player.h / 2, nAimX, nAimY);
    if (isActionDown('eat') && !player.hasBlock) {
        if (player.eatingProgress === 0) {
            if (target) {
                player.eatingTarget = { r: target.r, c: target.c, isBossCell: target.isBossCell };
                player.eatingProgress += 2 / 15;
            }
        } else if (player.eatingTarget) {
            let tr = player.eatingTarget.r;
            let tc = player.eatingTarget.c;
            let isBoss = player.eatingTarget.isBossCell;
            let blockType = isBoss ? (boss.grid[tr] && boss.grid[tr][tc]) : (level[tr] && level[tr][tc]);
            
            if (isEatable(blockType) || (isBoss && blockType === 3)) {
                let tx = isBoss ? (boss.x + (tc - (boss.minC ?? 0)) * TILE_SIZE + TILE_SIZE / 2) : (tc * TILE_SIZE + TILE_SIZE / 2);
                let ty = isBoss ? (boss.y + (tr - (boss.minR ?? 0)) * TILE_SIZE + TILE_SIZE / 2) : (tr * TILE_SIZE + TILE_SIZE / 2);
                let px = player.x + player.w / 2;
                let py = player.y + player.h / 2;
                let dist = Math.hypot(px - tx, py - ty);
                
                if (dist <= 85) {
                    player.eatingProgress += 2 / 15;
                    if (player.eatingProgress >= 1) {
                        if (isBoss) {
                            boss.grid[tr][tc] = 0;
                            if (currentPlayingSlot === 10) {
                                if (blockType === 3) {
                                    killWorld1BossAndRevealGoal();
                                } else {
                                    updateWorld1BossBounds();
                                }
                            }
                        } else {
                            level[tr][tc] = 0;
                        }
                        
                        // If center core was eaten, we don't carry any block, just win!
                        if (blockType !== 3) {
                            let prevCount = 0;
                            if (blockType === 1 || blockType === 5) prevCount = 0;
                            else if (blockType === 11 || blockType === 15) prevCount = 1;
                            else if (blockType === 12 || blockType === 25) prevCount = 2;
                            
                            let nextCount = prevCount + 1;
                            if (nextCount >= 3) {
                                // 🌟 THIRD swallowing: DIRECTLY DIGESTED
                                player.hasBlock = false;
                                player.inBulletTime = false;
                                player.carriedBlockType = 0;
                                player.carriedBlockEatenCount = 0;
                                let color = (blockType === 5 || blockType === 15 || blockType === 25) ? '#ec4899' : '#d97706';
                                spawnParticles(tx, ty, color, 30, 8);
                                camera.shake = Math.max(camera.shake, 8);
                            } else {
                                // Store the carried block
                                player.hasBlock = true;
                                player.waitingForShootRelease = true;
                                player.carriedBlockType = (blockType === 5 || blockType === 15 || blockType === 25) ? 5 : 1;
                                player.carriedBlockEatenCount = nextCount;
                                spawnParticles(tx, ty, player.carriedBlockType === 5 ? '#ec4899' : '#d97706', 15, 6);
                            }
                        }
                        
                        SoundEffects.playEat();
                        player.eatingProgress = 0;
                        player.eatingTarget = null;
                    }
                } else {
                    player.eatingProgress = 0;
                    player.eatingTarget = null;
                }
            } else {
                player.eatingProgress = 0;
                player.eatingTarget = null;
            }
        }
    } else {
        player.eatingProgress = 0;
        player.eatingTarget = null;
    }

    // Shooting Mechanism
    if (player.hasBlock) {
        if (player.waitingForShootRelease) {
            if (!isActionDown('shoot') && !isActionJustReleased('shoot')) {
                player.waitingForShootRelease = false;
            }
        }

        if (!player.waitingForShootRelease) {
            if (isActionDown('shoot')) {
                if (bulletTimeFeatureEnabled && !player.inBulletTime) {
                    player.inBulletTime = true;
                    SoundEffects.playEat(); // Feedback for entering bullet time
                }
            } else if (isActionJustReleased('shoot')) {
            if (player.inBulletTime) player.inBulletTime = false;
            let blockType = player.carriedBlockType || 1;
            let eatenCount = player.carriedBlockEatenCount || 1;
            player.hasBlock = false;
            player.carriedBlockType = 0;
            player.carriedBlockEatenCount = 0;
            let bx = player.x + nAimX * TILE_SIZE * 0.8;
            let by = player.y + nAimY * TILE_SIZE * 0.8;

            // Custom point-blank (貼臉射) safety: Backtrack the projectile center along the reverse aim vector 
            // until the center is in an empty cell so it can successfully place a block and recoil away.
            let startRx = bx + 20;
            let startRy = by + 20;
            let maxBackwardSteps = 45;
            let backtracked = false;
            for (let step = 0; step < maxBackwardSteps; step++) {
                let col = Math.floor(startRx / TILE_SIZE);
                let row = Math.floor(startRy / TILE_SIZE);
                let isCellSolid = true;
                if (row >= 0 && row < level.length && col >= 0 && col < level[0].length) {
                    isCellSolid = isSolid(level[row][col]);
                }
                if (isCellSolid) {
                    startRx -= nAimX * 1.5;
                    startRy -= nAimY * 1.5;
                    backtracked = true;
                } else {
                    break;
                }
            }
            if (backtracked) {
                bx = startRx - 20;
                by = startRy - 20;
            }
            
            projectiles.push({
                x: bx, y: by, vx: nAimX * BULLET_SPEED, vy: nAimY * BULLET_SPEED, w: 40, h: 40, dead: false,
                type: blockType, eatenCount: eatenCount, bounceCount: 0
            });
            SoundEffects.playShoot();

            // RECOIL!
            player.vx -= nAimX * RECOIL_FORCE * 1.8; // Strengthen horizontal recoil force!
            
            let ry = -nAimY * RECOIL_FORCE;
            if (ry < 0) {
                // We are recoiling UPWARD because of a downward shot. Make this consistent!
                if (player.vy > 0) {
                    player.vy = ry;
                } else {
                    player.vy = Math.min(player.vy, ry);
                }
            } else {
                player.vy += ry;
            }

            camera.shake = 12;
            player.isJumping = false;
            player.scaleX = 1.5;
            player.scaleY = 0.5;

            // Visual FX
            spawnParticles(player.x + player.w / 2, player.y + player.h / 2, '#fff', 15, 4);
        }
    }
    }

    if (player.grounded) {
        player.fallStartY = player.y;
    } else if (player.vy < 0) {
        // If rising (from jump, double-jump, or bounce), we only push the potential fall origin lower
        player.fallStartY = Math.max(player.fallStartY, player.y);
    }

    solveX(player);
    solveY(player);

    // Hazard & Goal checks
    let currentTiles = getBoxTiles(player.x, player.y, player.w, player.h); // alias fix
    let spikes = currentTiles.filter(t => isSpike(t.type) && checkSpikeCollision(player.x, player.y, player.w, player.h, t.r, t.c, t.type));
    if (spikes.length > 0 && !player.dead) {
        player.dead = true;
        deathTimer = 0;
        spawnParticles(player.x + player.w / 2, player.y + player.h / 2, '#22c55e', 40, 8);
        SoundEffects.playHurt();
    }
    
    // Out of bounds screen/map bottom void death
    if (player.y > level.length * TILE_SIZE && !player.dead && !player.won) {
        player.dead = true;
        deathTimer = 0;
        spawnParticles(player.x + player.w / 2, player.y + player.h / 2, '#4ade80', 30, 6);
        spawnParticles(player.x + player.w / 2, player.y + player.h / 2, '#ef4444', 40, 8);
        SoundEffects.playHurt();
    }

    let goals = currentTiles.filter(t => t.type === 3);
    if (goals.length > 0 && !player.won) {
        player.won = true;
        SoundEffects.playWin();
    }

    // Stretch based on vertical velocity if not grounded
    if (!player.grounded && Math.abs(player.scaleY - 1) < 0.2) {
        let stretch = Math.min(Math.abs(player.vy) * 0.04, 0.3);
        player.scaleX = 1 - stretch * 0.5;
        player.scaleY = 1 + stretch;
    }
    
    // Fall acceleration trails
    if (!player.grounded && Math.abs(player.vy) > 10 && Math.random() < 0.3) {
        spawnParticles(player.x + player.w / 2, player.y + player.h / 2, '#4ade80', 1, 0.5);
    }

    // Lerp scale back to normal
    player.scaleX += (1 - player.scaleX) * 0.15;
    player.scaleY += (1 - player.scaleY) * 0.15;
}

function updateProjectilesAndParticles() {
    // Bullets
    for (let i = projectiles.length - 1; i >= 0; i--) {
        let p = projectiles[i];
        p.vy += GRAVITY * 0.15;
        let rx = p.x + p.w / 2; let ry = p.y + p.h / 2;
        let dist = Math.hypot(p.vx, p.vy);
        let steps = Math.max(1, Math.ceil(dist / 10));

        let hit = false;
        let prevC = Math.floor(rx / TILE_SIZE); let prevR = Math.floor(ry / TILE_SIZE);

        for (let s = 1; s <= steps; s++) {
            let cx = rx + (p.vx * s / steps);
            let cy = ry + (p.vy * s / steps);
            let c = Math.floor(cx / TILE_SIZE);
            let r = Math.floor(cy / TILE_SIZE);

            if (p.isEnemy) {
                // Enemy projectile hitting player
                let pxL = player.x;
                let pxR = player.x + player.w;
                let pyT = player.y;
                let pyB = player.y + player.h;
                
                let pL = cx - p.w/2;
                let pR = cx + p.w/2;
                let pT = cy - p.h/2;
                let pB = cy + p.h/2;
                
                if (!(pR <= pxL || pL >= pxR || pB <= pyT || pT >= pyB)) {
                    if (!player.dead && !player.won) {
                        player.dead = true;
                        deathTimer = 0;
                        SoundEffects.playHurt();
                        spawnParticles(player.x + player.w/2, player.y + player.h/2, '#06b6d4', 35, 7.5);
                    }
                    hit = true;
                    break;
                }
                
                // Enemy projectile hitting environment
                if (r >= 0 && r < level.length && c >= 0 && c < level[0].length) {
                    let cellType = level[r][c];
                    if (isSolid(cellType)) {
                        // Solidify in previous cell if empty
                        if (prevR >= 0 && prevR < level.length && prevC >= 0 && prevC < level[0].length && level[prevR][prevC] === 0) {
                            let blockType = p.type || 6;
                            level[prevR][prevC] = blockType; // Solidify as its own block type (dirt or glass)!
                            let pColor = blockType === 1 ? '#d97706' : '#06b6d4';
                            spawnParticles(prevC * TILE_SIZE + 20, prevR * TILE_SIZE + 20, pColor, 20, 5);
                            SoundEffects.playLand();
                        } else {
                            let blockType = p.type || 6;
                            let pColor = blockType === 1 ? '#d97706' : '#06b6d4';
                            spawnParticles(cx, cy, pColor, 15, 4);
                        }
                        hit = true;
                        break;
                    }
                }
                prevC = c; prevR = r;
                continue; // Skip standard projectile logic for enemy projectiles!
            }

            // Prevent projectiles from passing through the BOSS (讓射出方塊不要穿過BOSS)
            if (boss.active && !boss.dead && boss.state !== 'suspended') {
                let pL = cx - p.w / 2;
                let pR = cx + p.w / 2;
                let pT = cy - p.h / 2;
                let pB = cy + p.h / 2;

                if (currentPlayingSlot === 30 && boss.state !== 'intro') {
                    let bossCenterX = boss.x + boss.w / 2;
                    let bossCenterY = boss.y + boss.h / 2;
                    
                    // 1. Check orbiting/detaching glass shields
                    let hitShieldIdx = -1;
                    
                    if (boss.shields) {
                        for (let idx = 0; idx < boss.shields.length; idx++) {
                            let s = boss.shields[idx];
                            if (s && s.active) {
                                if (Math.hypot(cx - s.cx, cy - s.cy) < 32) {
                                    hitShieldIdx = idx;
                                    break;
                                }
                            }
                        }
                    }
                    
                    if (hitShieldIdx !== -1) {
                        // Broken shield!
                        if (boss.shields) {
                            boss.shields[hitShieldIdx].active = false;
                        }
                        SoundEffects.playBounce();
                        spawnParticles(cx, cy, '#06b6d4', 20, 5); // cyan glass particles
                        hit = true;
                        break;
                    }
                    
                    // 2. Check Boss center Core directly
                    if (Math.hypot(cx - bossCenterX, cy - bossCenterY) < 60) {
                        // Boss is hit on core!
                        boss.durability = (boss.durability ?? 3) - 1;
                        boss.damageFlash = 1.0;
                        boss.scaleX = 1.45;
                        boss.scaleY = 0.6;
                        camera.shake = 25;
                        SoundEffects.playHurt();
                        spawnParticles(bossCenterX, bossCenterY, '#06b6d4', 30, 7);
                        spawnParticles(bossCenterX, bossCenterY, '#fbbf24', 20, 6); // gold spark
                        
                        if (boss.durability <= 0) {
                            // Defeated!
                            boss.dead = true;
                            boss.active = false;
                            camera.shake = 40;
                            SoundEffects.playWin();
                            spawnParticles(bossCenterX, bossCenterY, '#06b6d4', 60, 9);
                            spawnParticles(bossCenterX, bossCenterY, '#fbbf24', 40, 8);
                            spawnParticles(bossCenterX, bossCenterY, '#22d3ee', 40, 8);
                            
                            // Spawn Goal core in the middle of the arena
                            level[9][24] = 3; // Center Goal Block ($)
                            
                            // Elegant circle layout of glass blocks around Goal core as a trophy
                            let trophyR = 9;
                            let trophyC = 24;
                            for (let dr = -1; dr <= 1; dr++) {
                                for (let dc = -1; dc <= 1; dc++) {
                                    if (dr === 0 && dc === 0) continue;
                                    if (level[trophyR + dr]) {
                                        level[trophyR + dr][trophyC + dc] = 6; // surrounding glass blocks!
                                    }
                                }
                            }
                            
                            // Clear anything close for clean level ending
                            for (let r = 7; r <= 11; r++) {
                                for (let c = 20; c <= 28; c++) {
                                    if (level[r] && level[r][c] !== undefined) {
                                        let isTrophyPart = (r >= 8 && r <= 10 && c >= 23 && c <= 25);
                                        if (!isTrophyPart) {
                                            level[r][c] = 0;
                                        }
                                    }
                                }
                            }
                        } else {
                            // Reset shields based on new durability (3 -> 4, 2 -> 8, 1 -> 12)
                            let nextCount = boss.durability === 2 ? 8 : 12;
                            boss.shields = Array(nextCount).fill(null).map((_, idx) => ({
                                active: true,
                                state: 'orbit',
                                angleOffset: (idx * 2 * Math.PI) / nextCount,
                                radius: 85,
                                detachingTimer: 0,
                                cx: 0,
                                cy: 0
                            }));
                        }
                        
                        hit = true;
                        break;
                    }
                }
                
                if (currentPlayingSlot !== 30) {
                    let hitBossCell = false;
                    let isLevel10 = currentPlayingSlot === 10;
                    let size = isLevel10 ? boss.grid.length : 3;
                    let centerR = isLevel10 ? (boss.centerR ?? 10) : 1;
                    let centerC = isLevel10 ? (boss.centerC ?? 10) : 1;
                    let minR = isLevel10 ? (boss.minR ?? 0) : 0;
                    let minC = isLevel10 ? (boss.minC ?? 0) : 0;

                    for (let br = 0; br < size; br++) {
                        for (let bc = 0; bc < size; bc++) {
                            if (br === centerR && bc === centerC) continue; // Skip center Goal core
                            let cellX = isLevel10 ? (boss.x + (bc - minC) * TILE_SIZE) : (boss.x + bc * TILE_SIZE);
                            let cellY = isLevel10 ? (boss.y + (br - minR) * TILE_SIZE) : (boss.y + br * TILE_SIZE);
                            let cellXR = cellX + TILE_SIZE;
                            let cellYB = cellY + TILE_SIZE;
                            
                            if (!(pR <= cellX || pL >= cellXR || pB <= cellY || pT >= cellYB)) {
                                let targetR = br;
                                let targetC = bc;

                                let val = boss.grid[targetR] ? boss.grid[targetR][targetC] : 0;
                                if (val === 0) {
                                    // Check if adjacent to an active part of the boss to prevent floating disjoint blocks ("no 隔空沾")
                                    let isAdjacent = false;
                                    if (targetR > 0 && boss.grid[targetR - 1] && boss.grid[targetR - 1][targetC] > 0) isAdjacent = true;
                                    if (targetR < size - 1 && boss.grid[targetR + 1] && boss.grid[targetR + 1][targetC] > 0) isAdjacent = true;
                                    if (targetC > 0 && boss.grid[targetR][targetC - 1] > 0) isAdjacent = true;
                                    if (targetC < size - 1 && boss.grid[targetR][targetC + 1] > 0) isAdjacent = true;

                                    if (!isAdjacent) {
                                        continue;
                                    }

                                    // Empty cell: fill it!
                                    let placeType = p.type;
                                    if (p.type === 1) placeType = 12;
                                    else if (p.type === 5) placeType = 25;
                                    boss.grid[targetR][targetC] = placeType;
                                    p.dead = true;
                                    boss.damageFlash = 1;
                                    boss.scaleX = 1.35;
                                    boss.scaleY = 0.7;
                                    camera.shake = 12;
                                    SoundEffects.playEat();
                                    spawnParticles(cellX + TILE_SIZE / 2, cellY + TILE_SIZE / 2, p.type === 5 ? '#ec4899' : '#d97706', 15, 4);
                                    spawnParticles(cellX + TILE_SIZE / 2, cellY + TILE_SIZE / 2, '#a855f7', 15, 5);
                                    if (isLevel10) {
                                        updateWorld1BossBounds();
                                    }
                                    hit = true;
                                    hitBossCell = true;
                                    break;
                                } else {
                                    // Occupied cell: bounce off it!
                                    p.vx = -p.vx * 0.8 + (Math.random() - 0.5) * 2;
                                    p.vy = -Math.abs(p.vy) * 0.8 - 1.5; 
                                    p.y = cellY - p.h - 1;
                                    camera.shake = Math.max(camera.shake, 3);
                                    SoundEffects.playBounce();
                                    spawnParticles(cx, cy, val === 5 ? '#ec4899' : '#d97706', 8, 3);
                                    hit = true;
                                    hitBossCell = true;
                                    break;
                                }
                            }
                        }
                        if (hitBossCell) break;
                    }
                }
            }

            if (r >= 0 && r < level.length && c >= 0 && c < level[0].length) {
                let cellType = level[r][c];

                if (isSpike(cellType)) {
                    if (cellType === 7) { // Void gets filled
                        let tVal = p.type;
                        if (p.type === 1) tVal = 12;      // Dirt about to break
                        else if (p.type === 5) tVal = 25; // Bouncy about to break
                        level[r][c] = tVal;
                        spawnParticles(cx, cy, p.type === 5 ? '#ec4899' : '#d97706', 20, 5);
                    } else {
                        spawnParticles(cx, cy, p.type === 5 ? '#ec4899' : '#d97706', 15, 4);
                    }
                    hit = true;
                    break;
                }

                if (isSolid(cellType)) {
                    if (cellType === 6) { // Break glass AND consume projectile
                        level[r][c] = 0;
                        hit = true;
                        spawnParticles(cx, cy, '#06b6d4', 20, 5); // cyan glass shattering
                        break;
                    }

                    let hitBouncy = isBouncy(cellType);
                    let canBounce = false;

                    if (hitBouncy) {
                        canBounce = true;
                    } else if (p.type === 5 && p.bounceCount < 1) {
                        canBounce = true;
                        p.bounceCount++;
                    }

                    if (canBounce) {
                        // Determine reflection axes
                        let bounceX = false;
                        let bounceY = false;
                        if (c !== prevC) bounceX = true;
                        if (r !== prevR) bounceY = true;

                        if (!bounceX && !bounceY) {
                            bounceX = true;
                            bounceY = true;
                        }

                        if (bounceX) p.vx = -p.vx * 0.9;
                        if (bounceY) p.vy = -p.vy * 0.9;

                        // Reposition projectile slightly outside of the hit tile to avoid double-triggering
                        p.x = prevC * TILE_SIZE;
                        p.y = prevR * TILE_SIZE;

                        spawnParticles(cx, cy, '#ec4899', 12, 3);
                        camera.shake = Math.max(camera.shake, 2);
                        SoundEffects.playBounce();
                        break;
                    } else {
                        hit = true;
                        // Attempt to solidify securely in empty space
                        if (prevR >= 0 && prevR < level.length && prevC >= 0 && prevC < level[0].length && level[prevR][prevC] === 0) {
                            let cellL = prevC * TILE_SIZE; let cellR = prevC * TILE_SIZE + TILE_SIZE;
                            let cellT = prevR * TILE_SIZE; let cellB = prevR * TILE_SIZE + TILE_SIZE;
                            let pr = player.x + player.w; let pb = player.y + player.h;
                            
                            let playerOverlap = !(pr <= cellL || player.x >= cellR || pb <= cellT || player.y >= cellB);
                            
                            let tVal = p.type;
                            if (p.type === 1) { // Dirt
                                if (p.eatenCount === 1) tVal = 11;
                                else if (p.eatenCount === 2) tVal = 12;
                            } else if (p.type === 5) { // Bouncy
                                if (p.eatenCount === 1) tVal = 15;
                                else if (p.eatenCount === 2) tVal = 25;
                            }
                            level[prevR][prevC] = tVal;
                            spawnParticles(prevC * TILE_SIZE + 20, prevR * TILE_SIZE + 20, p.type === 5 ? '#ec4899' : '#d97706', 15, 3);
                            camera.shake = Math.max(camera.shake, 4);

                            if (playerOverlap) {
                                // Push the player in the direction opposite to the projectile's velocity 
                                // (recoil direction), ensuring they are always pushed to empty/safe space instead of into walls.
                                if (Math.abs(p.vx) > Math.abs(p.vy)) {
                                    if (p.vx > 0) {
                                        player.x = cellL - player.w - 0.1;
                                    } else {
                                        player.x = cellR + 0.1;
                                    }
                                } else {
                                    if (p.vy > 0) {
                                        player.y = cellT - player.h - 0.1;
                                    } else {
                                        player.y = cellB + 0.1;
                                    }
                                }
                            }
                        } else {
                            spawnParticles(rx, ry, p.type === 5 ? '#ec4899' : '#94a3b8', 20, 5);
                            camera.shake = Math.max(camera.shake, 3);
                        }
                        break;
                    }
                } else {
                    prevC = c; prevR = r;
                }
            } else {
                hit = true; break; // Out of bounds
            }
        }

        if (hit) projectiles.splice(i, 1);
        else { p.x += p.vx; p.y += p.vy; }
    }

    // Particles
    for (let i = particles.length - 1; i >= 0; i--) {
        let pt = particles[i];
        pt.vy += GRAVITY * 0.2;
        pt.x += pt.vx; pt.y += pt.vy;
        pt.life++;
        if (pt.life > pt.maxLife) particles.splice(i, 1);
    }
}

function drawBossEdgeSpikes(r: number, c: number, cellX: number, cellY: number, ctx: CanvasRenderingContext2D) {
    if (currentPlayingSlot !== 10) return;
    let size = boss.grid.length;
    let topVal = (r === 0 || !boss.grid[r - 1] || boss.grid[r - 1][c] === 0);
    let bottomVal = (r === size - 1 || !boss.grid[r + 1] || boss.grid[r + 1][c] === 0);
    let leftVal = (c === 0 || boss.grid[r][c - 1] === 0);
    let rightVal = (c === size - 1 || boss.grid[r][c + 1] === 0);

    ctx.fillStyle = '#ef4444'; // red-500 spike hazard color

    if (topVal) {
        ctx.beginPath();
        for (let s = 0; s < 3; s++) {
            let sw = TILE_SIZE / 3;
            ctx.moveTo(cellX + s * sw, cellY);
            ctx.lineTo(cellX + s * sw + sw / 2, cellY - 14);
            ctx.lineTo(cellX + s * sw + sw, cellY);
        }
        ctx.fill();
    }
    if (bottomVal) {
        ctx.beginPath();
        for (let s = 0; s < 3; s++) {
            let sw = TILE_SIZE / 3;
            ctx.moveTo(cellX + s * sw, cellY + TILE_SIZE);
            ctx.lineTo(cellX + s * sw + sw / 2, cellY + TILE_SIZE + 14);
            ctx.lineTo(cellX + s * sw + sw, cellY + TILE_SIZE);
        }
        ctx.fill();
    }
    if (leftVal) {
        ctx.beginPath();
        for (let s = 0; s < 3; s++) {
            let sh = TILE_SIZE / 3;
            ctx.moveTo(cellX, cellY + s * sh);
            ctx.lineTo(cellX - 14, cellY + s * sh + sh / 2);
            ctx.lineTo(cellX, cellY + s * sh + sh);
        }
        ctx.fill();
    }
    if (rightVal) {
        ctx.beginPath();
        for (let s = 0; s < 3; s++) {
            let sh = TILE_SIZE / 3;
            ctx.moveTo(cellX + TILE_SIZE, cellY + s * sh);
            ctx.lineTo(cellX + TILE_SIZE + 14, cellY + s * sh + sh / 2);
            ctx.lineTo(cellX + TILE_SIZE, cellY + s * sh + sh);
        }
        ctx.fill();
    }
}

function drawSpecificTile(t: number, x: number, y: number, ctx: CanvasRenderingContext2D) {
    if (t === 1) { // Eatable block (Dirt/Amber)
        ctx.fillStyle = '#d97706'; // amber-600
        ctx.fillRect(x, y, TILE_SIZE, TILE_SIZE);
        ctx.strokeStyle = '#b45309'; // amber-700
        ctx.lineWidth = 3;
        ctx.strokeRect(x + 1.5, y + 1.5, TILE_SIZE - 3, TILE_SIZE - 3);
    } else if (t === 11) { // Dirt block eaten 1 time
        ctx.fillStyle = '#b45309'; // darker amber
        ctx.fillRect(x, y, TILE_SIZE, TILE_SIZE);
        ctx.strokeStyle = '#92400e'; // dark brown
        ctx.lineWidth = 3;
        ctx.strokeRect(x + 1.5, y + 1.5, TILE_SIZE - 3, TILE_SIZE - 3);
        
        // Slime overlay (translucent green blobs/streaks)
        ctx.fillStyle = 'rgba(22, 163, 74, 0.25)';
        ctx.fillRect(x + 4, y + 4, TILE_SIZE - 8, TILE_SIZE - 8);

        // A crack
        ctx.strokeStyle = '#22c55e'; // lime crack
        ctx.lineWidth = 2;
        ctx.beginPath();
        ctx.moveTo(x + 5, y + 10);
        ctx.lineTo(x + 15, y + 25);
        ctx.lineTo(x + 35, y + 30);
        ctx.stroke();
    } else if (t === 12) { // Dirt block eaten 2 times
        ctx.fillStyle = '#78350f'; // very dark brown
        ctx.fillRect(x, y, TILE_SIZE, TILE_SIZE);
        ctx.strokeStyle = '#22c55e'; // slime green border
        ctx.lineWidth = 2.5;
        ctx.strokeRect(x + 1.5, y + 1.5, TILE_SIZE - 3, TILE_SIZE - 3);
        
        // intensive bubbling slime
        ctx.fillStyle = 'rgba(34, 197, 94, 0.45)';
        ctx.fillRect(x + 6, y + 6, TILE_SIZE - 12, TILE_SIZE - 12);

        // Multiple glowing cracks
        ctx.strokeStyle = '#a3e635'; // glowing lime
        ctx.lineWidth = 1.8;
        ctx.beginPath();
        ctx.moveTo(x + 5, y + 5);
        ctx.lineTo(x + 20, y + 18);
        ctx.lineTo(x + 8, y + 32);
        ctx.moveTo(x + 35, y + 5);
        ctx.lineTo(x + 22, y + 22);
        ctx.lineTo(x + 30, y + 35);
        ctx.stroke();
    } else if (t === 5) { // Bouncy Block (Pink/Violet)
        ctx.fillStyle = '#ec4899'; // pink-500
        ctx.fillRect(x, y, TILE_SIZE, TILE_SIZE);
        ctx.strokeStyle = '#db2777'; // pink-600
        ctx.lineWidth = 3;
        ctx.strokeRect(x + 1.5, y + 1.5, TILE_SIZE - 3, TILE_SIZE - 3);

        // Draw a bouncy cross/circle indicator
        ctx.strokeStyle = '#fbcfe8';
        ctx.lineWidth = 2.5;
        ctx.beginPath();
        ctx.arc(x + TILE_SIZE / 2, y + TILE_SIZE / 2, 8, 0, Math.PI * 2);
        ctx.stroke();
    } else if (t === 15) { // Bouncy block eaten 1 time
        ctx.fillStyle = '#be185d'; // darker pink
        ctx.fillRect(x, y, TILE_SIZE, TILE_SIZE);
        ctx.strokeStyle = '#9d174d'; // deeper border
        ctx.lineWidth = 3;
        ctx.strokeRect(x + 1.5, y + 1.5, TILE_SIZE - 3, TILE_SIZE - 3);
        
        // slime mark
        ctx.fillStyle = 'rgba(22, 163, 74, 0.25)';
        ctx.fillRect(x + 4, y + 4, TILE_SIZE - 8, TILE_SIZE - 8);

        // cracked inner circle
        ctx.strokeStyle = '#fbcfe8';
        ctx.lineWidth = 2;
        ctx.beginPath();
        ctx.arc(x + TILE_SIZE / 2, y + TILE_SIZE / 2, 8, 0.2, Math.PI * 1.5);
        ctx.stroke();

        // Lime green cracks
        ctx.strokeStyle = '#22c55e';
        ctx.lineWidth = 1.5;
        ctx.beginPath();
        ctx.moveTo(x + 5, y + 8);
        ctx.lineTo(x + 20, y + 15);
        ctx.stroke();
    } else if (t === 25) { // Bouncy block eaten 2 times
        ctx.fillStyle = '#831843'; // deep maroon
        ctx.fillRect(x, y, TILE_SIZE, TILE_SIZE);
        ctx.strokeStyle = '#22c55e'; // slime green border
        ctx.lineWidth = 2.5;
        ctx.strokeRect(x + 1.5, y + 1.5, TILE_SIZE - 3, TILE_SIZE - 3);
        
        // Slime corrosion blob
        ctx.fillStyle = 'rgba(34, 197, 94, 0.45)';
        ctx.fillRect(x + 6, y + 6, TILE_SIZE - 12, TILE_SIZE - 12);

        // broken circle
        ctx.strokeStyle = '#a3e635';
        ctx.lineWidth = 1.5;
        ctx.beginPath();
        ctx.arc(x + TILE_SIZE / 2, y + TILE_SIZE / 2, 8, 1, 3);
        ctx.stroke();

        // Bubbling glowing cracks
        ctx.strokeStyle = '#a3e635';
        ctx.lineWidth = 2;
        ctx.beginPath();
        ctx.moveTo(x + 4, y + 36);
        ctx.lineTo(x + 20, y + 18);
        ctx.lineTo(x + 36, y + 2);
        ctx.stroke();
    } else if (t === 2) { // Steel (Slate)
        ctx.fillStyle = '#475569'; // slate-600
        ctx.fillRect(x, y, TILE_SIZE, TILE_SIZE);
        ctx.fillStyle = '#334155'; // slate-700
        ctx.fillRect(x + 6, y + 6, TILE_SIZE - 12, TILE_SIZE - 12);
    } else if (t === 4) { // Spikes Up
        ctx.fillStyle = '#ef4444'; // red-500
        ctx.beginPath();
        for (let s = 0; s < 3; s++) {
            let sw = TILE_SIZE / 3;
            ctx.moveTo(x + s * sw, y + TILE_SIZE);
            ctx.lineTo(x + s * sw + sw / 2, y + TILE_SIZE - 16);
            ctx.lineTo(x + s * sw + sw, y + TILE_SIZE);
        }
        ctx.fill();
    } else if (t === 41) { // Spikes Right
        ctx.fillStyle = '#ef4444'; // red-500
        ctx.beginPath();
        for (let s = 0; s < 3; s++) {
            let sh = TILE_SIZE / 3;
            ctx.moveTo(x, y + s * sh);
            ctx.lineTo(x + 16, y + s * sh + sh / 2);
            ctx.lineTo(x, y + s * sh + sh);
        }
        ctx.fill();
    } else if (t === 42) { // Spikes Down
        ctx.fillStyle = '#ef4444'; // red-500
        ctx.beginPath();
        for (let s = 0; s < 3; s++) {
            let sw = TILE_SIZE / 3;
            ctx.moveTo(x + s * sw, y);
            ctx.lineTo(x + s * sw + sw / 2, y + 16);
            ctx.lineTo(x + s * sw + sw, y);
        }
        ctx.fill();
    } else if (t === 43) { // Spikes Left
        ctx.fillStyle = '#ef4444'; // red-500
        ctx.beginPath();
        for (let s = 0; s < 3; s++) {
            let sh = TILE_SIZE / 3;
            ctx.moveTo(x + TILE_SIZE, y + s * sh);
            ctx.lineTo(x + TILE_SIZE - 16, y + s * sh + sh / 2);
            ctx.lineTo(x + TILE_SIZE, y + s * sh + sh);
        }
        ctx.fill();
    } else if (t === 6) { // Breakable Glass
        ctx.fillStyle = 'rgba(6, 182, 212, 0.15)'; // cyan-500
        ctx.fillRect(x, y, TILE_SIZE, TILE_SIZE);
        ctx.strokeStyle = 'rgba(6, 182, 212, 0.6)';
        ctx.lineWidth = 1;
        ctx.strokeRect(x + 1, y + 1, TILE_SIZE - 2, TILE_SIZE - 2);
        ctx.beginPath();
        ctx.moveTo(x + 4, y + 4);
        ctx.lineTo(x + TILE_SIZE - 4, y + TILE_SIZE - 4);
        ctx.moveTo(x + TILE_SIZE - 4, y + 4);
        ctx.lineTo(x + 4, y + TILE_SIZE - 4);
        ctx.stroke();
    } else if (t === 7) { // Fillable Void
        // Dark purple-black cosmic background
        ctx.fillStyle = '#0a0518'; 
        ctx.fillRect(x, y, TILE_SIZE, TILE_SIZE);
        
        ctx.strokeStyle = '#a855f7'; // purple-500 dashed outline
        ctx.setLineDash([4, 4]);
        ctx.lineWidth = 2;
        ctx.strokeRect(x + 3, y + 3, TILE_SIZE - 6, TILE_SIZE - 6);
        ctx.setLineDash([]);
        
        // Dynamic purple pulse energy
        let pulse = Math.sin(Date.now() / 150) * 0.15 + 0.35;
        ctx.fillStyle = `rgba(168, 85, 247, ${pulse})`;
        ctx.fillRect(x + 9, y + 9, TILE_SIZE - 18, TILE_SIZE - 18);
        
        // Dangerous bright purple core (exact 16x16 collision box)
        ctx.fillStyle = '#c084fc'; // bright purple
        ctx.fillRect(x + 12, y + 12, TILE_SIZE - 24, TILE_SIZE - 24);
        
        // High-energy focus core
        ctx.fillStyle = '#f3e8ff'; // bright white-purple
        ctx.fillRect(x + 16, y + 16, TILE_SIZE - 32, TILE_SIZE - 32);
    } else if (t === 3) { // Goal
        ctx.fillStyle = '#fbbf24'; // amber-400
        ctx.fillRect(x + 4, y + 4, TILE_SIZE - 8, TILE_SIZE - 8);
        ctx.fillStyle = '#fef3c7'; // amber-100
        ctx.fillRect(x + 12, y + 12, TILE_SIZE - 24, TILE_SIZE - 24);
    }
}

// --- RENDERING ---
function draw(ctx: CanvasRenderingContext2D, canvas: HTMLCanvasElement) {
    // Clear & Backdrop
    ctx.fillStyle = '#0f172a'; // slate-950
    ctx.fillRect(0, 0, canvas.width, canvas.height);

    ctx.save();
    
    // Scale drawing coordinate space to zoom out by 2 tiles
    ctx.scale(CAMERA_ZOOM, CAMERA_ZOOM);
    
    if (!editState.active) {
        // Camera smooth follow
        let targetCamX = player.x + player.w / 2 - VIEW_WIDTH / 2;
        camera.x += (targetCamX - camera.x) * 0.1;
        
        if (level.length * TILE_SIZE > VIEW_HEIGHT) {
            let targetCamY = player.y + player.h / 2 - VIEW_HEIGHT / 2;
            camera.y += (targetCamY - camera.y) * 0.1;
        } else {
            camera.y = 0;
        }
    }
    camera.x = Math.max(0, Math.min(camera.x, level[0].length * TILE_SIZE - VIEW_WIDTH));
    if (level.length * TILE_SIZE > VIEW_HEIGHT) {
        camera.y = Math.max(0, Math.min(camera.y, level.length * TILE_SIZE - VIEW_HEIGHT));
    } else {
        camera.y = 0;
    }
    
    ctx.translate(-camera.x, -camera.y);

    if (camera.shake > 0.5) {
        ctx.translate((Math.random() - 0.5) * camera.shake, (Math.random() - 0.5) * camera.shake);
        camera.shake *= 0.9;
    } else {
        camera.shake = 0;
    }

    // Subtle Grid Background removed for cleaner aesthetic

    // Render drifting cave spores (parallax background starfield)
    for (let st of bgStars) {
        st.x = (st.x - st.speed) % 5000;
        if (st.x < 0) st.x += 5000;

        let levelW = level[0]?.length ? level[0].length * TILE_SIZE : 2000;
        let levelH = level?.length ? level.length * TILE_SIZE : 1000;

        let parallaxX = (st.x - camera.x * (st.size * 0.12)) % (levelW + 400);
        if (parallaxX < -50) parallaxX += (levelW + 400);

        let parallaxY = (st.y - camera.y * (st.size * 0.08)) % (levelH + 400);
        if (parallaxY < -50) parallaxY += (levelH + 400);

        ctx.fillStyle = st.color;
        ctx.fillRect(parallaxX, parallaxY, st.size, st.size);
    }

    // Tiles (with frustum culling)
    let startRow = Math.max(0, Math.floor(camera.y / TILE_SIZE) - 1);
    let endRow = Math.min(level.length - 1, Math.ceil((camera.y + VIEW_HEIGHT) / TILE_SIZE) + 1);
    let startCol = Math.max(0, Math.floor(camera.x / TILE_SIZE) - 1);
    let endCol = Math.min(level[0].length - 1, Math.ceil((camera.x + VIEW_WIDTH) / TILE_SIZE) + 1);

    for (let r = startRow; r <= endRow; r++) {
        for (let c = startCol; c <= endCol; c++) {
            let t = level[r][c];
            if (t === 0) continue;
            
            let x = c * TILE_SIZE; let y = r * TILE_SIZE;
            drawSpecificTile(t, x, y, ctx);
        }
    }

    // Target Aiming indicators
    let px = player.x + player.w / 2;
    let py = player.y + player.h / 2;
    let mx = mouse.x + camera.x;
    let my = mouse.y + camera.y;

    let aimX = mx - px;
    let aimY = my - py;
    let mag = Math.hypot(aimX, aimY);
    
    let nAimX = aimX / mag; let nAimY = aimY / mag;
    let aiming = mag > 0;

    if (!player.dead && !player.won) {
        if (player.hasBlock) {
            // Trajectory Line
            if (aiming && isActionDown('shoot') && !player.waitingForShootRelease && (!bulletTimeFeatureEnabled || player.inBulletTime)) {
                ctx.strokeStyle = 'rgba(255, 255, 255, 0.4)';
                ctx.setLineDash([6, 6]);
                ctx.lineWidth = 3;
                ctx.beginPath();
                
                let tx = player.x + player.w / 2;
                let ty = player.y + player.h / 2;
                let tvx = nAimX * BULLET_SPEED;
                let tvy = nAimY * BULLET_SPEED;
                
                ctx.moveTo(tx, ty);
                for (let i = 0; i < 40; i++) {
                    tvy += GRAVITY * 0.15;
                    tx += tvx;
                    ty += tvy;
                    ctx.lineTo(tx, ty);
                    
                    let c = Math.floor(tx / TILE_SIZE);
                    let r = Math.floor(ty / TILE_SIZE);
                    if (r >= 0 && r < level.length && c >= 0 && c < level[0].length && (level[r][c] === 1 || level[r][c] === 2 || level[r][c] === 5)) {
                        break;
                    }
                }
                ctx.stroke();
                ctx.setLineDash([]);
            }
        }
    }

    // Projectiles
    for (let p of projectiles) {
        if (p.type === 6) {
            ctx.fillStyle = 'rgba(165, 243, 252, 0.75)'; // cyan glass look
            ctx.fillRect(p.x, p.y, p.w, p.h);
            ctx.strokeStyle = '#06b6d4'; // clean cyan outline
            ctx.lineWidth = 2;
            ctx.strokeRect(p.x + 1, p.y + 1, p.w - 2, p.h - 2);
            
            // Diagonal shiny lines
            ctx.strokeStyle = 'rgba(255, 255, 255, 0.85)';
            ctx.lineWidth = 1.2;
            ctx.beginPath();
            ctx.moveTo(p.x + 4, p.y + 4);
            ctx.lineTo(p.x + p.w - 4, p.y + p.h - 4);
            ctx.moveTo(p.x + p.w - 4, p.y + 4);
            ctx.lineTo(p.x + 4, p.y + p.h - 4);
            ctx.stroke();
        } else if (p.type === 5) {
            ctx.fillStyle = '#ec4899'; // pink-500
            ctx.fillRect(p.x, p.y, p.w, p.h);
            ctx.strokeStyle = '#db2777'; // pink-600
            ctx.lineWidth = 3;
            ctx.strokeRect(p.x+1.5, p.y+1.5, p.w-3, p.h-3);
        } else {
            ctx.fillStyle = '#d97706'; // amber-600
            ctx.fillRect(p.x, p.y, p.w, p.h);
            ctx.strokeStyle = '#b45309'; // amber-700
            ctx.lineWidth = 3;
            ctx.strokeRect(p.x+1.5, p.y+1.5, p.w-3, p.h-3);
        }
    }

    // Player
    if (!player.dead) {
        ctx.save();
        ctx.translate(player.x + player.w / 2, player.y + player.h);
        
        if (player.grounded && Math.abs(player.vx) > 0.5) {
            let wobble = Math.sin(Date.now() / 60) * 0.1;
            ctx.rotate(wobble);
        }

        ctx.scale(player.scaleX, player.scaleY);

        let bloatW = 0;
        let bloatH = 0;

        ctx.fillStyle = 'rgba(34, 197, 94, 0.9)'; // slime green
        ctx.beginPath();
        ctx.roundRect(-(player.w + bloatW) / 2, -player.h - bloatH, player.w + bloatW, player.h + bloatH, player.hasBlock ? 16 : 12);
        ctx.fill();
        ctx.strokeStyle = '#16a34a';
        ctx.lineWidth = 2;
        ctx.stroke();

        if (player.hasBlock) {
            let bx = -10;
            let by = -player.h / 2 - 10;
            let count = player.carriedBlockEatenCount || 1;
            
            if (player.carriedBlockType === 6) {
                ctx.fillStyle = 'rgba(165, 243, 252, 0.75)';
                ctx.fillRect(bx, by, 20, 20);
                ctx.strokeStyle = '#06b6d4';
                ctx.lineWidth = 1.5;
                ctx.strokeRect(bx + 0.5, by + 0.5, 19, 19);
                
                // mini cross inside carried block
                ctx.strokeStyle = 'rgba(255, 255, 255, 0.8)';
                ctx.lineWidth = 1.0;
                ctx.beginPath();
                ctx.moveTo(bx + 3, by + 3);
                ctx.lineTo(bx + 17, by + 17);
                ctx.moveTo(bx + 17, by + 3);
                ctx.lineTo(bx + 3, by + 17);
                ctx.stroke();
            } else if (player.carriedBlockType === 5) {
                ctx.fillStyle = count === 2 ? '#831843' : count === 1 ? '#be185d' : '#ec4899';
                ctx.fillRect(bx, by, 20, 20);
                ctx.strokeStyle = count === 2 ? '#22c55e' : '#fbcfe8';
                ctx.lineWidth = 1.5;
                ctx.strokeRect(bx + 0.5, by + 0.5, 19, 19);
                
                if (count >= 1) {
                    ctx.fillStyle = 'rgba(22, 163, 74, 0.45)';
                    ctx.fillRect(bx + 3, by + 3, 14, 14);
                }
            } else {
                ctx.fillStyle = count === 2 ? '#78350f' : count === 1 ? '#b45309' : '#d97706';
                ctx.fillRect(bx, by, 20, 20);
                ctx.strokeStyle = count === 2 ? '#22c55e' : '#f59e0b';
                ctx.lineWidth = 1.5;
                ctx.strokeRect(bx + 0.5, by + 0.5, 19, 19);
                
                if (count >= 1) {
                    ctx.fillStyle = 'rgba(22, 163, 74, 0.45)';
                    ctx.fillRect(bx + 3, by + 3, 14, 14);
                }
            }
        }

        // Eyes
        let eyeMag = Math.min(1, mag / 150);
        let ex = nAimX * 6 * eyeMag;
        if (aiming === false) ex = player.facing * 4;
        let ey = nAimY * 6 * eyeMag;
        let blink = Date.now() % 4000 < 150;

        let eyeSpacing = 5; 

        if (blink) {
            ctx.fillStyle = '#0f172a';
            ctx.fillRect(ex - eyeSpacing - 1, -player.h + 14 + ey, 6, 2);
            ctx.fillRect(ex + eyeSpacing - 5, -player.h + 14 + ey, 6, 2);
        } else {
            ctx.fillStyle = '#fff';
            ctx.fillRect(ex - eyeSpacing - 1, -player.h + 10 + ey, 6, 10);
            ctx.fillRect(ex + eyeSpacing - 5, -player.h + 10 + ey, 6, 10);
            ctx.fillStyle = '#0f172a';
            let px = nAimX * 2;
            let py = nAimY * 2;
            if (aiming === false) px = player.facing * 2;
            ctx.fillRect(ex - eyeSpacing + 1 + px, -player.h + 13 + ey + py, 2, 4);
            ctx.fillRect(ex + eyeSpacing - 3 + px, -player.h + 13 + ey + py, 2, 4);
        }

        ctx.restore();
    }

    // Particles
    for (let pt of particles) {
        ctx.globalAlpha = 1 - pt.life / pt.maxLife;
        ctx.fillStyle = pt.color;
        ctx.fillRect(pt.x - pt.w/2, pt.y - pt.w/2, pt.w, pt.w);
    }
    ctx.globalAlpha = 1;

    // --- RENDER FALLING BLOCKS & BOSS ENCOUNTER ---
    
    // 1. Falling blocks trail & bodies
    for (let fb of fallingBlocks) {
        if (fb.delay !== undefined && fb.delay > 0) {
            // WARNING TRAJECTORY STAGE (Pulsing high-visibility red laser warning shaft)
            let pulseAlpha = 0.2 + 0.25 * Math.abs(Math.sin(fb.delay * 0.25)); // pulsing brightness
            
            // Draw background alert column
            ctx.fillStyle = `rgba(239, 68, 68, ${pulseAlpha})`;
            ctx.fillRect(fb.x - 20, 0, TILE_SIZE, level.length * TILE_SIZE); 

            // Draw side red neon lasers to outline the trajectory perfectly
            ctx.strokeStyle = `rgba(239, 68, 68, ${pulseAlpha * 1.8})`;
            ctx.lineWidth = 2.5;
            ctx.beginPath();
            ctx.moveTo(fb.x - 20, 0);
            ctx.lineTo(fb.x - 20, level.length * TILE_SIZE);
            ctx.moveTo(fb.x + 20, 0);
            ctx.lineTo(fb.x + 20, level.length * TILE_SIZE);
            ctx.stroke();

            // Intermittent bright flashing alert text "⚠️ DANGER ⚠️" or warning sign at the top of the shaft
            ctx.fillStyle = '#ef4444';
            ctx.font = 'bold 16px sans-serif';
            ctx.textAlign = 'center';
            ctx.textBaseline = 'middle';
            ctx.fillText("⚠️", fb.x, 20);
        } else {
            // ACTIVE FALLING BLOCK STAGE
            // Warning path/shaft below the falling block to highlight landing line in advance
            ctx.fillStyle = 'rgba(239, 68, 68, 0.12)';
            ctx.fillRect(fb.x - 20, fb.y + 20, TILE_SIZE, 600);

            // Uniform black block body
            ctx.fillStyle = '#000000';
            ctx.fillRect(fb.x - 20, fb.y - 20, TILE_SIZE, TILE_SIZE);
            
            ctx.strokeStyle = '#ef4444'; // dangerous red glowing outline
            ctx.lineWidth = 3;
            ctx.strokeRect(fb.x - 18.5, fb.y - 18.5, TILE_SIZE - 3, TILE_SIZE - 3);

            // Skull icon showing instant danger of death (碰撞即死)
            ctx.fillStyle = '#ef4444';
            ctx.font = 'bold 13px sans-serif';
            ctx.textAlign = 'center';
            ctx.textBaseline = 'middle';
            ctx.fillText("💀", fb.x, fb.y);
        }
    }

    // 2. Boss main renderer
    if (boss.active && !boss.dead) {
        // Draw ejection trajectory if charging
        if (boss.state === 'charging') {
            let simX = boss.x + boss.w / 2;
            let simY = boss.y + boss.h / 2;
            let simVy = 0;
            let simVx = 0;
            let trajectoryColor = '#db2777'; // Fallback pink
            let simBouncesRemaining = 0;
            let gravity = 0.2;
            
            if (currentPlayingSlot === 20 || currentPlayingSlot === 10) {
                simVy = -18;
                let dx = (player.x + player.w/2) - (boss.x + boss.w/2);
                let computedVx = dx * 0.035;
                simVx = (dx >= 0 ? 1 : -1) * Math.max(2.5, Math.min(14, Math.abs(computedVx)));
                trajectoryColor = currentPlayingSlot === 20 ? '#db2777' : '#f59e0b';
                
                if (currentPlayingSlot === 20) {
                    let lostD = 3 - (boss.durability ?? 3);
                    simBouncesRemaining = 3 + 2 * lostD;
                }
            } else if (currentPlayingSlot === 40) {
                simVy = -14.0 * 1.732;
                let dx = (player.x + player.w/2) - (boss.x + boss.w/2);
                let computedVx = dx * 0.03;
                simVx = (dx >= 0 ? 1 : -1) * Math.max(2.0, Math.min(12, Math.abs(computedVx)));
                trajectoryColor = '#a855f7';
            }
            
            let pts: {x: number, y: number}[] = [{ x: simX, y: simY }];
            let localW = boss.w || 40;
            let localH = boss.h || 40;
            
            // Run simulation for flight path up to 350 frames to show a significantly longer path
            for (let step = 0; step < 350; step++) {
                simVy += gravity;
                simX += simVx;
                
                // Horiz tile collision for simulation - precise match to real physics boundaries
                let colStart = Math.max(0, Math.floor((simX - localW / 2) / TILE_SIZE));
                let colEnd = Math.min(level[0].length - 1, Math.floor((simX + localW / 2 - 1) / TILE_SIZE));
                let rowStart = Math.max(0, Math.floor((simY - localH / 2) / TILE_SIZE));
                let rowEnd = Math.min(level.length - 1, Math.floor((simY + localH / 2 - 1) / TILE_SIZE));
                
                let hitSolid = false;
                let targetColForSim = -1;
                for (let r = rowStart; r <= rowEnd; r++) {
                    for (let c = colStart; c <= colEnd; c++) {
                        if (isSolid(level[r][c])) {
                            hitSolid = true;
                            targetColForSim = c;
                            break;
                        }
                    }
                    if (hitSolid) break;
                }
                
                if (hitSolid) {
                    if (simVx > 0) {
                        simX = targetColForSim * TILE_SIZE - localW / 2 - 0.1;
                    } else if (simVx < 0) {
                        simX = (targetColForSim + 1) * TILE_SIZE + localW / 2 + 0.1;
                    }
                    simVx = -simVx * 1.05;
                }
                
                simY += simVy;
                
                // Wall bounds - precise match to real bounds
                if (simX < TILE_SIZE + localW / 2) {
                    simX = TILE_SIZE + localW / 2;
                    simVx = -simVx * 1.05;
                } else if (simX > level[0].length * TILE_SIZE - TILE_SIZE - localW / 2) {
                    simX = level[0].length * TILE_SIZE - TILE_SIZE - localW / 2;
                    simVx = -simVx * 1.05;
                }
                
                // Ceiling bounds - precise match to real bounds
                if (simY < TILE_SIZE + localH / 2) {
                    simY = TILE_SIZE + localH / 2;
                    simVy = -simVy * 1.05;
                }
                
                pts.push({ x: simX, y: simY });
                
                // Floor landing bounds checking - precise match to real landing checks
                let rFloor = Math.floor((simY + localH / 2) / TILE_SIZE);
                let cL = Math.floor((simX - localW / 2) / TILE_SIZE);
                let cR = Math.floor((simX + localW / 2) / TILE_SIZE);
                let landed = false;
                if (rFloor >= 1) {
                    for (let col = cL; col <= cR; col++) {
                        if (isSolidOrBoundary(rFloor, col)) {
                            landed = true;
                            break;
                        }
                    }
                }
                if (landed && simVy >= 0) {
                    simY = rFloor * TILE_SIZE - localH / 2; // Fixed: Centered offset resolver
                    if (currentPlayingSlot === 20 && simBouncesRemaining > 0) {
                        simVy = -18;
                        if (Math.abs(simVx) < 5) {
                            simVx = (simVx >= 0 ? 1 : -1) * 6;
                        } else {
                            simVx = simVx * 1.05;
                        }
                        simBouncesRemaining--;
                    } else {
                        break;
                    }
                }
            }
            
            // Calculate quick charge progress
            let chargeProgress = 1.0;
            if (boss.maxChargeTimer && boss.chargeTimer !== undefined) {
                chargeProgress = 1.0 - (boss.chargeTimer / boss.maxChargeTimer);
            }
            // Growth rate formula to make it grow very quickly to full length
            let growth = Math.min(1.0, chargeProgress * 3.5); // achieves full length at ~28% of charging
            
            let totalPoints = pts.length;
            let drawPointsCount = Math.max(2, Math.floor(totalPoints * growth));
            
            ctx.save();
            
            // Render beautiful, clean flat rectangles that sweep along the precise trajectory paths
            // Draw lower opacity continuous swept rectangles matching the boss's actual boundaries
            let alpha = 0.05 + 0.12 * chargeProgress; 
            ctx.fillStyle = trajectoryColor;
            
            // We draw the sweep with step increments to keep it clean and lightning fast without lag
            let drawStep = 1;
            for (let i = 0; i < drawPointsCount; i += drawStep) {
                let p = pts[i];
                ctx.globalAlpha = alpha;
                ctx.fillRect(Math.floor(p.x - localW / 2), Math.floor(p.y - localH / 2), localW, localH);
            }
            
            // Draw warning target rectangle at the end of the trajectory in solid flat color
            if (drawPointsCount > 1) {
                let endPt = pts[drawPointsCount - 1];
                ctx.globalAlpha = 0.25 + 0.35 * chargeProgress;
                ctx.fillRect(Math.floor(endPt.x - localW / 2), Math.floor(endPt.y - localH / 2), localW, localH);
                
                // Draw crisp, solid flat white outline around the final target landing box
                ctx.strokeStyle = '#ffffff';
                ctx.lineWidth = 2.5;
                ctx.globalAlpha = 0.5 + 0.4 * chargeProgress;
                ctx.strokeRect(Math.floor(endPt.x - localW / 2), Math.floor(endPt.y - localH / 2), localW, localH);
            }
            
            ctx.restore();
        }

        ctx.save();
        
        let bx = boss.x + boss.w / 2;
        let by = boss.y + boss.h; 
        
        ctx.translate(bx, by);
        
        let sX = currentPlayingSlot === 10 ? 1.0 : boss.scaleX;
        let sY = currentPlayingSlot === 10 ? 1.0 : boss.scaleY;
        ctx.scale(sX, sY);
        
        let halfW = boss.w / 2;
        let bossH = boss.h;
        
        // No visual tilt for rotation for World 1 Boss
        
        let filledCountForRender = getBossFilledCount();
        if (currentPlayingSlot !== 10) {
            if (currentPlayingSlot === 20) {
                ctx.fillStyle = 'rgba(236, 72, 153, 0.22)';
            } else if (currentPlayingSlot === 30) {
                ctx.fillStyle = 'rgba(6, 182, 212, 0.18)'; // Translucent cyan glass body!
            } else if (boss.damageFlash > 0) {
                ctx.fillStyle = `rgba(254, 240, 138, ${0.4 + boss.damageFlash * 0.5})`; 
            } else if (isBossFilled()) {
                ctx.fillStyle = 'rgba(168, 85, 247, 0.35)'; 
            } else if (filledCountForRender >= 7) {
                // Phase 3: Violet-crimson overdrive slime layer
                let pIntensity = 0.28 + Math.sin(Date.now() / 65) * 0.12;
                ctx.fillStyle = `rgba(239, 68, 68, ${pIntensity})`; 
            } else if (filledCountForRender >= 4) {
                // Phase 2: Electric glowing amber
                let pIntensity = 0.18 + Math.sin(Date.now() / 120) * 0.05;
                ctx.fillStyle = `rgba(245, 158, 11, ${pIntensity})`; 
            } else {
                ctx.fillStyle = 'rgba(16, 185, 129, 0.15)'; 
            }
            
            ctx.beginPath();
            ctx.roundRect(-halfW, -bossH, boss.w, boss.h, 24);
            ctx.fill();

            if (currentPlayingSlot === 30) {
                // Diagonal cross lines inside the large glass block!
                ctx.strokeStyle = 'rgba(6, 182, 212, 0.55)';
                ctx.lineWidth = 4;
                ctx.beginPath();
                ctx.moveTo(-halfW + 14, -bossH + 14);
                ctx.lineTo(halfW - 14, -14);
                ctx.moveTo(halfW - 14, -bossH + 14);
                ctx.lineTo(-halfW + 14, -14);
                ctx.stroke();

                // Shiny glass reflection highlights
                ctx.strokeStyle = 'rgba(255, 255, 255, 0.55)';
                ctx.lineWidth = 4.5;
                ctx.beginPath();
                ctx.moveTo(-halfW + 24, -bossH + 24);
                ctx.lineTo(-halfW + 55, -bossH + 55);
                ctx.moveTo(halfW - 55, -55);
                ctx.lineTo(halfW - 24, -24);
                ctx.stroke();
            }
            
            if (currentPlayingSlot === 20) {
                ctx.strokeStyle = '#db2777';
                ctx.lineWidth = 4 + Math.sin(Date.now() / 60) * 1.5;
            } else if (currentPlayingSlot === 30) {
                ctx.strokeStyle = '#06b6d4';
                ctx.lineWidth = 4.5 + Math.sin(Date.now() / 60) * 1.5;
            } else if (isBossFilled()) {
                ctx.strokeStyle = '#a855f7'; 
                ctx.lineWidth = 5 + Math.sin(Date.now() / 80) * 2;
            } else if (filledCountForRender >= 7) {
                // Phase 3 outline: Violent blazing crimson border
                ctx.strokeStyle = '#ef4444'; 
                ctx.lineWidth = 4.5 + Math.sin(Date.now() / 45) * 2;
            } else if (filledCountForRender >= 4) {
                // Phase 2 outline: Crackling orange border
                ctx.strokeStyle = '#f59e0b'; 
                ctx.lineWidth = 3.5 + Math.sin(Date.now() / 90) * 1;
            } else {
                ctx.strokeStyle = '#10b981'; 
                ctx.lineWidth = 3;
            }
            ctx.stroke();

            // Draw glowing bubble shield around World 2 Boss
            if (currentPlayingSlot === 20) {
                ctx.save();
                let radius = Math.hypot(boss.w, boss.h) / 2 + 18 + Math.sin(Date.now() / 100) * 2;
                let shieldY = -boss.h / 2;
                
                ctx.fillStyle = 'rgba(232, 121, 249, 0.07)';
                ctx.beginPath();
                ctx.arc(0, shieldY, radius, 0, Math.PI * 2);
                ctx.fill();
                
                ctx.strokeStyle = '#e879f9';
                ctx.lineWidth = 3.5 + Math.sin(Date.now() / 50) * 1;
                ctx.shadowColor = '#d946ef';
                ctx.shadowBlur = 15;
                ctx.beginPath();
                ctx.arc(0, shieldY, radius, 0, Math.PI * 2);
                ctx.stroke();
                
                ctx.strokeStyle = 'rgba(217, 70, 239, 0.5)';
                ctx.lineWidth = 1.5;
                ctx.beginPath();
                ctx.arc(0, shieldY, radius - 6, 0, Math.PI * 2);
                ctx.stroke();
                ctx.restore();
            }

            // Draw rotating glass shields around World 3 Boss
            if (currentPlayingSlot === 30) {
                ctx.save();
                let bx = boss.x + boss.w / 2;
                let by = boss.y + boss.h;
                
                if (boss.shields) {
                    for (let idx = 0; idx < boss.shields.length; idx++) {
                        let s = boss.shields[idx];
                        if (s && s.active) {
                            let rx = s.cx - bx;
                            let ry = s.cy - by;
                            
                            ctx.save();
                            ctx.translate(rx, ry);
                            
                            let spinSpeed = s.state === 'detaching' ? 8 : 1.5;
                            let angle = (Date.now() / 1500) * spinSpeed + (idx * 2 * Math.PI / boss.shields.length);
                            ctx.rotate(angle + Math.PI/4);
                            
                            // If detaching, draw a bright cyan warning glow!
                            if (s.state === 'detaching') {
                                ctx.shadowColor = '#22d3ee';
                                ctx.shadowBlur = 10 + Math.sin(Date.now() / 30) * 4;
                            }
                            
                            // Glass look
                            ctx.fillStyle = s.state === 'detaching' ? 'rgba(165, 243, 252, 0.95)' : 'rgba(165, 243, 252, 0.65)';
                            ctx.strokeStyle = s.state === 'detaching' ? '#ffffff' : '#22d3ee';
                            ctx.lineWidth = s.state === 'detaching' ? 3.5 : 2.5;
                            
                            ctx.beginPath();
                            ctx.roundRect(-20, -20, 40, 40, 6);
                            ctx.fill();
                            ctx.stroke();
                            
                            // Shiny lines
                            ctx.strokeStyle = 'rgba(255, 255, 255, 0.85)';
                            ctx.lineWidth = 1.5;
                            ctx.beginPath();
                            ctx.moveTo(-10, -10);
                            ctx.lineTo(10, 10);
                            ctx.stroke();
                            
                            ctx.restore();
                        }
                    }
                }
                ctx.restore();
            }
        }
 
        // Electro discharges inside Boss body for Phase 3
        if (currentPlayingSlot !== 10 && filledCountForRender >= 7 && Date.now() % 350 < 160) {
            ctx.strokeStyle = 'rgba(248, 113, 113, 0.85)';
            ctx.lineWidth = 2.5;
            ctx.beginPath();
            let startR = Math.floor(Math.random() * 3);
            let startC = Math.floor(Math.random() * 3);
            let endR = Math.floor(Math.random() * 3);
            let endC = Math.floor(Math.random() * 3);
            
            let sx = -halfW + startC * TILE_SIZE + TILE_SIZE / 2;
            let sy = -bossH + startR * TILE_SIZE + TILE_SIZE / 2;
            let ex = -halfW + endC * TILE_SIZE + TILE_SIZE / 2;
            let ey = -bossH + endR * TILE_SIZE + TILE_SIZE / 2;
            
            ctx.moveTo(sx, sy);
            let midX = (sx + ex) / 2 + (Math.random() - 0.5) * 25;
            let midY = (sy + ey) / 2 + (Math.random() - 0.5) * 25;
            ctx.lineTo(midX, midY);
            ctx.lineTo(ex, ey);
            ctx.stroke();
        }
        
        // Grid inside Boss Slimy Body
        if (currentPlayingSlot === 10) {
            let minR = boss.minR ?? 0;
            let minC = boss.minC ?? 0;
            let maxR = boss.maxR ?? 4;
            let maxC = boss.maxC ?? 4;
            
            if (boss.reorgTimer && boss.reorgTimer > 0 && boss.reorgAnimCells) {
                let totalDuration = boss.reorgAnimCells.length > 0 
                    ? (boss.reorgAnimCells[boss.reorgAnimCells.length - 1].endFrame ?? 35) 
                    : 35;
                let t_elapsed = totalDuration - boss.reorgTimer;
                
                boss.reorgAnimCells.forEach(cell => {
                    let cellStart = cell.startFrame ?? 0;
                    let cellEnd = cell.endFrame ?? 35;
                    let cellT = 0;
                    if (t_elapsed >= cellEnd) {
                        cellT = 1;
                    } else if (t_elapsed <= cellStart) {
                        cellT = 0;
                    } else {
                        let pct = (t_elapsed - cellStart) / (cellEnd - cellStart);
                        cellT = 1 - Math.pow(1 - pct, 3); // Ease-out cubic curve
                    }
                    
                    let r = cell.fromR + (cell.toR - cell.fromR) * cellT;
                    let c = cell.fromC + (cell.toC - cell.fromC) * cellT;
                    
                    let cellX = -halfW + (c - minC) * TILE_SIZE;
                    let cellY = -bossH + (r - minR) * TILE_SIZE;
                    
                    ctx.save();
                    drawSpecificTile(cell.val, cellX, cellY, ctx);
                    if (boss.damageFlash > 0) {
                        ctx.fillStyle = `rgba(254, 240, 138, ${0.4 + boss.damageFlash * 0.4})`;
                        ctx.fillRect(cellX, cellY, TILE_SIZE, TILE_SIZE);
                    }
                    ctx.restore();
                });
                
                // Draw Goal center (if present)
                let val = boss.grid[10] ? boss.grid[10][10] : 0;
                if (val === 3) {
                    let cellX = -halfW + (10 - minC) * TILE_SIZE;
                    let cellY = -bossH + (10 - minR) * TILE_SIZE;
                    ctx.save();
                    drawSpecificTile(val, cellX, cellY, ctx);
                    ctx.restore();
                }
            } else {
                for (let r = minR; r <= maxR; r++) {
                    for (let c = minC; c <= maxC; c++) {
                        let val = boss.grid[r] ? boss.grid[r][c] : 0;
                        let cellX = -halfW + (c - minC) * TILE_SIZE;
                        let cellY = -bossH + (r - minR) * TILE_SIZE;
                        
                        if (val === 0) {
                            // Do not draw grids in the background for Level 13
                        } else {
                            ctx.save();
                            drawSpecificTile(val, cellX, cellY, ctx);
                            if (boss.damageFlash > 0) {
                                ctx.fillStyle = `rgba(254, 240, 138, ${0.4 + boss.damageFlash * 0.4})`;
                                ctx.fillRect(cellX, cellY, TILE_SIZE, TILE_SIZE);
                            }
                            ctx.restore();

                            // Temporarily grow spikes on the edges when jumping
                            if (boss.state === 'jumping' || !boss.grounded) {
                                ctx.save();
                                drawBossEdgeSpikes(r, c, cellX, cellY, ctx);
                                ctx.restore();
                            }
                        }
                    }
                }
            }
        } else {
            // 3x3 Grid inside Boss Slimy Body
            if (currentPlayingSlot !== 30) {
                for (let r = 0; r < 3; r++) {
                    for (let c = 0; c < 3; c++) {
                        let val = boss.grid[r][c];
                        let cellX = -halfW + c * TILE_SIZE;
                        let cellY = -bossH + r * TILE_SIZE;
                        
                        if (val === 0) {
                            ctx.fillStyle = '#0f172a'; // very dark slate void
                            ctx.fillRect(cellX + 2, cellY + 2, TILE_SIZE - 4, TILE_SIZE - 4);
                            
                            ctx.strokeStyle = '#a855f7'; // purple-500 void core dashed outline
                            ctx.lineWidth = 2;
                            ctx.setLineDash([4, 4]);
                            ctx.strokeRect(cellX + 3.5, cellY + 3.5, TILE_SIZE - 7, TILE_SIZE - 7);
                            ctx.setLineDash([]);
                            
                            ctx.fillStyle = 'rgba(168, 85, 247, 0.35)'; // translucent energy center
                            ctx.fillRect(cellX + 11, cellY + 11, TILE_SIZE - 22, TILE_SIZE - 22);
                        } else {
                            ctx.save();
                            drawSpecificTile(val, cellX, cellY, ctx);
                            ctx.restore();
                        }
                    }
                }
            }
        }
        
        // Cute Slime Expressions & Moving eyes
        let minR = boss.minR ?? 0;
        let minC = boss.minC ?? 0;
        let centerR = boss.centerR !== undefined ? boss.centerR : 2;
        let centerC = boss.centerC !== undefined ? boss.centerC : 2;
        let bossCenterX = (currentPlayingSlot === 10) ? (boss.x + (centerC - minC) * TILE_SIZE + TILE_SIZE / 2) : (boss.x + boss.w/2);
        let bossCenterY = (currentPlayingSlot === 10) ? (boss.y + (centerR - minR) * TILE_SIZE + TILE_SIZE / 2) : (boss.y + boss.h/2);
        
        let dx = (player.x + player.w/2) - bossCenterX;
        let dy = (player.y + player.h/2) - bossCenterY;
        let dist = Math.hypot(dx, dy);
        let eyeX = dist > 0 ? (dx / dist) * 12 : 0;
        let eyeY = dist > 0 ? (dy / dist) * 8 : -10;
        
        let blink = Date.now() % 3500 < 150;
        
        ctx.save();
        if (currentPlayingSlot === 10) {
            let cx = -halfW + (centerC - minC) * TILE_SIZE + TILE_SIZE / 2;
            let cy = -bossH + (centerR - minR) * TILE_SIZE + TILE_SIZE / 2;
            ctx.translate(cx, cy);
        } else {
            ctx.translate(0, -boss.h / 1.7);
        }
        
        if (blink) {
            ctx.fillStyle = '#0f172a';
            ctx.fillRect(eyeX - 28, eyeY, 15, 3);
            ctx.fillRect(eyeX + 13, eyeY, 15, 3);
        } else {
            ctx.fillStyle = '#fff';
            ctx.beginPath();
            ctx.arc(eyeX - 22, eyeY, 12, 0, Math.PI * 2);
            ctx.arc(eyeX + 22, eyeY, 12, 0, Math.PI * 2);
            ctx.fill();
            
            ctx.fillStyle = (currentPlayingSlot === 30) ? '#06b6d4' : ((isBossFilled() || boss.eatingProgress > 0) ? '#a855f7' : '#ef4444');
            ctx.beginPath();
            ctx.arc(eyeX - 22 + (dist > 0 ? (dx/dist)*3 : 0), eyeY + (dist > 0 ? (dy/dist)*2 : 0), 5, 0, Math.PI * 2);
            ctx.arc(eyeX + 22 + (dist > 0 ? (dx/dist)*3 : 0), eyeY + (dist > 0 ? (dy/dist)*2 : 0), 5, 0, Math.PI * 2);
            ctx.fill();
        }
        
        ctx.strokeStyle = '#0f172a';
        ctx.lineWidth = 3.5;
        ctx.beginPath();
        if (isBossFilled() || boss.eatingProgress > 0) {
            ctx.arc(0, eyeY + 18, 7, 0, Math.PI * 2);
            ctx.stroke();
        } else {
            ctx.arc(0, eyeY + 12, 10, 0.1 * Math.PI, 0.9 * Math.PI);
            ctx.stroke();
        }
        
        ctx.restore();
        
        // Progress overlays
        if (currentPlayingSlot === 20 || currentPlayingSlot === 30) {
            // Draw Durability Hearts above boss
            let dur = boss.durability ?? 3;
            let heartY = -boss.h - 38;
            let isW3 = currentPlayingSlot === 30;
            
            ctx.fillStyle = isW3 ? '#e0f7fa' : '#fce7f3';
            ctx.font = 'bold 11px monospace';
            ctx.textAlign = 'center';
            ctx.fillText(isW3 ? "CORE STABILITY" : "SHIELD DURABILITY", 0, heartY - 14);
            
            let heartSpacing = 22;
            let startH = -((3 - 1) * heartSpacing) / 2;
            for (let i = 0; i < 3; i++) {
                let hx = startH + i * heartSpacing;
                ctx.font = '16px serif';
                if (i < dur) {
                    ctx.fillText(isW3 ? '💎' : '💖', hx, heartY + 4);
                } else {
                    ctx.fillText('🖤', hx, heartY + 4);
                }
            }

            // Draw Charge/Jump progress bar if resting/charging or pre_jump
            // (on level 20 state machine, state is active/charging/jumping)
            if (boss.state === 'charging' || boss.state === 'active') {
                let barW = 130;
                let barH = 8;
                let barX = -barW / 2;
                let barY = -boss.h - 22;
                
                ctx.fillStyle = 'rgba(15, 23, 42, 0.85)';
                ctx.fillRect(barX, barY, barW, barH);
                
                let pct = 0;
                let isReady = false;
                if (boss.state === 'charging' && boss.maxChargeTimer) {
                    pct = Math.max(0, Math.min(1, (boss.maxChargeTimer - boss.chargeTimer) / boss.maxChargeTimer));
                    isReady = pct >= 0.95;
                } else if (boss.maxCooldown > 0) {
                    pct = Math.max(0, Math.min(1, (boss.maxCooldown - boss.cooldown) / boss.maxCooldown));
                }
                
                // Pulsing charging color
                ctx.fillStyle = isReady 
                    ? ((Date.now() % 160 < 80) ? '#f472b6' : '#ec4899')
                    : '#db2777';
                ctx.fillRect(barX + 1.5, barY + 1.5, (barW - 3) * pct, barH - 3);
                
                ctx.strokeStyle = '#fbcfe8';
                ctx.lineWidth = 1;
                ctx.strokeRect(barX, barY, barW, barH);
                
                ctx.fillStyle = '#fce7f3';
                ctx.font = 'bold 9px monospace';
                ctx.textAlign = 'center';
                let label = isReady ? "💥 READY TO CRUSH! 💥" : `⚡ CHARGING JUMP (${Math.round(pct * 100)}%)`;
                ctx.fillText(label, 0, barY - 6);
            }
        } else if (boss.state === 'charging') {
            let barW = 140;
            let barH = 12;
            let barX = -barW / 2;
            let barY = -boss.h - 25;
            
            ctx.fillStyle = 'rgba(15, 23, 42, 0.9)';
            ctx.fillRect(barX, barY, barW, barH);
            
            // Pulsing purple ultimate bar!
            ctx.fillStyle = (Date.now() % 150 < 75) ? '#a855f7' : '#ec4899';
            let maxC = boss.maxChargeTimer || 300;
            let pct = (maxC - boss.chargeTimer) / maxC;
            ctx.fillRect(barX + 2, barY + 2, (barW - 4) * pct, barH - 4);
            
            ctx.strokeStyle = '#c084fc';
            ctx.lineWidth = 1.5;
            ctx.strokeRect(barX, barY, barW, barH);
            
            ctx.fillStyle = '#f3e8ff';
            ctx.font = 'bold 11px monospace';
            ctx.textAlign = 'center';
            ctx.fillText("⚡ 大招蓄力中... ⚡", 0, barY - 8);
        } else if ((isBossFilled() || boss.eatingProgress > 0) && boss.eatingProgress > 0) {
            let barW = 80;
            let barH = 8;
            let barX = -barW / 2;
            let barY = -boss.h - 25;
            
            ctx.fillStyle = 'rgba(15, 23, 42, 0.8)';
            ctx.fillRect(barX, barY, barW, barH);
            
            ctx.fillStyle = '#a855f7'; 
            ctx.fillRect(barX, barY, barW * boss.eatingProgress, barH);
            
            ctx.strokeStyle = '#c084fc';
            ctx.lineWidth = 1;
            ctx.strokeRect(barX, barY, barW, barH);
            
            ctx.fillStyle = '#f3e8ff';
            ctx.font = 'bold 9px monospace';
            ctx.textAlign = 'center';
            ctx.fillText("DEVOUR SLIME BOSS! ⚡", 0, barY - 6);
        } else if (!isBossFilled() && boss.eatingProgress === 0 && boss.state !== 'suspended') {
            let filledCount = boss.grid.flat().filter(x => x > 0).length;
            let barY = -boss.h - 18;
            
            let phaseColor = "#c084fc"; // purple-400
            if (filledCount >= 7) {
                phaseColor = "#f87171"; // light red
            } else if (filledCount >= 4) {
                phaseColor = "#fbbf24"; // amber
            }
            
            ctx.fillStyle = phaseColor;
            ctx.font = 'bold 11px monospace';
            ctx.textAlign = 'center';

            // Draw Attack/Jump Progress Bar above the statistics text
            if ((boss.state === 'active' || boss.state === 'pre_jump') && boss.grounded) {
                let attackBarW = 120;
                let attackBarH = 6;
                let attackBarX = -attackBarW / 2;
                let attackBarY = barY - 20;
                
                // Draw background container
                ctx.fillStyle = 'rgba(15, 23, 42, 0.85)';
                ctx.beginPath();
                ctx.roundRect(attackBarX, attackBarY, attackBarW, attackBarH, 3);
                ctx.fill();
                
                // Calculate percentage
                let pct = 0;
                if (boss.state === 'pre_jump' && boss.maxPreJumpTimer) {
                    pct = Math.max(0, Math.min(1, 1 - (boss.preJumpTimer || 0) / boss.maxPreJumpTimer));
                } else if (boss.maxCooldown > 0) {
                    pct = Math.max(0, Math.min(1, (boss.maxCooldown - boss.cooldown) / boss.maxCooldown));
                }
                
                // Fill bar with gradient
                let grad = ctx.createLinearGradient(attackBarX, 0, attackBarX + attackBarW, 0);
                grad.addColorStop(0, '#ea580c'); // orange-600
                grad.addColorStop(0.5, '#f97316'); // orange-500
                grad.addColorStop(1, '#ef4444'); // red-500
                
                ctx.fillStyle = grad;
                ctx.beginPath();
                ctx.roundRect(attackBarX, attackBarY, attackBarW * pct, attackBarH, 3);
                ctx.fill();
                
                // Border
                ctx.strokeStyle = pct >= 0.9 ? '#fca5a5' : '#52525b';
                ctx.lineWidth = 1;
                ctx.beginPath();
                ctx.roundRect(attackBarX, attackBarY, attackBarW, attackBarH, 3);
                ctx.stroke();
                
                // Level subtitle badge text
                ctx.font = 'bold 8.5px monospace';
                ctx.fillStyle = pct >= 0.9 ? '#feca1d' : '#e4e4e7';
                let labelText = pct >= 0.9 ? '💥 READY TO LEAP! 💥' : `⚡ JUMP CHARGING (${Math.round(pct * 100)}%) ⚡`;
                ctx.fillText(labelText, 0, attackBarY - 6);
            }
        }
        
        ctx.restore();
        
        // Suction energy flow
        if ((isBossFilled() || boss.eatingProgress > 0) && getEatTargetOfBoss() && isActionDown('eat') && !player.hasBlock) {
            ctx.save();
            let px = player.x + player.w / 2;
            let py = player.y + player.h / 2;
            let bCenterH = boss.x + boss.w / 2;
            let bCenterY = boss.y + boss.h / 2;
            
            let time = Date.now() / 150;
            // Draw a curved gravitational path
            let midX = (px + bCenterH) / 2 + Math.sin(time) * 40;
            let midY = (py + bCenterY) / 2 + Math.cos(time) * 40;
            
            ctx.strokeStyle = 'rgba(168, 85, 247, 0.75)';
            ctx.lineWidth = 6 + Math.sin(Date.now() / 30) * 3;
            ctx.setLineDash([6, 12]);
            ctx.lineDashOffset = -Date.now() / 3;
            ctx.beginPath();
            ctx.moveTo(px, py);
            ctx.quadraticCurveTo(midX, midY, bCenterH, bCenterY);
            ctx.stroke();
            
            ctx.strokeStyle = '#f3e8ff';
            ctx.lineWidth = 2;
            ctx.beginPath();
            ctx.moveTo(px, py);
            ctx.quadraticCurveTo(midX, midY, bCenterH, bCenterY);
            ctx.stroke();
            ctx.setLineDash([]);
            ctx.restore();
        }
    }

    // Proximity suspend warnings
    if (boss.active && boss.state === 'suspended') {
        let bCenterH = boss.x + boss.w / 2;
        let distH = Math.abs((player.x + player.w/2) - bCenterH);
        if (distH < 500) {
            ctx.fillStyle = 'rgba(239, 68, 68, 0.85)';
            ctx.font = 'bold 12px monospace';
            ctx.textAlign = 'center';
            ctx.fillText("⚠️ DANGER // SOMETHING IS LURKING ABOVE...", bCenterH, 150);
            ctx.fillText("▼", bCenterH, 170 + Math.sin(Date.now() / 80) * 5);
        }
    }

    // Draw Target Devour Hint Layer (On top of all entities, player, boss, blocks, and particles!)
    if (!player.dead && !player.won) {
        if (!player.hasBlock) {
            let drawTarget: { r: number, c: number, type: number, isBossCell?: boolean } | null = null;
            if (player.eatingProgress > 0 && player.eatingTarget) {
                let tr = player.eatingTarget.r;
                let tc = player.eatingTarget.c;
                let isBoss = player.eatingTarget.isBossCell;
                let tType = isBoss 
                    ? (boss.grid[tr] && boss.grid[tr][tc]) 
                    : ((level[tr] && level[tr][tc]) || 1);
                drawTarget = { r: tr, c: tc, type: tType, isBossCell: isBoss };
            } else {
                let target = getEatTarget(player.x + player.w / 2, player.y + player.h / 2, nAimX, nAimY);
                if (target) {
                    drawTarget = { r: target.r, c: target.c, type: target.type, isBossCell: target.isBossCell };
                }
            }

            if (drawTarget && (aiming || player.eatingProgress > 0 || isActionDown('eat'))) {
                let isBoss = drawTarget.isBossCell;
                let x = isBoss 
                    ? (boss.x + (drawTarget.c - (boss.minC ?? 0)) * TILE_SIZE) 
                    : (drawTarget.c * TILE_SIZE);
                let y = isBoss 
                    ? (boss.y + (drawTarget.r - (boss.minR ?? 0)) * TILE_SIZE) 
                    : (drawTarget.r * TILE_SIZE);
                
                if (player.eatingProgress > 0) {
                    let shrink = player.eatingProgress;
                    let size = TILE_SIZE * (1 - shrink);
                    let offx = x + (TILE_SIZE - size) / 2;
                    let offy = y + (TILE_SIZE - size) / 2;
                    ctx.fillStyle = '#0f172a';
                    ctx.fillRect(x, y, TILE_SIZE, TILE_SIZE);
                    ctx.fillStyle = drawTarget.type === 3 ? '#ec4899' : (drawTarget.type === 5 ? '#ec4899' : '#d97706');
                    ctx.fillRect(offx, offy, size, size);
                    if (Math.random() < 0.3) {
                       spawnParticles(offx + size/2, offy + size/2, drawTarget.type === 5 ? '#fbcfe8' : '#f59e0b', 1, 2);
                    }
                }
                
                ctx.strokeStyle = '#22c55e'; // green-200
                ctx.lineWidth = 3;
                ctx.strokeRect(x, y, TILE_SIZE, TILE_SIZE);
            }
        }
    }

    if (editState.active) {
        // Edit Grid & Brush
        ctx.strokeStyle = 'rgba(255, 255, 255, 0.1)';
        ctx.lineWidth = 1;
        for (let x = 0; x <= level[0].length * TILE_SIZE; x += TILE_SIZE) {
            ctx.beginPath(); ctx.moveTo(x, 0); ctx.lineTo(x, level.length * TILE_SIZE); ctx.stroke();
        }
        for (let y = 0; y <= level.length * TILE_SIZE; y += TILE_SIZE) {
            ctx.beginPath(); ctx.moveTo(0, y); ctx.lineTo(level[0].length * TILE_SIZE, y); ctx.stroke();
        }
        
        let hc = Math.floor((mouse.x + camera.x) / TILE_SIZE);
        let hr = Math.floor((mouse.y + camera.y) / TILE_SIZE);
        
        if (mouse.brush === 'Camera' && editorSelectionStart) {
            let s_r1 = Math.min(editorSelectionStart.r, hr);
            let s_r2 = Math.max(editorSelectionStart.r, hr);
            let s_c1 = Math.min(editorSelectionStart.c, hc);
            let s_c2 = Math.max(editorSelectionStart.c, hc);
            ctx.fillStyle = 'rgba(56, 189, 248, 0.2)';
            ctx.fillRect(s_c1 * TILE_SIZE, s_r1 * TILE_SIZE, (s_c2 - s_c1 + 1) * TILE_SIZE, (s_r2 - s_r1 + 1) * TILE_SIZE);
            ctx.strokeStyle = '#38bdf8';
            ctx.lineWidth = 2;
            ctx.strokeRect(s_c1 * TILE_SIZE, s_r1 * TILE_SIZE, (s_c2 - s_c1 + 1) * TILE_SIZE, (s_r2 - s_r1 + 1) * TILE_SIZE);
        } else if (mouse.brush === 'Paste' && editorClipboard) {
            ctx.fillStyle = 'rgba(59, 130, 246, 0.3)';
            let rCount = editorClipboard.length;
            let cCount = editorClipboard[0].length;
            for(let i=0; i<rCount; i++) {
                for(let j=0; j<cCount; j++) {
                    if (editorClipboard[i][j] !== 0) {
                        ctx.fillRect((hc + j) * TILE_SIZE, (hr + i) * TILE_SIZE, TILE_SIZE, TILE_SIZE);
                    }
                }
            }
            ctx.strokeStyle = '#3b82f6';
            ctx.lineWidth = 2;
            ctx.strokeRect(hc * TILE_SIZE, hr * TILE_SIZE, cCount * TILE_SIZE, rCount * TILE_SIZE);
        } else {
            ctx.fillStyle = 'rgba(255, 255, 255, 0.3)';
            ctx.fillRect(hc * TILE_SIZE, hr * TILE_SIZE, TILE_SIZE, TILE_SIZE);
            ctx.strokeStyle = '#fff';
            ctx.lineWidth = 2;
            ctx.strokeRect(hc * TILE_SIZE, hr * TILE_SIZE, TILE_SIZE, TILE_SIZE);
        }
    }

    ctx.restore(); // Remove Camera Transform

    // Elegant 3-second Boss Intro Cinematic Overlays
    if (boss.active && boss.state === 'intro') {
        let count = boss.introTimer;
        // Pulse red threat background overlay
        ctx.fillStyle = `rgba(239, 68, 68, ${Math.min(0.25, (180 - count) / 360 * Math.sin(Date.now() / 150) + 0.15)})`;
        ctx.fillRect(0, 0, canvas.width, canvas.height);
        
        // Flashing Warning Bands (yellow and black hazard strips at top and bottom of screen)
        let bandH = 40;
        ctx.save();
        
        let offset = (Date.now() / 15) % 80;
        
        // Draw top band
        ctx.fillStyle = '#000';
        ctx.fillRect(0, 0, canvas.width, bandH);
        ctx.strokeStyle = '#eab308'; // Amber-500
        ctx.lineWidth = 14;
        ctx.beginPath();
        for (let x = -80; x < canvas.width + 80; x += 60) {
            ctx.moveTo(x + offset, 0);
            ctx.lineTo(x + offset - 20, bandH);
        }
        ctx.stroke();
        
        // Draw bottom band
        ctx.fillStyle = '#000';
        ctx.fillRect(0, canvas.height - bandH, canvas.width, bandH);
        ctx.beginPath();
        for (let x = -80; x < canvas.width + 80; x += 60) {
            ctx.moveTo(x + offset, canvas.height - bandH);
            ctx.lineTo(x + offset - 20, canvas.height);
        }
        ctx.stroke();
        
        ctx.restore();
        
        // Big warning title
        ctx.save();
        ctx.shadowColor = '#ef4444';
        ctx.shadowBlur = 15;
        ctx.fillStyle = '#fff';
        if (Date.now() % 500 < 250) {
            ctx.fillStyle = '#f87171'; // flashing alert color
        }
        ctx.font = 'bold 36px monospace';
        ctx.textAlign = 'center';
        ctx.fillText("⚡ WARNING! ⚡", canvas.width / 2, canvas.height / 2 - 20);
        ctx.restore();
        
        // Countdown timer overlay
        let secs = Math.ceil(count / 60);
        ctx.fillStyle = '#ef4444';
        ctx.font = 'bold 24px monospace';
        ctx.textAlign = 'center';
        ctx.fillText(`ENGAGING IN: ${secs}s`, canvas.width / 2, canvas.height / 2 + 30);
    }

    // UI Overlays
    if (editState.active) {
        ctx.fillStyle = 'rgba(15, 23, 42, 0.8)';
        ctx.fillRect(0, 0, canvas.width, 40);
        ctx.fillStyle = '#22c55e';
        ctx.font = 'bold 16px sans-serif';
        ctx.textAlign = 'left';
        ctx.fillText(`🛠️ 編輯模式 / 筆刷: ${mouse.brush} / 使用 A, D, W, S 移動視角`, 20, 26);
    } else if (player.won) {
        ctx.fillStyle = 'rgba(0, 0, 0, 0.7)';
        ctx.fillRect(0, 0, canvas.width, canvas.height);
        ctx.fillStyle = '#10b981'; // emerald-500
        ctx.font = 'bold 56px sans-serif';
        ctx.textAlign = 'center';
        ctx.fillText('LEVEL CLEARED!', canvas.width / 2, canvas.height / 2);
        ctx.fillStyle = '#94a3b8';
        ctx.font = '24px sans-serif';
        let hasNext = currentPlayingSlot < 50;
        if (hasNext) {
            ctx.fillText('Press [SPACE] to go to Next Level', canvas.width / 2, canvas.height / 2 + 45);
        } else {
            ctx.fillText('Press [SPACE] to return to menu', canvas.width / 2, canvas.height / 2 + 45);
        }
        ctx.fillText('Press [R] to replay', canvas.width / 2, canvas.height / 2 + 85);
    } else if (player.dead) {
        if (deathTimer < 5) {
            ctx.fillStyle = '#fff';
            ctx.fillRect(0, 0, canvas.width, canvas.height);
        } else {
            ctx.fillStyle = 'rgba(15, 23, 42, 0.4)'; // dark overlay
            ctx.fillRect(0, 0, canvas.width, canvas.height);
            
            ctx.fillStyle = '#ef4444'; 
            ctx.font = 'bold 56px sans-serif';
            ctx.textAlign = 'center';
            ctx.fillText('WASTED', canvas.width / 2, canvas.height / 2);
            ctx.fillStyle = '#94a3b8';
            ctx.font = '24px sans-serif';
            ctx.fillText('Press [R] to retry', canvas.width / 2, canvas.height / 2 + 50);
        }
    }
}

// --- REACT COMPONENT ---
export default function GameCanvas({ mode, slot, onReturnMenu, onWinLevel, onLoadLevelDims, onBrushChange }: { key?: string, mode: 'play' | 'edit', slot: number, onReturnMenu?: () => void, onWinLevel?: () => void, onLoadLevelDims?: (cols: number, rows: number) => void, onBrushChange?: (b: string) => void }) {
    const canvasRef = useRef<HTMLCanvasElement>(null);
    const onBrushChangeRef = useRef(onBrushChange);

    useEffect(() => {
        onBrushChangeRef.current = onBrushChange;
    });

    useEffect(() => {
        editState.active = mode === 'edit';
        previousBrushBeforeRightClick = null;
        resetLevel(slot); // initialize immediately
        if (onLoadLevelDims && level && level[0]) {
            onLoadLevelDims(level[0].length, level.length);
        }

        const canvas = canvasRef.current;
        if (!canvas) return;
        const ctx = canvas.getContext('2d');
        if (!ctx) return;

        let animationFrameId: number;

        const onKeyDown = (e: KeyboardEvent) => {
            SoundEffects.init();
            if (!keys[e.code]) {
                physicsActionTriggers[e.code] = true;
                visualActionTriggers[e.code] = true;
            }
            keys[e.code] = true;
            if (['Space', 'ArrowUp', 'ArrowDown', 'ArrowLeft', 'ArrowRight'].includes(e.code) || Object.values(customControls).includes(e.code)) {
                e.preventDefault();
            }
        };

        const onKeyUp = (e: KeyboardEvent) => {
            if (keys[e.code]) {
                physicsActionReleaseTriggers[e.code] = true;
                visualActionReleaseTriggers[e.code] = true;
            }
            keys[e.code] = false;
        };

        const onMouseMove = (e: MouseEvent) => {
            const rect = canvas.getBoundingClientRect();
            const scaleX = canvas.width / rect.width;
            const scaleY = canvas.height / rect.height;
            mouse.x = ((e.clientX - rect.left) * scaleX) / CAMERA_ZOOM;
            mouse.y = ((e.clientY - rect.top) * scaleY) / CAMERA_ZOOM;
        };
        const onMouseDown = (e: MouseEvent) => {
            SoundEffects.init();
            if (e.button === 0) {
                if (!mouse.leftDown) {
                    physicsActionTriggers['MouseLeft'] = true;
                    visualActionTriggers['MouseLeft'] = true;
                }
                mouse.leftDown = true;
            }
            if (e.button === 2) {
                if (!mouse.rightDown) {
                    physicsActionTriggers['MouseRight'] = true;
                    visualActionTriggers['MouseRight'] = true;
                }
                mouse.rightDown = true;
                mouse.rightClicked = true;
                if (editState.active) {
                    if (previousBrushBeforeRightClick === null) {
                        previousBrushBeforeRightClick = mouse.brush;
                        mouse.brush = 'Air';
                        onBrushChangeRef.current?.('Air');
                    }
                }
            }
        };
        const onMouseUp = (e: MouseEvent) => {
            if (e.button === 0) {
                if (mouse.leftDown) {
                    physicsActionReleaseTriggers['MouseLeft'] = true;
                    visualActionReleaseTriggers['MouseLeft'] = true;
                }
                mouse.leftDown = false;
            }
            if (e.button === 2) {
                if (mouse.rightDown) {
                    physicsActionReleaseTriggers['MouseRight'] = true;
                    visualActionReleaseTriggers['MouseRight'] = true;
                }
                mouse.rightDown = false;
                if (editState.active) {
                    if (previousBrushBeforeRightClick !== null) {
                        mouse.brush = previousBrushBeforeRightClick;
                        onBrushChangeRef.current?.(previousBrushBeforeRightClick);
                        previousBrushBeforeRightClick = null;
                    }
                }
            }
        };
        const onContextMenu = (e: MouseEvent) => { e.preventDefault(); };

        window.addEventListener('keydown', onKeyDown, { passive: false });
        window.addEventListener('keyup', onKeyUp);
        canvas.addEventListener('mousemove', onMouseMove);
        canvas.addEventListener('mousedown', onMouseDown);
        window.addEventListener('mouseup', onMouseUp);
        canvas.addEventListener('contextmenu', onContextMenu);

        const loop = () => {
            if (isActionJustPressedVisual('restart') && !editState.active) {
                resetLevel();
            }

            if (editState.active) {
                if (isActionDown('left')) camera.x -= 15;
                if (isActionDown('right')) camera.x += 15;
                camera.x = Math.max(0, Math.min(camera.x, level[0].length * TILE_SIZE - VIEW_WIDTH));
                
                if (isActionDown('up')) camera.y -= 15;
                if (isActionDown('down')) camera.y += 15;
                camera.y = Math.max(0, Math.min(camera.y, level.length * TILE_SIZE - VIEW_HEIGHT));
                
                if (mouse.leftDown || mouse.rightDown) {
                    let c = Math.floor((mouse.x + camera.x) / TILE_SIZE);
                    let r = Math.floor((mouse.y + camera.y) / TILE_SIZE);
                    if (r >= 0 && r < level.length && c >= 0 && c < level[0].length) {
                        if (mouse.brush === 'Camera') {
                            if (mouse.leftDown) {
                                if (!mouse.prevLeftDown) {
                                    editorSelectionStart = {c, r};
                                }
                                editorSelectionCurrent = {c, r};
                            }
                        } else if (mouse.brush === 'Paste') {
                            if (mouse.leftDown && !mouse.prevLeftDown && editorClipboard) {
                                for(let i=0; i<editorClipboard.length; i++) {
                                    for(let j=0; j<editorClipboard[0].length; j++) {
                                        let targetR = r + i;
                                        let targetC = c + j;
                                        if (targetR >= 0 && targetR < level.length && targetC >= 0 && targetC < level[0].length) {
                                            level[targetR][targetC] = editorClipboard[i][j];
                                        }
                                    }
                                }
                            }
                        } else if (mouse.rightDown) {
                            level[r][c] = 0; // right click always erases in edit mode
                        } else if (mouse.brush === 'Player') {
                            player.x = c * TILE_SIZE;
                            player.y = r * TILE_SIZE;
                        } else {
                            if (['Spikes', 'SpikesUp', 'SpikesRight', 'SpikesDown', 'SpikesLeft'].includes(mouse.brush)) {
                                let solidBottom = isSolidOrBoundary(r + 1, c);
                                let solidLeft = isSolidOrBoundary(r, c - 1);
                                let solidTop = isSolidOrBoundary(r - 1, c);
                                let solidRight = isSolidOrBoundary(r, c + 1);

                                let solidCount = (solidBottom ? 1 : 0) + (solidLeft ? 1 : 0) + (solidTop ? 1 : 0) + (solidRight ? 1 : 0);
                                if (solidCount === 1) {
                                    let newBrush = mouse.brush;
                                    if (solidBottom) newBrush = 'Spikes';
                                    else if (solidLeft) newBrush = 'SpikesRight';
                                    else if (solidTop) newBrush = 'SpikesDown';
                                    else if (solidRight) newBrush = 'SpikesLeft';
                                    
                                    if (newBrush !== mouse.brush) {
                                        mouse.brush = newBrush;
                                        onBrushChangeRef.current?.(newBrush);
                                    }
                                }
                            }

                            let t = 0;
                            if (mouse.brush === 'Dirt') t = 1;
                            else if (mouse.brush === 'Steel') t = 2;
                            else if (mouse.brush === 'Goal') t = 3;
                            else if (mouse.brush === 'Spikes' || mouse.brush === 'SpikesUp') t = 4;
                            else if (mouse.brush === 'SpikesRight') t = 41;
                            else if (mouse.brush === 'SpikesDown') t = 42;
                            else if (mouse.brush === 'SpikesLeft') t = 43;
                            else if (mouse.brush === 'Bouncy') t = 5;
                            else if (mouse.brush === 'Breakable') t = 6;
                            else if (mouse.brush === 'Void') t = 7;
                            level[r][c] = t;
                        }
                    }
                }

                if (!mouse.leftDown && mouse.prevLeftDown && mouse.brush === 'Camera') {
                    if (editorSelectionStart && editorSelectionCurrent) {
                        let r1 = Math.min(editorSelectionStart.r, editorSelectionCurrent.r);
                        let r2 = Math.max(editorSelectionStart.r, editorSelectionCurrent.r);
                        let c1 = Math.min(editorSelectionStart.c, editorSelectionCurrent.c);
                        let c2 = Math.max(editorSelectionStart.c, editorSelectionCurrent.c);
                        let copyArr = [];
                        for(let rr=r1; rr<=r2; rr++) {
                            let row = [];
                            for(let cc=c1; cc<=c2; cc++) {
                                row.push(level[rr] ? level[rr][cc] ?? 0 : 0);
                            }
                            copyArr.push(row);
                        }
                        editorClipboard = copyArr;
                        mouse.brush = 'Paste';
                        if (onBrushChangeRef.current) onBrushChangeRef.current('Paste');
                        editorSelectionStart = null;
                        editorSelectionCurrent = null;
                    }
                }
            } else {
                // Start/Tick procedural cave BGM
                if (!SoundAPI.isMuted() && !isPaused) {
                    SoundEffects.tickBgm();
                } else {
                    SoundEffects.stopBgm();
                }

                if (!isPaused) {
                    let targetBulletSpeed = player.inBulletTime ? 0.25 : 1;
                    smoothBulletTimeSpeed += (targetBulletSpeed - smoothBulletTimeSpeed) * 0.15;
                    let currentSpeed = gameSpeed * smoothBulletTimeSpeed;
                    tickAccumulator += currentSpeed;
                    while (tickAccumulator >= 1) {
                        audioState.bossFilledCount = boss.active ? getBossFilledCount() : 0;
                        // Save previous states for rendering Interpolation
                        (player as any).prevX = player.x;
                        (player as any).prevY = player.y;
                        if (boss.active) {
                            boss.prevX = boss.x;
                            boss.prevY = boss.y;
                        }
                        for (let p of projectiles) { p.prevX = p.x; p.prevY = p.y; }
                        for (let p of particles) { p.prevX = p.x; p.prevY = p.y; }
                        for (let fb of fallingBlocks) { fb.prevX = fb.x; fb.prevY = fb.y; }

                        if (!player.dead && !player.won) {
                            updatePhysics();
                            updateBossAndFallingBlocks();
                        }
                        updateProjectilesAndParticles();
                        
                        if (player.dead) {
                            player.inBulletTime = false;
                            deathTimer++;
                            if (deathTimer > 75) resetLevel();
                        }
                        if (player.won) {
                            player.inBulletTime = false;
                        }
                        for (let k in physicsActionTriggers) physicsActionTriggers[k] = false;
                        for (let k in physicsActionReleaseTriggers) physicsActionReleaseTriggers[k] = false;
                        tickAccumulator -= 1;
                    }
                }
                
                if (player.won && isActionJustPressedVisual('jump') && !isPaused) {
                    if (onWinLevel) onWinLevel();
                    else if (onReturnMenu) onReturnMenu();
                }
            }

            // --- RENDER INTERPOLATION ---
            let alpha = Math.min(1.0, tickAccumulator);
            
            function lerpState(obj: any) {
                if (!obj || obj.prevX === undefined || obj.prevY === undefined) return;
                obj.oldX = obj.x;
                obj.oldY = obj.y;
                obj.x = obj.prevX + (obj.x - obj.prevX) * alpha;
                obj.y = obj.prevY + (obj.y - obj.prevY) * alpha;
            }
            function restoreState(obj: any) {
                if (!obj || obj.oldX === undefined || obj.oldY === undefined) return;
                obj.x = obj.oldX;
                obj.y = obj.oldY;
                obj.oldX = undefined;
                obj.oldY = undefined;
            }

            lerpState(player);
            if (boss.active) lerpState(boss);
            for (let p of projectiles) lerpState(p);
            for (let p of particles) lerpState(p);
            for (let fb of fallingBlocks) lerpState(fb);

            draw(ctx, canvas);

            restoreState(player);
            if (boss.active) restoreState(boss);
            for (let p of projectiles) restoreState(p);
            for (let p of particles) restoreState(p);
            for (let fb of fallingBlocks) restoreState(fb);

            // Cycle prev keys
            for (let k in keys) prevKeys[k] = keys[k];
            mouse.prevRightDown = mouse.rightDown;
            mouse.prevLeftDown = mouse.leftDown;
            for (let k in visualActionTriggers) visualActionTriggers[k] = false;
            for (let k in visualActionReleaseTriggers) visualActionReleaseTriggers[k] = false;

            animationFrameId = requestAnimationFrame(loop);
        };

        loop();

        return () => {
            cancelAnimationFrame(animationFrameId);
            SoundEffects.stopBgm(); // Teardown synthesized timeline
            window.removeEventListener('keydown', onKeyDown);
            window.removeEventListener('keyup', onKeyUp);
            canvas.removeEventListener('mousemove', onMouseMove);
            canvas.removeEventListener('mousedown', onMouseDown);
            window.removeEventListener('mouseup', onMouseUp);
            canvas.removeEventListener('contextmenu', onContextMenu);
        };
    }, []);

    return (
        <canvas
            ref={canvasRef}
            width={960}
            height={540}
            className={mode === 'play' ? "w-full h-full shadow-2xl bg-black" : "w-full h-auto max-w-[800px] shadow-2xl bg-black"}
            style={{ imageRendering: 'pixelated' }}
        />
    );
}
