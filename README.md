# 史萊姆方塊吞噬者（Slime Block Eater）

吞下方塊、吐出方塊，靠反作用力和彈力方塊闖過五個世界的平台解謎遊戲，附關卡編輯器。

這個倉庫有同一款遊戲的兩個版本：

| 位置 | 內容 |
| --- | --- |
| [godot/](godot/) | **Godot 4 版**，目前開發中的版本。說明見 [godot/README.md](godot/README.md)。 |
| [src/](src/) | 原始的網頁版（React + Vite + TypeScript）。Godot 版的關卡資料與對照測試都以它為來源，所以保留在這裡。 |

## Godot 版

用 Godot 4.7 匯入 `godot/project.godot` 後按 F5 執行。操作方式、專案結構、測試與工具都寫在 [godot/README.md](godot/README.md)；架構與規範在 [godot/docs/ARCHITECTURE.md](godot/docs/ARCHITECTURE.md)；網頁版的缺陷與 Godot 版的處置在 [godot/docs/WEB_VERSION_DEFECTS.md](godot/docs/WEB_VERSION_DEFECTS.md)。

## 網頁版

需要 Node.js。

```
npm install
npm run dev
```

網頁版最初由 Google AI Studio 的範本建立：https://ai.studio/apps/46380ccb-7aee-4a30-869d-033da7566c55

## 關卡

關卡由遊戲設計者親自設計。協作規則見 [AGENTS.md](AGENTS.md)：不要自行設計或修改關卡配置。

## 授權

Godot 版隨附的字型 Noto Sans TC 依 SIL Open Font License 1.1 授權（[godot/assets/fonts/OFL.txt](godot/assets/fonts/OFL.txt)）。
