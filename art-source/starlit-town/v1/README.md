# 晨星镇场景与 UI 原稿

依据已确认的 `../../ui-concepts/genshin-v1/` 六页示意图制作，使用内置 `image_gen.imagegen`。

- `buildings-a/b/c.png`：11 座功能建筑及一座备用民居，统一等距透视、石木结构与蓝／赤瓦屋顶。
- `props.png`：树木、旗帜路灯、花墙、市场摊位；保留真实透明背景。
- `ground.png`：草地、土壤、沙地、石路四种地表。
- `items.png`：三种药剂及旅行补给图标。
- `menu-background.png`、`world-map.png`：不含文字与按钮的界面背景。
- `prompts.json`、`items-prompt.txt`：最终生成提示词；`layout.svg`：根据维护中的建筑坐标生成的布局草排。

运行素材位于 `godot/assets/starlit-town/`。原稿按透明连通区域机械拆分为独立精灵，保持绘画内容，不将邻格碎片带入建筑；未通过的带光晕装饰版本没有投入使用。两张背景原始尺寸为 1672×941，建筑及道具图集为 1254×1254；4K 实机截图由 Godot 原生渲染，不能将原稿称为原生 4K。

制作工具：`node tools/design-starlit-town.cjs` 校验布局并生成道路遮罩；`node tools/package-starlit-art.cjs` 提取素材及维护资源清单。先在 Godot 中导入资源，再运行 `tests/starlit_review.gd` 生成实机截图与晨星镇实际地图。
