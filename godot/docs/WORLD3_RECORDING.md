# 第三世界通關錄影（2026-10-14）

成品位置：`build/recordings/world3/world3-levels-01-10.mp4`。

原遊戲鏡頭、1280×720、60 FPS、4 分 12.367 秒（15,142 幀）、AAC 48 kHz 立體聲、10 個關卡章節，約 122.5 MB。全部十關實錄過關，完整解碼無錯誤。依使用者要求保留原鏡頭成品，取消全場鏡頭試錄；被試錄覆蓋的 Boss AVI 已移除，需要重打包時請先重新錄製第 30 格。

以移動、跳躍、吞食與吐出的正常輸入規劃路線，從開局獨立重播，再透過原本 GameScreen 錄製。沒有為了過關更改地圖、物理、角色位置或勝負狀態。影片呈現已驗證成功的完整路線；探索過程與失敗候選未收錄。

## 地圖版本

先快照使用者目前的 `user://levels/slot_21.json`～`slot_30.json`，搜尋及錄影均載入同一份快照。第 27 格沒有自訂存檔，使用現有出廠關卡。其餘九份快照與目前真實存檔的原始位元組相同；SHA-256 與來源見 `map-manifest.json`。獨立 sandbox 載入快照，沒有改寫真實關卡存檔。錄影開始時會核對 GameScreen 載入的關卡與快照一致。

## 路線重點

1. 利用連續彈跳越過尖刺。
2. 吞彈力方塊後配合吐出反作用力升高。
3. 跨島拿彈力，再回到左側上升。
4. 先帶彈力升高，再吐出越過中央尖刺。
5. 吞右側彈力牆並靠吐出攀升。
6. 挖側牆，從外側一路下降，再挖回底部終點。
7. 丟掉彈力，以泥土從中間斜搭上去；回收後方泥土鋪路，最後斜吐飛越。
8. 開局挖牆，走屋頂，從右側挖回終點。
9. 將彈力方塊射向右上玻璃，逐格打通；利用反彈與空中回收，再吐出補反作用力。完全不使用泥土。
10. 先挖掉左側連續五格地板，再到屋頂的洞口上方引誘 Boss；擊敗後回場內取終點。

第 2、4、6、7、8、9、10 關採用了使用者提供的提示。彈力方塊會彈走，沒有把它當成普通泥土橋使用；第 9 關向上射出的方塊穿過已打通的通道，反彈一次後落成彈力落腳點。

## 重現與驗證資料

`build/recordings/world3` 保留以下內容：

- `maps/`、`map-manifest.json`：當次使用的關卡與來源雜湊。
- `direct_21.json`～`direct_30.json`、`inputs.json`：逐幀輸入。
- `prepare-all.log`：十關重新從開局驗證的結果。
- `results_N-N.json`、`results.json`：實際 GameScreen 過關結果與錄影幀範圍。
- `verification.json`、`decode-check.log`、`verified-chapters.ffmeta`：成品完整解碼、音訊及章節檢查。
- `contact-sheet.jpg`：十關畫面抽樣。
- `package_video.py`、`verify_video.py`：打包及驗證工具。

在專案根目錄重新錄製：

```powershell
& ./godot/tools/godot.ps1 --headless -s res://tools/capture/record_world1.gd ++ --sandbox --world3 --prepare
foreach ($stage in 21..30) {
    & ./godot/tools/godot.ps1 --resolution 1280x720 --fixed-fps 60 --write-movie "res://build/recordings/world3/level_$stage.avi" -s res://tools/capture/record_world1.gd ++ --sandbox --world3 "--first=$stage" "--last=$stage"
}
```

打包工具使用 `build/video-tools/imageio_ffmpeg/binaries/ffmpeg-win-x86_64-v7.1.exe`。錄影結束時有 ObjectDB 引用未釋放警告，與影片解碼檢查分別記錄。


## 完整剪輯版

成品為 `build/recordings/world3/world3-edited-full.mp4`，保留原版 MP4。長度 4 分 48.783 秒，17,327 幀，1280×720／60 FPS，AAC 48 kHz 立體聲，12 章節。完整解碼驗證無錯誤。

- 三段真實畫面的開場預告、主題片頭、十關章節轉場與通關片尾。
- 主線保留原片十關全部影格及正常速度，不移動遊戲鏡頭。
- 三段另加的 0.65 倍速重播有明確字幕，輕微放大 3.5%。
- 畫面上緣的繁體中文字幕解釋捷徑；Boss 說明玩家在畫面上方屋頂。
- 轉場滑入、黑場淡入淡出、原創低音量電子配樂及轉場音效，保留原遊戲音效。
- 十二個影片章節涵蓋片頭、十關與片尾。

剪輯腳本 `build/recordings/world3/edit_video.py`，完整驗證 `verify_edit.py`；素材、逐段輸出、時間軸、原創音軌與驗證報告保存在 `edited/`。配樂與音效由腳本生成，未使用外部歌曲或取樣。
