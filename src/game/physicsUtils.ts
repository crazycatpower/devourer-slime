import { TILE_SIZE } from './constants';

export function isSolid(t: number): boolean {
    return t === 1 || t === 2 || t === 5 || t === 11 || t === 12 || t === 15 || t === 25 || t === 6;
}

export function isEatable(t: number): boolean {
    return t === 1 || t === 11 || t === 12 || t === 5 || t === 15 || t === 25;
}

export function isSpike(t: number): boolean {
    return t === 4 || (t >= 41 && t <= 43) || t === 7;
}

export function isBouncy(t: number): boolean {
    return t === 5 || t === 15 || t === 25;
}

export function checkSpikeCollision(px: number, py: number, pw: number, ph: number, r: number, c: number, type: number): boolean {
    let tileX = c * TILE_SIZE;
    let tileY = r * TILE_SIZE;
    let sx = tileX;
    let sy = tileY;
    let sw = TILE_SIZE;
    let sh = TILE_SIZE;

    if (type === 4) { // Spikes Up
        sx = tileX + 3;
        sw = TILE_SIZE - 6;
        sy = tileY + 24;
        sh = 16;
    } else if (type === 41) { // Spikes Right
        sx = tileX;
        sw = 16;
        sy = tileY + 3;
        sh = TILE_SIZE - 6;
    } else if (type === 42) { // Spikes Down
        sx = tileX + 3;
        sw = TILE_SIZE - 6;
        sy = tileY;
        sh = 16;
    } else if (type === 43) { // Spikes Left
        sx = tileX + 24;
        sw = 16;
        sy = tileY + 3;
        sh = TILE_SIZE - 6;
    } else if (type === 7) { // Void Block: Only kill on touching the center small square
        sx = tileX + 12;
        sw = TILE_SIZE - 24; // 16px wide
        sy = tileY + 12;
        sh = TILE_SIZE - 24; // 16px high
    }

    return px < sx + sw && px + pw > sx && py < sy + sh && py + ph > sy;
}
