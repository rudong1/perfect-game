# perfect_game

一个基于 **Godot 4.7** 的 2D 横板镜像解谜原型。

## 项目配置

| 项目 | 配置 |
| --- | --- |
| 引擎版本 | Godot 4.7（.NET 版） |
| 分辨率 | `1920 × 1080`（`canvas_items` / `expand`） |
| 渲染方式 | `mobile`（Windows 下使用 D3D12） |
| 当前内容 | 主菜单 + 五个单屏房间 + 三棱镜结算 + 结局 |
| 主题 | 「镜」；颜色使用灰阶 + 红 / 蓝 / 绿三色 |

## 运行

1. 安装 Godot 4.7 .NET 版。
2. 导入本目录的 `project.godot`。
3. 按 `F5`。标题画面输入角色名（可留空，默认「无名」），点击「踏入镜中」。

## 操作

| 按键 | 功能 |
| --- | --- |
| `A` / `D` 或 `←` / `→` | 左右移动 |
| `W` / `↑` | 跳跃（土狼时间、跳跃缓冲、短按小跳） |
| `S` / `↓` | 蹲下；蹲下时可以缓慢移动 |
| `M` | 整屏上下镜像；切换现实/倒影逻辑层 |
| `Shift` | 冲刺（临时保留的移动加速） |

HUD 在镜像层之上，所以画面翻转时操作提示和名字仍然保持正向。角色名会以小字跟随主角。

## 五个房间

1. **第一镜 · 无色**：纯黑白。用倒影桥跨过第一道缺口，踩倒影踏板开门。
2. **第二镜 · 赤**：红色世界。两扇门在现实/倒影中交替实体，需要找时机按 M 穿过。
3. **第三镜 · 青**：蓝色世界。倒影桥只在镜中实体，桥下是镜雨和尖刺。
4. **第四镜 · 翠**：绿色世界。先过现实门，再走倒影桥，回到现实踩下最后的踏板。
5. **终镜 · 虹**：彩色终点。走过最后的倒影桥，进入棱镜。

每关结束会展示三棱镜进度：白光射入棱镜，折射出**连续彩虹色带**；红色房间恢复 R，蓝色房间恢复 B，绿色房间恢复 G，最终 R、G、B 全部归位。

## 存档点

每个房间中有一座发光的三棱镜存档点（世界内标注「存档点」）。

- 触碰后，主角的重生点更新为存档点位置。
- 同时写入 `user://mirror_save.cfg`：角色名、当前关卡、已完成关卡、存档点坐标、R/G/B 进度。
- 掉坑、碰尖刺后回到最近的存档点；镜像状态自动复位。
- 标题画面检测到存档时会出现「继续旅程」，从存档点继续；「踏入镜中」开新游戏会清除旧存档并重置进度。

## 文件

| 文件 | 说明 |
| --- | --- |
| `scenes/ui/title_screen.tscn` | 标题画面 + 角色名输入 + 继续游戏 |
| `scenes/gameplay/gameplay.tscn` | 游戏容器：玩家、相机、HUD、棱镜结算层 |
| `scenes/ui/ending_screen.tscn` | 彩色结局 |
| `scenes/player/player.tscn` | 主角场景：动画、胶囊碰撞、名字跟随、镜像渲染 |
| `scripts/game_state.gd` | 全局进度、五关数据、存档读写（autoload） |
| `scripts/mirror_state.gd` | 全局镜像开关，M 键输入（autoload） |
| `scripts/level_builder.gd` | 用代码构建五个房间的几何和机关 |
| `scripts/gameplay.gd` | 关卡加载、HUD、目标、存档点提示、棱镜结算 |
| `scripts/checkpoint.gd` | 存档点触发与激活状态 |
| `scripts/prism_overlay.gd` | 关卡结束后的三棱镜进度层 |
| `scripts/prism_visual.gd` | 平面三棱镜 + 连续彩虹色带 + R/G/B 组件恢复 |
| `scripts/mirror_platform.gd` / `mirror_gate.gd` / `mirror_plate.gd` | 镜像机关组件 |
| `scripts/hazard.gd` / `fall_reset.gd` | 尖刺与坠落复位 |
| `scripts/name_tag.gd` | 跟随主角的英文/中文名字标签 |
| `shaders/screen_mirror.gdshader` | 整屏垂直镜像 |
| `shaders/level_backdrop.gdshader` | 随关卡变色的大气背景 |
| `assets/ui/ui_theme.tres` | SystemFont UI 主题（支持中文） |
| `docs/` | 运行截图（`.gdignore`，不参与 Godot 导入） |

## 截图

[标题](docs/title.png) · [第一镜](docs/level_01.png) ·
[镜像状态](docs/level_01_mirror.png) · [存档点](docs/checkpoint.png) ·
[三棱镜 RGB](docs/prism_rgb.png) · [部分恢复 R+B](docs/prism_partial_rb.png) · [结局](docs/ending.png)

## 技术说明

- `MirrorState` 只负责镜像开关与信号；`ScreenMirror` 只负责渲染。
- `MirrorPlatform` / `MirrorGate` / `MirrorPlate` 监听同一个 `mirror_changed` 信号，所以镜子、桥、门、踏板和 HUD 永远同步。
- 房间由 `LevelBuilder` 在运行时构建，单屏固定相机为 `(960, 540)`。
- 存档使用 `ConfigFile` + `user://`，不依赖平台相关路径。
- 颜色世界与 RGB 恢复分开：三个颜色房间负责叙事和氛围，三棱镜按进度恢复 R、G、B 分量。

## 已知边界

这是 Game Jam 原型，不包含敌人/战斗、音频、存档位管理、多结局或完整关卡内容。当前重点是：
用手感、镜像机关、颜色世界、棱镜进度与存档点组成一个可连续游玩的垂直切片。

## MCP 服务

项目已启用 Godot-MCP 插件。编辑器打开项目后，插件会连接
`http://localhost:26475/mcp`，提供 `rql-query`、`rql-mutate`、`script-*`、
`screenshot-*` 等工具；具体启动方式见 `addons/godot_mcp/README` 或本地 MCP 服务配置。
