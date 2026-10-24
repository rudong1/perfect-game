# perfect_game

一个基于 **Godot 4.7.2** 的 2D 横板镜像解谜原型。

## 项目配置

| 项目 | 配置 |
| --- | --- |
| 引擎版本 | Godot 4.7.2（.NET 版） |
| 分辨率 | `1920 × 1080`（`canvas_items` / `expand`） |
| 渲染方式 | `mobile`（Windows 下使用 D3D12） |
| 当前内容 | 主菜单 + 五个单屏房间 + 三棱镜结算 + 结局 |
| 主题 | 「镜」；颜色使用灰阶 + 红 / 蓝 / 绿三色 |

## 运行

1. 安装 Godot 4.7.2 .NET 版。
2. 导入本目录的 `project.godot`。
3. 按 `F5`。标题画面输入角色名（可留空，默认「无名」），点击「踏入镜中」。

## 操作

| 按键 | 功能 |
| --- | --- |
| `A` / `D` 或 `←` / `→` | 左右移动 |
| `W` / `↑` | 跳跃（土狼时间、跳跃缓冲、短按小跳） |
| `S` / `↓` | 蹲下；蹲下时可以缓慢移动 |
| `M` | 沿共享镜像轴翻转画面与重力；光路关中只转动附近的一面光镜 |
| `E` | 靠近立镜时穿镜，出口预览由当前镜面位置计算 |
| `R` | 重置当前房间的角色、分身和机关 |
| `Shift` | 冲刺；更容易拉开本体与分身的距离 |

HUD 在镜像层之上，所以画面翻转时操作提示和名字仍然保持正向。角色名会以小字跟随主角。

## 五颗沉星：机制初版

1. **双生门廊**：上下两块压板必须同时被本体与分身占用，且处于镜像态，持续片刻后锁存开门。按 M 后冲刺向右可以拉开两人的距离；也可以先越过压板再反向移动，利用分身惯性补位。
2. **推镜廊**：A/D 贴着立镜推动，镜面进入地面的绿色刻度（x=1040–1120），完成一次 E 穿镜后开门。出口位置实时预览，拒绝传送进墙；右侧缺口可以冲刺跳过，也可以借天花板绕行。
3. **三色回响**：靠近红镜 M → 推立镜越过绿镜、停在蓝光发射器之前 → 靠近绿镜 M → E 穿镜、走到蓝镜 → M。三色必须**此刻同时**抵达各自接收器；两色亮起时 HUD 会提示还差一色。走到没有光镜的位置再翻转，只改变重力，不改动光路。
4. **双生回响**：先同时压住双板留下回声，再解三色光路。压板的记忆会保留，光路必须保持畅通。
5. **沉星归途**：同时满足真实穿镜与三色到达，进入最后的棱镜。

五个世界是五颗沉进镜面的星。世界内的铭文预先上下反写，只有镜像态下可读；HUD 保持正向。当前关卡使用代码生成的几何，场景美术与难度仍待打磨。

## 机制约定

- `MirrorState.axis_y` 是世界坐标中的唯一水平镜像轴（默认 540）；分身按它生成，shader 通过相机变换读取同一轴。
- 分身是带独立碰撞的 `CharacterBody2D`（也是 `Node2D`），与本体重力相反，只惯性跟随水平速度，不读取跳跃。为了能补位，它仅在生成、重生或轴变更时严格对称，不会逐帧强制传送回对称位置。
- 翻转保留速度、反转重力及落地判定方向，并在机关碰撞更新后检查胶囊是否嵌入；沿竖直方向寻找最近空位，整列封闭时寻找邻近空位。
- 立镜的竖直反射轴是自己的 x：`出口.x = 2 * 镜面.x - 入口.x`。A/D 推动有加速和摩擦，E 手动穿镜，避免推镜时误触传送。
- 光路按实际线段求交和法线反射计算。每次 M 只转动横向 185 像素内最近的一面光镜；立镜会遮挡光，推错位置能使已点亮的通道熄灭。
- 光路关的 `colored_rays()`、`restored_channel_count()`、`has_rainbow()` 返回实时接收状态，不会因历史通关数自动判成功。离开房间后，棱镜结算继续展示旅程中的颜色恢复进度。
- 本体、分身、世界分别使用碰撞层 2、3、1；分身能压板，但不能触发主角的终点、存档点或死亡区。R 与死亡会重置房间机关，存档恢复后也需要重新解当前房间。

## 回归检查

使用 Godot 4.7.2 .NET，在项目根目录运行（Linux）：

```sh
# 先导入资源；godot 必须指向 .NET 版。
dotnet build perfect_game.csproj
godot --headless --editor --import --quit
# 使用隔离的用户数据目录，不覆盖自己的旅程存档。
XDG_DATA_HOME="$(mktemp -d)" godot --headless --fixed-fps 60 --path . --script res://tests/mirror_mechanics.gd
```

检查包含轴投影、上下重力与跳跃、分身惯性、真实双板接触、推镜摩擦、传送阻塞、三色反射与遮挡、组合关卡、最终结算与存档。测试会打印检查数与失败数，并以非零退出码报告失败。

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
| `scripts/level_builder.gd` | 用代码构建五个机制房间 |
| `scripts/mirror_self.gd` | 反重力实体分身与惯性跟随 |
| `scripts/mirror_slab.gd` | 推动、反射出口预览与安全穿镜 |
| `scripts/mirror_safety.gd` | 胶囊碰撞检查与翻转安全重定位 |
| `scripts/prism_circuit.gd` | 三色光线反射、遮挡和接收 |
| `scripts/room_puzzle.gd` | 双板、穿镜和实时光路的通关条件 |
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

以下截图来自机制重做前的原型，关卡以当前运行内容为准。

[标题](docs/title.png) · [第一镜](docs/level_01.png) ·
[镜像状态](docs/level_01_mirror.png) · [存档点](docs/checkpoint.png) ·
[三棱镜 RGB](docs/prism_rgb.png) · [部分恢复 R+B](docs/prism_partial_rb.png) · [结局](docs/ending.png)

## 技术说明

- `MirrorState` 负责共享轴、镜像开关及重置通知；`ScreenMirror` 将轴投影到屏幕后渲染。
- 玩家、分身、光镜与 HUD 监听同一个 `mirror_changed` 信号；渲染轴会随相机/窗口变化更新。
- 房间由 `LevelBuilder` 在运行时构建，单屏固定相机为 `(960, 540)`。
- 存档使用 `ConfigFile` + `user://`，不依赖平台相关路径。
- 颜色世界与 RGB 恢复分开：三个颜色房间负责叙事和氛围，三棱镜按进度恢复 R、G、B 分量。

## 已知边界

这是 Game Jam 原型，不包含敌人/战斗、音频、存档位管理、多结局或完整关卡内容。当前重点是：
用双生压板、推镜传送、反重力与实时三色光路组成一个可连续游玩的垂直切片。

## MCP 服务

项目已启用 Godot-MCP 插件。编辑器打开项目后，插件会连接
`http://localhost:26475/mcp`，提供 `rql-query`、`rql-mutate`、`script-*`、
`screenshot-*` 等工具；具体启动方式见 `addons/godot_mcp/README` 或本地 MCP 服务配置。
