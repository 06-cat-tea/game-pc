# 四地区重绘原稿

采用用户确认的四宫格 `approved-reference.png`，使用内置 `image_gen.imagegen` 重绘。`prompts.json` 保留十二张图集的完整提示词；`dock-material-prompt.txt` 对应独立码头木纹。PNG 原稿完整保留，实际尺寸由 `asset-audit.json` 记录。

- 19 处原功能建筑各有独立造型，原建筑 ID、剧情与服务保留。
- 归帆港由原港务所、独立货栈、鱼市、修船棚、两台吊机、三个泊位与三段可步行栈桥组成，附属设施使用独立基底碰撞。
- 四地专用林木、植被、残墙、矿具、海崖岩石和渔具共 16 种；独立船只、八种地表/道路和一张码头木纹。
- `layout-base.json` 是重绘前的几何来源，`layout.json` 是维护后的街路、建筑与港区布局；入口和路径以游戏配置为准。
- `emission-zones.json` 保存新建筑局部暖色像素对应的夜间亮窗/灯具区域。

`node tools/package-regional-art.cjs` 只做透明连通轮廓提取、裁切、补透明边、编码、缩放过滤和资源清单维护，不凭代码补画建筑。`node tools/design-regional-redraw.cjs` 生成地形遮罩与用途化装饰布局，同时检查道路净宽和出生点到各入口的连通性。运行图位于 `godot/assets/regional-redraw/`。

4K 交付图是 Godot 原生渲染截图，原始生成图按实际像素记录。
