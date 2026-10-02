import { useState } from 'react';
import { Sliders, Grid3X3, ChevronUp, ChevronDown, Save, Trash2, Download, Upload, Copy, Check, FileText, AlertCircle } from 'lucide-react';

interface LevelEditorSidebarProps {
  brush: string;
  handleBrush: (b: string) => void;
  mapSize: { cols: number; rows: number };
  isMapSizeOpen: boolean;
  setIsMapSizeOpen: (o: boolean) => void;
  handleResize: (c: number, r: number) => void;
  handleSave: () => void;
  showClearConfirm: boolean;
  setShowClearConfirm: (s: boolean) => void;
  handleClear: () => void;
  currentSlot?: number;
  onImportSuccess?: (msg: string) => void;
}

export default function LevelEditorSidebar({
  brush,
  handleBrush,
  mapSize,
  isMapSizeOpen,
  setIsMapSizeOpen,
  handleResize,
  handleSave,
  showClearConfirm,
  setShowClearConfirm,
  handleClear,
  currentSlot = 1,
  onImportSuccess
}: LevelEditorSidebarProps) {
  const [isBackupOpen, setIsBackupOpen] = useState(false);
  const [importText, setImportText] = useState('');
  const [copiedText, setCopiedText] = useState<'current' | 'all' | null>(null);
  const [importError, setImportError] = useState<string | null>(null);

  const handleExportCurrent = () => {
    const data = localStorage.getItem(`slime_maker_level_${currentSlot}`);
    if (!data) {
      alert(`請先點擊「儲存關卡」再進行匯出！\n(Slot ${currentSlot} 尚未有儲存資料)`);
      return;
    }
    navigator.clipboard.writeText(data).then(() => {
      setCopiedText('current');
      setTimeout(() => setCopiedText(null), 2000);
    }).catch(() => {
      setImportText(data);
      alert("複製失敗，已將資料填入下方文字框，您可以手動複製！");
    });
  };

  const handleExportAll = () => {
    const allData: Record<string, string[]> = {};
    let count = 0;
    for (let i = 1; i <= 50; i++) {
      const data = localStorage.getItem(`slime_maker_level_${i}`);
      if (data) {
        try {
          allData[`slime_maker_level_${i}`] = JSON.parse(data);
          count++;
        } catch (e) {}
      }
    }
    if (count === 0) {
      alert("目前沒有任何已儲存的自訂關卡可匯出！");
      return;
    }
    const jsonStr = JSON.stringify(allData, null, 2);
    navigator.clipboard.writeText(jsonStr).then(() => {
      setCopiedText('all');
      setTimeout(() => setCopiedText(null), 2000);
    }).catch(() => {
      setImportText(jsonStr);
      alert("複製失敗，已將資料填入下方文字框，您可以手動複製！");
    });
  };

  const handleImport = () => {
    const trimmed = importText.trim();
    if (!trimmed) {
      setImportError("請先貼上關卡資料！");
      return;
    }
    try {
      const parsed = JSON.parse(trimmed);
      
      // Case 1: Multiple levels packed
      if (parsed && typeof parsed === 'object' && !Array.isArray(parsed)) {
        let importedCount = 0;
        Object.entries(parsed).forEach(([key, val]) => {
          if (key.startsWith('slime_maker_level_') && Array.isArray(val)) {
            localStorage.setItem(key, JSON.stringify(val));
            importedCount++;
          }
        });
        if (importedCount > 0) {
          setImportText('');
          setImportError(null);
          if (onImportSuccess) {
            onImportSuccess(`成功匯入 ${importedCount} 個自訂關卡！`);
          } else {
            alert(`成功匯入 ${importedCount} 個自訂關卡！`);
            window.location.reload();
          }
        } else {
          setImportError("格式不符！找不到任何 slime_maker_level_ 鍵值。");
        }
      } 
      // Case 2: Single level array of strings
      else if (Array.isArray(parsed)) {
        if (parsed.every(el => typeof el === 'string')) {
          localStorage.setItem(`slime_maker_level_${currentSlot}`, JSON.stringify(parsed));
          setImportText('');
          setImportError(null);
          if (onImportSuccess) {
            onImportSuccess(`成功將關卡載入至 SLOT ${currentSlot}！`);
          } else {
            alert(`成功將關卡載入至 SLOT ${currentSlot}！`);
            window.location.reload();
          }
        } else {
          setImportError("關卡內容格式錯誤（必須為字串陣列）。");
        }
      } else {
        setImportError("未知的 JSON 格式，無法解析。");
      }
    } catch (e) {
      setImportError("解析失敗！請確保貼上的是正確的 JSON 格式。");
    }
  };
  return (
    <div className="flex flex-col gap-4 h-full">
      {/* Brush selection card */}
      <div className="p-4 rounded-2xl bg-slate-900/60 border border-slate-800/80 shadow-md flex-1 flex flex-col min-h-0">
        <div className="flex items-center gap-2 mb-4 shrink-0">
          <div className="w-7 h-7 rounded-lg bg-indigo-500/15 text-indigo-400 flex items-center justify-center">
            <Sliders className="w-4 h-4" />
          </div>
          <div>
            <h3 className="text-xs font-black text-white tracking-widest uppercase">編輯筆刷 brushes</h3>
            <p className="text-[9px] text-slate-500 font-bold uppercase tracking-wide">2-Row Grid Paint Mode</p>
          </div>
        </div>

        {/* Grid layout for Brushes: Double-column styling with wide comfortable eraser at bottom */}
        <div className="flex-1 overflow-y-auto pr-1 [&::-webkit-scrollbar]:w-1.5 [&::-webkit-scrollbar-thumb]:bg-slate-800 [&::-webkit-scrollbar-thumb]:rounded-full [&::-webkit-scrollbar-track]:bg-transparent">
          <div className="grid grid-cols-2 gap-2.5">
            {[
              { id: 'Dirt', symbol: '🟫', color: 'border-amber-500/65 text-amber-300 bg-amber-500/10' },
              { id: 'Bouncy', symbol: '🍥', color: 'border-pink-500/65 text-pink-300 bg-pink-500/10' },
              { id: 'Steel', symbol: '⬛', color: 'border-slate-500/65 text-slate-300 bg-slate-500/10' },
              { id: 'Breakable', symbol: '💠', color: 'border-cyan-500/65 text-cyan-400 bg-cyan-500/10' },
              { id: 'Void', symbol: '🕳️', color: 'border-purple-500/65 text-purple-400 bg-purple-500/10' },
              { id: 'Spikes', symbol: '🔺', color: 'border-red-500/65 text-red-400 bg-red-450/10' },
              { id: 'Goal', symbol: '⭐', color: 'border-yellow-500/65 text-yellow-300 bg-yellow-450/10' },
              { id: 'Player', symbol: '🟢', color: 'border-emerald-500/65 text-emerald-300 bg-emerald-450/10' },
              { id: 'Camera', symbol: '📸', color: 'border-blue-400/65 text-blue-300 bg-blue-500/10' },
              { id: 'Paste', symbol: '📋', color: 'border-sky-400/65 text-sky-300 bg-sky-500/10' },
              { id: 'Air', symbol: '💨', color: 'border-indigo-500/60 text-indigo-300 bg-indigo-500/10' }
            ].map(b => {
              const isSelected = brush === b.id || (b.id === 'Spikes' && ['Spikes', 'SpikesUp', 'SpikesRight', 'SpikesDown', 'SpikesLeft'].includes(brush));
              const isEraser = b.id === 'Air';
              
              return (
                <button 
                  key={b.id}
                  onClick={() => handleBrush(b.id)}
                  className={`p-3 rounded-xl flex flex-col items-center justify-center text-center transition-all duration-200 border group cursor-pointer min-h-[78px] ${
                    isEraser ? 'col-span-2 flex-row gap-3 min-h-[52px]' : 'col-span-1'
                  } ${
                    isSelected 
                    ? `${b.color} border-current ring-1 ring-current shadow-lg scale-[1.02]` 
                    : 'bg-slate-950/65 border-slate-800/80 hover:border-slate-700 hover:bg-slate-900/60'
                  }`}
                >
                  <div className={`rounded-lg flex items-center justify-center shadow-inner transition-colors shrink-0 ${
                    isEraser ? 'w-full h-12 text-2xl bg-slate-900' : 'w-full h-12 text-2xl bg-slate-900'
                  } ${
                    isSelected ? 'bg-slate-900/80 font-black scale-110' : 'group-hover:bg-slate-850'
                  }`}>
                    {b.symbol}
                  </div>
                </button>
              );
            })}
          </div>
        </div>

        {/* 🔺 Spike Direction Sub-Panel */}
        {['Spikes', 'SpikesUp', 'SpikesRight', 'SpikesDown', 'SpikesLeft'].includes(brush) && (
          <div className="mt-4 p-3 rounded-xl bg-red-950/20 border border-red-900/40 space-y-2 shrink-0 animate-fade-in">
            <p className="text-[10px] uppercase font-black tracking-widest text-red-100 flex items-center gap-1.5">
              <Sliders className="w-3 h-3 text-red-400" />
              <span>尖刺朝向 Spike Direction</span>
            </p>
            <div className="grid grid-cols-4 gap-1.5">
              {[
                { id: 'Spikes', icon: '🔺' },
                { id: 'SpikesRight', icon: '▶️' },
                { id: 'SpikesDown', icon: '🔻' },
                { id: 'SpikesLeft', icon: '◀️' },
              ].map(dir => (
                <button
                  key={dir.id}
                  onClick={() => handleBrush(dir.id)}
                  className={`py-1.5 rounded-lg border text-base font-bold flex items-center justify-center transition-all cursor-pointer ${
                    brush === dir.id || (dir.id === 'Spikes' && brush === 'SpikesUp')
                      ? 'bg-red-500/35 border-red-550 text-white shadow-md scale-105'
                      : 'bg-slate-950/90 border-slate-800 text-slate-400 hover:border-slate-700 hover:text-slate-200'
                  }`}
                >
                  {dir.icon}
                </button>
              ))}
            </div>
          </div>
        )}

      </div>

      {/* 📐 地圖大小 Map Size preset with collapsible option */}
      <div className="rounded-xl bg-slate-900/30 border border-slate-800/80 overflow-hidden shrink-0 transition-all">
          
          {/* Collapsible Trigger Header */}
          <button 
              type="button"
              onClick={() => setIsMapSizeOpen(!isMapSizeOpen)}
              className="w-full px-4 py-3 flex items-center justify-between text-slate-300 hover:text-white hover:bg-slate-900/40 transition-colors cursor-pointer"
          >
              <div className="flex items-center gap-2">
                  <Grid3X3 className="w-4 h-4 text-indigo-400" />
                  <span className="text-[10px] font-black uppercase tracking-wider">📐 地圖大小配置 MAP SIZE</span>
              </div>
              
              <div className="flex items-center gap-1.5">
                  <span className="text-[10px] font-mono bg-slate-950 px-2.5 py-0.5 rounded text-indigo-455 font-bold">
                      {mapSize.cols}×{mapSize.rows}
                  </span>
                  {isMapSizeOpen ? (
                      <ChevronUp className="w-3.5 h-3.5 text-slate-500" />
                  ) : (
                      <ChevronDown className="w-3.5 h-3.5 text-slate-500" />
                  )}
              </div>
          </button>

          {/* Collapsible Content Body */}
          {isMapSizeOpen && (
              <div className="p-4 pt-1 border-t border-slate-850/80 space-y-3 bg-slate-950/25">
                  {/* Size sliders in buttons */}
                  <div className="grid grid-cols-2 gap-2">
                      <div>
                          <label className="block text-[8px] uppercase text-slate-500 font-bold mb-1 font-mono">寬度 (10~200)</label>
                          <div className="flex items-center gap-1 bg-slate-950 p-1 rounded-lg border border-slate-800">
                              <button 
                                  type="button"
                                  onClick={() => handleResize(mapSize.cols - 10, mapSize.rows)}
                                  className="w-5 h-5 bg-slate-800 hover:bg-slate-700 rounded text-slate-205 flex items-center justify-center font-bold text-[10px] select-none transition-colors cursor-pointer"
                              >
                                  -
                              </button>
                              <div className="flex-1 text-center font-mono text-[10px] text-slate-200">
                                  {mapSize.cols}
                              </div>
                              <button 
                                  type="button"
                                  onClick={() => handleResize(mapSize.cols + 10, mapSize.rows)}
                                  className="w-5 h-5 bg-slate-800 hover:bg-slate-700 rounded text-slate-205 flex items-center justify-center font-bold text-[10px] select-none transition-colors cursor-pointer"
                              >
                                  +
                              </button>
                          </div>
                      </div>

                      <div>
                          <label className="block text-[8px] uppercase text-slate-500 font-bold mb-1 font-mono">高度 (10~120)</label>
                          <div className="flex items-center gap-1 bg-slate-950 p-1 rounded-lg border border-slate-800">
                              <button 
                                  type="button"
                                  onClick={() => handleResize(mapSize.cols, mapSize.rows - 5)}
                                  className="w-5 h-5 bg-slate-800 hover:bg-slate-700 rounded text-slate-205 flex items-center justify-center font-bold text-[10px] select-none transition-colors cursor-pointer"
                              >
                                  -
                              </button>
                              <div className="flex-1 text-center font-mono text-[10px] text-slate-200">
                                  {mapSize.rows}
                              </div>
                              <button 
                                  type="button"
                                  onClick={() => handleResize(mapSize.cols, mapSize.rows + 5)}
                                  className="w-5 h-5 bg-slate-800 hover:bg-slate-700 rounded text-slate-205 flex items-center justify-center font-bold text-[10px] select-none transition-colors cursor-pointer"
                              >
                                  +
                              </button>
                          </div>
                      </div>
                  </div>

                  {/* Quick-Preset-Toggles */}
                  <div className="pt-2 border-t border-slate-900/80">
                      <div className="grid grid-cols-3 gap-1 text-[8.5px] font-mono leading-tight">
                          {[
                              { c: 25, r: 15 },
                              { c: 40, r: 15 },
                              { c: 40, r: 24 },
                              { c: 65, r: 18 },
                              { c: 90, r: 25 },
                              { c: 160, r: 32 },
                          ].map((preset, idx) => {
                             const isCurrent = mapSize.cols === preset.c && mapSize.rows === preset.r;
                             return (
                               <button
                                   key={idx}
                                   type="button"
                                   onClick={() => handleResize(preset.c, preset.r)}
                                   className={`py-1 text-center rounded border transition-colors cursor-pointer truncate ${
                                      isCurrent 
                                      ? 'bg-indigo-500/20 text-indigo-300 border-indigo-500/40 font-bold' 
                                      : 'bg-slate-950/60 text-slate-400 border-slate-850 hover:bg-slate-800 hover:text-slate-200'
                                   }`}
                               >
                                   {preset.c}×{preset.r}
                               </button>
                             );
                          })}
                      </div>
                  </div>
              </div>
          )}
      </div>

      {/* 📤 匯出 / 匯入自訂關卡 IMPORT & EXPORT */}
      <div className="rounded-xl bg-slate-900/30 border border-slate-800/80 overflow-hidden shrink-0 transition-all">
          <button 
              type="button"
              onClick={() => setIsBackupOpen(!isBackupOpen)}
              className="w-full px-4 py-3 flex items-center justify-between text-slate-300 hover:text-white hover:bg-slate-900/40 transition-colors cursor-pointer"
          >
              <div className="flex items-center gap-2">
                  <Download className="w-4 h-4 text-indigo-400" />
                  <span className="text-[10px] font-black uppercase tracking-wider">📤 匯出/匯入自訂關卡 BACKUP</span>
              </div>
              <div>
                  {isBackupOpen ? (
                      <ChevronUp className="w-3.5 h-3.5 text-slate-500" />
                  ) : (
                      <ChevronDown className="w-3.5 h-3.5 text-slate-500" />
                  )}
              </div>
          </button>

          {isBackupOpen && (
              <div className="p-4 pt-1 border-t border-slate-850/80 space-y-3 bg-slate-950/25">
                  <p className="text-[10px] text-slate-400 leading-relaxed font-medium">
                      您可以將自己設計的關卡導出為 JSON 文字，分享給其他人或在其他瀏覽器中匯入！
                  </p>
                  
                  <div className="grid grid-cols-2 gap-2">
                      <button
                          type="button"
                          onClick={handleExportCurrent}
                          className="py-2 px-3 bg-slate-900 hover:bg-slate-850 text-slate-200 border border-slate-800 rounded-lg text-[10px] font-bold flex items-center justify-center gap-1.5 transition-colors cursor-pointer"
                      >
                          {copiedText === 'current' ? (
                              <><Check className="w-3.5 h-3.5 text-emerald-400" /> 已複製此關</>
                          ) : (
                              <><Copy className="w-3.5 h-3.5 text-indigo-400" /> 匯出當前關卡</>
                          )}
                      </button>
                      <button
                          type="button"
                          onClick={handleExportAll}
                          className="py-2 px-3 bg-slate-900 hover:bg-slate-850 text-slate-200 border border-slate-800 rounded-lg text-[10px] font-bold flex items-center justify-center gap-1.5 transition-colors cursor-pointer"
                      >
                          {copiedText === 'all' ? (
                              <><Check className="w-3.5 h-3.5 text-emerald-400" /> 已複製全部</>
                          ) : (
                              <><FileText className="w-3.5 h-3.5 text-indigo-400" /> 匯出所有關卡</>
                          )}
                      </button>
                  </div>

                  <div className="space-y-1.5">
                      <label className="block text-[8px] uppercase text-slate-500 font-bold font-mono">貼上欲匯入的 JSON 關卡資料</label>
                      <textarea
                          rows={3}
                          value={importText}
                          onChange={(e) => {
                              setImportText(e.target.value);
                              setImportError(null);
                          }}
                          placeholder="在此貼上匯出的單一關卡陣列或多關卡打包 JSON..."
                          className="w-full bg-slate-950 p-2 text-[10px] font-mono text-slate-300 rounded-lg border border-slate-800 focus:border-indigo-500 focus:outline-none resize-none placeholder-slate-700 leading-normal"
                      />
                      
                      {importError && (
                          <div className="flex items-start gap-1.5 p-2 rounded bg-red-955/10 border border-red-900/30 text-[9px] text-red-400 font-bold">
                              <AlertCircle className="w-3 h-3 shrink-0 mt-0.5" />
                              <span>{importError}</span>
                          </div>
                      )}

                      <button
                          type="button"
                          onClick={handleImport}
                          className="w-full py-2 bg-indigo-600/80 hover:bg-indigo-600 text-white rounded-lg text-[10px] font-black tracking-wide transition-colors flex items-center justify-center gap-1.5 cursor-pointer border border-indigo-500/20 shadow-md"
                      >
                          <Upload className="w-3.5 h-3.5" />
                          執行匯入 IMPORT DATA
                      </button>
                  </div>
              </div>
          )}
      </div>

      <button 
          onClick={handleSave} 
          className="w-full py-3 bg-gradient-to-r from-indigo-650 to-indigo-500 hover:from-indigo-600 hover:to-indigo-400 text-white rounded-xl font-bold text-xs tracking-wider transition-all shadow-[0_0_15px_rgba(99,102,241,0.2)] flex items-center justify-center gap-2 cursor-pointer border border-indigo-400/20"
      >
          <Save className="w-4 h-4" />
          儲存關卡 SAVE LEVEL
      </button>

      {showClearConfirm ? (
          <div className="bg-red-950/40 border border-red-500/40 p-2.5 rounded-xl space-y-2 text-center">
             <p className="text-[10px] text-red-200 font-bold">確定要清空關卡地圖嗎？(無法還原)</p>
             <div className="flex gap-2">
                <button 
                   onClick={handleClear}
                   className="flex-1 py-1 bg-red-650 text-white font-bold text-[10px] rounded-lg hover:bg-red-600 transition-colors cursor-pointer"
                >
                   沒錯，清空
                </button>
                <button 
                   onClick={() => setShowClearConfirm(false)}
                   className="flex-1 py-1 bg-slate-805 text-slate-300 font-bold text-[10px] rounded-lg hover:bg-slate-700 transition-colors cursor-pointer"
                >
                   取消
                </button>
             </div>
          </div>
      ) : (
          <button 
             onClick={() => setShowClearConfirm(true)} 
             className="w-full py-2 bg-slate-950/60 hover:bg-red-950/30 text-slate-400 hover:text-red-400 border border-slate-850 hover:border-red-900/30 rounded-xl text-xs font-bold font-mono tracking-wide transition-colors flex items-center justify-center gap-2 cursor-pointer"
          >
             <Trash2 className="w-4 h-4" />
             清空編輯器 CLEAR
          </button>
      )}
    </div>
  );
}
