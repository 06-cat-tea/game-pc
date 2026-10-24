# 加载画面与提示

网页首次下载、原生启动与游戏内场景切换，共用 `godot/data/loading.json` 的10张插画和30条提示。六类提示各5条，分别覆盖键鼠操作、探索任务、角色队伍、战斗、休整补给与存档。提示内容按现有规则整理，无剧情剧透。

- 每8秒轮换插画，下一张准备好后再用0.6秒淡入切换；每6秒轮换提示，不连续重复。
- 游戏内优先显示目的地或活动对应插画；目的地标题不会随背景轮换而改变。若连续进入相同目的地，首图也会变化。
- 资源加载完成即进入游戏，不为轮播等待。减少动效模式固定背景、取消过渡，保留文字提示切换。加载失败时停止轮播，继续提供错误、返回或重试。
- 原生进度条只展示资源读取的实际进度；未知进度与构建阶段使用不定进度。网页进度仍来自引擎真实下载字节。

## 制作和发布

原生使用既有1920×1080插画。`tools/build-loading-web.cjs` 在Web导出后，把同一批图片生成1600×900、单张不超过300KiB的独立WebP，并把共享提示配置嵌入网页。首次下载前即可显示画面；运行时只准备当前图与下一张，不同时下载全部图片。预览图、网页脚本和目录信息均随本站部署，不使用外部API或CDN，不读写玩家存档。

本地安装工程开发依赖后执行 `node tools/godot.cjs build-web`；GitHub Actions在导出前安装锁定版本的制作/浏览器工具。PR运行原生回归、Web导出、完整浏览器验收和加载页专项；合并main后使用现有Pages流程发布。

## 验证

- `node tools/godot.cjs test`：加载目的地、两层图像切换、提示轮换、减少动效、错误停止、缺图回退、快速完成与进度隔离。
- `node tools/godot.cjs run --script res://tests/loading_carousel_review.gd`：720p、1080p、4K原生实机图和错误状态，产物在 `artifacts/godot/loading-carousel-review`。
- `node tools/verify-loading-web.cjs`：延迟真实游戏包请求，检查实际网页下载页的画面与Tips轮播、三种分辨率、缺图、减少动效、下载失败重试及完成后停止计时。截图在 `artifacts/godot/loading-web-review`。
- `node tools/verify-godot-web.cjs --browser chrome`：完整游戏、存档、训练与战斗、王城昼夜等回归。
