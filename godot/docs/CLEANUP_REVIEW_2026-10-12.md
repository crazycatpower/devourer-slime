# 專案清理紀錄

狀態：使用者明確確認後，已依清單刪除 1,628 個檔案，約 977 MB。測試會重新產生必要快取及輸出，因此最終淨減少量略低。

完整檔案清單：`../build/cleanup-20261012.csv`，共 1,628 個檔案，約 977 MB。

## 已刪除

- Godot 可重建快取 `godot/.godot`。
- 可重跑產生的測試截圖與輸出 `godot/tests/output`。
- 暫時安裝的 FFmpeg 套件 `godot/build/video-tools`，之後錄影轉檔需重新安裝或使用系統 FFmpeg。
- 未被 src、tools、tests 程式引用的舊 art PNG、import 設定與 biofactory-v1 生圖展示／圖集；目前美術由 render 程式繪製。
- 已合成為完整影片的 AVI 原檔、分段 MP4、第 1～9 關部分合輯、舊倒流版本、接觸表、搜尋中間結果與過時日誌。刪除 AVI 後無法直接重新剪輯原始品質影片，但保留正式 MP4 及重錄輸入資料。
- 舊 Windows ZIP（保留目前 EXE 與 PCK），已不用的 diagnose_chase 與 solve_fine 草稿。

## 保留

- 所有遊戲原始碼、關卡資料、正式測試、開發與匯出工具、字型及授權、Git 歷史和現有修改。
- Windows EXE／PCK 及匯出依賴的 debug／release templates。
- 第 1～10 關完整通關 MP4、最新 death-rewind-polished MP4、封面 PNG 與提示詞。
- inputs.json、route_1～10.json、正式錄影 results、章節資料及最新版倒流測試／錄影證據。
- source-before.zip 原始碼備份，其內容不能判定為多餘。

產出資料夾已加入 .gdignore，避免錄影、封面與測試截圖被當成遊戲素材匯入。清理後驗證記錄位於 `build/cleanup-validation.log`，匯出記錄位於 `build/cleanup-export.log`。

## 清理後驗證

- 162 個腳本／場景編譯檢查通過。
- 334 項單元測試、25,191 次檢查通過。
- 125 次場景 smoke 檢查通過。
- Windows 匯出成功，匯出日誌無 ERROR／SCRIPT ERROR；PCK 約 10.2 MB。
- 重建必要快取後，godot 目錄約 378.9 MB。

首次清空快取後，匯入初期曾提示找不到字型快取；匯入已重建該字型，後续編譯、場景測試與匯出均成功。
