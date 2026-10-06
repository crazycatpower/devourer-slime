# 方形美術重設計

使用內建 image_gen 生圖功能。正式資產：`cavern-square-v2.png`、`slime-square-v2.png`。舊版保留供比較，遊戲使用 v2。

## 背景提示詞

Use case: stylized-concept. Production background for a square-block 2D platformer. Wide 16:9 flat side-view pixel art underground cavern. Strict square voxel-inspired shapes, stepped rectangular silhouettes, chunky pixel clusters, crisp hard edges, limited midnight navy, desaturated teal and emerald palette with sparse amber highlights. Layered distant square stone arches, block-shaped crystals and stepped hanging rocks at edges, broad empty DARK central area for gameplay readability. Elegant 32-bit indie game pixel art with atmospheric depth achieved by flat palette layers, not realistic texture. Background scenery only, no playable foreground platforms, no characters, no text, no UI, no watermark. Match a game whose terrain consists of small square orange, pink and steel blocks. Beautiful authored pixel composition, no rounded organic forms, no photographic or painted texture.

## 史萊姆提示詞

Use case: stylized-concept. Asset: single transparent front-facing SQUARE green jelly body sprite for a pixel art platformer. Exactly one flat 2D square, parallel horizontal top and bottom and vertical sides, tiny stepped 2-pixel corners only. Sprite occupies 92 percent of square canvas. Chunky crisp pixel-art clusters, emerald green outline, lime green inner body, jade bottom shading, rectangular pixel highlights at top left, small square speckles. Charming luminous jelly material expressed only through flat stepped color bands. NO eyes, NO mouth, NO face (game draws animated face), NO legs, NO accessories, NO perspective, NO isometric cube, NO background or external shadow. True transparent background. Square silhouette must read clearly at 32x32 pixels. No blur, no realistic rendering, no text.

## 動畫

角色位置沿用物理 tick 插值；身體縮放與傾斜採指數平滑，呼吸及跑動以真實時間驅動。保留視線追蹤、眨眼、吞入方塊與子彈時間量表。背景使用緩慢視差與方形光點，介面保留卡片及視窗的緩動。所有變化只作用於呈現層。


## 對稱方塊與 Q 彈表情更新

方塊使用等距同心方框、四角鏡像紋理，磨損裂紋維持左右平衡。史萊姆與選單吉祥物共用 SlimeMotion 與 SlimeFace；保持長而靠近的大眼睛，不畫嘴巴與腮紅；加入雙眨眼、開心搖晃、好奇張望、打瞌睡與吞吐回彈。起跳、落地、吞吐透過帶阻尼彈簧產生回彈；積分採小步長，避免低幀率下失控。待機動作會在移動或吞吐瞄準時停止。動畫不寫入模擬與碰撞狀態。
## 終點與吞吐效果

終點保留原本的金色方框與亮色方形核心；旋渦光點只在通關吸入動畫時出現。通關後角色在 1.35 秒內沿旋轉路徑被吸入並縮小，最後淡出；正式遊玩自動前往下一關（最後一關返回選單），Enter／跳躍鍵可略過，編輯器測試維持手動返回。重來取消轉場。吞入時完整方塊從原位置移向身體中央，逐漸縮至 20 單位大小，接續體內方塊，不使用吸力光點或原地消失效果。吐出時方塊從體內以半尺寸移出，85 毫秒內恢復完整大小並銜接實際飛行軌跡；發射物理不等待動畫。身體同步蓄力壓縮與彈性回彈，瞄準軌跡每幀讀取游標。保留長而靠近的大眼睛，不繪製嘴巴或腮紅。關卡配置、碰撞與物理常數不變。
## 晶洞與 Boss 方形材質更新

第三世界使用內建 image_gen 新生成的 crystal-cavern-square-v3.png：16:9、正交側視像素晶洞、深海軍藍中心留白、兩側階梯狀青藍方形晶柱、多層暗色矩形拱門。背景僅為裝飾，不包含可遊玩平台或地圖布局。生成提示限制無角色、無介面、無文字、無圓形晶體、無等距透視；已複製到正式 assets/art 目錄。

第二與第四世界沿用原洞窟素材，分別疊上玫紫與深紫環境色。背景邊缘採階梯式暗帶。Boss 本體、護盾、玻璃材質採小切角方形、同心內框與左右對稱高光；所有 Boss 移除嘴巴、保持長形大眼睛。保留終點方框造型、史萊姆追視與貼地動畫。改動僅在呈現層，官方關卡與模擬物理不變。

## 情境反應動畫

撞頭：上升中被天花板、彈力方塊或首領身體擋住即觸發（呈現層由「上升速度突然被截斷」判斷，不寫入模擬）。頭頂貼住天花板壓扁，眼睛擠成 >< ，兩側甩出撞擊線，硬天花板落下碎屑；撞得夠重會頭暈：瞳孔反向繞圈，眼睛半瞇，三顆像素星星在頭上繞行（前大後小），星星在眼睛睜開後才出現。彈力天花板只擠眼回彈，不頭暈。

落下：超過跳躍高度的長距離墜落眼睛睜大、瞳孔縮小；從高處重落地壓成扁片並擠眼。邊緣：站在平台邊、身體中心懸空時朝落差方向搖晃、低頭看下方，另一側冒出描邊冷汗滴；瞄準或吞吐時停止。走路：依實際移動距離每步一次輕微壓扁伸長。

眼睛隨身體變形但只變形一半（反向縮放），重壓扁時 >< 不會被壓成細線。全部只作用於呈現層；截圖用 `capture_screens.gd ++ --sandbox --slime-reactions` 產生 05l–05p。

## 反應音效

撞頭、頭暈、重落地各有一個由呈現層播放的短音效（`SfxLibrary.Cue`，經 `AudioDirector.play_cue`），不經過模擬的 `Sfx.Id`，因此對照測試的音效紀錄不變。撞硬天花板：明亮敲擊加短促空心低音的「咚」；星星出現時：三聲往下飄的高音啁啾；從高處落地：在原本落地聲下疊一層沉重低音。撞彈力天花板沿用模擬原有的彈跳音，不重複播放。
