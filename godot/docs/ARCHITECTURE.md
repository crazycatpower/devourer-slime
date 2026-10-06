# Godot 架構

`App` 管理選單、遊戲與編輯器的切換，子畫面透過訊號提出操作。

## 模擬

`GameSim` 以每秒 60 ticks 更新純資料狀態；`PlayerSystem`、`BossSystem`、碰撞與飛行方塊系統處理行為。核心不依賴節點或 autoload，方便無頭測試。遊戲速度與子彈時間由 `GameScreen` 控制每幀推進的 tick 數，繪製使用前後位置內插。

首領類型由 `BossState.Kind` 定義，`LevelLibrary` 將內部 slot 對應首領種類。展示世界順序由 `WorldCatalog` 管理。鋼鐵追逐戰的勝利條件為抵達終點，其餘四場各有独立行為。

## 繪製與音效

`WorldView` 組合各個 `WorldLayer`。圖層讀取模擬狀態，使用 `Painter`、`TilePainter` 與現有素材繪製；呈現用效果不修改玩法亂數。

`ToneSynth`、`SfxLibrary` 與 `MusicSequencer` 合成音效並排程背景音樂。

## 資料

關卡為 JSON 字串陣列：`@` 鋼鐵、`#` 泥土、`*` 彈力、`X` 玻璃、`O` 虛空、`~ > v <` 尖刺、`$` 終點、`P` 起點、`.` 空氣。方塊 ID 與內部 slot ID 不重新編號，以維持存檔相容。

`LevelRepository` 管理自訂關卡，`Settings` 與 `Progress` 管理設定和通關進度。關卡不含顯示名稱或教學說明。

## 驗證與開發

執行 `tools/test.ps1`：載入腳本與場景、跑 Godot 單元測試及實際輸入路線，再以沙盒進行遊戲流程冒煙測試。`tools/capture` 用於畫面檢查。

變數、參數及回傳值須標註型別；採 Tab 縮排與一檔一類別。玩法常數集中管理，訊號向上、呼叫向下。新增方塊須同步更新 `Tile`、`LevelCodec`、`TilePainter` 與編輯器筆刷；新增首領須連接模擬、關卡對應與繪製。
