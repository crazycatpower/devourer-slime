import { Play, Hammer } from 'lucide-react';

export function BossCard({
  id,
  curWorld,
  lobbyTab,
  hasCustom,
  setHoveredLevelId,
  onPlayOfficial,
  onPlayTest,
  onEdit
}: any) {
  return (
    <div 
        onMouseEnter={() => setHoveredLevelId(id)}
        onMouseLeave={() => setHoveredLevelId(null)}
        className={`group relative overflow-hidden rounded-2xl p-6 flex flex-col justify-between h-56 shadow-lg shadow-black/40 hover:-translate-y-1 hover:shadow-xl transition-all duration-300 select-none cursor-pointer border bg-[#1b0a11]/90 ${curWorld.border} hover:border-red-400 shadow-red-950/20`}
    >
        <div className="absolute inset-0 bg-gradient-to-tr from-transparent via-slate-905/10 to-slate-900/40 pointer-events-none"></div>
        <div className="absolute inset-[1px] rounded-[15px] pointer-events-none z-0 bg-[#14060b]"></div>

        <span className={`absolute top-3.5 right-3.5 z-20 text-[8px] font-mono font-black tracking-widest ${curWorld.color} bg-slate-950 border border-slate-800/80 py-0.5 px-2 rounded-md animate-pulse`}>
            WORLDBOSS 👿
        </span>

        <div className="relative z-10 flex-1 flex flex-col items-center justify-center pt-8 pb-3">
            <div className="flex flex-col items-center gap-1 group-hover:scale-105 transition-all duration-300">
                <span className="text-4xl animate-bounce">👿</span>
                <span className={`text-[10px] font-black uppercase ${curWorld.color} tracking-[0.2em] font-mono`}>BOSS STAGE</span>
            </div>
        </div>

        <div className="relative z-10 w-full">
            {lobbyTab === 'official' ? (
                <button 
                    onClick={() => onPlayOfficial(id)}
                    className={`w-full py-2.5 text-white font-black uppercase text-[11px] tracking-wider transition-all rounded-xl shadow-md hover:shadow-lg cursor-pointer flex items-center justify-center gap-1.5 hover:scale-[1.01] bg-gradient-to-r ${curWorld.btnGrad}`}
                >
                    <Play className="w-3 h-3 fill-current text-white" />
                    <span>CHALLENGE BOSS</span>
                </button>
            ) : (
                <div className="flex gap-2">
                    <button 
                        onClick={() => onEdit(id)}
                        className="flex-1 py-2 bg-slate-900 hover:bg-slate-850 text-indigo-300 border border-indigo-500/35 font-extrabold text-[10px] tracking-wider transition-all rounded-xl flex items-center justify-center gap-1 cursor-pointer"
                    >
                        <Hammer className="w-3 h-3 text-indigo-400" />
                        <span>編輯設計</span>
                    </button>
                    <button 
                        onClick={() => onPlayTest(id)}
                        className="flex-1 py-2 bg-gradient-to-r from-emerald-600 to-teal-600 hover:from-emerald-500 hover:to-teal-500 text-white font-extrabold text-[10px] tracking-wider transition-all rounded-xl flex items-center justify-center gap-1 cursor-pointer"
                    >
                        <Play className="w-3 h-3 fill-current" />
                        <span>測試冒險</span>
                    </button>
                </div>
            )}
        </div>
    </div>
  );
}
