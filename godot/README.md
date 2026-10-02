# 史萊姆方塊吞噬者（Godot 版）

吞下方塊、吐出方塊、靠反作用力和彈力方塊闖過五個世界。這是網頁版（本資料庫根目錄的 `src/`）的 Godot 4 移植版：保留原本的遊戲設計與手感數值，修掉網頁版的缺陷，並以分層、可測試的架構重寫。

- 引擎：Godot 4.7（標準版，GDScript，Compatibility 渲染器）
- 版本：0.2.0
- 網頁版缺陷與處置：[docs/WEB_VERSION_DEFECTS.md](docs/WEB_VERSION_DEFECTS.md)
- 架構與規範：[docs/ARCHITECTURE.md](docs/ARCHITECTURE.md)

## 開啟與執行

用 Godot 編輯器匯入 `godot/project.godot`，按 F5 執行。或者用附帶的腳本（它會自己找到 winget 安裝的 Godot；也可以用環境變數 `GODOT` 指定執行檔）：

```powershell
godot\tools\godot.ps1 -e      # 開啟編輯器
godot\tools\godot.ps1         # 直接執行遊戲
```

## 操作

| 動作 | 預設按鍵 |
| --- | --- |
| 左右移動 | A / D |
| 跳躍 | W（放開得早會跳得矮） |
| 吞噬 | 滑鼠左鍵（對準方塊按住） |
| 吐出 | 滑鼠右鍵（按住進入子彈時間並顯示彈道，放開發射） |
| 重來 | R |
| 暫停 / 設定 | Esc |
| 全螢幕 | F11 或 Alt+Enter |

Esc 與 F11 以外的按鍵都能在設定裡重新綁定。方塊被吞吐一次會磨損一階，第三次吞下就會被消化掉。

子彈時間有額度：一格能量可用 3 秒，放開吐出鍵後約 4 秒回滿，史萊姆頭上的小條顯示剩餘量。用完後彈道線仍會顯示，只是時間恢復正常。在空中朝旁邊吐方塊，後座力會把史萊姆推開約三格。

關卡編輯器：左鍵繪製、右鍵擦除、中鍵拖曳或 W A S D 移動視角、Ctrl+Z 復原、Ctrl+Y 重做、Ctrl+S 儲存。

## 專案結構

```
godot/
├─ project.godot
├─ data/levels/official_levels.json   內建關卡（由工具從網頁版原始碼產生，不可手改）
├─ assets/fonts/                      Noto Sans TC（SIL OFL 授權，見 OFL.txt）
├─ src/
│  ├─ core/        純邏輯，不依賴任何節點
│  │  ├─ level/    關卡格子、文字格式編解碼、驗證、內建關卡庫
│  │  └─ sim/      決定性模擬：玩家、碰撞、方塊子彈、四個首領、落石
│  ├─ services/    存檔路徑、自訂關卡存檔庫
│  ├─ autoload/    Settings、LevelStore、Progress、AudioDirector
│  ├─ input/       可重新綁定的動作
│  ├─ audio/       離線合成器、音效配方、背景音樂音序器
│  ├─ render/      世界繪製：WorldView 與各圖層
│  ├─ game/        遊戲畫面（主迴圈、輸入、覆蓋層）
│  ├─ editor/      關卡編輯器（文件模型與畫面）
│  ├─ ui/          主選單、設定、共用元件、主題
│  └─ app/         根場景與畫面切換
├─ tests/
│  ├─ unit/        單元測試
│  ├─ parity/      與網頁版引擎逐 tick 對照的黃金測試與參考軌跡
│  └─ smoke/       端到端冒煙測試
├─ tools/          測試、截圖、主題產生、關卡匯出、參考軌跡產生
└─ docs/
```

## 測試

```powershell
godot\tools\test.ps1          # 全部：編譯檢查 + 單元與對照測試 + 冒煙測試
godot\tools\test.ps1 unit     # 只跑路徑含 "unit" 的測試
godot\tools\test.ps1 -Smoke   # 只跑冒煙測試
```

- **編譯檢查**：載入每一個腳本與場景。專案把未標型別、不安全的存取、遮蔽變數等警告一律設為錯誤。
- **單元測試**：方塊分類、關卡編解碼與驗證、存檔庫、按鍵綁定、編輯器文件模型、合成器、子彈時間額度、視窗大小與全螢幕快捷鍵，以及每一項缺陷修正的回歸測試。
- **對照測試**：把網頁版引擎實際在 Node.js 裡跑起來，錄下 42 段遊玩的輸入與每一個 tick 的狀態；Godot 版重播同樣的輸入，逐 tick 比對位置、速度、首領狀態、關卡內容、粒子與音效（共約 283 萬項檢查）。細節見架構文件。
- **冒煙測試**：無頭啟動整個遊戲，用模擬按鍵走過選單、過關、暫停、死亡、首領戰、編輯器、測試遊玩、設定與全螢幕切換。

冒煙測試與截圖工具都以 `--sandbox` 執行，存檔會寫到 `user://sandbox/`，不會碰到真正的存檔。

## 工具

| 指令 | 用途 |
| --- | --- |
| `tools\test.ps1` | 執行自動化檢查 |
| `tools\capture.ps1` | 開視窗把每個畫面截圖到 `tests\output\`，不用實際玩就能檢查外觀 |
| `godot --headless -s res://tools/build_theme.gd` | 由程式碼重新產生 UI 主題 `src/ui/theme/game_theme.tres` |
| `node godot/tools/export_levels.mjs` | 從網頁版的 `constants.ts`、`default_levels.ts` 重新產生內建關卡資料 |
| `node godot/tools/parity/make_reference.mjs` | 重新產生對照測試的參考軌跡 |

後兩個需要 Node.js 22 以上。關卡匯出只有在網頁版原始碼變動時才要重跑；參考軌跡則是每次改動模擬行為（並在產生器裡加上對應補丁）之後都要重新產生。

## 關卡資料

關卡由遊戲設計者親自設計。這個專案**不設計、不修改、不補齊**任何關卡配置：內建關卡是用 `export_levels.mjs` 從網頁版的常數逐字轉出的，沒有專屬配置的格子一律使用既有的 `DEFAULT_LEVEL_DATA`、首領格使用 `BOSS_LEVEL_DATA`（同根目錄 `AGENTS.md` 的規定）。

要新增或修改官方關卡：在遊戲內的編輯器設計並存檔，用「複製全部存檔」取得 JSON，貼進網頁版的 `default_levels.ts`，再重跑 `export_levels.mjs`。

## 存檔位置

`user://` 在 Windows 上是 `%APPDATA%\Godot\app_userdata\Devourer Slime\`。

| 檔案 | 內容 |
| --- | --- |
| `settings.cfg` | 音量、遊戲速度、子彈時間、全螢幕、按鍵綁定 |
| `progress.cfg` | 已通關的格子 |
| `levels/slot_NN.json` | 自訂關卡（與網頁版相同的字串陣列格式，可互相匯入匯出） |

## 授權

字型 Noto Sans TC 依 SIL Open Font License 1.1 授權，授權全文在 `assets/fonts/OFL.txt`。
