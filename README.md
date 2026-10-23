# 灰烬边境：星陨纪事 · Godot 电脑版

这是独立的 Godot 电脑版工程，同一套剧情、规则与素材支持 Windows 和电脑浏览器游玩，手机版保持独立。Windows 包可离线运行；网页版由 Godot 导出，运行时不需要安装 Godot 或 Node.js。

[打开网页版](https://06-cat-tea.github.io/game-pc/) · [查看部署状态](https://github.com/06-cat-tea/game-pc/actions/workflows/godot-web.yml)

## 运行与构建

使用 Godot 4.7.2 打开 godot/project.godot 后运行。安装对应版本的 Windows／Web 导出模板后，可在本目录运行：

- pnpm dev：运行游戏。
- pnpm build：导出 artifacts/godot/windows/灰烬边境.exe 和同名 PCK。
- pnpm build:web：导出完整游戏到 artifacts/godot/web/，入口为 index.html。
- pnpm preview:web：启动本地 HTTP 预览；在浏览器中打开命令输出的地址。
- pnpm test:web：使用 Playwright Chromium 检查 Web 产物、键鼠与存档流程。
- pnpm test：原生规则、剧情、存档、界面与移动回归。
- pnpm test:standalone：复制原生工程，重新导入、测试并验证 PowerShell 构建。
- pnpm godot:content-check：验证原生文本基准、内容数量和素材校验值。
- pnpm godot:characters：从本地角色原稿打包全身立绘、头像和八向动作。
- pnpm godot:review：生成立绘、表情和动作总览。
- pnpm godot:resource-audit：生成资源引用与清理清单，不直接删除。

构建工具优先使用 GODOT_PATH，也可发现 artifacts/godot/engine 中的本地引擎。安装制作依赖使用 pnpm install --frozen-lockfile。运行、原生回归和 Web 导出也可直接执行 node tools/godot.cjs run、test、build-web，无需安装制作依赖。单独复制 godot/ 后还可直接使用其中的 build.ps1 构建 Windows 包，不需要 Node。

## 网页游玩与发布

使用支持 WebGL 2 的电脑浏览器和键盘鼠标，打开网页后点击游戏画面获得输入焦点；首次加载需要下载完整资源。Web 导出采用 Compatibility 渲染与单线程模式，不依赖跨源隔离响应头。本地预览需通过 HTTP 服务打开，不能直接双击 index.html。

网页的自动档与三个手动档位保存在当前浏览器的 IndexedDB 中，刷新后可继续。不同浏览器、隐私窗口、网站地址和 Windows 版的存档彼此独立；清除网站数据会清除本地进度。可在存档菜单下载 JSON 备份，再主动选择文件导入。

推送到 main 或手动运行 Godot Web 工作流后，GitHub Actions 使用固定 Godot 4.7.2 和官方模板执行原生回归、Web 导出及 Chrome（Chromium 引擎）验证，通过后使用官方 Pages Actions 发布。仓库 Settings → Pages 的 Source 设为 GitHub Actions。只部署 artifacts/godot/web/，源码、制作工具与缓存不作为网站文件上传；失败的构建不会替换线上版本。

浏览器验收使用固定 Playwright 1.62.1 与 sharp 0.35.5，可独立安装到 artifacts/web-test-deps/：运行 npm install --prefix artifacts/web-test-deps --no-save --package-lock=false --ignore-scripts playwright@1.62.1 sharp@0.35.5，再运行 node artifacts/web-test-deps/node_modules/playwright/cli.js install chromium，并让 NODE_PATH 指向其 node_modules 后执行 pnpm test:web。CI 使用同样的工具版本与 Ubuntu 运行器预装的 Google Chrome，无需另行下载浏览器。

## 操作

WASD／方向键八方向移动，Shift 跑步，F 交互。B 背包、C 角色、J 任务、M 地图、L 队伍；同键关闭，其他菜单键切页。按住 Tab 使用快捷轮盘，移向图标后松开执行，中央松开、Esc 或失焦取消。Esc 打开终端或返回；面板内 Tab 切换焦点。战斗 1–4 选技能，E 选择首个已配置技能，Q 选择大招，点击目标、Enter 确认。对白、确认框及文字输入优先。

七名角色有各自的觉醒故事和专属大招。旅人完成序章后开放，同伴需要入队并完成个人委托；从角色页或终端「角色觉醒」追踪。每段经过开场、两处调查、六级回响试炼和收束交谈。个人 TP 在觉醒后开始积累，跨战、旅行、休息和转职保留；满 100 才能释放大招，倒地清零。自动战斗默认保留 TP，战术页可单独允许自动大招。

## 任务与晨星镇生活

主线自动追踪；其余任务需要明确接取，完成后返回委托人或公会板交付。公会公告板有战斗、居民、采集、探索分类；J 日志优先显示可交付任务，已完成记录在列表底部默认折叠。新增3名孩子、6只小动物、6份连续居民委托与5处一次性采集点。十五个探索入口靠近并看见后才发现，首段发现只发布当地三段调查，不自动接取。旧渠检修口在晨星镇 `(22.5,14)`；路线返回对应所属地区的实际入口旁。

说明及验收见 [任务委托与探索入口](docs/Godot-任务委托与探索入口.md)。新版旧档首次读取前会另存 before-quests-v1 备份，保留原进度与已领奖记录。

## 内容与文件

加载插画、护盾、五属性克制、弱点削韧、战中变阵和羁绊升级见 [战术与加载升级说明](docs/Godot-护盾削韧与加载升级.md)。十张加载图采用日式西幻手绘风，原稿与提示词保存在 `art-source/loading/v2/`。新增物品符号使用 CC BY 3.0，来源与署名随包提供。

- godot/：独立运行工程、原生 JSON、GDScript、运行贴图及许可。
- art-source/：Godot 仍需的 CC0 制作素材、角色原稿、参考与 imagegen 提示词。
- tools/：原生构建、素材打包和验证工具。
- docs/Godot-角色觉醒与星轨交互.md：本轮玩法、改动、验证范围及证据。
- docs/Godot-原生角色与工程整理.md：此前纯 Godot 整理与角色素材制作记录。
- artifacts/godot/windows/：最新版 Windows 包，exe 与 PCK 保持同目录。
- artifacts/godot/web/：Godot Web 构建产物与随站许可，由 Actions 部署到 GitHub Pages。
- artifacts/backups/：一次变更前备份，支持恢复已退役网页及本次清理的内容。

原生 JSON 是内容唯一维护来源。原有 66 人物（本轮另加3名儿童）、204 话题、64 场景、242 调查物件和 15 篇世界观的文本基准保留。本轮 data/progression.json 追加七段觉醒、12 处建筑服务、24 处调查细节、14 处觉醒线索与两间内室，运行场景共 66 个。原文与新增内容分别使用 narrative-manifest、progression-manifest、quest-manifest 校验。quest-catalog 与 world-interactions 分别维护任务目录和世界交互。

Windows v1 存档仍使用 AshenFrontierDesktopGodot 命名空间；缺少新增字段的旧档在升级前保存 before-tp-v1 备份。GitHub 当前文件以这套完整 Godot 工程替换退役网页资源，已有提交历史保留。

游戏与原创素材沿用 CC0；第三方地表 CC0、字体 OFL、Godot MIT，以及 Game-icons.net 图标的 CC BY 3.0 作者署名随源工程、Windows 发行包和 Web 网站保留。
