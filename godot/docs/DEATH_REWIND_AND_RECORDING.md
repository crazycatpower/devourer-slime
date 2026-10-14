# 死亡倒流與世界 1 通關錄影（2026-10-10）

死亡白閃已替換為場景歷史倒播，使用 75 tick 的回復時間。倒到最近安全點後還原角色、鏡頭、地形、Boss、投射物、機關與隨機狀態，角色速度歸零、清除舊輸入後直接繼續，不重開關卡。倒播期間不新增角色跳躍／落地粒子及反應音效；R 可略過倒流直接回安全點，平時 R 仍可主動重玩。

連續畫面歷史保存最多 180 個樣本（六秒），每兩個模擬 tick 記錄一次，另外保留最多 32 個安全點。每 12 tick 檢查落點：尖刺留 10 像素距離，獨立模擬未來 90 tick 無輸入也不死亡，涵蓋 Boss、投射物與機關危險。地形不變時共用獨立地形快照，實體及巢狀 packed array 則複製隔離。恢復後只清除失敗的未來分支，保留更早的安全歷史。

倒流使用時間戳插值平滑角色、鏡頭與 Boss 位置，開頭短暫停留，中段加速，末段減速並停在精確安全狀態；畫面插值不修改存檔快照。倒流時間不受遊戲倍速影響。回復鏡頭同步前後位置，避免恢復操作時多跳一格。

單元驗證：334 項測試、25191 次檢查通過，涵蓋插值不污染歷史、精確落點、保留舊歷史與回復後存活。場景與實錄結果見 `build/recordings/world1/rewind-polish-tests.log` 及 `record-rewind-polished.log`。

## 影片

- `build/recordings/world1/world1-levels-01-10.mp4`：第 1～10 關，1280×720、60 FPS、原遊戲音效、每關章節。
- `build/recordings/world1/death-rewind-polished.mp4`：最新平滑安全倒流示範；舊版本與中間錄影已清理。
- `results_1-5.json`、`results_6-7.json`、`results_8-8.json`、`results_9-9.json`、`results_10-10.json`：真實 GameScreen 錄影過程的過關結果。

通關採自動輸入回放，在原本 GameScreen 中執行原物理與勝負判定；使用 shipped designer 關卡，未修改地圖、傳送角色或強制通關。1～9 關錄於倒流修改前，第 10 關錄於修改後，通關影片中均無死亡。完整 MP4 解碼檢查無錯誤。

## 重現

在專案根目錄使用 PowerShell：

```powershell
& ./godot/tools/test.ps1
& ./godot/tools/godot.ps1 --headless -s res://tools/capture/record_world1.gd ++ --sandbox --prepare
& ./godot/tools/godot.ps1 --resolution 1280x720 --fixed-fps 60 --write-movie build/recordings/world1/all.avi -s res://tools/capture/record_world1.gd ++ --sandbox --first=1 --last=10
& ./godot/tools/godot.ps1 --resolution 1280x720 --fixed-fps 60 --write-movie build/recordings/world1/death-rewind.avi -s res://tools/capture/record_rewind.gd ++ --sandbox --first=9 --last=9
```

錄影程式使用獨立 sandbox 存檔；請勿與會清空同一 sandbox 的 smoke test 同時執行。錄影工具結束時仍有 7 個 ObjectDB 引用未釋放的警告，不影響錄影結果；遊戲執行期間無 script error。

專案清理後保留最終 MP4、封面、輸入路線及通關結果，移除 AVI 原始輸出、分段影片及臨時 FFmpeg 安裝。需要重新轉檔時請使用本機 FFmpeg；上面的 Godot 指令可重新錄製 AVI。
