# 史萊姆方塊吞噬者

## 執行

使用 Godot 4.7 匯入 `project.godot`，按 F5。亦可從專案根目錄執行 `godot/tools/godot.ps1`。

## 操作

- A / D：左右移動；W：跳躍。
- 滑鼠左鍵：吞噬；右鍵按住瞄準、放開吐出。
- R：重試；Esc：暫停與設定；F11：全螢幕。
- 編輯器：左鍵繪製、右鍵擦除、中鍵拖曳、Ctrl+Z 復原、Ctrl+Y 重做、Ctrl+S 儲存。

## 目錄

- `src/core`：關卡資料、固定步長物理及首領邏輯。
- `src/render`：方塊、角色、首領及特效繪製。
- `src/ui`、`src/game`、`src/editor`：選單、遊戲及編輯器。
- `data/levels`：Godot 使用的關卡 JSON。
- `tests/unit`、`tests/smoke`：單元、實際輸入路線及遊戲流程測試。
- `tools`：啟動、測試、截圖及關卡資料工具。

## 測試

從專案根目錄執行：

```powershell
godot/tools/test.ps1
godot/tools/test.ps1 unit
godot/tools/test.ps1 -Smoke
```

完整檢查包含腳本與場景編譯、Godot 單元測試與冒煙測試。截圖及冒煙測試使用 `--sandbox` 隔離存檔。

## 關卡與存檔

關卡使用字串陣列 JSON，一個字元代表一格。官方資料位於 `data/levels`；協作規則見根目錄 `AGENTS.md`。

世界展示順序由 `WorldCatalog.ORDER` 決定，內部 slot ID 保持穩定，讓自訂關卡與通關進度持續對應同一關。

存檔位置為 `%APPDATA%/Godot/app_userdata/Devourer Slime/`：`settings.cfg` 儲存設定、`progress.cfg` 儲存通關紀錄、`levels/slot_NN.json` 儲存自訂關卡。

字型依 [SIL OFL](assets/fonts/OFL.txt) 授權。
