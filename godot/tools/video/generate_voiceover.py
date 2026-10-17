"""Generate Taiwanese voiceover from world5-voiceover-script.md using edge-tts async API and mix into world5-animated-cut.mp4.
"""
import asyncio
from pathlib import Path
import re
import subprocess
import wave
import edge_tts
import numpy as np

ROOT = Path(__file__).resolve().parents[2]
BUILD_DIR = ROOT / 'build/recordings/world5'
VOICE_DIR = BUILD_DIR / 'voiceover_clips'
VOICE_DIR.mkdir(parents=True, exist_ok=True)

FF = ROOT / 'build/video-tools/imageio_ffmpeg/binaries/ffmpeg-win-x86_64-v7.1.exe'
SRC_VIDEO = BUILD_DIR / 'world5-animated-cut.mp4'
OUT_VIDEO = BUILD_DIR / 'world5-voiceover-cut.mp4'
SCRIPT_FILE = ROOT / 'docs/media/world5-voiceover-script.md'

VOICE = "zh-TW-YunJheNeural"
SAMPLE_RATE = 48000

def clean_text(t: str) -> str:
    t = re.sub(r'（.*?）|\(.*?\)', '', t)
    t = re.sub(r'……', '，', t)
    t = re.sub(r'[/／]', '，', t)
    t = re.sub(r'。，|，。', '。', t)
    t = re.sub(r'，+', '，', t)
    t = t.strip('， ')
    if not t.endswith(('。', '？', '！')):
        t += '。'
    return t

def parse_script():
    items = []
    with open(SCRIPT_FILE, 'r', encoding='utf-8') as f:
        for line in f:
            m = re.match(r'\|\s*(\d{2}:\d{2})[–-](\d{2}:\d{2})\s*\|\s*([^|]+)\s*\|', line)
            if m:
                start_str, end_str, raw_text = m.groups()
                if '不說話' in raw_text:
                    continue
                mins, secs = map(int, start_str.split(':'))
                start_sec = mins * 60 + secs
                if start_sec == 0:
                    start_sec = 0.25
                text = clean_text(raw_text)
                items.append({'start': start_sec, 'text': text})
                
    # Fine-tuned natural phrase adjustments for smooth TTS
    if len(items) >= 18:
        items[15]['text'] = '現在，還差兩格。'
        items[16]['text'] = '再一口一口吃掉。'
        items[17]['text'] = '這條路，是靠吃出來的。'
    return items

async def generate_single_clip(idx, item):
    mp3_path = VOICE_DIR / f"clip_{idx:02d}.mp3"
    wav_path = VOICE_DIR / f"clip_{idx:02d}.wav"
    
    if wav_path.exists() and wav_path.stat().st_size > 5000:
        print(f"  [{idx+1:02d}] (Cached) {item['start']:.1f}s: {item['text']}")
        return
        
    for attempt in range(1, 6):
        try:
            comm = edge_tts.Communicate(item['text'], VOICE)
            await comm.save(str(mp3_path))
            if mp3_path.exists() and mp3_path.stat().st_size > 100:
                break
        except Exception as e:
            wait_sec = 1.0 * attempt
            print(f"    Retry {attempt} for clip {idx} ({e}), waiting {wait_sec}s...")
            await asyncio.sleep(wait_sec)
            
    # Convert to 48000Hz stereo WAV
    subprocess.run([
        str(FF), "-hide_banner", "-v", "warning", "-y",
        "-i", str(mp3_path),
        "-ar", str(SAMPLE_RATE),
        "-ac", "2",
        str(wav_path)
    ], check=True)
    print(f"  [{idx+1:02d}] Generated {item['start']:.1f}s: {item['text']}")
    await asyncio.sleep(0.3)

async def generate_clips(items):
    print(f"Generating {len(items)} voice clips with voice {VOICE}...")
    for idx, item in enumerate(items):
        await generate_single_clip(idx, item)
    print("All voice clips ready.")

def read_wav(path: Path) -> np.ndarray:
    with wave.open(str(path), 'rb') as w:
        frames = w.readframes(w.getnframes())
        data = np.frombuffer(frames, dtype=np.int16).astype(np.float32) / 32768.0
        channels = w.getnchannels()
        data = data.reshape(-1, channels)
        if channels == 1:
            data = np.repeat(data, 2, axis=1)
        return data

def mix_audio(items):
    print("Mixing voiceover with original game audio...")
    bg_wav = BUILD_DIR / "temp_bg.wav"
    subprocess.run([
        str(FF), "-hide_banner", "-v", "warning", "-y",
        "-i", str(SRC_VIDEO),
        "-ar", str(SAMPLE_RATE),
        "-ac", "2",
        str(bg_wav)
    ], check=True)
    
    bg_data = read_wav(bg_wav)
    total_samples = len(bg_data)
    total_seconds = total_samples / SAMPLE_RATE
    print(f"Original audio duration: {total_seconds:.2f}s ({total_samples} samples)")
    
    voice_track = np.zeros_like(bg_data)
    ducking_mask = np.ones(total_samples, dtype=np.float32)
    fade_len = int(SAMPLE_RATE * 0.18)  # 180ms smooth fade
    
    for idx, item in enumerate(items):
        wav_path = VOICE_DIR / f"clip_{idx:02d}.wav"
        clip = read_wav(wav_path)
        clip_len = len(clip)
        
        start_samp = int(item["start"] * SAMPLE_RATE)
        end_samp = min(total_samples, start_samp + clip_len)
        actual_len = end_samp - start_samp
        
        if actual_len > 0:
            voice_track[start_samp:end_samp] += clip[:actual_len] * 1.35
            
            d_start = max(0, start_samp - fade_len)
            d_end = min(total_samples, end_samp + fade_len)
            
            duck_seg = np.full(d_end - d_start, 0.60, dtype=np.float32)
            in_len = min(fade_len, len(duck_seg))
            duck_seg[:in_len] = np.linspace(1.0, 0.60, in_len)
            out_len = min(fade_len, len(duck_seg))
            duck_seg[-out_len:] = np.linspace(0.60, 1.0, out_len)
            
            ducking_mask[d_start:d_end] = np.minimum(ducking_mask[d_start:d_end], duck_seg)
            
    mixed = (bg_data * ducking_mask[:, None]) + voice_track
    
    peak = np.max(np.abs(mixed))
    if peak > 0.89:
        print(f"Limiting audio peak: {peak:.3f} -> 0.89 (-1dB)")
        mixed = mixed / peak * 0.89
        
    mixed_wav = BUILD_DIR / "temp_mixed.wav"
    mixed_int16 = (np.clip(mixed, -1.0, 1.0) * 32767).astype(np.int16)
    with wave.open(str(mixed_wav), 'wb') as w:
        w.setnchannels(2)
        w.setsampwidth(2)
        w.setframerate(SAMPLE_RATE)
        w.writeframes(mixed_int16.tobytes())
        
    print(f"Muxing to {OUT_VIDEO}...")
    subprocess.run([
        str(FF), "-hide_banner", "-v", "warning", "-y",
        "-i", str(SRC_VIDEO),
        "-i", str(mixed_wav),
        "-c:v", "copy",
        "-c:a", "aac",
        "-b:a", "256k",
        "-map", "0:v:0",
        "-map", "1:a:0",
        str(OUT_VIDEO)
    ], check=True)
    
    if bg_wav.exists(): bg_wav.unlink()
    if mixed_wav.exists(): mixed_wav.unlink()
    print(f"SUCCESS: {OUT_VIDEO} generated successfully!")

async def main():
    items = parse_script()
    await generate_clips(items)
    mix_audio(items)

if __name__ == '__main__':
    asyncio.run(main())
