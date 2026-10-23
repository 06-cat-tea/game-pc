# Godot 原生电脑版整理

本次范围仅为 `desktop`，手机版未修改。维护入口为 `godot/project.godot`，剧情与数值唯一来源为 `godot/data/*.json`。

## 实现

- 同页更新由 `refresh_menu()` 与 `UIReconciler` 更新现有节点；背景、立绘、按钮焦点和滚动位置保留。导航入口与同页更新分开，常规点击不再播放整页透明度动画。
- 屏幕八方向输入通过场景投影逆变换计算，室内外均等速，Shift 为 1.8 倍。实际位移决定朝向，停止保留朝向；点击寻路共用位移、终点钳制及分步碰撞滑动。
- 七人各三种全身表情，运行图 768×1152 透明 WebP、头像 256×256；八方向每向一张站立加四张行走，均为 384×384，脚底对齐。
- 对话使用固定上身取景，角色与战斗展示全身。深入话题严肃、赠礼正向反馈微笑；缺图按常态、职业素材回退。

## 原稿与制作

内置 imagegen 生成，七人保留原有人物、服装与道具设定；艾拉使用白金祭司服、灰发与星形法杖。表情以同一人物常态稿编辑。

- 原稿、逐图提示词及参考路径：`art-source/characters/<id>/fullbody-v2/`。
- 参考存档：各角色 `web-reference/`，含移除前的立绘与设计原稿。提示词中的旧运行路径为制作时来源，现可在此存档找到。
- 正向动作原稿及四组斜向原帧：`art-source/characters/hero/movement-v2/`。
- 重打包：`pnpm godot:characters`；透明边缘、尺寸和脚底检查：`node tools/native-verify-characters.cjs`；总览：`pnpm godot:review`。

## 清理与恢复

删除前已备份：`artifacts/backups/before-godot-only-20261016.zip`，并保留上版 Windows 包。角色原稿、资源来源和许可迁入制作目录。

清理依据覆盖原生脚本、场景、JSON、动态目录、表情回退、八向帧和导出规则；清单记录每个删除目标、字节数及原因。网页入口、浏览器实现、Live2D 运行依赖、迁移工具、旧构建和隔离测试副本均退出电脑版。Godot 引擎、导出模板及必要制作工具继续保留。

详细结果：`artifacts/godot/native-cleanup-result.json`。当前编辑器使用的 `.godot` 缓存保留。

## 验证与交付

Windows 包位于 `artifacts/godot/windows/`，双击 `灰烬边境.exe`，同目录保留 `灰烬边境.pck` 与许可文件。新版为 479.9 MB（整个文件夹，十进制），运行无需编辑器、Node 或联网。

2026-10-16 完成以下验收：

| 项目 | 结果与证据 |
| --- | --- |
| 完整原生回归 | 3,763 项通过，含旧 v1 存档加载、剧情、战斗、轮盘、八向实际输入、等速/奔跑、寻路非网格终点、碰撞滑动、停止朝向及缺图回退；`native-acceptance.json` |
| 原生内容基准 | 9,251 项通过；66 人物、64 场景、204 话题、242 调查物件、15 篇世界观，9,157 条文本记录未变；`content-parity.json` |
| 点击连续性 | 30 次选择、90 帧检查通过，覆盖分类、物品、七名角色、技能、地图、对话回复、战斗技能与目标；背景节点持续可见；`upgrade-review/click-continuity.json` |
| 人物素材 | 21 全身图、7 头像、40 动作帧尺寸与透明通道检查通过；动作脚底在统一的 365 像素位置；`native-character-acceptance.json` |
| 四种窗口比例 | 1920×1080、1280×720、960×540、2560×1080，标题、角色、对话、战斗、轮盘、背包、技能和地图通过；另核对七人角色页，共 38 张布局截图；`native-upgrade-visuals.json`、`native-character-layouts.json`、`native-menu-layouts.json` |
| 独立工程 | 复制 `godot/` 后重新导入、3,763 项回归通过；只保留 Windows System32 PATH，使用 Godot 和 PowerShell 构建并启动；`standalone-build.json`、`standalone-acceptance.json` |
| 独立发行包 | 在含中文及空格目录下启动，19 个图形场景和无界面烟雾检查通过，无开发插件、测试和制作原稿；`windows-acceptance.json` |
| Windows 品牌 | EXE 六尺寸图标与 ICO 原稿逐像素资源匹配，中文产品名/文件说明、窗口/任务栏图标通过；`brand-acceptance.json`、`windows-brand-acceptance.json` |
| 资源审计 | 451 个有效运行文件，无缺失引用、无未引用运行素材；逐文件 SHA-256 见 `native-resource-audit.json` |

机器可读报告均在 `artifacts/godot/`。立绘、表情和八向动作总览在 `upgrade-review/`，90 帧点击证据同目录保存。EXE/PCK 及许可文件的 SHA-256 和交付汇总见 `native-delivery.json`。

闪烁原因已在变更前源码中确认：`UIkit.enter()` 在每次刷新时把整页透明度设为 0，并重新播放 0.2 秒入场动画；同时菜单与战斗选中重建节点。本版移除该透明度重置，同页保留现有节点，对话回复更新内容与表情。截图覆盖范围内未发现整页闪白。

初次删除清单共 1,143 项，移除约 12.54 GB，包含 61 个退役运行素材及其导入记录。完成验收后另清除约 1.59 GB 的新建隔离副本和旧截图。整个电脑版目录从约 17.86 GB 降至 5.43 GB，净减少约 12.43 GB；统计包含 `.git`、一次源代码备份、上版发行包、当前发行包、引擎/模板、当前编辑器缓存及最新证据。目录大小会随编辑器缓存变化。

保留 `.godot` 缓存是因为当前编辑器仍在使用该目录。上版包和变更前 ZIP 位于交付目录外的 `artifacts/backups/`。独立工程和发行包验收的临时目录在检查成功后已删除；报告保留当时路径以说明测试环境。

Windows 图标及产品属性接入遵循 [Godot 官方 Windows 导出配置](https://docs.godotengine.org/en/stable/classes/class_editorexportplatformwindows.html)。视觉验收环境为 NVIDIA RTX 3050 Ti，OpenGL Compatibility；结论限于上述场景、交互及分辨率覆盖。

存档目录、格式和兼容迁移规则保持不变。验收使用隔离的 APPDATA，避免修改玩家存档。
