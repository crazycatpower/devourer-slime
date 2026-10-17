"""Action Transitions Enhanced: Adds dynamic hook typography, world entrance cards, and 7 Taiwanese voiceover guides.
"""
from pathlib import Path
import json, subprocess, math, wave, time
import numpy as np
from PIL import Image, ImageDraw, ImageFont, ImageFilter

G = Path(__file__).resolve().parents[2]
R = G / 'build/recordings'
BASE = R / 'anthology'
O = BASE / 'action-transitions'
O.mkdir(exist_ok=True)

FF = G / 'build/video-tools/imageio_ffmpeg/binaries/ffmpeg-win-x86_64-v7.1.exe'
W, H = 1920, 1080
FPS = 60
HALF = 18

old = json.loads((BASE / 'timeline.json').read_text(encoding='utf-8'))
plan = []
cursor = 0
world_ends = {max(s['index'] for s in old['segments'] if s['kind'] == 'play' and s['world'] == w) for w in range(1, 5)}

for row in old['segments']:
    if row['kind'] not in ['play', 'hook']:
        continue
    s = {**row, 'old_start': row['start'], 'start': cursor}
    if row['index'] in world_ends:
        s['frames'] -= 60
        s['b'] -= 1.0
    plan.append(s)
    cursor += s['frames']

boundaries = {}
pairs = []
for i, s in enumerate(plan):
    if s['kind'] == 'play' and (i == 0 or plan[i - 1]['world'] != s['world'] or plan[i - 1]['kind'] == 'hook'):
        mode = ['tile', 'slime', 'whip', 'tile', 'slime'][s['world'] - 1]
        boundaries[i] = ('in', mode)
        boundaries[i - 1] = ('out', mode)
        pairs.append({'frame': s['start'], 'world': s['world'], 'mode': mode, 'length_frames': 36})

artdir = R / 'world5/original-art'
ART = {n: Image.open(artdir / (n + '.png')).convert('RGBA').crop((48, 48, 464, 464)) for n in ['slime_carry', 'dirt', 'glass']}

FONT_PATH = 'C:/Windows/Fonts/msjhbd.ttc'
FONT_HOOK = ImageFont.truetype(FONT_PATH, 76)
FONT_BADGE = ImageFont.truetype(FONT_PATH, 36)
FONT_WORLD = ImageFont.truetype(FONT_PATH, 52)
FONT_VICTORY = ImageFont.truetype(FONT_PATH, 68)

NAMES = ['第一口，出發', '把障礙變成道路', '借力，越過極限', '破開下一條路', '把所有本領用上']
HOOK_TITLES = [
    '「路不夠？」',
    '「那就把地圖吃光！」',
    '「極限空中反衝」',
    '「1~5 世界 · 50 關神操作」'
]

def run(args, name):
    with (O / (name + '.log')).open('w') as log:
        subprocess.run([str(FF), '-v', 'warning', '-y', *map(str, args)], stdout=log, stderr=subprocess.STDOUT, check=True)

def exact(pipe, n):
    data = bytearray()
    while len(data) < n:
        b = pipe.read(n - len(data))
        if not b:
            break
        data += b
    return bytes(data)

def shift(im, dx, dy):
    p = Image.new('RGB', (W * 3, H * 3))
    for x in range(3):
        for y in range(3):
            tile = im.transpose(Image.Transpose.FLIP_LEFT_RIGHT) if x != 1 else im
            if y != 1:
                tile = tile.transpose(Image.Transpose.FLIP_TOP_BOTTOM)
            p.paste(tile, (x * W, y * H))
    return p.crop((W + dx, H + dy, 2 * W + dx, 2 * H + dy))

def transition(im, q, mode, world):
    envelope = math.sin(math.pi * q) ** 4
    if mode == 'whip':
        dy = round((q if q < .5 else q - 1) * -800 * envelope)
        moved = shift(im, 0, dy)
        blur = moved.copy()
        for k in [1, 2, 3]:
            blur = Image.blend(blur, shift(moved, 0, k * round(18 * envelope)), 1 / (k + 1))
        im = blur.convert('RGBA')
        name = 'glass'
        size = 180 + 2900 * envelope
        x = -600 + 3120 * q
        y = 540
    else:
        im = im.convert('RGBA')
        name = 'slime_carry' if mode == 'slime' else 'dirt'
        size = 110 + 3100 * envelope
        x = -550 + 3020 * q
        y = 540 + 70 * math.sin(q * math.tau)
        if envelope > .05:
            im = im.filter(ImageFilter.GaussianBlur(2.4 * envelope))
            
    asset = ART[name].resize((round(size), round(size * (.91 if mode == 'slime' else 1))), Image.Resampling.BICUBIC)
    angle = (q - .5) * -34
    asset = asset.rotate(angle, Image.Resampling.BICUBIC, expand=True)
    if q < .38 or q > .62:
        tail = asset.copy()
        tail.putalpha(tail.getchannel('A').point(lambda a: round(a * .16)))
        im.alpha_composite(tail, (round(x - asset.width / 2 - 95), round(y - asset.height / 2)))
    im.alpha_composite(asset, (round(x - asset.width / 2), round(y - asset.height / 2)))
    return im.convert('RGB')

def draw_hook_overlay(im, f, hook_idx):
    """Draw eye-catching typography on the 0-8s hook segments."""
    l = Image.new('RGBA', (W, H), (0, 0, 0, 0))
    d = ImageDraw.Draw(l)
    
    # Entrance animation (0-15 frames)
    alpha = min(1.0, f / 12.0)
    a_int = int(255 * alpha)
    
    # Top badge
    bw, bh = 420, 56
    bx = (W - bw) // 2
    by = 90
    d.rounded_rectangle([bx, by, bx + bw, by + bh], radius=28, fill=(16, 22, 38, int(220 * alpha)), outline=(110, 231, 183, a_int), width=2)
    d.text((W // 2, by + bh // 2), "史萊姆 50 關神操作合集", font=FONT_BADGE, fill=(110, 231, 183, a_int), anchor="mm")
    
    # Main bold glowing hook title
    title_text = HOOK_TITLES[hook_idx]
    ty = by + bh + 45
    # Shadow/glow
    d.text((W // 2 + 3, ty + 3), title_text, font=FONT_HOOK, fill=(0, 0, 0, int(230 * alpha)), anchor="mm")
    d.text((W // 2, ty), title_text, font=FONT_HOOK, fill=(255, 220, 95, a_int), stroke_width=3, stroke_fill=(15, 20, 32, a_int), anchor="mm")
    
    im_rgba = im.convert('RGBA')
    im_rgba.alpha_composite(l)
    return im_rgba.convert('RGB')

def draw_world_banner(im, f, world):
    """Draw sleek world entrance card (frames 18 to 110 of world start)."""
    if f < 18 or f > 115:
        return im
    # Alpha curve: 18->32 fade in, 32->95 hold, 95->115 fade out
    if f < 32:
        alpha = (f - 18) / 14.0
    elif f <= 95:
        alpha = 1.0
    else:
        alpha = (115 - f) / 20.0
    a_int = int(255 * max(0.0, min(1.0, alpha)))
    if a_int <= 0:
        return im
        
    l = Image.new('RGBA', (W, H), (0, 0, 0, 0))
    d = ImageDraw.Draw(l)
    
    bw, bh = 680, 78
    bx = (W - bw) // 2
    by = 85
    d.rounded_rectangle([bx, by, bx + bw, by + bh], radius=39, fill=(14, 18, 30, int(210 * alpha)), outline=(255, 205, 103, a_int), width=2)
    
    banner_text = f"第 {world} 世界 ｜ {NAMES[world-1]}"
    d.text((W // 2 + 2, by + bh // 2 + 2), banner_text, font=FONT_WORLD, fill=(0, 0, 0, int(200 * alpha)), anchor="mm")
    d.text((W // 2, by + bh // 2), banner_text, font=FONT_WORLD, fill=(255, 245, 220, a_int), anchor="mm")
    
    im_rgba = im.convert('RGBA')
    im_rgba.alpha_composite(l)
    return im_rgba.convert('RGB')

print("Starting Enhanced Action Transitions rendering...")

for i, s in enumerate(plan):
    src = BASE / 'segments' / s['file']
    dst = O / s['file']
    s['path'] = str(src)
    
    is_hook = (s['kind'] == 'hook')
    is_boundary = (i in boundaries)
    is_last = (i == len(plan) - 1)
    
    if not is_hook and not is_boundary and not is_last:
        continue
        
    s['path'] = str(dst)
    tmp = dst.with_suffix('.silent.mp4')
    
    print(f"Rendering segment [{i:02d}]: {s['file']} ({s['frames']} frames)...")
    with (O / (s['file'] + '.render.log')).open('wb') as log:
        dec = subprocess.Popen([str(FF), '-v', 'error', '-i', str(src), '-map', '0:v:0', '-frames:v', str(s['frames']), '-f', 'rawvideo', '-pix_fmt', 'rgb24', '-'], stdout=subprocess.PIPE, stderr=log)
        enc = subprocess.Popen([str(FF), '-v', 'warning', '-y', '-f', 'rawvideo', '-pix_fmt', 'rgb24', '-s', '1920x1080', '-r', '60', '-i', '-', '-an', '-c:v', 'h264_nvenc', '-preset', 'p7', '-cq', '16', '-rc', 'vbr', '-b:v', '0', '-profile:v', 'high', '-pix_fmt', 'yuv420p', str(tmp)], stdin=subprocess.PIPE, stderr=log)
        
        for f in range(s['frames']):
            raw = exact(dec.stdout, W * H * 3)
            assert len(raw) == W * H * 3
            im = Image.frombytes('RGB', (W, H), raw)
            
            # 1. Hook typography overlay
            if is_hook:
                im = draw_hook_overlay(im, f, i)
                
            # 2. Action Transition
            if is_boundary:
                side, mode = boundaries[i]
                if side == 'out' and f >= s['frames'] - HALF:
                    q = (f - (s['frames'] - HALF)) / 35
                    im = transition(im, q, mode, s['world'])
                if side == 'in':
                    if f < HALF:
                        q = (f + HALF) / 35
                        im = transition(im, q, mode, s['world'])
                    else:
                        im = draw_world_banner(im, f, s['world'])
                        
            # 3. Final victory celebration
            if is_last and f > s['frames'] - 120:
                d = ImageDraw.Draw(im)
                d.text((W // 2, 125), '50 / 50  ·  全部通關', font=FONT_VICTORY, fill='#ffd279', stroke_width=3, stroke_fill='#101521', anchor='mt')
                
            enc.stdin.write(im.tobytes())
            
        enc.stdin.close()
        assert enc.wait() == 0
        dec.stdout.close()
        assert dec.wait() == 0
        
    run(['-i', tmp, '-i', src, '-map', '0:v', '-map', '1:a', '-c', 'copy', '-t', s['frames'] / 60, dst], s['file'] + '-mux')
    tmp.unlink()
    dst.with_suffix('.done').write_text(str(s['frames']))
    print(f"  DONE segment {s['file']}")

# Mix voiceover into score.wav
VOICE_DIR = O / 'voices'
VOICE_TIMINGS = [
    (0.2, VOICE_DIR / 'hook.wav'),
    (8.2, VOICE_DIR / 'w1.wav'),
    (125.3, VOICE_DIR / 'w2.wav'),
    (300.5, VOICE_DIR / 'w3.wav'),
    (460.8, VOICE_DIR / 'w4.wav'),
    (647.8, VOICE_DIR / 'w5.wav'),
    (833.5, VOICE_DIR / 'end.wav')
]

print("Mixing music score with voiceover clips and ducking...")
with wave.open(str(BASE / 'score.wav'), 'rb') as source, wave.open(str(O / 'score.wav'), 'wb') as target:
    target.setparams(source.getparams())
    rate = source.getframerate()
    rng = np.random.default_rng(105)
    
    score_samples = []
    for s in plan:
        source.setpos(round(s['old_start'] / 60 * rate))
        n = round(s['frames'] / 60 * rate)
        data = np.frombuffer(source.readframes(n), dtype='<i2').reshape(-1, 2).astype(np.float32) / 32768
        edge = min(240, len(data) // 2)
        data[:edge] *= np.linspace(0, 1, edge)[:, None]
        data[-edge:] *= np.linspace(1, 0, edge)[:, None]
        times = s['start'] / 60 + np.arange(len(data)) / rate
        for boundary in pairs:
            age = times - boundary['frame'] / 60 + .3
            mask = (age >= 0) & (age < .6)
            x = age[mask]
            if len(x):
                noise = rng.normal(0, 1, len(x))
                noise = np.convolve(noise, np.ones(9) / 9, 'same')
                wavefx = noise * np.sin(np.pi * x / .6) ** 2 * .07 + np.sin(2 * np.pi * (85 * x + 30 * x * x)) * np.sin(np.pi * x / .6) ** 2 * .025
                data[mask] += wavefx[:, None]
        if s is plan[-1]:
            data *= np.minimum((len(data) - np.arange(len(data))) / (rate * .6), 1)[:, None]
        score_samples.append(data)
        
    full_music = np.concatenate(score_samples, axis=0)
    total_music_samples = len(full_music)
    
    # Voice track & ducking mask
    voice_track = np.zeros_like(full_music)
    ducking_mask = np.ones(total_music_samples, dtype=np.float32)
    fade_len = int(rate * 0.18)
    
    for v_time, v_path in VOICE_TIMINGS:
        if not v_path.exists():
            continue
        with wave.open(str(v_path), 'rb') as vw:
            v_frames = vw.readframes(vw.getnframes())
            v_data = np.frombuffer(v_frames, dtype=np.int16).astype(np.float32) / 32768.0
            if vw.getnchannels() == 1:
                v_data = np.repeat(v_data[:, None], 2, axis=1)
            else:
                v_data = v_data.reshape(-1, 2)
                
            start_s = int(v_time * rate)
            end_s = min(total_music_samples, start_s + len(v_data))
            actual_n = end_s - start_s
            
            if actual_n > 0:
                voice_track[start_s:end_s] += v_data[:actual_n] * 1.35
                d_start = max(0, start_s - fade_len)
                d_end = min(total_music_samples, end_s + fade_len)
                
                duck_seg = np.full(d_end - d_start, 0.55, dtype=np.float32)
                in_n = min(fade_len, len(duck_seg))
                duck_seg[:in_n] = np.linspace(1.0, 0.55, in_n)
                out_n = min(fade_len, len(duck_seg))
                duck_seg[-out_n:] = np.linspace(0.55, 1.0, out_n)
                ducking_mask[d_start:d_end] = np.minimum(ducking_mask[d_start:d_end], duck_seg)
                
    combined_score = (full_music * ducking_mask[:, None]) + voice_track
    peak = np.max(np.abs(combined_score))
    if peak > 0.89:
        combined_score = combined_score / peak * 0.89
    target.writeframes((np.clip(combined_score, -1, 1) * 32767).astype('<i2').tobytes())

print("Updating concat and chapters...")
(O / 'concat.txt').write_text(''.join("file '" + s['path'].replace('\\', '/') + f"'\nduration {s['frames']/60:.9f}\n" for s in plan), encoding='utf-8')
meta = [';FFMETADATA1', 'title=一口氣吃穿五個世界｜動作轉場導讀版', 'comment=50 original levels; 1080p60 action cut with hook cards and chapter guidance.']
chap = [(0, '五個世界搶先看')] + [(s['start'], f"世界 {s['world']} · 第 {(s['slot']-1)%10+1:02d} 關") for s in plan if s['tag']]
for i, (a, title) in enumerate(chap):
    meta += ['[CHAPTER]', 'TIMEBASE=1/60', f'START={a}', f'END={chap[i+1][0] if i+1<len(chap) else cursor}', f'title={title}']
(O / 'chapters.ffmeta').write_text('\n'.join(meta), encoding='utf-8')

final = BASE / 'worlds-1-5-action-cut-1080p60.mp4'
print(f"Muxing into final video: {final}...")
run(['-f', 'concat', '-safe', 0, '-i', O / 'concat.txt', '-i', O / 'score.wav', '-i', O / 'chapters.ffmeta', '-filter_complex', '[0:a][1:a]amix=inputs=2:normalize=0:duration=first,loudnorm=I=-16:TP=-2.5:LRA=9,aresample=48000[a]', '-map', '0:v', '-map', '[a]', '-map_metadata', 2, '-map_chapters', 2, '-c:v', 'copy', '-c:a', 'aac', '-b:a', '320k', '-t', cursor / 60, '-movflags', '+faststart', final], 'final')
print(f"ALL COMPLETE: {final} ({cursor} frames, {cursor/60:.2f}s)")
