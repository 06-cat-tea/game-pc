# 王城布局与昼夜光照

## 制作与数据

`node tools/design-royal-city.cjs` 是王城布局的制作入口，写入 `world-regions.json` 中的 city、地形遮罩，以及 `art-source/royal-city/v2/layout.json` 和 `layout.svg`。其余地区数据不变。制作工具校验建筑不重叠、道路净宽、入口与 NPC 可达性；主街6格、街区道路4格、支巷和滨水道路2格。保留九区、52个建筑ID、原有内室及服务。

新版使用工程内已有的王城建筑、植物、旗帜、庭墙、长椅和喷泉素材，补入晨星镇摊位与既有货桶；不引入外部服务。场景中有168处独立装饰，其中9处摊位、14组货桶、9张长椅和3处喷泉/雕像。大型物件的实体基底在 RegionCatalog 中参与碰撞，树冠仍可淡化。NPC位置来自王城数据中的 npcPositions，仅覆盖运行时坐标，不改叙事原文。旧档合法坐标原样保留；被新建筑占用的王城坐标优先回落到附近安全道路。

`node tools/bake-godot-regions.cjs` 先重建王城，再导入并从实际场景烘焙地区地图。已移除对此前不存在的 import-godot-regions.cjs 的依赖。地图冻结为中性日光，不烘入动态灯火或当前玩家时段。

## 昼夜与轮盘

`godot/data/daylight.json` 配置四时段色调、六地色彩倾向和各建筑的窗户/火源UV区域。WorldLighting 独立管理场景 CanvasModulate，HUD 保持独立 CanvasLayer；晨星镇地表已移除 unshaded，使地表真正参与昼夜光照。室内保持暖色和较高亮度。

黄昏与深夜开启暖色灯池、灯芯光晕、窗户和炉火自发光；王城运河等水面在附近灯源处增加条纹反光。灯光按相机距离裁剪，最多7个环境PointLight2D加1个人物补光。正常模式平滑过渡，减少动效时立即切换；保持原有休息/事件推进时段的规则及存档格式。

Tab轮盘沿用八项功能、原有方向顺序和85像素中心取消区。新版采用实心米白图标、半透明深蓝灰扇区、金色选中扇区与指示菱形、统一衬线中文。松开执行、中心取消、Esc/失焦取消和防重复结算逻辑不变。

## 验证与交付

- `node tools/godot.cjs test`：含 royal_daylight_acceptance.gd，验证全部王城目标可达、F精确命中、全部道路净宽、合法/占用旧档恢复、原有内室进出及新入口返回、六地四时段与灯光数量上限。
- `node tools/godot.cjs run --script res://tests/royal_daylight_review.gd`：真实渲染720p、1080p、3840×2160画面，输出四时段、九街区、轮盘与4096×2385全景；烘焙实际王城地图。输出在 artifacts/godot/royal-daylight-review。
- `node tools/godot.cjs run --script res://tests/regions_performance.gd -- --night`：六地深夜性能抽查；默认命令保留日间五地区基准。
- Windows 和 Web 使用同一工程导出；图像预览与测试产物位于 artifacts，不包含于发行源码资源中。本轮不发布。
