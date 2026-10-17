"""Replace anthology title cards with short foreground action transitions.
Original maps/gameplay are unchanged; foreground slimes/blocks are editorial art.
"""
from pathlib import Path
import json,subprocess,math,wave
import numpy as np
from PIL import Image,ImageDraw,ImageFont,ImageFilter
G=Path(__file__).resolve().parents[2];R=G/'build/recordings';BASE=R/'anthology';O=BASE/'action-transitions';O.mkdir(exist_ok=True)
FF=G/'build/video-tools/imageio_ffmpeg/binaries/ffmpeg-win-x86_64-v7.1.exe'
W,H=1920,1080;FPS=60;HALF=18
old=json.loads((BASE/'timeline.json').read_text(encoding='utf-8'));plan=[];cursor=0
world_ends={max(s['index'] for s in old['segments'] if s['kind']=='play' and s['world']==w) for w in range(1,5)}
for row in old['segments']:
 if row['kind'] not in ['play','hook']:continue
 s={**row,'old_start':row['start'],'start':cursor}
 if row['index'] in world_ends:
  s['frames']-=60;s['b']-=1.0
 plan.append(s);cursor+=s['frames']
boundaries={};pairs=[]
for i,s in enumerate(plan):
 if s['kind']=='play' and (i==0 or plan[i-1]['world']!=s['world'] or plan[i-1]['kind']=='hook'):
  mode=['tile','slime','whip','tile','slime'][s['world']-1]
  boundaries[i]=('in',mode);boundaries[i-1]=('out',mode);pairs.append({'frame':s['start'],'world':s['world'],'mode':mode,'length_frames':36})
artdir=R/'world5/original-art'
ART={n:Image.open(artdir/(n+'.png')).convert('RGBA').crop((48,48,464,464)) for n in ['slime_carry','dirt','glass']}
FONT=ImageFont.truetype('C:/Windows/Fonts/msjhbd.ttc',64)
def run(args,name):
 with (O/(name+'.log')).open('w') as log:subprocess.run([str(FF),'-v','warning','-y',*map(str,args)],stdout=log,stderr=subprocess.STDOUT,check=True)
def exact(pipe,n):
 data=bytearray()
 while len(data)<n:
  b=pipe.read(n-len(data))
  if not b:break
  data+=b
 return bytes(data)
def shift(im,dx,dy):
 # Mirrored edge extension avoids black borders during fast camera movement.
 p=Image.new('RGB',(W*3,H*3))
 for x in range(3):
  for y in range(3):
   tile=im.transpose(Image.Transpose.FLIP_LEFT_RIGHT) if x!=1 else im
   if y!=1:tile=tile.transpose(Image.Transpose.FLIP_TOP_BOTTOM)
   p.paste(tile,(x*W,y*H))
 return p.crop((W+dx,H+dy,2*W+dx,2*H+dy))
def transition(im,q,mode,world):
 envelope=math.sin(math.pi*q)**4
 if mode=='whip':
  dy=round((q if q<.5 else q-1)*-800*envelope)
  moved=shift(im,0,dy);blur=moved.copy()
  for k in [1,2,3]:blur=Image.blend(blur,shift(moved,0,k*round(18*envelope)),1/(k+1))
  im=blur.convert('RGBA')
  # Original cyan glass spans the lens at the cut, hiding the scene change.
  name='glass';size=180+2900*envelope;x=-600+3120*q;y=540
 else:
  im=im.convert('RGBA');name='slime_carry' if mode=='slime' else 'dirt'
  size=110+3100*envelope;x=-550+3020*q;y=540+70*math.sin(q*math.tau)
  # Fast approach to camera and departure; no held full-screen pose.
  if envelope>.05:
   im=im.filter(ImageFilter.GaussianBlur(2.4*envelope))
 asset=ART[name].resize((round(size),round(size*(.91 if mode=='slime' else 1))),Image.Resampling.BICUBIC)
 angle=(q-.5)*-34
 asset=asset.rotate(angle,Image.Resampling.BICUBIC,expand=True)
 # A brief translucent trailing silhouette, followed by the crisp artwork.
 if q<.38 or q>.62:
  tail=asset.copy();tail.putalpha(tail.getchannel('A').point(lambda a:round(a*.16)))
  im.alpha_composite(tail,(round(x-asset.width/2-95),round(y-asset.height/2)))
 im.alpha_composite(asset,(round(x-asset.width/2),round(y-asset.height/2)))
 return im.convert('RGB')

for i,s in enumerate(plan):
 src=BASE/'segments'/s['file'];dst=O/s['file'];s['path']=str(src)
 if i not in boundaries and i!=len(plan)-1:continue
 s['path']=str(dst)
 if dst.with_suffix('.done').exists() and dst.with_suffix('.done').read_text()==str(s['frames']):continue
 tmp=dst.with_suffix('.silent.mp4')
 with (O/(s['file']+'.render.log')).open('wb') as log:
  dec=subprocess.Popen([str(FF),'-v','error','-i',str(src),'-map','0:v:0','-frames:v',str(s['frames']),'-f','rawvideo','-pix_fmt','rgb24','-'],stdout=subprocess.PIPE,stderr=log)
  enc=subprocess.Popen([str(FF),'-v','warning','-y','-f','rawvideo','-pix_fmt','rgb24','-s','1920x1080','-r','60','-i','-','-an','-c:v','h264_nvenc','-preset','p7','-cq','16','-rc','vbr','-b:v','0','-profile:v','high','-pix_fmt','yuv420p',str(tmp)],stdin=subprocess.PIPE,stderr=log)
  for f in range(s['frames']):
   raw=exact(dec.stdout,W*H*3);assert len(raw)==W*H*3
   im=Image.frombytes('RGB',(W,H),raw)
   if i in boundaries:
    side,mode=boundaries[i]
    if side=='out' and f>=s['frames']-HALF:q=(f-(s['frames']-HALF))/35;im=transition(im,q,mode,s['world'])
    if side=='in' and f<HALF:q=(f+HALF)/35;im=transition(im,q,mode,s['world'])
   if i==len(plan)-1 and f>s['frames']-120:
    d=ImageDraw.Draw(im);d.text((W//2,125),'50 / 50  ·  全部通關',font=FONT,fill='#ffd279',stroke_width=3,stroke_fill='#101521',anchor='mt')
   enc.stdin.write(im.tobytes())
  enc.stdin.close();assert enc.wait()==0;dec.stdout.close();assert dec.wait()==0
 run(['-i',tmp,'-i',src,'-map','0:v','-map','1:a','-c','copy','-t',s['frames']/60,dst],s['file']+'-mux')
 tmp.unlink();dst.with_suffix('.done').write_text(str(s['frames']))
 print('ACTION',i,s['file'],flush=True)

# Preserve the original score's alignment to the retained gameplay, add precise swishes.
with wave.open(str(BASE/'score.wav'),'rb') as source,wave.open(str(O/'score.wav'),'wb') as target:
 target.setparams(source.getparams());rate=source.getframerate();rng=np.random.default_rng(105)
 for s in plan:
  source.setpos(round(s['old_start']/60*rate));n=round(s['frames']/60*rate)
  data=np.frombuffer(source.readframes(n),dtype='<i2').reshape(-1,2).astype(np.float32)/32768
  # Smooth score joins; retain game SFX separately at full resolution.
  edge=min(240,len(data)//2);data[:edge]*=np.linspace(0,1,edge)[:,None];data[-edge:]*=np.linspace(1,0,edge)[:,None]
  times=s['start']/60+np.arange(len(data))/rate
  for boundary in pairs:
   age=times-boundary['frame']/60+.3;mask=(age>=0)&(age<.6);x=age[mask]
   if len(x):
    noise=rng.normal(0,1,len(x));noise=np.convolve(noise,np.ones(9)/9,'same')
    wavefx=noise*np.sin(np.pi*x/.6)**2*.07+np.sin(2*np.pi*(85*x+30*x*x))*np.sin(np.pi*x/.6)**2*.025
    data[mask]+=wavefx[:,None]
  if s is plan[-1]:data*=np.minimum((len(data)-np.arange(len(data)))/(rate*.6),1)[:,None]
  target.writeframes((np.clip(data,-1,1)*32767).astype('<i2').tobytes())

(O/'concat.txt').write_text(''.join("file '"+s['path'].replace('\\','/')+f"'\nduration {s['frames']/60:.9f}\n" for s in plan),encoding='utf-8')
meta=[';FFMETADATA1','title=一口氣吃穿五個世界｜動作轉場版','comment=50 original levels; 720p gameplay upscaled to 1080p60; original-art editorial foreground transitions; speed changes labeled.']
chap=[(0,'五個世界搶先看')]+[(s['start'],f"世界 {s['world']} · 第 {(s['slot']-1)%10+1:02d} 關") for s in plan if s['tag']]
for i,(a,title) in enumerate(chap):meta+=['[CHAPTER]','TIMEBASE=1/60',f'START={a}',f'END={chap[i+1][0] if i+1<len(chap) else cursor}',f'title={title}']
(O/'chapters.ffmeta').write_text('\n'.join(meta),encoding='utf-8')
manifest={'frames':cursor,'seconds':cursor/60,'fps':60,'levels':50,'chapters':len(chap),'removed_title_card_seconds':26,'trimmed_world_end_hold_seconds':4,'transitions':pairs,'segments':plan,'source_resolution':'1280x720','output_resolution':'1920x1080','gameplay_upscaled':True}
(O/'timeline.json').write_text(json.dumps(manifest,ensure_ascii=False,indent=2),encoding='utf-8')
final=BASE/'worlds-1-5-action-cut-1080p60.mp4'
run(['-f','concat','-safe',0,'-i',O/'concat.txt','-i',O/'score.wav','-i',O/'chapters.ffmeta','-filter_complex','[0:a][1:a]amix=inputs=2:normalize=0:duration=first,loudnorm=I=-16:TP=-2.5:LRA=9,aresample=48000[a]','-map','0:v','-map','[a]','-map_metadata',2,'-map_chapters',2,'-c:v','copy','-c:a','aac','-b:a','320k','-t',cursor/60,'-movflags','+faststart',final],'final')
print('COMPLETE',final,cursor,flush=True)
