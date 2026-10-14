# 第二世界十關通關錄影（2026-10-13）

成品：`build/recordings/world2/world2-levels-01-10.mp4`。

- 第 1～10 關（正式 slot 11～20），包含泥土 Boss。
- 1280×720、60 FPS、4 分 31.733 秒（16,304 幀）。
- H.264 / AAC，保留原遊戲音效與正常遊戲速度，內含十個關卡章節。
- 約 52.2 MB；完整影片解碼檢查通過，沒有損壞幀，音訊非靜音。

通關路線以正常移動、跳躍、吞食與吐出輸入搜尋，再從各關起點獨立驗證，最後透過原本的 GameScreen 逐關實錄。十關全部 `won=true`、`dead=false`。沒有改動關卡配置、物理規則、角色位置或勝負判定，也没有剪掉錄製途中失敗的片段；錄製的是已驗證成功的完整路線。使用者提供了搭路、回收泥土、縮小缺口、斜向鋪路及從中間攀升等提示。

## 保留的重現與驗證資料

- `inputs.json`：十關完整逐幀輸入；`direct_11.json`～`direct_20.json` 為各關原始輸入。
- `prepare-all.log`：全部十關從起點重新驗證的結果。
- `results.json`、`results_N-N.json`：GameScreen 實際錄影的過關結果及影格範圍。
- `verification.json`、`decode-check.log`：影片規格、16,304 幀完整解碼、音訊及章節檢查。
- `contact-sheet.jpg`：十關影片畫面抽樣。
- `package_video.py`、`verify_video.py`：打包與影片檢查工具。

## 重新錄製

在專案根目錄執行，使用獨立 sandbox 存檔：

```powershell
& ./godot/tools/godot.ps1 --headless -s res://tools/capture/record_world1.gd ++ --sandbox --world2 --prepare
foreach ($stage in 11..20) {
    & ./godot/tools/godot.ps1 --resolution 1280x720 --fixed-fps 60 --write-movie "build/recordings/world2/level-$stage.avi" -s res://tools/capture/record_world1.gd ++ --sandbox --world2 "--first=$stage" "--last=$stage"
}
```

`tools/capture/world2_routes.gd` 可重現一般關卡的操作規劃，`solve_mud.gd` 處理 Boss。搜尋候選在第一次死亡時即停止，不跨過死亡重開繼續搜尋。

錄影結束時仍有既有的 7 個 ObjectDB 引用未釋放警告；錄影期間沒有腳本錯誤，十關實錄與成品解碼均通過。最終驗證後清理 AVI 中間檔及暫存 FFmpeg 安裝；重新轉檔時可將 `imageio-ffmpeg` 安裝到 `build/video-tools`，再執行保留的打包工具。
