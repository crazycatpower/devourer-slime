import { useState, useEffect } from 'react';
import { Play, Hammer, Grid3X3, Volume2, VolumeX } from 'lucide-react';
import { WORLDS } from '../game/worlds';
import { SoundAPI } from '../game/audio';

interface MenuProps {
  isSoundMuted: boolean;
  setIsSoundMuted: (m: boolean) => void;
  soundVolumeState: number;
  setSoundVolumeState: (v: number) => void;
  lobbyTab: 'official' | 'custom';
  setLobbyTab: (t: 'official' | 'custom') => void;
  selectedWorld: number;
  setSelectedWorld: (w: number) => void;
  levelsMade: boolean[];
  onPlayOfficial: (slot: number) => void;
  onPlayTest: (slot: number) => void;
  onEdit: (slot: number) => void;
  hoveredLevelId: number | null;
  setHoveredLevelId: (id: number | null) => void;
}

export default function Menu({
  isSoundMuted, setIsSoundMuted,
  soundVolumeState, setSoundVolumeState,
  lobbyTab, setLobbyTab,
  selectedWorld, setSelectedWorld,
  levelsMade,
  onPlayOfficial, onPlayTest, onEdit,
  hoveredLevelId, setHoveredLevelId
}: MenuProps) {
  const curWorld = WORLDS[selectedWorld - 1] || WORLDS[0];

  return (
    <div className="w-full min-h-screen bg-[#070b19] text-slate-100 flex flex-col relative overflow-x-hidden font-sans pb-12">
        {/* Ambient Background Grid elements */}
        <div className="absolute inset-0 bg-[radial-gradient(#1e293b_1px,transparent_1px)] [background-size:32px_32px] opacity-25"></div>
        <div className={`absolute top-0 left-1/4 w-96 h-96 ${curWorld.glowBg} rounded-full blur-3xl pointer-events-none`}></div>
        <div className={`absolute bottom-10 right-1/4 w-96 h-96 ${curWorld.glowBg} rounded-full blur-3xl pointer-events-none`}></div>
        
        {/* Header branding */}
        <div className="z-10 w-full max-w-7xl mx-auto px-6 pt-10 pb-6 flex flex-col md:flex-row items-center justify-between border-b border-slate-800/60 mb-8">
            <div className="flex items-center gap-4 mb-6 md:mb-0">
                <div className={`w-14 h-14 bg-gradient-to-tr ${curWorld.btnGrad} rounded-2xl flex flex-col items-center justify-center shadow-lg border border-slate-800/60 pb-1 hover:scale-105 group relative overflow-hidden transition-all duration-300`}>
                    <div className="flex gap-1 mb-1 z-10">
                        <div className="w-2.5 h-2.5 bg-white rounded-full flex items-center justify-center relative shadow-sm">
                            <div className="w-1 h-1 bg-slate-950 rounded-full absolute top-0.5 right-0.5"></div>
                        </div>
                        <div className="w-2.5 h-2.5 bg-white rounded-full flex items-center justify-center relative shadow-sm">
                            <div className="w-1 h-1 bg-slate-950 rounded-full absolute top-0.5 right-0.5"></div>
                        </div>
                    </div>
                    <div className="w-5 h-1.5 bg-black/35 rounded-full z-10 animate-pulse"></div>
                    <div className="absolute inset-0 bg-white/5 opacity-0 group-hover:opacity-100 transition-opacity"></div>
                </div>
                <div className="text-left">
                    <h1 className="text-2xl md:text-3xl font-extrabold tracking-tight text-white italic flex items-center gap-2 mb-1">
                       史萊姆方塊吞噬者
                    </h1>
                    <p className={`text-[10px] md:text-xs ${curWorld.color} tracking-[0.3em] uppercase font-mono font-bold`}>Slime Block Eater // Build & Play</p>
                </div>
            </div>
            <div className="flex flex-wrap items-center gap-3 shrink-0">
                <div className="flex items-center gap-2.5 bg-slate-900/85 hover:bg-slate-900 border border-slate-800/85 py-1.5 px-3 rounded-xl shadow-md transition-all">
                    <button 
                        onClick={() => {
                            const nextMute = !isSoundMuted;
                            setIsSoundMuted(nextMute);
                            SoundAPI.setMuted(nextMute);
                        }} 
                        className="flex items-center justify-center p-1 text-slate-300 hover:text-white transition-all cursor-pointer active:scale-95"
                        title={isSoundMuted ? "解鎖靜音" : "靜音模式"}
                    >
                        {isSoundMuted ? <VolumeX className="w-4 h-4 text-rose-400" /> : <Volume2 className={`w-4 h-4 ${curWorld.color} animate-pulse`} />}
                    </button>
                    <input 
                        type="range"
                        min="0"
                        max="100"
                        value={isSoundMuted ? 0 : Math.round(soundVolumeState * 100)}
                        onChange={(e) => {
                            const newVol = parseInt(e.target.value) / 100;
                            setSoundVolumeState(newVol);
                            SoundAPI.setVolume(newVol);
                            if (newVol > 0 && isSoundMuted) {
                                setIsSoundMuted(false);
                                SoundAPI.setMuted(false);
                            } else if (newVol === 0 && !isSoundMuted) {
                                setIsSoundMuted(true);
                                SoundAPI.setMuted(true);
                            }
                        }}
                        className="w-16 md:w-20 h-1 bg-slate-800/80 rounded-lg appearance-none cursor-pointer accent-purple-500 hover:accent-purple-400 transition-all"
                        title={`音量: ${Math.round(soundVolumeState * 100)}%`}
                    />
                    <span className="text-[10px] font-mono text-slate-400 w-8 text-right shrink-0">
                        {isSoundMuted ? "0%" : `${Math.round(soundVolumeState * 100)}%`}
                    </span>
                </div>
                <div className="flex items-center gap-3 bg-slate-900/80 border border-slate-800/80 py-2 px-4 rounded-xl text-[11px] text-slate-400 font-mono shadow-inner">
                    <span className={`w-2 h-2 rounded-full ${curWorld.dotColor}`}></span>
                    <span>BROWSER ENGINE: PERSISTENT SAVING</span>
                </div>
            </div>
        </div>

        {/* Mode Lobby Tab switches */}
        <div className="z-10 w-full max-w-7xl mx-auto px-6 flex justify-center pb-8 font-sans">
            <div className="bg-slate-950/80 border border-slate-800/80 p-1.5 rounded-2xl flex items-center max-w-md w-full shadow-2xl">
                <button
                    onClick={() => setLobbyTab('official')}
                    className={`flex-1 py-3 px-4 rounded-xl text-xs font-black uppercase tracking-wider transition-all flex items-center justify-center gap-2 cursor-pointer ${
                        lobbyTab === 'official'
                        ? `bg-gradient-to-r ${curWorld.btnGrad} text-white shadow-lg`
                        : 'text-slate-400 hover:text-slate-200'
                    }`}
                >
                    <Play className="w-4 h-4 fill-current" />
                    <span>🏆 關卡</span>
                </button>
                <button
                    onClick={() => setLobbyTab('custom')}
                    className={`flex-1 py-3 px-4 rounded-xl text-xs font-black uppercase tracking-wider transition-all flex items-center justify-center gap-2 cursor-pointer ${
                        lobbyTab === 'custom'
                        ? 'bg-gradient-to-r from-slate-850 to-slate-900 text-indigo-300 shadow-lg border border-slate-800'
                        : 'text-slate-400 hover:text-slate-200'
                    }`}
                >
                    <Hammer className="w-4 h-4 text-indigo-400" />
                    <span>🛠️ 編輯</span>
                </button>
            </div>
        </div>

        {/* World Selection Tabs Bar */}
        <div className="z-10 w-full max-w-7xl mx-auto px-6 mb-2">
            <div className="grid grid-cols-2 md:grid-cols-5 gap-3 bg-slate-950/45 p-2 rounded-2xl border border-slate-900 shadow-2xl">
                {WORLDS.map((w) => {
                    const isCurW = selectedWorld === w.id;
                    return (
                        <button
                            key={w.id}
                            onClick={() => setSelectedWorld(w.id)}
                            className={`py-3 px-4 rounded-xl text-center border flex flex-col items-center justify-center transition-all duration-300 relative overflow-hidden select-none cursor-pointer ${
                                isCurW
                                ? `bg-[#0e172e] ${w.border} ${w.color} shadow-lg ring-1 ${w.activeTabRing} scale-[1.01]`
                                : "bg-slate-900/10 border-slate-900/40 hover:border-slate-800 text-slate-400 hover:text-slate-200"
                            }`}
                        >
                            {/* Decorative colored glow if current */}
                            {isCurW && (
                                <div className={`absolute top-0 right-0 w-16 h-16 bg-gradient-to-br ${w.bg} rounded-full blur-xl opacity-80`} />
                            )}
                            <span className="text-xl mb-1 select-none relative z-10">{w.icon}</span>
                            <span className="text-xs font-black font-mono tracking-widest uppercase relative z-10">WORLD 0{w.id}</span>
                        </button>
                    );
                })}
            </div>
        </div>

        {/* Main lobby centerpiece grid only */}
        <div className="z-10 w-full max-w-7xl mx-auto px-6 space-y-6">
            <div className="flex items-center justify-between border-b border-slate-800 pb-3 mb-2">
                <h2 className={`text-base font-extrabold ${curWorld.color} font-mono tracking-widest uppercase flex items-center gap-2`}>
                    <Grid3X3 className={`w-5 h-5 ${curWorld.color} animate-spin-slow`} />
                    {lobbyTab === 'official' ? '冒險挑戰關卡 LEVEL SELECT' : '自訂地圖創作 CUSTOM WORKSPACE'}
                </h2>
                <span className="text-xs text-slate-500 font-mono bg-slate-900/40 border border-slate-800 px-2.5 py-1 rounded">5 WORLDS × 10 LEVELS = 50 SLOTS</span>
            </div>

            <div className="grid grid-cols-1 sm:grid-cols-3 gap-6 max-w-4xl mx-auto">
                {Array.from({length: 10}, (_, i) => i + 1).map(lvlIndex => {
                    const id = (selectedWorld - 1) * 10 + lvlIndex;
                    const isBoss = lvlIndex === 10;
                    const hasCustom = levelsMade[id - 1];
                    
                    if (isBoss) {
                        return (
                            <div 
                                key={id} 
                                onMouseEnter={() => setHoveredLevelId(id)}
                                onMouseLeave={() => setHoveredLevelId(null)}
                                className="group relative overflow-hidden rounded-2xl p-6 flex flex-col md:flex-row items-center justify-between gap-6 shadow-xl shadow-red-950/25 hover:-translate-y-1 hover:shadow-2xl transition-all duration-300 select-none cursor-pointer border col-span-1 sm:col-span-3 bg-gradient-to-r from-red-950/40 via-red-910/10 to-[#0d1226]/90 border-red-500/25 hover:border-red-400"
                            >
                                {/* Glowing ambient background inside boss frame */}
                                <div className="absolute inset-0 bg-gradient-to-tr from-transparent via-slate-905/5 to-slate-900/30 pointer-events-none"></div>
                                <div className="absolute inset-[1px] rounded-[15px] pointer-events-none z-0 bg-gradient-to-r from-[#170308] to-[#0a0d1c]"></div>

                                <div className="relative z-10 flex flex-col sm:flex-row items-center gap-5 flex-1">
                                    <div className="w-16 h-16 bg-[#2d0a15] border border-red-500/20 rounded-2xl flex items-center justify-center text-4xl shadow-md group-hover:scale-105 transition-transform duration-300 shrink-0">
                                        <span className="animate-bounce select-none">👿</span>
                                    </div>
                                    <div className="text-center sm:text-left">
                                        <div className="flex flex-wrap items-center justify-center sm:justify-start gap-2 mb-1.5">
                                            <span className="text-[9px] font-black tracking-widest text-red-400 bg-red-950 border border-red-550/30 px-2 py-0.5 rounded-md animate-pulse uppercase font-mono">
                                                WORLD {selectedWorld} BOSS STAGE
                                            </span>
                                            <span className="text-[9px] font-black tracking-widest text-indigo-400 bg-indigo-950/80 border border-indigo-550/30 px-2 py-0.5 rounded-md uppercase font-mono">
                                                SLOT {id}
                                            </span>
                                        </div>
                                        <h3 className="text-lg font-black tracking-tight text-red-200">
                                            世界首領挑戰
                                        </h3>
                                    </div>
                                </div>

                                <div className="relative z-10 w-full md:w-48 shrink-0 flex flex-col justify-center">
                                    {lobbyTab === 'official' ? (
                                        <button 
                                            onClick={() => onPlayOfficial(id)}
                                            className="w-full py-3 px-5 text-white font-black uppercase text-[11px] tracking-wider transition-all rounded-xl shadow-lg border border-red-400/40 hover:scale-[1.01] bg-gradient-to-r from-red-600 via-rose-600 to-red-650 cursor-pointer flex items-center justify-center gap-1.5 focus:outline-none"
                                        >
                                            <Play className="w-3.5 h-3.5 fill-current text-white" />
                                            <span>挑戰世界首領</span>
                                        </button>
                                    ) : (
                                        <div className="flex gap-2 w-full">
                                            <button 
                                                onClick={() => onEdit(id)}
                                                className="flex-1 py-3 bg-slate-900 hover:bg-slate-850 text-indigo-300 border border-indigo-500/35 font-extrabold text-[10px] tracking-wider transition-all rounded-xl flex items-center justify-center gap-1 cursor-pointer"
                                            >
                                                <Hammer className="w-3 h-3 text-indigo-400" />
                                                <span>編輯設計</span>
                                            </button>
                                            <button 
                                                onClick={() => onPlayTest(id)}
                                                className="flex-1 py-3 bg-gradient-to-r from-emerald-600 to-teal-600 hover:from-emerald-500 hover:to-teal-500 text-white font-extrabold text-[10px] tracking-wider transition-all rounded-xl flex items-center justify-center gap-1 cursor-pointer"
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

                    // Normal levels in a beautiful 3x3 layout
                    return (
                        <div 
                            key={id} 
                            onMouseEnter={() => setHoveredLevelId(id)}
                            onMouseLeave={() => setHoveredLevelId(null)}
                            className={`group relative overflow-hidden rounded-2xl p-6 flex flex-col justify-between h-48 shadow-lg shadow-black/40 hover:-translate-y-1 hover:shadow-xl transition-all duration-300 select-none cursor-pointer border ${
                                lobbyTab === 'custom' && hasCustom 
                                  ? 'border-indigo-500/50 hover:border-indigo-400 shadow-indigo-950/20 bg-[#0f1129]/90' 
                                  : `${curWorld.cardBorder} bg-[#0d1226]/80`
                            }`}
                        >
                            {/* Subtle internal depth outline */}
                            <div className="absolute inset-0 bg-gradient-to-tr from-transparent via-slate-905/10 to-slate-900/40 pointer-events-none"></div>
                            <div className="absolute inset-[1px] rounded-[15px] pointer-events-none z-0 bg-[#0c1024]/90"></div>

                            {/* Badge */}
                            {lobbyTab === 'custom' && (
                                hasCustom ? (
                                    <span className="absolute top-3.5 right-3.5 z-20 text-[8px] font-mono font-black tracking-widest text-[#a5b4fc] bg-indigo-950/80 border border-indigo-500/30 py-0.5 px-2 rounded-md animate-pulse">
                                        CUSTOM SAVED
                                    </span>
                                ) : (
                                    <span className="absolute top-3.5 right-3.5 z-20 text-[8px] font-mono font-black tracking-widest text-slate-500 bg-slate-950/80 border border-slate-800 py-0.5 px-2 rounded-md">
                                        EMPTY
                                    </span>
                                )
                            )}

                            {/* Centerpiece: Big Beautiful Double Digit Number */}
                            <div className="relative z-10 flex-1 flex flex-col items-center justify-center pt-4">
                                <span className={`text-5xl md:text-6xl font-black font-mono tracking-tighter transition-all duration-300 group-hover:scale-105 ${
                                    lobbyTab === 'official'
                                    ? `${curWorld.levelNumColor}`
                                    : 'text-indigo-500/70 group-hover:text-indigo-400'
                                }`}>
                                    {lvlIndex < 10 ? `0${lvlIndex}` : lvlIndex}
                                </span>
                            </div>

                            {/* Actions at the bottom */}
                            <div className="relative z-10 w-full">
                                {lobbyTab === 'official' ? (
                                    <button 
                                        onClick={() => onPlayOfficial(id)}
                                        className={`w-full py-2.5 text-white font-black uppercase text-[11px] tracking-wider transition-all rounded-xl shadow-md hover:shadow-lg cursor-pointer flex items-center justify-center gap-1.5 hover:scale-[1.01] bg-gradient-to-r ${curWorld.btnGrad}`}
                                    >
                                        <Play className="w-3 h-3 fill-current text-white" />
                                        <span>PLAY</span>
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
                                            className="flex-1 py-1.5 bg-gradient-to-r from-emerald-600 to-teal-600 hover:from-emerald-500 hover:to-teal-500 text-white font-extrabold text-[10px] tracking-wider transition-all rounded-xl flex items-center justify-center gap-1 cursor-pointer"
                                        >
                                            <Play className="w-3 h-3 fill-current" />
                                            <span>測試冒險</span>
                                        </button>
                                    </div>
                                )}
                            </div>
                        </div>
                    );
                })}
            </div>
        </div>
        
        <p className="z-10 mt-12 text-center text-[10px] text-slate-650 uppercase tracking-widest font-mono">
           CORE SYSTEM LOADED // PERSISTENT SLIME LEVEL DESIGNER
        </p>
    </div>
  );
}
