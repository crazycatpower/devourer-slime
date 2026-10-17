"""Five-world editorial master. Uses only existing recorded maps and game art.
Run from any directory. Original recordings are never overwritten.
"""
from pathlib import Path
import subprocess, json, re, math, wave, sys
import numpy as np
from PIL import Image, ImageDraw, ImageFont, ImageFilter

G=Path(__file__).resolve().parents[2]; R=G/'build/recordings'; O=R/'anthology'
O.mkdir(exist_ok=True); (O/'segments').mkdir(exist_ok=True)
FF=G/'build/video-tools/imageio_ffmpeg/binaries/ffmpeg-win-x86_64-v7.1.exe'
W,H,FPS=1920,1080,60
FONT='C:/Windows/Fonts/msjhbd.ttc'
COLORS=['#6ee7b7','#ffbf63','#ff90c8','#6ce3f3','#c397ff']
NAMES=['第一口，出發','把障礙變成道路','借力，越過極限','破開下一條路','把所有本領用上']
DETAILS=['第一世界 / 起步','第二世界 / 搬運與鋪路','第三世界 / 彈跳與反衝','第四世界 / 玻璃與突破','第五世界 / 迷宮與決戰']
ART={p.stem:Image.open(p).convert('RGBA').crop((48,48,464,464)) for p in (R/'world5/original-art').glob('*.png') if p.stem!='cover-map-reference'}
FONTS={s:ImageFont.truetype(FONT,s) for s in [24,28,32,36,42,54,68,88,108,148]}
LEVELS={}; PLAN=[]; CURSOR=0; CHAPTERS=[]

def run(args,name):
 with (O/(name+'.log')).open('w',encoding='utf-8') as log:
  subprocess.run([str(FF),'-hide_banner','-v','warning','-y',*map(str,args)],stdout=log,stderr=subprocess.STDOUT,check=True)

for world in range(1,6):
 if world==1:
  raw=(R/'world1/chapters-01-10.txt').read_text()
  for i,part in enumerate(raw.split('[CHAPTER]')[1:],1):
   a=round(int(re.search(r'START=(\d+)',part)[1])*.06);b=round(int(re.search(r'END=(\d+)',part)[1])*.06)
   LEVELS[i]={'slot':i,'world':1,'movie_start_frame':a,'movie_frames':b-a,'input_ticks':b-a-120}
 else:
  for row in json.loads((R/f'world{world}/results.json').read_text(encoding='utf-8'))['levels']:
   assert row['won'] and not row['dead'];LEVELS[row['slot']]={**row,'world':world}

def add(kind,world,slot=0,a=0,b=0,duration=0,caption='',tag=False):
 global CURSOR
 frames=round(duration*60);idx=len(PLAN)
 PLAN.append(dict(index=idx,kind=kind,world=world,slot=slot,a=a,b=b,frames=frames,start=CURSOR,file=f'{idx:03d}_{kind}_{slot or world}.mp4',caption=caption,tag=tag))
 CURSOR+=frames

# A rapid promise drawn from actual actions, followed by a new animated title.
for world,slot,a,b in [(1,9,8,10),(3,26,5,7),(4,33,36,38),(5,46,14,16)]:add('hook',world,slot,a,b,2)
add('intro',1,duration=5)
for world in range(1,6):
 CHAPTERS.append((CURSOR,f'{world:02d} {NAMES[world-1]}'))
 add('bridge',world,duration=3)
 for slot in range(world*10-9,world*10+1):
  row=LEVELS[slot];end=(row['movie_frames']-25)/60
  CHAPTERS.append((CURSOR,f'世界 {world} · 第 {(slot-1)%10+1:02d} 關'))
  cap=34 if slot%10==0 else 27 if slot in [19,27,29,35,36,37,48] else 18
  if end<=cap:
   add('play',world,slot,0,end,end,tag=True)
  else:
   lead=4.;tail=7. if slot%10 else 10.
   middle=end-lead-tail;speed=min(3.5,middle/max(6,cap-lead-tail))
   add('play',world,slot,0,lead,lead,tag=True)
   add('play',world,slot,lead,end-tail,middle/speed)
   add('play',world,slot,end-tail,end,tail)
CHAPTERS.append((CURSOR,'五個世界，五十關'))
add('outro',5,duration=6)
TOTAL=CURSOR/60
(O/'timeline.json').write_text(json.dumps({'fps':60,'frames':CURSOR,'seconds':TOTAL,'source_resolution':'1280x720','delivery_resolution':'1920x1080','gameplay_upscaled':True,'levels':50,'segments':PLAN},ensure_ascii=False,indent=2),encoding='utf-8')

def txt(im,xy,value,size,color='white',anchor=None,alpha=255):
 layer=Image.new('RGBA',(W,H));d=ImageDraw.Draw(layer)
 d.text(xy,value,font=FONTS[size],fill=color,stroke_width=3,stroke_fill='#0a101f',anchor=anchor)
 if alpha<255:layer.putalpha(layer.getchannel('A').point(lambda a:round(a*max(0,alpha)/255)))
 im.alpha_composite(layer)

def ease(t):return 1-(1-max(0,min(1,t)))**3
def sprite(im,name,x,y,size,sx=1,sy=1,angle=0):
 p=ART[name].resize((max(1,round(size*sx)),max(1,round(size*sy))),Image.Resampling.LANCZOS)
 if angle:p=p.rotate(angle,Image.Resampling.BICUBIC,expand=True)
 im.alpha_composite(p,(round(x-p.width/2),round(y-p.height/2)))

def grab(world,seconds):
 dest=O/f'background-{world}.png'
 if not dest.exists():run(['-ss',seconds,'-i',R/f'world{world}/world{world}-levels-01-10.mp4','-frames:v',1,'-vf',f'scale={W}:{H}:flags=lanczos',dest],f'grab-{world}')
 return Image.open(dest).convert('RGBA')
BGS={world:grab(world,t).filter(ImageFilter.GaussianBlur(3)) for world,t in enumerate([57,180,150,242,150],1)}
for bg in BGS.values():bg.alpha_composite(Image.new('RGBA',(W,H),(5,9,20,170)))
EDGES={}
for world in range(1,6):
 slot=world*10-9;row=LEVELS[slot];dest=O/f'entry-{world}.png'
 if not dest.exists():run(['-ss',row['movie_start_frame']/60,'-i',R/f'world{world}/world{world}-levels-01-10.mp4','-frames:v',1,'-vf',f'scale={W}:{H}:flags=lanczos',dest],f'entry-{world}')
 EDGES[world]=Image.open(dest).convert('RGBA')


def animate(s,t):
 world=s['world'];kind=s['kind'];bg=BGS[world]
 im=bg.copy();color=COLORS[world-1]
 # All environment imagery comes from the existing recordings; no generated map.
 if kind=='intro':
  now=min(4,int(t/.65));p=ease((t% .65)/.65)
  im=BGS[now+1].copy()
  if now<4:
   mask=Image.new('L',(W,H));md=ImageDraw.Draw(mask);r=p*2200
   md.ellipse((1450-r,540-r,1450+r,540+r),fill=255)
   im=Image.composite(BGS[now+2],im,mask)
  x=310+100*math.sin(t*1.6);y=690-80*abs(math.sin(t*3))
  sprite(im,'slime_carry' if 1<t<2 else 'slime_right',x,y,300,1+.12*math.sin(t*6),1-.12*math.sin(t*6))
  for k,name in enumerate(['dirt','bouncy','glass','void']):
   ang=t*1.8+k*math.pi/2;sprite(im,name,x+235*math.cos(ang),y+145*math.sin(ang),62,angle=-ang*25)
  alpha=round(255*ease((t-.35)/.5))
  txt(im,(760,295),'從第一口',88,alpha=alpha)
  txt(im,(755,410),'到第五世界',108,'#ffcf77',alpha=alpha)
  txt(im,(770,585),'五個世界  ·  五十關實錄合集',36,alpha=alpha)
  txt(im,(770,655),'吞下障礙，走出自己的路。',32,'#cbd5e1',alpha=alpha)
 elif kind=='bridge':
  u=ease(t/.7);x=-200+660*u;y=695-180*math.sin(math.pi*min(1,t/.7))
  tile=['dirt','dirt_used','bouncy','glass','void'][world-1]
  age=max(0,t-.7);sq=1+.16*math.exp(-age*3)*math.sin(age*18)
  sprite(im,'slime_right',x,y,265,sq,1/sq)
  sprite(im,tile,470+160*math.cos(t*2),460+30*math.sin(t*3),100,angle=math.sin(t*3)*18)
  sprite(im,f'goal_{int(t/.075)%16:02d}',1660,720,150)
  txt(im,(745,320),f'WORLD {world:02d}',54,color,alpha=round(255*ease(t/.4)))
  txt(im,(740,425+30*(1-ease((t-.2)/.6))),NAMES[world-1],88,alpha=round(255*ease((t-.2)/.5)))
  txt(im,(750,565),DETAILS[world-1],36,'#d5ddec',alpha=round(255*ease((t-.4)/.5)))
  d=ImageDraw.Draw(im)
  for i in range(5):d.line((750+i*155,660,860+i*155,660),fill=COLORS[i] if i<world else '#333749',width=6)
 else:
  for k in range(5):
   x=350+k*305;y=800-55*abs(math.sin(t*3-k*.5))
   sprite(im,'slime_carry' if k==1 else 'slime_idle',x,y,125,1+.08*math.sin(t*5+k),1-.08*math.sin(t*5+k))
   sprite(im,['dirt','dirt_used','bouncy','glass','void'][k],x,y+130,55)
  txt(im,(960,200),'50 / 50',148,'#ffd279',anchor='mt',alpha=round(255*ease(t/.7)))
  txt(im,(960,420),'這條路，是吃出來的。',68,anchor='mt',alpha=round(255*ease((t-.3)/.7)))
  txt(im,(960,540),'第一至第五世界  ·  全部通關',36,'#d7d9ed',anchor='mt')
  txt(im,(960,1000),'原關卡實錄 / 自動化正常操作輸入 / 包含加速剪輯',24,'#bec7d5',anchor='mt')
 if kind=='bridge' and t>2.5:
  q=ease((t-2.5)/.5);mask=Image.new('L',(W,H));md=ImageDraw.Draw(mask);r=q*2050
  md.ellipse((1660-r,720-r,1660+r,720+r),fill=255)
  im=Image.composite(EDGES[world],im,mask)
 return im.convert('RGB')

def render_animation(s):
 dst=O/'segments'/s['file'];n=s['frames']
 temp=dst.with_suffix('.silent.mp4')
 with (O/(s['file']+'.log')).open('wb') as log:
  p=subprocess.Popen([str(FF),'-v','warning','-y','-f','rawvideo','-pix_fmt','rgb24','-s','1920x1080','-r','60','-i','-','-an','-c:v','h264_nvenc','-preset','p7','-rc','vbr','-cq','16','-b:v','0','-profile:v','high','-pix_fmt','yuv420p',str(temp)],stdin=subprocess.PIPE,stderr=log)
  for f in range(n):p.stdin.write(animate(s,f/60).tobytes())
  p.stdin.close();assert p.wait()==0
 run(['-i',temp,'-f','lavfi','-i','anullsrc=r=48000:cl=stereo','-map','0:v','-map','1:a','-c:v','copy','-c:a','aac','-t',n/60,dst],s['file']+'-audio')
 temp.unlink()

def render_play(s):
 world=s['world'];slot=s['slot'];dur=s['frames']/60;speed=(s['b']-s['a'])/dur
 overlay=Image.new('RGBA',(W,H));d=ImageDraw.Draw(overlay)
 # Discreet fixed running folio, plus an animated level label on entry.
 txt(overlay,(1840,1015),f'{slot:02d} / 50',28,COLORS[world-1],anchor='ra')
 if speed>1.05:txt(overlay,(1835,122),f'加速 ×{speed:.1f}',28,'#d3dce8',anchor='ra')
 if s['kind']=='hook':txt(overlay,(960,900),'一口一塊，走過五個世界。',54,anchor='mt')
 static=O/(s['file']+'.png');overlay.save(static)
 args=['-ss',LEVELS[slot]['movie_start_frame']/60+s['a'],'-t',s['b']-s['a'],'-i',R/f'world{world}/world{world}-levels-01-10.mp4','-loop','1','-framerate',60,'-i',static]
 vf=f'[0:v]setpts=(PTS-STARTPTS)/{speed},fps=60,scale={W}:{H}:flags=lanczos,setsar=1,format=yuv420p[base];[base][1:v]overlay=0:0[v0]'
 previous='v0'
 if s['tag']:
  label=Image.new('RGBA',(W,H));txt(label,(55,128),f'WORLD {world:02d}',28,COLORS[world-1]);txt(label,(55,172),f'{(slot-1)%10+1:02d}',68)
  path=O/(s['file']+'.tag.png');label.save(path);args+=['-loop','1','-framerate',60,'-i',path]
  vf+=';[2:v]format=rgba,fade=t=in:st=0:d=0.18:alpha=1,fade=t=out:st=1.7:d=0.3:alpha=1[tag];[v0][tag]overlay=x=\'min(0,-35+175*t)\':y=0[v1]';previous='v1'
 tempo=[];rem=speed
 while rem>2:tempo.append('atempo=2');rem/=2
 tempo.append(f'atempo={rem}')
 vf+=f';[0:a]asetpts=PTS-STARTPTS,'+','.join(tempo)+f',volume={1.45 if world in [3,5] else 2.1},apad,atrim=duration={dur},afade=t=in:d=0.012,afade=t=out:st={max(0,dur-.025)}:d=0.025[a]'
 args+=['-filter_complex_threads',2,'-filter_complex',vf,'-map',f'[{previous}]','-map','[a]','-frames:v',s['frames'],'-t',dur,'-c:v','h264_nvenc','-preset','p7','-rc','vbr','-cq',16,'-b:v',0,'-profile:v','high','-pix_fmt','yuv420p','-c:a','aac','-ar',48000,'-ac',2,'-b:a','192k',O/'segments'/s['file']]
 run(args,s['file'])

if '--preview' in sys.argv:
 s=next(s for s in PLAN if s['kind']=='intro');animate(s,3.7).save(O/'intro-preview.png')
 sys.exit()
for s in PLAN:
 dest=O/'segments'/s['file'];done=dest.with_suffix('.done')
 if not done.exists():
  (render_animation if s['kind'] in ['intro','bridge','outro'] else render_play)(s)
  done.write_text(str(s['frames']))
 print('RENDERED',s['index'],len(PLAN),s['file'],flush=True)

# A continuous original score, with different instrument density per world.
# Write in 8-second blocks to bound memory for the long master.
rate=48000;rng=np.random.default_rng(170105)
chapter_times=[(s['start']/60,s['world']) for s in PLAN if s['kind']=='bridge']
with wave.open(str(O/'score.wav'),'wb') as wav:
 wav.setnchannels(2);wav.setsampwidth(2);wav.setframerate(rate)
 for start in np.arange(0,TOTAL,8):
  count=round(min(8,TOTAL-start)*rate);tt=start+np.arange(count)/rate;sound=np.zeros((count,2),np.float32)
  world=max([w for t,w in chapter_times if t<=start] or [1]);beat=60/112
  for k in range(max(0,int((start-2)/beat*2)),int((start+8)/beat*2)+1):
   at=k*beat/2;age=tt-at;mask=(age>=0)&(age<1.8)
   if not mask.any():continue
   x=age[mask];v=np.zeros(len(x));root=[45,41,48,43][(k//32)%4]
   if k%2==0:v+=np.sin(2*np.pi*(48*x+48*(1-np.exp(-x*32))/32))*np.exp(-x*24)*(.048+.006*world)
   if k%2==1 and world>=2:v+=rng.normal(0,1,len(x))*np.exp(-x*105)*.009
   if k%4==2 and world>=3:v+=rng.normal(0,1,len(x))*np.exp(-x*30)*.012
   midi=root+[0,7,12,19,12,7,15,7][k%8];hz=440*2**((midi-69)/12)
   if k%2==0 or world>=4:v+=(np.sin(2*np.pi*hz*x)+.2*np.sin(4*np.pi*hz*x))*np.minimum(x/.008,1)*np.exp(-x*8)*.022
   if k%8==0:v+=np.sin(2*np.pi*440*2**((root-81)/12)*x)*np.minimum(x/.02,1)*np.exp(-x*2)*.036
   sound[mask,0]+=v*(.82 if k%2 else 1);sound[mask,1]+=v*(1 if k%2 else .82)
  for k in range(max(0,int((start-5)/(beat*8))),int((start+8)/(beat*8))+1):
   age=tt-k*beat*8;mask=(age>=0)&(age<beat*8)
   x=age[mask];root=[45,41,48,43][k%4]
   pad=sum(np.sin(2*np.pi*440*2**((root+i-69)/12)*x) for i in [0,7,12])*.004
   pad*=np.minimum(x/.5,1)*np.minimum((beat*8-x)/.7,1)
   sound[mask]+=pad[:,None]
  # Score breathes under the last seconds of every level and rises into chapters.
  gain=np.ones(count,dtype=np.float32)
  for s in PLAN:
   if s['kind']=='play' and s['b']>LEVELS[s['slot']]['input_ticks']/60:
    end=(s['start']+s['frames'])/60;mask=(tt>end-2)&(tt<end);gain[mask]*=.4
   if s['kind'] in ['bridge','intro']:
    age=tt-s['start']/60;mask=(age>=0)&(age<.65);x=age[mask]
    sw=rng.normal(0,1,len(x))*.013*np.sin(np.pi*x/.65)**2;sound[mask]+=sw[:,None]
  gain*=np.minimum(tt/.1,1)*np.minimum((TOTAL-tt)/2,1)
  sound*=gain[:,None];wav.writeframes((np.clip(sound,-1,1)*32767).astype('<i2').tobytes())

(O/'segments/concat.txt').write_text(''.join(f"file '{s['file']}'\nduration {s['frames']/60:.9f}\n" for s in PLAN),encoding='utf-8')
meta=[';FFMETADATA1','title=從第一口到第五世界｜五十關合集','comment=Original 720p60 gameplay upscaled to 1080p60; native 1080p graphics; automated normal-input runs; speed changes labeled.']
chapters=[(0,'序幕：一口一塊')]+CHAPTERS
for i,(a,name) in enumerate(chapters):
 b=chapters[i+1][0] if i+1<len(chapters) else CURSOR
 meta+=['[CHAPTER]','TIMEBASE=1/60',f'START={a}',f'END={b}',f'title={name}']
(O/'chapters.ffmeta').write_text('\n'.join(meta)+'\n',encoding='utf-8')
run(['-f','concat','-safe',0,'-i',O/'segments/concat.txt','-i',O/'score.wav','-i',O/'chapters.ffmeta','-filter_complex','[0:a][1:a]amix=inputs=2:normalize=0:duration=first,loudnorm=I=-16:TP=-2.5:LRA=9,aresample=48000[a]','-map','0:v','-map','[a]','-map_metadata',2,'-map_chapters',2,'-c:v','copy','-c:a','aac','-b:a','320k','-t',TOTAL,'-movflags','+faststart',O/'worlds-1-5-anthology-1080p60.mp4'],'master')
print('COMPLETE',TOTAL,'seconds',CURSOR,'frames',flush=True)
