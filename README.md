# perfect_game

一个基于 **Godot 4.7** 的游戏项目。

## 项目配置

| 项目 | 配置 |
| --- | --- |
| 引擎版本 | Godot 4.7（Mobile 版） |
| 渲染方式 | `mobile`（Windows 下使用 D3D12） |
| 物理引擎 | Jolt Physics（3D） |
| 窗口拉伸 | `canvas_items` / `expand` |
| .NET 程序集 | `perfect_game` |

## 目录结构

```
.
├── project.godot           # Godot 项目配置（已启用 Godot-MCP 插件）
├── perfect_game.csproj     # C# 项目文件（含 Godot-MCP 依赖）
├── addons/godot_mcp/       # Godot-MCP 编辑器插件（v0.33.0）
├── icon.svg                # 项目图标
├── icon.svg.import         # 图标导入配置
├── .editorconfig           # 编辑器编码规范
├── .gitattributes          # 换行符规范化（LF）
└── .gitignore              # 忽略 .godot/ 缓存与自动生成的 skills
```

## 本地运行

1. 安装 [Godot 4.7](https://godotengine.org/download)（如需 C# 支持请安装 .NET 版）。
2. 在项目管理器中点击「导入」，选择本目录下的 `project.godot`。
3. 按 `F5` 运行，或按 `F6` 运行当前场景。

> `.godot/` 为引擎自动生成的缓存目录，已被 `.gitignore` 忽略，无需提交。

## MCP 服务（Godot-MCP）

项目已集成 [Godot-MCP](https://github.com/IvanMurzak/Godot-MCP) 插件，让 AI Agent 通过
MCP（Model Context Protocol）直接操作 Godot 编辑器。

### 组件与端口

| 组件 | 说明 |
| --- | --- |
| 插件 | `res://addons/godot_mcp/`，已在 `project.godot` 的 `[editor_plugins]` 中启用 |
| 本地 MCP 服务 | `gamedev-mcp-server` 9.2.17，监听 `http://localhost:26475`，MCP 端点 `/mcp` |
| 服务缓存 | `.godot/mcp-server/win-x64/`（由插件下载/校验，已被 git 忽略） |
| 编辑器连接 | 插件启动后通过 SignalR 连接 `ws://localhost:26475/hub/mcp-server` |
| 插件配置 | `%APPDATA%\Godot\app_userdata\perfect_game\godot-mcp-config.json`（Custom 模式） |

### 启动方式

1. **随 Windows 登录自动启动**：登录时由启动文件夹中的 `Godot-MCP-Server.vbs`
   隐藏拉起服务。
2. **手动启动**：
   ```powershell
   cd .godot\mcp-server\win-x64
   .\gamedev-mcp-server.exe --port 26475 --client-transport streamableHttp
   ```
3. **由编辑器启动**：打开 Godot 编辑器后，在 Godot-MCP 面板点击 `Start Server`。

服务启动后，在编辑器中打开本项目，插件会自动连接；AI 客户端（如 DeepSeek Harness、
Claude Code 等）通过 `http://localhost:26475/mcp` 即可获得 `rql-query`、`rql-mutate`、
`script-*`、`screenshot-*` 等工具。

### 依赖包

`perfect_game.csproj` 中已声明插件所需 NuGet 包（与 `addons/godot_mcp/nuget-deps.json` 一致）：
`com.IvanMurzak.McpPlugin`、`com.IvanMurzak.ReflectorNet`，以及仅编辑器构建使用的
`com.IvanMurzak.Rql`、`com.IvanMurzak.CodeExec*`、`Microsoft.CodeAnalysis.CSharp`。
