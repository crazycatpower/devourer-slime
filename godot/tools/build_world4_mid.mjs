// User commissioned World 4 stages 4–7. Preserve the original archive.
import {writeFileSync} from 'node:fs';
const slots={},solutions={};
function room(slot,w,h){
 const a=Array.from({length:h},(_,r)=>Array.from({length:w},(_,c)=>r===0||r===h-1||c===0||c===w-1?'@':'.'));
 const route=[];
 const put=(r,c,v)=>a[r][c]=v;
 const floor=(r,l,u)=>{for(let c=l;c<=u;c++)for(let y=r;y<h-1;y++)put(y,c,'@');};
 const glass=(c,b)=>{for(let r=1;r<=b;r++)put(r,c,'X');};
 const move=(op,c)=>route.push({op,x:c*40+3});
 const use=(op,r,c)=>route.push({op,r,c});
 const finish=()=>{slots[slot]=a.map(r=>r.join(''));solutions[slot]=route;};
 return {put,floor,glass,move,use,finish};
}
{
 const l=room(34,25,18);
 l.put(16,2,'P');l.put(16,5,'#');l.put(16,6,'#');l.floor(12,10,23);l.glass(17,11);l.put(11,22,'$');
 l.move('walk',5);l.use('eat',16,6);l.move('walk',8);l.use('shoot',11,10);l.move('walk',4);l.use('eat',16,5);l.move('walk',8);l.move('recoil_jump',11);
 l.move('walk',9.425);l.use('eat',13,9);l.move('walk',15);l.use('shoot',11,17);l.move('walk',22);l.finish();
}
{
 const l=room(35,31,16);
 l.floor(12,1,8);l.floor(12,11,15);l.floor(12,19,29);
 for(const c of [9,10,16,17,18]){l.put(13,c,'~');l.put(14,c,'@');}
 for(let c=7;c<=29;c++)l.put(10,c,'@');
 l.put(11,2,'P');l.put(11,3,'#');l.put(11,5,'#');l.glass(7,9);l.put(11,7,'X');
 l.put(11,8,'#');l.put(11,21,'#');l.put(11,24,'X');l.put(11,28,'$');
 l.move('walk',2);l.use('eat',11,3);l.move('jump',6);l.use('shoot',11,7);
 l.move('walk',7);l.use('eat',11,8);l.move('walk',8.5);l.use('shoot',12,11);
 l.move('walk',4);l.use('eat',11,5);l.move('walk',8.5);l.use('shoot',12,10);
 l.move('walk',11);l.move('walk',10.7);l.use('eat',12,10);
 l.move('walk',14.7);l.use('shoot',12,19);
 l.move('walk',10.7);l.use('eat',12,9);l.move('walk',14.7);l.use('shoot',12,18);
 l.move('walk',15.7);l.move('jump',19);l.move('walk',20);l.use('eat',11,21);
 l.move('walk',22);l.use('shoot',11,24);l.move('walk',28);l.finish();
}
{
 const l=room(36,31,19);
 l.put(17,2,'P');l.put(17,5,'#');l.glass(8,17);l.put(17,11,'#');l.put(17,12,'#');
 l.floor(13,16,19);l.floor(13,22,29);
 l.put(17,20,'~');l.put(17,21,'~');
 for(let c=16;c<=29;c++)l.put(11,c,'@');
 l.put(12,23,'#');l.put(12,25,'X');l.put(12,28,'$');
 l.move('walk',4);l.use('eat',17,5);l.move('walk',6);l.use('shoot',17,8);
 l.move('walk',10);l.use('eat',17,11);l.move('jump',14);l.use('shoot',12,16);l.move('walk',11);l.use('eat',17,12);l.move('walk',14);l.move('recoil_jump',17);
 l.move('walk',15.425);l.use('eat',14,15);l.move('walk',18.7);l.use('shoot',13,22);l.move('walk',19.7);
 l.move('jump',22);l.use('eat',12,23);l.move('walk',24);l.use('shoot',12,25);l.move('walk',28);l.finish();
}
{
 const l=room(37,31,17);
 l.floor(7,1,6);l.floor(7,9,14);
 for(const c of [7,8]){l.put(8,c,'~');for(let r=9;r<=15;r++)l.put(r,c,'@');}
 for(let c=1;c<=18;c++)l.put(5,c,'@');
 // The second bridge plugs the only entrance to the exit shaft.
 for(let r=8;r<=15;r++){l.put(r,15,'@');l.put(r,17,'@');}
 l.put(8,15,'>');l.put(10,16,'X');l.put(12,16,'X');l.put(14,16,'$');l.put(15,16,'@');
 for(let r=7;r<=8;r++)for(let c=17;c<=21;c++)l.put(r,c,'@');
 l.floor(12,18,29);
 for(let r=9;r<=11;r++)l.put(r,21,'@');
 for(let c=23;c<=24;c++)l.put(6,c,'@');
 for(let c=26;c<=29;c++)l.put(3,c,'@');
 l.put(6,2,'P');l.put(6,4,'#');l.put(2,28,'#');l.put(11,28,'#');
 // A: bridge the entrance once, reclaim it, then cap the exit shaft.
 l.move('walk',3);l.use('eat',6,4);l.move('walk',5.7);l.use('shoot',7,9);
 l.move('walk',6.7);l.move('jump',9);l.move('walk',8.7);l.use('eat',7,8);
 l.move('walk',13.7);l.use('shoot',7,17);l.move('walk',14.7);l.move('jump',17);
 // B: upper branch; store on the ledge next to the hub.
 l.move('walk',21);l.move('jump',23);l.move('jump',26);l.move('walk',27);l.use('eat',2,28);
 l.move('walk',23);l.move('walk',20);l.use('shoot',8,20);
 // Digest A while empty handed, then use the stored upper-branch block B.
 l.move('walk',16.325);l.use('eat',7,16);
 l.move('walk',19);l.use('eat',6,20);l.move('walk',16.325);l.use('shoot',10,16);
 // C must build its own return foothold, then be reclaimed before leaving.
 l.move('walk',22);l.move('walk',27);l.use('eat',11,28);l.move('walk',23);
 l.use('shoot',8,21);l.move('walk',24);l.move('jump',22);l.use('eat',9,22);l.move('jump',21);
 l.move('walk',16.325);l.use('shoot',12,16);
 l.move('walk',16);l.move('walk',16);l.finish();
}
writeFileSync(new URL('../data/levels/world4_mid_levels.json',import.meta.url),JSON.stringify({format:1,slots},null,2)+'\n');
writeFileSync(new URL('../tests/fixtures/world4_mid_solutions.json',import.meta.url),JSON.stringify(solutions,null,2)+'\n');
