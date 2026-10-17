"""Generate the 7 voiceover clips for Anthology Action Cut with caching and polite delay.
"""
from pathlib import Path
import subprocess
import time

ROOT = Path(__file__).resolve().parents[2]
VOICE_DIR = ROOT / 'build/recordings/anthology/action-transitions/voices'
VOICE_DIR.mkdir(parents=True, exist_ok=True)
FF = ROOT / 'build/video-tools/imageio_ffmpeg/binaries/ffmpeg-win-x86_64-v7.1.exe'

VOICE = "zh-TW-YunJheNeural"
CLIPS = [
    {"id": "hook", "time": 0.2, "text": "這個距離，怎麼過？"},
    {"id": "w1", "time": 8.2, "text": "第一世界：先從一塊方塊開始。"},
    {"id": "w2", "time": 125.3, "text": "第二世界：把障礙變成道路。"},
    {"id": "w3", "time": 300.5, "text": "第三世界：借力，越過極限。"},
    {"id": "w4", "time": 460.8, "text": "第四世界：破開下一條路。"},
    {"id": "w5", "time": 647.8, "text": "第五世界：把所有本領用上。"},
    {"id": "end", "time": 833.5, "text": "五十關，全部吃穿！"}
]

def main():
    print("Generating Anthology voiceover clips...")
    for idx, item in enumerate(CLIPS):
        txt_path = VOICE_DIR / f"{item['id']}.txt"
        mp3_path = VOICE_DIR / f"{item['id']}.mp3"
        wav_path = VOICE_DIR / f"{item['id']}.wav"
        
        if wav_path.exists() and wav_path.stat().st_size > 5000:
            print(f"[{idx+1}/{len(CLIPS)}] (Cached) {item['id']}: {item['text']}")
            continue
            
        with open(txt_path, 'w', encoding='utf-8') as f:
            f.write(item['text'])
            
        print(f"[{idx+1}/{len(CLIPS)}] Generating {item['id']} ({item['time']}s): {item['text']}")
        cmd = [
            "python", "-m", "edge_tts",
            "--voice", VOICE,
            "--file", str(txt_path),
            "--write-media", str(mp3_path)
        ]
        
        success = False
        for attempt in range(1, 6):
            res = subprocess.run(cmd, capture_output=True)
            if res.returncode == 0 and mp3_path.exists() and mp3_path.stat().st_size > 500:
                success = True
                break
            wait_t = 2.0 * attempt
            print(f"  Retry {attempt}/5 for {item['id']} after {wait_t}s...")
            time.sleep(wait_t)
            
        if not success:
            raise RuntimeError(f"Failed to generate clip {item['id']}")
            
        # Convert to 48000Hz stereo WAV
        subprocess.run([
            str(FF), "-hide_banner", "-v", "warning", "-y",
            "-i", str(mp3_path),
            "-ar", "48000",
            "-ac", "2",
            str(wav_path)
        ], check=True)
        time.sleep(1.0)
    print("All Anthology voice clips generated successfully!")

if __name__ == '__main__':
    main()
