"""Create a 1080x1920 vertical Shorts/Reels video from world5-voiceover-cut.mp4.
Highlights the Level 6 recoil stunt (65.0s - 83.5s) with top/bottom branding, blurred dynamic backdrop, and crisp center gameplay.
"""
from pathlib import Path
import subprocess
import cv2
import numpy as np
from PIL import Image, ImageDraw, ImageFont, ImageFilter

ROOT = Path(__file__).resolve().parents[2]
BUILD_DIR = ROOT / 'build/recordings/world5'
FF = ROOT / 'build/video-tools/imageio_ffmpeg/binaries/ffmpeg-win-x86_64-v7.1.exe'
SRC_VIDEO = BUILD_DIR / 'world5-voiceover-cut.mp4'
OUT_SHORTS = BUILD_DIR / 'world5-shorts-recoil.mp4'

FONT_PATH = 'C:/Windows/Fonts/msjhbd.ttc'
FONT_TITLE = ImageFont.truetype(FONT_PATH, 54)
FONT_SUB = ImageFont.truetype(FONT_PATH, 34)
FONT_CTA = ImageFont.truetype(FONT_PATH, 38)

SW, SH = 1080, 1920
START_SEC = 65.0
END_SEC = 83.5
DURATION = END_SEC - START_SEC
FPS = 60

def build_overlay(t_norm: float) -> Image.Image:
    """Pre-render static/dynamic text and badges for Shorts."""
    im = Image.new('RGBA', (SW, SH), (0, 0, 0, 0))
    d = ImageDraw.Draw(im)
    
    # 1. Top badge
    badge_w, badge_h = 560, 64
    bx, by = (SW - badge_w) // 2, 140
    d.rounded_rectangle([bx, by, bx + badge_w, by + badge_h], radius=32, fill=(20, 25, 45, 230), outline=(110, 231, 183, 255), width=3)
    d.text((SW // 2, by + badge_h // 2), "史萊姆方塊吞噬者 · 神操作", font=FONT_SUB, fill=(110, 231, 183), anchor="mm")
    
    # 2. Main punchy title
    title_y = by + badge_h + 40
    d.text((SW // 2 + 3, title_y + 3), "「路不夠？把牆壁吃光！」", font=FONT_TITLE, fill=(0, 0, 0, 220), anchor="mm")
    d.text((SW // 2, title_y), "「路不夠？把牆壁吃光！」", font=FONT_TITLE, fill=(255, 225, 110), anchor="mm")
    
    # 3. Bottom CTA pill
    cta_w, cta_h = 620, 76
    cx, cy = (SW - cta_w) // 2, 1620
    d.rounded_rectangle([cx, cy, cx + cta_w, cy + cta_h], radius=38, fill=(15, 20, 35, 220), outline=(255, 144, 200, 200), width=2)
    d.text((SW // 2, cy + cta_h // 2), "最後反衝這一下能給幾分？👇", font=FONT_CTA, fill=(255, 245, 245), anchor="mm")
    
    # 4. Animated progress line at the bottom
    prog_y = 1880
    prog_w = int(SW * t_norm)
    d.line([(0, prog_y), (SW, prog_y)], fill=(50, 55, 75), width=6)
    d.line([(0, prog_y), (prog_w, prog_y)], fill=(110, 231, 183), width=6)
    
    return im

def process_shorts():
    print(f"Creating vertical Shorts ({SW}x{SH}, {DURATION:.1f}s, {FPS}fps)...")
    
    # 1. Extract audio clip for this segment
    temp_audio = BUILD_DIR / 'temp_shorts_audio.aac'
    subprocess.run([
        str(FF), "-hide_banner", "-v", "warning", "-y",
        "-ss", str(START_SEC),
        "-t", str(DURATION),
        "-i", str(SRC_VIDEO),
        "-vn", "-c:a", "copy",
        str(temp_audio)
    ], check=True)
    
    # 2. Read frames with OpenCV
    cap = cv2.VideoCapture(str(SRC_VIDEO))
    cap.set(cv2.CAP_PROP_POS_MSEC, START_SEC * 1000.0)
    
    # 3. Pipe to ffmpeg
    temp_video = BUILD_DIR / 'temp_shorts_video.mp4'
    cmd = [
        str(FF), "-hide_banner", "-v", "warning", "-y",
        "-f", "rawvideo",
        "-vcodec", "rawvideo",
        "-s", f"{SW}x{SH}",
        "-pix_fmt", "bgr24",
        "-r", str(FPS),
        "-i", "-",
        "-c:v", "libx264",
        "-preset", "fast",
        "-crf", "18",
        "-pix_fmt", "yuv420p",
        str(temp_video)
    ]
    proc = subprocess.Popen(cmd, stdin=subprocess.PIPE)
    
    total_frames = int(DURATION * FPS)
    overlay_static = build_overlay(0.0) # Base overlay
    
    for f_idx in range(total_frames):
        ret, frame = cap.read()
        if not ret:
            break
            
        t_norm = f_idx / max(1, total_frames - 1)
        
        # 1. Background: scale and heavy blur
        # Frame is 1280x720
        # Resize to cover 1080x1920
        # Aspect ratio: 1920 / 720 = 2.666 -> width = 1280 * 2.666 = 3413
        bg_w = int(1280 * (SH / 720.0))
        bg = cv2.resize(frame, (bg_w, SH), interpolation=cv2.INTER_LINEAR)
        x_start = (bg_w - SW) // 2
        bg_crop = bg[:, x_start:x_start + SW]
        # Gaussian blur + darken
        bg_blur = cv2.GaussianBlur(bg_crop, (51, 51), 30)
        bg_dark = (bg_blur.astype(np.float32) * 0.35).astype(np.uint8)
        
        # 2. Foreground Center Gameplay:
        # Scale 1280x720 to 1080 wide -> height = 1080 * 720 / 1280 = 607.5 -> 608
        center_h = int(SW * 720.0 / 1280.0)
        center = cv2.resize(frame, (SW, center_h), interpolation=cv2.INTER_LANCZOS4)
        
        # Center Y coordinate
        cy = (SH - center_h) // 2
        
        # Composite center onto dark bg
        bg_dark[cy:cy + center_h, :] = center
        
        # Border framing for center game window
        cv2.rectangle(bg_dark, (0, cy - 2), (SW, cy + center_h + 2), (110, 231, 183), 3)
        
        # 3. Add dynamic overlay
        im_frame = Image.fromarray(cv2.cvtColor(bg_dark, cv2.COLOR_BGR2RGB))
        overlay = build_overlay(t_norm)
        im_frame.paste(overlay, (0, 0), overlay)
        
        final_bgr = cv2.cvtColor(np.array(im_frame), cv2.COLOR_RGB2BGR)
        proc.stdin.write(final_bgr.tobytes())
        
        if f_idx % 120 == 0:
            print(f"  Shorts rendering: {f_idx}/{total_frames} frames ({f_idx/total_frames*100:.1f}%)")
            
    cap.release()
    proc.stdin.close()
    proc.wait()
    
    # 4. Mux video and audio
    print(f"Muxing into final Shorts: {OUT_SHORTS}...")
    subprocess.run([
        str(FF), "-hide_banner", "-v", "warning", "-y",
        "-i", str(temp_video),
        "-i", str(temp_audio),
        "-c:v", "copy",
        "-c:a", "aac",
        "-b:a", "192k",
        str(OUT_SHORTS)
    ], check=True)
    
    if temp_video.exists(): temp_video.unlink()
    if temp_audio.exists(): temp_audio.unlink()
    print("SUCCESS: 9:16 Shorts created successfully!")

if __name__ == '__main__':
    process_shorts()
