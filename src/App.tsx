import { useState, useEffect } from 'react';
import GameCanvas, { GameAPI, ControlBindings } from './components/GameCanvas';
import { SoundAPI } from './game/audio';
import { 
  Play, 
  Hammer, 
  ArrowLeft, 
  ChevronLeft, 
  ChevronRight, 
  Settings, 
  Check, 
  Sparkles, 
  RotateCcw, 
  Sliders, 
  Volume2,
  VolumeX,
  X,
  Keyboard
} from 'lucide-react';



import { WORLDS } from './game/worlds';
import Menu from './components/Menu';
import LevelEditorSidebar from './components/LevelEditorSidebar';

export default function App() {
  const [appState, setAppState] = useState<'menu' | 'play_official' | 'play_test' | 'edit'>('menu');
  const [isSoundMuted, setIsSoundMuted] = useState(SoundAPI.isMuted());
  const [soundVolumeState, setSoundVolumeState] = useState(SoundAPI.getVolume());
  const [lobbyTab, setLobbyTab] = useState<'official' | 'custom'>('official');
  const [selectedWorld, setSelectedWorld] = useState<number>(1);
  const [currentSlot, setCurrentSlot] = useState<number>(1);
  const [brush, setBrush] = useState('Dirt');
  const [mapSize, setMapSize] = useState({ cols: 40, rows: 15 });
  const [levelsMade, setLevelsMade] = useState<boolean[]>(Array(50).fill(false));
  const [resetCount, setResetCount] = useState<number>(0);
  const [toastMessage, setToastMessage] = useState<string | null>(null);
  
  const showToast = (msg: string) => {
      setToastMessage(msg);
      setTimeout(() => setToastMessage(null), 3000);
  };

  const [showClearConfirm, setShowClearConfirm] = useState<boolean>(false);
  const [isMapSizeOpen, setIsMapSizeOpen] = useState<boolean>(false);
  const [hoveredLevelId, setHoveredLevelId] = useState<number | null>(null);
  const [isGameMenuOpen, setIsGameMenuOpen] = useState<boolean>(false);
  const [gameSpeedState, setGameSpeedState] = useState<number>(GameAPI.getGameSpeed());
  const [controls, setControls] = useState<ControlBindings>(GameAPI.getControls());
  const [bulletTimeState, setBulletTimeState] = useState<boolean>(GameAPI.getBulletTimeEnabled());
  const [bindingAction, setBindingAction] = useState<keyof ControlBindings | null>(null);

  // Automatically pause/unpause when game menu opens
  useEffect(() => {
    GameAPI.setPaused(isGameMenuOpen);
    if (!isGameMenuOpen) setBindingAction(null);
  }, [isGameMenuOpen]);

  // Handle key binding globally
  useEffect(() => {
     if (bindingAction) {
         const handleKeyDown = (e: KeyboardEvent) => {
             e.preventDefault();
             const newControls = { ...controls, [bindingAction]: e.code };
             setControls(newControls);
             GameAPI.setControls(newControls);
             setBindingAction(null);
         };
         const handleMouseDown = (e: MouseEvent) => {
             e.preventDefault();
             let code = '';
             if (e.button === 0) code = 'MouseLeft';
             else if (e.button === 1) code = 'MouseMiddle';
             else if (e.button === 2) code = 'MouseRight';
             else return;
             
             const newControls = { ...controls, [bindingAction]: code };
             setControls(newControls);
             GameAPI.setControls(newControls);
             setBindingAction(null);
         };
         
         const handleContextMenu = (e: MouseEvent) => {
             e.preventDefault();
         };
         
         window.addEventListener('keydown', handleKeyDown);
         window.addEventListener('mousedown', handleMouseDown);
         window.addEventListener('contextmenu', handleContextMenu);
         return () => {
             window.removeEventListener('keydown', handleKeyDown);
             window.removeEventListener('mousedown', handleMouseDown);
             window.removeEventListener('contextmenu', handleContextMenu);
         };
     }
  }, [bindingAction, controls]);

  // Toggle menu with ESC key
  useEffect(() => {
    const handleKeyDown = (e: KeyboardEvent) => {
        if (e.key === 'Escape' && (appState === 'play_official' || appState === 'play_test')) {
            setIsGameMenuOpen(prev => !prev);
        }
    };
    window.addEventListener('keydown', handleKeyDown);
    return () => window.removeEventListener('keydown', handleKeyDown);
  }, [appState]);

  // Reset menu state on exit
  useEffect(() => {
    if (appState !== 'play_official' && appState !== 'play_test') {
        setIsGameMenuOpen(false);
    }
  }, [appState]);

  const checkLevels = () => {
    const status = [];
    for (let i = 1; i <= 50; i++) {
        status.push(!!localStorage.getItem(`slime_maker_level_${i}`));
    }
    setLevelsMade(status);
  };

  useEffect(() => {
    if (appState === 'menu') {
        checkLevels();
    }
  }, [appState]);

  const handlePlayOfficial = (slot: number) => {
      setCurrentSlot(slot);
      setAppState('play_official');
      setResetCount(r => r + 1);
  };

  const handlePlayTest = (slot: number) => {
      setCurrentSlot(slot);
      setAppState('play_test');
      setResetCount(r => r + 1);
  };

  const handleEdit = (slot: number) => {
      setCurrentSlot(slot);
      setAppState('edit');
      setResetCount(r => r + 1);
  };

  const handleRestart = () => {
    setResetCount(r => r + 1);
    showToast('🔄 關卡已重新開始');
  };

  const handlePrevLevel = () => {
    if (currentSlot > 1) {
        setCurrentSlot(prev => prev - 1);
        setResetCount(r => r + 1);
        showToast('⬅️ 載入上一關');
    }
  };

  const handleNextLevel = () => {
    if (currentSlot < 50) {
        setCurrentSlot(prev => prev + 1);
        setResetCount(r => r + 1);
        showToast('➡️ 載入下一關');
    }
  };

  const handleBrush = (b: string) => {
      setBrush(b);
      GameAPI.setBrush(b);
  };

  const handleResize = (cols: number, rows: number) => {
      setMapSize({cols, rows});
      GameAPI.resizeLevel(cols, rows);
      showToast('📏 畫布已調整');
  };

  const handleSave = () => {
      GameAPI.saveLevel();
      showToast('💾 關卡已儲存');
      checkLevels();
  };

  const handleClear = () => {
      GameAPI.clearLevel();
      showToast('🗑️ 畫布已清空');
      setShowClearConfirm(false);
  };

  if (appState === 'menu') {
      return (
          <Menu 
            isSoundMuted={isSoundMuted}
            setIsSoundMuted={setIsSoundMuted}
            soundVolumeState={soundVolumeState}
            setSoundVolumeState={setSoundVolumeState}
            lobbyTab={lobbyTab}
            setLobbyTab={setLobbyTab}
            selectedWorld={selectedWorld}
            setSelectedWorld={setSelectedWorld}
            levelsMade={levelsMade}
            onPlayOfficial={handlePlayOfficial}
            onPlayTest={handlePlayTest}
            onEdit={handleEdit}
            hoveredLevelId={hoveredLevelId}
            setHoveredLevelId={setHoveredLevelId}
          />
      );
  }

  if (appState === 'play_official' || appState === 'play_test') {
      return (
        <div className="w-full h-screen bg-[#070b1a] text-slate-100 font-sans flex flex-col overflow-hidden relative items-center justify-center">
             {/* Ambient Background Grid elements */}
             <div className="absolute inset-0 bg-[radial-gradient(#1e293b_1px,transparent_1px)] [background-size:32px_32px] opacity-15 pointer-events-none"></div>
             
             {/* Dynamic Floating Toast Feedback */}
             {toastMessage && (
                <div className="absolute top-4 left-1/2 -translate-x-1/2 z-50 bg-gradient-to-r from-emerald-600 to-indigo-600 outline outline-1 outline-emerald-400/30 text-white font-bold text-xs px-6 py-3 rounded-full flex items-center gap-2 shadow-[0_4px_25px_rgba(16,185,129,0.35)] animate-bounce duration-300">
                    <Check className="w-4 h-4 stroke-[3]" />
                    <span>{toastMessage}</span>
                </div>
             )}

             {/* Open Menu Button */}
             <div className="absolute top-4 right-4 z-20">
               <button 
                   onClick={() => setIsGameMenuOpen(true)}
                   className="px-4 py-2 bg-slate-900/90 border border-slate-800/80 hover:bg-slate-800 text-slate-300 hover:text-white rounded-xl text-xs font-black tracking-wider transition-all flex items-center gap-2 shadow-xl shadow-black/80 cursor-pointer active:scale-95 group"
               >
                   <Settings className="w-4 h-4 text-emerald-400 group-hover:rotate-45 transition-transform" />
                   <span>暫停 / 設定 (ESC)</span>
               </button>
             </div>

             {/* Settings & Pause Modal Overlay */}
             {isGameMenuOpen && (
                 <div className="absolute inset-0 z-50 bg-black/60 backdrop-blur-sm flex items-center justify-center p-4">
                     <div className="bg-slate-900 border border-slate-700/80 rounded-2xl w-full max-w-md shadow-2xl flex flex-col overflow-hidden animate-in fade-in zoom-in-95 duration-200">
                         <div className="p-4 bg-slate-800/40 border-b border-slate-700/50 flex items-center justify-between">
                             <h2 className="text-lg font-black text-slate-100 flex items-center gap-2">
                                 <Sliders className="w-5 h-5 text-emerald-400" />
                                 遊戲設定 MENU
                             </h2>
                             <button 
                                 onClick={() => setIsGameMenuOpen(false)}
                                 className="p-1 text-slate-400 hover:text-white bg-slate-800 hover:bg-slate-700 rounded-lg transition-colors cursor-pointer"
                             >
                                 <X className="w-5 h-5" />
                             </button>
                         </div>
                         <div className="p-6 space-y-6">
                             
                             {/* Volume Control */}
                             <div className="space-y-3">
                                 <div className="flex items-center justify-between text-sm font-bold text-slate-300">
                                     <span>音量大小 VOLUME</span>
                                     <span className="text-emerald-400">{isSoundMuted ? "0%" : `${Math.round(soundVolumeState * 100)}%`}</span>
                                 </div>
                                 <div className="flex items-center gap-3">
                                     <button 
                                         onClick={() => {
                                             const nextMute = !isSoundMuted;
                                             setIsSoundMuted(nextMute);
                                             SoundAPI.setMuted(nextMute);
                                         }} 
                                         className="p-2 bg-slate-800 hover:bg-slate-700 text-slate-300 hover:text-white rounded-xl transition-all cursor-pointer"
                                     >
                                         {isSoundMuted ? <VolumeX className="w-5 h-5 text-rose-400" /> : <Volume2 className="w-5 h-5 text-emerald-400" />}
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
                                         className="w-full h-2 bg-slate-800 rounded-lg appearance-none cursor-pointer accent-emerald-500 hover:accent-emerald-400 transition-all font-sans"
                                     />
                                 </div>
                             </div>

                             {/* Game Speed Control */}
                             <div className="space-y-3">
                                 <div className="flex items-center justify-between text-sm font-bold text-slate-300">
                                     <span>遊戲速度 GAME SPEED</span>
                                     <span className="text-emerald-400">x{gameSpeedState.toFixed(1)}</span>
                                 </div>
                                 <div className="grid grid-cols-4 gap-2">
                                     {[0.5, 1.0, 1.5, 2.0].map((s) => (
                                         <button 
                                             key={s}
                                             onClick={() => {
                                                 setGameSpeedState(s);
                                                 GameAPI.setGameSpeed(s);
                                             }}
                                             className={`py-2 rounded-lg text-xs font-black transition-all border cursor-pointer ${gameSpeedState === s ? 'bg-emerald-500/20 border-emerald-500/50 text-emerald-400' : 'bg-slate-800/80 border-slate-700/80 text-slate-400 hover:bg-slate-700 hover:text-slate-300'}`}
                                         >
                                             x{s.toFixed(1)}
                                         </button>
                                     ))}
                                 </div>
                             </div>

                             {/* Bullet Time Control */}
                             <div className="space-y-3 mb-6">
                                 <div className="flex items-center justify-between text-sm font-bold text-slate-300">
                                     <span>子彈時間 BULLET TIME</span>
                                 </div>
                                 <button
                                     onClick={() => {
                                         const newVal = !bulletTimeState;
                                         setBulletTimeState(newVal);
                                         GameAPI.setBulletTimeEnabled(newVal);
                                     }}
                                     className={`w-full py-2 rounded-lg text-sm font-black transition-all border cursor-pointer flex items-center justify-center gap-2 ${bulletTimeState ? 'bg-emerald-500/20 border-emerald-500/50 text-emerald-400' : 'bg-slate-800/80 border-slate-700/80 text-slate-400 hover:bg-slate-700 hover:text-slate-300'}`}
                                 >
                                     {bulletTimeState ? (
                                         <><Check className="w-4 h-4" /> 已啟用 (Enabled)</>
                                     ) : (
                                         <><X className="w-4 h-4" /> 已停用 (Disabled)</>
                                     )}
                                 </button>
                                 <p className="text-xs text-slate-500 mt-1 pb-2">長按射擊鍵緩慢時間及顯示輔助線，鬆開發射</p>
                             </div>

                             {/* Controls Info & Mapping */}
                             <div className="bg-slate-950/50 rounded-xl p-4 border border-slate-800/80">
                                 <h3 className="text-xs font-bold text-slate-400 mb-3 uppercase tracking-wider flex items-center gap-1.5">
                                    <Keyboard className="w-4 h-4" /> 操作按鍵 CONTROLS
                                 </h3>
                                 <div className="grid grid-cols-2 gap-y-2 gap-x-2 text-[11px] font-medium text-slate-300">
                                     <div className="flex items-center justify-between">
                                         <span>上 (Up)</span>
                                         <button onClick={() => setBindingAction('up')} className={`font-mono px-2 py-1 rounded border overflow-hidden whitespace-nowrap text-ellipsis max-w-[80px] ${bindingAction === 'up' ? 'bg-emerald-500/20 border-emerald-500 text-emerald-400 animate-pulse' : 'bg-slate-800 border-slate-700 hover:border-emerald-400/50'}`}>
                                            {bindingAction === 'up' ? '...' : controls.up.replace('Key', '')}
                                         </button>
                                     </div>
                                     <div className="flex items-center justify-between">
                                         <span>下 (Down)</span>
                                         <button onClick={() => setBindingAction('down')} className={`font-mono px-2 py-1 rounded border overflow-hidden whitespace-nowrap text-ellipsis max-w-[80px] ${bindingAction === 'down' ? 'bg-emerald-500/20 border-emerald-500 text-emerald-400 animate-pulse' : 'bg-slate-800 border-slate-700 hover:border-emerald-400/50'}`}>
                                            {bindingAction === 'down' ? '...' : controls.down.replace('Key', '')}
                                         </button>
                                     </div>
                                     <div className="flex items-center justify-between">
                                         <span>左 (Left)</span>
                                         <button onClick={() => setBindingAction('left')} className={`font-mono px-2 py-1 rounded border overflow-hidden whitespace-nowrap text-ellipsis max-w-[80px] ${bindingAction === 'left' ? 'bg-emerald-500/20 border-emerald-500 text-emerald-400 animate-pulse' : 'bg-slate-800 border-slate-700 hover:border-emerald-400/50'}`}>
                                            {bindingAction === 'left' ? '...' : controls.left.replace('Key', '').replace('Mouse', 'M-')}
                                         </button>
                                     </div>
                                     <div className="flex items-center justify-between">
                                         <span>右 (Right)</span>
                                         <button onClick={() => setBindingAction('right')} className={`font-mono px-2 py-1 rounded border overflow-hidden whitespace-nowrap text-ellipsis max-w-[80px] ${bindingAction === 'right' ? 'bg-emerald-500/20 border-emerald-500 text-emerald-400 animate-pulse' : 'bg-slate-800 border-slate-700 hover:border-emerald-400/50'}`}>
                                            {bindingAction === 'right' ? '...' : controls.right.replace('Key', '').replace('Mouse', 'M-')}
                                         </button>
                                     </div>
                                     <div className="flex items-center justify-between">
                                         <span>跳躍 (Jump)</span>
                                         <button onClick={() => setBindingAction('jump')} className={`font-mono px-2 py-1 rounded border overflow-hidden whitespace-nowrap text-ellipsis max-w-[80px] ${bindingAction === 'jump' ? 'bg-emerald-500/20 border-emerald-500 text-emerald-400 animate-pulse' : 'bg-slate-800 border-slate-700 hover:border-emerald-400/50'}`}>
                                            {bindingAction === 'jump' ? '...' : controls.jump.replace('Key', '').replace('Mouse', 'M-')}
                                         </button>
                                     </div>
                                     <div className="flex items-center justify-between">
                                         <span>吞噬 (Eat)</span>
                                         <button onClick={() => setBindingAction('eat')} className={`font-mono px-2 py-1 rounded border overflow-hidden whitespace-nowrap text-ellipsis max-w-[80px] ${bindingAction === 'eat' ? 'bg-emerald-500/20 border-emerald-500 text-emerald-400 animate-pulse' : 'bg-slate-800 border-slate-700 hover:border-emerald-400/50'}`}>
                                            {bindingAction === 'eat' ? '...' : controls.eat.replace('Key', '').replace('Mouse', 'M-')}
                                         </button>
                                     </div>
                                     <div className="flex items-center justify-between">
                                         <span>吐出 (Shoot)</span>
                                         <button onClick={() => setBindingAction('shoot')} className={`font-mono px-2 py-1 rounded border overflow-hidden whitespace-nowrap text-ellipsis max-w-[80px] ${bindingAction === 'shoot' ? 'bg-emerald-500/20 border-emerald-500 text-emerald-400 animate-pulse' : 'bg-slate-800 border-slate-700 hover:border-emerald-400/50'}`}>
                                            {bindingAction === 'shoot' ? '...' : controls.shoot.replace('Key', '').replace('Mouse', 'M-')}
                                         </button>
                                     </div>
                                     <div className="flex items-center justify-between">
                                         <span>重製 (Restart)</span>
                                         <button onClick={() => setBindingAction('restart')} className={`font-mono px-2 py-1 rounded border overflow-hidden whitespace-nowrap text-ellipsis max-w-[80px] ${bindingAction === 'restart' ? 'bg-emerald-500/20 border-emerald-500 text-emerald-400 animate-pulse' : 'bg-slate-800 border-slate-700 hover:border-emerald-400/50'}`}>
                                            {bindingAction === 'restart' ? '...' : controls.restart.replace('Key', '').replace('Mouse', 'M-')}
                                         </button>
                                     </div>
                                 </div>
                             </div>

                         </div>
                         <div className="p-4 bg-slate-800/40 border-t border-slate-700/50 flex justify-between gap-3">
                             <button
                                 onClick={() => {
                                     setIsGameMenuOpen(false);
                                     setAppState('menu');
                                 }}
                                 className="flex-1 py-2.5 bg-slate-800 hover:bg-slate-700 text-slate-300 hover:text-white border border-slate-700 rounded-xl text-sm font-bold transition-all cursor-pointer"
                             >
                                 返回主選單
                             </button>
                             <button
                                 onClick={() => setIsGameMenuOpen(false)}
                                 className="flex-1 py-2.5 bg-emerald-600 hover:bg-emerald-500 text-white border border-emerald-500/50 rounded-xl text-sm font-bold transition-all shadow-[0_4px_15px_rgba(16,185,129,0.3)] cursor-pointer"
                             >
                                 繼續遊戲
                             </button>
                         </div>
                     </div>
                 </div>
             )}

              {/* Single Game Window Centered vertically and horizontally - Expanded with perfect aspect ratio wrapping (16:9) */}
              <div className="z-10 bg-slate-950 p-2 md:p-3 rounded-2xl border border-slate-800 shadow-[0_4px_30px_rgba(0,0,0,0.8)] aspect-[16/9] w-[95vw] md:w-[90vw] max-w-[145vh] max-h-[82vh] flex flex-col justify-center">
                  <div className="relative border border-slate-800/80 rounded-xl overflow-hidden bg-black select-none w-full h-full flex items-center justify-center">
                     <GameCanvas 
                         key={`${appState}-${currentSlot}-${resetCount}`} 
                         mode="play" 
                         slot={currentSlot} 
                         onReturnMenu={() => setAppState('menu')}
                         onWinLevel={() => {
                             if (appState === 'play_official') {
                                 const nextSlot = currentSlot + 1;
                                 if (currentSlot < 50 && nextSlot <= 50) {
                                     setCurrentSlot(nextSlot);
                                     showToast('🚀 挑戰成功！自動加載下一關 🚀');
                                 } else {
                                     setAppState('menu');
                                     showToast('🎉 恭喜通關全部關卡！ 🎉');
                                 }
                             } else {
                                 // For custom test play
                                 setAppState('edit');
                                  showToast('🎉 自訂關卡測試完成！已返回編輯模式 🎉');
                              }
                          }}
                          onLoadLevelDims={(cols, rows) => {
                              setMapSize({ cols, rows });
                          }}
                          onBrushChange={setBrush}
                      />
                  </div>
              </div>
         </div>
       );
  }

  const isEditMode = appState === 'edit';
  const worldIdx = Math.floor((currentSlot - 1) / 10) + 1;
  const activeWorld = WORLDS[worldIdx - 1] || WORLDS[0];

  return (
    <div className="w-full h-screen bg-[#070b1a] text-slate-105 font-sans flex flex-col overflow-hidden relative">
      
      {/* Dynamic Floating Toast Feedback (Instead of blocking ugly alert) */}
      {toastMessage && (
        <div className={`absolute top-4 left-1/2 -translate-x-1/2 z-50 bg-gradient-to-r ${activeWorld.btnGrad} outline outline-1 outline-white/20 text-white font-bold text-xs px-6 py-3 rounded-full flex items-center gap-2 shadow-2xl animate-bounce duration-300`}>
            <Check className="w-4 h-4 stroke-[3]" />
            <span>{toastMessage}</span>
        </div>
      )}

      {/* Header Bar */}
      <header className="h-16 border-b border-slate-800 bg-[#0b0f1f]/90 flex items-center justify-between px-4 md:px-8 z-10 shrink-0 select-none">
        
        {/* Left Brand and Navigation */}
        <div className="flex items-center gap-4">
          <button 
              onClick={() => setAppState('menu')} 
              className="px-3 py-1.5 bg-slate-900 border border-slate-800 hover:bg-slate-800 text-slate-350 hover:text-white rounded-lg text-xs font-bold uppercase tracking-wider transition-all flex items-center gap-1.5"
          >
              <ArrowLeft className="w-4 h-4" />
              <span className="hidden sm:inline">選單</span> Menu
          </button>
          
          <div className="hidden lg:flex items-center gap-3 pl-3 border-l border-slate-800">
             <div className={`w-8 h-8 rounded-lg ${activeWorld.subIconBg} flex items-center justify-center`}>
                 <div className={`w-4 h-4 ${activeWorld.dotColor} rounded-full animate-pulse`}></div>
             </div>
             <div>
                <h2 className="text-xs font-black tracking-widest text-[#eff6ff] uppercase italic leading-none">史萊姆方塊吞噬者</h2>
                <span className={`text-[8.5px] font-mono font-bold tracking-[0.22em] h-2.5 ${activeWorld.color} uppercase leading-none block mt-1`}>WORLD {worldIdx} // LEVEL {((currentSlot - 1) % 10) + 1}</span>
             </div>
          </div>
        </div>

        {/* Center Mode Switcher - Pill slider design */}
        {appState !== 'play_official' ? (
            <div className="flex items-center gap-1 bg-slate-950 border border-slate-800 p-1 rounded-xl">
               <button 
                  onClick={() => setAppState('play_test')}
                  className={`px-4 py-1.5 rounded-lg text-xs font-bold uppercase tracking-wider transition-all flex items-center gap-1.5 cursor-pointer ${
                     appState === 'play_test' 
                     ? `bg-gradient-to-r ${activeWorld.btnGrad} text-white font-extrabold shadow-md` 
                     : 'text-slate-400 hover:text-slate-200 hover:bg-slate-900/50'
                  }`}
               >
                  <Play className="w-3.5 h-3.5 fill-current" />
                  測試冒險 Play
               </button>
               <button 
                  onClick={() => setAppState('edit')}
                  className={`px-4 py-1.5 rounded-lg text-xs font-bold uppercase tracking-wider transition-all flex items-center gap-1.5 cursor-pointer ${
                     appState === 'edit' 
                     ? `bg-gradient-to-r ${activeWorld.btnGrad} text-white font-extrabold shadow-md` 
                     : 'text-slate-400 hover:text-slate-200 hover:bg-slate-900/50'
                  }`}
               >
                  <Hammer className="w-3.5 h-3.5" />
                  地圖編輯 Build
               </button>
            </div>
         ) : (
            <div className={`px-5 py-2 bg-gradient-to-r ${activeWorld.accentBg} rounded-xl flex items-center gap-2`}>
                <Sparkles className={`w-4 h-4 ${activeWorld.color} animate-pulse`} />
                <span className={`text-[10px] md:text-xs uppercase font-extrabold tracking-widest ${activeWorld.color} font-mono`}>🏆 WORLD {worldIdx} 挑戰關卡</span>
            </div>
         )}

        {/* Right Level Selector & Indicators */}
        <div className="flex items-center gap-2">
            
            {/* Quick Level Switcher */}
            <div className="flex items-center gap-1 bg-slate-900/90 border border-slate-800 p-1.5 rounded-xl">
                <button 
                   onClick={handlePrevLevel}
                   disabled={currentSlot === 1}
                   className="w-7 h-7 bg-slate-950 hover:bg-slate-800 disabled:opacity-30 disabled:hover:bg-slate-950 rounded-lg flex items-center justify-center transition-colors border border-slate-800"
                >
                     <ChevronLeft className="w-4 h-4 text-slate-300" />
                </button>
                
                <span className={`px-3 text-xs font-bold font-mono tracking-widest ${activeWorld.color}`}>
                    SLOT {currentSlot < 10 ? '0' + currentSlot : currentSlot}
                </span>

                <button 
                   onClick={handleNextLevel}
                   disabled={currentSlot === 50}
                   className="w-7 h-7 bg-slate-950 hover:bg-slate-800 disabled:opacity-30 disabled:hover:bg-slate-950 rounded-lg flex items-center justify-center transition-colors border border-slate-800"
                >
                     <ChevronRight className="w-4 h-4 text-slate-300" />
                </button>
            </div>
        </div>
      </header>
      
      {/* Main Workspace Frame */}
      <div className="flex-1 relative bg-[radial-gradient(#1e293b_1px,transparent_1px)] [background-size:32px_32px] overflow-hidden flex flex-col lg:flex-row">
        
        {/* Game Stage Area */}
        <div className="flex-1 relative p-4 md:p-6 lg:p-8 flex items-center justify-center overflow-auto">
          
          <div className="bg-slate-950 p-3 rounded-2xl border border-slate-800 flex flex-col gap-2 shadow-[0_4px_30px_rgba(0,0,0,0.6)]">
             
             {/* Stage Info Header Ribbon */}
             <div className="flex items-center justify-between px-2 py-1 bg-slate-900/70 border border-slate-800 rounded-lg text-xs">
                <div className="flex items-center gap-2">
                   <span className={`w-2.5 h-2.5 rounded-full ${activeWorld.dotColor} animate-pulse`}></span>
                   <span className="font-extrabold text-slate-200 tracking-wide">
                      SLOT {currentSlot < 10 ? `0${currentSlot}` : currentSlot} (WORLD {worldIdx})
                   </span>
                </div>
                <div className="flex items-center gap-3 text-[10px] font-mono text-slate-500 uppercase tracking-widest">
                   <span>Viewport: Fixed 800×600</span>
                   <span className="border-l border-slate-800 pl-3">DIMS: {mapSize.cols} × {mapSize.rows}</span>
                </div>
             </div>

             {/* Raw Game Canvas Wrapper */}
             <div className="relative border border-slate-800/80 rounded-xl overflow-hidden shadow-2xl bg-black select-none">
                 <GameCanvas 
                     key={`${appState}-${currentSlot}-${resetCount}`} 
                     mode={isEditMode ? 'edit' : 'play'} 
                     slot={currentSlot} 
                     onReturnMenu={() => setAppState('menu')}
                     onWinLevel={() => {
                         if (appState === 'play_official') {
                             const nextSlot = currentSlot + 1;
                             if (currentSlot < 50 && nextSlot <= 50) {
                                 setCurrentSlot(nextSlot);
                                 showToast('🚀 挑戰成功！自動加載下一關 🚀');
                             } else {
                                 setAppState('menu');
                                 showToast('🎉 恭喜通關全部正式關卡！ 🎉');
                             }
                         } else {
                             // For custom test play
                             setAppState('edit');
                             showToast('🎉 自訂關卡測試完成！已返回編輯模式 🎉');
                         }
                     }}
                     onLoadLevelDims={(cols, rows) => {
                         setMapSize({ cols, rows });
                     }}
                     onBrushChange={setBrush}
                 />
             </div>

             {/* Small Control Ribbon for Play Testing (on screen button helpful for tablets/convenience) */}
              {!isEditMode && (
                 <div className="flex items-center justify-end gap-4 mt-1 px-1">
                    <button 
                       onClick={handleRestart}
                       className="px-4 py-1.5 bg-slate-900 hover:bg-slate-850 active:bg-slate-950 border border-slate-800 hover:border-slate-750 text-slate-300 font-bold text-xs rounded-xl flex items-center gap-1.5 transition-all shadow-inner shrink-0 cursor-pointer"
                    >
                       <RotateCcw className="w-3.5 h-3.5" />
                       重新挑戰 (R)
                    </button>
                 </div>
              )}
           </div>
         </div>
         
         {/* Right Sidebar Workspace Controls */}
         <div className="w-full lg:w-80 bg-[#0f1527]/90 border-t lg:border-t-0 lg:border-l border-slate-800 p-5 flex flex-col gap-5 overflow-y-auto shrink-0 z-10 select-none max-h-[300px] lg:max-h-full">
           
           {isEditMode && (
             <LevelEditorSidebar currentSlot={currentSlot} onImportSuccess={(msg) => { setResetCount(r => r + 1); showToast(msg); checkLevels(); }} 
               brush={brush}
               handleBrush={handleBrush}
               mapSize={mapSize}
               isMapSizeOpen={isMapSizeOpen}
               setIsMapSizeOpen={setIsMapSizeOpen}
               handleResize={handleResize}
               handleSave={handleSave}
               showClearConfirm={showClearConfirm}
               setShowClearConfirm={setShowClearConfirm}
               handleClear={handleClear}
             />
            )}
          </div>
        </div>
      
      {/* Footer bar */}
      <footer className="h-12 bg-[#090d19] border-t border-slate-850 px-6 flex items-center justify-between z-10 shrink-0 select-none text-[10px] text-slate-500 font-mono">
        <div className="flex items-center gap-6">
          <div className="flex items-center gap-1.5">
            <span className={`w-2.5 h-2.5 rounded-full ${isEditMode ? 'bg-indigo-500' : 'bg-emerald-500 animate-pulse'}`}></span>
            <span className="uppercase tracking-wider text-slate-400">
               {isEditMode ? 'WORKSPACE: EDITOR ACTIVE' : 'LIVESTAGE: RUNNING'}
            </span>
          </div>
          <span className="hidden sm:inline border-l border-slate-850 pl-4 text-slate-650">SYSTEM STABLE: 60 FPS</span>
        </div>
        <p className="hidden md:block">SLIME ENGINE X3.0.1 // CRAFTED & POLISHED</p>
      </footer>
    </div>
  );
}
