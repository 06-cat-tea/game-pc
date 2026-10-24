# 晨星镇与六页界面升级

## 维护位置

`godot/data/town-design.json` 是晨星镇表现布局的运行数据；`tools/design-starlit-town.cjs` 是其制作源，维护 11 座建筑的占地、入口、NPC、任务物件、道路与装饰。修改布局后运行制作工具，先通过连通与占地检查再查看实机。

内容加载完成后应用城镇几何覆盖，保留原有建筑、任务和剧情 ID。原文 JSON 与剧情基准没有重写。其他五地、室内及其地图资源保留。

## 场景与界面

建筑、装饰、地表、阴影、人物分层显示；人物位于屋顶或树冠后方时淡化遮挡物。入口、寻路、地图标记使用实际运行坐标。镇外延伸草地覆盖边缘镜头；原出生点 `(30,27)` 保持可通行。

旧档坐标仍可通行时保持原值；落在新建筑内时使用附近安全点，并同步会话坐标，之后正常保存。存档格式、个人成长、任务记录和战斗规则保持兼容。

六页 UI 使用实时中文控件和游戏数据。角色／任务页使用星空深色主题，背包／地图使用米白主题；统一胶囊按钮、金色焦点、方形物品格和圆形队伍头像。六地总览可以选择地区、打开当地地图和按现有规则旅行。地图页保留内室视图、定位、缩放与拖动。

探索 HUD 由 `ExplorationHUD` 独立维护，按已确认的示意图对齐：宋体文字、实心功能图标、金色菱形任务标记、分行显示的角色名与等级、独立 HP／MP 条、键帽提示及 F 行动胶囊。小地图使用实际地图的柔化采样，保留稀疏功能地标与任务标记，不混入动物和采集点圆点。`tools/create-hud-reference-assets.cjs` 维护可缩放图标；宋体及许可来源位于 `godot/assets/fonts/NotoSerifSC-SOURCE.txt`。

`tests/hud_reference_review.gd` 额外生成 1672×941 同尺寸对照截图、720p、1080p、4K 及四人队伍截图，检查文字行框、键帽文字包含关系和图标加载，结果在 `artifacts/godot/hud-reference-review/`。

## 制作与验收

从 desktop 目录执行：

```powershell
node tools/design-starlit-town.cjs
node tools/package-starlit-art.cjs
node tools/godot.cjs test
node tools/verify-godot-content.cjs
node tools/godot.cjs run --resolution 960x540 --script res://tests/starlit_review.gd
node tools/godot.cjs build
node tools/verify-starlit-delivery.cjs
node tools/godot.cjs build-web
node tools/verify-godot-web.cjs --browser=chrome
```

`starlit_review.gd` 在独立 SubViewport 中以 720p、1080p、原生 4K 渲染六页，另检查七人角色栏、空背包、所有互动点的寻路与旧档安全落点。截图和报告在 `artifacts/godot/starlit-review/`；Windows 无开发依赖的运行验收在 `starlit-delivery/`。该脚本仅重新烘焙已变更的晨星镇地图。制作后应先完成截图／地图烘焙，再导出双端。

原稿、示意图和提示词保存在 `art-source/`；运行时不依赖制作目录。发行包排除测试与作者工程，本轮不自动部署。
