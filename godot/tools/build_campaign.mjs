// Explicitly requested full campaign redesign. Original exports remain recoverable.
import {readFileSync,writeFileSync} from 'node:fs';
import './build_world4.mjs';
const base=new URL('../',import.meta.url);
const w4=JSON.parse(readFileSync(new URL('data/levels/world4_levels.json',base)));
const slots={},solutions={};
function room(slot,width){
 const a=Array.from({length:15},(_,r)=>Array.from({length:width},(_,c)=>r===0||r===14||c===0||c===width-1?'@':'.'));
 a[13][2]='P';a[13][width-3]='$';const route=[];
 const put=(r,c,t)=>a[r][c]=t;
 const walk=c=>route.push({op:'walk',x:c*40+3});
 const jump=c=>route.push({op:'jump',x:c*40+3});
 const eat=(r,c)=>route.push({op:'eat',r,c});
 const shoot=(r,c)=>route.push({op:'shoot',r,c});
 const supply=(c,t='#',r=13)=>put(r,c,t);
 const gate=(c,t='X',bottom=13)=>{
  for(let r=1;r<=13;r++)put(r,c,t==='X'?t:r<bottom-1||r>bottom?'@':r===bottom?'O':'.');
  if(t==='O')for(let r=1;r<=13;r++)put(r,c+1,r<bottom-1||r>bottom?'@':r===bottom?'O':'.');
 };
 const plateau=(from,row,t='@')=>{a[13][width-3]='.';for(let r=row;r<=13;r++)for(let c=from;c<width-1;c++)put(r,c,t);put(row-1,width-3,'$');};
 const step=(from,to,row,t='@')=>{for(let r=row;r<=13;r++)for(let c=from;c<=to;c++)put(r,c,t);};
 const spikes=(from,to)=>{for(let c=from;c<=to;c++)put(13,c,'~');};
 const finish=()=>{slots[slot]=a.map(r=>r.join(''));solutions[slot]=route;};
 return {a,put,walk,jump,eat,shoot,supply,gate,plateau,step,spikes,finish,route,width};
}
// Keep World 5 (Void)'s tested routes.
for(let slot=41;slot<=49;slot++){
 slots[slot]=w4.slots[slot];
}
Object.assign(solutions,JSON.parse(readFileSync(new URL('tests/fixtures/world4_solutions.json',base))));
// World 1 (Steel): ten actual combination stages, with safe staging between challenges.
for(let n=1;n<=10;n++){
 const width=n>=8?50+n: n>=4?49:39;
 const l=room(n,width);
 l.supply(6);l.gate(11,'X');l.supply(18);l.gate(24,'O');
 l.walk(5);l.eat(13,6);l.walk(9);l.shoot(13,11);l.walk(17);l.eat(13,18);l.walk(22);l.shoot(13,24);
 if(n===2){l.spikes(30,31);l.walk(28);l.jump(34);}
 if(n===3){l.supply(30);l.gate(34,'X');l.walk(29);l.eat(13,30);l.walk(32);l.shoot(13,34);}
 if(n===4){l.step(32,36,12);l.plateau(37,10);l.walk(30);l.jump(34);l.walk(35);l.jump(40);}
 if(n===5){l.step(32,35,12,'*');l.step(39,42,11,'*');l.walk(30);l.jump(34);l.walk(37);l.jump(41);}
 if(n===6){l.spikes(31,33);l.walk(29);l.jump(36);}
 if(n===7){l.supply(32);l.gate(39);l.walk(31);l.eat(13,32);l.walk(37);l.shoot(13,39);}
 if(n>=8){l.supply(32);l.walk(31);l.eat(13,32);l.plateau(39,9);l.walk(35);l.route.push({op:'recoil_jump',x:1683});}
 if(n>=9){l.supply(45,'#',8);for(let r=1;r<=8;r++)l.put(r,50,'X');l.walk(44);l.eat(8,45);l.walk(48);l.shoot(8,50);}
 if(n===10){l.put(8,54,'~');l.put(8,55,'~');l.walk(52);l.jump(57);}
 l.walk(width-3);l.finish();
}
writeFileSync(new URL('data/levels/campaign_levels.json',base),JSON.stringify({format:1,slots},null,2)+'\n');
writeFileSync(new URL('tests/fixtures/campaign_solutions.json',base),JSON.stringify(solutions,null,2)+'\n');
