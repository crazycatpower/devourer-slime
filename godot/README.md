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

玻璃世界 Boss（slot 40）的地下填充區在進場及重試時重新抽取泥土位置。每列以約 3% 的比例取整、至少一塊泥土，表層至少兩塊；其餘為玻璃。固定模擬種子可重現場地，向下延伸使用獨立亂數串流，不影響 Boss 攻擊抽樣。

玻璃 Boss 飛行高度為玩家上方 310 世界單位，俯衝最低點深入玩家腳下 80 單位。下砸及俯衝撞泥土時扣一點泥土耐久並暈眩；護盾依血量為 4／8／12。炸彈投擲有水平 ±140、垂直 ±40 單位的瞄準偏差，碰撞即爆。本體接觸只做固體碰撞與位置分離，不會彈跳或反彈，只有炸彈爆炸及被本體擠向地形才會致死。

招式意圖隨機抽選：下砸、俯衝、炸彈各佔 30%，護盾修復佔 10%；護盾已滿時不抽修復、沒有可投擲護盾時不抽炸彈，其餘招式按原權重抽選。修復蓄力 1.5 秒，依血量階段補回 2／3／4 面護盾，上限仍為 4／8／12 面。蓄力時顯示修復意圖及可補回數量，命中核心會中斷修復；不修復地形或核心血量。

存檔位置為 `%APPDATA%/Godot/app_userdata/Devourer Slime/`：`settings.cfg` 儲存設定、`progress.cfg` 儲存通關紀錄、`levels/slot_NN.json` 儲存自訂關卡。

在遊戲內編輯器儲存的關卡就是官方關卡：`tools/build.ps1` 匯出前會執行 `tools/bake_levels.gd`，把存檔資料夾裡的關卡寫進 `data/levels/designer_levels.json`，該檔案的關卡會取代同一格的內建版面並隨遊戲發佈。

字型依 [SIL OFL](assets/fonts/OFL.txt) 授權。
