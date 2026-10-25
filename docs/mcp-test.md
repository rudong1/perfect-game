# MCP（godot）端到端测试报告

- 测试对象：本仓库已配置的 Godot-MCP（`serverName: godot`）链路
- 测试日期：2026-10-25（Asia/Shanghai, UTC+08:00）
- 测试范围：MCP 服务进程/端口、streamable-http 协议握手、无引擎插件时的降级行为、`godot-cli` 调用链路、临时启用 `addons/godot_mcp` 后的编辑器端到端真实工具调用、收尾清理
- 结论速览：**协议层通过；`godot-cli` 链路部分通过；降级行为与预期一致；端到端（插件连接后真实工具调用）通过。MCP 在本项目可用，但需要显式把插件指向 26475 端口（或反之把 DSH 配置对齐到插件派生端口 23156），否则会出现「插件连自己的 23156、DSH 连 26475」的分裂状态。**

---

## 1. 测试环境

| 项目 | 值 |
| --- | --- |
| 主机 / OS | Windows 10 Pro 26H2，build 26300（`Microsoft Windows NT 10.0.26300.0`） |
| 仓库 / 工作目录 | `C:\Users\CuteGrass\Documents\perfect_game`（「镜尽余色」Godot 2D 项目） |
| Godot 编辑器 | `Godot_v4.7.2-stable_mono_win64_console.exe`（4.7.2-stable official，.NET/Mono 版） |
| 插件 | `addons/godot_mcp`，plugin.cfg version `0.33.0`，plugin API `2.0.0` |
| MCP 服务 | `gamedev-mcp-server 9.2.17.0`，PID **29900**，启动于 2026-10-24 17:20:47 |
| 服务地址 / 传输 | `http://localhost:26475/mcp`（streamable-http，auth=none，bind loopback） |
| 服务可执行文件 | `.godot\mcp-server\win-x64\gamedev-mcp-server.exe` |
| 服务日志 | `.godot\mcp-server\win-x64\logs\server-log.txt`（另有 `server-log-error.txt`） |
| DSH 侧配置来源 | `C:\Users\CuteGrass\.dsh\profiles\desktop\cordis.patch.yml` 第 35–46 行（`serverName: godot`，`transport: streamable-http`，`url: http://localhost:26475/mcp`，`failOnStartupError: false`） |
| .NET SDK | `10.0.402`（`C:\Program Files\dotnet\dotnet.exe`） |
| Node / npm | Node `v24.19.0` / npm `11.17.0` |
| godot-cli | `0.33.0`（`C:\Users\CuteGrass\AppData\Roaming\npm\godot-cli.cmd`） |
| 插件启用状态（测试前） | `[editor_plugins] enabled=PackedStringArray()`（关闭，与 README 一致） |
| 测试前仓库状态 | 存在**预存未提交改动**：`project.godot` 的 `config/features` 由 `PackedStringArray("4.7", "Mobile")` 变为 `PackedStringArray("4.7", "C#", "Mobile")`（非本次测试产生，测试中未回退，因为 .NET 版 Godot 加载 C# 插件需要该 feature） |
| C# 构建产物 | 复用 `.godot\mono\temp\bin\Debug` 下 2026-10-24 已有构建（`perfect_game.dll`、`McpPlugin.dll` 等），本次**未重新执行 `dotnet build`**，插件正常加载 |

测试开始前已把 `project.godot` 快照备份到 `%TEMP%\perfect_game-project.godot.bak`，SHA256 为
`FA62148F5AB65CBC7174D2CD450D17015C433A3D05BB2D8008EA56953410B883`（测试结束恢复后重新计算一致）。

---

## 2. 测试矩阵

> 说明：原始 JSON-RPC 请求使用 `curl.exe`（Windows 自带）发送；`Mcp-Session-Id` 从 `initialize` 响应头读取并复用于后续请求。时间均为 2026-10-25。

| # | 测试项 | 命令 / 操作（摘要） | 期望 | 实际 | 结论 |
| --- | --- | --- | --- | --- | --- |
| 1 | 服务进程与端口 | `Get-Process -Id 29900`；`netstat -ano \| findstr 26475` | 进程存活、26475 LISTENING | PID 29900 存活（StartTime 10/24 17:20:47）；`127.0.0.1:26475`、`[::1]:26475` 均 LISTENING，Owner 29900 | 通过 |
| 2 | `initialize` 握手 | `curl -X POST http://localhost:26475/mcp -H 'Accept: application/json, text/event-stream' -d '{...initialize...}'` | 200，返回 serverInfo 与 `Mcp-Session-Id` | HTTP 200；`serverInfo=gamedev-mcp-server 9.2.17.0`；`protocolVersion=2024-11-05`；响应头 `Mcp-Session-Id` 非空；capabilities=`logging,prompts,resources,tools` | 通过 |
| 3 | 无会话头调用非 initialize 方法 | 同上但不带 `Mcp-Session-Id` 调 `tools/list` | 400，提示必须带会话头 | HTTP 400，`-32000`：`Bad Request: A new session can only be created by an initialize request. Include a valid Mcp-Session-Id header for non-initialize requests, ...` | 通过（符合规范） |
| 4 | `notifications/initialized` | 带会话头发送该通知 | 202 Accepted | HTTP 202，空 body | 通过 |
| 5 | `tools/list`（无引擎插件） | 带会话头 `tools/list` | 返回列表（服务端日志称“返回 server-native 工具”） | HTTP 200，`{"tools":[]}`，**数量 0** | 通过（见 §6 注意点） |
| 6 | `prompts/list`（无引擎插件） | 同上 | 空列表 | HTTP 200，`{"prompts":[]}` | 通过 |
| 7 | `resources/list`（无引擎插件） | 同上 | 空列表 | HTTP 200，`{"resources":[]}` | 通过 |
| 8 | `resources/templates/list`（无引擎插件） | 同上 | 空列表 | HTTP 200，`{"resourceTemplates":[]}` | 通过 |
| 9 | 无插件时调用引擎工具（降级行为） | `tools/call`：`ping` / `rql-schema` / `script-read` | 明确报错（isError） | 三个工具均 HTTP 200、`isError=true`，文本 `Invoke 'RunCallTool': Failed to invoke 'com.IvanMurzak.McpPlugin.Common.Model.RequestCallTool' after 10 retries.`；单次耗时约 10.5 s；服务端日志 `No engine plugin is connected.` + `Retrying [10/10]` | 通过（降级符合基线） |
| 10 | `godot-cli --version` | `godot-cli.cmd --version` | 打印版本 | `0.33.0` | 通过 |
| 11 | `godot-cli status`（默认端口） | `godot-cli.cmd status` | 探测默认地址 | 默认 URL `http://localhost:23156`，`ERROR: Not available (connection refused)`，退出码 1 | 通过（证明默认端口与 DSH 26475 不一致） |
| 12 | `godot-cli status --url 26475`（无编辑器） | `godot-cli.cmd status --url http://localhost:26475` | 服务可达 | `Probing http://localhost:26475... ERROR: Not available (timed out)` | 失败（无插件连接时探测超时，见 §6） |
| 13 | `godot-cli run-tool`（无插件） | `godot-cli.cmd run-tool rql-schema --url http://localhost:26475 --input '{}'` | 返回 503/错误 | HTTP 503，JSON `{"error":"Invoke 'RunCallTool': Failed to invoke ... after 10 retries."}`，退出码 1 | 通过（降级可见） |
| 14 | 临时启用插件 | 将 `project.godot [editor_plugins] enabled` 改为 `PackedStringArray("res://addons/godot_mcp/plugin.cfg")` | 编辑器启动时加载插件 | 插件加载，Godot 输出 `[Godot-MCP] connecting (mode=Custom, host=http://localhost:26475)` | 通过 |
| 15 | 启动 headless 编辑器 | `Start-Process Godot_v4.7.2-stable_mono_win64_console.exe -ArgumentList '--headless','--editor','--path','.'`，环境变量 `GODOT_MCP_HOST=http://localhost:26475`、`GODOT_MCP_CONNECTION_MODE=Custom`、`GODOT_MCP_AUTH_OPTION=none` | 进程存活并连接 SignalR | 启动 PID 23164；16:17:04.5908 服务日志出现 `Client ... connected to McpServerHub. Total connected clients: 1`；16:17:04.6613 `Version handshake successful. Plugin: 0.33.0, API: 2.0.0, Environment: Godot 4.7.2-stable (official)` | 通过 |
| 16 | 插件连接后 `tools/list` | 带会话头 `tools/list` | 返回引擎工具 | HTTP 200，**15 个工具**（见 §4），耗时 131 ms | 通过 |
| 17 | 真实工具 `rql-schema` | `tools/call` `{"name":"rql-schema","arguments":{}}` | 返回编辑器/场景 schema | HTTP 200，`isError=false`，6371 字符，含 sources/functions/节点类统计；客户端 30 ms / 服务端 handler 7.9 ms | 通过 |
| 18 | 真实工具 `script-read` | `{"scriptPath":"res://scripts/game_state.gd","lineFrom":1,"lineTo":12}` | 返回脚本内容 | HTTP 200，`isError=false`，返回 `Language:GDScript`、`LineCount:12` 及真实脚本内容；52 ms / 30.3 ms | 通过 |
| 19 | 真实工具 `rql-query` | `{"query":"editor"}` | 返回编辑器状态 | HTTP 200，`isError=false`，返回 `1 result {isPlaying:false, editedScene:"res://scenes/player/player.tscn", godotVersion:"4.7.2-stable (official)", ...}`；36 ms / 11.7 ms | 通过 |
| 20 | 真实工具 `runtime-errors-get` | `{}` | 返回运行时错误信息 | HTTP 200，`isError=false`，`{Available:false,Ok:true,Count:0,...,Note:"Runtime error capture is not enabled in this game..."}`；31 ms / 8.6 ms | 通过 |
| 21 | `godot-cli status --url 26475`（有编辑器） | 同上 | 服务可达 | `SUCCESS: Connected`（但编辑器进程检测为 `WARN: Godot is not running with this project`，见 §6） | 部分通过 |
| 22 | `godot-cli run-tool`（有插件） | `godot-cli.cmd run-tool rql-schema --url http://localhost:26475 --input '{}'` | 成功返回 schema | `SUCCESS: rql-schema completed`，返回真实 schema 文本（与 #17 一致） | 通过 |
| 23 | 收尾：结束编辑器 | `Stop-Process -Id 23164 -Force`（复测时另为 `-Id 2044`） | 进程退出、无遗留 | 两轮进程均已退出；`Get-Process *Godot*` 无结果 | 通过 |
| 24 | 收尾：恢复 project.godot | 从 `%TEMP%\perfect_game-project.godot.bak` 复制回 | 字节级一致 | SHA256 恢复前后均为 `FA62148F...10B883` 一致 | 通过 |
| 25 | 收尾：仓库状态 | `git status --porcelain` | 仅预存 `M project.godot` + 新增 `docs/mcp-test.md` | 恢复后仅 ` M project.godot`（预存 C# feature 改动）；写入本报告后为 `M project.godot` + `?? docs/mcp-test.md` | 通过 |
| 26 | 服务保持运行 | `Get-Process -Id 29900`、`netstat` | 29900 存活、未重启 | PID 29900 存活，StartTime 仍为 10/24 17:20:47，端口 26475 LISTENING；测试期间**未重启服务** | 通过 |

汇总：共 26 项，通过 24 项，部分通过 1 项（#21 编辑器进程检测误报），失败 1 项（#12 无插件时 status 探测超时），无阻塞项。

---

## 3. 协议层细节

### 3.1 握手与能力

```text
POST http://localhost:26475/mcp
Accept: application/json, text/event-stream
Content-Type: application/json

{"jsonrpc":"2.0","id":1,"method":"initialize","params":{
  "protocolVersion":"2024-11-05","capabilities":{},
  "clientInfo":{"name":"dsh-probe-e2e","version":"1.0"}}}
```

响应（HTTP 200，`Content-Type: text/event-stream`，响应头含 `Mcp-Session-Id`）：

```json
{"result":{"protocolVersion":"2024-11-05",
  "capabilities":{"logging":{},"prompts":{"listChanged":true},
                  "resources":{"listChanged":true},"tools":{"listChanged":true}},
  "serverInfo":{"name":"gamedev-mcp-server","version":"9.2.17.0"}},
 "id":1,"jsonrpc":"2.0"}
```

要点（均为实测）：

1. 会话是必需的：`initialize` 之外的方法必须带响应头里的 `Mcp-Session-Id`，否则 HTTP 400 / `-32000`（见矩阵 #3）。
2. `notifications/initialized` 返回 **202 Accepted**（空 body），不是 JSON。
3. 列表类方法返回 SSE 帧（`event: message` + `data: {...}`），解析时取 `data:` 行。
4. 服务无 Redis（启动日志 WARN：`REDIS_URL is not set — MCP sessions will NOT survive a server restart`），因此**不要随意重启服务**，否则既有 MCP 会话全部失效。

### 3.2 客户端坑位（实测，供复现参考）

- 用 PowerShell `Invoke-WebRequest` 复用 `Mcp-Session-Id` 时，后续请求返回 `404 {"error":{"code":-32001,"message":"Session not found"}}`；同一 `initialize` 返回的 session 用 `curl.exe` 立刻重放则正常（202/200）。判断为 PowerShell HTTP 栈与 SSE/会话头的交互差异，**不是服务端缺陷**。复现时请用 `curl.exe` 或 MCP 官方 SDK。
- `curl.exe` 需要 `--data-binary` 直接给 JSON 字符串；`Mcp-Session-Id` 的值从 `-D` 导出的响应头中取。

### 3.3 列表数量

| 方法 | 无引擎插件 | 插件连接后 |
| --- | --- | --- |
| `tools/list` | 0（服务日志称“只返回 server-native 工具”，实际返回空数组） | **15** |
| `prompts/list` | 0 | 0（实测，插件未注册 prompt） |
| `resources/list` | 0 | 0（实测，插件未提供 resource） |
| `resources/templates/list` | 0 | 0（实测，插件未提供 resource template） |

> 连接后计数于 16:20:06 复测（编辑器 PID 2044，`server-log.txt` 第 1626 行连接记录）：tools 15 / prompts 0 / resources 0 / templates 0。

---

## 4. 工具清单（插件连接后，`tools/list`，共 15 个）

| 工具 | 用途（据 description 摘要） |
| --- | --- |
| `rql-query` | 对运行中的编辑器执行只读 RQL 查询，返回紧凑行 |
| `rql-mutate` | RQL 写操作（改场景/资源） |
| `rql-schema` | RQL 源/函数/节点类与成员自省（可按类型名查询） |
| `screenshot-camera` | 相机截图 |
| `screenshot-isolated` | 隔离场景截图 |
| `screenshot-viewport` | 视口截图 |
| `script-read` | 读取 res:// 下脚本内容（支持行区间） |
| `script-create` | 新建脚本 |
| `script-update` | 更新脚本 |
| `script-delete` | 删除脚本 |
| `script-execute` | 执行脚本 |
| `script-validate` | 校验脚本 |
| `script-attach-to-node` | 把脚本挂到节点 |
| `runtime-errors-get` | 获取运行时错误捕获 |
| `runtime-errors-clear` | 清空运行时错误 |

注意：**本版本没有 `ping` 工具**（任务书中的 `ping` 期望不适用于 0.33.0 插件）；健康检查可用 `rql-schema` 或 `runtime-errors-get`。

---

## 5. 端到端证据

### 5.1 时间线（2026-10-25，本地时间 UTC+8）

| 时间 | 事件 | 证据 |
| --- | --- | --- |
| 16:16:59 | 启动 headless 编辑器（PID 23164），环境变量指向 26475 | `Start-Process` 返回 PID；`%TEMP%\godot-e2e-stdout.log` |
| 16:17:04.5908 | 插件 SignalR 连接成功 | `server-log.txt` 第 1591 行：`Client 'f735EMkoKe2V8ClOvR_14A' connected to McpServerHub. Total connected clients: 1` |
| 16:17:04.6613 | 版本握手成功 | 第 1592 行：`Version handshake successful. Plugin: 0.33.0, API: 2.0.0, Environment: Godot 4.7.2-stable (official)` |
| 16:17:40–41 | 第一轮真实工具调用（rql-schema/script-read/runtime-errors-get/rql-query） | 第 1600/1603/1606/1609 行：`"... completed. IsError = False."` |
| 16:17:51–52 | 第二轮真实工具调用（同上，用于取耗时） | 第 1614/1617/1620/1623 行 |
| 16:18 左右 | `godot-cli status/run-tool` 验证 | 命令输出见矩阵 #21/#22 |
| 16:18 左右 | 停止编辑器（PID 23164）、恢复 `project.godot` | `Get-FileHash` 与备份一致；`git status` 仅预存改动 |
| 16:20:06.7745 | 复测：再次启动编辑器（PID 2044）并连接成功，用于补充“插件连接后”的 prompts/resources/templates 计数 | 第 1626 行：`Client 'maSshTJbv4ddVEYN2zY3RA' connected to McpServerHub. Total connected clients: 1` |
| 16:20 左右 | 停止编辑器（PID 2044）、再次恢复 `project.godot`（哈希仍一致） | `RESTORED_HASH=FA62148F...10B883` |

连接建立耗时：启动 → 连接成功约 **5.4 s**（16:16:59 → 16:17:04.5908）。

### 5.2 Godot 侧日志（stdout，`%TEMP%\godot-e2e-stdout.log`，共 188 行）

```text
[Godot-MCP] project identity: pin=94bbe2fa derivedPort=23156 (portOverridden=False); enrolled serverTarget=<none>.
[Godot-MCP] auto-generate skills: ensured up-to-date skills in C:/Users/CuteGrass/Documents/perfect_game/.claude/skills.
[Godot-MCP] connecting (mode=Custom, host=http://localhost:26475) ...
[McpPlugin] HubConnection: Starting transport. Transfer mode: Text. Url: 'ws://localhost:26475/hub/mcp-server?instance_id=...&engine=godot&project_name=perfect_game&project_path_hash=94bbe2fa...'
[McpPlugin] HubConnection: HubConnection started.
[McpPlugin] McpManagerClientHub: McpManagerClientHub Version handshake completed. Compatible: True, Message: API version is compatible.
[Godot-MCP] connected.
```

关键点：插件**默认派生端口是 23156**（`derivedPort=23156`），本次通过环境变量把它指向了服务实际端口 26475。

### 5.3 真实工具返回（摘要）

- `rql-schema`（`{}`）：`isError=false`，6371 字符，开头为 RQL 的 sources/functions 说明，并列出当前编辑场景中的节点类统计（`CanvasLayer ×2, AnimatedSprite2D ×1, CharacterBody2D ×1, ...`）。客户端 30 ms，服务端 handler 7.9 ms。
- `script-read`（`{"scriptPath":"res://scripts/game_state.gd","lineFrom":1,"lineTo":12}`）：

  ```text
  {ResourcePath:"res://scripts/game_state.gd",Language:GDScript,
   Content:"extends Node\n## Run state for the four-world color journey...",
   LineCount:12,Status:"Script read."}
  ```

  客户端 52 ms，服务端 handler 30.3 ms。
- `rql-query`（`{"query":"editor"}`）：`1 result {isPlaying:false,playingScene:null,editedScene:"res://scenes/player/player.tscn",godotVersion:"4.7.2-stable (official)",projectPath:"C:/Users/CuteGrass/Documents/perfect_game/",selection:"Node[][0]"}`，36 ms / 11.7 ms。
- `runtime-errors-get`（`{}`）：`{Available:false,Ok:true,Count:0,...,Note:"Runtime error capture is not enabled in this game..."}`，31 ms / 8.6 ms。
- `godot-cli run-tool rql-schema --url http://localhost:26475 --input '{}'`（插件连接时）：`SUCCESS: rql-schema completed`，返回内容与 #17 一致。

### 5.4 编辑器启动时的告警/错误（非致命，已记录）

- stderr 共 32 行，其中 `ERROR:` 仅 1 条：`ERROR: Failed to read the root certificate store.`（Windows headless 读取系统根证书失败，插件仍正常连接）。
- 启动早期有 1 段 `EnsureConnection ... auto-reconnect disabled` 的 WARNING 及其 C# 堆栈（发生在连接建立前、RqlInstaller 注册工具触发 `NotifyAboutUpdatedTools` 时）；随后连接成功、工具可用，属启动顺序噪声，不影响功能。

---

## 6. 降级行为（无引擎插件连接）基线

在插件关闭/未连接时，MCP 服务的行为是「协议可用、引擎能力不可用」：

- **列表**：`tools/list`、`prompts/list`、`resources/list`、`resources/templates/list` 全部 HTTP 200，但内容为空（`tools` 为 `[]`；服务端日志措辞为 `Returning server-native tools only`，实际没有暴露任何 server-native 工具）。
- **引擎工具调用**：HTTP 200 + `isError=true`，正文为
  `Invoke 'RunCallTool': Failed to invoke 'com.IvanMurzak.McpPlugin.Common.Model.RequestCallTool' after 10 retries.`
  单次调用约 **10.5 s**（服务端 `No connected clients. Retrying [1/10]...[10/10]` 后报错）。
- **服务端日志**（`server-log.txt`）：
  - 第 1492 行：`ERROR ... RemoteToolRunner | Error: No engine plugin is connected.`
  - 第 1493 行：`WARN ... ToolRouter | ListAll error (plugin may not be connected yet): No engine plugin is connected.. Returning server-native tools only.`
  - 第 1557/1558 行：`Retrying [10/10]` → `Failed to invoke ... after 10 retries.`
- **godot-cli**：`run-tool` 走 `http://localhost:26475/api/tools/<name>`，无插件时返回 HTTP 503 + 上述错误 JSON，退出码 1；`--url` 缺省时默认探测 23156，直接 connection refused。

---

## 7. 结论

1. **MCP 服务本身（协议层）可用**：streamable-http 会话、initialize/tools/prompts/resources 均正常，会话头机制符合预期。
2. **端到端可用（已验证）**：临时启用 `addons/godot_mcp` 并让插件显式连接 26475 后，编辑器注册 15 个工具，`rql-schema` / `script-read` / `rql-query` / `runtime-errors-get` 全部成功，延迟 30–52 ms；`godot-cli run-tool` 同步可用。
3. **不可用/受限的部分**：
   - 编辑器未启动（或插件未启用）时，任何引擎工具都不可用 → DSH 侧只能看到空工具列表，调用会等约 10 s 后报错。
   - `godot-cli status` 对「非 godot-cli 启动的 headless 编辑器」识别不到编辑器进程（只报 `WARN: Godot is not running with this project`），但 MCP 服务连通性判断本身可用；`godot-cli status` 无插件连接时探测会超时（#12）。
   - 本版本无 `ping` 工具；健康检查请用 `rql-schema`/`runtime-errors-get`。
4. **根因/关键配置风险**：插件按项目身份派生的默认端口是 **23156**，而 DSH 配置与常驻服务使用 **26475**。若不同时做显式指向，二者会各自为政（插件在 23156 起/连自己的服务，DSH 在 26475 看不到插件）。本次通过 `GODOT_MCP_HOST=http://localhost:26475` + `GODOT_MCP_CONNECTION_MODE=Custom` + `GODOT_MCP_AUTH_OPTION=none` 消除了分裂。

---

## 8. 修复 / 使用建议

### 8.1 保持现状（服务固定 26475）时，让插件指向 26475

启动编辑器前设置三个环境变量（本次验证有效）：

```powershell
$env:GODOT_MCP_HOST           = 'http://localhost:26475'
$env:GODOT_MCP_CONNECTION_MODE = 'Custom'
$env:GODOT_MCP_AUTH_OPTION     = 'none'
& 'C:\Users\CuteGrass\Desktop\Godot\Godot_v4.7.2-stable_mono_win64_console.exe' --path .
```

也可在项目根写 `.env`（插件会读取 `res://.env`，`GODOT_MCP_HOST` 指向 loopback 时会自动进入 Custom 模式）。本仓库已落地该方案：`.env`（已被 `.gitignore` 忽略）+ `.env.example`（模板），详见 §11。

### 8.2 或让插件管理服务（派生 23156），把 DSH 配置对齐

若希望「打开编辑器即自动有 MCP」，可改 DSH 配置 `C:\Users\CuteGrass\.dsh\profiles\desktop\cordis.patch.yml` 第 42 行：

```yaml
url: http://localhost:23156/mcp
```

（23156 为本项目 `pin=94bbe2fa` 的派生端口；不同项目/机器的端口可能不同，以编辑器 stdout 的 `derivedPort=` 为准。）

### 8.3 临时启用插件的最小步骤（可复现）

```powershell
# 1) 备份
Copy-Item project.godot "$env:TEMP\project.godot.before" -Force
# 2) 启用（保留 config/features 中的 "C#"）
(Get-Content project.godot -Raw) -replace 'enabled=PackedStringArray\(\)', 'enabled=PackedStringArray("res://addons/godot_mcp/plugin.cfg")' | Set-Content project.godot -Encoding utf8 -NoNewline
# 3) 启动 headless 编辑器（见 8.1 的环境变量）
# 4) 恢复
Copy-Item "$env:TEMP\project.godot.before" project.godot -Force
```

注：本次直接复用 2026-10-24 已构建的 `.godot\mono\temp\bin\Debug` 产物，未执行 `dotnet build`；若换机器或清空 `.godot`，需要 `dotnet build perfect_game.csproj` 后再启动编辑器。

### 8.4 如何在 DSH 里使用这些工具

- DSH 配置位置：`C:\Users\CuteGrass\.dsh\profiles\desktop\cordis.patch.yml` 第 35–46 行，`serverName: godot`，`url: http://localhost:26475/mcp`；`reconnect.enabled: true`（maxAttempts 10）。
- 使用前提：**先打开（或让 godot-cli 保持一个）启用插件的编辑器**，让插件连上 26475；DSH 的 MCP 客户端在会话启动时拉取一次工具列表，因此需要在编辑器已连接的状态下（重新）开启 DSH 会话，agent 侧才会出现上述 15 个工具。若 DSH 已在运行、之后才启动编辑器，当前会话的工具集不会自动补齐（本次实测：DSH 于 16:11:33 启动时插件未连接，收到 0 个工具；16:17 插件连上后服务端 `tools/list` 才有 15 个工具）。此时可以先开着编辑器再重开会话，或直接用 `godot-cli` / §8.5 的 curl 调用。
- 降级提示：服务常驻但编辑器关闭时不会自动启动编辑器；此时 DSH 工具列表为空，调用引擎工具会得到 §6 的错误。
- 保持服务不重启：服务未配置 Redis，重启会丢会话。

### 8.5 手工 JSON-RPC 复现（curl）

```powershell
# initialize，导出响应头
curl.exe -s -D init-headers.txt -o init-body.txt -X POST http://localhost:26475/mcp `
  -H "Content-Type: application/json" -H "Accept: application/json, text/event-stream" `
  --data-binary '{"jsonrpc":"2.0","id":1,"method":"initialize","params":{"protocolVersion":"2024-11-05","capabilities":{},"clientInfo":{"name":"probe","version":"1.0"}}}'
# 取 session id
$sid = ((Get-Content init-headers.txt | Select-String '^Mcp-Session-Id:').Line -split ':\s*',2)[1].Trim()
# initialized（202）
curl.exe -s -o NUL -w "%{http_code}`n" -X POST http://localhost:26475/mcp -H "Content-Type: application/json" `
  -H "Accept: application/json, text/event-stream" -H "Mcp-Session-Id: $sid" `
  --data-binary '{"jsonrpc":"2.0","method":"notifications/initialized"}'
# 列表
curl.exe -s -X POST http://localhost:26475/mcp -H "Content-Type: application/json" `
  -H "Accept: application/json, text/event-stream" -H "Mcp-Session-Id: $sid" `
  --data-binary '{"jsonrpc":"2.0","id":2,"method":"tools/list","params":{}}'
# 真实工具调用
curl.exe -s -X POST http://localhost:26475/mcp -H "Content-Type: application/json" `
  -H "Accept: application/json, text/event-stream" -H "Mcp-Session-Id: $sid" `
  --data-binary '{"jsonrpc":"2.0","id":3,"method":"tools/call","params":{"name":"rql-schema","arguments":{}}}'
```

`godot-cli` 侧（插件连接时）：

```powershell
godot-cli.cmd --version
godot-cli.cmd status --url http://localhost:26475
godot-cli.cmd run-tool rql-schema --url http://localhost:26475 --input '{}'
```

---

## 9. 收尾与仓库状态

| 检查项 | 结果 |
| --- | --- |
| `project.godot` 恢复 | 已从 `%TEMP%\perfect_game-project.godot.bak` 恢复；SHA256 前后一致：`FA62148F5AB65CBC7174D2CD450D17015C433A3D05BB2D8008EA56953410B883` |
| `git status --porcelain` | `M project.godot`（**预存**的 `config/features` 增加 `"C#"` 改动，非本次测试引入、未回退）+ `?? docs/mcp-test.md`（本报告）+ `?? docs/framework.md`（并行任务产出，非本次测试创建） |
| 其它未跟踪/修改文件 | 无（插件生成的 `.claude/skills` 已被 `.gitignore` 忽略；临时脚本/日志均在 `%TEMP%`） |
| 本次启动的 Godot 进程 | 两轮均使用独立 PID（23164、2044），均已 `Stop-Process`，确认无遗留（`Get-Process *Godot*` 为空） |
| MCP 服务（PID 29900） | 仍存活，未重启；26475 继续 LISTENING |
| git commit | 未执行 |

---

## 10. 附：原始证据文件位置

- 服务日志：`.godot\mcp-server\win-x64\logs\server-log.txt`（关键行号见 §5/§6）
- 服务错误日志：`.godot\mcp-server\win-x64\logs\server-log-error.txt`
- 本次测试临时产物（均在 `%TEMP%\dsh-ZuJATE\`）：
  - `godot-e2e-stdout.log`（编辑器 stdout，188 行）
  - `godot-e2e-stderr.log`（编辑器 stderr，32 行）
  - `godot-e2e2-stdout.log`、`godot-e2e2-stderr.log`（16:20 复测的编辑器输出）
  - `godot-e2e.pid`（PID 23164）
  - `mcp-e2e\tools-list.json`（15 工具原始 JSON）
  - `mcp-e2e\call_*.body.txt`（各工具调用 SSE 原始响应）
  - `perfect_game-project.godot.bak`（测试前 project.godot 备份）
  - 测试脚本：`mcp-proto.ps1`、`mcp-proto2.ps1`、`mcp-e2e-list.ps1`、`mcp-e2e-calls.ps1`（均在 `%TEMP%` 根目录）

---

## 11. 修复落地与复测（2026-10-25 第二轮，已实施）

### 11.1 采用的方案：项目内 `.env` 把插件固定指向 26475

新增/修改文件：

| 文件 | 说明 |
| --- | --- |
| `.env` | 本地生效，**已被 `.gitignore` 忽略**；3 行：`GODOT_MCP_HOST=http://localhost:26475`、`GODOT_MCP_CONNECTION_MODE=Custom`、`GODOT_MCP_AUTH_OPTION=none` |
| `.env.example` | 可提交的模板（同样 3 行 + 注释），新机器先复制为 `.env` |
| `.gitignore` | 追加 `.env`，避免把机器相关配置提交 |

插件启用时会读取 `res://.env`。本轮**没有设置任何进程环境变量**，只在项目根放 `.env`，编辑器 stdout 即出现：

```text
[Godot-MCP] applied 3 setting(s) from project .env (C:/Users/CuteGrass/Documents/perfect_game/.env).
[Godot-MCP] connecting (mode=Custom, host=http://localhost:26475) ...
[McpPlugin] McpManagerClientHub: ... Connection established successfully to: /hub/mcp-server
[McpPlugin] ... Version handshake completed. Compatible: True
```

`derivedPort=23156` 仍会打印（插件身份派生值不变），但连接目标已被 `.env` 覆盖为 26475，因此插件、常驻服务与 DSH 配置三者一致，不再分裂。

### 11.2 复测结果

| 检查项 | 实际结果 |
| --- | --- |
| `.env` 被读取 | `applied 3 setting(s) from project .env` |
| SignalR 连接 | `connected to McpServerHub` + `Version handshake successful`（Plugin 0.33.0 / API 2.0.0 / Godot 4.7.2-stable） |
| 工具注册 | `tools/list` 返回 **15** 个工具（与 §4 完全一致） |
| 真实工具调用 | `rql-schema` → `isError=false`，返回 sources/functions 文本 |
| 收尾 | `project.godot` 恢复（SHA256 前后一致）、`Get-Process Godot*` 为空、服务 PID 29900 未重启、26475 仍 LISTENING |

复测脚本：`%TEMP%\pg-mcp-fix-e2e.ps1`（本机临时文件，不入库）。

### 11.3 日常使用步骤

1. 新机器：`Copy-Item .env.example .env`（本机已完成，`.env` 不会提交）。
2. 在编辑器内启用 `addons/godot_mcp/plugin.cfg`（或把 `project.godot` 的 `[editor_plugins] enabled` 指向它；仓库默认仍关闭）。
3. 直接启动编辑器即可连上 26475，无需再设 `GODOT_MCP_*` 环境变量。
4. 若希望 DSH 会话里的 agent 直接使用这 15 个工具：先启动编辑器并确认插件已连接，再开启/重开 DSH 会话（原因见 §8.4）。
