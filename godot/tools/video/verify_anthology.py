from pathlib import Path
import subprocess,json,re,io,sys
from PIL import Image,ImageDraw
G=Path(__file__).resolve().parents[2];O=G/'build/recordings/anthology'
FF=G/'build/video-tools/imageio_ffmpeg/binaries/ffmpeg-win-x86_64-v7.1.exe'
MOVIE=O/'worlds-1-5-anthology-1080p60.mp4'
ACTION='--action' in sys.argv
if ACTION:
 MOVIE=O/'worlds-1-5-action-cut-1080p60.mp4'
 O=O/'action-transitions'
CHAPTER_COUNT=51 if ACTION else 57
plan=json.loads((O/'timeline.json').read_text(encoding='utf-8'));segments=plan['segments']
cursor=0
for s in segments:
 assert s['start']==cursor;cursor+=s['frames']
 assert Path(s.get('path',O/'segments'/s['file'])).stat().st_size>10000
assert cursor==plan['frames']
assert {s['slot'] for s in segments if s['kind']=='play'}==set(range(1,51))
for slot in range(1,51):
 rows=[s for s in segments if s['slot']==slot and s['kind']=='play']
 assert rows[0]['a']==0
 for a,b in zip(rows,rows[1:]):assert abs(a['b']-b['a'])<1e-6
 for row in rows:assert (row['b']-row['a'])/(row['frames']/60)<3.51
print('Timeline: all 50 levels, continuous source coverage, speed <=3.5x',flush=True)
r=subprocess.run([str(FF),'-hide_banner','-i',str(MOVIE),'-map','0:v:0','-map','0:a:0','-vf','blackdetect=d=0.2:pix_th=0.06:pic_th=0.98','-af','loudnorm=I=-16:TP=-2:LRA=9:print_format=json','-progress','pipe:1','-f','null','-'],capture_output=True,text=True,encoding='utf-8',errors='replace')
(O/'decode-check.log').write_text(r.stderr+'\n'+r.stdout,encoding='utf-8')
assert r.returncode==0
frames=int(re.findall(r'^frame=(\d+)$',r.stdout,re.M)[-1]);assert frames==cursor,(frames,cursor)
assert '1920x1080' in r.stderr and '60 fps' in r.stderr and '48000 Hz, stereo' in r.stderr
assert not re.search(r'(Invalid data|corrupt|Error while)',r.stderr)
assert 'black_start:' not in r.stderr
measure=json.loads(re.findall(r'\{\s*"input_i".*?\}',r.stderr,re.S)[-1])
assert -18<float(measure['input_i'])<-14
assert float(measure['input_tp'])<0
meta=subprocess.run([str(FF),'-v','error','-i',str(MOVIE),'-f','ffmetadata','-'],capture_output=True,text=True,encoding='utf-8',check=True).stdout
assert meta.count('[CHAPTER]')==CHAPTER_COUNT
print('Decode, frame count, loudness, chapters passed',flush=True)
samples=[(s['start']/60+min(1.2,s['frames']/120),f"{s['kind']} / W{s['world']} L{s['slot']}") for s in segments if s['tag'] or s['kind'] in ['intro','bridge','outro']]
for page in range(3):
 batch=samples[page*20:(page+1)*20]
 sheet=Image.new('RGB',(1600,math_h:=250*((len(batch)+3)//4)),'#0a101d');draw=ImageDraw.Draw(sheet)
 for i,(t,label) in enumerate(batch):
  raw=subprocess.run([str(FF),'-v','error','-ss',str(t),'-i',str(MOVIE),'-frames:v','1','-vf','scale=400:225','-f','image2pipe','-vcodec','png','-'],capture_output=True,check=True).stdout
  x=i%4*400;y=i//4*250;sheet.paste(Image.open(io.BytesIO(raw)),(x,y+25));draw.text((x+6,y+5),f'{t:.2f}s {label}',fill='white')
 sheet.save(O/f'contact-sheet-{page+1}.jpg',quality=93)
report={'file':str(MOVIE),'seconds':cursor/60,'frames':frames,'resolution':'1920x1080','fps':60,'source_resolution':'1280x720','gameplay_upscaled':True,'levels':50,'chapters':CHAPTER_COUNT,'decode_errors':0,'black_segments':0,'integrated_lufs':float(measure['input_i']),'true_peak_dbtp':float(measure['input_tp']),'bytes':MOVIE.stat().st_size,'voiceover':False,'source_route_coverage':('continuous gameplay; world-end victory holds additionally trimmed by 60 frames' if ACTION else 'continuous; final victory holds trimmed by 25 frames')}
(O/'verification.json').write_text(json.dumps(report,ensure_ascii=False,indent=2),encoding='utf-8')
print(json.dumps(report,ensure_ascii=False),flush=True)
